# Data Model: RTMP Input Pipeline

**Date**: 2025-11-10
**Feature**: RTMP Input Pipeline
**Branch**: 001-rtmp-input-pipeline

## Overview

This document defines the key entities and data structures for the RTMP input implementation. The design follows the proven HLS input pattern with RTMP-specific adaptations.

---

## 1. RtmpInput

**Description**: Main input structure managing RTMP stream lifecycle.

**Structure**:
```rust
pub struct RtmpInput {
    should_close: Arc<AtomicBool>,
}
```

**Fields**:
- `should_close`: Atomic flag for graceful shutdown signal

**Relationships**:
- Creates `FfmpegInputContext` (FFmpeg demuxer)
- Spawns decoder threads via `AudioDecoderThread` and `VideoDecoderThread`
- Integrates with `PipelineCtx`

**Lifecycle**:
1. Created via `new_input()`
2. Spawns FFmpeg demuxer thread
3. Spawns audio/video decoder threads
4. Runs until stream disconnects or Drop called
5. Drop sets `should_close` → triggers cleanup

**Pattern Source**: Identical to `HlsInput` (hls_input.rs:45-47)

---

## 2. RtmpInputOptions

**Description**: Configuration for RTMP input creation.

**Structure**:
```rust
pub struct RtmpInputOptions {
    pub port: u16,
    pub stream_key: String,
    pub buffer: InputBufferOptions,
    pub video_decoders: VideoDecodersConfig,
    pub timeout_seconds: u32,
}
```

**Fields**:
- `port`: RTMP listening port (default 1935)
- `stream_key`: Expected stream key for authentication
- `buffer`: Buffer configuration (lower latency than HLS)
- `video_decoders`: H.264 decoder selection (FFmpeg or Vulkan)
- `timeout_seconds`: Connection timeout (default 30)

**Default Values**:
```rust
impl Default for RtmpInputOptions {
    fn default() -> Self {
        Self {
            port: 1935,  // Standard RTMP port
            stream_key: String::new(),  // Must be set by user
            buffer: InputBufferOptions {
                buffer_duration: Duration::from_millis(500),  // Low latency
                min_buffering: Duration::from_millis(100),
                max_buffering: Duration::from_secs(2),
            },
            video_decoders: VideoDecodersConfig::default(),
            timeout_seconds: 30,
        }
    }
}
```

**Validation Rules**:
- `port`: 1024-65535 (avoid privileged ports < 1024)
- `stream_key`: Non-empty, alphanumeric + dash/underscore
- `timeout_seconds`: 5-300 seconds

---

## 3. Track (Reused from HLS)

**Description**: Represents audio or video track being decoded.

**Structure** (from hls_input.rs:49-53):
```rust
struct Track {
    index: usize,
    handle: DecoderThreadHandle,
    state: StreamState,
}
```

**Fields**:
- `index`: FFmpeg stream index
- `handle`: Decoder thread handle (Audio or Video)
- `state`: Discontinuity detection and PTS tracking

**Relationships**:
- Owned by demuxer thread
- Sends packets to decoder via `DecoderThreadHandle`

**No RTMP-Specific Changes**: Structure identical to HLS usage

---

## 4. StreamState (Reused)

**Description**: Tracks stream timing and discontinuities.

**Usage** (from HLS): Detects PTS jumps, handles wraparound, manages timing.

**No RTMP-Specific Changes**: RTMP timestamps handled identically by FFmpeg FLV demuxer.

---

## 5. FfmpegInputContext (Enhanced)

**Description**: Wrapper around FFmpeg AVFormatContext for RTMP server.

**New Method**:
```rust
impl FfmpegInputContext {
    pub fn new_rtmp_server(
        port: u16,
        stream_key: &str,
        should_close: Arc<AtomicBool>,
        timeout_seconds: u32,
    ) -> Result<Self, InputInitError> {
        let url = format!("rtmp://0.0.0.0:{}/live/{}", port, stream_key);

        let ctx = input_with_dictionary_and_interrupt(
            &url,
            Dictionary::from_iter([
                ("listen", "1"),  // RTMP server mode
                ("timeout", &timeout_seconds.to_string()),
                ("rtmp_live", "live"),
                ("rtmp_buffer", "1000"),  // 1 second buffer
                ("probesize", "32768"),  // Fast stream detection
                ("analyzeduration", "500000"),  // 0.5s analysis
                ("fflags", "nobuffer"),
            ]),
            move || should_close.load(Ordering::Relaxed),
        )?;

        Ok(Self { ctx })
    }
}
```

**Key Differences from HLS**:
- URL format: `rtmp://0.0.0.0:PORT/live/STREAM_KEY`
- Dictionary options: RTMP-specific (`listen=1`, `rtmp_live`, `rtmp_buffer`)
- Behavior: Blocks until client connects (vs HLS immediate open)

---

## 6. DecoderThreadHandle (Reused)

**Description**: Handle to audio or video decoder thread.

**Variants**:
```rust
pub enum DecoderThreadHandle {
    Audio(AudioDecoderThreadHandle),
    Video(VideoDecoderThreadHandle),
}
```

**No RTMP-Specific Changes**: Identical usage to HLS

---

## 7. Input Enum Integration

**Description**: Add RTMP variant to existing Input enum.

**Modification** (input.rs):
```rust
pub enum Input {
    Hls(HlsInput),
    Rtmp(RtmpInput),  // NEW
    WhipWhep(/* ... */),
    // ... other variants
}
```

**Pattern**: Consistent with other input types

---

## 8. RTMP Connection Metadata (Internal)

**Description**: Information extracted from RTMP stream (not exposed as public struct initially).

**Data**:
- Codec types (H.264, AAC)
- Video resolution (width × height)
- Frame rate (from FLV metadata)
- Audio sample rate, channels
- Bitrate (if available in FLV metadata)

**Source**: Extracted from `AVStream` after `avformat_find_stream_info`

**Usage**: Passed to decoder thread initialization

---

## Entity Relationships

```
RtmpInput
  │
  ├──> FfmpegInputContext (FFmpeg demuxer)
  │      │
  │      ├──> audio_stream() → AVStream
  │      └──> video_stream() → AVStream
  │
  ├──> Track (Audio)
  │      ├──> DecoderThreadHandle::Audio
  │      │      └──> AudioDecoderThread<FdkAacDecoder>
  │      │             └──> Receiver<AudioSamples>
  │      └──> StreamState
  │
  └──> Track (Video)
         ├──> DecoderThreadHandle::Video
         │      └──> VideoDecoderThread<FfmpegH264Decoder | VulkanH264Decoder>
         │             └──> Receiver<VideoFrame>
         └──> StreamState

PipelineCtx
  └──> RtmpInput (via register_pipeline_input)
         └──> QueueDataReceiver { video, audio }
```

---

## State Transitions

### RtmpInput Lifecycle

```
┌─────────────┐
│  Creating   │ ← RtmpInput::new_input() called
└──────┬──────┘
       │ FfmpegInputContext::new_rtmp_server()
       │ (blocks until RTMP client connects)
       ▼
┌─────────────┐
│  Connected  │ ← Client performed RTMP handshake
└──────┬──────┘
       │ Stream key validation
       │ avformat_find_stream_info()
       ▼
┌─────────────┐
│   Streaming │ ← Demuxer thread reading packets
│             │ ← Decoder threads processing
└──────┬──────┘
       │ Client disconnect, timeout, or manual close
       ▼
┌──────────────┐
│ Disconnecting│ ← should_close set, av_read_frame returns EOF
└──────┬───────┘
       │ Channels closed, decoders receive EOS
       ▼
┌─────────────┐
│   Closed    │ ← Threads terminated, resources released
└─────────────┘
```

### Connection States (FFmpeg Internal)

```
Listen → Handshake → Metadata → Streaming → EOF/Error → Cleanup
```

---

## Data Flow

```
RTMP Client (OBS/FFmpeg)
  │
  │ RTMP protocol (TCP 1935)
  ▼
FFmpeg listen mode
  │ RTMP handshake, chunk parsing
  │ FLV demuxing
  ▼
AVStream (audio & video)
  │ H.264 (AVCC) + AAC
  │
  ├──> Demuxer Thread
  │      │ av_read_frame() loop
  │      │
  │      ├──> Audio Track
  │      │      └──> AudioDecoderThread
  │      │             └──> decoded AudioSamples
  │      │                    └──> Pipeline Queue
  │      │
  │      └──> Video Track
  │             └──> VideoDecoderThread
  │                    └──> decoded VideoFrame
  │                           └──> Pipeline Queue
  │
  └──> Disconnect Detection
         └──> Cleanup (Drop)
```

---

## Codec Data Formats

### H.264 (Video)

**RTMP/FLV Format**: AVCC (AVC1)
- Length-prefixed NAL units
- SPS/PPS in `extradata`
- Example: `[00 00 00 2A] [67 42 C0 1E ...]` (length + NALU)

**Decoder Input**: Annex B (converted by `AvccToAnnexBRepacker`)
- Start codes (`00 00 00 01`)
- Example: `[00 00 00 01] [67 42 C0 1E ...]`

**Conversion**: Automatic (existing infrastructure from HLS)

### AAC (Audio)

**RTMP/FLV Format**: Raw AAC frames
- AudioSpecificConfig in `extradata`
- No ADTS headers

**Decoder Input**: Same (FDK-AAC accepts raw AAC)

---

## Memory Ownership

### Reference Counting (Arc)

- `PipelineCtx`: `Arc` (shared across all inputs/outputs)
- `AtomicBool` (`should_close`): `Arc` (shared with demuxer thread)
- `InputBuffer`: `Arc` (shared between demuxer and decoders)

### Move Semantics

- `FfmpegInputContext`: Moved into demuxer thread
- `DecoderThreadHandle`: Owned by `Track` struct
- `Receiver<AudioSamples>`, `Receiver<VideoFrame>`: Moved to pipeline

### Thread Safety

- `Arc<AtomicBool>`: Lock-free atomic operations
- `Receiver` (crossbeam): Thread-safe channel
- No explicit locks needed (message passing architecture)

---

## Validation & Error Handling

### Stream Key Validation

```rust
fn validate_stream_key(url: &str, expected: &str) -> Result<(), AuthError> {
    let actual = url.split('/').last().ok_or(AuthError::MissingKey)?;
    if actual != expected {
        return Err(AuthError::InvalidKey(actual.to_string()));
    }
    Ok(())
}
```

### Codec Validation

**Supported**:
- Video: H.264 (AVC1)
- Audio: AAC

**Unsupported** (return error):
- Video: VP8, VP9, HEVC (reject connection)
- Audio: MP3, Opus (reject connection)

**Validation Point**: After `avformat_find_stream_info()`

---

## Configuration Examples

### Low Latency Configuration

```rust
RtmpInputOptions {
    port: 1935,
    stream_key: "low-latency-stream".into(),
    buffer: InputBufferOptions {
        buffer_duration: Duration::from_millis(200),  // Minimal buffering
        min_buffering: Duration::from_millis(50),
        max_buffering: Duration::from_millis(500),
    },
    video_decoders: VideoDecodersConfig {
        h264: Some(VideoDecoderOptions::VulkanH264),  // Hardware decode
    },
    timeout_seconds: 10,  // Short timeout for low latency
}
```

### High Quality Configuration

```rust
RtmpInputOptions {
    port: 1935,
    stream_key: "high-quality-stream".into(),
    buffer: InputBufferOptions {
        buffer_duration: Duration::from_secs(2),  // More buffering
        min_buffering: Duration::from_millis(500),
        max_buffering: Duration::from_secs(5),
    },
    video_decoders: VideoDecodersConfig {
        h264: Some(VideoDecoderOptions::FfmpegH264),  // Software decode (quality)
    },
    timeout_seconds: 60,
}
```

---

## Summary

**New Entities**:
1. `RtmpInput` - Main input struct (pattern from HLS)
2. `RtmpInputOptions` - Configuration struct
3. `FfmpegInputContext::new_rtmp_server()` - RTMP-specific factory method

**Reused Entities** (no changes):
1. `Track` - Audio/video track management
2. `StreamState` - Timing and discontinuity handling
3. `DecoderThreadHandle` - Decoder thread reference
4. `InputBuffer` - Jitter buffer
5. `AudioDecoderThread`, `VideoDecoderThread` - Decoding infrastructure

**Key Design Decisions**:
- Minimal new code (95% reuse)
- FFmpeg handles all protocol complexity
- Standard Rust ownership patterns (Arc for sharing, move for transfer)
- No locks needed (message passing via channels)

**Validation**: Post-connection stream key check, pre-decoding codec validation

**Ready for Implementation** ✅
