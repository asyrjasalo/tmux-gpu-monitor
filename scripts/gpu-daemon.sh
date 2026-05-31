#!/usr/bin/env bash
# Persistent GPU daemon for macOS (Apple Silicon).
# Runs macmon pipe in background, keeps tmux @gpu_pct option updated.
# Killed automatically when tmux server exits (child of tmux server process).
set -euo pipefail

interval=1
while getopts "i:" opt; do
    case $opt in
        i) interval="$OPTARG" ;;
        *) ;;
    esac
done

# Only needed on macOS with macmon
if [ "$(uname)" != "Darwin" ]; then
    exit 0
fi

command -v macmon >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

# Set initial value so first status render shows something
tmux set-option -gq "@gpu_pct" "" 2>/dev/null || true

# Run macmon pipe continuously, update tmux option on each line
# Use process substitution so while loop runs in main shell (can detect tmux exit)
while IFS= read -r line; do
    [ -n "$line" ] || continue
    pct="$(echo "$line" | jq -r '(.gpu_usage[1] * 100 | round | tostring) + "%"' 2>/dev/null)" || continue
    [ -n "$pct" ] && [ "$pct" != "null" ] && [ "$pct" != "null%" ] || continue
    tmux set-option -gq "@gpu_pct" "$(printf "%3s" "$pct")" 2>/dev/null || exit 0
done < <(macmon pipe -i "$((interval * 1000))" 2>/dev/null)
