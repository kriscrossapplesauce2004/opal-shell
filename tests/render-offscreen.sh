#!/usr/bin/env bash
set -euo pipefail
source_dir=$(cd "$(dirname "$0")/.." && pwd)
root=$(mktemp -d /tmp/opal-render.XXXXXX)
mkdir -p "$root/home/.local/share/Steam/appcache" "$root/runtime" "$root/images"
chmod 700 "$root/runtime"
# Small generated image fixtures exercise the gallery without reading user photos.
python3 - "$root/home/Pictures/Wallpapers" <<'PY'
import pathlib, struct, sys, zlib
folder=pathlib.Path(sys.argv[1]);folder.mkdir(parents=True)
def chunk(kind,data):
    return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
for index in range(3):
    pixels=b''.join(b'\0'+bytes(c for x in range(256) for c in ((x+index*60)%256,(y*2+index*30)%256,(x//2+y+80)%256)) for y in range(160))
    image=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',256,160,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(pixels))+chunk(b'IEND',b'')
    (folder/f'Fixture-{index+1}.png').write_bytes(image)
PY
# Assets are only read. Preferences and every service endpoint stay isolated.
if [[ -d $HOME/.local/share/Steam/appcache/librarycache ]]; then
    ln -s "$HOME/.local/share/Steam/appcache/librarycache" "$root/home/.local/share/Steam/appcache/librarycache"
fi
if [[ -d $HOME/.local/share/icons ]]; then
    ln -s "$HOME/.local/share/icons" "$root/home/.local/share/icons"
fi
if [[ -d $HOME/.local/share/applications ]]; then
    ln -s "$HOME/.local/share/applications" "$root/home/.local/share/applications"
fi
printf 'Isolated render directory: %s\n' "$root"
env -u DISPLAY -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE \
    HOME="$root/home" XDG_RUNTIME_DIR="$root/runtime" \
    XDG_CONFIG_HOME="$root/home/.config" XDG_DATA_HOME="$root/home/.local/share" \
    QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
    OPAL_TEST_OUTPUT="$root/images" DBUS_SESSION_BUS_ADDRESS="unix:path=$root/no-bus" \
    timeout 40s quickshell -p "$source_dir/headless.qml" > "$root/render.log" 2>&1
printf 'Log: %s/render.log\nImages: %s/images/\n' "$root" "$root"
if grep -E 'TypeError|ReferenceError|ERROR|Unable to assign|Binding loop|ASSERTION_FAILED' "$root/render.log"; then
    exit 1
fi
grep 'OFFSCREEN_TESTS_COMPLETE' "$root/render.log"
