use vk_video::{ParsedNalu, Slice, SliceFamily};

use crate::codecs::VideoCodec;
use crate::prelude::*;

// TODO: Bundle NAL units or bytes depending on what decoder needs
// TODO: Make it an iterator
pub(super) struct MissedFrameDetector {
    parser: VideoChunkParser,
    prev_ref_frame_num: u32,
    is_corrupted_state: bool,
}

impl MissedFrameDetector {
    // TODO: Some way of detecting decoder's coder??
    pub fn new(video_codec: VideoCodec) -> Result<Self, CreateMissedFrameDetectorError> {
        let parser = match video_codec {
            VideoCodec::H264 => VideoChunkParser::H264(vk_video::Parser::new()),
            codec => return Err(CreateMissedFrameDetectorError::UnsupportedCodec(codec)),
        };

        Ok(Self {
            parser,
            prev_ref_frame_num: 0,
            is_corrupted_state: false,
        })
    }

    pub fn detect(&mut self, chunk: &EncodedInputChunk) -> bool {
        let nalus = self
            .parser
            .parse(&chunk.data, Some(chunk.pts.as_micros() as u64))
            .unwrap_or(Vec::new());

        for nalus in nalus {
            let (nalu, _) = nalus.last().unwrap();
            let ParsedNalu::Slice(slice) = nalu else {
                continue;
            };

            // TODO: What about SP and SI frames?
            if slice.header.slice_type.family == SliceFamily::I {
                self.reset_state();
                continue;
            }
            if self.is_corrupted_state {
                continue;
            }

            let is_correct_frame_num = self.verify_frame_num(slice);
            self.prev_ref_frame_num = slice.header.frame_num as u32;
            if !is_correct_frame_num {
                self.is_corrupted_state = true;
                return true;
            }
        }
        self.is_corrupted_state
    }

    fn verify_frame_num(&self, slice: &Slice) -> bool {
        let frame_num = slice.header.frame_num as u32;
        let max_frame_num = 1u32 << slice.sps.log2_max_frame_num();
        frame_num == self.prev_ref_frame_num
            || frame_num == (self.prev_ref_frame_num + 1) % max_frame_num
    }

    fn reset_state(&mut self) {
        self.prev_ref_frame_num = 0;
        self.is_corrupted_state = false;
    }
}

pub(super) enum VideoChunkParser {
    // TODO: Maybe we don't have to parse the whole thing. Maybe there's a faster way?
    H264(vk_video::Parser),
}

// TODO: Don't rely on vk_video::ParserError
// Also using vk_video::Parser looks wrong. Maybe it would be better to export them to separate crate? (codec-utlis)
// TODO: vk-video is only avaiable on platforms that support vulkan so this won't work on macos
impl VideoChunkParser {
    pub fn parse(
        &mut self,
        bytes: &[u8],
        pts: Option<u64>,
    ) -> Result<Vec<Vec<(ParsedNalu, Option<u64>)>>, vk_video::ParserError> {
        match self {
            VideoChunkParser::H264(parser) => parser.parse(bytes, pts),
        }
    }
}

#[derive(thiserror::Error, Debug)]
pub enum CreateMissedFrameDetectorError {
    #[error("Provided codec is not supported by missed frame detector: {0:?}")]
    UnsupportedCodec(VideoCodec),
}
