# API Contracts: RTMP Input Pipeline

**Feature**: RTMP Input Pipeline
**Branch**: 001-rtmp-input-pipeline
**Date**: 2025-11-10

## Status: No Public API Changes Required (Initial Implementation)

### Rationale

The initial RTMP input implementation is **library-level functionality** within `smelter-core`. It follows the existing pattern of HLS input, which is also library-internal.

**No changes required to**:
- `smelter-api` types
- TypeScript SDK (`api.generated.ts`)
- OpenAPI schema
- JSON schema

### Internal Rust API

RTMP input is consumed via the same `Input` enum pattern as other input types:

```rust
// smelter-core/src/input.rs
pub enum Input {
    Hls(HlsInput),
    Rtmp(RtmpInput),  // NEW variant
    WhipWhep(/* ... */),
    // ... other variants
}

// Public API (library consumers)
pub fn register_pipeline_input<F>(
    pipeline: &Pipeline,
    input_id: InputId,
    queue_options: QueueOptions,
    factory: F,
) -> Result<(), InputInitError>
where
    F: FnOnce(&Arc<PipelineCtx>, &InputId) -> Result<(Input, QueueDataReceiver), InputInitError>;
```

### Usage Pattern

```rust
use smelter_core::{RtmpInput, RtmpInputOptions, Input};

let (input, _, receivers) = RtmpInput::new_input(ctx, input_id, options)?;

register_pipeline_input(
    &pipeline,
    input_id,
    queue_options,
    |_, _| Ok((Input::Rtmp(input), receivers)),
)?;
```

This matches the existing HLS pattern exactly.

---

## Future API Exposure (Post-MVP)

If RTMP input configuration needs to be exposed via HTTP API (for runtime configuration), the following changes would be required:

### 1. smelter-api Types

```rust
// smelter-api/src/types/input.rs
#[derive(Serialize, Deserialize)]
pub struct RtmpInputConfig {
    pub port: u16,
    pub stream_key: String,
    pub buffer_ms: u32,
    pub timeout_seconds: u32,
}

#[derive(Serialize, Deserialize)]
#[serde(tag = "type")]
pub enum InputConfig {
    Hls { url: String },
    Rtmp(RtmpInputConfig),  // NEW
    Whip { endpoint_id: String },
    // ...
}
```

### 2. HTTP API Endpoint

```
POST /api/inputs
{
  "type": "Rtmp",
  "port": 1935,
  "stream_key": "my-stream",
  "buffer_ms": 500,
  "timeout_seconds": 30
}
```

### 3. TypeScript SDK Update

```typescript
// Generated from JSON schema
interface RtmpInputConfig {
  type: "Rtmp";
  port: number;
  stream_key: string;
  buffer_ms: number;
  timeout_seconds: number;
}

type InputConfig = HlsInputConfig | RtmpInputConfig | WhipInputConfig | /* ... */;
```

### 4. Schema Generation

Run schema generation commands:
```bash
cargo run -p tools --bin generate_json_schema
cd typescript-sdk && pnpm run generate-types
```

### 5. Documentation Updates

- OpenAPI spec in `smelter-api/openapi.yaml`
- TypeScript SDK README
- Migration guide if breaking changes

---

## Constitution Check: API Compatibility

From `.specify/memory/constitution.md`, Principle III:

> API changes MUST land in the same PR for both Rust and TypeScript

**Current Status**: N/A - No API changes in initial implementation ✅

**Future**: If HTTP API exposure is added, Rust + TypeScript changes must be in same PR with schema regeneration.

---

## Internal Contract Documentation

For library consumers (Rust crates depending on smelter-core):

### RtmpInput::new_input

```rust
pub fn new_input(
    ctx: Arc<PipelineCtx>,
    input_id: InputId,
    opts: RtmpInputOptions,
) -> Result<(Input, InputInitInfo, QueueDataReceiver), InputInitError>
```

**Parameters**:
- `ctx`: Pipeline context (shared across inputs/outputs)
- `input_id`: Unique identifier for this input
- `opts`: RTMP-specific configuration

**Returns**:
- `Input`: Input enum variant for registration
- `InputInitInfo`: Initialization metadata
- `QueueDataReceiver`: Channels for decoded video/audio frames

**Errors**:
- `InputInitError::FfmpegError`: FFmpeg initialization failed (port in use, invalid config)
- `InputInitError::CodecUnsupported`: Stream uses unsupported codec
- `InputInitError::AuthenticationFailed`: Stream key validation failed

**Thread Safety**: Safe to call from any thread. Creates background threads for demuxing/decoding.

### RtmpInputOptions

```rust
pub struct RtmpInputOptions {
    pub port: u16,                         // RTMP port (1024-65535)
    pub stream_key: String,                // Expected stream key (non-empty)
    pub buffer: InputBufferOptions,        // Buffer configuration
    pub video_decoders: VideoDecodersConfig, // H.264 decoder selection
    pub timeout_seconds: u32,              // Connection timeout (5-300)
}
```

**Validation**: Performed in `new_input`, returns `InputInitError` if invalid.

### Drop Behavior

```rust
impl Drop for RtmpInput {
    fn drop(&mut self) {
        // Sets atomic flag, triggers FFmpeg interrupt
        // Decoder threads receive EOS and terminate
        // Cleanup completes within 10 seconds
    }
}
```

**Cleanup Guarantee**: Resources released within 10 seconds (per spec SC-005).

---

## Integration Testing

No HTTP API tests needed initially. Integration tests use Rust API directly:

```rust
#[test]
fn test_rtmp_input_library_api() {
    let ctx = Arc::new(PipelineCtx::new(PipelineOptions::default()).unwrap());

    let options = RtmpInputOptions {
        port: 1935,
        stream_key: "test-key".into(),
        buffer: InputBufferOptions::default_rtmp(),
        video_decoders: VideoDecodersConfig::default(),
        timeout_seconds: 30,
    };

    let (input, _, receivers) = RtmpInput::new_input(
        ctx.clone(),
        InputId::from("test-input"),
        options,
    ).unwrap();

    // Assert receivers are created
    assert!(receivers.video.is_some());
    assert!(receivers.audio.is_some());

    // Cleanup
    drop(input);
}
```

---

## Summary

**Phase 1 (Current)**:
- ✅ No smelter-api changes
- ✅ No TypeScript SDK changes
- ✅ Library-level Rust API only
- ✅ Follows HLS input pattern
- ✅ Constitution compliance (no API sync needed)

**Phase 2 (Future - If HTTP API Needed)**:
- Add `RtmpInputConfig` to smelter-api
- Update HTTP endpoints
- Regenerate TypeScript types
- Update OpenAPI spec
- Single PR with Rust + TypeScript changes

**Current Deliverable**: Internal Rust API contracts documented ✅
