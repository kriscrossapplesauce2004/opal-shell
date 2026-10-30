# luna-statusd

Status service for lunaOS. It reads battery, power profile, network and audio, and sends
typed changes to the shell. It is the first Rust service from the moonshot plan (section 28,
item 13). It replaces the status polling in `opal/src/backend.py` (Appendix A).

This crate is standalone. The Opal shell does not use it yet.

## Protocol

Transport: one JSON object per line (UTF-8, LF). A Unix socket at
`$XDG_RUNTIME_DIR/luna/statusd.sock` (the directory is mode 0700). The server sends; clients
only read. Protocol version: 1.

Every connection gets, in order:

1. `{"type":"hello","version":1}`
2. `{"type":"snapshot","state":{...}}`: the full status, once.
3. `{"type":"delta","changes":[...]}`: only the fields that changed. A delta is never empty.

Status shape (`null` means unknown or missing):

```json
{"battery":{"percent":81,"charging":false,"time_to_empty_s":5400},
 "power":{"profile":"balanced","ac_online":true},
 "network":{"kind":"wifi","ssid":"<name>","strength":58,"online":true},
 "audio":{"volume":88,"muted":false,"sink":"<device>"}}
```

- `power.profile`: `performance`, `balanced`, `power-saver`, `low-power`.
- `network.kind`: `wifi`, `ethernet`, `none`.

Change objects use `field` and `value`:

```json
{"type":"delta","changes":[{"field":"battery_percent","value":80},{"field":"network_kind","value":"ethernet"}]}
```

Fields: `battery_percent`, `battery_charging`, `battery_time_to_empty_s`, `power_profile`,
`power_ac_online`, `network_kind`, `network_ssid`, `network_strength`, `network_online`,
`audio_volume`, `audio_muted`, `audio_sink`.

Clients reconnect and read a new snapshot. There are no sequence numbers yet.

## Sources and rates

| Source | Reads | Rate |
|---|---|---|
| `/sys/class/power_supply/*/uevent` | battery percent, charging, time to empty, AC | 10 s |
| `powerprofilesctl get`, then `/sys/firmware/acpi/platform_profile` | power profile | 2 s |
| `/sys/class/net` operstate, then `nmcli -t` (device status, Wi-Fi list) | link kind, online, SSID, signal | 2 s |
| `wpctl get-volume` and `wpctl inspect` on `@DEFAULT_AUDIO_SINK@` | volume, mute, output name | 2 s |

Every command runs with an argument array (no shell). Each command has a 1 s timeout. A
missing command or tool gives unknown values. The service never changes device settings.

## Run

```sh
cargo run -- --stdout          # protocol on stdout, for testing
cargo run                      # serve on $XDG_RUNTIME_DIR/luna/statusd.sock
cargo test
```

## Not done yet

- Event sources replace polling: udev for power supply, NetworkManager D-Bus for network,
  PipeWire for audio. The poll timers in `src/main.rs` mark the places to change.
- The shell does not read the socket. `Hub.qml` and `backend.py` still poll.
- Not covered: per-device batteries (Bluetooth headsets), microphone mute, Wi-Fi radio and
  Bluetooth power, CPU governor, CPU and memory, brightness, uptime, media, pacman and camera
  activity. Section 28 item 2 moves CPU and memory to their own signal.
- No client messages. The protocol is read-only.
- A killed service leaves its socket file. The next start removes it after checking that
  no instance answers.
- Commands run one after another on the poll thread. Up to 1 s is lost per slow command.
- The protocol is binary-free JSON. Section 6.3 asks for a binary IPC later.
