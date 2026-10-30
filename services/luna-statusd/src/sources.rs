//! Read-only system sources. Each reader gives unknown values when its input is missing.

use std::collections::HashMap;
use std::fs;
use std::io::Read;
use std::process::{Command, Stdio};
use std::thread;
use std::time::{Duration, Instant};

use crate::protocol::{Audio, Battery, Network, NetworkKind, PowerProfile};

const POWER_SUPPLY_DIR: &str = "/sys/class/power_supply";
const NET_DIR: &str = "/sys/class/net";
const PLATFORM_PROFILE: &str = "/sys/firmware/acpi/platform_profile";
const COMMAND_TIMEOUT: Duration = Duration::from_secs(1);

/// Run a program with an argument array and return its stdout on success.
pub fn run(program: &str, args: &[&str]) -> Option<String> {
    let mut child = Command::new(program)
        .args(args)
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()
        .ok()?;
    let mut out = child.stdout.take()?;
    // Read on a thread so a full pipe cannot block the wait below.
    let reader = thread::spawn(move || {
        let mut text = String::new();
        let _ = out.read_to_string(&mut text);
        text
    });
    let deadline = Instant::now() + COMMAND_TIMEOUT;
    loop {
        match child.try_wait() {
            Ok(Some(status)) => {
                let text = reader.join().ok()?;
                return status.success().then_some(text);
            }
            Ok(None) if Instant::now() < deadline => thread::sleep(Duration::from_millis(10)),
            _ => {
                // Stop a command that hangs, so the poll loop keeps running.
                let _ = child.kill();
                let _ = child.wait();
                return None;
            }
        }
    }
}

/// One record from the power-supply class.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub enum SupplyKind {
    #[default]
    Other,
    Battery,
    Mains,
}

#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct Supply {
    pub kind: SupplyKind,
    pub present: bool,
    pub capacity: Option<u8>,
    pub status: String,
    pub time_to_empty_s: Option<u32>,
    pub online: Option<bool>,
}

/// Parse the `POWER_SUPPLY_*` lines of a power-supply `uevent` file.
pub fn parse_uevent(text: &str) -> Supply {
    let keys: HashMap<&str, &str> = text
        .lines()
        .filter_map(|line| line.strip_prefix("POWER_SUPPLY_"))
        .filter_map(|line| line.split_once('='))
        .map(|(key, value)| (key.trim(), value.trim()))
        .collect();
    let kind = match keys.get("TYPE").map(|t| t.to_ascii_lowercase()).as_deref() {
        Some("battery") => SupplyKind::Battery,
        Some("mains") => SupplyKind::Mains,
        _ => SupplyKind::Other,
    };
    Supply {
        kind,
        present: keys.get("PRESENT").is_none_or(|v| *v != "0"),
        capacity: keys
            .get("CAPACITY")
            .and_then(|v| v.parse::<u8>().ok())
            .filter(|v| *v <= 100),
        status: keys
            .get("STATUS")
            .copied()
            .unwrap_or("")
            .to_ascii_lowercase(),
        time_to_empty_s: keys
            .get("TIME_TO_EMPTY_NOW")
            .and_then(|v| v.parse::<u32>().ok())
            .filter(|v| *v > 0),
        online: keys.get("ONLINE").map(|v| *v == "1"),
    }
}

/// Combine all supplies into one battery view and one mains state.
pub fn summarize_power(supplies: &[Supply]) -> (Battery, Option<bool>) {
    let batteries: Vec<&Supply> = supplies
        .iter()
        .filter(|s| s.kind == SupplyKind::Battery && s.present && s.capacity.is_some())
        .collect();
    let battery = if batteries.is_empty() {
        Battery::default()
    } else {
        // Round the mean capacity half up.
        let sum: u32 = batteries
            .iter()
            .filter_map(|s| s.capacity)
            .map(u32::from)
            .sum();
        let count = batteries.len() as u32;
        let percent = ((sum + count / 2) / count) as u8;
        let charging = batteries.iter().any(|s| is_charging(&s.status));
        let times: Vec<u32> = batteries.iter().filter_map(|s| s.time_to_empty_s).collect();
        let time_to_empty_s = if charging || times.is_empty() {
            None
        } else {
            Some(times.iter().sum())
        };
        Battery {
            percent: Some(percent),
            charging: Some(charging),
            time_to_empty_s,
        }
    };
    let mains: Vec<&Supply> = supplies
        .iter()
        .filter(|s| s.kind == SupplyKind::Mains)
        .collect();
    let ac_online = if mains.is_empty() {
        None
    } else {
        Some(mains.iter().any(|s| s.online == Some(true)))
    };
    (battery, ac_online)
}

fn is_charging(status: &str) -> bool {
    matches!(status, "charging" | "pending-charge")
}

/// Read every power supply from sysfs. Missing sysfs gives unknown values.
pub fn read_power_supplies() -> (Battery, Option<bool>) {
    let Ok(entries) = fs::read_dir(POWER_SUPPLY_DIR) else {
        return summarize_power(&[]);
    };
    let supplies: Vec<Supply> = entries
        .flatten()
        .filter_map(|entry| fs::read_to_string(entry.path().join("uevent")).ok())
        .map(|text| parse_uevent(&text))
        .collect();
    summarize_power(&supplies)
}

/// Parse a power profile name from powerprofilesctl or platform_profile.
pub fn parse_profile(text: &str) -> Option<PowerProfile> {
    match text.trim() {
        "performance" => Some(PowerProfile::Performance),
        "balanced" => Some(PowerProfile::Balanced),
        "power-saver" => Some(PowerProfile::PowerSaver),
        "low-power" => Some(PowerProfile::LowPower),
        _ => None,
    }
}

/// Read the active power profile. powerprofilesctl comes first.
pub fn read_power_profile() -> Option<PowerProfile> {
    run("powerprofilesctl", &["get"])
        .as_deref()
        .and_then(parse_profile)
        .or_else(|| {
            fs::read_to_string(PLATFORM_PROFILE)
                .ok()
                .as_deref()
                .and_then(parse_profile)
        })
}

/// One non-loopback network interface from sysfs.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Iface {
    pub name: String,
    pub up: bool,
    pub wireless: bool,
}

/// Read network interfaces from sysfs, skipping loopback.
pub fn read_interfaces() -> Vec<Iface> {
    let Ok(entries) = fs::read_dir(NET_DIR) else {
        return Vec::new();
    };
    entries
        .flatten()
        .filter_map(|entry| {
            let name = entry.file_name().into_string().ok()?;
            if name == "lo" {
                return None;
            }
            let dir = entry.path();
            let up = fs::read_to_string(dir.join("operstate"))
                .map(|s| s.trim() == "up")
                .unwrap_or(false);
            let wireless = dir.join("wireless").exists() || dir.join("phy80211").exists();
            Some(Iface { name, up, wireless })
        })
        .collect()
}

/// Pick the link kind from sysfs alone. Wi-Fi wins over Ethernet.
pub fn kind_from_interfaces(ifaces: &[Iface]) -> NetworkKind {
    if ifaces.iter().any(|i| i.up && i.wireless) {
        NetworkKind::Wifi
    } else if ifaces.iter().any(|i| i.up) {
        NetworkKind::Ethernet
    } else {
        NetworkKind::None
    }
}

/// Split one `nmcli -t` line into fields. A backslash escapes the next character.
pub fn split_terse(line: &str) -> Vec<String> {
    let mut fields = Vec::new();
    let mut current = String::new();
    let mut chars = line.chars();
    while let Some(c) = chars.next() {
        match c {
            '\\' => current.extend(chars.next()),
            ':' => fields.push(std::mem::take(&mut current)),
            _ => current.push(c),
        }
    }
    fields.push(current);
    fields
}

/// Parse `nmcli -t -f DEVICE,TYPE,STATE device status`. Wi-Fi wins over Ethernet.
pub fn parse_nmcli_devices(text: &str) -> NetworkKind {
    let mut kind = NetworkKind::None;
    for line in text.lines() {
        let fields = split_terse(line);
        if fields.len() < 3 || !fields[2].starts_with("connected") {
            continue;
        }
        match fields[1].as_str() {
            "wifi" => return NetworkKind::Wifi,
            "ethernet" => kind = NetworkKind::Ethernet,
            _ => {}
        }
    }
    kind
}

/// Parse `nmcli -t -f IN-USE,SIGNAL,SSID device wifi list`. Return the active network.
pub fn parse_nmcli_wifi(text: &str) -> (Option<String>, Option<u8>) {
    let active = text
        .lines()
        .map(split_terse)
        .find(|f| f.len() >= 3 && f[0] == "*");
    match active {
        Some(fields) => {
            let ssid = Some(fields[2].clone()).filter(|s| !s.is_empty());
            let strength = fields[1].parse::<u8>().ok().map(|v| v.min(100));
            (ssid, strength)
        }
        None => (None, None),
    }
}

/// Read the network state. nmcli adds the Wi-Fi name and signal when present.
pub fn read_network() -> Network {
    let ifaces = read_interfaces();
    let online = ifaces.iter().any(|i| i.up);
    let mut kind = kind_from_interfaces(&ifaces);
    let mut ssid = None;
    let mut strength = None;
    if let Some(text) = run(
        "nmcli",
        &["-t", "-f", "DEVICE,TYPE,STATE", "device", "status"],
    ) {
        kind = parse_nmcli_devices(&text);
        if kind == NetworkKind::Wifi {
            let list = run(
                "nmcli",
                &[
                    "-t",
                    "-f",
                    "IN-USE,SIGNAL,SSID",
                    "device",
                    "wifi",
                    "list",
                    "--rescan",
                    "no",
                ],
            );
            if let Some(list) = list {
                (ssid, strength) = parse_nmcli_wifi(&list);
            }
        }
    }
    Network {
        kind,
        ssid,
        strength,
        online,
    }
}

/// Parse `wpctl get-volume` output. Return the percent and the mute flag.
pub fn parse_volume(text: &str) -> Option<(u8, bool)> {
    let mut parts = text.split_whitespace();
    if parts.next()? != "Volume:" {
        return None;
    }
    let level: f64 = parts.next()?.parse().ok()?;
    if !level.is_finite() {
        return None;
    }
    let percent = (level * 100.0).round().clamp(0.0, 150.0) as u8;
    Some((percent, text.contains("[MUTED]")))
}

/// Parse the `node.description` value from `wpctl inspect` output.
pub fn parse_sink(text: &str) -> Option<String> {
    let line = text.lines().find(|l| l.contains("node.description"))?;
    let first = line.find('"')?;
    let last = line.rfind('"')?;
    if last <= first {
        return None;
    }
    Some(line[first + 1..last].to_string())
}

/// Read the default output through wpctl. Missing wpctl gives unknown values.
pub fn read_audio() -> Audio {
    let volume = run("wpctl", &["get-volume", "@DEFAULT_AUDIO_SINK@"])
        .as_deref()
        .and_then(parse_volume);
    match volume {
        Some((percent, muted)) => {
            let sink = run("wpctl", &["inspect", "@DEFAULT_AUDIO_SINK@"])
                .as_deref()
                .and_then(parse_sink);
            Audio {
                volume: Some(percent),
                muted: Some(muted),
                sink,
            }
        }
        None => Audio::default(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const BATTERY_DISCHARGING: &str = "\
POWER_SUPPLY_NAME=BAT0
POWER_SUPPLY_TYPE=Battery
POWER_SUPPLY_STATUS=Discharging
POWER_SUPPLY_PRESENT=1
POWER_SUPPLY_CAPACITY=81
POWER_SUPPLY_TIME_TO_EMPTY_NOW=5400
";

    const MAINS_ONLINE: &str =
        "POWER_SUPPLY_NAME=AC\nPOWER_SUPPLY_TYPE=Mains\nPOWER_SUPPLY_ONLINE=1\n";

    #[test]
    fn uevent_battery_fields_parse() {
        let s = parse_uevent(BATTERY_DISCHARGING);
        assert_eq!(s.kind, SupplyKind::Battery);
        assert_eq!(s.capacity, Some(81));
        assert_eq!(s.status, "discharging");
        assert_eq!(s.time_to_empty_s, Some(5400));
        assert!(s.present);
    }

    #[test]
    fn uevent_rejects_bad_capacity_and_zero_time() {
        let s = parse_uevent("POWER_SUPPLY_TYPE=Battery\nPOWER_SUPPLY_CAPACITY=140\nPOWER_SUPPLY_TIME_TO_EMPTY_NOW=0\n");
        assert_eq!(s.capacity, None);
        assert_eq!(s.time_to_empty_s, None);
    }

    #[test]
    fn summary_reads_battery_and_mains() {
        let supplies = vec![
            parse_uevent(BATTERY_DISCHARGING),
            parse_uevent(MAINS_ONLINE),
        ];
        let (battery, ac) = summarize_power(&supplies);
        assert_eq!(battery.percent, Some(81));
        assert_eq!(battery.charging, Some(false));
        assert_eq!(battery.time_to_empty_s, Some(5400));
        assert_eq!(ac, Some(true));
    }

    #[test]
    fn summary_without_supplies_is_unknown() {
        let (battery, ac) = summarize_power(&[]);
        assert_eq!(battery, Battery::default());
        assert_eq!(ac, None);
    }

    #[test]
    fn summary_charging_hides_time_and_averages() {
        let charging = "POWER_SUPPLY_TYPE=Battery\nPOWER_SUPPLY_STATUS=Charging\nPOWER_SUPPLY_CAPACITY=50\nPOWER_SUPPLY_TIME_TO_EMPTY_NOW=900\n";
        let full =
            "POWER_SUPPLY_TYPE=Battery\nPOWER_SUPPLY_STATUS=Full\nPOWER_SUPPLY_CAPACITY=100\n";
        let supplies = vec![
            parse_uevent(charging),
            parse_uevent(full),
            parse_uevent(MAINS_ONLINE.replace("=1", "=0").as_str()),
        ];
        let (battery, ac) = summarize_power(&supplies);
        assert_eq!(battery.percent, Some(75));
        assert_eq!(battery.charging, Some(true));
        assert_eq!(battery.time_to_empty_s, None);
        assert_eq!(ac, Some(false));
    }

    #[test]
    fn profile_names_parse() {
        assert_eq!(parse_profile("balanced\n"), Some(PowerProfile::Balanced));
        assert_eq!(parse_profile("power-saver"), Some(PowerProfile::PowerSaver));
        assert_eq!(parse_profile("low-power"), Some(PowerProfile::LowPower));
        assert_eq!(parse_profile("turbo"), None);
    }

    #[test]
    fn wpctl_volume_parses_plain_and_muted() {
        assert_eq!(parse_volume("Volume: 0.45\n"), Some((45, false)));
        assert_eq!(parse_volume("Volume: 0.00 [MUTED]\n"), Some((0, true)));
        assert_eq!(parse_volume("Volume: 1.30\n"), Some((130, false)));
        assert_eq!(parse_volume("Volume: 9.99\n"), Some((150, false)));
    }

    #[test]
    fn wpctl_volume_rejects_garbage() {
        assert_eq!(parse_volume(""), None);
        assert_eq!(parse_volume("Volume: NaN"), None);
        assert_eq!(parse_volume("Level: 0.5"), None);
    }

    #[test]
    fn wpctl_inspect_gives_sink_description() {
        let text = "id 52, type PipeWire:Interface:Node\n  * node.description = \"Built-in Audio Analog Stereo\"\n    node.name = \"alsa_output.pci\"\n";
        assert_eq!(
            parse_sink(text).as_deref(),
            Some("Built-in Audio Analog Stereo")
        );
        assert_eq!(parse_sink("node.name = \"x\""), None);
    }

    #[test]
    fn nmcli_device_status_prefers_wifi() {
        let text = "wlan0:wifi:connected\ntailscale0:tun:connected (externally)\nenp4s0:ethernet:unavailable\n";
        assert_eq!(parse_nmcli_devices(text), NetworkKind::Wifi);
        assert_eq!(
            parse_nmcli_devices("enp4s0:ethernet:connected\n"),
            NetworkKind::Ethernet
        );
        assert_eq!(
            parse_nmcli_devices("wlan0:wifi:disconnected\n"),
            NetworkKind::None
        );
    }

    #[test]
    fn nmcli_wifi_list_reads_active_row_with_escaped_colon() {
        let text = "no:61:Office\n*:78:Cafe\\:Guest\n";
        assert_eq!(
            parse_nmcli_wifi(text),
            (Some("Cafe:Guest".to_string()), Some(78))
        );
        assert_eq!(parse_nmcli_wifi("no:61:Office\n"), (None, None));
    }

    #[test]
    fn terse_split_handles_escapes_and_empty_fields() {
        assert_eq!(split_terse("a:b\\:c:"), vec!["a", "b:c", ""]);
    }

    #[test]
    fn interfaces_pick_kind_without_nmcli() {
        let ifaces = vec![
            Iface {
                name: "enp4s0".into(),
                up: true,
                wireless: false,
            },
            Iface {
                name: "wlan0".into(),
                up: false,
                wireless: true,
            },
        ];
        assert_eq!(kind_from_interfaces(&ifaces), NetworkKind::Ethernet);
        let wifi = vec![Iface {
            name: "wlan0".into(),
            up: true,
            wireless: true,
        }];
        assert_eq!(kind_from_interfaces(&wifi), NetworkKind::Wifi);
        assert_eq!(kind_from_interfaces(&[]), NetworkKind::None);
    }
}
