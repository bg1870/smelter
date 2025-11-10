use std::time::Duration;

use crate::common_core::prelude as core;
use crate::*;

impl TryFrom<RtmpInput> for core::RegisterInputOptions {
    type Error = TypeError;

    fn try_from(value: RtmpInput) -> Result<Self, Self::Error> {
        let RtmpInput {
            port,
            stream_key,
            timeout_seconds,
            video,
            required,
            offset_ms,
        } = value;

        // Validate port range (1024-65535)
        // Note: port is u16, so it's always <= 65535
        if port < 1024 {
            return Err(TypeError::new(
                "RTMP port must be between 1024 and 65535 (non-privileged ports). \
                 Ports below 1024 require root privileges and are not recommended for security reasons.",
            ));
        }

        // Validate stream_key is non-empty
        if stream_key.is_empty() {
            return Err(TypeError::new(
                "RTMP stream_key cannot be empty. \
                 Recommended: Use UUID or long random string for security.",
            ));
        }

        // Validate timeout_seconds if provided
        let timeout = timeout_seconds.unwrap_or(30);
        if timeout < 5 || timeout > 300 {
            return Err(TypeError::new(
                "RTMP timeout_seconds must be between 5 and 300. \
                 Values below 5 seconds are impractical for network latency. \
                 Values above 300 seconds waste resources on dead connections.",
            ));
        }

        // Convert video decoder options
        let video_decoders = core::RtmpInputVideoDecoders {
            h264: video.and_then(|v| {
                v.decoder.map(|decoder| match decoder {
                    RtmpVideoDecoderOptions::FfmpegH264 => core::VideoDecoderOptions::FfmpegH264,
                    RtmpVideoDecoderOptions::VulkanH264 => core::VideoDecoderOptions::VulkanH264,
                })
            }),
        };

        // Create RTMP input options with latency-optimized buffer (RTMP standard for low-latency)
        let input_options = core::ProtocolInputOptions::Rtmp(core::RtmpInputOptions {
            port,
            stream_key,
            buffer: core::InputBufferOptions::LatencyOptimized,
            video_decoders,
            timeout_seconds: timeout,
        });

        // Create queue options
        let queue_options = core::QueueInputOptions {
            required: required.unwrap_or(false),
            offset: offset_ms.map(|ms| Duration::from_secs_f64(ms / 1000.0)),
        };

        Ok(core::RegisterInputOptions {
            input_options,
            queue_options,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_try_from_minimal_rtmp_input() {
        let input = RtmpInput {
            port: 1935,
            stream_key: String::from("test-key"),
            timeout_seconds: None,
            video: None,
            required: None,
            offset_ms: None,
        };

        let result = core::RegisterInputOptions::try_from(input);
        assert!(result.is_ok());

        let options = result.unwrap();
        assert!(!options.queue_options.required);
        assert!(options.queue_options.offset.is_none());
    }

    #[test]
    fn test_try_from_full_rtmp_input() {
        let input = RtmpInput {
            port: 1936,
            stream_key: String::from("production-key"),
            timeout_seconds: Some(60),
            video: Some(InputRtmpVideoOptions {
                decoder: Some(RtmpVideoDecoderOptions::VulkanH264),
            }),
            required: Some(true),
            offset_ms: Some(100.0),
        };

        let result = core::RegisterInputOptions::try_from(input);
        assert!(result.is_ok());

        let options = result.unwrap();
        assert!(options.queue_options.required);
        assert_eq!(
            options.queue_options.offset,
            Some(Duration::from_millis(100))
        );
    }

    #[test]
    fn test_try_from_with_default_values() {
        let input = RtmpInput {
            port: 1935,
            stream_key: String::from("test-key"),
            timeout_seconds: None, // Should default to 30
            video: None,           // Should default to None (auto-select)
            required: None,        // Should default to false
            offset_ms: None,       // Should default to None
        };

        let result = core::RegisterInputOptions::try_from(input);
        assert!(result.is_ok());
    }

    #[test]
    fn test_try_from_invalid_port_too_low() {
        let input = RtmpInput {
            port: 80, // Invalid: below 1024
            stream_key: String::from("test-key"),
            timeout_seconds: None,
            video: None,
            required: None,
            offset_ms: None,
        };

        let result = core::RegisterInputOptions::try_from(input);
        assert!(result.is_err());
        let err_msg = result.unwrap_err().to_string();
        assert!(err_msg.contains("1024"));
        assert!(err_msg.contains("65535"));
    }

    // Note: Port validation for > 65535 is not needed because port is u16 (max value is 65535)

    #[test]
    fn test_try_from_empty_stream_key() {
        let input = RtmpInput {
            port: 1935,
            stream_key: String::from(""), // Invalid: empty
            timeout_seconds: None,
            video: None,
            required: None,
            offset_ms: None,
        };

        let result = core::RegisterInputOptions::try_from(input);
        assert!(result.is_err());
        let err_msg = result.unwrap_err().to_string();
        assert!(err_msg.contains("stream_key"));
        assert!(err_msg.contains("empty"));
    }

    #[test]
    fn test_try_from_invalid_timeout_too_low() {
        let input = RtmpInput {
            port: 1935,
            stream_key: String::from("test-key"),
            timeout_seconds: Some(2), // Invalid: below 5
            video: None,
            required: None,
            offset_ms: None,
        };

        let result = core::RegisterInputOptions::try_from(input);
        assert!(result.is_err());
        let err_msg = result.unwrap_err().to_string();
        assert!(err_msg.contains("timeout_seconds"));
        assert!(err_msg.contains("5"));
        assert!(err_msg.contains("300"));
    }

    #[test]
    fn test_try_from_invalid_timeout_too_high() {
        let input = RtmpInput {
            port: 1935,
            stream_key: String::from("test-key"),
            timeout_seconds: Some(500), // Invalid: above 300
            video: None,
            required: None,
            offset_ms: None,
        };

        let result = core::RegisterInputOptions::try_from(input);
        assert!(result.is_err());
        let err_msg = result.unwrap_err().to_string();
        assert!(err_msg.contains("timeout_seconds"));
        assert!(err_msg.contains("5"));
        assert!(err_msg.contains("300"));
    }

    #[test]
    fn test_decoder_conversion_ffmpeg() {
        let input = RtmpInput {
            port: 1935,
            stream_key: String::from("test-key"),
            timeout_seconds: None,
            video: Some(InputRtmpVideoOptions {
                decoder: Some(RtmpVideoDecoderOptions::FfmpegH264),
            }),
            required: None,
            offset_ms: None,
        };

        let result = core::RegisterInputOptions::try_from(input);
        assert!(result.is_ok());
    }

    #[test]
    fn test_decoder_conversion_vulkan() {
        let input = RtmpInput {
            port: 1935,
            stream_key: String::from("test-key"),
            timeout_seconds: None,
            video: Some(InputRtmpVideoOptions {
                decoder: Some(RtmpVideoDecoderOptions::VulkanH264),
            }),
            required: None,
            offset_ms: None,
        };

        let result = core::RegisterInputOptions::try_from(input);
        assert!(result.is_ok());
    }

    #[test]
    fn test_decoder_conversion_auto_select() {
        let input = RtmpInput {
            port: 1935,
            stream_key: String::from("test-key"),
            timeout_seconds: None,
            video: None, // Auto-select decoder
            required: None,
            offset_ms: None,
        };

        let result = core::RegisterInputOptions::try_from(input);
        assert!(result.is_ok());
    }

    #[test]
    fn test_offset_conversion() {
        let input = RtmpInput {
            port: 1935,
            stream_key: String::from("test-key"),
            timeout_seconds: None,
            video: None,
            required: None,
            offset_ms: Some(250.0), // 250ms offset
        };

        let result = core::RegisterInputOptions::try_from(input);
        assert!(result.is_ok());

        let options = result.unwrap();
        assert_eq!(
            options.queue_options.offset,
            Some(Duration::from_millis(250))
        );
    }
}
