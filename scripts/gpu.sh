#!/usr/bin/env bash
# GPU usage monitor for tmux status bar.
#
# Supported platforms:
#   macOS (Apple Silicon): reads @gpu_pct from persistent gpu-daemon (instant)
#   Linux NVIDIA: uses `nvidia-smi`
#   Linux AMD: reads /sys/class/drm/card*/device/gpu_busy_percent
#   Other: prints empty string
set -euo pipefail

gpu_macos_macmon() {
    # Read cached value from persistent daemon — returns instantly
    local val
    val="$(tmux show-option -gqv "@gpu_pct" 2>/dev/null)" || true
    [ -n "$val" ] && printf "%s" "$val" && return 0
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
