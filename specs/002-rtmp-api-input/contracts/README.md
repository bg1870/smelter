# API Contracts: RTMP Input Registration

**Feature**: 002-rtmp-api-input
**Date**: 2025-11-10

## Overview

This document defines the API contracts for RTMP input registration. The contracts follow the established smelter pattern where API types are defined in Rust with JSON schema generation for TypeScript SDK compatibility.

## Contract Generation

The API contracts are generated automatically from Rust code using:

```bash
# Generate JSON schema from Rust types
cargo run -p tools --bin generate_json_schema

# Generate TypeScript types from JSON schema
cd typescript-sdk
pnpm run generate-types
```

**Output**: `typescript-sdk/src/api.generated.ts` (contains TypeScript definitions)

## RtmpInput Contract

### Type Definition (Rust)

```rust
use schemars::JsonSchema;
use serde::{Deserialize, Serialize};

/// Parameters for an input stream from RTMP source.
#[derive(Debug, Serialize, Deserialize, Clone, JsonSchema)]
#[serde(deny_unknown_fields)]
pub struct RtmpInput {
    /// RTMP server listening port. Must be in range 1024-65535.
    /// Standard RTMP port is 1935.
    pub port: u16,

    /// Stream key for authentication. Publishers must connect to
    /// rtmp://host:PORT/live/STREAM_KEY with matching key.
    /// Must be non-empty. Recommended: Use UUID or long random string.
    pub stream_key: String,

    /// (**default=`30`**) Connection timeout in seconds. How long to wait
    /// for publisher to connect. Valid range: 5-300 seconds.
    pub timeout_seconds: Option<u32>,

    /// Parameters of the video decoder for H.264 video.
    pub video: Option<InputRtmpVideoOptions>,

    /// (**default=`LatencyOptimized`**) Buffer configuration for latency control.
    pub buffer: Option<InputBufferOptions>,

    /// (**default=`false`**) If input is required and the stream is not delivered
    /// on time, then Smelter will delay producing output frames.
    pub required: Option<bool>,

    /// Offset in milliseconds relative to the pipeline start (start request).
    /// If not defined, stream will be synchronized based on RTMP timestamp delivery.
    pub offset_ms: Option<f64>,
}

/// Video decoder options for RTMP streams.
#[derive(Debug, Serialize, Deserialize, Clone, JsonSchema)]
#[serde(deny_unknown_fields)]
pub struct InputRtmpVideoOptions {
    /// Preferred H.264 decoder. If not specified, system auto-selects
    /// (Vulkan if available, else FFmpeg).
    pub decoder: Option<RtmpVideoDecoderOptions>,
}

/// Supported H.264 decoders for RTMP input.
#[derive(Debug, Serialize, Deserialize, Clone, Copy, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum RtmpVideoDecoderOptions {
    /// Software H264 decoder based on FFmpeg. Always available.
    FfmpegH264,

    /// Hardware decoder. Requires GPU that supports Vulkan Video decoding.
    /// Requires vk-video feature. Platforms: Linux, Windows.
    VulkanH264,
}
```

### JSON Schema

Generated schema for `RtmpInput`:

```json
{
  "type": "object",
  "required": ["port", "stream_key"],
  "properties": {
    "port": {
      "type": "integer",
      "format": "uint16",
      "minimum": 1024,
      "maximum": 65535,
      "description": "RTMP server listening port"
    },
    "stream_key": {
      "type": "string",
      "minLength": 1,
      "description": "Stream key for authentication"
    },
    "timeout_seconds": {
      "type": "integer",
      "format": "uint32",
      "minimum": 5,
      "maximum": 300,
      "default": 30,
      "description": "Connection timeout in seconds"
    },
    "video": {
      "type": "object",
      "properties": {
        "decoder": {
          "type": "string",
          "enum": ["ffmpeg_h264", "vulkan_h264"],
          "description": "Preferred H.264 decoder"
        }
      }
    },
    "buffer": {
      "oneOf": [
        { "type": "string", "enum": ["latency_optimized", "none"] },
        {
          "type": "object",
          "properties": {
            "const": { "type": "number", "description": "Buffer duration in seconds" }
          }
        }
      ],
      "default": "latency_optimized"
    },
    "required": {
      "type": "boolean",
      "default": false,
      "description": "Whether pipeline waits for this input"
    },
    "offset_ms": {
      "type": "number",
      "description": "Manual A/V sync offset in milliseconds"
    }
  },
  "additionalProperties": false
}
```

### TypeScript Type (Generated)

```typescript
export interface RtmpInput {
  /** RTMP server listening port (1024-65535) */
  port: number;

  /** Stream key for authentication (non-empty) */
  stream_key: string;

  /** Connection timeout in seconds (default: 30, range: 5-300) */
  timeout_seconds?: number;

  /** Video decoder options */
  video?: InputRtmpVideoOptions;

  /** Buffer configuration (default: "latency_optimized") */
  buffer?: InputBufferOptions;

  /** Whether input is required (default: false) */
  required?: boolean;

  /** Manual A/V sync offset in milliseconds */
  offset_ms?: number;
}

export interface InputRtmpVideoOptions {
  /** Preferred H.264 decoder */
  decoder?: RtmpVideoDecoderOptions;
}

export type RtmpVideoDecoderOptions = "ffmpeg_h264" | "vulkan_h264";

export type InputBufferOptions =
  | "latency_optimized"
  | "none"
  | { const: number };
```

## Request Examples

### Minimal Request (Required Fields Only)

```json
{
  "port": 1935,
  "stream_key": "my-secret-key"
}
```

**Result**: RTMP server on port 1935, 30s timeout, auto-select decoder, latency-optimized buffering

### Full Request (All Fields Specified)

```json
{
  "port": 1936,
  "stream_key": "production-stream-abc123",
  "timeout_seconds": 60,
  "video": {
    "decoder": "vulkan_h264"
  },
  "buffer": "latency_optimized",
  "required": true,
  "offset_ms": 150.0
}
```

**Result**: RTMP server on port 1936, 60s timeout, Vulkan H.264 decoder, latency-optimized buffering, required input, 150ms offset

### Custom Buffer Request

```json
{
  "port": 1935,
  "stream_key": "buffered-stream",
  "buffer": { "const": 2.0 }
}
```

**Result**: RTMP server with 2-second fixed buffer (for unstable networks)

## Response Examples

### Success Response

When RTMP input is successfully registered:

```json
{
  "id": "input_rtmp_abc123",
  "type": "rtmp",
  "status": "listening",
  "rtmp_url": "rtmp://server.example.com:1935/live/my-secret-key",
  "timeout_seconds": 30
}
```

**Fields**:
- `id`: Unique input identifier
- `type`: Always "rtmp" for RTMP inputs
- `status`: "listening" (waiting for publisher) or "connected" (actively streaming)
- `rtmp_url`: Full RTMP URL for publisher to connect to
- `timeout_seconds`: Actual timeout value used

### Error Responses

#### Invalid Port

```json
{
  "error": "InvalidParameter",
  "message": "RTMP port must be between 1024 and 65535",
  "field": "port",
  "value": 80
}
```

#### Empty Stream Key

```json
{
  "error": "InvalidParameter",
  "message": "RTMP stream_key cannot be empty",
  "field": "stream_key"
}
```

#### Invalid Timeout

```json
{
  "error": "InvalidParameter",
  "message": "RTMP timeout_seconds must be between 5 and 300",
  "field": "timeout_seconds",
  "value": 500
}
```

#### Port Conflict

```json
{
  "error": "ResourceConflict",
  "message": "Port 1935 is already in use by another input",
  "field": "port",
  "conflicting_input_id": "input_rtmp_xyz789"
}
```

#### Decoder Not Available

```json
{
  "error": "DecoderUnavailable",
  "message": "Vulkan H.264 decoder requested but not supported on this system",
  "field": "video.decoder",
  "available_decoders": ["ffmpeg_h264"]
}
```

## Validation Rules

### Runtime Validation (API Layer)

Performed in `TryFrom<RtmpInput> for RegisterInputOptions`:

| Field | Rule | Error Message |
|-------|------|---------------|
| `port` | 1024 ≤ port ≤ 65535 | "RTMP port must be between 1024 and 65535" |
| `stream_key` | Non-empty string | "RTMP stream_key cannot be empty" |
| `timeout_seconds` | If provided: 5 ≤ timeout ≤ 300 | "RTMP timeout_seconds must be between 5 and 300" |

### Type Validation (Serde)

Performed during JSON deserialization:

- Unknown fields rejected (via `deny_unknown_fields`)
- Type mismatches rejected (e.g., string for port)
- Required fields missing rejected
- Enum variants validated (e.g., "vulkan_h264" must be exact)

### Core Layer Validation

Performed in `smelter-core` when creating RTMP input:

- Port availability (not already bound)
- Decoder availability (Vulkan requires GPU support)
- Stream key format (FFmpeg accepts it)

## Integration with Existing API

### Input Registration Endpoint

RTMP inputs are registered via the same endpoint as other input types:

**Endpoint**: `POST /api/inputs/register`

**Request Body**:
```json
{
  "type": "rtmp",
  "config": {
    "port": 1935,
    "stream_key": "my-key"
  }
}
```

**Alternative**: Type-discriminated union in Rust

```rust
pub enum InputConfig {
    Rtp(RtpInput),
    Rtmp(RtmpInput),
    Hls(HlsInput),
    Whip(WhipInput),
    // ...
}
```

**Note**: Actual endpoint design depends on existing smelter API implementation (not specified in this feature scope)

## SDK Usage Examples

### TypeScript SDK

```typescript
import { Smelter, RtmpInput } from 'smelter-sdk';

const smelter = new Smelter({ /* config */ });

// Minimal configuration
const rtmpInput: RtmpInput = {
  port: 1935,
  stream_key: 'my-stream-key',
};

// Full configuration
const advancedRtmpInput: RtmpInput = {
  port: 1936,
  stream_key: 'production-key-abc123',
  timeout_seconds: 45,
  video: {
    decoder: 'vulkan_h264',
  },
  buffer: 'latency_optimized',
  required: false,
  offset_ms: 100.0,
};

// Register input
const inputId = await smelter.registerInput('rtmp', rtmpInput);

console.log(`RTMP URL: rtmp://your-server:${rtmpInput.port}/live/${rtmpInput.stream_key}`);

// Publisher connects with OBS/FFmpeg to this URL
```

### Rust API (Direct)

```rust
use smelter_api::{RtmpInput, InputRtmpVideoOptions, RtmpVideoDecoderOptions};

let rtmp_config = RtmpInput {
    port: 1935,
    stream_key: String::from("my-stream-key"),
    timeout_seconds: Some(30),
    video: Some(InputRtmpVideoOptions {
        decoder: Some(RtmpVideoDecoderOptions::FfmpegH264),
    }),
    buffer: None, // Use default
    required: None, // Use default
    offset_ms: None, // Use default
};

// Convert to core options
let core_options = smelter_core::RegisterInputOptions::try_from(rtmp_config)?;

// Register with pipeline
pipeline.register_input(input_id, core_options)?;
```

## Backward Compatibility

### Schema Versioning

- Schema version tracked in generated `api.generated.ts`
- Breaking changes require MAJOR version bump
- New optional fields are backward compatible (MINOR version bump)

### Deprecation Strategy

If field needs to be deprecated:

1. Mark as deprecated in doc comments
2. Add deprecation warning in SDK
3. Maintain support for 2 MAJOR versions
4. Remove in 3rd MAJOR version

Example:
```rust
pub struct RtmpInput {
    /// @deprecated Use `timeout_seconds` instead. Will be removed in v3.0.0.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub timeout_ms: Option<u64>,

    /// Timeout in seconds (replaces deprecated timeout_ms)
    pub timeout_seconds: Option<u32>,
}
```

## Testing Contracts

### JSON Schema Validation

```bash
# Validate JSON schema is generated correctly
cargo run -p tools --bin generate_json_schema
git diff typescript-sdk/src/api.generated.ts

# No unexpected changes should appear
```

### TypeScript Compilation

```bash
# Ensure generated types compile
cd typescript-sdk
pnpm run build

# Should compile without errors
```

### Contract Tests

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_rtmp_input_minimal_json() {
        let json = r#"{"port": 1935, "stream_key": "test"}"#;
        let input: RtmpInput = serde_json::from_str(json).unwrap();
        assert_eq!(input.port, 1935);
        assert_eq!(input.stream_key, "test");
        assert_eq!(input.timeout_seconds, None); // Default applied in conversion
    }

    #[test]
    fn test_rtmp_input_full_json() {
        let json = r#"{
            "port": 1936,
            "stream_key": "secret",
            "timeout_seconds": 60,
            "video": {"decoder": "vulkan_h264"},
            "buffer": "latency_optimized",
            "required": true,
            "offset_ms": 150.0
        }"#;
        let input: RtmpInput = serde_json::from_str(json).unwrap();
        assert_eq!(input.port, 1936);
        assert_eq!(input.timeout_seconds, Some(60));
    }

    #[test]
    fn test_rtmp_input_unknown_field_rejected() {
        let json = r#"{"port": 1935, "stream_key": "test", "unknown": "value"}"#;
        let result: Result<RtmpInput, _> = serde_json::from_str(json);
        assert!(result.is_err()); // deny_unknown_fields
    }
}
```

## References

- JSON Schema Spec: https://json-schema.org/specification.html
- Serde Documentation: https://serde.rs/
- Schemars Documentation: https://docs.rs/schemars/
- TypeScript Handbook: https://www.typescriptlang.org/docs/handbook/
- Existing contracts: `smelter-api/src/input/{rtp.rs, whip.rs, hls.rs}`
