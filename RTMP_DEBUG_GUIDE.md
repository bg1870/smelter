# RTMP Output Debugging Guide

## Overview

This guide documents the fixes applied to enable RTMP streaming in Smelter. The primary issue was the missing `AV_CODEC_FLAG_GLOBAL_HEADER` flag, which RTMP servers require to decode H.264 streams. The solution implements a **protocol-aware conditional flag system** that:

- ✅ Enables `global_header` for streaming protocols (RTMP, HLS, RTP)
- ✅ Disables `global_header` for WebRTC protocols (WHEP, WHIP) to prevent breakage
- ✅ Disables `global_header` for file outputs (MP4) where it's not needed

See [RTMP_FIX_SUMMARY.md](./RTMP_FIX_SUMMARY.md) for detailed technical information.

## Changes Made

### 1. Fixed H.264 Global Header Flag (Primary Fix)
Implemented conditional `AV_CODEC_FLAG_GLOBAL_HEADER` flag that is:
- **Enabled** for streaming protocols (RTMP, HLS, RTP) - generates SPS/PPS in extradata
- **Disabled** for WebRTC protocols (WHEP, WHIP) - prevents WebRTC compatibility issues
- **Disabled** for file outputs (MP4) - not needed for file-based outputs

This fix resolves the root cause: RTMP servers require SPS/PPS headers in extradata to properly decode H.264 streams.

### 2. Enhanced Debug Logging
Added `SMELTER_FFMPEG_LOGGER_LEVEL="debug"` to `start_smelter_debug.sh` to enable detailed FFmpeg output.

### 3. RTMP-Specific Options
Modified `smelter-core/src/pipeline/rtmp/rtmp_output.rs` to add:
- `flvflags=aac_seq_header_detect` - Better AAC compatibility
- `rtmp_buffer=3000` - 3 second buffer (standard)
- `tcp_nodelay=1` - Disable Nagle's algorithm for lower latency

### 4. Improved Error Logging
Added detailed packet-level logging showing:
- Stream ID
- PTS/DTS values
- Packet size
- Keyframe status
- Success/failure for each packet write

## How to Test

### Step 1: Start Smelter with Debug Logging
```bash
./start_smelter_debug.sh
```

### Step 2: Register Your RTMP Output
Use this JSON (your exact configuration):
```json
{
  "type": "rtmp_client",
  "url": "rtmp://rtmp.genwin.app:1935/demo-ozarkslunkersdemo231v6389kzv22c754elyiojc/main-innnt7jt14yvcy6jwslj3920",
  "video": {
    "resolution": {"width": 1280, "height": 720},
    "encoder": {"type": "ffmpeg_h264", "preset": "fast", "pixel_format": "yuv420p"},
    "initial": {"root": {...}}
  },
  "audio": {
    "encoder": {"type": "aac", "sample_rate": 44100},
    "channels": "stereo",
    "initial": {"inputs": [...]}
  }
}
```

### Step 3: Look for These New Log Messages

**On successful connection:**
```
Writing RTMP header to: rtmp://...
RTMP header written successfully
RTMP sender thread started for URL: rtmp://...
Successfully wrote video packet: stream=0, pts=..., size=... bytes
Successfully wrote audio packet: stream=1, pts=..., size=... bytes
```

**On failure, you should now see:**
```
Failed to write RTMP header: [detailed error]
Failed to write packet to RTMP stream: [error]. Stream: X, PTS: ..., DTS: ..., Size: X bytes, Keyframe: true/false
```

### Step 4: Test RTMP URL Directly (Optional)
To verify the RTMP server works with FFmpeg:
```bash
./test_rtmp_direct.sh
```

This sends a 10-second test stream using the same encoding settings as Smelter.

## Common Issues & Solutions

### Issue 1: "Failed to write RTMP header"
**Cause:** Cannot connect to RTMP server or authentication failed
**Solutions:**
- Verify URL is correct (including stream key)
- Check firewall/network connectivity
- Verify RTMP server is running and accepting connections
- Check if stream key is still valid

### Issue 2: "Failed to write packet" errors
**Cause:** Connection established but packet transmission fails
**Solutions:**
- Check if the issue is only with video or audio packets
- Look at the PTS/DTS values - are they increasing monotonically?
- Check packet sizes - are they reasonable?
- Look for patterns (e.g., only keyframes fail, or only audio)

### Issue 3: Works with OBS but not Smelter
**Possible causes:**
- **Timestamp issues:** Check PTS/DTS in logs - RTMP requires monotonically increasing timestamps
- **Codec parameters:** Compare OBS settings with Smelter encoder settings
- **Handshake timing:** Some servers are sensitive to how quickly packets arrive after handshake
- **FLV metadata:** Different metadata might cause issues

### Issue 4: Connection drops after a few seconds
**Possible causes:**
- Network issues (packet loss, high latency)
- RTMP server timeout
- Buffer underrun/overrun
- Bitrate too high for connection

## What Changed in the Code

### Primary Fix: H.264 Global Header Flag

The root cause of RTMP streaming failures was the missing `AV_CODEC_FLAG_GLOBAL_HEADER` flag, which RTMP requires to properly decode H.264 streams. The fix implements a **conditional approach** that enables this flag only for streaming protocols.

#### 1. New Codec Flags Struct (`smelter-core/src/codecs/h264.rs`)

**Lines 21-29:** Added extensible codec flags struct:
```rust
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Default)]
pub struct FfmpegH264CodecFlags {
    /// Enable global header (SPS/PPS in extradata).
    /// Required for streaming protocols like RTMP, HLS, DASH.
    /// May cause issues with WebRTC (WHEP) outputs.
    pub global_header: bool,
}
```

**Line 39:** Added optional field to `FfmpegH264EncoderOptions`:
```rust
pub codec_flags: Option<FfmpegH264CodecFlags>,
```

#### 2. Conditional Flag Logic (`smelter-core/src/pipeline/encoder/ffmpeg_h264.rs`)

**Lines 59-66:** Conditionally enable global header based on protocol needs:
```rust
// Conditionally set CODEC_FLAG_GLOBAL_HEADER based on codec_flags
if let Some(codec_flags) = options.codec_flags {
    if codec_flags.global_header {
        (*encoder).flags |= ffi::AV_CODEC_FLAG_GLOBAL_HEADER as i32;
    }
}
```

#### 3. Protocol-Specific Configuration

- **RTMP, HLS, RTP** (`smelter-api/src/output/*_into.rs`): Enable `global_header`
- **WHEP, WHIP** (`smelter-api/src/output/*_into.rs`): Disable `global_header` (prevents WebRTC issues)
- **MP4** (`smelter-api/src/output/mp4_into.rs`): Disable `global_header` (not needed for files)

### Additional Debugging Improvements: `smelter-core/src/pipeline/rtmp/rtmp_output.rs`

**Line 4:** Added `Dictionary` import for RTMP options
**Line 5:** Added `debug` import for logging

**Lines 72-87:** Changed from simple `write_header()` to `write_header_with()` with RTMP options:
```rust
let rtmp_options = Dictionary::from_iter([
    ("flvflags", "aac_seq_header_detect"),
    ("rtmp_buffer", "3000"),
    ("tcp_nodelay", "1"),
]);

debug!("Writing RTMP header to: {}", options.url);
output_ctx
    .write_header_with(rtmp_options)
    .map_err(|e| {
        error!("Failed to write RTMP header: {:?}", e);
        OutputInitError::FfmpegError(e)
    })?;
debug!("RTMP header written successfully");
```

**Lines 363-386:** Enhanced packet write error logging with full context

**Line 121:** Added thread start logging

## Next Steps if Still Failing

1. **Capture Full Logs:** Save complete output when starting stream
2. **Compare with OBS:** Use Wireshark to capture RTMP traffic from both OBS and Smelter
3. **Test Simple Case:** Try without web_view overlay to isolate rendering issues
4. **Check Timestamps:** Look at PTS/DTS progression in logs
5. **Try Different Settings:**
   - Sample rate: 48000 instead of 44100
   - Preset: "ultrafast" instead of "fast"
   - Lower resolution: 640x360 for testing

## Environment Variables Reference

```bash
export SMELTER_FFMPEG_LOGGER_LEVEL="debug"     # FFmpeg verbosity: error/warn/info/debug
export SMELTER_LOGGER_LEVEL="debug"            # Smelter verbosity
export SMELTER_LOGGER_FORMAT="pretty"          # Log format: json/pretty/compact
export SMELTER_API_PORT=8081                   # API port
```
