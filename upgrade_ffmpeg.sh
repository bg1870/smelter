#!/bin/bash
# Upgrade FFmpeg to version 6.x for Smelter compatibility

set -e

echo "Adding FFmpeg 6.x PPA repository..."
sudo add-apt-repository ppa:ubuntuhandbook1/ffmpeg6 -y

echo "Updating package lists..."
sudo apt-get update

echo "Installing FFmpeg 6.x and development libraries..."
sudo apt-get install -y ffmpeg libavutil-dev libavcodec-dev libavformat-dev \
    libavfilter-dev libavdevice-dev libswscale-dev libswresample-dev

echo "Verifying FFmpeg version..."
ffmpeg -version | head -1
pkg-config --modversion libavutil

echo ""
echo "FFmpeg upgrade complete!"
