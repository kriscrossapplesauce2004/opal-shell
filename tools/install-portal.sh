#!/usr/bin/env bash
# Makes Opal the FileChooser portal for this user, without root. Revert with --revert.
# xdg-desktop-portal reads backends from one folder; Opal points it at its own folder holding links to the system backends plus opal.portal.
# The FileChooser that was configured before becomes Opal's fallback for dialogs Opal does not draw (desktop layout by default).
set -euo pipefail

config="${OPAL_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/opal}"
data="${XDG_DATA_HOME:-$HOME/.local/share}"
state="${XDG_STATE_HOME:-$HOME/.local/state}/opal"
portal_dir="$data/opal/portals"
dropin_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/xdg-desktop-portal.service.d"
dropin="$dropin_dir/opal-portal.conf"
service="$data/dbus-1/services/org.freedesktop.impl.portal.desktop.opal.service"
portals_conf_dir="${XDG_CONFIG_HOME:-$HOME/.config}/xdg-desktop-portal"
desktop=$(printf '%s' "${XDG_CURRENT_DESKTOP:-Hyprland}" | cut -d: -f1 | tr '[:upper:]' '[:lower:]')
portals_conf="$portals_conf_dir/$desktop-portals.conf"
record="$state/portal.json"
system_portals=/usr/share/xdg-desktop-portal/portals

restart_portal() {
    systemctl --user daemon-reload
    # Only a running portal needs a restart; D-Bus starts it again on the next request.
    if systemctl --user is-active --quiet xdg-desktop-portal.service; then
        systemctl --user restart xdg-desktop-portal.service || true
    fi
}

# The FileChooser line currently in effect, from the user's desktop file, then the user's portals.conf, then the system's.
current_chooser() {
    local file value
    for file in "$portals_conf" "$portals_conf_dir/portals.conf" "/usr/share/xdg-desktop-portal/$desktop-portals.conf"; do
        [[ -f "$file" ]] || continue
        value=$(sed -n 's/^[[:space:]]*org\.freedesktop\.impl\.portal\.FileChooser[[:space:]]*=[[:space:]]*//p' "$file" | head -1)
        [[ -n "$value" ]] || value=$(sed -n 's/^[[:space:]]*default[[:space:]]*=[[:space:]]*//p' "$file" | head -1)
        if [[ -n "$value" ]]; then
            # The first backend that implements FileChooser.
            for name in ${value//;/ }; do
                [[ "$name" == opal ]] && continue
                if grep -qs 'org.freedesktop.impl.portal.FileChooser' "$system_portals/$name.portal"; then echo "$name"; return; fi
            done
        fi
    done
    for name in gtk kde gnome; do
        [[ -f "$system_portals/$name.portal" ]] && { echo "$name"; return; }
    done
    echo gtk
}

if [[ "${1:-}" == "--revert" ]]; then
    rm -f -- "$dropin" "$service"
    rm -rf -- "$portal_dir"
    if [[ -f "$state/portal-conf.backup" ]]; then
        mv -- "$state/portal-conf.backup" "$portals_conf"
    elif [[ -f "$state/portal-conf.none" ]]; then
        rm -f -- "$portals_conf" "$state/portal-conf.none"
    fi
    rm -f -- "$record"
    restart_portal
    echo "Opal no longer draws file dialogs; your previous FileChooser is back."
    exit 0
fi

if [[ "${1:-}" == "--status" ]]; then
    [[ -f "$dropin" ]] && echo "on (fallback: $(sed -n 's/.*"fallback": *"\([^"]*\)".*/\1/p' "$record" 2>/dev/null))" || echo off
    exit 0
fi

python3 -c 'import gi; gi.require_version("Gio", "2.0")' 2>/dev/null || { echo "python-gobject is required for the portal." >&2; exit 1; }
[[ -f "$config/opal_portal.py" ]] || { echo "Install Opal first (opal_portal.py is missing from $config)." >&2; exit 1; }

mkdir -p "$portal_dir" "$dropin_dir" "$(dirname -- "$service")" "$portals_conf_dir" "$state"
fallback=$(current_chooser)
[[ -f "$record" ]] && fallback=$(sed -n 's/.*"fallback": *"\([^"]*\)".*/\1/p' "$record")
printf '{"fallback": "%s"}\n' "$fallback" > "$record"

find "$portal_dir" -maxdepth 1 -name '*.portal' -delete
for file in "$system_portals"/*.portal; do
    [[ -e "$file" ]] && ln -s -- "$file" "$portal_dir/$(basename -- "$file")"
done
cat > "$portal_dir/opal.portal" <<'EOF'
[portal]
DBusName=org.freedesktop.impl.portal.desktop.opal
Interfaces=org.freedesktop.impl.portal.FileChooser
EOF

printf '[Service]\nEnvironment=XDG_DESKTOP_PORTAL_DIR=%s\n' "$portal_dir" > "$dropin"
printf '[D-BUS Service]\nName=org.freedesktop.impl.portal.desktop.opal\nExec=/usr/bin/python3 %s/opal_portal.py\n' "$config" > "$service"

# Keep the user's portals file; only the FileChooser line changes.
if [[ ! -f "$state/portal-conf.backup" && ! -f "$state/portal-conf.none" ]]; then
    if [[ -f "$portals_conf" ]]; then cp -- "$portals_conf" "$state/portal-conf.backup"; else touch "$state/portal-conf.none"; fi
fi
if [[ -f "$portals_conf" ]]; then
    sed -i '/^[[:space:]]*org\.freedesktop\.impl\.portal\.FileChooser[[:space:]]*=/d' "$portals_conf"
    grep -qi '^\[preferred\]' "$portals_conf" || printf '[preferred]\n' >> "$portals_conf"
    sed -i "0,/^\[[Pp]referred\]/s//&\norg.freedesktop.impl.portal.FileChooser=opal;$fallback/" "$portals_conf"
else
    printf '[preferred]\ndefault=hyprland;gtk\norg.freedesktop.impl.portal.FileChooser=opal;%s\n' "$fallback" > "$portals_conf"
fi

restart_portal
echo "Opal draws apps' file dialogs on phones and tablets; desktop dialogs still come from $fallback."
echo "Change that in Settings → Wallpaper & style → Files, or undo with: opal portal off"
