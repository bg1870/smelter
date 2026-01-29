# =============================================================================
# Smelter Production Dockerfile
# Optimized for AWS NVIDIA EC2 instances (g4dn, g5, p3, p4, etc.)
# =============================================================================
#
# Build:
#   docker build -t smelter:latest .
#
# Run on AWS NVIDIA EC2:
#   docker run --gpus all --runtime=nvidia -p 8081:8081 -p 9000:9000 smelter:latest
#
# Run with docker-compose:
#   docker-compose up -d
#

# =============================================================================
# Stage 1: Build Environment
# =============================================================================
# Use NVIDIA CUDA image for better GPU driver compatibility on AWS
FROM nvidia/cuda:12.6.3-devel-ubuntu24.04 AS builder

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive

# Rust version - Smelter requires Rust 1.85+ (edition 2024)
ARG RUST_VERSION=stable

# Install build dependencies
# - FFmpeg 6.x dev libraries (required by Smelter)
# - Vulkan SDK for GPU rendering
# - GTK/X11 libs for CEF (Chromium Embedded Framework)
RUN apt-get update -y -qq \
    && apt-get install -y --no-install-recommends \
        # Build essentials
        build-essential \
        curl \
        ca-certificates \
        git \
        pkg-config \
        cmake \
        # SSL and development headers
        libssl-dev \
        libclang-dev \
        # FFmpeg development libraries
        ffmpeg \
        libavcodec-dev \
        libavformat-dev \
        libavfilter-dev \
        libavdevice-dev \
        libavutil-dev \
        libswscale-dev \
        libswresample-dev \
        libopus-dev \
        # Vulkan SDK
        libvulkan-dev \
        vulkan-tools \
        # Mesa drivers (fallback)
        libegl1-mesa-dev \
        libgl1-mesa-dri \
        libxcb-xfixes0-dev \
        mesa-vulkan-drivers \
        # GTK/X11 for CEF
        libnss3 \
        libatk1.0-0 \
        libatk-bridge2.0-0 \
        libgdk-pixbuf2.0-0 \
        libgtk-3-0 \
    && rm -rf /var/lib/apt/lists/*

# Install Rust toolchain
RUN curl https://sh.rustup.rs -sSf | bash -s -- -y --default-toolchain ${RUST_VERSION} \
    && . "$HOME/.cargo/env" \
    && rustup component add rustfmt clippy

ENV PATH="/root/.cargo/bin:$PATH"

# Create app directory
WORKDIR /build

# =============================================================================
# Stage 1.5: Dependency Cache (speeds up rebuilds)
# =============================================================================
# Copy only Cargo files first to cache dependencies
COPY Cargo.toml Cargo.lock ./
COPY smelter-api/Cargo.toml smelter-api/
COPY smelter-core/Cargo.toml smelter-core/
COPY smelter-render/Cargo.toml smelter-render/
COPY smelter-render-wasm/Cargo.toml smelter-render-wasm/
COPY vk-video/Cargo.toml vk-video/
COPY rtmp/Cargo.toml rtmp/
COPY decklink/Cargo.toml decklink/
COPY integration-tests/Cargo.toml integration-tests/
COPY tools/Cargo.toml tools/
COPY libcef/Cargo.toml libcef/

# Create dummy src files for dependency compilation
RUN mkdir -p src/bin smelter-api/src smelter-core/src smelter-render/src \
             smelter-render-wasm/src vk-video/src rtmp/src decklink/src \
             integration-tests/src tools/src libcef/src \
    && echo "fn main() {}" > src/bin/main_process.rs \
    && echo "fn main() {}" > src/bin/process_helper.rs \
    && echo "pub fn dummy() {}" > smelter-api/src/lib.rs \
    && echo "pub fn dummy() {}" > smelter-core/src/lib.rs \
    && echo "pub fn dummy() {}" > smelter-render/src/lib.rs \
    && echo "pub fn dummy() {}" > smelter-render-wasm/src/lib.rs \
    && echo "pub fn dummy() {}" > vk-video/src/lib.rs \
    && echo "pub fn dummy() {}" > rtmp/src/lib.rs \
    && echo "pub fn dummy() {}" > decklink/src/lib.rs \
    && echo "pub fn dummy() {}" > tools/src/lib.rs \
    && echo "pub fn dummy() {}" > libcef/src/lib.rs \
    && echo "fn main() {}" > integration-tests/src/main.rs

# Pre-build dependencies (this layer is cached)
RUN cargo build --release 2>/dev/null || true

# =============================================================================
# Stage 2: Full Build
# =============================================================================
# Copy full source code
COPY . /build

# Build release binaries
RUN cargo build --release --bin main_process --bin process_helper

# Strip debug symbols to reduce binary size
RUN strip --strip-unneeded /build/target/release/main_process \
    && strip --strip-unneeded /build/target/release/process_helper

# =============================================================================
# Stage 3: Production Runtime
# =============================================================================
FROM nvidia/cuda:12.6.3-runtime-ubuntu24.04

LABEL org.opencontainers.image.source="https://github.com/software-mansion/smelter"
LABEL org.opencontainers.image.description="Smelter - Real-time video composition toolkit"
LABEL org.opencontainers.image.vendor="Software Mansion"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# =============================================================================
# NVIDIA GPU Configuration for AWS EC2
# =============================================================================
# Required for NVIDIA Container Toolkit on AWS
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,graphics,utility,video
ENV NVIDIA_REQUIRE_CUDA="cuda>=12.0"

# Vulkan configuration for NVIDIA
ENV VK_LAYER_PATH=/usr/share/vulkan/explicit_layer.d
# Include NVIDIA library paths injected by the container toolkit
ENV LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:/usr/lib64:${LD_LIBRARY_PATH}
# Point to our custom ICD file that uses libnvidia-vulkan-producer.so
ENV VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.json

# =============================================================================
# Runtime Dependencies
# =============================================================================
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -y -qq \
    && apt-get install -y --no-install-recommends \
        # Process management
        sudo \
        dbus \
        dbus-x11 \
        # FFmpeg runtime
        ffmpeg \
        # X11/Display for headless rendering
        xvfb \
        x11-utils \
        # X11 libraries required by NVIDIA GLX/Vulkan drivers
        libx11-6 \
        libxext6 \
        libxrandr2 \
        libxrender1 \
        libxcb1 \
        libxau6 \
        libxdmcp6 \
        libxfixes3 \
        libxxf86vm1 \
        # EGL/GL libraries required by libnvidia-vulkan-producer
        libegl1 \
        libgl1 \
        libglx0 \
        libglvnd0 \
        # GTK/CEF dependencies
        libnss3 \
        libatk1.0-0 \
        libatk-bridge2.0-0 \
        libgdk-pixbuf2.0-0 \
        libgtk-3-0 \
        libgbm1 \
        libasound2t64 \
        # Vulkan runtime
        libvulkan1 \
        mesa-vulkan-drivers \
        vulkan-tools \
        # Networking tools
        curl \
        ca-certificates \
        # Font support
        fontconfig \
        fonts-liberation \
    && rm -rf /var/lib/apt/lists/* \
    && fc-cache -fv

# Create NVIDIA Vulkan ICD file pointing to the vulkan-producer library
# (The container toolkit injects this lib but the default ICD points to libGLX_nvidia which doesn't work)
RUN mkdir -p /usr/share/vulkan/icd.d && \
    echo '{"file_format_version":"1.0.0","ICD":{"library_path":"/usr/lib/x86_64-linux-gnu/libnvidia-vulkan-producer.so","api_version":"1.3.242"}}' \
    > /usr/share/vulkan/icd.d/nvidia_icd.json

# =============================================================================
# User Setup (security best practice)
# =============================================================================
ARG USERNAME=smelter
ARG USER_UID=1000
ARG USER_GID=1000

RUN if ! getent group ${USERNAME} > /dev/null 2>&1; then \
        (groupadd --gid ${USER_GID} ${USERNAME} 2>/dev/null || groupadd ${USERNAME}); \
    fi \
    && if ! getent passwd ${USERNAME} > /dev/null 2>&1; then \
        USER_GID_ACTUAL=$(getent group ${USERNAME} | cut -d: -f3); \
        (useradd --uid ${USER_UID} --gid ${USER_GID_ACTUAL} -m -s /bin/bash ${USERNAME} 2>/dev/null || \
         useradd --gid ${USER_GID_ACTUAL} -m -s /bin/bash ${USERNAME}); \
    fi \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME}

# Create application directories
RUN mkdir -p \
        /home/${USERNAME}/smelter/lib \
        /home/${USERNAME}/smelter/logs \
        /home/${USERNAME}/smelter/xdg_runtime \
        /home/${USERNAME}/smelter/downloads \
        /home/${USERNAME}/smelter/.cache \
    && chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}

# =============================================================================
# Copy Binaries from Builder
# =============================================================================
COPY --from=builder --chown=${USERNAME}:${USERNAME} \
    /build/target/release/main_process \
    /home/${USERNAME}/smelter/main_process

COPY --from=builder --chown=${USERNAME}:${USERNAME} \
    /build/target/release/process_helper \
    /home/${USERNAME}/smelter/process_helper

COPY --from=builder --chown=${USERNAME}:${USERNAME} \
    /build/target/release/lib \
    /home/${USERNAME}/smelter/lib

# Make binaries executable
RUN chmod +x /home/${USERNAME}/smelter/main_process \
    && chmod +x /home/${USERNAME}/smelter/process_helper

# =============================================================================
# Smelter Configuration (Production Defaults)
# =============================================================================
# Binary paths
ENV SMELTER_MAIN_EXECUTABLE_PATH=/home/${USERNAME}/smelter/main_process
ENV SMELTER_PROCESS_HELPER_PATH=/home/${USERNAME}/smelter/process_helper
# Include app libs + NVIDIA libs injected by container toolkit
ENV LD_LIBRARY_PATH=/home/${USERNAME}/smelter/lib:/usr/lib/x86_64-linux-gnu:/usr/lib64

# XDG runtime for DBus
ENV XDG_RUNTIME_DIR=/home/${USERNAME}/smelter/xdg_runtime

# API Configuration
ENV SMELTER_API_PORT=8081
ENV SMELTER_WHIP_WHEP_SERVER_PORT=9000
ENV SMELTER_START_WHIP_WHEP_SERVER=true

# GPU Configuration
ENV SMELTER_FORCE_GPU=true
ENV SMELTER_GPU_DEVICE_DRIVER=nvidia

# Rendering Configuration
ENV SMELTER_WEB_RENDERER_ENABLE=true
ENV SMELTER_WEB_RENDERER_GPU_ENABLE=true
ENV SMELTER_OUTPUT_FRAMERATE=30
ENV SMELTER_MIXING_SAMPLE_RATE=48000
ENV SMELTER_LOAD_SYSTEM_FONTS=true

# Production Logging (JSON for CloudWatch/ELK)
ENV SMELTER_LOGGER_FORMAT=json
ENV SMELTER_LOGGER_LEVEL="info,wgpu_hal=warn,wgpu_core=warn,webrtc_srtp::session=warn,naga=warn"
ENV SMELTER_FFMPEG_LOGGER_LEVEL=warn

# Download directory
ENV SMELTER_DOWNLOAD_DIR=/home/${USERNAME}/smelter/downloads

# Shader cache
ENV __GL_SHADER_DISK_CACHE=1
ENV __GL_SHADER_DISK_CACHE_PATH=/home/${USERNAME}/smelter/.cache

# =============================================================================
# Entrypoint Script
# =============================================================================
COPY --chmod=755 <<'ENTRYPOINT_SCRIPT' /home/${USERNAME}/smelter/entrypoint.sh
#!/usr/bin/env bash
set -eo pipefail

# =============================================================================
# Smelter Production Entrypoint
# Optimized for AWS NVIDIA EC2 instances
# =============================================================================

log() {
    echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] $*"
}

# -----------------------------------------------------------------------------
# GPU Verification
# -----------------------------------------------------------------------------
verify_gpu() {
    log "Verifying NVIDIA GPU access..."

    if command -v nvidia-smi &>/dev/null; then
        nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader || true
    else
        log "WARNING: nvidia-smi not available"
    fi

    # Verify the vulkan producer library is available (injected by container toolkit)
    if [ -f "/usr/lib/x86_64-linux-gnu/libnvidia-vulkan-producer.so" ]; then
        log "Found libnvidia-vulkan-producer.so"
    else
        log "WARNING: libnvidia-vulkan-producer.so not found - Vulkan may not work"
    fi

    # ICD file is created at build time, just verify it exists
    log "VK_ICD_FILENAMES=${VK_ICD_FILENAMES:-not set}"

    # Check Vulkan devices
    if command -v vulkaninfo &>/dev/null; then
        log "Checking Vulkan devices..."
        vulkaninfo --summary 2>&1 | grep -E "(deviceName|deviceType|vendorID)" | head -10 || {
            log "WARNING: vulkaninfo failed or found no GPU devices"
        }
    fi
}

# -----------------------------------------------------------------------------
# DBus Setup (required for CEF/Chromium)
# -----------------------------------------------------------------------------
setup_dbus() {
    log "Setting up DBus session..."

    export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"

    # Ensure runtime directory exists with correct permissions
    mkdir -p "${XDG_RUNTIME_DIR}"
    chmod 700 "${XDG_RUNTIME_DIR}"

    # Start system dbus if not running
    if ! pgrep -x dbus-daemon &>/dev/null; then
        sudo service dbus start 2>/dev/null || true
    fi

    # Start session dbus
    dbus-daemon --session --address="${DBUS_SESSION_BUS_ADDRESS}" --nofork --nopidfile --syslog-only &
    DBUS_PID=$!

    # Wait for DBus to be ready
    sleep 1

    log "DBus session started (PID: ${DBUS_PID})"
}

# -----------------------------------------------------------------------------
# Signal Handlers
# -----------------------------------------------------------------------------
cleanup() {
    log "Received shutdown signal, cleaning up..."

    # Kill main process gracefully
    if [[ -n "${MAIN_PID:-}" ]]; then
        kill -TERM "${MAIN_PID}" 2>/dev/null || true
        wait "${MAIN_PID}" 2>/dev/null || true
    fi

    # Kill DBus
    if [[ -n "${DBUS_PID:-}" ]]; then
        kill -TERM "${DBUS_PID}" 2>/dev/null || true
    fi

    log "Cleanup complete"
    exit 0
}

trap cleanup SIGTERM SIGINT SIGQUIT

# -----------------------------------------------------------------------------
# Health Check Endpoint (for AWS ALB/ECS)
# -----------------------------------------------------------------------------
wait_for_health() {
    local max_attempts=30
    local attempt=0

    while [[ ${attempt} -lt ${max_attempts} ]]; do
        if curl -sf "http://localhost:${SMELTER_API_PORT}/status" &>/dev/null; then
            log "Health check passed"
            return 0
        fi
        ((attempt++))
        sleep 1
    done

    log "WARNING: Health check did not pass within ${max_attempts} seconds"
    return 1
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    log "Starting Smelter (AWS NVIDIA EC2 optimized)"
    log "  API Port: ${SMELTER_API_PORT}"
    log "  WHIP/WHEP Port: ${SMELTER_WHIP_WHEP_SERVER_PORT}"
    log "  Web Renderer: ${SMELTER_WEB_RENDERER_ENABLE}"
    log "  GPU Driver: ${SMELTER_GPU_DEVICE_DRIVER:-auto}"

    # Refresh library cache to pick up NVIDIA libs injected by container toolkit
    sudo ldconfig 2>/dev/null || true

    verify_gpu
    setup_dbus

    log "Launching Smelter under Xvfb..."

    # Launch under Xvfb for headless X11
    # -a: auto-select display number
    # -s: screen configuration (24-bit color)
    xvfb-run -a -s "-screen 0 1920x1080x24" "${SMELTER_MAIN_EXECUTABLE_PATH}" &
    MAIN_PID=$!

    log "Smelter started (PID: ${MAIN_PID})"

    # Wait for health check in background
    wait_for_health &

    # Wait for main process
    wait "${MAIN_PID}"
    exit_code=$?

    log "Smelter exited with code: ${exit_code}"
    exit ${exit_code}
}

main "$@"
ENTRYPOINT_SCRIPT

# Fix ownership of entrypoint
RUN chown ${USERNAME}:${USERNAME} /home/${USERNAME}/smelter/entrypoint.sh

# =============================================================================
# Switch to Non-root User
# =============================================================================
USER ${USERNAME}
WORKDIR /home/${USERNAME}/smelter

# =============================================================================
# Health Check (for AWS ECS/EKS/ALB)
# =============================================================================
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -sf http://localhost:${SMELTER_API_PORT}/status || exit 1

# =============================================================================
# Expose Ports
# =============================================================================
# HTTP API
EXPOSE 8081
# RTMP (streaming)
EXPOSE 1935
# WHIP/WHEP (WebRTC)
EXPOSE 9000

# =============================================================================
# Entry Point
# =============================================================================
ENTRYPOINT ["./entrypoint.sh"]
