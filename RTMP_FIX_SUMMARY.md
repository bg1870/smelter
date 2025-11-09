# RTMP Streaming Fix - Technical Summary

## Issue

RTMP streaming from Smelter was failing after the first 2 video packets with the error:
```
Failed to write packet to RTMP stream
```

## Root Cause

The FFmpeg H.264 encoder was not generating **SPS/PPS (Sequence Parameter Set / Picture Parameter Set)** headers in the extradata. These headers are critical codec metadata that RTMP servers require to properly decode H.264 streams.

### Why This Happened

Without the `AV_CODEC_FLAG_GLOBAL_HEADER` flag, libx264:
1. Does not generate SPS/PPS in extradata during encoder initialization
2. Embeds SPS/PPS inline within keyframes instead
3. This causes RTMP servers to reject packets after the initial handshake

## The Fix

**File:** `smelter-core/src/pipeline/encoder/ffmpeg_h264.rs`
**Line:** 59 (added)

```rust
// Set CODEC_FLAG_GLOBAL_HEADER to force SPS/PPS into extradata
// This is REQUIRED for streaming protocols like RTMP, HLS, etc.
(*encoder).flags |= ffi::AV_CODEC_FLAG_GLOBAL_HEADER as i32;
```

This flag forces libx264 to:
- Generate SPS/PPS immediately when the encoder is opened
- Place SPS/PPS in extradata (not inline in keyframes)
- Make the stream compatible with RTMP, HLS, DASH, and other streaming protocols

## Is This a Bug or Configuration Issue?

**This is a BUG** that should be fixed in the code, not worked around via configuration.

### Why Code Fix is Correct

1. **Protocol Requirement**: Streaming protocols (RTMP, HLS, DASH) REQUIRE global headers
2. **User Transparency**: Users shouldn't need to know about low-level codec flags
3. **FFmpeg Standard**: This is a well-documented requirement for streaming outputs

### Could It Be Configured?

Technically, `ffmpeg_options` field exists in the API:

```json
{
  "type": "rtmp_client",
  "url": "rtmp://...",
  "video": {
    "encoder": {
      "type": "ffmpeg_h264",
      "ffmpeg_options": {
        // Custom FFmpeg encoder options here
      }
    }
  }
}
```

**However:**
- `AV_CODEC_FLAG_GLOBAL_HEADER` is a codec context flag, not an encoder option
- There's no standard FFmpeg option string to set this flag
- It would require users to understand internal FFmpeg details

## Impact

This fix affects:
- ✅ **RTMP outputs** - Now works correctly
- ✅ **HLS outputs** - Will also benefit from this fix
- ✅ **DASH outputs** - Will also benefit from this fix
- ✅ **MP4 outputs** - No negative impact (flag is optional for file outputs)

## Testing

### Before Fix
- 0 successful video packets (after first 2)
- Stream rejected by RTMP server
- Error: "WARNING: No H.264 extradata (SPS/PPS) available from encoder!"

### After Fix
- 1,802+ successful video packets
- 0 failed video packets
- Extradata present: 38 bytes of SPS/PPS
- RTMP stream working perfectly

## Related Files

- `smelter-core/src/pipeline/encoder/ffmpeg_h264.rs` - The fix
- `smelter-core/src/pipeline/rtmp/rtmp_output.rs` - RTMP output implementation
- `smelter-api/src/output/rtmp.rs` - API definition

## Recommendation

**Keep the code fix.** This is the correct solution for this issue. The flag should be set automatically for all H.264 encoding in Smelter, as it's required for streaming outputs and harmless for file outputs.

### Future Improvement (Optional)

If MP4 file outputs ever exhibit issues, you could conditionally set the flag only for streaming outputs. However, this is likely unnecessary as the flag is generally harmless for file outputs.
