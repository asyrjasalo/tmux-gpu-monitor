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
}
main
