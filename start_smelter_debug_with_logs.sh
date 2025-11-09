#!/bin/bash

# Stop any running instance
pkill -f main_process

# Create logs directory if it doesn't exist
mkdir -p logs

# Generate log filename with timestamp
LOG_FILE="logs/smelter_debug_$(date +%Y%m%d_%H%M%S).log"

echo "Starting Smelter in debug mode..."
echo "Logs will be written to: $LOG_FILE"
echo ""

# Set environment variables for debug mode
export SMELTER_MAIN_EXECUTABLE_PATH="$(pwd)/target/debug/main_process"
export SMELTER_PROCESS_HELPER_PATH="$(pwd)/target/debug/process_helper"
export LD_LIBRARY_PATH="$(pwd)/target/debug/lib:$LD_LIBRARY_PATH"
export SMELTER_API_PORT=8081
export SMELTER_WEB_RENDERER_ENABLE=true
export SMELTER_WEB_RENDERER_GPU_ENABLE=true
export SMELTER_LOGGER_LEVEL="debug"
export SMELTER_LOGGER_FORMAT="pretty"
export SMELTER_FFMPEG_LOGGER_LEVEL="debug"

# Build debug version if it doesn't exist or is out of date
echo "Building debug version..."
cargo build --bin main_process --bin process_helper

echo ""
echo "Starting Smelter..."
echo "Press Ctrl+C to stop"
echo ""

# Start Smelter and tee output to both console and file
./target/debug/main_process 2>&1 | tee "$LOG_FILE"
