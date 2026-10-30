//! Socket protocol: one JSON object per line, in both directions.

use serde::{Deserialize, Serialize};
use serde_json::{Map, Value};

/// Protocol version sent in `hello`. Change it on any wire change.
pub const PROTOCOL_VERSION: u32 = 1;
/// Longest request line that the server accepts, in bytes.
pub const MAX_LINE: usize = 4096;

/// An entry id. Notifications use numbers, activities use text.
#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
#[serde(untagged)]
pub enum Id {
    Num(u32),
    Text(String),
}

/// The kind of entry that a message is about.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum Entity {
    Notification,
    Activity,
}

/// One entry inside a snapshot.
#[derive(Clone, Debug, PartialEq, Serialize)]
pub struct Item {
    pub id: Id,
    pub fields: Map<String, Value>,
}

/// One message from the server. The `type` field selects the variant.
#[derive(Clone, Debug, PartialEq, Serialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum Message {
    /// First line of every connection.
    Hello { version: u32, server: &'static str },
    /// Full state, sent once after `hello`. Notifications keep their arrival order.
    Snapshot { dnd: bool, notifications: Vec<Item>, activities: Vec<Item> },
    /// A new entry, with all of its fields.
    Inserted { entity: Entity, id: Id, fields: Map<String, Value> },
    /// Only the fields that changed. A removed field has a null value.
    Changed { entity: Entity, id: Id, fields: Map<String, Value> },
    /// An entry that left the state, with the reason.
    Removed { entity: Entity, id: Id, reason: &'static str },
    /// The do-not-disturb state changed.
    State { dnd: bool },
    /// The last request failed. Only the requesting client receives it.
    Error { message: String },
}

/// One command from a client. The `type` field selects the variant.
#[derive(Clone, Debug, PartialEq, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum Request {
    /// The user dismissed a notification.
    Dismiss { id: u32 },
    /// The user pressed an action. A notification that is not resident is then dismissed.
    Invoke { id: u32, action: String },
    /// Freeze the popup countdown, for example while the pointer is over it.
    PauseExpiry { id: u32 },
    /// Continue a frozen popup countdown.
    ResumeExpiry { id: u32 },
    /// Turn do-not-disturb on or off.
    SetDnd { on: bool },
    /// Dismiss every history entry.
    ClearHistory,
    /// The user pressed a control on a live activity.
    InvokeActivity { id: String, action: String },
}

/// Parse one request line. Reject lines that are too long or malformed.
pub fn parse_request(line: &str) -> Result<Request, String> {
    if line.len() > MAX_LINE {
        return Err("line is too long".into());
    }
    serde_json::from_str(line).map_err(|error| format!("bad request: {error}"))
}

/// Encode one message as a single JSON line without the newline.
pub fn encode(message: &Message) -> String {
    serde_json::to_string(message).unwrap_or_else(|_| "{\"type\":\"error\",\"message\":\"encode failed\"}".into())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_every_request() {
        assert_eq!(parse_request(r#"{"type":"dismiss","id":4}"#), Ok(Request::Dismiss { id: 4 }));
        assert_eq!(
            parse_request(r#"{"type":"invoke","id":4,"action":"default"}"#),
            Ok(Request::Invoke { id: 4, action: "default".into() })
        );
        assert_eq!(parse_request(r#"{"type":"pause_expiry","id":4}"#), Ok(Request::PauseExpiry { id: 4 }));
        assert_eq!(parse_request(r#"{"type":"resume_expiry","id":4}"#), Ok(Request::ResumeExpiry { id: 4 }));
        assert_eq!(parse_request(r#"{"type":"set_dnd","on":true}"#), Ok(Request::SetDnd { on: true }));
        assert_eq!(parse_request(r#"{"type":"clear_history"}"#), Ok(Request::ClearHistory));
        assert_eq!(
            parse_request(r#"{"type":"invoke_activity","id":"cc-1","action":"stop"}"#),
            Ok(Request::InvokeActivity { id: "cc-1".into(), action: "stop".into() })
        );
    }

    #[test]
    fn rejects_unknown_and_oversized_requests() {
        assert!(parse_request(r#"{"type":"explode"}"#).is_err());
        assert!(parse_request("not json").is_err());
        let long = format!(r#"{{"type":"clear_history","pad":"{}"}}"#, "x".repeat(MAX_LINE));
        assert_eq!(parse_request(&long), Err("line is too long".into()));
    }

    #[test]
    fn encodes_a_tagged_line() {
        let line = encode(&Message::State { dnd: true });
        assert_eq!(line, r#"{"type":"state","dnd":true}"#);
        let removed = encode(&Message::Removed { entity: Entity::Notification, id: Id::Num(3), reason: "expired" });
        assert_eq!(removed, r#"{"type":"removed","entity":"notification","id":3,"reason":"expired"}"#);
    }
}
