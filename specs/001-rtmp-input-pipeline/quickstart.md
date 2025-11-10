# Quickstart: RTMP Input

**Feature**: RTMP Input Pipeline
**Branch**: 001-rtmp-input-pipeline
**Date**: 2025-11-10

## Overview

This guide demonstrates how to use the RTMP input feature to receive live streams from broadcasting software like OBS Studio or FFmpeg.

---

## Prerequisites

- Smelter with RTMP input feature compiled
- FFmpeg CLI or OBS Studio for publishing
- Network access to RTMP port (default 1935)

---

## Basic Usage

### 1. Create RTMP Input

```rust
use smelter_core::{RtmpInput, RtmpInputOptions, PipelineCtx};

let ctx = Arc::new(PipelineCtx::new(/* ... */)?);
let input_id = InputId::from("rtmp-stream-1");

let options = RtmpInputOptions {
    port: 1935,
    stream_key: "my-secret-key-123".to_string(),
    buffer: InputBufferOptions::default_rtmp(),
    video_decoders: VideoDecodersConfig::default(),
    timeout_seconds: 30,
};

let (input, init_info, receivers) = RtmpInput::new_input(
    ctx.clone(),
    input_id.clone(),
    options,
)?;

// Register with pipeline
register_pipeline_input(
    &pipeline,
    input_id,
    queue_options,
    |_, _| Ok((Input::Rtmp(input), receivers)),
)?;
```

### 2. Publish Stream with FFmpeg

```bash
ffmpeg -re -i input.mp4 \
  -c:v libx264 -preset ultrafast -tune zerolatency \
  -c:a aac \
  -f flv rtmp://localhost:1935/live/my-secret-key-123
```

### 3. Publish Stream with OBS Studio

1. Open OBS Studio
2. Go to **Settings** → **Stream**
3. Set **Service**: Custom
4. Set **Server**: `rtmp://localhost:1935/live`
5. Set **Stream Key**: `my-secret-key-123`
6. Click **Start Streaming**

---

## Configuration Examples

### Low Latency Streaming

For interactive applications requiring minimal latency:

```rust
let options = RtmpInputOptions {
    port: 1935,
    stream_key: "low-latency".to_string(),
    buffer: InputBufferOptions {
        buffer_duration: Duration::from_millis(200),
        min_buffering: Duration::from_millis(50),
        max_buffering: Duration::from_millis(500),
    },
    video_decoders: VideoDecodersConfig {
        h264: Some(VideoDecoderOptions::VulkanH264),  // Hardware acceleration
    },
    timeout_seconds: 10,
};
```

**Expected Latency**: 200-300ms

### High Quality Streaming

For broadcast quality with buffering:

```rust
let options = RtmpInputOptions {
    port: 1935,
    stream_key: "broadcast-quality".to_string(),
    buffer: InputBufferOptions {
        buffer_duration: Duration::from_secs(2),
        min_buffering: Duration::from_millis(500),
        max_buffering: Duration::from_secs(5),
    },
    video_decoders: VideoDecodersConfig {
        h264: Some(VideoDecoderOptions::FfmpegH264),
    },
    timeout_seconds: 60,
};
```

**Expected Latency**: 2-3 seconds

### Multiple Concurrent Streams

```rust
// Stream 1
let input1 = RtmpInput::new_input(
    ctx.clone(),
    InputId::from("stream-1"),
    RtmpInputOptions {
        port: 1935,
        stream_key: "camera-1".to_string(),
        /* ... */
    },
)?;

// Stream 2 (different port or stream key)
let input2 = RtmpInput::new_input(
    ctx.clone(),
    InputId::from("stream-2"),
    RtmpInputOptions {
        port: 1935,
        stream_key: "camera-2".to_string(),
        /* ... */
    },
)?;
```

**Publishers Connect To**:
- Camera 1: `rtmp://server:1935/live/camera-1`
- Camera 2: `rtmp://server:1935/live/camera-2`

---

## Testing

### Test with FFmpeg (File Input)

```bash
ffmpeg -re -i test-pattern.mp4 \
  -c:v libx264 -b:v 2M -preset ultrafast \
  -c:a aac -b:a 128k \
  -f flv rtmp://localhost:1935/live/test-key
```

### Test with FFmpeg (Webcam)

**Linux**:
```bash
ffmpeg -f v4l2 -i /dev/video0 \
  -c:v libx264 -preset ultrafast -tune zerolatency \
  -f flv rtmp://localhost:1935/live/webcam-key
```

**macOS**:
```bash
ffmpeg -f avfoundation -i "0:0" \
  -c:v libx264 -preset ultrafast -tune zerolatency \
  -f flv rtmp://localhost:1935/live/webcam-key
```

### Verify Connection

```rust
// Check if input is receiving data
if let Some(frame) = receivers.video.as_ref().unwrap().try_recv() {
    println!("Receiving video: {}x{}", frame.width, frame.height);
}

if let Some(samples) = receivers.audio.as_ref().unwrap().try_recv() {
    println!("Receiving audio: {} samples", samples.len());
}
```

---

## Common Issues

### Connection Refused

**Problem**: Publisher cannot connect to RTMP server

**Solutions**:
1. Check firewall allows port 1935
2. Verify Smelter is listening: `netstat -an | grep 1935`
3. Check stream key matches exactly

### Authentication Failed

**Problem**: Connection rejected after handshake

**Solutions**:
1. Verify stream key in URL matches `RtmpInputOptions.stream_key`
2. Check for typos in stream key
3. Ensure stream key is alphanumeric (no special characters except `-` and `_`)

### High Latency

**Problem**: Latency exceeds requirements

**Solutions**:
1. Reduce `buffer_duration` in `InputBufferOptions`
2. Use hardware H.264 decoder (`VulkanH264`)
3. Publisher settings:
   - FFmpeg: Add `-tune zerolatency`
   - OBS: Lower keyframe interval (1-2 seconds)

### Dropped Frames

**Problem**: Video stuttering or frame drops

**Solutions**:
1. Increase `buffer_duration` (trade latency for stability)
2. Check network bandwidth
3. Publisher settings:
   - Reduce bitrate
   - Lower resolution/frame rate

### Stream Disconnects Unexpectedly

**Problem**: Stream stops after short time

**Solutions**:
1. Increase `timeout_seconds` in `RtmpInputOptions`
2. Check publisher is sending data continuously
3. Verify network stability

---

## Advanced Usage

### Custom Port

```rust
let options = RtmpInputOptions {
    port: 8080,  // Non-standard port
    stream_key: "stream".to_string(),
    /* ... */
};
```

**Publisher**: `rtmp://server:8080/live/stream`

### Dynamic Stream Keys

```rust
use rand::Rng;

let stream_key = format!("stream-{}", rand::thread_rng().gen::<u32>());

let options = RtmpInputOptions {
    port: 1935,
    stream_key: stream_key.clone(),
    /* ... */
};

println!("Publish to: rtmp://server:1935/live/{}", stream_key);
```

### Graceful Shutdown

```rust
// Signal shutdown
drop(input);  // Triggers Drop trait

// Or manual close
// (input.should_close set internally)

// Wait for cleanup
std::thread::sleep(Duration::from_secs(2));
```

---

## Performance Tuning

### Latency Optimization

| Setting | Low Latency | Default | High Quality |
|---------|-------------|---------|--------------|
| `buffer_duration` | 200ms | 500ms | 2000ms |
| `timeout_seconds` | 10s | 30s | 60s |
| Decoder | Vulkan | Auto | FFmpeg |
| Expected Latency | 200-300ms | 280-380ms | 2-3s |

### Concurrent Streams

| Streams | Memory | Threads | CPU Load |
|---------|--------|---------|----------|
| 1 | ~14MB | 3 | ~15-30% |
| 5 | ~70MB | 11 | ~50-80% |
| 10 | ~140MB | 21 | ~80-100% |

**Recommendation**: Test with expected workload, monitor system resources.

---

## Integration with Pipeline

### Complete Example

```rust
use smelter_core::*;
use std::sync::Arc;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Initialize pipeline context
    let ctx = Arc::new(PipelineCtx::new(PipelineOptions::default())?);

    // Create RTMP input
    let input_id = InputId::from("live-stream");
    let options = RtmpInputOptions {
        port: 1935,
        stream_key: "broadcast".to_string(),
        buffer: InputBufferOptions::default_rtmp(),
        video_decoders: VideoDecodersConfig::default(),
        timeout_seconds: 30,
    };

    let (input, _, receivers) = RtmpInput::new_input(
        ctx.clone(),
        input_id.clone(),
        options,
    )?;

    // Register input
    let pipeline = /* your pipeline instance */;
    register_pipeline_input(
        &pipeline,
        input_id.clone(),
        QueueOptions::default(),
        |_, _| Ok((Input::Rtmp(input), receivers)),
    )?;

    println!("RTMP server listening on port 1935");
    println!("Publish to: rtmp://localhost:1935/live/broadcast");

    // Keep running
    std::thread::park();

    Ok(())
}
```

### With Outputs

```rust
// Add output (e.g., RTP)
let rtp_output = RtpOutput::new(/* ... */)?;
pipeline.add_output(OutputId::from("rtp-out"), rtp_output)?;

// Link input to output
pipeline.link(input_id, OutputId::from("rtp-out"))?;
```

---

## Monitoring

### Log Output

```bash
# Enable debug logging
RUST_LOG=smelter_core::pipeline::rtmp=debug cargo run

# Example output:
# [RTMP] Listening on port 1935
# [RTMP] Client connected: 192.168.1.100:54321
# [RTMP] Stream key validated: broadcast
# [RTMP] Stream info: H.264 1920x1080 @ 30fps, AAC 48kHz stereo
# [RTMP] Decoding started
# [RTMP] Client disconnected: 192.168.1.100:54321
# [RTMP] Cleanup completed in 2.3s
```

### Metrics (if instrumented)

```rust
// Example metrics (if tracing/metrics crate integrated)
let metrics = rtmp_input.get_metrics();
println!("Frames received: {}", metrics.frames_received);
println!("Packets dropped: {}", metrics.packets_dropped);
println!("Current latency: {}ms", metrics.current_latency_ms);
```

---

## Next Steps

- **Production Deployment**: See `DEPLOYMENT.md` for firewall, security, scaling
- **Troubleshooting**: See `TROUBLESHOOTING.md` for detailed diagnostics
- **API Reference**: See `docs/api/rtmp-input.md` for complete API documentation

---

## Support

- GitHub Issues: https://github.com/smelter-labs/smelter/issues
- Documentation: https://docs.smelter.dev/rtmp-input
- Examples: `examples/rtmp_input_example.rs`
