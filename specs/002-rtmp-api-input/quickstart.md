# Quickstart: RTMP Input API Registration

**Feature**: 002-rtmp-api-input
**Date**: 2025-11-10

## Overview

This guide shows how to register RTMP inputs via the smelter API and start streaming from common encoders (OBS, FFmpeg, hardware encoders).

## Prerequisites

- Smelter server running with RTMP support enabled
- Network port available for RTMP (default: 1935)
- RTMP encoder (OBS Studio, FFmpeg, or hardware encoder)
- Basic understanding of RTMP streaming concepts

## Quick Start (5 Minutes)

### Step 1: Register RTMP Input

**Minimal Example** (TypeScript SDK):

```typescript
import { Smelter, RtmpInput } from 'smelter-sdk';

const smelter = new Smelter({ apiUrl: 'http://localhost:8080' });

const rtmpInput: RtmpInput = {
  port: 1935,
  stream_key: 'my-secret-stream-key',
};

const inputId = await smelter.registerInput('rtmp', rtmpInput);
console.log(`RTMP input registered: ${inputId}`);
console.log(`Publish to: rtmp://localhost:1935/live/my-secret-stream-key`);
```

**Minimal Example** (Rust):

```rust
use smelter_api::RtmpInput;
use smelter_core::RegisterInputOptions;

let rtmp_config = RtmpInput {
    port: 1935,
    stream_key: String::from("my-secret-stream-key"),
    timeout_seconds: None, // Use default (30s)
    video: None, // Auto-select decoder
    buffer: None, // Use default (latency-optimized)
    required: None, // Use default (false)
    offset_ms: None, // Auto-sync
};

// Convert to core options
let core_options = RegisterInputOptions::try_from(rtmp_config)?;

// Register with pipeline
let input_id = pipeline.register_input(core_options)?;
println!("RTMP input registered: {}", input_id);
println!("Publish to: rtmp://localhost:1935/live/my-secret-stream-key");
```

**Minimal Example** (REST API):

```bash
curl -X POST http://localhost:8080/api/inputs/register \
  -H "Content-Type: application/json" \
  -d '{
    "type": "rtmp",
    "config": {
      "port": 1935,
      "stream_key": "my-secret-stream-key"
    }
  }'
```

### Step 2: Start Streaming

**Option A: OBS Studio**

1. Open OBS Studio
2. Go to Settings → Stream
3. **Service**: Custom
4. **Server**: `rtmp://localhost:1935/live`
5. **Stream Key**: `my-secret-stream-key`
6. Click "OK", then "Start Streaming"

**Option B: FFmpeg**

```bash
# Stream from webcam (Linux)
ffmpeg -f v4l2 -i /dev/video0 \
       -f alsa -i hw:0 \
       -c:v libx264 -preset veryfast -b:v 2500k \
       -c:a aac -b:a 128k \
       -f flv rtmp://localhost:1935/live/my-secret-stream-key

# Stream from file
ffmpeg -re -i input.mp4 \
       -c:v libx264 -preset veryfast -b:v 2500k \
       -c:a aac -b:a 128k \
       -f flv rtmp://localhost:1935/live/my-secret-stream-key

# Stream from screen capture (macOS)
ffmpeg -f avfoundation -i "1:0" \
       -c:v libx264 -preset veryfast -b:v 2500k \
       -c:a aac -b:a 128k \
       -f flv rtmp://localhost:1935/live/my-secret-stream-key
```

**Option C: Hardware Encoder**

Configure your hardware encoder with:
- **Protocol**: RTMP
- **URL**: `rtmp://your-server-ip:1935/live`
- **Stream Key**: `my-secret-stream-key`
- **Video**: H.264, 2-6 Mbps, 2s keyframe interval
- **Audio**: AAC, 128 kbps, 48kHz

### Step 3: Verify Stream

Check pipeline status:

```typescript
const status = await smelter.getInputStatus(inputId);
console.log(status); // Should show "connected" when publisher is streaming
```

## Common Configurations

### Production Setup (Recommended)

```typescript
const productionRtmpInput: RtmpInput = {
  port: 1935,
  stream_key: generateSecureStreamKey(), // UUID or crypto.randomBytes
  timeout_seconds: 60, // Longer timeout for unreliable networks
  video: {
    decoder: 'vulkan_h264', // Use GPU acceleration if available
  },
  buffer: 'latency_optimized', // Minimize latency
  required: false, // Don't block pipeline if stream is late
  offset_ms: 0, // Trust RTMP timestamps
};
```

### High-Latency Network (Satellite, Mobile)

```typescript
const bufferedRtmpInput: RtmpInput = {
  port: 1935,
  stream_key: 'buffered-stream-key',
  timeout_seconds: 120, // Longer timeout for slow connections
  buffer: { const: 3.0 }, // 3-second buffer for jitter absorption
};
```

### Multi-Camera Sync

```typescript
// Camera 1 (reference)
const camera1: RtmpInput = {
  port: 1935,
  stream_key: 'camera-1-key',
  required: true, // Wait for this camera
  offset_ms: 0, // Reference camera
};

// Camera 2 (needs 100ms offset to align)
const camera2: RtmpInput = {
  port: 1936,
  stream_key: 'camera-2-key',
  required: false, // Optional camera
  offset_ms: 100, // Compensate for network latency difference
};
```

### CPU-Only Environment (No GPU)

```typescript
const cpuOnlyRtmpInput: RtmpInput = {
  port: 1935,
  stream_key: 'cpu-stream-key',
  video: {
    decoder: 'ffmpeg_h264', // Force software decoder
  },
};
```

## Encoder Configuration Best Practices

### OBS Studio Settings

**Video**:
- **Encoder**: x264
- **Rate Control**: CBR (Constant Bitrate)
- **Bitrate**: 2500-6000 Kbps (depending on resolution)
- **Keyframe Interval**: 2 seconds (60 frames at 30fps, 120 frames at 60fps)
- **CPU Preset**: veryfast or faster
- **Profile**: main or high
- **Tune**: zerolatency (for live streaming)

**Audio**:
- **Encoder**: AAC
- **Bitrate**: 128 Kbps
- **Sample Rate**: 48kHz

**Advanced** → **Network**:
- Enable "Dynamically change bitrate when dropping frames" (optional)

### FFmpeg Command Line

**1080p30 (High Quality)**:
```bash
ffmpeg -i input.mp4 \
  -c:v libx264 -preset veryfast -tune zerolatency \
  -profile:v main -b:v 4500k -maxrate 4500k -bufsize 9000k \
  -g 60 -keyint_min 60 -sc_threshold 0 \
  -c:a aac -b:a 128k -ar 48000 \
  -f flv rtmp://server:1935/live/stream-key
```

**720p30 (Balanced)**:
```bash
ffmpeg -i input.mp4 \
  -c:v libx264 -preset veryfast -tune zerolatency \
  -profile:v main -b:v 2500k -maxrate 2500k -bufsize 5000k \
  -g 60 -keyint_min 60 -sc_threshold 0 \
  -c:a aac -b:a 128k -ar 48000 \
  -f flv rtmp://server:1935/live/stream-key
```

**540p30 (Low Bandwidth)**:
```bash
ffmpeg -i input.mp4 \
  -c:v libx264 -preset veryfast -tune zerolatency \
  -profile:v main -b:v 1200k -maxrate 1200k -bufsize 2400k \
  -g 60 -keyint_min 60 -sc_threshold 0 \
  -c:a aac -b:a 96k -ar 48000 \
  -f flv rtmp://server:1935/live/stream-key
```

**Key Parameters Explained**:
- `-preset veryfast`: CPU usage vs compression trade-off
- `-tune zerolatency`: Optimize for low-latency streaming
- `-b:v`, `-maxrate`, `-bufsize`: Bitrate control (CBR)
- `-g 60`, `-keyint_min 60`: Keyframe every 2 seconds at 30fps
- `-sc_threshold 0`: Disable scene change detection (prevents extra keyframes)
- `-f flv`: RTMP requires FLV container

## Troubleshooting

### Connection Refused

**Symptom**: Encoder can't connect to RTMP server

**Causes**:
1. **Port not open**: Check firewall rules allow port 1935
2. **Smelter not listening**: Verify RTMP input registered successfully
3. **Wrong URL**: Ensure using correct hostname/IP and port

**Solutions**:
```bash
# Check if port is listening
netstat -tuln | grep 1935

# Test port connectivity
telnet localhost 1935

# Check firewall (Linux)
sudo ufw allow 1935/tcp

# Check firewall (macOS)
# System Preferences → Security & Privacy → Firewall → Firewall Options
```

### Stream Key Rejected

**Symptom**: Connection closes immediately after connecting

**Cause**: Stream key mismatch

**Solution**:
- Verify stream key in encoder matches registration: `my-secret-stream-key`
- Check for typos, spaces, or special characters
- Stream key is case-sensitive

### Timeout Waiting for Connection

**Symptom**: RTMP input times out before encoder connects

**Cause**: Connection timeout too short for network conditions

**Solution**:
```typescript
const rtmpInput: RtmpInput = {
  port: 1935,
  stream_key: 'my-key',
  timeout_seconds: 120, // Increase from default 30s
};
```

### Decoder Not Available

**Symptom**: Error "Vulkan H.264 decoder requested but not supported"

**Cause**: GPU doesn't support Vulkan Video decoding

**Solutions**:
1. **Auto-select**: Omit `video.decoder` field (system chooses best available)
2. **Force FFmpeg**: Explicitly use `decoder: 'ffmpeg_h264'`
3. **Check Vulkan**: Run `vulkaninfo` to verify Vulkan Video support

### High Latency / Buffering

**Symptom**: Stream lags behind real-time

**Causes**:
1. **Network congestion**: Encoder upload speed insufficient
2. **Bitrate too high**: Exceeds network capacity
3. **Buffer too large**: Using `buffer: { const: N }` with high N

**Solutions**:
```typescript
// Reduce buffer
const rtmpInput: RtmpInput = {
  port: 1935,
  stream_key: 'my-key',
  buffer: 'latency_optimized', // Minimal buffering
};

// Reduce encoder bitrate (OBS/FFmpeg)
// Lower from 4500k to 2500k or 1200k
```

### Audio/Video Out of Sync

**Symptom**: Audio and video misaligned

**Cause**: Network jitter, encoder issues

**Solution**:
```typescript
const rtmpInput: RtmpInput = {
  port: 1935,
  stream_key: 'my-key',
  offset_ms: 100, // Adjust until A/V aligns (trial and error)
};
```

### Port Already in Use

**Symptom**: Error "Port 1935 is already in use"

**Causes**:
1. **Another RTMP input**: Already registered on same port
2. **External process**: Other application using port

**Solutions**:
```bash
# Find process using port
sudo lsof -i :1935
# or
sudo netstat -tlnp | grep 1935

# Use different port
const rtmpInput: RtmpInput = {
  port: 1936, // Or any available port 1024-65535
  stream_key: 'my-key',
};
```

## Security Considerations

### Stream Key Protection

**DO**:
- Use long, random stream keys (UUID recommended)
- Rotate stream keys periodically
- Use HTTPS for API requests containing stream keys
- Store stream keys securely (environment variables, secrets manager)

**DON'T**:
- Hardcode stream keys in client-side code
- Log stream keys in plaintext
- Reuse stream keys across multiple users/streams
- Use predictable stream keys (e.g., "stream1", "admin", "test")

**Example**:
```typescript
import { v4 as uuidv4 } from 'uuid';

const streamKey = uuidv4(); // e.g., "550e8400-e29b-41d4-a716-446655440000"
```

### Network Security

**Firewall Rules**:
```bash
# Allow RTMP port only from trusted sources
sudo ufw allow from 192.168.1.0/24 to any port 1935 proto tcp

# Block all other sources
sudo ufw deny 1935/tcp
```

**Reverse Proxy** (for TLS termination):
```nginx
# Nginx RTMP module
rtmp {
    server {
        listen 1935;

        application live {
            live on;
            # Forward to smelter
            exec_push rtmp://localhost:1936/live/$name;

            # Authentication via stream key
            on_publish http://localhost:8080/api/auth/rtmp;
        }
    }
}
```

**Note**: RTMPS (RTMP over TLS) not implemented in this feature (requires port 1936 and TLS certificates)

### Rate Limiting

Prevent bandwidth exhaustion attacks:

```typescript
// Limit bitrate (future enhancement - not in current API)
const rtmpInput: RtmpInput = {
  port: 1935,
  stream_key: 'my-key',
  // max_bitrate_mbps: 10, // Not yet implemented
};
```

**Workaround**: Use OS-level traffic shaping:
```bash
# Linux tc (traffic control)
sudo tc qdisc add dev eth0 root tbf rate 10mbit burst 32kbit latency 400ms
```

## Performance Optimization

### GPU Acceleration (Recommended)

```typescript
const gpuAcceleratedInput: RtmpInput = {
  port: 1935,
  stream_key: 'my-key',
  video: {
    decoder: 'vulkan_h264', // 3-5x faster than software decoding
  },
};
```

**Benefits**:
- Lower CPU usage (frees CPU for other tasks)
- Higher throughput (more concurrent streams)
- Lower latency (hardware pipelines)

**Requirements**:
- GPU with Vulkan Video support (NVIDIA 10xx+, AMD RX 5xx+, Intel Arc)
- Linux: `vulkan-tools` package installed
- Windows: Latest GPU drivers

### Resource Planning

**Single 1080p30 stream**:
- CPU (FFmpeg): ~20-40% of 1 core
- CPU (Vulkan): ~5-10% of 1 core
- Memory: ~50-100 MB
- Network: ~4-5 Mbps upload (encoder) + download (server)

**Concurrent streams**:
- 10 streams: 4-8 GB RAM, 4-8 CPU cores (FFmpeg) or 1-2 cores (Vulkan)
- 50 streams: 16-32 GB RAM, dedicated GPU recommended

## Next Steps

- **Add Outputs**: Connect RTMP input to outputs (HLS, WebRTC, file recording)
- **Monitoring**: Set up logging and metrics for stream health
- **Scaling**: Configure load balancer for multiple smelter instances
- **Automation**: Script stream key generation and input registration

## References

- RTMP Specification: https://rtmp.veriskope.com/docs/spec/
- OBS Studio: https://obsproject.com/
- FFmpeg RTMP: https://ffmpeg.org/ffmpeg-protocols.html#rtmp
- Smelter API Documentation: `/docs/api/inputs`
- Core RTMP Implementation: `smelter-core/src/pipeline/rtmp/rtmp_input.rs`
