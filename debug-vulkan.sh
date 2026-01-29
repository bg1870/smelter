#!/bin/bash
# Quick Vulkan debugging script for AWS EC2 NVIDIA instances
# Run this directly on the EC2 host (not in container)

set -e

echo "=========================================="
echo "1. Host GPU Info"
echo "=========================================="
nvidia-smi --query-gpu=name,driver_version --format=csv,noheader

echo ""
echo "=========================================="
echo "2. Host Vulkan ICD Files"
echo "=========================================="
echo "--- /usr/share/vulkan/icd.d/ ---"
ls -la /usr/share/vulkan/icd.d/ 2>/dev/null || echo "Directory not found"
echo ""
echo "--- /etc/vulkan/icd.d/ ---"
ls -la /etc/vulkan/icd.d/ 2>/dev/null || echo "Directory not found"

echo ""
echo "=========================================="
echo "3. NVIDIA ICD File Contents"
echo "=========================================="
for f in /usr/share/vulkan/icd.d/nvidia*.json /etc/vulkan/icd.d/nvidia*.json; do
    if [ -f "$f" ]; then
        echo "--- $f ---"
        cat "$f"
        echo ""
    fi
done

echo ""
echo "=========================================="
echo "4. NVIDIA Vulkan Libraries on Host"
echo "=========================================="
echo "Looking for libGLX_nvidia and libnvidia-vulkan-producer..."
ldconfig -p | grep -i nvidia | grep -iE "(glx|vulkan)" || echo "No NVIDIA Vulkan libs found in ldconfig"
echo ""
echo "Direct file search:"
find /usr/lib* -name "*nvidia*vulkan*" -o -name "libGLX_nvidia*" 2>/dev/null | head -20 || echo "None found"

echo ""
echo "=========================================="
echo "5. Host Vulkan Test"
echo "=========================================="
if command -v vulkaninfo &>/dev/null; then
    echo "Running vulkaninfo --summary on host..."
    vulkaninfo --summary 2>&1 | head -40 || echo "vulkaninfo failed"
else
    echo "vulkaninfo not installed on host. Install with: sudo apt install vulkan-tools"
fi

echo ""
echo "=========================================="
echo "6. Docker NVIDIA Runtime Test"
echo "=========================================="
echo "Testing minimal NVIDIA container with Vulkan..."
docker run --rm --gpus all \
    -e NVIDIA_DRIVER_CAPABILITIES=all \
    nvidia/cuda:12.6.3-runtime-ubuntu24.04 \
    bash -c '
        echo "--- Inside container ---"
        echo "nvidia-smi:"
        nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || echo "nvidia-smi failed"

        echo ""
        echo "NVIDIA libs in container:"
        ldconfig -p 2>/dev/null | grep -i nvidia | head -10 || echo "No nvidia libs"

        echo ""
        echo "Vulkan ICD files in container:"
        ls -la /usr/share/vulkan/icd.d/ 2>/dev/null || echo "No /usr/share/vulkan/icd.d/"
        ls -la /etc/vulkan/icd.d/ 2>/dev/null || echo "No /etc/vulkan/icd.d/"
    '

echo ""
echo "=========================================="
echo "7. Docker Vulkan Test with Host ICD Mount"
echo "=========================================="
echo "Testing with Vulkan tools and host ICD mounted..."
docker run --rm --gpus all \
    -e NVIDIA_DRIVER_CAPABILITIES=all \
    -v /usr/share/vulkan/icd.d:/usr/share/vulkan/icd.d:ro \
    nvidia/cuda:12.6.3-runtime-ubuntu24.04 \
    bash -c '
        apt-get update -qq && apt-get install -y -qq vulkan-tools libvulkan1 >/dev/null 2>&1

        echo "--- Vulkan ICD files ---"
        ls -la /usr/share/vulkan/icd.d/

        echo ""
        echo "--- ICD contents ---"
        cat /usr/share/vulkan/icd.d/nvidia*.json 2>/dev/null || echo "No nvidia ICD"

        echo ""
        echo "--- NVIDIA Vulkan libs ---"
        ldconfig -p | grep -iE "nvidia.*(glx|vulkan)" || echo "No NVIDIA Vulkan libs"

        echo ""
        echo "--- vulkaninfo ---"
        VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.json vulkaninfo --summary 2>&1 | head -30 || echo "vulkaninfo failed"
    '

echo ""
echo "=========================================="
echo "DIAGNOSIS"
echo "=========================================="
echo "If step 5 (host vulkaninfo) fails: Install NVIDIA Vulkan on host"
echo "  -> sudo apt install nvidia-driver-535 libnvidia-gl-535"
echo ""
echo "If step 6 shows no NVIDIA libs: Container toolkit not injecting drivers"
echo "  -> Check: nvidia-container-cli info"
echo ""
echo "If step 7 vulkaninfo fails: ICD points to missing library"
echo "  -> The ICD JSON references a library path that doesn't exist in container"
