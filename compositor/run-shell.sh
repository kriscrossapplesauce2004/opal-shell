#!/usr/bin/env bash
# Run the full Opal shell (Quickshell, opal/src) as a client inside luna-compositor, isolated from the live session.
# Usage: run-shell.sh [--impl waylib|qt] [--offscreen] [--seconds N] [--out DIR] [--clients N] [--snapshot] [--src DIR] [--no-scenario]
#   --impl NAME    waylib (default): luna-compositor on the waylib fork; qt: luna-compositor-qt (QtWaylandCompositor)
#   --offscreen    no window on screen (waylib: headless backend; qt: offscreen platform); default when no host Wayland
#   --seconds N    stop after N seconds (default 40)
#   --out DIR      screenshots, logs and frames.json go here (default build/shell-run)
#   --clients N    number of test clients to start (default 3)
#   --snapshot     copy opal/src into the temp root first, so edits by others do not reload the shell mid-run
#   --src DIR      shell source folder (default opal/src)
#   --no-scenario  start the shell and clients only; take no screenshots and send no IPC calls
#   --layer-test   run the small layer-shell test shell (clients/layer-test) instead of Opal
#   --system-bus   let the shell reach the system bus (status data; its polkit agent may then register)
#   --extra        after the scenario, also start foot and one X11 client (glxgears), waylib only
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPAL="$(cd "$HERE/.." && pwd)"
BUILD="$HERE/build"

# The inner part runs inside the private D-Bus session; the outer part prepares and cleans up.
if [[ "${1:-}" == "--inner" ]]; then
    shift
    # shellcheck source=/dev/null
    source "$LUNA_RUN_ROOT/env.sh"
    exec bash "$HERE/shell-scenario.sh" "$@"
fi

IMPL=waylib
EXTRA=0
OFFSCREEN=0
RUN_SECONDS=40
OUT="$BUILD/shell-run"
CLIENTS=3
SNAPSHOT=0
SRC="$OPAL/src"
SCENARIO=1
SYSTEM_BUS=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --impl) IMPL="$2"; shift ;;
        --extra) EXTRA=1 ;;
        --offscreen) OFFSCREEN=1 ;;
        --seconds) RUN_SECONDS="$2"; shift ;;
        --out) OUT="$2"; shift ;;
        --clients) CLIENTS="$2"; shift ;;
        --snapshot) SNAPSHOT=1 ;;
        --src) SRC="$(realpath "$2")"; shift ;;
        --no-scenario) SCENARIO=0 ;;
        --layer-test) SCENARIO=layers; SRC="$HERE/clients/layer-test" ;;
        --system-bus) SYSTEM_BUS=1 ;;
        -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done

case "$IMPL" in
    waylib) COMP_BIN="$BUILD/luna-compositor" ;;
    qt) COMP_BIN="$BUILD/luna-compositor-qt" ;;
    *) echo "unknown --impl: $IMPL (waylib or qt)" >&2; exit 2 ;;
esac

HOST_WAYLAND=""
if [[ $OFFSCREEN -eq 0 ]]; then
    if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
        echo "No host Wayland session; using --offscreen." >&2
        OFFSCREEN=1
    else
        # An absolute path keeps the host socket reachable after XDG_RUNTIME_DIR changes.
        case "$WAYLAND_DISPLAY" in
            /*) HOST_WAYLAND="$WAYLAND_DISPLAY" ;;
            *) HOST_WAYLAND="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/$WAYLAND_DISPLAY" ;;
        esac
    fi
fi

cmake -S "$HERE" -B "$BUILD" -G Ninja -DCMAKE_BUILD_TYPE=Release >/dev/null
cmake --build "$BUILD" >/dev/null

mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
ROOT="$(mktemp -d "${TMPDIR:-/tmp}/luna-shell.XXXXXX")"
# Socket paths have a 108-byte limit, so the runtime folder and the bus live in a short path.
RT="$(mktemp -d /tmp/luna-rt.XXXXXX)"
mkdir -p "$ROOT/home/.local/state/opal" "$ROOT/home/.config" "$ROOT/home/.local/share" "$ROOT/home/.cache" \
    "$RT/runtime" "$RT/bus"
chmod 700 "$RT" "$RT/runtime"

if [[ $SNAPSHOT -eq 1 ]]; then
    cp -a "$SRC" "$ROOT/src"
    SRC="$ROOT/src"
fi

# Seed preferences: setup done, desktop mode, the user's colours only. Link stays off, so no network port is taken.
python3 -I - "$HOME/.local/state/opal/preferences.json" "$ROOT/home/.local/state/opal/preferences.json" <<'PY'
import json, pathlib, sys
seed = {'onboarded': True, 'mode': 'desktop', 'linkEnabled': False, 'pinsConfigured': False}
try:
    saved = json.loads(pathlib.Path(sys.argv[1]).read_text())
    for key in ('palette', 'light', 'dynamicColors', 'dynamicPalette', 'colorScheme', 'barStyle', 'iconStyle', 'glass'):
        if key in saved:
            seed[key] = saved[key]
except (OSError, ValueError):
    pass
pathlib.Path(sys.argv[2]).write_text(json.dumps(seed))
PY

# Read-only assets: icons, fonts, desktop entries. Nothing in the real home is written.
for rel in .local/share/icons .local/share/fonts .local/share/applications .config/fontconfig; do
    if [[ -e "$HOME/$rel" ]]; then
        mkdir -p "$(dirname "$ROOT/home/$rel")"
        ln -s "$HOME/$rel" "$ROOT/home/$rel"
    fi
done

# A private bus with no service directories: nothing is auto-started, no live bus name is taken.
cat > "$ROOT/bus.conf" <<EOF
<!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-Bus Bus Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig>
  <type>session</type>
  <keep_umask/>
  <listen>unix:dir=$RT/bus</listen>
  <auth>EXTERNAL</auth>
  <policy context="default">
    <allow send_destination="*" eavesdrop="true"/>
    <allow eavesdrop="true"/>
    <allow own="*"/>
  </policy>
</busconfig>
EOF

cat > "$ROOT/env.sh" <<EOF
export LUNA_RUN_ROOT="$ROOT"
export LUNA_HERE="$HERE"
export LUNA_BUILD="$BUILD"
export LUNA_IMPL="$IMPL"
export LUNA_COMP_BIN="$COMP_BIN"
export LUNA_EXTRA="$EXTRA"
export LUNA_OUT="$OUT"
export LUNA_SRC="$SRC"
export LUNA_SECONDS="$RUN_SECONDS"
export LUNA_CLIENTS="$CLIENTS"
export LUNA_OFFSCREEN="$OFFSCREEN"
export LUNA_HOST_WAYLAND="$HOST_WAYLAND"
export LUNA_SCENARIO="$SCENARIO"
export LUNA_SYSTEM_BUS="$SYSTEM_BUS"
export HOME="$ROOT/home"
export XDG_CONFIG_HOME="$ROOT/home/.config"
export XDG_STATE_HOME="$ROOT/home/.local/state"
export XDG_DATA_HOME="$ROOT/home/.local/share"
export XDG_CACHE_HOME="$ROOT/home/.cache"
export XDG_RUNTIME_DIR="$RT/runtime"
export OPAL_STATE_DIR="$ROOT/home/.local/state/opal"
export XDG_CURRENT_DESKTOP=Luna
export XDG_SESSION_DESKTOP=luna
export XDG_SESSION_TYPE=wayland
EOF

echo "compositor: $IMPL ($COMP_BIN)"
echo "isolated root: $ROOT"
echo "output: $OUT"

# Every process of the run carries LUNA_RUN_ROOT, so cleanup finds exactly our own processes.
cleanup() {
    local pids pid
    if [[ -n "${RUN_PGID:-}" ]]; then
        kill -TERM -- "-$RUN_PGID" 2>/dev/null || true
    fi
    sleep 1
    pids="$(grep -lsz "^LUNA_RUN_ROOT=$ROOT\$" /proc/[0-9]*/environ 2>/dev/null | cut -d/ -f3 || true)"
    for pid in $pids; do
        [[ "$pid" == "$$" ]] && continue
        kill -KILL "$pid" 2>/dev/null || true
    done
    sleep 0.3
    left="$(grep -lsz "^LUNA_RUN_ROOT=$ROOT\$" /proc/[0-9]*/environ 2>/dev/null | cut -d/ -f3 | tr '\n' ' ' || true)"
    echo "processes left from this run: ${left:-none}"
    rm -rf "$RT"
}
trap cleanup EXIT

# The run gets its own process group, so one signal reaches every process it started.
env -u DISPLAY -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE -u XDG_SESSION_ID -u DBUS_SESSION_BUS_ADDRESS \
    -u QT_QPA_PLATFORMTHEME -u SWAYSOCK -u NIRI_SOCKET -u QS_CONFIG_PATH -u QS_CONFIG_NAME \
    LUNA_RUN_ROOT="$ROOT" \
    setsid dbus-run-session --config-file="$ROOT/bus.conf" -- bash "$0" --inner &
RUN_PID=$!
RUN_PGID=$RUN_PID
STATUS=0
wait "$RUN_PID" || STATUS=$?
echo "run exited with status $STATUS"

# Frame summary: busy frames are intervals of 100 ms or less; longer gaps are idle time.
if [[ -f "$OUT/frames.json" ]]; then
    python3 -I - "$OUT/frames.json" <<'PY2'
import json, statistics, sys
data = json.load(open(sys.argv[1]))
intervals = data["intervals_ms"]
busy = sorted(v for v in intervals if v <= 100.0)
print(f"frames={len(intervals)} idle_gaps_over_100ms={len(intervals) - len(busy)} backend={data['backend']}")
if len(busy) >= 2:
    def pct(p):
        rank = p / 100 * (len(busy) - 1)
        lo = int(rank)
        hi = min(lo + 1, len(busy) - 1)
        return busy[lo] + (busy[hi] - busy[lo]) * (rank - lo)
    over = sum(1 for v in busy if v > data["budget_ms"])
    print(f"busy frames: median={statistics.median(busy):.2f}ms p95={pct(95):.2f}ms p99={pct(99):.2f}ms "
          f"max={busy[-1]:.2f}ms over{data['budget_ms']}={100 * over / len(busy):.1f}%")
PY2
fi
exit "$STATUS"
