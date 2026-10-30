#!/usr/bin/env bash
# Load v4l2loopback (camera) and vivid (virtual CEC), and feed a test pattern if ffmpeg exists.
# Usage: media.sh up|down|status [--dry-run]. up and down need root.
set -Eeuo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
RIG_SCRIPT=$0
# shellcheck source=lib.sh
. "$HERE/lib.sh"

NAME=media
STATE=$RIG_RUN_DIR/$NAME
CAM_NR=42
CAM_LABEL="Luna Rig Camera"
# Check vivid options with: modinfo vivid. Override with VIVID_OPTS.
VIVID_OPTS=${VIVID_OPTS:-n_devs=1}

rig_init "$NAME" "$@"

load_module_once() {
    # Load a module only when it is absent, and record that this script loaded it.
    local mod=$1
    shift
    if [ -d "/sys/module/$mod" ]; then
        echo "$NAME: $mod already loaded by someone else; leaving it alone."
        return 0
    fi
    rig_do modprobe "$mod" "$@"
    rig_do mkdir -p "$STATE"
    if [ "$RIG_DRY" = 0 ]; then
        echo "$mod" >>"$STATE/loaded"
    fi
}

cmd_up() {
    rig_require_root "$NAME"
    load_module_once v4l2loopback devices=1 "video_nr=$CAM_NR" "card_label=$CAM_LABEL" exclusive_caps=1
    local -a vivid_args
    read -r -a vivid_args <<<"$VIVID_OPTS"
    load_module_once vivid "${vivid_args[@]}"
    if command -v ffmpeg >/dev/null 2>&1 && ! rig_pid_alive "$STATE/ffmpeg.pid" ffmpeg; then
        rig_bg user "$STATE/ffmpeg.pid" ffmpeg -loglevel error -re -f lavfi \
            -i testsrc=size=1280x720:rate=30 -pix_fmt yuv420p -f v4l2 "/dev/video$CAM_NR"
    fi
    echo "$NAME: up. Camera: /dev/video$CAM_NR. CEC: cec-ctl --list-devices"
}

cmd_down() {
    rig_require_root "$NAME"
    rig_stop_pid "$STATE/ffmpeg.pid" ffmpeg
    if [ -f "$STATE/loaded" ]; then
        # Unload in reverse order of loading.
        for mod in $(tac "$STATE/loaded"); do
            rig_do rmmod "$mod"
        done
    fi
    rig_do rm -rf "$STATE"
    echo "$NAME: down."
}

cmd_status() {
    for mod in v4l2loopback vivid; do
        if [ -d "/sys/module/$mod" ]; then echo "$mod: loaded"; else echo "$mod: not loaded"; fi
    done
    if command -v v4l2-ctl >/dev/null 2>&1; then v4l2-ctl --list-devices || true; fi
    if command -v cec-ctl >/dev/null 2>&1; then cec-ctl --list-devices || true; fi
    if rig_pid_alive "$STATE/ffmpeg.pid" ffmpeg; then echo "test pattern: running"; else echo "test pattern: stopped"; fi
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
