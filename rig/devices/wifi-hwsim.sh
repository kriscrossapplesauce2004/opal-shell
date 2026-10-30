#!/usr/bin/env bash
# Bring up mac80211_hwsim radios: hostapd PSK, hidden and 802.1X APs, plus a client radio.
# Usage: wifi-hwsim.sh up|down|status|check [--dry-run]. up and down need root.
set -Eeuo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
RIG_SCRIPT=$0
# shellcheck source=lib.sh
. "$HERE/lib.sh"

NAME=wifi-hwsim
RADIOS=4
# Radio roles in creation order. The last radio is the NetworkManager client.
ROLES=(psk hidden enterprise client)
AP_ROLES=(psk hidden enterprise)
STATE=$RIG_RUN_DIR/$NAME
RADIUS_DIR=$STATE/radius
CONF=$HERE/conf

rig_init "$NAME" "$@"

hwsim_iface_for_phy() {
    # Print the wlan interface that belongs to phy#N, where N is $1.
    iw dev | awk -v want="phy#$1" '/^phy#/ {cur=$0} /^[[:space:]]+Interface/ && cur==want {print $2; exit}'
}

ssid_of() {
    sed -n 's/^ssid=//p' "$CONF/hostapd-$1.conf"
}

ensure_certs() {
    # Make a self-signed RADIUS certificate once. It also serves as the CA file.
    local dir=$1
    if [ -f "$dir/certs/server.pem" ]; then
        return 0
    fi
    rig_do mkdir -p "$dir/certs"
    rig_do openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -subj "/CN=luna-rig-radius" \
        -keyout "$dir/certs/server.key" -out "$dir/certs/server.pem"
}

render_radius() {
    # Copy the FreeRADIUS config and users into a directory. Args: target directory.
    local dir=$1
    rig_do mkdir -p "$dir/run"
    rig_write "$dir/radiusd.conf" <"$CONF/radius/radiusd.conf"
    rig_write "$dir/users" <"$CONF/radius/users"
}

cmd_up() {
    rig_require_root "$NAME"
    if [ -f "$STATE/loaded" ]; then
        echo "$NAME: already up (see status)."
        return 0
    fi
    if [ "$RIG_DRY" = 0 ] && [ -d /sys/module/mac80211_hwsim ]; then
        echo "$NAME: mac80211_hwsim is loaded by someone else. Refusing to touch its radios." >&2
        exit 1
    fi
    local -a ifaces=()
    if [ "$RIG_DRY" = 1 ]; then
        echo "+ modprobe mac80211_hwsim radios=$RADIOS"
        for role in "${ROLES[@]}"; do ifaces+=("<wlan-$role>"); done
    else
        local before after new phy
        before=$(ls /sys/class/ieee80211 2>/dev/null | sort || true)
        rig_do modprobe mac80211_hwsim "radios=$RADIOS"
        after=$(ls /sys/class/ieee80211 | sort)
        # Only phys that appear after the load are ours. Other interfaces stay untouched.
        new=$(comm -13 <(printf '%s\n' "$before") <(printf '%s\n' "$after"))
        [ "$(printf '%s\n' "$new" | grep -c .)" -eq "$RADIOS" ] || {
            echo "$NAME: expected $RADIOS new phys, found: $new" >&2
            exit 1
        }
        while read -r phy; do
            ifaces+=("$(hwsim_iface_for_phy "${phy#phy}")")
        done <<<"$new"
        rig_write "$STATE/loaded" <<<"hwsim"
    fi

    local i role iface
    local map=""
    for i in "${!ROLES[@]}"; do
        role=${ROLES[$i]}
        iface=${ifaces[$i]}
        map+="$role $iface"$'\n'
    done
    printf '%s' "$map" | rig_write "$STATE/ifaces"

    ensure_certs "$RADIUS_DIR"
    render_radius "$RADIUS_DIR"

    for role in "${AP_ROLES[@]}"; do
        iface=$(printf '%s' "$map" | awk -v r="$role" '$1==r {print $2}')
        if command -v nmcli >/dev/null 2>&1; then
            rig_do nmcli device set "$iface" managed no
        fi
        sed -e "s/@IFACE@/$iface/" "$CONF/hostapd-$role.conf" | rig_write "$STATE/hostapd-$role.conf"
        rig_do hostapd -B -f "$STATE/hostapd-$role.log" -P "$STATE/hostapd-$role.pid" "$STATE/hostapd-$role.conf"
    done

    rig_do radiusd -d "$RADIUS_DIR"
    echo "$NAME: up. Client radio is the last one listed in $STATE/ifaces."
}

cmd_down() {
    rig_require_root "$NAME"
    for role in "${AP_ROLES[@]}"; do
        rig_stop_pid "$STATE/hostapd-$role.pid" hostapd
    done
    rig_stop_pid "$RADIUS_DIR/run/radiusd.pid" radiusd
    if [ -f "$STATE/ifaces" ]; then
        while read -r role iface; do
            if [ "$role" != client ] && command -v nmcli >/dev/null 2>&1; then
                rig_do nmcli device set "$iface" managed yes
            fi
        done <"$STATE/ifaces"
    fi
    if [ -f "$STATE/loaded" ]; then
        rig_do rmmod mac80211_hwsim
    fi
    rig_do rm -rf "$STATE"
    echo "$NAME: down."
}

cmd_status() {
    if [ -d /sys/module/mac80211_hwsim ]; then
        echo "module: loaded"
    else
        echo "module: not loaded"
    fi
    if [ -f "$STATE/ifaces" ]; then
        echo "radios:"
        sed 's/^/  /' "$STATE/ifaces"
    fi
    for role in "${AP_ROLES[@]}"; do
        if rig_pid_alive "$STATE/hostapd-$role.pid" hostapd; then
            echo "$role: running, SSID $(ssid_of "$role")"
        else
            echo "$role: stopped"
        fi
    done
    if rig_pid_alive "$RADIUS_DIR/run/radiusd.pid" radiusd; then
        echo "radius: running on 127.0.0.1:11812"
    else
        echo "radius: stopped"
    fi
}

cmd_check() {
    # Check configs in a scratch directory. Touches no system state and needs no root.
    local tmp
    tmp=$(mktemp -d)
    trap "rm -rf '$tmp'" EXIT
    render_radius "$tmp"
    ensure_certs "$tmp"
    if command -v radiusd >/dev/null 2>&1; then
        radiusd -C -d "$tmp"
    else
        echo "$NAME: radiusd not installed; skipped the FreeRADIUS config check."
    fi
    for role in "${AP_ROLES[@]}"; do
        local ssid
        ssid=$(ssid_of "$role")
        if [ "${#ssid}" -gt 32 ]; then
            echo "$NAME: SSID $ssid is longer than 32 bytes" >&2
            exit 1
        fi
    done
    echo "$NAME: configs OK."
}

case $RIG_CMD in
up) cmd_up ;;
down) cmd_down ;;
status) cmd_status ;;
check) cmd_check ;;
*)
    echo "usage: $0 up|down|status|check [--dry-run]" >&2
    exit 2
    ;;
esac
