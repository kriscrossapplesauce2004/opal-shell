#!/usr/bin/env bash
# Install the Opal greeter for greetd, or restore the previous greeter with --revert. Run with sudo.
set -Eeuo pipefail

source_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../src" && pwd)
share=/usr/share/opal/greeter
etc=/etc/greetd/opal
cache=/var/cache/opal-greeter
state=/var/lib/opal-greeter
config=/etc/greetd/config.toml
backup=/etc/greetd/config.toml.opal-backup
greeter_user=greeter
owner=${SUDO_USER:-}

die() { echo "install-greeter: $*" >&2; exit 1; }
[[ $EUID -eq 0 ]] || die "run this with sudo"

if [[ ${1:-} == --revert ]]; then
    [[ -f $backup ]] || die "no backup at $backup; nothing to restore"
    cp -- "$backup" "$config"
    echo "Restored $config from $backup. The previous greeter starts at the next login screen."
    exit 0
fi

for tool in greetd Hyprland quickshell python3; do command -v "$tool" >/dev/null || die "$tool is not installed"; done
id "$greeter_user" >/dev/null 2>&1 || die "user '$greeter_user' does not exist"
[[ -f $config ]] || die "$config not found"
[[ -n $owner && $owner != root ]] || die "run through sudo from your own account, so the theme cache belongs to you"

# Shell files: a flat copy of src, like the session install.
rm -rf -- "$share.new"
mkdir -p -- "$share.new"
cp -a -- "$source_dir/." "$share.new/"
rm -rf -- "$share.new/__pycache__"
cat > "$share.new/run-greeter" <<'EOF'
#!/bin/sh
# Start the Opal greeter, then end the greeter compositor so greetd can start the session.
export OPAL_GREETER=1 QT_QPA_PLATFORM=wayland
quickshell -p /usr/share/opal/greeter/greeter.qml
pkill -u "$(id -u)" -x Hyprland
EOF
chmod 0755 "$share.new/run-greeter"
rm -rf -- "$share"
mv -- "$share.new" "$share"

# A minimal compositor config for the greeter.
mkdir -p -- "$etc"
cat > "$etc/hyprland.lua" <<'EOF'
-- Opal greeter compositor. Written by tools/install-greeter.sh.
hl.config({
    input = { kb_layout = "gb", numlock_by_default = true },
    misc = { disable_hyprland_logo = true, disable_splash_rendering = true, force_default_wallpaper = 0 },
    animations = { enabled = false },
    decoration = { blur = { enabled = true, size = 8, passes = 2 } },
})
hl.on("hyprland.start", function()
    hl.exec_cmd("/usr/share/opal/greeter/run-greeter")
end)
EOF
# Keep the greeter keyboard layout in step with the system layout.
layout=$(localectl status 2>/dev/null | awk -F': ' '/X11 Layout/ {print $2}')
[[ -n $layout ]] && sed -i "s/kb_layout = \"gb\"/kb_layout = \"$layout\"/" "$etc/hyprland.lua"

# Theme cache: written by your session, read by the greeter.
install -d -m 0755 -o "$owner" -g "$greeter_user" "$cache"
# Greeter state: last user and session, written by the greeter.
install -d -m 0700 -o "$greeter_user" -g "$greeter_user" "$state"

# Point greetd at the Opal greeter, keeping one backup of the original.
[[ -f $backup ]] || cp -- "$config" "$backup"
python3 - "$config" <<'EOF'
import re, sys
path = sys.argv[1]
text = open(path).read()
command = 'command = "Hyprland --config /etc/greetd/opal/hyprland.lua"'
section = re.search(r'(?ms)^\[default_session\]\s*$(.*?)(?=^\[|\Z)', text)
if not section: sys.exit('no [default_session] section in ' + path)
body = section.group(1)
body = re.sub(r'(?m)^command\s*=.*$', command, body) if re.search(r'(?m)^command\s*=', body) else command + '\n' + body
text = text[:section.start(1)] + body + text[section.end(1):]
open(path, 'w').write(text)
EOF

echo "Opal greeter installed. It starts at the next login screen."
echo "Your session fills $cache with your wallpaper and colours on the next settings change."
echo "To go back: sudo $(realpath "$0") --revert"
