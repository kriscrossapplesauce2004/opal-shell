"""The recorded shell's HOME and PATH shims.

The fixture HOME holds tidy sample files instead of the user's own, and links only read-only
assets (icons, applications, Steam art, wallpapers). The shims stand in for every command that
would read or change the real machine: Wi-Fi, Bluetooth, audio, power, theme settings and pkill.
"""
import os, pathlib, shutil, stat, textwrap

HOME = pathlib.Path.home()
PROMO = HOME / '.local/state/opal/promo-home'
SHIMS = HOME / '.local/state/opal/promo-shims'

LINKS = ['.local/share/icons', '.local/share/applications', '.local/share/Steam', '.steam', '.local/share/PrismLauncher',
         '.local/share/fonts', 'Pictures/Wallpapers', '.config/heroic', '.config/lutris']

FILES = {
    'Documents/Opal roadmap.md': '# Opal roadmap\n\nOne shell for every screen.\n',
    'Documents/Trip to Lisbon.pdf': '',
    'Documents/Budget 2026.ods': '',
    'Documents/Notes/ideas.txt': 'Chips that morph into cards.\n',
    'Music/Midnight Drive.flac': '',
    'Music/Opal Theme.flac': '',
    'Projects/opal/README.md': '# Opal\n',
    'Projects/keyboard/firmware.c': 'int main(void) { return 0; }\n',
    'Downloads/quickshell-0.3.tar.gz': '',
    'Videos/Launch trailer.mp4': '',
    '.zshrc': "PROMPT='%F{blue}opal%f %F{white}%~%f %F{magenta}❯%f '\nalias ls='ls --color=auto'\n",
    '.config/fastfetch/config.jsonc': '{"logo": {"type": "small"}, "modules": ["title", "separator", "os", "kernel", "wm", "shell", "terminal", "cpu", "gpu", "memory", "break", "colors"]}\n',
}
SKIP_PHOTOS = {'HFzVfJ5WEAAadoU.jpeg'}
PHOTOS = {
    'Pictures/Space': HOME / 'Pictures/Wallpapers',
}

SHIM_SCRIPTS = {
    'nmcli': r'''
case "$*" in
  *"connection show --active"*) echo "Home:802-11-wireless";;
  *"radio wifi"*) echo enabled;;
  *"wifi list"*) printf '%s\n' "*:Home:92:WPA2:wlan0" " :Studio 5G:74:WPA3:wlan0" " :Cafe Lumen:51::wlan0" " :Neighbours:30:WPA2:wlan0";;
  *"connection show"*) printf '%s\n' "Home:802-11-wireless" "Studio 5G:802-11-wireless";;
esac''',
    'bluetoothctl': r'''
case "$*" in
  show*) echo "Controller 00:11:22:33:44:55 opal"; echo "	Powered: yes";;
  "devices Connected"|"devices Paired"|devices) echo "Device AA:BB:CC:DD:EE:01 Pixel Buds Pro"; echo "Device AA:BB:CC:DD:EE:02 DualSense Wireless Controller";;
  info*) echo "	Connected: yes"; echo "	Battery Percentage: 0x50 (80)";;
esac''',
    'wpctl': r'''
case "$*" in
  *get-volume*SOURCE*) echo "Volume: 0.80";;
  *get-volume*) echo "Volume: ${PROMO_VOLUME:-0.62}";;
  inspect*) echo '    * node.description = "Speakers"'; echo '    * node.name = "alsa_output.speakers"';;
esac''',
    'upower': r'''
[ -n "$PROMO_BATTERY" ] || exit 0
cat <<EOF
Device: /org/freedesktop/UPower/devices/battery_BAT0
  native-path:          BAT0
  power supply:         yes
  battery
    present:             yes
    state:               discharging
    percentage:          ${PROMO_BATTERY}%
EOF''',
    'powerprofilesctl': r'''
case "$*" in
  get) echo balanced;;
  list) printf '%s\n' "  performance:" "* balanced:" "  power-saver:";;
esac''',
    'gsettings': r'''
[ "$1" = get ] && exec /usr/bin/gsettings "$@"
exit 0''',
    'systemctl': r'''
case "$*" in *is-active*) echo inactive; exit 3;; *is-enabled*) echo disabled; exit 1;; esac
exit 0''',
}
NOOPS = ['pkill', 'loginctl', 'brightnessctl', 'plasma-apply-colorscheme', 'flatpak', 'steam', 'ufw', 'adb', 'waydroid',
         'pkexec', 'sudo', 'matugen', 'kwriteconfig6', 'dconf', 'hyprsunset', 'gamemoded', 'checkupdates']


def build():
    PROMO.mkdir(parents=True, exist_ok=True)
    for rel in LINKS:
        target, link = HOME / rel, PROMO / rel
        if target.exists() and not link.exists() and not link.is_symlink():
            link.parent.mkdir(parents=True, exist_ok=True)
            link.symlink_to(target)
    for rel, body in FILES.items():
        path = PROMO / rel
        if not path.exists():
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(body)
    (PROMO / 'Desktop').mkdir(exist_ok=True)
    # Real copies, so photo apps that skip symlinks still find them.
    for rel, source in PHOTOS.items():
        folder = PROMO / rel
        folder.mkdir(parents=True, exist_ok=True)
        for image in sorted(source.glob('*')):
            if image.suffix.lower() in ('.jpg', '.jpeg', '.png', '.webp') and image.name not in SKIP_PHOTOS and not (folder / image.name).exists():
                shutil.copy2(image, folder / image.name)
    SHIMS.mkdir(parents=True, exist_ok=True)
    scripts = dict(SHIM_SCRIPTS, **{name: 'exit 0' for name in NOOPS})
    for name, body in scripts.items():
        path = SHIMS / name
        path.write_text('#!/bin/sh\n# Promo recording stand-in: never touches the real machine.\n' + textwrap.dedent(body).strip() + '\n')
        path.chmod(path.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
    return PROMO, SHIMS


if __name__ == '__main__':
    print(*build())
