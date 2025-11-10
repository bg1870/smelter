use std::{
    ffi::CString,
    ptr, slice,
    sync::{
        Arc,
        atomic::{AtomicBool, Ordering},
    },
    time::{Duration, Instant},
};

use bytes::Bytes;
use crossbeam_channel::{Receiver, bounded};
use ffmpeg_next::{
    Dictionary, Packet, Stream,
    ffi::{
        avformat_alloc_context, avformat_close_input, avformat_find_stream_info,
        avformat_open_input,
    },
    format::context,
    media::Type,
    util::interrupt,
};
use smelter_render::InputId;
use tracing::{Level, debug, error, span, trace, warn};

use crate::{
    pipeline::{
        decoder::{
            DecoderThreadHandle,
            decoder_thread_audio::{AudioDecoderThread, AudioDecoderThreadOptions},
            decoder_thread_video::{VideoDecoderThread, VideoDecoderThreadOptions},
            fdk_aac, ffmpeg_h264,
            h264_utils::{AvccToAnnexBRepacker, H264AvcDecoderConfig},
            vulkan_h264,
        },
        input::Input,
        utils::input_buffer::InputBuffer,
    },
    queue::QueueDataReceiver,
    thread_utils::InitializableThread,
};

use crate::prelude::*;

/// Main RTMP input structure managing stream lifecycle
pub struct RtmpInput {
    should_close: Arc<AtomicBool>,
}

/// Internal track structure for audio/video streams
struct Track {
    index: usize,
    handle: DecoderThreadHandle,
    state: StreamState,
}

impl RtmpInput {
    pub fn new_input(
        ctx: Arc<PipelineCtx>,
        input_id: InputId,
        opts: RtmpInputOptions,
    ) -> Result<(Input, InputInitInfo, QueueDataReceiver), InputInitError> {
        let should_close = Arc::new(AtomicBool::new(false));
        let buffer = InputBuffer::new(&ctx, opts.buffer);

        // Create RTMP server context with listen mode
        let input_ctx = FfmpegInputContext::new_rtmp_server(
            opts.port,
            &opts.stream_key,
            should_close.clone(),
            opts.timeout_seconds,
        )?;

        // Handle audio track (AAC)
        let (audio, samples_receiver) = match input_ctx.audio_stream() {
            Some(stream) => {
                let (track, receiver) =
                    Self::handle_audio_track(&ctx, &input_id, &stream, buffer.clone())?;
                (Some(track), Some(receiver))
            }
            None => (None, None),
        };

        // Handle video track (H.264)
        let (video, frame_receiver) = match input_ctx.video_stream() {
            Some(stream) => {
                let (track, receiver) = Self::handle_video_track(
                    &ctx,
                    &input_id,
                    &stream,
                    opts.video_decoders,
                    buffer,
                )?;
                (Some(track), Some(receiver))
            }
            None => (None, None),
        };

        let receivers = QueueDataReceiver {
            video: frame_receiver,
            audio: samples_receiver,
        };

        // Spawn demuxer thread
        Self::spawn_demuxer_thread(input_id, input_ctx, audio, video);

        Ok((
            Input::Rtmp(Self { should_close }),
            InputInitInfo::Other,
            receivers,
        ))
    }

    fn handle_audio_track(
        ctx: &Arc<PipelineCtx>,
        input_id: &InputId,
        stream: &Stream<'_>,
        buffer: InputBuffer,
    ) -> Result<(Track, Receiver<PipelineEvent<InputAudioSamples>>), InputInitError> {
        // AAC audio stream - extract AudioSpecificConfig from extradata
        let asc = read_extra_data(stream);
        let (samples_sender, samples_receiver) = bounded(5);
        let state = StreamState::new(ctx.queue_sync_point, stream.time_base(), buffer);
        let handle = AudioDecoderThread::<fdk_aac::FdkAacDecoder>::spawn(
            input_id.clone(),
            AudioDecoderThreadOptions {
                ctx: ctx.clone(),
                decoder_options: FdkAacDecoderOptions { asc },
                samples_sender,
                input_buffer_size: 2000,
            },
        )?;

        Ok((
            Track {
                index: stream.index(),
                handle,
                state,
            },
            samples_receiver,
        ))
    }

    fn handle_video_track(
        ctx: &Arc<PipelineCtx>,
        input_id: &InputId,
        stream: &Stream<'_>,
        video_decoders: RtmpInputVideoDecoders,
        buffer: InputBuffer,
    ) -> Result<(Track, Receiver<PipelineEvent<Frame>>), InputInitError> {
        let (frame_sender, frame_receiver) = bounded(5);
        let state = StreamState::new(ctx.queue_sync_point, stream.time_base(), buffer);

        let extra_data = read_extra_data(stream);
        let h264_config = extra_data
            .map(H264AvcDecoderConfig::parse)
            .transpose()
            .unwrap_or_else(|e| match e {
                H264AvcDecoderConfigError::NotAVCC => None,
                _ => {
                    warn!("Could not parse extra data: {e}");
                    None
                }
            });

        let decoder_thread_options = VideoDecoderThreadOptions {
            ctx: ctx.clone(),
            transformer: h264_config.clone().map(AvccToAnnexBRepacker::new),
            frame_sender,
            input_buffer_size: 2000,
        };

        // Auto-select decoder based on Vulkan support if not specified
        let vulkan_supported = ctx.graphics_context.has_vulkan_decoder_support();
        let h264_decoder = video_decoders.h264.unwrap_or({
            match vulkan_supported {
                true => VideoDecoderOptions::VulkanH264,
                false => VideoDecoderOptions::FfmpegH264,
            }
        });

        let handle = match h264_decoder {
            VideoDecoderOptions::FfmpegH264 => {
                VideoDecoderThread::<ffmpeg_h264::FfmpegH264Decoder, _>::spawn(
                    input_id.clone(),
                    decoder_thread_options,
                )?
            }
            VideoDecoderOptions::VulkanH264 => {
                if !vulkan_supported {
                    return Err(InputInitError::DecoderError(
                        DecoderInitError::VulkanContextRequiredForVulkanDecoder,
                    ));
                }
                VideoDecoderThread::<vulkan_h264::VulkanH264Decoder, _>::spawn(
                    input_id.clone(),
                    decoder_thread_options,
                )?
            }
            _ => {
                return Err(InputInitError::InvalidVideoDecoderProvided {
                    expected: VideoCodec::H264,
                });
            }
        };

        Ok((
            Track {
                index: stream.index(),
                handle,
                state,
            },
            frame_receiver,
        ))
    }

    fn spawn_demuxer_thread(
        input_id: InputId,
        input_ctx: FfmpegInputContext,
        audio: Option<Track>,
        video: Option<Track>,
    ) {
        std::thread::Builder::new()
            .name(format!("RTMP thread for input {}", input_id.clone()))
            .spawn(move || {
                let _span =
                    span!(Level::INFO, "RTMP thread", input_id = input_id.to_string()).entered();

                Self::run_demuxer_thread(input_ctx, audio, video);
            })
            .unwrap();
    }

    fn run_demuxer_thread(
        mut input_ctx: FfmpegInputContext,
        mut audio: Option<Track>,
        mut video: Option<Track>,
    ) {
        loop {
            let packet = match input_ctx.read_packet() {
                Ok(packet) => packet,
                Err(ffmpeg_next::Error::Eof | ffmpeg_next::Error::Exit) => {
                    debug!("RTMP stream ended");
                    break;
                }
                Err(err) => {
                    warn!("RTMP read error {err:?}");
                    continue;
                }
            };

            if packet.is_corrupt() {
                error!(
                    "Corrupted packet {:?} {:?}",
                    packet.stream(),
                    packet.flags()
                );
                continue;
            }

            // Handle video packets
            if let Some(track) = &mut video
                && packet.stream() == track.index
            {
                let (pts, dts) = track.state.pts_dts_from_packet(&packet);

                let chunk = EncodedInputChunk {
                    data: Bytes::copy_from_slice(packet.data().unwrap()),
                    pts,
                    dts,
                    kind: MediaKind::Video(VideoCodec::H264),
                };

                let sender = &track.handle.chunk_sender;
                trace!(?chunk, buffer = sender.len(), "Sending video chunk");
                if sender.is_empty() {
                    debug!("RTMP input video channel was drained");
                }
                if sender.send(PipelineEvent::Data(chunk)).is_err() {
                    debug!("Channel closed")
                }
            }

            // Handle audio packets
            if let Some(track) = &mut audio
                && packet.stream() == track.index
            {
                let (pts, dts) = track.state.pts_dts_from_packet(&packet);

                let chunk = EncodedInputChunk {
                    data: bytes::Bytes::copy_from_slice(packet.data().unwrap()),
                    pts,
                    dts,
                    kind: MediaKind::Audio(AudioCodec::Aac),
                };

                let sender = &track.handle.chunk_sender;
                trace!(?chunk, buffer = sender.len(), "Sending audio chunk");
                if sender.is_empty() {
                    debug!("RTMP input audio channel was drained");
                }
                if sender.send(PipelineEvent::Data(chunk)).is_err() {
                    debug!("Channel closed")
                }
            }
        }

        // Send EOS to decoder threads
        if let Some(Track { handle, .. }) = &audio
            && handle.chunk_sender.send(PipelineEvent::EOS).is_err()
        {
            debug!("Channel closed. Failed to send audio EOS.")
        }

        if let Some(Track { handle, .. }) = &video
            && handle.chunk_sender.send(PipelineEvent::EOS).is_err()
        {
            debug!("Channel closed. Failed to send video EOS.")
        }

        debug!("RTMP demuxer thread terminated");
    }
}

impl Drop for RtmpInput {
    fn drop(&mut self) {
        debug!("Closing RTMP input");
        self.should_close.store(true, Ordering::Relaxed);
    }
}

/// Stream state for timestamp management and discontinuity detection
struct StreamState {
    queue_start_time: Instant,
    buffer: InputBuffer,
    time_base: ffmpeg_next::Rational,

    reference_pts_and_timestamp: Option<(Duration, f64)>,

    pts_discontinuity: DiscontinuityState,
    dts_discontinuity: DiscontinuityState,
}

impl StreamState {
    fn new(
        queue_start_time: Instant,
        time_base: ffmpeg_next::Rational,
        buffer: InputBuffer,
    ) -> Self {
        Self {
            queue_start_time,
            time_base,
            buffer,

            reference_pts_and_timestamp: None,
            pts_discontinuity: DiscontinuityState::new(false, time_base),
            dts_discontinuity: DiscontinuityState::new(true, time_base),
        }
    }

    fn pts_dts_from_packet(&mut self, packet: &Packet) -> (Duration, Option<Duration>) {
        let pts_timestamp = packet.pts().unwrap_or(0) as f64;
        let dts_timestamp = packet.dts().map(|dts| dts as f64);
        let packet_duration = packet.duration() as f64;

        self.pts_discontinuity
            .detect_discontinuity(pts_timestamp, packet_duration);
        if let Some(dts) = dts_timestamp {
            self.dts_discontinuity
                .detect_discontinuity(dts, packet_duration);
        }

        let pts_timestamp = pts_timestamp + self.pts_discontinuity.offset;
        let dts_timestamp = dts_timestamp.map(|dts| dts + self.dts_discontinuity.offset);

        let (reference_pts, reference_timestamp) = *self
            .reference_pts_and_timestamp
            .get_or_insert_with(|| (self.queue_start_time.elapsed(), pts_timestamp));

        let pts_diff_secs = timestamp_to_secs(pts_timestamp - reference_timestamp, self.time_base);
        let pts =
            Duration::from_secs_f64(reference_pts.as_secs_f64() + f64::max(pts_diff_secs, 0.0));

        let dts = dts_timestamp.map(|dts| {
            Duration::from_secs_f64(f64::max(timestamp_to_secs(dts, self.time_base), 0.0))
        });

        self.buffer.recalculate_buffer(pts);
        (pts + self.buffer.size(), dts)
    }
}

/// Discontinuity detection state for PTS/DTS
struct DiscontinuityState {
    check_timestamp_monotonicity: bool,
    time_base: ffmpeg_next::Rational,
    prev_timestamp: Option<f64>,
    next_predicted_timestamp: Option<f64>,
    offset: f64,
}

impl DiscontinuityState {
    /// (10s) This value was picked arbitrarily but it's quite conservative.
    const DISCONTINUITY_THRESHOLD: f64 = 10.0;

    fn new(check_timestamp_monotonicity: bool, time_base: ffmpeg_next::Rational) -> Self {
        Self {
            check_timestamp_monotonicity,
            time_base,
            prev_timestamp: None,
            next_predicted_timestamp: None,
            offset: 0.0,
        }
    }

    fn detect_discontinuity(&mut self, timestamp: f64, packet_duration: f64) {
        let (Some(prev_timestamp), Some(next_timestamp)) =
            (self.prev_timestamp, self.next_predicted_timestamp)
        else {
            self.prev_timestamp = Some(timestamp);
            self.next_predicted_timestamp = Some(timestamp + packet_duration);
            return;
        };

        // Detect discontinuity
        let timestamp_delta =
            timestamp_to_secs(f64::abs(next_timestamp - timestamp), self.time_base);

        let is_discontinuity = timestamp_delta >= Self::DISCONTINUITY_THRESHOLD
            || (self.check_timestamp_monotonicity && prev_timestamp > timestamp);
        if is_discontinuity {
            debug!("Discontinuity detected: {prev_timestamp} -> {timestamp}");
            self.offset += next_timestamp - timestamp;
        }

        self.prev_timestamp = Some(timestamp);
        self.next_predicted_timestamp = Some(timestamp + packet_duration);
    }
}

/// Convert FFmpeg timestamp to seconds
fn timestamp_to_secs(timestamp: f64, time_base: ffmpeg_next::Rational) -> f64 {
    f64::max(timestamp, 0.0) * time_base.numerator() as f64 / time_base.denominator() as f64
}

/// Helper function to read extra data from stream (SPS/PPS for H.264, ASC for AAC)
fn read_extra_data(stream: &Stream<'_>) -> Option<Bytes> {
    unsafe {
        let codecpar = (*stream.as_ptr()).codecpar;
        let size = (*codecpar).extradata_size;
        if size > 0 {
            Some(Bytes::copy_from_slice(slice::from_raw_parts(
                (*codecpar).extradata,
                size as usize,
            )))
        } else {
            None
        }
    }
}

/// FFmpeg input context wrapper for RTMP server
struct FfmpegInputContext {
    ctx: context::Input,
}

impl FfmpegInputContext {
    /// Create new RTMP server context with listen mode
    fn new_rtmp_server(
        port: u16,
        stream_key: &str,
        should_close: Arc<AtomicBool>,
        timeout_seconds: u32,
    ) -> Result<Self, ffmpeg_next::Error> {
        // Validate stream key
        if stream_key.is_empty() {
            error!("Stream key cannot be empty");
            return Err(ffmpeg_next::Error::InvalidData);
        }

        // Construct RTMP URL for listen mode: rtmp://0.0.0.0:PORT/live/STREAM_KEY
        let url = format!("rtmp://0.0.0.0:{}/live/{}", port, stream_key);

        debug!("Starting RTMP server on {}", url);

        let ctx = input_with_dictionary_and_interrupt(
            &url,
            Dictionary::from_iter([
                ("listen", "1"),  // Enable RTMP server mode
                ("timeout", &timeout_seconds.to_string()),  // Connection timeout
                ("rtmp_live", "live"),  // Optimize for live streaming
                ("rtmp_buffer", "1000"),  // 1 second buffer
                ("probesize", "32768"),  // Fast stream detection
                ("analyzeduration", "500000"),  // 0.5s analysis
                ("fflags", "nobuffer"),  // Minimize buffering
            ]),
            move || should_close.load(Ordering::Relaxed),
        )?;

        debug!("RTMP server started successfully");
        Ok(Self { ctx })
    }

    fn audio_stream(&self) -> Option<Stream<'_>> {
        self.ctx.streams().best(Type::Audio)
    }

    fn video_stream(&self) -> Option<Stream<'_>> {
        self.ctx.streams().best(Type::Video)
    }

    fn read_packet(&mut self) -> Result<Packet, ffmpeg_next::Error> {
        let mut packet = Packet::empty();
        packet.read(&mut self.ctx)?;
        Ok(packet)
    }
}

/// Combined implementation of ffmpeg_next::format::input_with_interrupt and
/// ffmpeg_next::format::input_with_dictionary that allows passing both interrupt
/// callback and Dictionary with options
fn input_with_dictionary_and_interrupt<F>(
    path: &str,
    options: Dictionary,
    interrupt_fn: F,
) -> Result<context::Input, ffmpeg_next::Error>
where
    F: FnMut() -> bool + 'static,
{
    unsafe {
        let mut ps = avformat_alloc_context();

        (*ps).interrupt_callback = interrupt::new(Box::new(interrupt_fn)).interrupt;

        let path = CString::new(path).unwrap();
        let mut opts = options.disown();
        let res = avformat_open_input(&mut ps, path.as_ptr(), ptr::null_mut(), &mut opts);

        Dictionary::own(opts);

        match res {
            0 => match avformat_find_stream_info(ps, ptr::null_mut()) {
                r if r >= 0 => Ok(context::Input::wrap(ps)),
                e => {
                    avformat_close_input(&mut ps);
                    Err(ffmpeg_next::Error::from(e))
                }
            },

            e => Err(ffmpeg_next::Error::from(e)),
        }
    }
}
