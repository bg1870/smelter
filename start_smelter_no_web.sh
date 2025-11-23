#!/bin/bash

# Stop any running instance
pkill -f main_process

# Set environment variables
export SMELTER_MAIN_EXECUTABLE_PATH="$(pwd)/target/release/main_process"
export SMELTER_PROCESS_HELPER_PATH="$(pwd)/target/release/process_helper"
export LD_LIBRARY_PATH="$(pwd)/target/release/lib:$LD_LIBRARY_PATH"
export SMELTER_API_PORT=8089
export SMELTER_WEB_RENDERER_ENABLE=false
export SMELTER_LOGGER_LEVEL="info,wgpu_hal=warn,wgpu_core=warn"
export SMELTER_LOGGER_FORMAT="json"
export RUST_BACKTRACE=1

# Build release version if it doesn't exist or is out of date
echo "Building release version..."
cargo build --release --bin main_process --bin process_helper

# Start Smelter without web renderer
echo "Starting Smelter (web renderer disabled)..."
./target/release/main_process
