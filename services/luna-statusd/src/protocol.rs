//! Typed status protocol: one JSON object per line.

use serde::{Deserialize, Serialize};

/// Protocol version sent in `hello`. Change it on any wire change.
pub const PROTOCOL_VERSION: u32 = 1;

/// Full status. Sent once per connection in a `snapshot`.
#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct Status {
    pub battery: Battery,
    pub power: Power,
    pub network: Network,
    pub audio: Audio,
}

/// Battery and charge state. A `null` field is unknown or missing.
#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct Battery {
    /// Charge level, 0 to 100.
    pub percent: Option<u8>,
    pub charging: Option<bool>,
    pub time_to_empty_s: Option<u32>,
}

/// Power profile and mains supply state.
#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct Power {
    pub profile: Option<PowerProfile>,
    pub ac_online: Option<bool>,
}

/// Network link state.
#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct Network {
    pub kind: NetworkKind,
    pub ssid: Option<String>,
    /// Wi-Fi signal, 0 to 100.
    pub strength: Option<u8>,
    /// True when any non-loopback interface is up.
    pub online: bool,
}

/// Default audio output state.
#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct Audio {
    /// Output volume in percent. Values above 100 mean amplification.
    pub volume: Option<u8>,
    pub muted: Option<bool>,
    /// Output device description.
    pub sink: Option<String>,
}

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum NetworkKind {
    Wifi,
    Ethernet,
    #[default]
    None,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum PowerProfile {
    Performance,
    Balanced,
    PowerSaver,
    LowPower,
}

/// One changed field. The wire form is `{"field":"...","value":...}`.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "field", content = "value", rename_all = "snake_case")]
pub enum Change {
    BatteryPercent(Option<u8>),
    BatteryCharging(Option<bool>),
    BatteryTimeToEmptyS(Option<u32>),
    PowerProfile(Option<PowerProfile>),
    PowerAcOnline(Option<bool>),
    NetworkKind(NetworkKind),
    NetworkSsid(Option<String>),
    NetworkStrength(Option<u8>),
    NetworkOnline(bool),
    AudioVolume(Option<u8>),
    AudioMuted(Option<bool>),
    AudioSink(Option<String>),
}

/// One line on the wire. The `type` field selects the variant.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum Message {
    /// First line of every connection.
    Hello { version: u32 },
    /// Full status, sent once after `hello`.
    Snapshot { state: Status },
    /// Only the fields that changed. Never empty.
    Delta { changes: Vec<Change> },
}

/// Return the fields that differ between two statuses.
pub fn diff(old: &Status, new: &Status) -> Vec<Change> {
    let mut out = Vec::new();
    if old.battery.percent != new.battery.percent {
        out.push(Change::BatteryPercent(new.battery.percent));
    }
    if old.battery.charging != new.battery.charging {
        out.push(Change::BatteryCharging(new.battery.charging));
    }
    if old.battery.time_to_empty_s != new.battery.time_to_empty_s {
        out.push(Change::BatteryTimeToEmptyS(new.battery.time_to_empty_s));
    }
    if old.power.profile != new.power.profile {
        out.push(Change::PowerProfile(new.power.profile));
    }
    if old.power.ac_online != new.power.ac_online {
        out.push(Change::PowerAcOnline(new.power.ac_online));
    }
    if old.network.kind != new.network.kind {
        out.push(Change::NetworkKind(new.network.kind));
    }
    if old.network.ssid != new.network.ssid {
        out.push(Change::NetworkSsid(new.network.ssid.clone()));
    }
    if old.network.strength != new.network.strength {
        out.push(Change::NetworkStrength(new.network.strength));
    }
    if old.network.online != new.network.online {
        out.push(Change::NetworkOnline(new.network.online));
    }
    if old.audio.volume != new.audio.volume {
        out.push(Change::AudioVolume(new.audio.volume));
    }
    if old.audio.muted != new.audio.muted {
        out.push(Change::AudioMuted(new.audio.muted));
    }
    if old.audio.sink != new.audio.sink {
        out.push(Change::AudioSink(new.audio.sink.clone()));
    }
    out
}

/// Encode one message as a JSON line with a trailing newline.
pub fn encode_line(message: &Message) -> String {
    // Protocol types always serialize, so this cannot fail.
    let mut line = serde_json::to_string(message).expect("protocol message serializes");
    line.push('\n');
    line
}

/// Decode one JSON line. The newline is optional.
#[cfg(test)]
pub fn decode_line(line: &str) -> Result<Message, serde_json::Error> {
    serde_json::from_str(line.trim_end())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample() -> Status {
        Status {
            battery: Battery {
                percent: Some(80),
                charging: Some(false),
                time_to_empty_s: Some(3600),
            },
            power: Power {
                profile: Some(PowerProfile::Balanced),
                ac_online: None,
            },
            network: Network {
                kind: NetworkKind::Wifi,
                ssid: Some("Home".into()),
                strength: Some(70),
                online: true,
            },
            audio: Audio {
                volume: Some(45),
                muted: Some(false),
                sink: Some("Speakers".into()),
            },
        }
    }

    #[test]
    fn identical_status_has_no_changes() {
        assert!(diff(&sample(), &sample()).is_empty());
    }

    #[test]
    fn single_field_change_yields_single_change() {
        let old = sample();
        let mut new = sample();
        new.battery.percent = Some(79);
        assert_eq!(diff(&old, &new), vec![Change::BatteryPercent(Some(79))]);
    }

    #[test]
    fn option_to_none_is_a_change() {
        let old = sample();
        let mut new = sample();
        new.network.ssid = None;
        new.audio.sink = None;
        assert_eq!(
            diff(&old, &new),
            vec![Change::NetworkSsid(None), Change::AudioSink(None)]
        );
    }

    #[test]
    fn change_wire_form_is_field_and_value() {
        let line = encode_line(&Message::Delta {
            changes: vec![
                Change::BatteryPercent(Some(80)),
                Change::NetworkKind(NetworkKind::Ethernet),
            ],
        });
        assert_eq!(
            line,
            "{\"type\":\"delta\",\"changes\":[{\"field\":\"battery_percent\",\"value\":80},{\"field\":\"network_kind\",\"value\":\"ethernet\"}]}\n"
        );
    }

    #[test]
    fn snapshot_round_trips_with_nulls() {
        let msg = Message::Snapshot {
            state: Status::default(),
        };
        let line = encode_line(&msg);
        assert!(line.contains("\"ssid\":null"));
        assert!(line.contains("\"kind\":\"none\""));
        assert_eq!(decode_line(&line).unwrap(), msg);
    }

    #[test]
    fn hello_and_profile_names_match_spec() {
        assert_eq!(
            encode_line(&Message::Hello {
                version: PROTOCOL_VERSION
            }),
            "{\"type\":\"hello\",\"version\":1}\n"
        );
        let profile = encode_line(&Message::Delta {
            changes: vec![Change::PowerProfile(Some(PowerProfile::PowerSaver))],
        });
        assert!(profile.contains("\"power-saver\""));
    }

    #[test]
    fn delta_round_trips() {
        let msg = Message::Delta {
            changes: vec![
                Change::AudioMuted(Some(true)),
                Change::BatteryTimeToEmptyS(None),
            ],
        };
        assert_eq!(decode_line(&encode_line(&msg)).unwrap(), msg);
    }
}
