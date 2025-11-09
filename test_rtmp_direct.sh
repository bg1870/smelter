#!/bin/bash

# Test RTMP connection with FFmpeg directly to isolate if it's a Smelter issue or RTMP server issue

RTMP_URL="rtmp://rtmp.genwin.app:1935/demo-ozarkslunkersdemo231v6389kzv22c754elyiojc/main-innnt7jt14yvcy6jwslj3920"

echo "Testing RTMP connection to: $RTMP_URL"
echo "This will send a 10 second test stream..."
echo ""

# Test with similar settings to what Smelter uses
ffmpeg -v verbose \
  -re \
  -f lavfi -i testsrc=size=1280x720:rate=30 \
  -f lavfi -i sine=frequency=1000:sample_rate=44100 \
  -c:v libx264 -preset fast -pix_fmt yuv420p \
  -c:a aac -ar 44100 -ac 2 \
  -f flv \
  -t 10 \
  "$RTMP_URL"

echo ""
echo "Test complete. Check the output above for any connection errors."
