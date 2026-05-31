#!/usr/bin/env bash
# GPU usage monitor for tmux status bar.
#
# Supported platforms:
#   macOS (Apple Silicon): uses `macmon` CLI (sudoless)
#   Linux NVIDIA: uses `nvidia-smi`
#   Linux AMD: reads /sys/class/drm/card*/device/gpu_busy_percent
#   Other: prints empty string
set -euo pipefail

interval=1
while getopts "i:" opt; do
    case $opt in
        i) interval="$OPTARG" ;;
        *) ;;
    esac
done

gpu_macos_macmon() {
    command -v macmon >/dev/null 2>&1 || return 1
    local line
    # head -1 reads one JSON line then exits; macmon dies from SIGPIPE
    line="$(macmon pipe -i "$((interval * 1000))" 2>/dev/null | head -1)" || true
    [ -n "$line" ] || return 1
    # gpu_usage: [int, float] — second element is usage ratio 0..1
    local pct
    pct="$(echo "$line" | jq -r '(.gpu_usage[1] * 100 | round | tostring) + "%"' 2>/dev/null)" || return 1
    [ -n "$pct" ] && [ "$pct" != "null" ] && [ "$pct" != "null%" ] && printf "%3s" "$pct" && return 0
    return 1
}

gpu_linux_nvidia() {
    command -v nvidia-smi >/dev/null 2>&1 || return 1
    local out
    out="$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null)" || return 1
    [ -n "$out" ] || return 1
    local pct
    pct="$(echo "$out" | head -1 | tr -d '[:space:]')"
    [ -n "$pct" ] && printf "%3d%%" "$pct" && return 0
    return 1
}

gpu_linux_amd() {
    local drm="/sys/class/drm"
    [ -d "$drm" ] || return 1
    local card busy pct
    for card in "$drm"/card*; do
        busy="$card/device/gpu_busy_percent"
        if [ -f "$busy" ]; then
            pct="$(cat "$busy" 2>/dev/null)" || continue
            [ -n "$pct" ] && printf "%3d%%" "$pct" && return 0
        fi
    done
    return 1
}

case "$(uname)" in
    Darwin)
        gpu_macos_macmon || echo ""
        ;;
    Linux)
        gpu_linux_nvidia || gpu_linux_amd || echo ""
        ;;
    *)
        echo ""
        ;;
esac
