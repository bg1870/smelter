# Smelter Dockerfile
#
# This Dockerfile builds a Smelter HTTP server image with
# web‑rendering support.  It follows the guidance from the official
# Smelter documentation: the build stage installs build tools, FFmpeg
# and other libraries (required by Smelter) and compiles the project
# using cargo with default features (which includes the WebRenderer)
#【779638992328645†L202-L244】.  The runtime stage installs only the
# runtime dependencies such as ffmpeg, Xvfb and Mesa drivers and
# copies the compiled binaries and libraries.  An entrypoint script
# is used to launch the compositor under Xvfb with a DBus session,
# mirroring the official full Dockerfile provided by the Smelter
# project【215809594434415†L0-L70】.

# ----- Build stage ---------------------------------------------------
FROM ubuntu:noble-20250716 AS builder

# Use non‑interactive front‑end for apt
ENV DEBIAN_FRONTEND=noninteractive

# Smelter uses Rust edition 2024 which requires Rust 1.85+
ARG RUST_VERSION=stable

# Install development dependencies.  The Smelter docs list FFmpeg,
# libopus, SSL, pkg‑config and other libraries as prerequisites for
# building from source【779638992328645†L202-L233】.
RUN apt-get update -y -qq \
    && apt-get install -y --no-install-recommends \
      build-essential curl ca-certificates git pkg-config cmake libssl-dev libclang-dev sudo \
      libnss3 libatk1.0-0 libatk-bridge2.0-0 libgdk-pixbuf2.0-0 libgtk-3-0 \
      libegl1-mesa-dev libgl1-mesa-dri libxcb-xfixes0-dev mesa-vulkan-drivers \
      ffmpeg libavcodec-dev libavformat-dev libavfilter-dev \
      libavdevice-dev libavutil-dev libswscale-dev libswresample-dev libopus-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Rust toolchain.  Smelter is written in Rust and compiled with
# cargo【779638992328645†L202-L244】.
RUN curl https://sh.rustup.rs -sSf | bash -s -- -y \
    && . "$HOME/.cargo/env" \
    && rustup install "$RUST_VERSION" \
    && rustup default "$RUST_VERSION"
ENV PATH="$PATH:/root/.cargo/bin"

# Copy the Smelter project into the build context.  The working
# directory inside the container is set to the root of the project.
COPY . /root/project
WORKDIR /root/project

# Build the Smelter server with default features.  The default
# features include the `web-renderer` feature which brings in the
# Chromium Embedded Framework【406782852827269†L25-L30】.
RUN cargo build --release

# ----- Runtime stage -------------------------------------------------
FROM ubuntu:noble-20250716

LABEL org.opencontainers.image.source="https://github.com/software-mansion/smelter"

# NOTE: This container REQUIRES GPU access at runtime because Smelter
# requires the TEXTURE_BINDING_ARRAY WGPU feature which is not supported
# by software renderers (llvmpipe/lavapipe).
#
# Run with GPU access:
#   AMD/Intel: docker run --device /dev/dri <image-name>
#   NVIDIA:    docker run --gpus all --runtime=nvidia <image-name>

ENV DEBIAN_FRONTEND=noninteractive
ENV NVIDIA_DRIVER_CAPABILITIES="compute,graphics,utility"

# Create a non‑root user who will run the process.  Using a regular
# user improves security.
ARG USERNAME=smelter

# Install runtime dependencies.  The runtime image needs ffmpeg for
# media handling and the GTK and X11 libraries for CEF.  We also
# install `sudo` and `adduser` for user management and `xvfb` for
# headless X11 display【215809594434415†L30-L70】.
RUN apt-get update -y -qq \
    && apt-get install -y --no-install-recommends \
      sudo adduser ffmpeg libnss3 libatk1.0-0 libatk-bridge2.0-0 \
      libgdk-pixbuf2.0-0 libgtk-3-0 xvfb dbus \
    && rm -rf /var/lib/apt/lists/*

# After installing sudo, create a new user and grant it password‑less
# sudo privileges.  We avoid using `adduser` since it may not be
# available in minimal images.
RUN useradd -ms /bin/bash "$USERNAME" \
    && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
    && mkdir -p \
      /home/"$USERNAME"/smelter \
      /home/"$USERNAME"/smelter/lib \
      /home/"$USERNAME"/smelter/xdg_runtime

# Copy compiled binaries and dynamic libraries from the builder stage.
# Set ownership to the smelter user and make binaries executable.
COPY --from=builder --chown=$USERNAME:$USERNAME /root/project/target/release/main_process /home/$USERNAME/smelter/main_process
COPY --from=builder --chown=$USERNAME:$USERNAME /root/project/target/release/process_helper /home/$USERNAME/smelter/process_helper
COPY --from=builder --chown=$USERNAME:$USERNAME /root/project/target/release/lib /home/$USERNAME/smelter/lib

# Copy the entrypoint script into the image.  This script starts the
# DBus service and launches the Smelter compositor under Xvfb as
# performed by the official Dockerfile【215809594434415†L60-L69】.
COPY --chmod=755 --chown=$USERNAME:$USERNAME tools/docker/entrypoint.sh /home/$USERNAME/smelter/entrypoint.sh

# Switch to the non-root user and set working directory
USER "$USERNAME"
WORKDIR /home/"$USERNAME"/smelter

# Set environment variables required by Smelter.  The compositor uses
# these variables to locate its helper processes and libraries.
ENV SMELTER_MAIN_EXECUTABLE_PATH=/home/$USERNAME/smelter/main_process
ENV SMELTER_PROCESS_HELPER_PATH=/home/$USERNAME/smelter/process_helper
ENV LD_LIBRARY_PATH=/home/$USERNAME/smelter/lib
ENV XDG_RUNTIME_DIR=/home/$USERNAME/smelter/xdg_runtime

# Expose the default HTTP port.  When the container starts, the
# entrypoint script will launch Smelter, which listens on port 8081.
EXPOSE 8081

# Run the entrypoint script.  It starts a DBus session, then uses
# xvfb-run to execute the Smelter main process【703617412425487†L1-L10】.
ENTRYPOINT ["./entrypoint.sh"]