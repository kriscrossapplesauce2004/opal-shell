#!/usr/bin/env bash
# Create uinput touch, pen and gamepad devices through luna_uinput.py (stdlib only).
# Usage: input.sh up|down|status [--dry-run]. up and down need root.
set -Eeuo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
RIG_SCRIPT=$0
# shellcheck source=lib.sh
. "$HERE/lib.sh"

NAME=input
STATE=$RIG_RUN_DIR/$NAME
KINDS=(touch pen gamepad)

rig_init "$NAME" "$@"

cmd_up() {
    rig_require_root "$NAME"
    if [ "$RIG_DRY" = 0 ] && [ ! -e /dev/uinput ]; then
        echo "$NAME: /dev/uinput is missing. Load uinput (kernel module) first." >&2
        exit 1
    fi
    rig_do mkdir -p "$STATE"
    local kind
    for kind in "${KINDS[@]}"; do
        if ! rig_pid_alive "$STATE/$kind.pid" luna_uinput; then
            # Runs as root: the device node needs root or the input group.
            rig_bg root "$STATE/$kind.pid" python3 -I "$HERE/luna_uinput.py" create \
                --kind "$kind" --name "Luna Rig $kind"
        fi
    done
    echo "$NAME: up. Devices appear as 'Luna Rig <kind>'."
}

cmd_down() {
    rig_require_root "$NAME"
    local kind
    for kind in "${KINDS[@]}"; do
        rig_stop_pid "$STATE/$kind.pid" luna_uinput
    done
    rig_do rm -rf "$STATE"
    echo "$NAME: down."
}

cmd_status() {
    grep -A4 'Luna Rig' /proc/bus/input/devices 2>/dev/null | grep -E 'Name|Handlers' || echo "no Luna Rig input devices"
}

case $RIG_CMD in
up) cmd_up ;;
down) cmd_down ;;
status) cmd_status ;;
*)
    echo "usage: $0 up|down|status [--dry-run]" >&2
    exit 2
    ;;
esac
