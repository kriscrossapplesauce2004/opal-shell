#!/usr/bin/env bash
set -euo pipefail
source_dir=$(cd "$(dirname "$0")/.." && pwd)
root=$(mktemp -d /tmp/opal-render.XXXXXX)
mkdir -p "$root/home/.local/share/Steam/appcache" "$root/runtime" "$root/images"
chmod 700 "$root/runtime"
# Quickshell requires imports to remain below the entry point's directory.
mkdir -p "$root/config"
cp -a "$source_dir/src" "$root/config/src"
cp "$source_dir/tests/headless.qml" "$root/config/headless.qml"
# Small generated image fixtures exercise the gallery without reading user photos.
python3 - "$root/home/Pictures/Wallpapers" "$HOME/.local/state/opal/preferences.json" "$root/home/.local/state/opal/preferences.json" <<'PY'
import json, pathlib, struct, sys, zlib
# Copy theme roles only into the isolated preview state.
try:
    saved=json.loads(pathlib.Path(sys.argv[2]).read_text())
    theme={key:saved[key] for key in ('palette','light','dynamicColors','dynamicPalette','colorScheme') if key in saved}
    destination=pathlib.Path(sys.argv[3]);destination.parent.mkdir(parents=True,exist_ok=True)
    destination.write_text(json.dumps(theme))
except (OSError, ValueError):
    pass
folder=pathlib.Path(sys.argv[1]);folder.mkdir(parents=True)
def chunk(kind,data):
    return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
for index in range(3):
    pixels=b''.join(b'\0'+bytes(c for x in range(256) for c in ((x+index*60)%256,(y*2+index*30)%256,(x//2+y+80)%256)) for y in range(160))
    image=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',256,160,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(pixels))+chunk(b'IEND',b'')
    (folder/f'Fixture-{index+1}.png').write_bytes(image)
# A generated shoreline photo backs the composite desktop scenes. It lives outside the gallery folder.
import math, random
random.seed(7)
width,height=640,360
rows=[]
for y in range(height):
    row=bytearray(b'\0')
    for x in range(width):
        edge=width*(.55+.08*math.sin(y/37.0)+.04*math.sin(y/11.0))
        n=random.random()*18
        if x<edge-40:
            depth=x/edge
            r,g,b=8+40*depth+n*.4,70+70*depth+n,90+60*depth+n
        elif x<edge+30:
            foam=1-abs(x-edge+5)/40
            r,g,b=150+100*foam+n,200+50*foam+n*.5,205+45*foam
        else:
            r,g,b=205+n,198+n,185+n
        row+=bytes((min(255,int(r)),min(255,int(g)),min(255,int(b))))
    rows.append(bytes(row))
image=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',width,height,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(b''.join(rows)))+chunk(b'IEND',b'')
(folder.parent.parent/'Ocean.png').write_bytes(image)
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
    QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=basic QT_QUICK_BACKEND=software QT_LOGGING_RULES="qml.debug=true" \
    OPAL_TEST_OUTPUT="$root/images" DBUS_SESSION_BUS_ADDRESS="unix:path=$root/no-bus" \
    timeout 90s quickshell -p "$root/config/headless.qml" > "$root/render.log" 2>&1
printf 'Log: %s/render.log\nImages: %s/images/\n' "$root" "$root"
if grep -E 'TypeError|ReferenceError|ERROR|Unable to assign|Binding loop|ASSERTION_FAILED' "$root/render.log"; then
    exit 1
fi
grep 'OFFSCREEN_TESTS_COMPLETE' "$root/render.log"
