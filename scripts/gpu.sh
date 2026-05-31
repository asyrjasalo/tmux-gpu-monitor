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
    # Read cached values from persistent daemon — returns instantly
    local val
    val="$(tmux show-option -gqv "@gpu_pct" 2>/dev/null)" || true
    [ -n "$val" ] || return 1
    printf " %s" "$val"
    return 0
}

gpu_linux_nvidia() {
    command -v nvidia-smi >/dev/null 2>&1 || return 1
    local out
    out="$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null)" || return 1
    [ -n "$out" ] || return 1
    local pct
    pct="$(echo "$out" | head -1 | tr -d '[:space:]')"
    [ -n "$pct" ] && printf " %3d%%" "$pct" || return 1

    # Set raw temp options for external formatting
    local gpu_temp
    gpu_temp="$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null)" || true
    if [ -n "$gpu_temp" ]; then
        gpu_temp="$(echo "$gpu_temp" | head -1 | tr -d '[:space:]')"
        [ -n "$gpu_temp" ] && tmux set-option -gq "@gpu_gpu_temp" "${gpu_temp}°C" 2>/dev/null || true
    fi

    return 0
}

gpu_linux_amd() {
    local drm="/sys/class/drm"
    [ -d "$drm" ] || return 1
    local card busy pct
    for card in "$drm"/card*; do
        busy="$card/device/gpu_busy_percent"
        if [ -f "$busy" ]; then
            pct="$(cat "$busy" 2>/dev/null)" || continue
            [ -n "$pct" ] && printf " %3d%%" "$pct" || continue

            # Set raw GPU temp option for external formatting
            for hwmon in "$card"/device/hwmon/hwmon*; do
                if [ -f "$hwmon/temp1_input" ]; then
                    local t
                    t="$(cat "$hwmon/temp1_input" 2>/dev/null)" || continue
                    [ -n "$t" ] && tmux set-option -gq "@gpu_gpu_temp" "$((t / 1000))°C" 2>/dev/null && break
                fi
            done

            return 0
        fi
    done
    return 1
}

_set_linux_cpu_temp() {
    local zone temp type
    for zone in /sys/class/thermal/thermal_zone*; do
        [ -f "$zone/temp" ] || continue
        temp="$(cat "$zone/temp" 2>/dev/null)" || continue
        [ -n "$temp" ] || continue
        [ -f "$zone/type" ] && type="$(cat "$zone/type" 2>/dev/null)" || true
        case "$type" in
            x86_pkg_temp|cpu*|acpi)
                tmux set-option -gq "@gpu_cpu_temp" "$((temp / 1000))°C" 2>/dev/null || true
                return 0
                ;;
        esac
    done
    # Fallback: first thermal zone with valid temp
    for zone in /sys/class/thermal/thermal_zone*; do
        [ -f "$zone/temp" ] || continue
        temp="$(cat "$zone/temp" 2>/dev/null)" || continue
        [ -n "$temp" ] && [ "$temp" -gt 0 ] 2>/dev/null || continue
        tmux set-option -gq "@gpu_cpu_temp" "$((temp / 1000))°C" 2>/dev/null || true
        return 0
    done
}

case "$(uname)" in
    Darwin)
        gpu_macos_macmon || echo ""
        ;;
    Linux)
        _set_linux_cpu_temp
        gpu_linux_nvidia || gpu_linux_amd || echo ""
        ;;
    *)
        echo ""
        ;;
esac
