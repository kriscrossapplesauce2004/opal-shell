#!/usr/bin/env bash
set -Eeuo pipefail

source_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../src" && pwd)
config_home=${XDG_CONFIG_HOME:-$HOME/.config}
data_home=${XDG_DATA_HOME:-$HOME/.local/share}
state_home=${XDG_STATE_HOME:-$HOME/.local/state}
destination=$data_home/opal/polkit
unit=$config_home/systemd/user/opal-polkit.service
backup=$state_home/opal/pre-deploy-$(date +%Y%m%d-%H%M%S)-polkit

command -v quickshell >/dev/null
systemctl --user show-environment >/dev/null
mkdir -p -- "$backup" "$destination" "$config_home/opal" "$(dirname -- "$unit")"
if [[ -f $unit ]]; then cp -a -- "$unit" "$backup/opal-polkit.service"; fi
if [[ -f $destination/polkit.qml ]]; then cp -a -- "$destination" "$backup/polkit"; fi
if [[ -f $config_home/opal/polkit-standalone ]]; then cp -a -- "$config_home/opal/polkit-standalone" "$backup/polkit-standalone"; fi
systemctl --user is-enabled hyprpolkitagent.service > "$backup/hyprpolkitagent-state" || true
cp -a -- "$source_dir/." "$destination/"

python3 - "$unit" "$destination/polkit.qml" "$(command -v quickshell)" <<'PY'
import pathlib, sys

def quote(value):
    return '"' + value.replace('\\', '\\\\').replace('"', '\\"').replace('%', '%%').replace('$', '$$') + '"'

pathlib.Path(sys.argv[1]).write_text('''[Unit]
Description=Opal authentication agent
PartOf=graphical-session.target
After=graphical-session.target
ConditionEnvironment=WAYLAND_DISPLAY

[Service]
Type=simple
Environment=OPAL_POLKIT=1
ExecStart=''' + quote(sys.argv[3]) + ' --no-duplicate --path ' + quote(sys.argv[2]) + '''
Restart=on-failure
RestartSec=3
TimeoutStopSec=5
Slice=session.slice

[Install]
WantedBy=graphical-session.target
''')
PY

systemctl --user daemon-reload
systemctl --user enable opal-polkit.service
systemctl --user disable hyprpolkitagent.service
systemctl --user mask --now hyprpolkitagent.service
printf '1\n' > "$config_home/opal/polkit-standalone"
systemctl --user restart opal-polkit.service
printf 'Opal authentication is enabled for graphical logins. Backup: %s\n' "$backup"
