#!/usr/bin/env bash
# Build the waylib fork (waylib + its vendored wlroots) and its two protocol packages into opal/compositor/vendor-prefix.
# No sudo and nothing outside opal/compositor: build trees go to vendor-build/, the install to vendor-prefix/.
# Usage: vendor/build-waylib.sh [-j N]
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOP="$(cd "$HERE/.." && pwd)"
PREFIX="$TOP/vendor-prefix"
BUILD="$TOP/vendor-build"
JOBS=6
if [[ "${1:-}" == "-j" ]]; then JOBS="$2"; fi

export PKG_CONFIG_PATH="$PREFIX/share/pkgconfig:$PREFIX/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"

# wlr-protocols: XML files and a .pc file only (Arch package wlr-protocols).
make -C "$HERE/wlr-protocols" PREFIX="$PREFIX" install >/dev/null
make -C "$HERE/wlr-protocols" clean >/dev/null

# treeland-protocols: XML files and a CMake package (Arch package treeland-protocols).
cmake -S "$HERE/treeland-protocols" -B "$BUILD/treeland-protocols" -G Ninja -DCMAKE_INSTALL_PREFIX="$PREFIX" >/dev/null
cmake --build "$BUILD/treeland-protocols" >/dev/null
cmake --install "$BUILD/treeland-protocols" >/dev/null

# waylib standalone; it pulls in ../wlroots (the vendored, patched wlroots 0.20.2).
cmake -S "$HERE/treeland/waylib" -B "$BUILD/waylib" -G Ninja \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_INSTALL_PREFIX="$PREFIX" -DCMAKE_PREFIX_PATH="$PREFIX" \
    -DBUILD_TESTS=OFF -DBUILD_EXAMPLES=ON -DSTART_DEMO=OFF -DTREELAND_INSTALL_DEV=ON >/dev/null
# GCC 16 crashed (internal compiler error) a few times at -j12; a retry builds on.
for attempt in 1 2 3; do
    if cmake --build "$BUILD/waylib" -j "$JOBS" > "$BUILD/waylib-build.log" 2>&1; then
        break
    fi
    if [[ $attempt -eq 3 ]] || ! grep -q 'internal compiler error' "$BUILD/waylib-build.log"; then
        tail -30 "$BUILD/waylib-build.log" >&2
        exit 1
    fi
    echo "compiler crash, retry $attempt" >&2
done
cmake --install "$BUILD/waylib" > "$BUILD/waylib-install.log"
echo "waylib fork installed in $PREFIX"
