use std::{sync::Arc, time::Duration};

use crate::{
    codecs::{AudioEncoderOptions, VideoDecoderOptions, VideoEncoderOptions},
    input::InputBufferOptions,
};

// Input options
#[derive(Debug, Clone)]
pub struct RtmpInputOptions {
    pub port: u16,
    pub stream_key: String,
    pub buffer: InputBufferOptions,
    pub video_decoders: RtmpInputVideoDecoders,
    pub timeout_seconds: u32,
}

#[derive(Debug, Clone, Copy)]
pub struct RtmpInputVideoDecoders {
    pub h264: Option<VideoDecoderOptions>,
}

impl Default for RtmpInputOptions {
    fn default() -> Self {
        Self {
            port: 1935,
            stream_key: String::new(),
            buffer: InputBufferOptions::Const(Some(Duration::from_millis(500))),
            video_decoders: RtmpInputVideoDecoders::default(),
            timeout_seconds: 30,
        }
    }
}

impl Default for RtmpInputVideoDecoders {
    fn default() -> Self {
        Self { h264: None }
    }
}

// Output options
#[derive(Debug, Clone)]
pub struct RtmpOutputOptions {
    pub url: Arc<str>,
    pub video: Option<VideoEncoderOptions>,
    pub audio: Option<AudioEncoderOptions>,
}
