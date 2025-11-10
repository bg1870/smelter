# Data Model: RTMP Input API Registration

**Feature**: 002-rtmp-api-input
**Date**: 2025-11-10

## Overview

This document defines the data structures for RTMP input registration at the API layer. The model follows the established pattern from other input types (RTP, WHIP, HLS) with user-friendly optional parameters that convert to core layer requirements.

## Entity Relationships

```
┌─────────────────────────┐
│     RtmpInput (API)     │  User-facing request structure
│─────────────────────────│
│ port: u16               │
│ stream_key: String      │
│ timeout_seconds: Option │
│ video: Option           │──┐
│ buffer: Option          │  │
│ required: Option        │  │
│ offset_ms: Option       │  │
└─────────────────────────┘  │
            │                │
            │ TryFrom        │
            ▼                │
┌─────────────────────────┐  │  ┌───────────────────────────┐
│ RegisterInputOptions    │  │  │ InputRtmpVideoOptions     │
│─────────────────────────│  └─▶│───────────────────────────│
│ input_options           │─────│ decoder: Option           │──┐
│ queue_options           │     └───────────────────────────┘  │
└─────────────────────────┘                                    │
            │                                                  │
            │ Contains                                         │
            ▼                                                  │
┌─────────────────────────┐     ┌───────────────────────────┐│
│ ProtocolInputOptions    │     │ RtmpVideoDecoderOptions   ││
│─────────────────────────│     │───────────────────────────││
│ Rtmp(RtmpInputOptions)  │────▶│ FfmpegH264                ││
└─────────────────────────┘  │  │ VulkanH264                ││
                             │  └───────────────────────────┘│
                             │                               │
                             │                               │
                             ▼                               │
                  ┌─────────────────────────┐                │
                  │  RtmpInputOptions (Core)│                │
                  │─────────────────────────│                │
                  │ port: u16               │                │
                  │ stream_key: String      │                │
                  │ buffer: InputBuffer...  │                │
                  │ video_decoders          │───┐            │
                  │ timeout_seconds: u32    │   │            │
                  └─────────────────────────┘   │            │
                                                │            │
                                                ▼            │
                              ┌──────────────────────────────┐│
                              │ RtmpInputVideoDecoders (Core)││
                              │──────────────────────────────││
                              │ h264: Option<VideoDecoder>   ││◀┘
                              └──────────────────────────────┘
```

## API Layer Entities

### RtmpInput

User-facing structure for registering RTMP input streams.

**Purpose**: Accept RTMP configuration from API users (REST API, SDK, etc.)

**Fields**:
- `port: u16` (required) - RTMP server listening port
  - Valid range: 1024-65535 (non-privileged ports)
  - Common values: 1935 (RTMP standard), 1936 (RTMPS)
  - Validation: Must not conflict with other registered inputs

- `stream_key: String` (required) - Authentication stream key
  - Format: Alphanumeric + hyphens/underscores
  - Purpose: Prevents unauthorized publishers
  - Validation: Must be non-empty
  - Best practice: UUID or long random string

- `timeout_seconds: Option<u32>` (optional, default: 30) - Connection timeout
  - Valid range: 5-300 seconds
  - Purpose: How long to wait for publisher to connect
  - Too short: Rejects slow encoders
  - Too long: Wastes resources on dead connections

- `video: Option<InputRtmpVideoOptions>` (optional, default: auto-select decoder) - Video decoding preferences
  - If None: System auto-selects decoder (Vulkan if available, else FFmpeg)
  - If Some: User specifies decoder preference

- `buffer: Option<InputBufferOptions>` (optional, default: LatencyOptimized) - Buffer configuration
  - LatencyOptimized: Minimal buffering for low latency
  - Const(Duration): Fixed buffer size
  - None: No buffering
  - Default rationale: RTMP typically used for low-latency streaming

- `required: Option<bool>` (optional, default: false) - Whether input is required
  - If true: Pipeline waits for this input before starting output
  - If false: Pipeline starts immediately, input joins when available
  - Default rationale: Most RTMP use cases are add-on inputs, not primary sources

- `offset_ms: Option<f64>` (optional, default: None) - Manual A/V sync offset
  - Value in milliseconds relative to pipeline start
  - If None: Auto-sync based on RTMP timestamp delivery
  - If Some: Manual offset for alignment with other inputs
  - Use case: Synchronizing multiple cameras with different latencies

**Serialization**: JSON via serde (deny_unknown_fields to catch typos)

**JSON Schema**: Generated via schemars for TypeScript SDK

**Example**:
```rust
RtmpInput {
    port: 1935,
    stream_key: String::from("abc123-secret-key"),
    timeout_seconds: Some(45),
    video: Some(InputRtmpVideoOptions {
        decoder: Some(RtmpVideoDecoderOptions::VulkanH264)
    }),
    buffer: Some(InputBufferOptions::LatencyOptimized),
    required: Some(false),
    offset_ms: Some(100.0),
}
```

**JSON Example**:
```json
{
  "port": 1935,
  "stream_key": "abc123-secret-key",
  "timeout_seconds": 45,
  "video": {
    "decoder": "vulkan_h264"
  },
  "buffer": "latency_optimized",
  "required": false,
  "offset_ms": 100.0
}
```

### InputRtmpVideoOptions

Video decoder configuration for RTMP streams.

**Purpose**: Allow users to specify decoder preference (hardware vs software)

**Fields**:
- `decoder: Option<RtmpVideoDecoderOptions>` - Preferred H.264 decoder
  - If None: Auto-select (Vulkan if GPU supports it, else FFmpeg)
  - If Some: Use specified decoder
  - Validation: Vulkan requires GPU with Vulkan Video support

**Structure**:
```rust
pub struct InputRtmpVideoOptions {
    pub decoder: Option<RtmpVideoDecoderOptions>,
}
```

**Rationale**: Wrapper struct allows future expansion (e.g., adding codec-specific parameters)

### RtmpVideoDecoderOptions

Enumeration of supported H.264 decoders for RTMP.

**Purpose**: Type-safe decoder selection

**Variants**:
- `FfmpegH264` - Software decoder (CPU-based, universal compatibility)
  - Always available
  - Lower performance but works everywhere
  - Use case: Environments without GPU or when Vulkan unavailable

- `VulkanH264` - Hardware decoder (GPU-accelerated)
  - Requires Vulkan Video decoding support
  - Higher performance, lower CPU usage
  - Use case: Production environments with capable GPUs
  - Platforms: Linux (NVIDIA/AMD/Intel), Windows (NVIDIA/AMD)

**Structure**:
```rust
pub enum RtmpVideoDecoderOptions {
    FfmpegH264,
    VulkanH264,
}
```

**Serialization**: snake_case JSON (e.g., "ffmpeg_h264", "vulkan_h264")

**Note**: Only H.264 supported in initial implementation (RTMP's primary video codec)

## Core Layer Entities

### RtmpInputOptions

Core layer configuration for RTMP input (already exists in `smelter-core/src/protocols/rtmp.rs`).

**Purpose**: Internal representation with all defaults resolved

**Structure**:
```rust
pub struct RtmpInputOptions {
    pub port: u16,
    pub stream_key: String,
    pub buffer: InputBufferOptions,
    pub video_decoders: RtmpInputVideoDecoders,
    pub timeout_seconds: u32,
}
```

**Field Mapping from API**:
- `port`: Direct copy from API
- `stream_key`: Direct copy from API
- `buffer`: API `buffer.unwrap_or(LatencyOptimized)`
- `video_decoders`: Constructed from API `video` field
- `timeout_seconds`: API `timeout_seconds.unwrap_or(30)`

### RtmpInputVideoDecoders

Core layer decoder configuration (already exists in `smelter-core/src/protocols/rtmp.rs`).

**Purpose**: Decoder options per codec type (extensible for future codecs)

**Structure**:
```rust
pub struct RtmpInputVideoDecoders {
    pub h264: Option<VideoDecoderOptions>,
}
```

**Mapping from API**:
- If API `video.decoder == Some(FfmpegH264)`: `h264 = Some(VideoDecoderOptions::FfmpegH264)`
- If API `video.decoder == Some(VulkanH264)`: `h264 = Some(VideoDecoderOptions::VulkanH264)`
- If API `video.decoder == None`: `h264 = None` (core auto-selects)

### RegisterInputOptions

Core layer unified input registration structure (already exists in `smelter-core/src/input.rs`).

**Purpose**: Wrap protocol-specific options with queue options

**Structure**:
```rust
pub struct RegisterInputOptions {
    pub input_options: ProtocolInputOptions,
    pub queue_options: QueueInputOptions,
}
```

**Components**:
- `input_options`: Protocol-specific (RtmpInputOptions wrapped in ProtocolInputOptions::Rtmp)
- `queue_options`: Universal options (`required`, `offset`)

### QueueInputOptions

Core layer queue/sync configuration (already exists in `smelter-core/src/input.rs`).

**Purpose**: Control input timing and synchronization

**Structure**:
```rust
pub struct QueueInputOptions {
    pub required: bool,
    pub offset: Option<Duration>,
}
```

**Mapping from API**:
- `required`: API `required.unwrap_or(false)`
- `offset`: API `offset_ms.map(|ms| Duration::from_secs_f64(ms / 1000.0))`

## Validation Rules

### Port Validation
- **Rule**: Must be in range 1024-65535
- **Rationale**: Ports <1024 require root privileges (security risk)
- **Error**: TypeError with message "RTMP port must be between 1024 and 65535"

### Stream Key Validation
- **Rule**: Must be non-empty string
- **Rationale**: Empty stream key allows unauthorized access
- **Error**: TypeError with message "RTMP stream_key cannot be empty"

### Timeout Validation
- **Rule**: If provided, must be in range 5-300 seconds
- **Rationale**: <5s is impractical for network latency, >300s is resource wasteful
- **Error**: TypeError with message "RTMP timeout_seconds must be between 5 and 300"

### Decoder Validation
- **Rule**: VulkanH264 requires Vulkan support (runtime check in core)
- **Rationale**: Prevent runtime errors from invalid decoder selection
- **Error**: InputInitError::DecoderError from core layer (not API layer)

### Conflict Validation
- **Rule**: Port must not be in use by another input
- **Rationale**: Only one listener per port
- **Error**: InputInitError from core layer when registering

## State Transitions

RTMP inputs have the following lifecycle:

```
┌─────────────┐
│  Unregistered│
└──────┬──────┘
       │ API request (RtmpInput)
       │ → TryFrom validation
       │ → Core registration
       ▼
┌─────────────┐
│  Listening  │ (RTMP server waiting for connection)
└──────┬──────┘
       │ Publisher connects (with stream_key)
       │ → Stream key validation
       │ → FFmpeg format detection
       ▼
┌─────────────┐
│  Connected  │ (Receiving RTMP packets)
└──────┬──────┘
       │ Stream demux & decode
       │ → Video frames to pipeline
       │ → Audio samples to pipeline
       ▼
┌─────────────┐
│  Streaming  │ (Active processing)
└──────┬──────┘
       │ Publisher disconnects or error
       │ → Send EOS to decoders
       │ → Cleanup resources
       ▼
┌─────────────┐
│  Closed     │
└─────────────┘
```

**Notes**:
- API layer only handles Unregistered → Listening transition
- Core layer handles all other transitions
- State is implicit (no explicit state machine in structs)

## Type Conversion Flow

```rust
// User provides JSON
{
  "port": 1935,
  "stream_key": "secret"
}

// Deserialized to RtmpInput (API)
RtmpInput {
    port: 1935,
    stream_key: "secret",
    timeout_seconds: None,  // Will use default: 30
    video: None,            // Will auto-select decoder
    buffer: None,           // Will use LatencyOptimized
    required: None,         // Will use false
    offset_ms: None,        // Will auto-sync
}

// TryFrom<RtmpInput> for RegisterInputOptions
RegisterInputOptions {
    input_options: ProtocolInputOptions::Rtmp(
        RtmpInputOptions {
            port: 1935,
            stream_key: "secret",
            timeout_seconds: 30,  // Default applied
            video_decoders: RtmpInputVideoDecoders {
                h264: None,  // Auto-select
            },
            buffer: InputBufferOptions::LatencyOptimized,  // Default
        }
    ),
    queue_options: QueueInputOptions {
        required: false,  // Default
        offset: None,     // Auto-sync
    },
}

// Core layer creates RtmpInput instance
// Spawns RTMP server on port 1935
// Waits for connection with stream_key="secret"
```

## Default Value Summary

| API Field | Default Value | Source |
|-----------|---------------|--------|
| `timeout_seconds` | 30 seconds | Common practice for network timeouts |
| `video.decoder` | None (auto-select) | Maximize compatibility, use best available |
| `buffer` | LatencyOptimized | RTMP is low-latency protocol |
| `required` | false | RTMP typically for add-on streams |
| `offset_ms` | None (auto-sync) | Trust RTMP timestamps |

## Extension Points

Future enhancements could add:

1. **Audio Decoder Selection**
   - Currently AAC is assumed (RTMP standard)
   - Could add `audio` field with codec options

2. **TLS Support (RTMPS)**
   - Add `tls` field with certificate configuration
   - Requires RTMP port 1936 and TLS setup

3. **Multiple Stream Keys**
   - Support array of stream keys for multi-user scenarios
   - Requires core layer changes for key validation

4. **Bandwidth Limits**
   - Add `max_bitrate_mbps` field
   - Prevent bandwidth exhaustion attacks

5. **Recording Options**
   - Add `record_to_file` field
   - Save raw RTMP stream to disk

**Note**: All extensions would maintain backward compatibility via optional fields.
