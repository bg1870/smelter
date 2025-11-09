# RTMP Output Debugging Guide

## Changes Made

### 1. Enhanced Debug Logging
Added `SMELTER_FFMPEG_LOGGER_LEVEL="debug"` to `start_smelter_debug.sh` to enable detailed FFmpeg output.

### 2. RTMP-Specific Options
Modified `smelter-core/src/pipeline/rtmp/rtmp_output.rs` to add:
- `flvflags=aac_seq_header_detect` - Better AAC compatibility
- `rtmp_buffer=3000` - 3 second buffer (standard)
- `tcp_nodelay=1` - Disable Nagle's algorithm for lower latency

### 3. Improved Error Logging
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

### File: `smelter-core/src/pipeline/rtmp/rtmp_output.rs`

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
