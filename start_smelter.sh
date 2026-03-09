#!/bin/bash
#
# Smelter Production Run Script
# Optimized for NVIDIA RTX 3050 (4GB VRAM)
#
# Usage:
#   ./start_smelter.sh              # Start in foreground
#   ./start_smelter.sh --daemon     # Start in background
#   ./start_smelter.sh --stop       # Stop running instance
#   ./start_smelter.sh --status     # Check status
#

set -euo pipefail

# ==============================================================================
# Configuration
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SMELTER_HOME="${SCRIPT_DIR}"
LOG_DIR="${SMELTER_HOME}/logs"
PID_FILE="${SMELTER_HOME}/smelter.pid"
LOG_FILE="${LOG_DIR}/smelter.log"

# ==============================================================================
# NVIDIA GPU Configuration
# ==============================================================================
export SMELTER_FORCE_GPU=true
export SMELTER_GPU_DEVICE_DRIVER=nvidia
# export SMELTER_GPU_DEVICE_ID=0  # Uncomment if you have multiple GPUs

# NVIDIA driver capabilities for CUDA/Vulkan
export NVIDIA_DRIVER_CAPABILITIES="compute,graphics,utility,video"
export __GL_SHADER_DISK_CACHE=1
export __GL_SHADER_DISK_CACHE_PATH="${SMELTER_HOME}/.gl_cache"

# Vulkan settings for NVIDIA
export VK_ICD_FILENAMES="/usr/share/vulkan/icd.d/nvidia_icd.json"
export VK_LOADER_DEBUG=error

# ==============================================================================
# Binary Paths
# ==============================================================================
export SMELTER_MAIN_EXECUTABLE_PATH="${SMELTER_HOME}/target/release/main_process"
export SMELTER_PROCESS_HELPER_PATH="${SMELTER_HOME}/target/release/process_helper"
export LD_LIBRARY_PATH="${SMELTER_HOME}/target/release/lib:${LD_LIBRARY_PATH:-}"

# ==============================================================================
# API & Network Configuration
# ==============================================================================
export SMELTER_API_PORT=8081
export SMELTER_WHIP_WHEP_SERVER_PORT=9000
export SMELTER_START_WHIP_WHEP_SERVER=true
export SMELTER_STUN_SERVERS="stun:stun.l.google.com:19302,stun:stun1.l.google.com:19302"
# export SMELTER_START_RTMP_SERVER=false

# ==============================================================================
# Rendering Configuration
# ==============================================================================
export SMELTER_WEB_RENDERER_ENABLE=true
export SMELTER_WEB_RENDERER_GPU_ENABLE=true
export SMELTER_OUTPUT_FRAMERATE=30
export SMELTER_MIXING_SAMPLE_RATE=48000

# GPU-optimized rendering (set to true for CPU-optimized if VRAM limited)
export SMELTER_FORCE_CPU_OPTIMIZED_RENDERING_MODE=false

# Buffer configuration for real-time streaming (lower = less latency, higher = more stability)
export SMELTER_INPUT_BUFFER_DURATION_MS=500
export SMELTER_STREAM_FALLBACK_TIMEOUT_MS=2000

# ==============================================================================
# Production Logging
# ==============================================================================
export SMELTER_LOGGER_FORMAT=json
export SMELTER_LOGGER_LEVEL="debug"
export SMELTER_FFMPEG_LOGGER_LEVEL="debug"
export SMELTER_LOG_FILE="${LOG_FILE}"

# ==============================================================================
# Performance Settings
# ==============================================================================
export SMELTER_LOAD_SYSTEM_FONTS=true
export SMELTER_NEVER_DROP_OUTPUT_FRAMES=false
export SMELTER_RUN_LATE_SCHEDULED_EVENTS=false

# Instance ID for multi-instance setups
export SMELTER_INSTANCE_ID="smelter_prod_$(hostname)"

# ==============================================================================
# Helper Functions
# ==============================================================================
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" >&2
}

check_nvidia_gpu() {
    if ! command -v nvidia-smi &>/dev/null; then
        error "nvidia-smi not found. Please install NVIDIA drivers."
        return 1
    fi

    if ! nvidia-smi &>/dev/null; then
        error "NVIDIA GPU not accessible. Check driver installation."
        return 1
    fi

    log "NVIDIA GPU detected:"
    nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader | while read -r line; do
        log "  $line"
    done
}

check_vulkan() {
    if command -v vulkaninfo &>/dev/null; then
        if vulkaninfo --summary 2>/dev/null | grep -q "NVIDIA"; then
            log "Vulkan NVIDIA support confirmed"
            return 0
        fi
    fi
    log "Warning: Could not verify Vulkan support (vulkaninfo not available)"
    return 0
}

check_port() {
    local port=$1
    if ss -tuln | grep -q ":${port} "; then
        error "Port ${port} is already in use"
        return 1
    fi
    return 0
}

check_binary() {
    if [[ ! -x "${SMELTER_MAIN_EXECUTABLE_PATH}" ]]; then
        log "Binary not found or not executable. Building..."
        build_release
    fi
}

build_release() {
    log "Building release version..."
    cd "${SMELTER_HOME}"
    cargo build --release --bin main_process --bin process_helper
    if [[ $? -ne 0 ]]; then
        error "Build failed"
        exit 1
    fi
    log "Build completed successfully"
}

setup_dbus() {
    # Required for Chromium/CEF web renderer
    if [[ "${SMELTER_WEB_RENDERER_ENABLE}" == "true" ]]; then
        export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
        export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=${XDG_RUNTIME_DIR}/bus}"

        # Start dbus-daemon if not running
        if ! pgrep -u "$(id -u)" dbus-daemon &>/dev/null; then
            log "Starting DBus session daemon..."
            dbus-daemon --session --address="${DBUS_SESSION_BUS_ADDRESS}" --nofork --nopidfile &>/dev/null &
            sleep 1
        fi
    fi
}

get_pid() {
    if [[ -f "${PID_FILE}" ]]; then
        cat "${PID_FILE}"
    fi
}

is_running() {
    local pid
    pid=$(get_pid)
    if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
        return 0
    fi
    return 1
}

stop_smelter() {
    local pid
    pid=$(get_pid)

    if [[ -z "${pid}" ]]; then
        log "No PID file found"
        # Try to find and kill any running instance
        pkill -f "main_process" 2>/dev/null || true
        return 0
    fi

    if kill -0 "${pid}" 2>/dev/null; then
        log "Stopping Smelter (PID: ${pid})..."
        kill -TERM "${pid}" 2>/dev/null

        # Wait for graceful shutdown (up to 10 seconds)
        local count=0
        while kill -0 "${pid}" 2>/dev/null && [[ ${count} -lt 10 ]]; do
            sleep 1
            ((count++))
        done

        # Force kill if still running
        if kill -0 "${pid}" 2>/dev/null; then
            log "Forcing shutdown..."
            kill -KILL "${pid}" 2>/dev/null
        fi

        log "Smelter stopped"
    else
        log "Process not running (stale PID file)"
    fi

    rm -f "${PID_FILE}"
}

start_smelter() {
    local daemon_mode="${1:-false}"

    # Pre-flight checks
    log "Running pre-flight checks..."
    check_nvidia_gpu || exit 1
    check_vulkan
    check_port "${SMELTER_API_PORT}" || exit 1
    check_port "${SMELTER_WHIP_WHEP_SERVER_PORT}" || exit 1
    check_binary

    # Setup
    mkdir -p "${LOG_DIR}"
    mkdir -p "${__GL_SHADER_DISK_CACHE_PATH}"
    setup_dbus

    # Check if already running
    if is_running; then
        error "Smelter is already running (PID: $(get_pid))"
        exit 1
    fi

    log "Starting Smelter..."
    log "  API Port: ${SMELTER_API_PORT}"
    log "  WHIP/WHEP Port: ${SMELTER_WHIP_WHEP_SERVER_PORT}"
    log "  GPU: NVIDIA (driver: nvidia)"
    log "  Web Renderer: ${SMELTER_WEB_RENDERER_ENABLE}"
    log "  Log File: ${LOG_FILE}"

    cd "${SMELTER_HOME}"

    if [[ "${daemon_mode}" == "true" ]]; then
        # Daemon mode - run in background
        if [[ "${SMELTER_WEB_RENDERER_ENABLE}" == "true" ]] && [[ -z "${DISPLAY:-}" ]]; then
            # Use xvfb-run for headless web renderer
            nohup xvfb-run -a "${SMELTER_MAIN_EXECUTABLE_PATH}" >> "${LOG_FILE}" 2>&1 &
        else
            nohup "${SMELTER_MAIN_EXECUTABLE_PATH}" >> "${LOG_FILE}" 2>&1 &
        fi
        local pid=$!
        echo "${pid}" > "${PID_FILE}"

        # Wait a moment and verify it started
        sleep 2
        if kill -0 "${pid}" 2>/dev/null; then
            log "Smelter started in background (PID: ${pid})"
            log "Logs: tail -f ${LOG_FILE}"
        else
            error "Smelter failed to start. Check logs: ${LOG_FILE}"
            rm -f "${PID_FILE}"
            exit 1
        fi
    else
        # Foreground mode
        echo $$ > "${PID_FILE}"
        trap 'rm -f "${PID_FILE}"; exit' INT TERM EXIT

        if [[ "${SMELTER_WEB_RENDERER_ENABLE}" == "true" ]] && [[ -z "${DISPLAY:-}" ]]; then
            # Use xvfb-run for headless web renderer
            exec xvfb-run -a "${SMELTER_MAIN_EXECUTABLE_PATH}"
        else
            exec "${SMELTER_MAIN_EXECUTABLE_PATH}"
        fi
    fi
}

show_status() {
    if is_running; then
        local pid
        pid=$(get_pid)
        log "Smelter is running (PID: ${pid})"

        # Show resource usage
        if command -v ps &>/dev/null; then
            ps -p "${pid}" -o pid,ppid,%cpu,%mem,etime,args --no-headers 2>/dev/null || true
        fi

        # Show GPU usage
        log "GPU Status:"
        nvidia-smi --query-compute-apps=pid,used_gpu_memory,name --format=csv,noheader 2>/dev/null | grep "${pid}" || echo "  No GPU memory allocated yet"

        # Health check API
        if command -v curl &>/dev/null; then
            if curl -sf "http://localhost:${SMELTER_API_PORT}/status" >/dev/null 2>&1; then
                log "API Status: healthy"
            else
                log "API Status: not responding"
            fi
        fi
    else
        log "Smelter is not running"
        exit 1
    fi
}

show_help() {
    cat << EOF
Smelter Production Run Script

Usage: $(basename "$0") [OPTION]

Options:
    --daemon, -d    Start Smelter in background (daemon mode)
    --stop          Stop running Smelter instance
    --status, -s    Show status of Smelter
    --build, -b     Build release binary only
    --help, -h      Show this help message

Environment Variables (can override defaults):
    SMELTER_API_PORT              HTTP API port (default: 8081)
    SMELTER_WHIP_WHEP_SERVER_PORT WHIP/WHEP port (default: 9000)
    SMELTER_OUTPUT_FRAMERATE      Output framerate (default: 30)
    SMELTER_WEB_RENDERER_ENABLE   Enable web renderer (default: true)
    SMELTER_LOGGER_LEVEL          Log level filter

Examples:
    ./$(basename "$0")              # Start in foreground
    ./$(basename "$0") --daemon     # Start as daemon
    ./$(basename "$0") --stop       # Stop daemon
    ./$(basename "$0") --status     # Check if running

EOF
}

# ==============================================================================
# Main
# ==============================================================================
main() {
    case "${1:-}" in
        --daemon|-d)
            start_smelter true
            ;;
        --stop)
            stop_smelter
            ;;
        --status|-s)
            show_status
            ;;
        --build|-b)
            build_release
            ;;
        --help|-h)
            show_help
            ;;
        "")
            start_smelter false
            ;;
        *)
            error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
