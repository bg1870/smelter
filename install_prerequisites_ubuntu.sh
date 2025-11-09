#!/usr/bin/env bash

# Smelter Prerequisites Installation Script for Ubuntu Linux
# This script installs all required dependencies to build and run Smelter on Ubuntu
# Tested on Ubuntu 24.04 (noble)

set -eo pipefail

# Color output for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running on Ubuntu
if [ ! -f /etc/os-release ]; then
    echo_error "Cannot detect OS. This script is designed for Ubuntu Linux."
    exit 1
fi

source /etc/os-release
if [[ "$ID" != "ubuntu" ]]; then
    echo_warn "This script is designed for Ubuntu. Detected OS: $ID"
    echo_warn "Continuing anyway, but some packages may not be available..."
fi

echo_info "Installing Smelter prerequisites on Ubuntu $VERSION_ID..."
echo ""

# Update package lists
echo_info "Updating package lists..."
sudo apt-get update -y

# Install essential build tools and compilers
echo_info "Installing build tools and compilers..."
sudo apt-get install -y \
    build-essential \
    cmake \
    curl \
    git \
    pkg-config \
    ca-certificates

# Install C/C++ development tools
echo_info "Installing C/C++ development tools..."
sudo apt-get install -y \
    libclang-dev \
    libstdc++-dev \
    clang \
    llvm-dev

# Install cryptography and security libraries
echo_info "Installing OpenSSL and security libraries..."
sudo apt-get install -y \
    libssl-dev

# Install FFmpeg and media libraries
echo_info "Installing FFmpeg and media processing libraries..."
sudo apt-get install -y \
    ffmpeg \
    libavcodec-dev \
    libavformat-dev \
    libavfilter-dev \
    libavdevice-dev \
    libavutil-dev \
    libswscale-dev \
    libswresample-dev \
    libopus-dev

# Install graphics and Vulkan libraries
echo_info "Installing graphics and Vulkan libraries..."
sudo apt-get install -y \
    mesa-vulkan-drivers \
    libvulkan-dev \
    libegl1-mesa-dev \
    libgl1-mesa-dri

# Install X11 libraries
echo_info "Installing X11 libraries..."
sudo apt-get install -y \
    libx11-dev \
    libxcb-xfixes0-dev \
    xvfb

# Install D-Bus (required for CEF)
echo_info "Installing D-Bus..."
sudo apt-get install -y \
    dbus \
    dbus-x11

# Install GTK and related libraries (required for CEF)
echo_info "Installing GTK and CEF dependencies..."
sudo apt-get install -y \
    libgtk-3-0 \
    libgdk-pixbuf2.0-0 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libnss3

# Install system utilities
echo_info "Installing system utilities..."
sudo apt-get install -y \
    sudo \
    adduser

echo ""
echo_info "System packages installed successfully!"
echo ""

# Check if Rust is already installed
if command -v rustc &> /dev/null; then
    RUST_VERSION=$(rustc --version | awk '{print $2}')
    echo_info "Rust is already installed (version $RUST_VERSION)"

    # Check if version is sufficient (>= 1.85.0)
    REQUIRED_VERSION="1.85.0"
    if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$RUST_VERSION" | sort -V | head -n1)" = "$REQUIRED_VERSION" ]; then
        echo_info "Rust version is sufficient (>= $REQUIRED_VERSION)"
    else
        echo_warn "Rust version $RUST_VERSION is older than required $REQUIRED_VERSION"
        echo_warn "Consider updating Rust with: rustup update"
    fi
else
    echo_warn "Rust is not installed."
    echo_info "Installing Rust via rustup..."

    # Install Rust
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

    # Source cargo environment
    source "$HOME/.cargo/env"

    echo_info "Rust installed successfully!"
    rustc --version
fi

echo ""
echo_info "============================================"
echo_info "Prerequisites installation complete!"
echo_info "============================================"
echo ""

# Provide next steps
echo_info "Next steps:"
echo "  1. If you just installed Rust, restart your terminal or run:"
echo "     source \$HOME/.cargo/env"
echo ""
echo "  2. Initialize git submodules:"
echo "     git submodule update --init --checkout"
echo ""
echo "  3. Build Smelter:"
echo "     cargo build --release"
echo ""
echo "  4. (Optional) For DeckLink support:"
echo "     cargo build --release --features decklink"
echo ""

# Check for GPU/Vulkan support
echo_info "Checking Vulkan support..."
if command -v vulkaninfo &> /dev/null; then
    echo_info "vulkaninfo is available. Run 'vulkaninfo' to check your GPU support."
else
    echo_warn "vulkaninfo not found. Install vulkan-tools to verify GPU support:"
    echo "     sudo apt-get install vulkan-tools"
fi

# Check for NVIDIA GPU
if lspci | grep -i nvidia &> /dev/null; then
    echo_warn "NVIDIA GPU detected. You may need to install NVIDIA drivers:"
    echo "     sudo apt-get install nvidia-driver-XXX"
    echo "     (Replace XXX with appropriate version number)"
fi

echo ""
echo_info "Installation script completed successfully!"
