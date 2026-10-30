//! Bus interfaces: org.freedesktop.Notifications and dev.opal.Activities.

use std::collections::HashMap;
use std::sync::mpsc::Sender;

use futures_channel::oneshot;
use futures_util::StreamExt;
use serde_json::{Map, Value};
use zbus::fdo::{self, RequestNameFlags, RequestNameReply};
use zbus::message::Header;
use zbus::zvariant::{OwnedValue, Value as ZValue};
use zbus::{interface, Connection, DBusError};

use crate::model::{Incoming, Urgency, MAX_ACTIONS, MAX_TEXT_CHARS};
use crate::service::Command;

pub const NOTIFY_NAME: &str = "org.freedesktop.Notifications";
pub const NOTIFY_PATH: &str = "/org/freedesktop/Notifications";
pub const ACTIVITY_NAME: &str = "dev.opal.Activities";
pub const ACTIVITY_PATH: &str = "/dev/opal/Activities";
const MAX_ACTIVITY_JSON: usize = 8192;

/// Errors that the activity methods return.
#[derive(DBusError, Debug)]
#[zbus(prefix = "dev.opal.Activities.Error")]
pub enum ActivityError {
    #[zbus(error)]
    ZBus(zbus::Error),
    Invalid(String),
}

/// The org.freedesktop.Notifications object.
pub struct Notifications {
    tx: Sender<Command>,
}

/// The dev.opal.Activities object.
pub struct Activities {
    tx: Sender<Command>,
}

#[interface(name = "org.freedesktop.Notifications")]
impl Notifications {
    async fn get_capabilities(&self) -> Vec<String> {
        ["actions", "body", "icon-static", "persistence"].iter().map(|name| name.to_string()).collect()
    }

    async fn get_server_information(&self) -> (String, String, String, String) {
        ("luna-notifyd".into(), "lunaOS".into(), env!("CARGO_PKG_VERSION").into(), "1.2".into())
    }

    #[allow(clippy::too_many_arguments)]
    async fn notify(
        &self,
        app_name: String,
        replaces_id: u32,
        app_icon: String,
        summary: String,
        body: String,
        actions: Vec<String>,
        hints: HashMap<String, OwnedValue>,
        expire_timeout: i32,
    ) -> fdo::Result<u32> {
        let note = incoming(app_name, replaces_id, app_icon, summary, body, actions, &hints, expire_timeout);
        ask(&self.tx, |reply| Command::Notify { note, reply }).await.map_err(fdo::Error::Failed)
    }

    async fn close_notification(&self, id: u32) -> fdo::Result<()> {
        ask(&self.tx, |reply| Command::Close { id, reply }).await.map_err(fdo::Error::Failed)
    }
}

#[interface(name = "dev.opal.Activities")]
impl Activities {
    async fn start(&self, json: String, #[zbus(header)] header: Header<'_>) -> Result<String, ActivityError> {
        let data = object(&json)?;
        let owner = header.sender().map(|name| name.to_string());
        ask(&self.tx, |reply| Command::ActivityStart { data, owner, reply }).await.map_err(ActivityError::Invalid)
    }

    async fn update(&self, id: String, json: String) -> Result<(), ActivityError> {
        let data = object(&json)?;
        ask(&self.tx, |reply| Command::ActivityUpdate { id: clip_id(id), data, reply }).await.map_err(ActivityError::Invalid)
    }

    async fn end(&self, id: String) -> Result<(), ActivityError> {
        ask(&self.tx, |reply| Command::ActivityEnd { id: clip_id(id), reply }).await.map_err(ActivityError::Invalid)
    }
}

/// Send a command and wait for its reply. A stopped service gives an error.
async fn ask<T>(tx: &Sender<Command>, build: impl FnOnce(oneshot::Sender<Result<T, String>>) -> Command) -> Result<T, String> {
    let (reply, answer) = oneshot::channel();
    tx.send(build(reply)).map_err(|_| "the service is stopping".to_string())?;
    answer.await.unwrap_or_else(|_| Err("the service did not reply".into()))
}

fn clip_id(id: String) -> String {
    id.chars().take(64).collect()
}

fn object(text: &str) -> Result<Map<String, Value>, ActivityError> {
    if text.len() > MAX_ACTIVITY_JSON {
        return Err(ActivityError::Invalid("The activity is too large".into()));
    }
    match serde_json::from_str::<Value>(text) {
        Ok(Value::Object(map)) => Ok(map),
        Ok(_) => Err(ActivityError::Invalid("The activity must be a JSON object".into())),
        Err(error) => Err(ActivityError::Invalid(format!("The activity is not valid JSON: {error}"))),
    }
}

fn clip(text: String) -> String {
    text.chars().take(MAX_TEXT_CHARS).collect()
}

#[allow(clippy::too_many_arguments)]
fn incoming(
    app_name: String,
    replaces_id: u32,
    app_icon: String,
    summary: String,
    body: String,
    actions: Vec<String>,
    hints: &HashMap<String, OwnedValue>,
    expire_timeout: i32,
) -> Incoming {
    let pairs = actions
        .chunks_exact(2)
        .take(MAX_ACTIONS)
        .map(|pair| (clip(pair[0].clone()), clip(pair[1].clone())))
        .collect();
    let (image_size, image_bytes) = image_data(hints).unwrap_or((None, 0));
    let sync_tag = first_text(hints, &["x-canonical-private-synchronous", "synchronous"]);
    Incoming {
        app_name: clip(app_name),
        app_icon: clip(app_icon),
        summary: clip(summary),
        body: clip(body),
        actions: pairs,
        urgency: hint_byte(hints, "urgency").map(Urgency::from_byte).unwrap_or_default(),
        category: hint_text(hints, "category"),
        desktop_entry: hint_text(hints, "desktop-entry"),
        image_path: first_text(hints, &["image-path", "image_path"]).unwrap_or_default(),
        image_size,
        image_bytes,
        transient: hint_bool(hints, "transient"),
        resident: hint_bool(hints, "resident"),
        sync_tag,
        expire_timeout,
        replaces_id,
    }
}

fn hint_text(hints: &HashMap<String, OwnedValue>, key: &str) -> String {
    hints.get(key).and_then(|value| String::try_from(value.clone()).ok()).map(clip).unwrap_or_default()
}

fn first_text(hints: &HashMap<String, OwnedValue>, keys: &[&str]) -> Option<String> {
    keys.iter().map(|key| hint_text(hints, key)).find(|text| !text.is_empty())
}

fn hint_bool(hints: &HashMap<String, OwnedValue>, key: &str) -> bool {
    hints.get(key).and_then(|value| bool::try_from(value.clone()).ok()).unwrap_or(false)
}

fn hint_byte(hints: &HashMap<String, OwnedValue>, key: &str) -> Option<u8> {
    let value = hints.get(key)?;
    u8::try_from(value.clone()).ok().or_else(|| i32::try_from(value.clone()).ok().and_then(|n| u8::try_from(n).ok()))
}

/// Read the size and byte count of image-data. The pixels are not kept.
fn image_data(hints: &HashMap<String, OwnedValue>) -> Option<(Option<(i32, i32)>, usize)> {
    let value = ["image-data", "image_data", "icon_data"].iter().find_map(|key| hints.get(*key))?;
    let ZValue::Structure(structure) = &**value else { return None };
    let fields = structure.fields();
    let width = i32::try_from(fields.first()?).ok()?;
    let height = i32::try_from(fields.get(1)?).ok()?;
    let bytes = match fields.get(6) {
        Some(ZValue::Array(array)) => array.len(),
        _ => 0,
    };
    Some((Some((width, height)), bytes))
}

/// Claim both well-known names. Without `replace`, an owned name is an error.
pub async fn connect(tx: Sender<Command>, replace: bool) -> Result<Connection, String> {
    let conn = zbus::connection::Builder::session()
        .map_err(bus_error)?
        .serve_at(NOTIFY_PATH, Notifications { tx: tx.clone() })
        .map_err(bus_error)?
        .serve_at(ACTIVITY_PATH, Activities { tx })
        .map_err(bus_error)?
        .build()
        .await
        .map_err(bus_error)?;
    claim(&conn, NOTIFY_NAME, replace).await?;
    claim(&conn, ACTIVITY_NAME, replace).await?;
    Ok(conn)
}

async fn claim(conn: &Connection, name: &str, replace: bool) -> Result<(), String> {
    let flags = if replace { RequestNameFlags::ReplaceExisting.into() } else { RequestNameFlags::DoNotQueue.into() };
    let taken = format!("{name} is owned by another process; start with --replace only for a private test bus");
    match conn.request_name_with_flags(name, flags).await {
        Ok(RequestNameReply::PrimaryOwner | RequestNameReply::AlreadyOwner) => Ok(()),
        Ok(RequestNameReply::InQueue | RequestNameReply::Exists) => Err(taken),
        Err(zbus::Error::NameTaken) => Err(taken),
        Err(error) => Err(bus_error(error)),
    }
}

fn bus_error(error: zbus::Error) -> String {
    format!("bus: {error}")
}

/// Report bus names that lose their owner, so that their activities end.
pub async fn watch_owners(conn: Connection, tx: Sender<Command>) -> zbus::Result<()> {
    let proxy = fdo::DBusProxy::new(&conn).await?;
    let mut changes = proxy.receive_name_owner_changed().await?;
    while let Some(signal) = changes.next().await {
        let args = signal.args()?;
        if args.new_owner().is_none() {
            let _ = tx.send(Command::BusNameGone { name: args.name().to_string() });
        }
    }
    Ok(())
}

pub async fn emit_closed(conn: &Connection, id: u32, code: u32) -> zbus::Result<()> {
    conn.emit_signal(None::<&str>, NOTIFY_PATH, NOTIFY_NAME, "NotificationClosed", &(id, code)).await
}

pub async fn emit_action(conn: &Connection, id: u32, key: &str) -> zbus::Result<()> {
    conn.emit_signal(None::<&str>, NOTIFY_PATH, NOTIFY_NAME, "ActionInvoked", &(id, key)).await
}

pub async fn emit_activity_action(conn: &Connection, id: &str, key: &str) -> zbus::Result<()> {
    conn.emit_signal(None::<&str>, ACTIVITY_PATH, ACTIVITY_NAME, "ActionInvoked", &(id, key)).await
}
