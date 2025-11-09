#!/usr/bin/env bash

# Install FFmpeg 6.x from source for Smelter compatibility
# This script is useful when the PPA repository doesn't work on your Ubuntu version

set -eo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# FFmpeg version to install
FFMPEG_VERSION="6.1.2"
FFMPEG_URL="https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz"
BUILD_DIR="/tmp/ffmpeg-build-$$"
INSTALL_PREFIX="/usr/local"

echo_info "Building FFmpeg ${FFMPEG_VERSION} from source..."
echo_warn "This may take 10-30 minutes depending on your system."
echo ""

# Install build dependencies
echo_info "Installing build dependencies..."
sudo apt-get update -y
sudo apt-get install -y \
    build-essential \
    yasm \
    nasm \
    pkg-config \
    libx264-dev \
    libx265-dev \
    libvpx-dev \
    libfdk-aac-dev \
    libmp3lame-dev \
    libopus-dev \
    libvorbis-dev \
    libass-dev \
    libfreetype6-dev \
    libgnutls28-dev \
    libsdl2-dev \
    libtool \
    wget

# Create build directory
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Download FFmpeg
echo_info "Downloading FFmpeg ${FFMPEG_VERSION}..."
wget -q --show-progress "$FFMPEG_URL"
tar -xf "ffmpeg-${FFMPEG_VERSION}.tar.xz"
cd "ffmpeg-${FFMPEG_VERSION}"

# Configure FFmpeg
echo_info "Configuring FFmpeg build..."
./configure \
    --prefix="$INSTALL_PREFIX" \
    --enable-gpl \
    --enable-version3 \
    --enable-nonfree \
    --enable-shared \
    --disable-static \
    --enable-libx264 \
    --enable-libx265 \
    --enable-libvpx \
    --enable-libfdk-aac \
    --enable-libmp3lame \
    --enable-libopus \
    --enable-libvorbis \
    --enable-libass \
    --enable-libfreetype \
    --enable-gnutls \
    --enable-sdl2 \
    --disable-doc \
    --disable-htmlpages \
    --disable-manpages \
    --disable-podpages \
    --disable-txtpages

# Build FFmpeg (use all available CPU cores)
echo_info "Building FFmpeg (this will take a while)..."
NPROC=$(nproc)
make -j"$NPROC"

# Install FFmpeg
echo_info "Installing FFmpeg to ${INSTALL_PREFIX}..."
sudo make install

# Update shared library cache
echo_info "Updating library cache..."
sudo ldconfig

# Clean up build directory
echo_info "Cleaning up build files..."
cd /
rm -rf "$BUILD_DIR"

# Verify installation
echo ""
echo_info "============================================"
echo_info "FFmpeg installation complete!"
echo_info "============================================"
echo ""

INSTALLED_VERSION=$(ffmpeg -version | head -1)
echo_info "Installed: $INSTALLED_VERSION"
echo ""

# Check if version is correct
if ffmpeg -version | grep -q "version ${FFMPEG_VERSION}"; then
    echo_info "FFmpeg ${FFMPEG_VERSION} successfully installed!"
else
    echo_warn "FFmpeg version may not match expected version."
    echo_warn "Please verify with: ffmpeg -version"
fi

echo ""
echo_info "Development libraries location:"
echo "  - Headers: ${INSTALL_PREFIX}/include"
echo "  - Libraries: ${INSTALL_PREFIX}/lib"
echo ""
echo_info "pkg-config should now find FFmpeg libraries:"
pkg-config --modversion libavutil || echo_warn "pkg-config cannot find libavutil"
echo ""
echo_info "You can now build Smelter with: cargo build --release"
