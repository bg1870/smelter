#!/bin/bash
set -e  # Exit on error

# Stop any running instance
pkill -f main_process || true

# Set environment variables
export SMELTER_MAIN_EXECUTABLE_PATH="$(pwd)/target/release/main_process"
export SMELTER_PROCESS_HELPER_PATH="$(pwd)/target/release/process_helper"
export LD_LIBRARY_PATH="$(pwd)/target/release/lib:$LD_LIBRARY_PATH"
export SMELTER_API_PORT=8089
export SMELTER_WEB_RENDERER_ENABLE=true
export SMELTER_WEB_RENDERER_GPU_ENABLE=false
export SMELTER_LOGGER_LEVEL="info,wgpu_hal=warn,wgpu_core=warn"
export SMELTER_LOGGER_FORMAT="json"
export RUST_BACKTRACE=1

# Build release version if it doesn't exist or is out of date
echo "Building release version..."
cargo build --release --bin main_process --bin process_helper

# Check if Xvfb is installed
if ! command -v Xvfb &> /dev/null; then
    echo "ERROR: Xvfb is not installed. Please run:"
    echo "  sudo apt-get update && sudo apt-get install -y xvfb libxkbcommon-x11-0 libxcomposite1 libxdamage1 libxrandr2 libpango-1.0-0 libcairo2 libasound2 libatk1.0-0 libatk-bridge2.0-0 libcups2 libxss1 libnss3"
    exit 1
fi

# Start Xvfb (virtual display) if not running
if ! pgrep -x "Xvfb" > /dev/null; then
    echo "Starting Xvfb virtual display..."
    Xvfb :99 -screen 0 1920x1080x24 -ac +extension GLX +render -noreset &
    XVFB_PID=$!
    export DISPLAY=:99
    sleep 3
    echo "Xvfb started with PID $XVFB_PID"
else
    export DISPLAY=:99
fi

# Verify DISPLAY is set
echo "Using DISPLAY=$DISPLAY"

# Start Smelter with headless Chromium args
# Key flags for RunPod/container environment:
# --no-sandbox: Required in containers without proper user namespaces
# --disable-dev-shm-usage: Use /tmp instead of /dev/shm (common container issue)
# --disable-setuid-sandbox: Required when running as non-root in containers
# --disable-gpu: Software rendering only
# --disable-gpu-compositing: Disable GPU-accelerated compositing
echo "Starting Smelter in headless mode..."
./target/release/main_process --web-renderer-chromium-extra-args="--no-sandbox --disable-dev-shm-usage --disable-setuid-sandbox --disable-gpu --disable-gpu-compositing"
