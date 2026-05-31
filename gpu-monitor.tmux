#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# $1: option name
# $2: default value
get_tmux_option() {
    local value
    value="$(tmux show-option -gqv "$1")"
    [ -n "$value" ] && echo "$value" || echo "$2"
}

# $1: option name
# $2: value
set_tmux_option() {
    tmux set-option -gq "$1" "$2"
}

# Replace #{gpu} and #{gpu ...} with the shell command
update_placeholder() {
    local option="$1"
    local option_value
    option_value="$(tmux show-option -gqv "$option")"

    # Match #{gpu} or #{gpu ...} (with optional flags)
    local placeholder_pat='\#[{]gpu[^}]*[}]'
    if echo "$option_value" | grep -qE "$placeholder_pat"; then
        # Extract flags if any: #{gpu -i 2} -> " -i 2"
        local flags
        flags="$(echo "$option_value" | sed -n 's/.*#{gpu\([^}]*\)}.*/\1/p')"
        local command="#($CURRENT_DIR/scripts/gpu.sh$flags)"
        local new_value
        # Use sed for the replacement
        new_value="$(echo "$option_value" | sed "s|#{gpu[^}]*}|$command|g")"
        set_tmux_option "$option" "$new_value"
    fi
}

main() {
    update_placeholder "status-right"
    update_placeholder "status-left"
    start_daemon
}

# Start persistent macmon daemon on macOS (instant reads via @gpu_pct)
start_daemon() {
    [ "$(uname)" = "Darwin" ] || return 0
    command -v macmon >/dev/null 2>&1 || return 0

    local interval
    interval="$(get_tmux_option "@gpu_interval" "1")"

    # Kill stale daemon if any (check by locked PID)
    local pidfile="/tmp/tmux-gpu-daemon.pid"
    if [ -f "$pidfile" ]; then
        local oldpid
        oldpid="$(cat "$pidfile" 2>/dev/null)" || true
        if [ -n "$oldpid" ] && kill -0 "$oldpid" 2>/dev/null; then
            return 0  # daemon already running
        fi
    fi

    "$CURRENT_DIR/scripts/gpu-daemon.sh" -i "$interval" &
    echo $! > "$pidfile"
}

main
