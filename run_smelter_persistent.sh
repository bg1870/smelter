#!/bin/bash
# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Kill any existing process
pkill -f main_process || true
sleep 2

# Start Xvfb if not running
if ! pgrep -x "Xvfb" > /dev/null; then
    Xvfb :99 -screen 0 1920x1080x24 -ac +extension GLX +render -noreset >/dev/null 2>&1 &
    sleep 3
fi

# Set environment
export DISPLAY=:99
export SMELTER_MAIN_EXECUTABLE_PATH="$(pwd)/target/release/main_process"
export SMELTER_PROCESS_HELPER_PATH="$(pwd)/target/release/process_helper"
export LD_LIBRARY_PATH="$(pwd)/target/release/lib:$LD_LIBRARY_PATH"
export SMELTER_API_PORT=8089
export SMELTER_WEB_RENDERER_ENABLE=true
export SMELTER_WEB_RENDERER_GPU_ENABLE=false
export SMELTER_LOGGER_LEVEL="info,wgpu_hal=warn,wgpu_core=warn"
export SMELTER_LOGGER_FORMAT="json"
export RUST_BACKTRACE=1

# Start Smelter in background with nohup
nohup ./target/release/main_process \
  --web-renderer-chromium-extra-args="--no-sandbox --disable-dev-shm-usage --disable-setuid-sandbox --disable-gpu --disable-gpu-compositing --log-level=0" \
  > /tmp/smelter_output.log 2>&1 &

PID=$!
echo "Smelter started with PID: $PID"
echo "Logs: /tmp/smelter_output.log"

# Wait and verify
sleep 5
if ps -p $PID > /dev/null; then
    echo "✓ Smelter is running!"
    echo "API: http://localhost:8089"
    echo "WHIP/WHEP: http://localhost:9000"
else
    echo "✗ Smelter failed to start. Check logs:"
    tail -50 /tmp/smelter_output.log
fi
