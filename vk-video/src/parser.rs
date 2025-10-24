use std::sync::{Arc, mpsc};

use au_splitter::AUSplitter;
use h264_reader::{
    annexb::AnnexBReader,
    nal::{pps::PicParameterSet, slice::SliceHeader, sps::SeqParameterSet},
    push::NalAccumulator,
};
use nalu_parser::{NalReceiver, ParsedNalu};
use nalu_splitter::NALUSplitter;
use reference_manager::{ReferenceContext, ReferenceManagementError};

pub use reference_manager::ReferenceId;

mod au_splitter;
mod nalu_parser;
mod nalu_splitter;
mod reference_manager;

#[derive(Clone, derivative::Derivative)]
#[derivative(Debug)]
#[allow(non_snake_case)]
pub struct DecodeInformation {
    pub reference_list: Option<Vec<ReferencePictureInfo>>,
    #[derivative(Debug = "ignore")]
    pub rbsp_bytes: Vec<u8>,
    pub slice_indices: Vec<usize>,
    #[derivative(Debug = "ignore")]
    pub header: Arc<SliceHeader>,
    pub sps_id: u8,
    pub pps_id: u8,
    pub picture_info: PictureInfo,
    pub pts: Option<u64>,
}

#[derive(Debug, Clone, Copy)]
#[allow(non_snake_case)]
pub struct ReferencePictureInfo {
    pub id: ReferenceId,
    pub LongTermPicNum: Option<u64>,
    pub non_existing: bool,
    pub FrameNum: u16,
    pub PicOrderCnt: [i32; 2],
}

#[derive(Debug, Clone, Copy)]
#[allow(non_snake_case)]
pub struct PictureInfo {
    pub used_for_long_term_reference: bool,
    pub non_existing: bool,
    pub FrameNum: u16,
    pub PicOrderCnt_for_decoding: [i32; 2],
    pub PicOrderCnt_as_reference_pic: [i32; 2],
}

#[derive(Debug, Clone)]
pub enum DecoderInstruction {
    Decode {
        decode_info: DecodeInformation,
        reference_id: ReferenceId,
    },

    Idr {
        decode_info: DecodeInformation,
        reference_id: ReferenceId,
    },

    Drop {
        reference_ids: Vec<ReferenceId>,
    },

    Sps(SeqParameterSet),

    Pps(PicParameterSet),
}

#[derive(Debug, thiserror::Error)]
pub enum ParserError {
    #[error(transparent)]
    ReferenceManagementError(#[from] ReferenceManagementError),

    #[error("Bitstreams that allow gaps in frame_num are not supported")]
    GapsInFrameNumNotSupported,

    #[error("Streams containing fields instead of frames are not supported")]
    FieldsNotSupported,

    #[error("Error while parsing a NAL header: {0:?}")]
    NalHeaderParseError(h264_reader::nal::NalHeaderError),

    #[error("Error while parsing SPS: {0:?}")]
    SpsParseError(h264_reader::nal::sps::SpsError),

    #[error("Error while parsing PPS: {0:?}")]
    PpsParseError(h264_reader::nal::pps::PpsError),

    #[error("Error while parsing a slice: {0:?}")]
    SliceParseError(h264_reader::nal::slice::SliceHeaderError),
}

pub struct Parser {
    reader: AnnexBReader<NalAccumulator<NalReceiver>>,
    reference_ctx: ReferenceContext,
    au_splitter: AUSplitter,
    receiver: mpsc::Receiver<Result<ParsedNalu, ParserError>>,
    nalu_splitter: NALUSplitter,
}

impl Default for Parser {
    fn default() -> Self {
        let (tx, rx) = mpsc::channel();

        Parser {
            reader: AnnexBReader::accumulate(NalReceiver::new(tx)),
            reference_ctx: ReferenceContext::default(),
            au_splitter: AUSplitter::default(),
            receiver: rx,
            nalu_splitter: NALUSplitter::default(),
        }
    }
}

impl Parser {
    pub fn parse(
        &mut self,
        bytes: &[u8],
        pts: Option<u64>,
    ) -> Result<Vec<DecoderInstruction>, ParserError> {
        let nalus = self.nalu_splitter.push(bytes, pts);
        let nalus = nalus
            .into_iter()
            .map(|(nalu, pts)| {
                self.reader.push(&nalu);
                (self.receiver.try_recv().unwrap(), pts)
            })
            .collect::<Vec<_>>();

        let mut instructions = Vec::new();
        for (nalu, pts) in nalus {
            let nalu = nalu?;

            let Some(nalus) = self.au_splitter.put_nalu(nalu, pts) else {
                continue;
            };

            let mut slices = Vec::new();
            for (nalu, pts) in nalus {
                match nalu {
                    ParsedNalu::Sps(seq_parameter_set) => {
                        instructions.push(DecoderInstruction::Sps(seq_parameter_set))
                    }
                    ParsedNalu::Pps(pic_parameter_set) => {
                        instructions.push(DecoderInstruction::Pps(pic_parameter_set))
                    }
                    ParsedNalu::Slice(slice) => {
                        slices.push((slice, pts));
                    }

                    ParsedNalu::Other(_) => {}
                }
            }

            // TODO: warn when not all pts are equal here
            let mut inst = self.reference_ctx.put_picture(slices)?;
            instructions.append(&mut inst);
        }

        Ok(instructions)
    }
}
