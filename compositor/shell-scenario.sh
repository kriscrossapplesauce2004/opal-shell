#!/usr/bin/env bash
# Scenario for run-shell.sh: compositor, Opal shell, test clients, IPC calls, screenshots. Runs on the private bus.
set -uo pipefail

: "${LUNA_RUN_ROOT:?run this through run-shell.sh}"
SOCKET=luna-0
SOCK_PATH="$XDG_RUNTIME_DIR/$SOCKET"
SHOTS="$LUNA_RUN_ROOT/shots"
LOG="$LUNA_OUT"
mkdir -p "$SHOTS"
rm -f "$LOG"/*.png "$LOG"/compositor.log "$LOG"/shell.log "$LOG"/frames.json
COMP_PID=""
SHELL_PID=""
CLIENT_PIDS=()
SHOT_N=0

comp_args=(--socket "$SOCKET" --frame-log "$LOG/frames.json" --exit-after $((LUNA_SECONDS * 1000))
    --shot-dir "$SHOTS")
if [[ "$LUNA_IMPL" == waylib ]]; then
    # wlroots backends: headless for tests, nested Wayland on the host session otherwise.
    if [[ "$LUNA_OFFSCREEN" == 1 ]]; then
        QT_FORCE_STDERR_LOGGING=1 "$LUNA_COMP_BIN" --backend headless "${comp_args[@]}" > "$LOG/compositor.log" 2>&1 &
    else
        QT_FORCE_STDERR_LOGGING=1 WAYLAND_DISPLAY="$LUNA_HOST_WAYLAND" \
            "$LUNA_COMP_BIN" --backend wayland "${comp_args[@]}" > "$LOG/compositor.log" 2>&1 &
    fi
elif [[ "$LUNA_OFFSCREEN" == 1 ]]; then
    QT_FORCE_STDERR_LOGGING=1 QT_QPA_PLATFORM=offscreen "$LUNA_COMP_BIN" "${comp_args[@]}" > "$LOG/compositor.log" 2>&1 &
else
    QT_FORCE_STDERR_LOGGING=1 WAYLAND_DISPLAY="$LUNA_HOST_WAYLAND" QT_QPA_PLATFORM=wayland \
        "$LUNA_COMP_BIN" "${comp_args[@]}" > "$LOG/compositor.log" 2>&1 &
fi
COMP_PID=$!

for _ in $(seq 100); do
    [[ -S "$SOCK_PATH" ]] && break
    sleep 0.1
done
[[ -S "$SOCK_PATH" ]] || { echo "socket $SOCK_PATH did not appear" >&2; cat "$LOG/compositor.log" >&2; exit 1; }
echo "compositor up on $SOCK_PATH (pid $COMP_PID)"

export WAYLAND_DISPLAY="$SOCKET"
export QT_QPA_PLATFORM=wayland

# Asks the compositor for a screenshot and stores it under a name.
shoot() {
    local name="$1" file
    SHOT_N=$((SHOT_N + 1))
    file="$(printf '%s/shot-%02d.png' "$SHOTS" "$SHOT_N")"
    kill -USR1 "$COMP_PID" 2>/dev/null || return
    for _ in $(seq 50); do
        [[ -s "$file" ]] && break
        sleep 0.1
    done
    if [[ -s "$file" ]]; then
        mv "$file" "$LOG/$name.png"
        echo "screenshot $LOG/$name.png"
    else
        echo "screenshot $name failed"
    fi
}

ipc() {
    timeout 5 qs -p "$LUNA_SRC" ipc call "$@" 2>&1 | sed 's/^/  ipc: /'
}

launch_client() {
    env -u DISPLAY qml6 "$LUNA_HERE/clients/test-client.qml" -- "$1" >> "$LOG/clients.log" 2>&1 &
    CLIENT_PIDS+=("$!")
}

# Extra clients: foot (needs wl_seat v5+) and one X11 client through Xwayland; runs before the lock.
run_extra() {
    [[ "$LUNA_EXTRA" == 1 && "$LUNA_IMPL" == waylib ]] || return 0
    local xdisplay x
    xdisplay="$(grep -o 'xwayland=[^ ]*' "$LOG/compositor.log" | head -1 | cut -d= -f2)"
    if command -v foot >/dev/null; then
        foot sh -c 'echo foot on luna-compositor; sleep 60' >> "$LOG/clients.log" 2>&1 &
        CLIENT_PIDS+=("$!")
    fi
    if [[ -n "$xdisplay" && "$xdisplay" != off ]]; then
        for x in glxgears xeyes xclock xterm xlogo; do
            if command -v "$x" >/dev/null; then
                env -u WAYLAND_DISPLAY DISPLAY="$xdisplay" "$x" >> "$LOG/clients.log" 2>&1 &
                CLIENT_PIDS+=("$!")
                echo "X11 client $x on $xdisplay"
                break
            fi
        done
    fi
    sleep 4
    shoot 09-extra
}

: > "$LOG/clients.log"
# Without --system-bus the shell gets a dead system bus, so its polkit agent cannot register for the live session.
shell_env=()
if [[ "$LUNA_SYSTEM_BUS" != 1 ]]; then
    shell_env=(DBUS_SYSTEM_BUS_ADDRESS="unix:path=$LUNA_RUN_ROOT/no-system-bus")
fi
env "${shell_env[@]}" quickshell -p "$LUNA_SRC" --no-color > "$LOG/shell.log" 2>&1 &
SHELL_PID=$!
echo "shell started (pid $SHELL_PID)"

if [[ "$LUNA_SCENARIO" == layers ]]; then
    # Layer-shell test shell: two clients tile beside the dock and under the bar.
    sleep 4
    launch_client A
    sleep 1
    launch_client B
    sleep 3
    shoot layers
elif [[ "$LUNA_SCENARIO" == 1 ]]; then
    sleep 10
    shoot 01-desktop
    for i in $(seq "$LUNA_CLIENTS"); do
        launch_client "$(echo ABCDEFGH | cut -c"$i")"
        sleep 1
    done
    sleep 3
    shoot 02-clients
    ipc opal launcher
    sleep 2
    shoot 03-launcher
    ipc opal close
    sleep 1
    ipc opal controls
    sleep 2
    shoot 04-controls
    ipc opal close
    sleep 1
    notify-send -a "Luna test" "Hello from luna-0" "A notification on the private bus" || echo "notify-send failed"
    sleep 2
    shoot 05-notification
    ipc opal notifications
    sleep 2
    shoot 06-notification-center
    ipc opal close
    sleep 1
    ipc opal windows
    shoot 07-final
    run_extra
    ipc opal lock
    sleep 3
    shoot 08-lock
fi


wait "$COMP_PID"
STATUS=$?
echo "compositor exited with status $STATUS"
for pid in "${CLIENT_PIDS[@]}" "$SHELL_PID"; do
    kill "$pid" 2>/dev/null || true
done
sleep 0.5
exit "$STATUS"
