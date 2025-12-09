#!/bin/bash

# Stop any running instance
pkill -f main_process

# Set environment variables
export SMELTER_MAIN_EXECUTABLE_PATH="$(pwd)/target/release/main_process"
export SMELTER_PROCESS_HELPER_PATH="$(pwd)/target/release/process_helper"
export LD_LIBRARY_PATH="$(pwd)/target/release/lib:$LD_LIBRARY_PATH"
export SMELTER_API_PORT=8081
export SMELTER_WEB_RENDERER_ENABLE=true
export SMELTER_WEB_RENDERER_GPU_ENABLE=true
export SMELTER_FORCE_GPU=true
# export SMELTER_AHEAD_OF_TIME_PROCESSING_ENABLE=true
# export SMELTER_RUN_LATE_SCHEDULED_EVENTS=true
# export SMELTER_LOGGER_LEVEL="info,wgpu_hal=warn,wgpu_core=warn"
# export SMELTER_LOGGER_FORMAT="json"
# export RUST_BACKTRACE=1

# Build release version if it doesn't exist or is out of date
echo "Building release version..."
cargo build --release --bin main_process --bin process_helper

# Start Smelter
echo "Starting Smelter..."
./target/release/main_process
