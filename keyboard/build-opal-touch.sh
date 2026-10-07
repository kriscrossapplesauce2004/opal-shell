#!/bin/sh
# Build the Aurora Hyprland touch-routing plugin for the docked phone.
set -eu
SOURCE=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
AURORA=${AURORA_SOURCE:-/home/melissa/aurora}
SYSROOT=$AURORA/build/arch-desktop/sysroot
PORT=$AURORA/build/dethyprland-sysroot/opt/dethyprland
OUTPUT=${OUTPUT:-$SOURCE/libopal-touch.so}
if ! command -v podman >/dev/null 2>&1; then echo "podman is missing; cannot cross-build opal-touch." >&2; exit 1; fi
if [ ! -f "$SOURCE/opal-touch.cpp" ]; then echo "opal-touch.cpp not found in $SOURCE." >&2; exit 1; fi
if [ ! -d "$SYSROOT" ]; then echo "Aurora sysroot not found at $SYSROOT; run the Aurora desktop build first." >&2; exit 1; fi
if [ ! -d "$PORT" ]; then echo "DetHyprland sysroot not found at $PORT; run the Aurora compositor build first." >&2; exit 1; fi
podman run --rm \
    -v "$SYSROOT:/sysroot:ro" \
    -v "$PORT:/sysroot/opt/dethyprland:ro" \
    -v "$SOURCE:/work:rw" -w /work \
    localhost/aurora/arch-desktop-cross:trixie \
    aarch64-linux-gnu-g++ --sysroot=/sysroot -std=c++23 -O2 -Wall -Wextra \
    -shared -fPIC -DWLR_USE_UNSTABLE \
    -I/sysroot/usr/include/pixman-1 -I/sysroot/usr/include/libdrm \
    -I/sysroot/opt/dethyprland/include \
    -I/sysroot/opt/dethyprland/include/hyprland \
    -I/sysroot/opt/dethyprland/include/hyprland/protocols \
    opal-touch.cpp -o libopal-touch.so
# Load with: hyprctl plugin load libopal-touch.so.
echo "Built $SOURCE/libopal-touch.so"
if [ "$OUTPUT" != "$SOURCE/libopal-touch.so" ]; then cp -- "$SOURCE/libopal-touch.so" "$OUTPUT"; echo "Copied to $OUTPUT"; fi
