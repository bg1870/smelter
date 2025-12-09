use std::sync::Arc;

use smelter_render::Resolution;

use crate::codecs::{OutputPixelFormat, VideoEncoderBitrate};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum FfmpegH264EncoderPreset {
    Ultrafast,
    Superfast,
    Veryfast,
    Faster,
    Fast,
    Medium,
    Slow,
    Slower,
    Veryslow,
    Placebo,
}

/// Codec-level flags for FFmpeg H264 encoder.
/// This struct is extensible for future codec flags.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Default)]
pub struct FfmpegH264CodecFlags {
    /// Enable global header (SPS/PPS in extradata).
    /// Required for streaming protocols like RTMP, HLS, DASH.
    /// May cause issues with WebRTC (WHEP) outputs.
    pub global_header: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct FfmpegH264EncoderOptions {
    pub preset: FfmpegH264EncoderPreset,
    pub bitrate: Option<VideoEncoderBitrate>,
    pub resolution: Resolution,
    pub pixel_format: OutputPixelFormat,
    pub raw_options: Vec<(Arc<str>, Arc<str>)>,
    /// Optional codec-level flags. If None, no special codec flags are set.
    pub codec_flags: Option<FfmpegH264CodecFlags>,
}

#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct VulkanH264EncoderOptions {
    pub resolution: Resolution,
    pub bitrate: Option<VideoEncoderBitrate>,
}

#[derive(Debug, thiserror::Error)]
pub enum H264AvcDecoderConfigError {
    #[error("Incorrect AVCDecoderConfig. Expected more bytes.")]
    NotEnoughBytes(#[from] bytes::TryGetError),

    #[error("Not AVCC")]
    NotAVCC,
}
