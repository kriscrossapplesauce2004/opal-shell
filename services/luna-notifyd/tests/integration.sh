#!/usr/bin/env bash
# Integration test for luna-notifyd on a private session bus. It never touches the user's bus.
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
CRATE=$(cd "$HERE/.." && pwd)
HELPER="$HERE/shell_socket.py"

if [ -z "${LUNA_NOTIFYD_INNER:-}" ]; then
    command -v dbus-run-session >/dev/null || { echo "dbus-run-session is required" >&2; exit 2; }
    exec env LUNA_NOTIFYD_INNER=1 LUNA_NOTIFYD_OUTER_BUS="${DBUS_SESSION_BUS_ADDRESS:-}" \
        dbus-run-session -- bash "$0" "$@"
fi

for tool in cargo notify-send gdbus python3; do
    command -v "$tool" >/dev/null || { echo "missing tool: $tool" >&2; exit 2; }
done
if [ "${DBUS_SESSION_BUS_ADDRESS:-}" = "${LUNA_NOTIFYD_OUTER_BUS:-}" ]; then
    echo "refusing to run on the outer session bus" >&2
    exit 2
fi

WORK=$(mktemp -d "${TMPDIR:-/tmp}/luna-notifyd-it.XXXXXX")
export XDG_RUNTIME_DIR="$WORK/run"
mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"
SOCK="$XDG_RUNTIME_DIR/luna/notifyd.sock"
EVENTS="$WORK/events.jsonl"
SIGNALS="$WORK/signals.txt"
LOG="$WORK/daemon.log"
DAEMON_PID=""
TAIL_PID=""
MONITOR_PID=""
FAILED=0

cleanup() {
    [ -n "$MONITOR_PID" ] && kill "$MONITOR_PID" 2>/dev/null
    [ -n "${MONITOR2_PID:-}" ] && kill "$MONITOR2_PID" 2>/dev/null
    [ -n "$TAIL_PID" ] && kill "$TAIL_PID" 2>/dev/null
    [ -n "${OWNER1_PID:-}" ] && kill "$OWNER1_PID" 2>/dev/null
    [ -n "${OWNER2_PID:-}" ] && kill "$OWNER2_PID" 2>/dev/null
    [ -n "$DAEMON_PID" ] && kill "$DAEMON_PID" 2>/dev/null
    wait 2>/dev/null
    if [ "$FAILED" -eq 0 ]; then
        rm -rf "$WORK"
    else
        echo "logs kept in $WORK" >&2
    fi
}
trap cleanup EXIT

fail() {
    echo "FAIL: $*" >&2
    if [ -s "$LOG" ]; then sed 's/^/  daemon: /' "$LOG" >&2; fi
    FAILED=1
    exit 1
}

pass() { echo "ok - $*"; }

# expect DESCRIPTION PATTERN [SECONDS]: a matching event must appear in the stream.
expect() {
    python3 "$HELPER" wait "$EVENTS" "$2" "${3:-5}" >/dev/null || fail "$1"
    pass "$1"
}

# refute DESCRIPTION PATTERN START_LINE SECONDS: no matching event may appear after START_LINE.
refute() {
    python3 "$HELPER" refute "$EVENTS" "$2" "$3" "$4" || fail "$1"
    pass "$1"
}

# wait_signal DESCRIPTION FIXED_TEXT: a bus signal must appear in the gdbus monitor output.
wait_signal() {
    local end=$((SECONDS + 5))
    while [ "$SECONDS" -lt "$end" ]; do
        if grep -qF -- "$2" "$SIGNALS" 2>/dev/null; then pass "$1"; return; fi
        sleep 0.1
    done
    fail "$1 (missing: $2)"
}

# first_number TEXT: return the first unsigned integer in a gdbus reply.
first_number() { sed -E 's/.*uint32 ([0-9]+).*/\1/' <<<"$1"; }

# quoted_id TEXT: return the first single-quoted string in a gdbus reply.
quoted_id() { sed -E "s/.*'([^']*)'.*/\1/" <<<"$1"; }

notify_call() {
    gdbus call --session --dest org.freedesktop.Notifications \
        --object-path /org/freedesktop/Notifications \
        --method org.freedesktop.Notifications.Notify -- "$@"
}

send() { python3 "$HELPER" send "$SOCK" "$1"; }

echo "building luna-notifyd"
cargo build --quiet --manifest-path "$CRATE/Cargo.toml" || fail "cargo build"
BIN="$CRATE/target/debug/luna-notifyd"

"$BIN" >"$LOG" 2>&1 &
DAEMON_PID=$!
for _ in $(seq 1 50); do
    [ -S "$SOCK" ] && break
    sleep 0.1
done
[ -S "$SOCK" ] || fail "socket did not appear at $SOCK"
pass "daemon serves the private bus and $SOCK"

# A second instance must refuse the owned name and leave the socket alone.
if "$BIN" 2>"$WORK/second.log"; then fail "second instance started on an owned name"; fi
grep -q "owned by another process" "$WORK/second.log" || fail "second instance gave no clear error"
pass "second instance refuses the owned name without --replace"

python3 "$HELPER" tail "$SOCK" "$EVENTS" 120 &
TAIL_PID=$!
expect "hello is the first line" '{"type":"hello","version":1}' 5

gdbus monitor --session --dest org.freedesktop.Notifications >"$SIGNALS" 2>&1 &
MONITOR_PID=$!
gdbus monitor --session --dest dev.opal.Activities >>"$SIGNALS" 2>&1 &
MONITOR2_PID=$!
sleep 0.5

# Plain notifications and replacement in place.
ID1=$(notify_call "demo" 0 "" "First" "one" "[]" "{}" -1)
ID1=$(first_number "$ID1")
[ -n "$ID1" ] || fail "Notify returned no id"
expect "gdbus insert" \
    "{\"type\":\"inserted\",\"entity\":\"notification\",\"id\":$ID1,\"fields\":{\"summary\":\"First\",\"app_name\":\"demo\",\"popup\":true}}"

NS_ID=$(notify-send -p -a demo "Via notify-send" "from the CLI") || fail "notify-send failed"
[ -n "$NS_ID" ] || fail "notify-send printed no id"
expect "notify-send insert" \
    "{\"type\":\"inserted\",\"entity\":\"notification\",\"id\":$NS_ID,\"fields\":{\"summary\":\"Via notify-send\"}}"

ID2=$(first_number "$(notify_call "demo" "$ID1" "" "Replaced" "two" "[]" "{}" -1)")
[ "$ID2" = "$ID1" ] || fail "replacement returned $ID2, expected $ID1"
expect "replacement keeps the id and sends only the changed field" \
    "{\"type\":\"changed\",\"entity\":\"notification\",\"id\":$ID1,\"fields\":{\"summary\":\"Replaced\"}}"

# Actions and critical urgency.
IDA=$(first_number "$(notify_call "demo" 0 "" "Choose" "pick one" "['default', 'Open', 'later', 'Later']" "{'urgency': <byte 2>}" 0)")
expect "critical notification with actions and no timeout" \
    "{\"type\":\"inserted\",\"entity\":\"notification\",\"id\":$IDA,\"fields\":{\"urgency\":\"critical\",\"timeout_ms\":null,\"actions\":[{\"key\":\"default\",\"label\":\"Open\"},{\"key\":\"later\",\"label\":\"Later\"}]}}"
send "{\"type\":\"invoke\",\"id\":$IDA,\"action\":\"default\"}" >/dev/null
wait_signal "ActionInvoked signal on the bus" "ActionInvoked (uint32 $IDA, 'default')"
wait_signal "non-resident notification closes after its action with reason 2" "NotificationClosed (uint32 $IDA, uint32 2)"
expect "action removes the notification with reason dismissed" \
    "{\"type\":\"removed\",\"entity\":\"notification\",\"id\":$IDA,\"reason\":\"dismissed\"}"

# Expiry: a normal popup hides; a critical popup stays.
CRIT=$(first_number "$(notify_call "demo" 0 "" "Sticky" "stays" "[]" "{'urgency': <byte 2>}" -1)")
START=$(wc -l <"$EVENTS")
NORMAL=$(first_number "$(notify_call "demo" 0 "" "Timed" "goes away" "[]" "{}" -1)")
expect "normal popup expires after its default time" \
    "{\"type\":\"changed\",\"entity\":\"notification\",\"id\":$NORMAL,\"fields\":{\"popup\":false}}" 10
refute "critical popup never expires" \
    "{\"type\":\"changed\",\"entity\":\"notification\",\"id\":$CRIT,\"fields\":{\"popup\":false}}" "$START" 0

# Pause and resume the countdown.
PAUSED=$(first_number "$(notify_call "demo" 0 "" "Hover" "pause me" "[]" "{}" 3000)")
send "{\"type\":\"pause_expiry\",\"id\":$PAUSED}" >/dev/null
expect "pause is reported as a change" \
    "{\"type\":\"changed\",\"entity\":\"notification\",\"id\":$PAUSED,\"fields\":{\"expiry_paused\":true}}"
START=$(wc -l <"$EVENTS")
refute "a paused popup does not expire" \
    "{\"type\":\"changed\",\"entity\":\"notification\",\"id\":$PAUSED,\"fields\":{\"popup\":false}}" "$START" 3
send "{\"type\":\"resume_expiry\",\"id\":$PAUSED}" >/dev/null
expect "resumed popup expires" \
    "{\"type\":\"changed\",\"entity\":\"notification\",\"id\":$PAUSED,\"fields\":{\"popup\":false}}" 4

# Do-not-disturb keeps history and suppresses popups.
send '{"type":"set_dnd","on":true}' >/dev/null
expect "DND state event" '{"type":"state","dnd":true}'
QUIET=$(first_number "$(notify_call "demo" 0 "" "Quiet" "dnd" "[]" "{}" -1)")
expect "DND insert has no popup" \
    "{\"type\":\"inserted\",\"entity\":\"notification\",\"id\":$QUIET,\"fields\":{\"summary\":\"Quiet\",\"popup\":false}}"
send '{"type":"set_dnd","on":false}' >/dev/null
expect "DND off state event" '{"type":"state","dnd":false}'

# Close over the bus and dismiss over the socket.
gdbus call --session --dest org.freedesktop.Notifications --object-path /org/freedesktop/Notifications \
    --method org.freedesktop.Notifications.CloseNotification "$QUIET" >/dev/null || fail "CloseNotification call"
wait_signal "CloseNotification emits NotificationClosed reason 3" "NotificationClosed (uint32 $QUIET, uint32 3)"
expect "close removes the entry with reason closed" \
    "{\"type\":\"removed\",\"entity\":\"notification\",\"id\":$QUIET,\"reason\":\"closed\"}"
DISMISS=$(first_number "$(notify_call "demo" 0 "" "Dismiss me" "socket" "[]" "{}" -1)")
send "{\"type\":\"dismiss\",\"id\":$DISMISS}" >/dev/null
expect "socket dismiss removes the entry with reason dismissed" \
    "{\"type\":\"removed\",\"entity\":\"notification\",\"id\":$DISMISS,\"reason\":\"dismissed\"}"

# Live activities over dev.opal.Activities.
# A holder process keeps the bus name alive, so that the activity stays owned.
python3 "$HERE/activity_owner.py" '{"id":"cc-1","title":"Build","controls":[{"id":"stop","label":"Stop"}]}' \
    >"$WORK/owner1.out" 2>"$WORK/owner1.err" &
OWNER1_PID=$!
expect "activity insert" \
    '{"type":"inserted","entity":"activity","id":"cc-1","fields":{"title":"Build"}}'
gdbus call --session --dest dev.opal.Activities --object-path /dev/opal/Activities \
    --method dev.opal.Activities.Update "cc-1" '{"progress":0.5,"title":"Build 2"}' >/dev/null || fail "activity Update"
expect "activity update sends only changed fields" \
    '{"type":"changed","entity":"activity","id":"cc-1","fields":{"progress":0.5,"title":"Build 2"}}'
send '{"type":"invoke_activity","id":"cc-1","action":"stop"}' >/dev/null
wait_signal "activity ActionInvoked signal on dev.opal.Activities" "ActionInvoked ('cc-1', 'stop')"
gdbus call --session --dest dev.opal.Activities --object-path /dev/opal/Activities \
    --method dev.opal.Activities.End "cc-1" >/dev/null || fail "activity End"
expect "activity end" '{"type":"removed","entity":"activity","id":"cc-1","reason":"ended"}'

# An activity ends when the bus name that started it leaves the bus.
python3 "$HERE/activity_owner.py" '{"id":"cc-2"}' >"$WORK/owner2.out" 2>"$WORK/owner2.err" &
OWNER2_PID=$!
expect "owner-bound activity is inserted" '{"type":"inserted","entity":"activity","id":"cc-2"}'
kill "$OWNER2_PID" 2>/dev/null
expect "activity ends when its owner leaves the bus" \
    '{"type":"removed","entity":"activity","id":"cc-2","reason":"ended"}' 5

# Errors go only to the requesting client.
ERR=$(send '{"type":"explode"}')
grep -q '"type":"error"' <<<"$ERR" || fail "bad request did not return an error line"
pass "bad request returns an error line"

# A new client receives the current state first.
SNAP=$(python3 "$HELPER" snapshot "$SOCK") || fail "snapshot"
grep -q '"type":"snapshot","dnd":false' <<<"$SNAP" || fail "snapshot has the wrong header"
grep -q "\"id\":$PAUSED,\"fields\"" <<<"$SNAP" || fail "snapshot lacks a notification in history"
pass "new client gets a snapshot with the current history"

if grep -q -i "panic" "$LOG"; then fail "daemon panicked"; fi
pass "daemon log has no panic"
echo "all integration checks passed"
