# smelter Development Guidelines

Auto-generated from all feature plans. Last updated: 2025-11-10

## Active Technologies
- N/A (streaming data only, no persistence) (001-rtmp-input-pipeline)
- Rust 2024 edition + schemars (JSON schema), serde (serialization), smelter-core (RTMP implementation), ffmpeg-next (via core) (002-rtmp-api-input)

- Rust 2024 edition + FFmpeg (via ffmpeg-next) with native RTMP support, tokio for async runtime (optional for connection handling), crossbeam-channel for threading, tracing for logging (001-rtmp-input-pipeline)

## Project Structure

```text
src/
tests/
```

## Commands

cargo test [ONLY COMMANDS FOR ACTIVE TECHNOLOGIES][ONLY COMMANDS FOR ACTIVE TECHNOLOGIES] cargo clippy

## Code Style

Rust 2024 edition: Follow standard conventions

## Recent Changes
- 002-rtmp-api-input: Added Rust 2024 edition + schemars (JSON schema), serde (serialization), smelter-core (RTMP implementation), ffmpeg-next (via core)
- 001-rtmp-input-pipeline: Added Rust 2024 edition + FFmpeg (via ffmpeg-next) with native RTMP support, tokio for async runtime (optional for connection handling), crossbeam-channel for threading, tracing for logging

- 001-rtmp-input-pipeline: Added Rust 2024 edition + FFmpeg (via ffmpeg-next) with native RTMP support, tokio for async runtime (optional for connection handling), crossbeam-channel for threading, tracing for logging

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
