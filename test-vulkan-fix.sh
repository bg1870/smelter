#!/bin/bash
# Quick test to verify Vulkan fix - run on EC2

echo "Testing with libnvidia-vulkan-producer + libEGL..."
docker run --rm --gpus all \
    -e NVIDIA_DRIVER_CAPABILITIES=all \
    -v /usr/lib/x86_64-linux-gnu/libnvidia-vulkan-producer.so:/usr/lib/x86_64-linux-gnu/libnvidia-vulkan-producer.so:ro \
    -v /usr/lib/x86_64-linux-gnu/libnvidia-vulkan-producer.so.535.288.01:/usr/lib/x86_64-linux-gnu/libnvidia-vulkan-producer.so.535.288.01:ro \
    nvidia/cuda:12.6.3-runtime-ubuntu24.04 \
    bash -c '
        apt-get update -qq
        apt-get install -y -qq libx11-6 libxext6 libvulkan1 vulkan-tools libegl1 libgl1 libglx0 libglvnd0 >/dev/null 2>&1
        ldconfig

        echo "--- Check dependencies of vulkan-producer ---"
        ldd /usr/lib/x86_64-linux-gnu/libnvidia-vulkan-producer.so 2>&1 | grep "not found" || echo "All deps OK"

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
        vulkaninfo --summary 2>&1 | head -50
    '
