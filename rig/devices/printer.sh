#!/usr/bin/env bash
# Run ippeveprinter (IPP Everywhere) and enable SANE's test scanner backend.
# Usage: printer.sh up|down|status [--dry-run]. up and down need root.
set -Eeuo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
RIG_SCRIPT=$0
# shellcheck source=lib.sh
. "$HERE/lib.sh"

NAME=printer
STATE=$RIG_RUN_DIR/$NAME
PORT=8631
PRINTER_NAME="Luna Rig Printer"

rig_init "$NAME" "$@"

cmd_up() {
    rig_require_root "$NAME"
    if [ "$RIG_DRY" = 0 ] && ! command -v ippeveprinter >/dev/null 2>&1; then
        echo "$NAME: ippeveprinter not found. Check: command -v ippeveprinter" >&2
        exit 1
    fi
    rig_do mkdir -p "$STATE/spool"
    # SANE reads its own config directory. The rig uses only the test backend.
    printf 'test\n' | rig_write "$STATE/sane/dll.conf"
    if ! rig_pid_alive "$STATE/ippeveprinter.pid" ippeveprinter; then
        rig_bg user "$STATE/ippeveprinter.pid" ippeveprinter -p "$PORT" -d "$STATE/spool" "$PRINTER_NAME"
    fi
    cat <<MSG
printer: ipp://127.0.0.1:$PORT/ipp/print
  Add in CUPS: lpadmin -p luna-rig -E -v ipp://localhost:$PORT/ipp/print -m everywhere
  Scanner: SANE_CONFIG_DIR=$STATE/sane scanimage -L
MSG
}

cmd_down() {
    rig_require_root "$NAME"
    rig_stop_pid "$STATE/ippeveprinter.pid" ippeveprinter
    rig_do rm -rf "$STATE/sane"
    echo "$NAME: down."
}

cmd_status() {
    if rig_pid_alive "$STATE/ippeveprinter.pid" ippeveprinter; then
        echo "ippeveprinter: running on port $PORT"
    else
        echo "ippeveprinter: stopped"
    fi
    if [ -f "$STATE/sane/dll.conf" ] && command -v scanimage >/dev/null 2>&1; then
        SANE_CONFIG_DIR="$STATE/sane" scanimage -L || true
    else
        echo "sane: not enabled or scanimage missing"
    fi
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
