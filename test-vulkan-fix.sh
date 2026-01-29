#!/bin/bash
# Quick test to verify the X11 library fix for Vulkan
# Run on EC2 - no rebuild needed

echo "Testing Vulkan with X11 libs installed..."
docker run --rm --gpus all \
    -e NVIDIA_DRIVER_CAPABILITIES=all \
    -v /usr/share/vulkan/icd.d:/usr/share/vulkan/icd.d:ro \
    nvidia/cuda:12.6.3-runtime-ubuntu24.04 \
    bash -c '
        echo "Installing X11 libs and Vulkan tools..."
        apt-get update -qq
        apt-get install -y -qq libx11-6 libxext6 libxrandr2 libvulkan1 vulkan-tools >/dev/null 2>&1

        echo ""
        echo "--- Checking libGLX_nvidia dependencies ---"
        ldd /usr/lib/x86_64-linux-gnu/libGLX_nvidia.so.0 2>/dev/null | grep -E "(not found|libX)" || echo "Library check failed"

        echo ""
        echo "--- Running vulkaninfo ---"
        VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.json vulkaninfo --summary 2>&1
    '

echo ""
echo "If vulkaninfo shows the Tesla T4, the fix works!"
