#!/usr/bin/env bash
# Start BlueZ virtual controllers (btvirt) for PIN and passkey pairing tests.
# Usage: bt-virt.sh up|down|status [--dry-run]. up and down need root.
set -Eeuo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
RIG_SCRIPT=$0
# shellcheck source=lib.sh
. "$HERE/lib.sh"

NAME=bt-virt
STATE=$RIG_RUN_DIR/$NAME
# Override with BTVIRT_ARGS if your BlueZ build uses other flags. Check: btvirt --help
BTVIRT_ARGS=${BTVIRT_ARGS:--L -l2}

rig_init "$NAME" "$@"

cmd_up() {
    rig_require_root "$NAME"
    if [ "$RIG_DRY" = 0 ] && ! command -v btvirt >/dev/null 2>&1; then
        echo "$NAME: btvirt not found. Install BlueZ tools that include the emulator." >&2
        exit 1
    fi
    if [ "$RIG_DRY" = 0 ] && ! systemctl is-active --quiet bluetooth; then
        echo "$NAME: bluetoothd is not running. Start bluetooth.service first." >&2
        exit 1
    fi
    if [ ! -e /dev/vhci ]; then
        # btvirt registers its controllers through the vhci driver. This script does not load it outside dry runs.
        rig_do modprobe hci_vhci
    fi
    if rig_pid_alive "$STATE/btvirt.pid" btvirt; then
        echo "$NAME: already up."
        return 0
    fi
    rig_do mkdir -p "$STATE"
    local -a args
    read -r -a args <<<"$BTVIRT_ARGS"
    # Root mode: btvirt needs the vhci device node.
    rig_bg root "$STATE/btvirt.pid" btvirt "${args[@]}"
    cat <<'MSG'
bt-virt: started. Pairing tests:
  PIN (legacy):  bluetoothctl agent NoInputNoOutput, then pair; the peer uses PIN 0000.
  Passkey (SSP): bluetoothctl agent KeyboardDisplay, then pair; the peer shows passkey 123456.
Note: the Opal pairing agent is not in connectivity.py yet (moonshot section 28, item 10).
MSG
}

cmd_down() {
    rig_require_root "$NAME"
    rig_stop_pid "$STATE/btvirt.pid" btvirt
    rig_do rm -rf "$STATE"
    echo "$NAME: down. hci_vhci is left loaded."
}

cmd_status() {
    if rig_pid_alive "$STATE/btvirt.pid" btvirt; then
        echo "btvirt: running"
    else
        echo "btvirt: stopped"
    fi
    if command -v bluetoothctl >/dev/null 2>&1; then
        bluetoothctl list || true
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
