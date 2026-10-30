# luna-notifyd

luna-notifyd is the lunaOS notification service. It serves the freedesktop
notification interface and the live activity API on the session bus. The shell
reads a typed, incremental event stream over a Unix socket.

## Run

```sh
cargo build
cargo run -- --help
```

By default the service refuses to start when `org.freedesktop.Notifications` or
`dev.opal.Activities` already has an owner. `--replace` takes the names from
their owner. Use `--replace` only on a private test bus, never on a real session
bus where another notification daemon runs.

The socket is `$XDG_RUNTIME_DIR/luna/notifyd.sock`, with mode 0700 on its
directory. A socket that answers means another instance runs, and the new
instance refuses to start. A stale socket is removed.

## Bus interfaces

`org.freedesktop.Notifications` at `/org/freedesktop/Notifications`:

- `GetCapabilities`: actions, body, icon-static, persistence.
- `GetServerInformation`: `luna-notifyd`, `lunaOS`, the crate version, `1.2`.
- `Notify`: honors `replaces_id`, `expire_timeout`, and the hints `urgency`,
  `category`, `desktop-entry`, `image-path`, `image-data` (size and byte count
  only, the pixels are not kept), `transient`, `resident` and
  `x-canonical-private-synchronous`.
- `CloseNotification`: removes the entry with reason 3 (closed).
- Signals `NotificationClosed` (reason codes 1 to 4) and `ActionInvoked`.

`dev.opal.Activities` at `/dev/opal/Activities`, with the same method names and
signatures as `activity_dbus.py`:

- `Start(s json) -> s id`: uses the `id` field of the JSON when present.
- `Update(s id, s json)`: merges top-level fields. A null value removes a field.
- `End(s id)`.
- Signal `ActionInvoked(s id, s action)`.

An activity ends when the bus name that started it leaves the bus.

## Model limits

These limits come from `opal/src/Notifier.qml`:

- Popup queue: at most 8 popups. The oldest popups are hidden first.
- History: at most 100 entries that are not transient. The oldest entries are evicted.
- Popup time: default 6500 ms, minimum 1000 ms. `expire_timeout` 0 and critical
  urgency never expire.
- Activities: at most 16. Each JSON object is at most 8192 bytes.
- Text fields are cut at 4096 characters. Actions are cut at 8 pairs.

Other rules:

- Replacement keeps the id and the position. Its popup shows again unless DND is on.
- Do-not-disturb keeps the history and hides every popup. Critical popups are
  also hidden, as in `Notifier.qml`.
- A transient notification is removed when its popup ends, or at once when no popup is shown.
- A non-resident notification is dismissed (reason 2) after an action is invoked.
- The history is session-only. Nothing is written to disk.

## Socket protocol

Each line is one JSON object with a `type` field. Lines are at most 4096 bytes
in each direction. Notifications have numeric ids. Activities have text ids.

On connect the server sends:

1. `{"type":"hello","version":1,"server":"luna-notifyd"}`
2. `{"type":"snapshot","dnd":false,"notifications":[{"id":1,"fields":{...}}],"activities":[{"id":"cc-1","fields":{...}}]}`

Then, for every change:

- `{"type":"inserted","entity":"notification","id":1,"fields":{...all fields...}}`
- `{"type":"changed","entity":"notification","id":1,"fields":{"summary":"new"}}`
  only the fields that changed. A removed field has a null value.
- `{"type":"removed","entity":"notification","id":1,"reason":"expired"}`
  reasons: `expired`, `dismissed`, `closed`, `evicted`, `ended`.
- `{"type":"state","dnd":true}` when do-not-disturb changes.

Entities are `notification` and `activity`. Activity events use `"entity":"activity"`.

Notification fields: `app_name`, `app_icon`, `summary`, `body`, `actions`
(a list of `{key,label}`), `urgency`, `category`, `desktop_entry`,
`image_path`, `image_size`, `image_bytes`, `transient`, `resident`,
`timeout_ms` (null means never), `popup`, `expiry_paused`, `received_ms`.

Errors go only to the client that sent the bad request:
`{"type":"error","message":"..."}`.

Client requests (one JSON object per line):

| Request | Effect |
| --- | --- |
| `{"type":"dismiss","id":1}` | Remove with reason `dismissed`. |
| `{"type":"invoke","id":1,"action":"default"}` | Emit `ActionInvoked`. Dismiss unless resident. |
| `{"type":"pause_expiry","id":1}` | Freeze the popup countdown, for example on hover. |
| `{"type":"resume_expiry","id":1}` | Continue the countdown. |
| `{"type":"set_dnd","on":true}` | Turn do-not-disturb on or off. |
| `{"type":"clear_history"}` | Dismiss every non-transient entry. |
| `{"type":"invoke_activity","id":"cc-1","action":"stop"}` | Emit the activity `ActionInvoked` signal. |

The shell can follow the stream after the snapshot. A client that falls more
than 1024 lines behind is disconnected.

## Tests

```sh
cargo test                       # model and protocol unit tests
cargo clippy --all-targets       # lints
bash tests/integration.sh        # private bus, real notify-send and gdbus calls
```

`tests/integration.sh` re-runs itself under `dbus-run-session` with its own
`XDG_RUNTIME_DIR`. It refuses to run on the outer bus. The helpers are
`tests/shell_socket.py` (socket reader and matcher) and `tests/activity_owner.py`
(a process that holds an activity's bus name).

## Not included

- Activity `ttl` is stored as data but not enforced.
- The notification centre state (open, read) is not modelled.
- Image pixels are not stored or served. Only size and byte count are kept.
- The shell does not use this service yet. `opal/src/Notifier.qml` and
  `opal/src/activity_dbus.py` still run.
