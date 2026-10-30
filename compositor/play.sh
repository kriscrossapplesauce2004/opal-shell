#!/usr/bin/env bash
# Open luna-compositor in a window on the current session with the full shell inside, until the window closes.
# The shell is isolated: temp home and state, private D-Bus. Apps opened from it run inside the compositor.
# Extra arguments go to run-shell.sh, for example --impl qt or --offscreen.
set -euo pipefail
here=$(dirname "$(readlink -f "$0")")
out="${XDG_CACHE_HOME:-$HOME/.cache}/luna-compositor/play"
mkdir -p "$out"
if [[ ! -x "$here/build/luna-compositor" ]]; then
    notify-send -a "Luna compositor" "Luna compositor is not built" "Run: cmake --build $here/build" 2>/dev/null || true
    echo "luna-compositor is not built: cmake --build $here/build" >&2
    exit 1
fi
exec "$here/run-shell.sh" --no-scenario --seconds 0 --snapshot --out "$out" "$@"
