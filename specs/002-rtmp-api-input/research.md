# Research: RTMP Input API Registration

**Feature**: 002-rtmp-api-input
**Date**: 2025-11-10
**Status**: Complete

## Overview

This document captures research findings for implementing RTMP input registration at the smelter-api layer. Since the core RTMP implementation already exists and is functional, the primary research focus is on API design patterns and parameter mapping.

## Decision: API Structure Pattern

**Chosen**: Follow the established RTP/WHIP/HLS input pattern with separate struct and conversion files.

**Rationale**:
- Consistency with existing codebase (12+ existing input types all use this pattern)
- Clear separation of concerns: `rtmp.rs` for API types, `rtmp_into.rs` for core conversion
- Enables independent evolution of API and core layers
- Simplifies code review and maintenance (developers know where to find what)

**Alternatives Considered**:

1. **Single file for struct + conversion**
   - Rejected: Violates established pattern, makes files too large
   - All existing inputs use two-file pattern

2. **Embedded conversion as method on struct**
   - Rejected: TryFrom trait is idiomatic Rust for fallible conversions
   - Existing codebase uses TryFrom consistently

## Decision: Parameter Mapping Strategy

**Chosen**: Direct 1:1 mapping from API RtmpInput to core RtmpInputOptions with optional wrapper for decoder preferences.

**Core Layer Structure** (from `smelter-core/src/protocols/rtmp.rs`):
```rust
pub struct RtmpInputOptions {
    pub port: u16,
    pub stream_key: String,
    pub buffer: InputBufferOptions,
    pub video_decoders: RtmpInputVideoDecoders,
    pub timeout_seconds: u32,
}

pub struct RtmpInputVideoDecoders {
    pub h264: Option<VideoDecoderOptions>,
}
```

**API Layer Structure** (to be created):
```rust
pub struct RtmpInput {
    pub port: u16,
    pub stream_key: String,
    pub timeout_seconds: Option<u32>,
    pub video: Option<InputRtmpVideoOptions>,
    pub buffer: Option<InputBufferOptions>,
    pub required: Option<bool>,
    pub offset_ms: Option<f64>,
}

pub struct InputRtmpVideoOptions {
    pub decoder: Option<RtmpVideoDecoderOptions>,
}

pub enum RtmpVideoDecoderOptions {
    FfmpegH264,
    VulkanH264,
}
```

**Rationale**:
- API layer provides user-friendly optional parameters with sensible defaults
- Core layer uses concrete values (non-optional) for internal processing
- Conversion layer (`rtmp_into.rs`) handles default value application and validation
- Matches patterns from RTP (has decoder options) and WHIP (has bearer_token)

**Key Mappings**:
| API Field | Core Field | Default/Conversion |
|-----------|------------|-------------------|
| `port` | `port` | Direct copy (required) |
| `stream_key` | `stream_key` | Direct copy (required) |
| `timeout_seconds` | `timeout_seconds` | Default: 30 |
| `video.decoder` | `video_decoders.h264` | Default: None (auto-select) |
| `buffer` | `buffer` | Default: LatencyOptimized |
| `required` | (QueueInputOptions) | Default: false |
| `offset_ms` | (QueueInputOptions) | Default: None |

**Alternatives Considered**:

1. **Expose all core fields directly at API level**
   - Rejected: Overwhelming for basic use cases, reduces API flexibility to change defaults

2. **Use presets instead of individual parameters**
   - Rejected: Less flexible, doesn't match existing API patterns

## Decision: Validation Strategy

**Chosen**: Validate critical parameters in conversion logic (TryFrom), return TypeError for violations.

**Validation Rules**:
- `port`: Must be in range 1024-65535 (standard non-privileged port range)
- `stream_key`: Must be non-empty string
- `timeout_seconds`: If specified, must be 5-300 seconds (reasonable bounds)
- `decoder`: Must be valid enum variant (type system enforces this)

**Rationale**:
- Early validation catches user errors before hitting core layer
- TypeError provides actionable error messages
- Port range validation prevents privilege escalation issues (ports <1024 require root)
- Timeout bounds prevent infinite waits or sub-second timeouts (impractical for RTMP)

**Reference Implementation** (from `rtp_into.rs`):
```rust
impl TryFrom<RtpInput> for core::RegisterInputOptions {
    type Error = TypeError;

    fn try_from(value: RtpInput) -> Result<Self, Self::Error> {
        // Validation + conversion logic
        if video.is_none() && audio.is_none() {
            return Err(TypeError::new("At least one of video/audio required"));
        }
        // ... more conversion
    }
}
```

**Alternatives Considered**:

1. **Validate in core layer only**
   - Rejected: API layer should provide immediate feedback, reduces core layer coupling

2. **Use builder pattern for validation**
   - Rejected: Overengineered for simple struct conversion, doesn't match existing patterns

## Decision: RTMP URL Format

**Chosen**: Document expected URL format but do not construct URLs in API layer.

**Expected Format**: `rtmp://host:PORT/live/STREAM_KEY`
- `PORT`: From `port` parameter
- `STREAM_KEY`: From `stream_key` parameter
- `/live/`: Hardcoded application path (matches core implementation)

**Rationale**:
- URL construction happens in core layer (already implemented in `rtmp_input.rs:482`)
- API layer only provides parameters, not URLs
- Simplifies API (users don't need to understand URL escaping, just provide stream key)
- Documentation in quickstart.md will show full URLs for clarity

**Core Implementation Reference** (`smelter-core/src/pipeline/rtmp/rtmp_input.rs`):
```rust
let url = format!("rtmp://0.0.0.0:{}/live/{}", port, stream_key);
```

**Alternatives Considered**:

1. **Accept full RTMP URL at API layer**
   - Rejected: More complex to validate, requires URL parsing, easy to misconfigure

2. **Make application path (`/live/`) configurable**
   - Rejected: Not needed for initial implementation, can add later if required

## Decision: Buffer Configuration

**Chosen**: Expose `buffer` parameter as optional, default to `LatencyOptimized` for RTMP use case.

**Rationale**:
- RTMP is typically used for low-latency live streaming (vs HLS which tolerates higher latency)
- `LatencyOptimized` buffer mode minimizes glass-to-glass latency
- Users can override for specific use cases (e.g., buffering for unstable networks)
- Matches WHIP input pattern (also used for low-latency)

**Buffer Options** (from `smelter-core/src/utils/input_buffer.rs`):
- `LatencyOptimized`: Minimal buffering
- `Const(Option<Duration>)`: Fixed buffer size
- `None`: No buffering

**Reference** (from `whip_into.rs:29`):
```rust
buffer: core::InputBufferOptions::LatencyOptimized,
```

**Alternatives Considered**:

1. **Always use fixed 1-second buffer**
   - Rejected: Introduces unnecessary latency for default use case

2. **No buffer option at API layer**
   - Rejected: Reduces flexibility for advanced users

## Decision: Required Field and Offset

**Chosen**: Include `required` and `offset_ms` fields for consistency with other input types.

**Rationale**:
- These are QueueInputOptions fields present in all input types
- `required`: Determines if pipeline waits for this input before starting (default: false for RTMP)
- `offset_ms`: Allows manual A/V sync adjustments (default: None, auto-sync based on timestamps)
- Omitting would break API consistency

**Conversion** (same pattern as RTP):
```rust
let queue_options = smelter_core::QueueInputOptions {
    required: required.unwrap_or(false),
    offset: offset_ms.map(|offset_ms| Duration::from_secs_f64(offset_ms / 1000.0)),
};
```

## Best Practices: RTMP Streaming

Research into RTMP streaming best practices to inform API defaults and documentation:

### Port Selection
- **Standard**: Port 1935 (official RTMP port)
- **Alternative**: Port 1936 (RTMPS - RTMP over TLS, not implemented in this feature)
- **Development**: Any non-privileged port (1024-65535)
- **Firewall**: RTMP port must be open in firewall rules

### Stream Key Security
- **Purpose**: Prevents unauthorized publishers from hijacking streams
- **Best Practices**:
  - Use long, random strings (UUID recommended)
  - Rotate stream keys periodically
  - Don't expose in client-side code or logs
  - Consider per-user or per-session keys
- **Format**: Alphanumeric, hyphens/underscores allowed, no spaces or special chars

### Timeout Configuration
- **Connection timeout**: 30 seconds (default) - time to wait for publisher to connect
- **Too short (<5s)**: May reject slow encoders or high-latency networks
- **Too long (>300s)**: Wastes resources waiting for dead connections
- **Use case specific**: Increase for satellite uplinks, decrease for local networks

### Encoder Compatibility
- **OBS Studio**: Default RTMP output settings work out-of-box
- **FFmpeg**: Use `-f flv` format, `-c:v libx264 -c:a aac`
- **Hardware Encoders**: Most support RTMP with H.264/AAC (compatible)
- **Codec Requirements**: H.264 (AVC) video, AAC audio (per spec constraints)

### Performance Considerations
- **Bitrate**: 2-6 Mbps typical for 1080p30, 4-10 Mbps for 1080p60
- **Keyframe interval**: 2 seconds recommended (enables fast startup)
- **CBR vs VBR**: Constant bitrate (CBR) preferred for live streaming
- **Network**: Stable upload bandwidth critical (spikes cause buffer issues)

## Integration Points

### JSON Schema Generation
- Run `cargo run -p tools --bin generate_json_schema` after adding RtmpInput
- This generates TypeScript types in SDK: `api.generated.ts`
- Ensures Rust API and TypeScript SDK stay in sync

### TypeScript SDK
- Run `pnpm run generate-types` to update TypeScript definitions
- Developers can then use RtmpInput in type-safe manner
- Example:
  ```typescript
  const rtmpInput: RtmpInput = {
    port: 1935,
    stream_key: "my-stream-key",
    timeout_seconds: 30
  };
  ```

### Testing Strategy
- **Unit tests**: TryFrom conversion logic (valid params, invalid params, defaults)
- **Integration tests**: Optional - full end-to-end RTMP streaming test
  - Can leverage existing RTMP core tests (already functional)
  - Use FFmpeg to publish test stream, verify reception
- **Contract tests**: JSON schema validation ensures API contract stability

## References

- Existing implementations: `smelter-api/src/input/{rtp.rs, rtp_into.rs, whip.rs, whip_into.rs}`
- Core RTMP: `smelter-core/src/pipeline/rtmp/rtmp_input.rs`
- Core options: `smelter-core/src/protocols/rtmp.rs`
- RTMP specification: RTMP specification v1.0 (Adobe)
- FFmpeg RTMP: https://ffmpeg.org/ffmpeg-protocols.html#rtmp

## Open Questions

None - All technical decisions resolved through analysis of existing codebase and RTMP domain knowledge.
