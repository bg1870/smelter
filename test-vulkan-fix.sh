#!/bin/bash
# Quick test to verify Vulkan fix - run on EC2

echo "Testing Vulkan with libnvidia-vulkan-producer.so ICD..."
docker run --rm --gpus all \
    -e NVIDIA_DRIVER_CAPABILITIES=all \
    nvidia/cuda:12.6.3-runtime-ubuntu24.04 \
    bash -c '
        apt-get update -qq
        apt-get install -y -qq libx11-6 libxext6 libxrandr2 libvulkan1 vulkan-tools libxcb1 >/dev/null 2>&1

        echo "--- NVIDIA Vulkan libs available ---"
        ldconfig -p | grep -i nvidia | grep -iE "(vulkan|glx)"

        echo ""
        echo "--- Creating ICD with vulkan-producer lib ---"
        mkdir -p /etc/vulkan/icd.d
        cat > /etc/vulkan/icd.d/nvidia_icd.json << EOF
{
    "file_format_version" : "1.0.0",
    "ICD": {
        "library_path": "libnvidia-vulkan-producer.so",
        "api_version" : "1.3.242"
    }
}
EOF

        echo "--- vulkaninfo ---"
        VK_ICD_FILENAMES=/etc/vulkan/icd.d/nvidia_icd.json vulkaninfo --summary 2>&1
    '
