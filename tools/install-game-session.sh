#!/usr/bin/env bash
# Adds "Opal Game Mode" to the login screen's session list: gamescope with Opal as its shell.
# Usage (as root): install-game-session.sh /path/to/opal   |   install-game-session.sh --remove
set -euo pipefail
entry=/usr/share/wayland-sessions/opal-game.desktop
[[ $(id -u) -eq 0 ]] || { echo 'Run this as root (opal game-session install-entry uses sudo).' >&2; exit 1; }
if [[ ${1:-} == --remove ]]; then
    rm -f -- "$entry"
    echo "Removed $entry"
    exit 0
fi
opal=${1:?path to the opal command}
[[ -x $opal ]] || { echo "$opal is not executable." >&2; exit 1; }
install -d /usr/share/wayland-sessions
cat > "$entry.tmp" <<DESKTOP
[Desktop Entry]
Name=Opal Game Mode
Comment=Opal's console home on gamescope, like SteamOS
Exec=$opal game-session
Type=Application
DesktopNames=gamescope
DESKTOP
mv -- "$entry.tmp" "$entry"
echo "Installed $entry. Pick Opal Game Mode on the login screen."
