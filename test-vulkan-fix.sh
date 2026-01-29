#!/bin/bash
# Quick test to verify Vulkan fix - run on EC2

echo "=========================================="
echo "1. Check what nvidia-container-cli exposes"
echo "=========================================="
nvidia-container-cli info 2>/dev/null || echo "nvidia-container-cli not found"

echo ""
echo "=========================================="
echo "2. Test with explicit capabilities"
echo "=========================================="
docker run --rm --gpus all \
    -e NVIDIA_DRIVER_CAPABILITIES=graphics,compute,utility,video,display \
    nvidia/cuda:12.6.3-runtime-ubuntu24.04 \
    bash -c '
        echo "--- All NVIDIA libs injected ---"
        ldconfig -p | grep -i nvidia
    '

echo ""
echo "=========================================="
echo "3. Test with --privileged (full access)"
echo "=========================================="
docker run --rm --gpus all --privileged \
    -e NVIDIA_DRIVER_CAPABILITIES=all \
    -v /dev:/dev \
    nvidia/cuda:12.6.3-runtime-ubuntu24.04 \
    bash -c '
        apt-get update -qq
        apt-get install -y -qq libx11-6 libxext6 libvulkan1 vulkan-tools >/dev/null 2>&1

        echo "--- NVIDIA libs ---"
        ldconfig -p | grep -i nvidia | grep -iE "(vulkan|glx|producer)"

        echo ""
        echo "--- Check if vulkan producer exists anywhere ---"
        find /usr -name "*vulkan*producer*" 2>/dev/null || echo "Not found in /usr"
        find /lib* -name "*vulkan*producer*" 2>/dev/null || echo "Not found in /lib"
    '

echo ""
echo "=========================================="
echo "4. Mount host NVIDIA libs directly"
echo "=========================================="
docker run --rm --gpus all \
    -e NVIDIA_DRIVER_CAPABILITIES=all \
    -v /usr/lib/x86_64-linux-gnu/libnvidia-vulkan-producer.so:/usr/lib/x86_64-linux-gnu/libnvidia-vulkan-producer.so:ro \
    -v /usr/lib/x86_64-linux-gnu/libnvidia-vulkan-producer.so.535.288.01:/usr/lib/x86_64-linux-gnu/libnvidia-vulkan-producer.so.535.288.01:ro \
    nvidia/cuda:12.6.3-runtime-ubuntu24.04 \
    bash -c '
        apt-get update -qq
        apt-get install -y -qq libx11-6 libxext6 libvulkan1 vulkan-tools >/dev/null 2>&1
        ldconfig

        echo "--- Check vulkan producer ---"
        ls -la /usr/lib/x86_64-linux-gnu/libnvidia-vulkan-producer* 2>/dev/null

        echo ""
        mkdir -p /etc/vulkan/icd.d
        cat > /etc/vulkan/icd.d/nvidia_icd.json << EOF
{
    "file_format_version" : "1.0.0",
    "ICD": {
        "library_path": "/usr/lib/x86_64-linux-gnu/libnvidia-vulkan-producer.so",
        "api_version" : "1.3.242"
    }
}
EOF

        echo "--- vulkaninfo ---"
        vulkaninfo --summary 2>&1
    '
