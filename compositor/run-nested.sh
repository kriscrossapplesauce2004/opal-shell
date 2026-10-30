#!/usr/bin/env bash
# Build luna-compositor, run it nested, start three Qt test clients, then stop everything.
# Usage: run-nested.sh [--impl waylib|qt] [--offscreen] [--seconds N] [--out DIR]
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD="$HERE/build"
SOCKET="${LUNA_SOCKET:-luna-0}"
RUN_SECONDS=20
OUT="$BUILD/run"
PLATFORM_ARGS=()
IMPL=waylib
OFFSCREEN=0
CLIENT_PIDS=()
COMP_PID=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --impl) IMPL="$2"; shift ;;
        --offscreen) OFFSCREEN=1 ;;
        --seconds) RUN_SECONDS="$2"; shift ;;
        --out) OUT="$2"; shift ;;
        -h|--help) sed -n '2,3p' "$0"; exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done

# waylib picks a wlroots backend; the Qt harness picks a Qt platform.
if [[ "$IMPL" == waylib ]]; then
    COMP_BIN="$BUILD/luna-compositor"
    if [[ $OFFSCREEN -eq 1 ]]; then PLATFORM_ARGS=(--backend headless); else PLATFORM_ARGS=(--backend wayland); fi
elif [[ "$IMPL" == qt ]]; then
    COMP_BIN="$BUILD/luna-compositor-qt"
    if [[ $OFFSCREEN -eq 1 ]]; then PLATFORM_ARGS=(-platform offscreen); fi
else
    echo "unknown --impl: $IMPL (waylib or qt)" >&2
    exit 2
fi

if [[ $OFFSCREEN -eq 0 && -z "${WAYLAND_DISPLAY:-}" ]]; then
    echo "No host Wayland session; use --offscreen." >&2
    exit 1
fi

cleanup() {
    local pid
    for pid in ${CLIENT_PIDS[@]+"${CLIENT_PIDS[@]}"}; do
        pkill -P "$pid" 2>/dev/null || true
        kill "$pid" 2>/dev/null || true
    done
    if [[ -n "$COMP_PID" ]]; then
        kill "$COMP_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT

# Start a Qt client in the luna session, never on the host X server.
launch() {
    env -u DISPLAY WAYLAND_DISPLAY="$SOCKET" QT_QPA_PLATFORM=wayland XDG_SESSION_TYPE=wayland \
        qml6 "$HERE/clients/test-client.qml" -- "$1" &
    CLIENT_PIDS+=("$!")
}

cmake -S "$HERE" -B "$BUILD" -G Ninja -DCMAKE_BUILD_TYPE=Release >/dev/null
cmake --build "$BUILD"

mkdir -p "$OUT"
FRAMES="$OUT/frames.json"
rm -f "$FRAMES"

# The compositor sees no host X display and no Hyprland signature.
env -u DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE "$COMP_BIN" ${PLATFORM_ARGS[@]+"${PLATFORM_ARGS[@]}"} \
    --stand-in-bar --socket "$SOCKET" --frame-log "$FRAMES" --exit-after $((RUN_SECONDS * 1000)) &
COMP_PID="$!"

SOCK_PATH="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/$SOCKET"
for _ in $(seq 100); do
    [[ -S "$SOCK_PATH" ]] && break
    sleep 0.1
done
[[ -S "$SOCK_PATH" ]] || { echo "socket $SOCK_PATH did not appear" >&2; exit 1; }
echo "compositor up on $SOCKET"

# Staggered starts make the tiling springs run while clients appear.
sleep 0.5
launch A
sleep 1
launch B
CLIENT_B_PID="${CLIENT_PIDS[1]}"
sleep 1
launch C

# Close client B part way through, so the close animation runs.
sleep "$(awk -v s="$RUN_SECONDS" 'BEGIN { printf "%.2f", s * 0.5 }')"
pkill -P "$CLIENT_B_PID" 2>/dev/null || true
kill "$CLIENT_B_PID" 2>/dev/null || true
echo "closed client B"

STATUS=0
wait "$COMP_PID" || STATUS=$?
COMP_PID=""
echo "compositor exited with status $STATUS"

if [[ -f "$FRAMES" ]]; then
    python3 - "$FRAMES" <<'PY'
import json, statistics, sys

data = json.load(open(sys.argv[1]))
intervals = data["intervals_ms"]
busy = [v for v in intervals if v <= 100.0]
idle = len(intervals) - len(busy)
print(f"frames={len(intervals)} idle_gaps_over_100ms={idle} backend={data['backend']}")
if len(busy) >= 2:
    busy.sort()
    def pct(p):
        rank = p / 100 * (len(busy) - 1)
        lo = int(rank)
        hi = min(lo + 1, len(busy) - 1)
        return busy[lo] + (busy[hi] - busy[lo]) * (rank - lo)
    over = sum(1 for v in busy if v > 16.7)
    print(f"busy frames: median={statistics.median(busy):.2f}ms p95={pct(95):.2f}ms "
          f"p99={pct(99):.2f}ms max={busy[-1]:.2f}ms over16.7={100 * over / len(busy):.1f}%")
PY
fi

exit "$STATUS"
