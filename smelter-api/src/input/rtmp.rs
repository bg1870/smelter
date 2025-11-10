use schemars::JsonSchema;
use serde::{Deserialize, Serialize};

/// Parameters for an input stream from RTMP source.
///
/// RTMP (Real-Time Messaging Protocol) is a TCP-based streaming protocol commonly used
/// with encoders like OBS Studio, FFmpeg, and hardware encoders. Publishers connect to
/// `rtmp://host:PORT/live/STREAM_KEY` where PORT and STREAM_KEY must match the
/// registered input configuration.
///
/// # Minimal Example
///
/// ```json
/// {
///   "port": 1935,
///   "stream_key": "my-secret-key"
/// }
/// ```
///
/// This creates an RTMP server listening on port 1935 with a 30-second timeout,
/// auto-selected decoder, and latency-optimized buffering.
///
/// # Full Example
///
/// ```json
/// {
///   "port": 1936,
///   "stream_key": "production-stream-abc123",
///   "timeout_seconds": 60,
///   "video": {
///     "decoder": "vulkan_h264"
///   },
///   "buffer": "latency_optimized",
///   "required": false,
///   "offset_ms": 100.0
/// }
/// ```
#[derive(Debug, Serialize, Deserialize, Clone, JsonSchema)]
#[serde(deny_unknown_fields)]
pub struct RtmpInput {
    /// RTMP server listening port. Must be in range 1024-65535 (non-privileged ports).
    /// Standard RTMP port is 1935. Publishers connect to `rtmp://host:PORT/live/STREAM_KEY`.
    ///
    /// Common values:
    /// - `1935`: Standard RTMP port
    /// - `1936`: Often used for RTMPS (RTMP over TLS, not currently supported)
    pub port: u16,

    /// Stream key for authentication. Publishers must provide this key to connect.
    /// Must be non-empty. Recommended: Use UUID or long random string for security.
    ///
    /// Example: `"550e8400-e29b-41d4-a716-446655440000"`
    ///
    /// Publishers connect to: `rtmp://host:PORT/live/STREAM_KEY`
    pub stream_key: String,

    /// (**default=`30`**) Connection timeout in seconds. How long to wait for publisher
    /// to connect after registration. Valid range: 5-300 seconds.
    ///
    /// - Too short (<5s): May reject slow encoders or high-latency networks
    /// - Too long (>300s): Wastes resources waiting for dead connections
    /// - Default (30s): Balanced for most use cases
    pub timeout_seconds: Option<u32>,

    /// Parameters of the video decoder for H.264 video from the RTMP stream.
    /// If not specified, system auto-selects decoder (Vulkan if available, else FFmpeg).
    ///
    /// RTMP streams typically use H.264 (AVC) video codec. Other codecs are not supported.
    pub video: Option<InputRtmpVideoOptions>,

    /// (**default=`false`**) If input is required and the stream is not delivered
    /// on time, then Smelter will delay producing output frames.
    ///
    /// - `true`: Pipeline waits for this input before starting (blocking)
    /// - `false`: Pipeline starts immediately, input joins when available
    ///
    /// Default rationale: RTMP typically used for add-on inputs, not primary sources.
    pub required: Option<bool>,

    /// Offset in milliseconds relative to the pipeline start (start request).
    /// If not defined, stream will be synchronized based on RTMP timestamp delivery.
    ///
    /// Use case: Synchronizing multiple cameras with different network latencies.
    /// Example: If Camera 2 is 100ms behind Camera 1, set `offset_ms: 100.0` for Camera 2.
    pub offset_ms: Option<f64>,
}

/// Video decoder configuration for RTMP streams.
///
/// Allows users to specify decoder preference (hardware vs software).
/// If not specified, system auto-selects (Vulkan if GPU supports it, else FFmpeg).
#[derive(Debug, Serialize, Deserialize, Clone, JsonSchema)]
#[serde(deny_unknown_fields)]
pub struct InputRtmpVideoOptions {
    /// Preferred H.264 decoder.
    ///
    /// - `None`: Auto-select (Vulkan if available, else FFmpeg) - **recommended**
    /// - `FfmpegH264`: Force software decoder (CPU-based, universal compatibility)
    /// - `VulkanH264`: Force hardware decoder (GPU-accelerated, requires Vulkan Video support)
    ///
    /// # Decoder Selection
    ///
    /// **FFmpeg H.264** (Software):
    /// - Always available
    /// - CPU-based decoding (20-40% of 1 core per 1080p30 stream)
    /// - Universal compatibility
    /// - Use when: GPU unavailable or Vulkan not supported
    ///
    /// **Vulkan H.264** (Hardware):
    /// - Requires GPU with Vulkan Video decoding support
    /// - GPU-accelerated (5-10% CPU per stream, offloads to GPU)
    /// - 3-5x faster than software decoding
    /// - Platforms: Linux (NVIDIA 10xx+, AMD RX 5xx+, Intel Arc), Windows (NVIDIA/AMD)
    /// - Use when: Production environments with capable GPUs
    pub decoder: Option<RtmpVideoDecoderOptions>,
}

/// Supported H.264 decoders for RTMP input.
///
/// RTMP streams typically use H.264 (AVC) video codec. This enum allows
/// selecting between software (FFmpeg) and hardware (Vulkan) decoders.
#[derive(Debug, Serialize, Deserialize, Clone, Copy, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum RtmpVideoDecoderOptions {
    /// Software H264 decoder based on FFmpeg. Always available.
    /// Uses CPU for decoding. Lower performance but works everywhere.
    FfmpegH264,

    /// Hardware decoder using Vulkan Video. Requires GPU with Vulkan Video decoding support.
    /// Requires vk-video feature. Significantly faster than software decoding.
    /// Platforms: Linux (NVIDIA/AMD/Intel), Windows (NVIDIA/AMD).
    VulkanH264,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_rtmp_input_struct_creation() {
        let input = RtmpInput {
            port: 1935,
            stream_key: String::from("test-key"),
            timeout_seconds: None,
            video: None,
            required: None,
            offset_ms: None,
        };

        assert_eq!(input.port, 1935);
        assert_eq!(input.stream_key, "test-key");
        assert_eq!(input.timeout_seconds, None);
        assert!(input.video.is_none());
        assert_eq!(input.required, None);
        assert_eq!(input.offset_ms, None);
    }

    #[test]
    fn test_rtmp_input_with_video_options() {
        let input = RtmpInput {
            port: 1936,
            stream_key: String::from("production-stream"),
            timeout_seconds: Some(60),
            video: Some(InputRtmpVideoOptions {
                decoder: Some(RtmpVideoDecoderOptions::VulkanH264),
            }),
            required: Some(true),
            offset_ms: Some(150.0),
        };

        assert_eq!(input.port, 1936);
        assert_eq!(input.stream_key, "production-stream");
        assert_eq!(input.timeout_seconds, Some(60));
        assert!(input.video.is_some());
        assert_eq!(input.required, Some(true));
        assert_eq!(input.offset_ms, Some(150.0));
    }

    #[test]
    fn test_decoder_options_variants() {
        let ffmpeg = RtmpVideoDecoderOptions::FfmpegH264;
        let vulkan = RtmpVideoDecoderOptions::VulkanH264;

        // Just verify variants exist and can be created
        assert!(matches!(ffmpeg, RtmpVideoDecoderOptions::FfmpegH264));
        assert!(matches!(vulkan, RtmpVideoDecoderOptions::VulkanH264));
    }
}
