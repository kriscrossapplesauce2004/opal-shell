//! Pure model of notifications and live activities. It has no bus, clock or I/O.

use serde_json::{json, Map, Value};

use crate::protocol::{Entity, Id, Item, Message};

// Limits come from Notifier.qml: eight queued popups and a history of 100.
pub const POPUP_QUEUE: usize = 8;
pub const HISTORY_LIMIT: usize = 100;
// Default and minimum popup time, in milliseconds, as in Notifier.qml.
pub const DEFAULT_EXPIRE_MS: i64 = 6500;
pub const MIN_EXPIRE_MS: i64 = 1000;
pub const MAX_ACTIVITIES: usize = 16;
pub const MAX_TEXT_CHARS: usize = 4096;
pub const MAX_ACTIONS: usize = 8;
const MAX_ID_CHARS: usize = 64;

/// Notification urgency from the freedesktop hint.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub enum Urgency {
    Low,
    #[default]
    Normal,
    Critical,
}

impl Urgency {
    /// Map the urgency byte. Unknown values count as normal.
    pub fn from_byte(value: u8) -> Self {
        match value {
            0 => Self::Low,
            2 => Self::Critical,
            _ => Self::Normal,
        }
    }

    fn name(self) -> &'static str {
        match self {
            Self::Low => "low",
            Self::Normal => "normal",
            Self::Critical => "critical",
        }
    }
}

/// Why an entry left the model.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Reason {
    Expired,
    Dismissed,
    Closed,
    Evicted,
    Ended,
}

impl Reason {
    /// The reason name used on the socket.
    pub fn wire(self) -> &'static str {
        match self {
            Self::Expired => "expired",
            Self::Dismissed => "dismissed",
            Self::Closed => "closed",
            Self::Evicted => "evicted",
            Self::Ended => "ended",
        }
    }

    /// The NotificationClosed code. Evicted entries use the undefined code.
    pub fn code(self) -> u32 {
        match self {
            Self::Expired => 1,
            Self::Dismissed => 2,
            Self::Closed => 3,
            Self::Evicted | Self::Ended => 4,
        }
    }
}

/// Bus side effects that the service turns into D-Bus signals.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Signal {
    Closed { id: u32, code: u32 },
    ActionInvoked { id: u32, key: String },
    ActivityAction { id: String, key: String },
}

/// A parsed Notify call, before the model assigns an id.
#[derive(Clone, Debug, Default)]
pub struct Incoming {
    pub app_name: String,
    pub app_icon: String,
    pub summary: String,
    pub body: String,
    pub actions: Vec<(String, String)>,
    pub urgency: Urgency,
    pub category: String,
    pub desktop_entry: String,
    pub image_path: String,
    pub image_size: Option<(i32, i32)>,
    pub image_bytes: usize,
    pub transient: bool,
    pub resident: bool,
    pub sync_tag: Option<String>,
    pub expire_timeout: i32,
    pub replaces_id: u32,
}

/// One notification. Its id and position stay fixed when it is replaced.
#[derive(Clone, Debug)]
pub struct Notification {
    pub id: u32,
    pub seq: u64,
    pub received_ms: u64,
    pub app_name: String,
    pub app_icon: String,
    pub summary: String,
    pub body: String,
    pub actions: Vec<(String, String)>,
    pub urgency: Urgency,
    pub category: String,
    pub desktop_entry: String,
    pub image_path: String,
    pub image_size: Option<(i32, i32)>,
    pub image_bytes: usize,
    pub transient: bool,
    pub resident: bool,
    pub sync_tag: Option<String>,
    /// None means the popup never expires.
    pub timeout_ms: Option<i64>,
    pub popup: bool,
    pub remaining_ms: Option<i64>,
    pub expiry_paused: bool,
}

impl Notification {
    fn from_incoming(id: u32, inc: Incoming, seq: u64, now_ms: u64) -> Self {
        let timeout_ms = expiry(inc.urgency, inc.expire_timeout);
        Self {
            id,
            seq,
            received_ms: now_ms,
            app_name: inc.app_name,
            app_icon: inc.app_icon,
            summary: inc.summary,
            body: inc.body,
            actions: inc.actions,
            urgency: inc.urgency,
            category: inc.category,
            desktop_entry: inc.desktop_entry,
            image_path: inc.image_path,
            image_size: inc.image_size,
            image_bytes: inc.image_bytes,
            transient: inc.transient,
            resident: inc.resident,
            sync_tag: inc.sync_tag,
            timeout_ms,
            popup: false,
            remaining_ms: timeout_ms,
            expiry_paused: false,
        }
    }

    /// The public fields that the shell sees.
    pub fn view(&self) -> Map<String, Value> {
        let actions: Vec<Value> = self.actions.iter().map(|(key, label)| json!({ "key": key, "label": label })).collect();
        let image_size = self.image_size.map(|(w, h)| json!([w, h]));
        let value = json!({
            "app_name": self.app_name,
            "app_icon": self.app_icon,
            "summary": self.summary,
            "body": self.body,
            "actions": actions,
            "urgency": self.urgency.name(),
            "category": self.category,
            "desktop_entry": self.desktop_entry,
            "image_path": self.image_path,
            "image_size": image_size,
            "image_bytes": self.image_bytes,
            "transient": self.transient,
            "resident": self.resident,
            "timeout_ms": self.timeout_ms,
            "popup": self.popup,
            "expiry_paused": self.expiry_paused,
            "received_ms": self.received_ms,
        });
        into_map(value)
    }
}

/// A live activity from dev.opal.Activities. Its data is kept as sent.
#[derive(Clone, Debug)]
struct Activity {
    id: String,
    owner: Option<String>,
    data: Map<String, Value>,
}

/// The whole service state. Each mutation queues wire messages and bus signals.
#[derive(Debug, Default)]
pub struct Model {
    notes: Vec<Notification>,
    next_id: u32,
    seq: u64,
    dnd: bool,
    activities: Vec<Activity>,
    next_activity: u64,
    messages: Vec<Message>,
    signals: Vec<Signal>,
}

impl Model {
    /// Create an empty model with DND off.
    pub fn new() -> Self {
        Self { next_id: 1, next_activity: 1, ..Self::default() }
    }

    /// Return the notification with this id, if it exists.
    #[cfg(test)]
    pub fn get(&self, id: u32) -> Option<&Notification> {
        self.notes.iter().find(|n| n.id == id)
    }

    /// Return the number of notifications in history.
    #[cfg(test)]
    pub fn history_len(&self) -> usize {
        self.notes.len()
    }

    /// Return the full state as one snapshot message.
    pub fn snapshot(&self) -> Message {
        Message::Snapshot {
            dnd: self.dnd,
            notifications: self.notes.iter().map(|n| Item { id: Id::Num(n.id), fields: n.view() }).collect(),
            activities: self.activities.iter().map(|a| Item { id: Id::Text(a.id.clone()), fields: a.data.clone() }).collect(),
        }
    }

    /// Take the queued wire messages.
    pub fn take_messages(&mut self) -> Vec<Message> {
        std::mem::take(&mut self.messages)
    }

    /// Take the queued bus signals.
    pub fn take_signals(&mut self) -> Vec<Signal> {
        std::mem::take(&mut self.signals)
    }

    /// Add a notification, or replace an existing one in place. Return its id.
    pub fn notify(&mut self, inc: Incoming, now_ms: u64) -> u32 {
        self.seq += 1;
        let seq = self.seq;
        let id = match self.find_replaced(&inc) {
            Some(index) => {
                let id = self.notes[index].id;
                let before = self.notes[index].view();
                let paused = self.notes[index].expiry_paused;
                let mut next = Notification::from_incoming(id, inc, seq, now_ms);
                next.expiry_paused = paused;
                next.popup = !self.dnd;
                self.notes[index] = next;
                if self.notes[index].transient && !self.notes[index].popup {
                    self.remove_at(index, Reason::Expired);
                } else {
                    self.push_change(index, &before);
                }
                id
            }
            None => {
                let id = self.allocate_id();
                let mut next = Notification::from_incoming(id, inc, seq, now_ms);
                next.popup = !self.dnd;
                let hidden_transient = next.transient && !next.popup;
                let fields = next.view();
                self.notes.push(next);
                self.messages.push(Message::Inserted { entity: Entity::Notification, id: Id::Num(id), fields });
                if hidden_transient {
                    self.remove_id(id, Reason::Expired);
                }
                id
            }
        };
        self.enforce_limits();
        id
    }

    /// Remove a notification with this id. Return false when it does not exist.
    pub fn close(&mut self, id: u32, reason: Reason) -> bool {
        match self.index_of(id) {
            Some(index) => {
                self.remove_at(index, reason);
                true
            }
            None => false,
        }
    }

    /// Invoke an action. A notification that is not resident is then dismissed.
    pub fn invoke(&mut self, id: u32, key: &str) -> Result<(), String> {
        let index = self.index_of(id).ok_or("no such notification")?;
        if !self.notes[index].actions.iter().any(|(known, _)| known == key) {
            return Err("no such action".into());
        }
        self.signals.push(Signal::ActionInvoked { id, key: key.to_string() });
        if !self.notes[index].resident {
            self.remove_at(index, Reason::Dismissed);
        }
        Ok(())
    }

    /// Pause or resume the popup countdown. The shell calls this on hover.
    pub fn set_expiry_paused(&mut self, id: u32, paused: bool) -> Result<(), String> {
        let index = self.index_of(id).ok_or("no such notification")?;
        if self.notes[index].expiry_paused == paused {
            return Ok(());
        }
        let before = self.notes[index].view();
        self.notes[index].expiry_paused = paused;
        self.push_change(index, &before);
        Ok(())
    }

    /// Turn DND on or off. Turning it on hides every popup but keeps the history.
    pub fn set_dnd(&mut self, on: bool) {
        if self.dnd == on {
            return;
        }
        self.dnd = on;
        self.messages.push(Message::State { dnd: on });
        if on {
            let ids: Vec<u32> = self.notes.iter().filter(|n| n.popup).map(|n| n.id).collect();
            for id in ids {
                self.hide_popup(id);
            }
        }
    }

    /// Dismiss every history entry that is not transient.
    pub fn clear_history(&mut self) {
        let ids: Vec<u32> = self.notes.iter().filter(|n| !n.transient).map(|n| n.id).collect();
        for id in ids {
            self.remove_id(id, Reason::Dismissed);
        }
    }

    /// Advance popup timers by this many milliseconds. Paused and critical popups do not move.
    pub fn tick(&mut self, elapsed_ms: i64) {
        let mut due = Vec::new();
        for note in self.notes.iter_mut() {
            if !note.popup || note.expiry_paused {
                continue;
            }
            if let Some(left) = note.remaining_ms.as_mut() {
                *left -= elapsed_ms;
                if *left <= 0 {
                    due.push(note.id);
                }
            }
        }
        for id in due {
            self.hide_popup(id);
        }
    }

    /// Start an activity. Use the `id` field when it is given. Return the id.
    pub fn activity_start(&mut self, mut data: Map<String, Value>, owner: Option<String>) -> Result<String, String> {
        if self.activities.len() >= MAX_ACTIVITIES {
            return Err("too many activities".into());
        }
        let id = match data.get("id") {
            Some(Value::String(text)) => {
                if text.is_empty() || text.chars().count() > MAX_ID_CHARS {
                    return Err("invalid activity id".into());
                }
                if self.activity_index(text).is_some() {
                    return Err("activity already exists".into());
                }
                text.clone()
            }
            Some(_) => return Err("activity id must be a string".into()),
            None => self.allocate_activity_id(),
        };
        data.insert("id".into(), Value::String(id.clone()));
        self.messages.push(Message::Inserted { entity: Entity::Activity, id: Id::Text(id.clone()), fields: data.clone() });
        self.activities.push(Activity { id: id.clone(), owner, data });
        Ok(id)
    }

    /// Merge top-level fields into an activity. A null value removes the field.
    pub fn activity_update(&mut self, id: &str, data: Map<String, Value>) -> Result<(), String> {
        let index = self.activity_index(id).ok_or("no such activity")?;
        let before = self.activities[index].data.clone();
        for (key, value) in data {
            if key == "id" {
                continue;
            }
            if value.is_null() {
                self.activities[index].data.remove(&key);
            } else {
                self.activities[index].data.insert(key, value);
            }
        }
        let fields = diff(&before, &self.activities[index].data);
        if !fields.is_empty() {
            self.messages.push(Message::Changed { entity: Entity::Activity, id: Id::Text(id.to_string()), fields });
        }
        Ok(())
    }

    /// End an activity. Return an error when it does not exist.
    pub fn activity_end(&mut self, id: &str) -> Result<(), String> {
        let index = self.activity_index(id).ok_or("no such activity")?;
        self.remove_activity(index, Reason::Ended);
        Ok(())
    }

    /// End every activity that this bus name started.
    pub fn end_owned_by(&mut self, owner: &str) {
        let ids: Vec<String> = self.activities.iter().filter(|a| a.owner.as_deref() == Some(owner)).map(|a| a.id.clone()).collect();
        for id in ids {
            let _ = self.activity_end(&id);
        }
    }

    /// Invoke a control on an activity. The control must exist in its controls list.
    pub fn activity_action(&mut self, id: &str, key: &str) -> Result<(), String> {
        let index = self.activity_index(id).ok_or("no such activity")?;
        let known = self.activities[index]
            .data
            .get("controls")
            .and_then(Value::as_array)
            .is_some_and(|controls| controls.iter().any(|c| c.get("id").and_then(Value::as_str) == Some(key)));
        if !known {
            return Err("no such control".into());
        }
        self.signals.push(Signal::ActivityAction { id: id.to_string(), key: key.to_string() });
        Ok(())
    }

    fn find_replaced(&self, inc: &Incoming) -> Option<usize> {
        if inc.replaces_id != 0 {
            if let Some(index) = self.index_of(inc.replaces_id) {
                return Some(index);
            }
        }
        let tag = inc.sync_tag.as_ref()?;
        self.notes.iter().position(|n| n.sync_tag.as_ref() == Some(tag) && n.app_name == inc.app_name)
    }

    fn index_of(&self, id: u32) -> Option<usize> {
        self.notes.iter().position(|n| n.id == id)
    }

    fn allocate_id(&mut self) -> u32 {
        loop {
            let id = self.next_id;
            self.next_id = if id == u32::MAX { 1 } else { id + 1 };
            if id != 0 && self.index_of(id).is_none() {
                return id;
            }
        }
    }

    fn activity_index(&self, id: &str) -> Option<usize> {
        self.activities.iter().position(|a| a.id == id)
    }

    fn allocate_activity_id(&mut self) -> String {
        loop {
            let id = format!("act-{}", self.next_activity);
            self.next_activity += 1;
            if self.activity_index(&id).is_none() {
                return id;
            }
        }
    }

    fn remove_activity(&mut self, index: usize, reason: Reason) {
        let activity = self.activities.remove(index);
        self.messages.push(Message::Removed { entity: Entity::Activity, id: Id::Text(activity.id), reason: reason.wire() });
    }

    fn push_change(&mut self, index: usize, before: &Map<String, Value>) {
        let id = self.notes[index].id;
        let fields = diff(before, &self.notes[index].view());
        if !fields.is_empty() {
            self.messages.push(Message::Changed { entity: Entity::Notification, id: Id::Num(id), fields });
        }
    }

    /// Hide a popup. A transient popup then leaves the model.
    fn hide_popup(&mut self, id: u32) {
        let Some(index) = self.index_of(id) else { return };
        if !self.notes[index].popup {
            return;
        }
        if self.notes[index].transient {
            self.remove_at(index, Reason::Expired);
            return;
        }
        let before = self.notes[index].view();
        self.notes[index].popup = false;
        self.push_change(index, &before);
    }

    /// Bound the popup queue and the history. Remove the oldest entries first.
    fn enforce_limits(&mut self) {
        let mut popups: Vec<(u64, u32)> = self.notes.iter().filter(|n| n.popup).map(|n| (n.seq, n.id)).collect();
        popups.sort_unstable();
        let excess = popups.len().saturating_sub(POPUP_QUEUE);
        for (_, id) in popups.into_iter().take(excess) {
            self.hide_popup(id);
        }
        let mut history: Vec<(u64, u32)> = self.notes.iter().filter(|n| !n.transient).map(|n| (n.seq, n.id)).collect();
        history.sort_unstable();
        let excess = history.len().saturating_sub(HISTORY_LIMIT);
        for (_, id) in history.into_iter().take(excess) {
            self.remove_id(id, Reason::Evicted);
        }
    }

    fn remove_id(&mut self, id: u32, reason: Reason) {
        if let Some(index) = self.index_of(id) {
            self.remove_at(index, reason);
        }
    }

    fn remove_at(&mut self, index: usize, reason: Reason) {
        let note = self.notes.remove(index);
        self.messages.push(Message::Removed { entity: Entity::Notification, id: Id::Num(note.id), reason: reason.wire() });
        self.signals.push(Signal::Closed { id: note.id, code: reason.code() });
    }
}

/// Return the popup time for one notification. None means it never expires.
fn expiry(urgency: Urgency, expire_timeout: i32) -> Option<i64> {
    if urgency == Urgency::Critical || expire_timeout == 0 {
        return None;
    }
    if expire_timeout < 0 {
        return Some(DEFAULT_EXPIRE_MS);
    }
    Some(i64::from(expire_timeout).max(MIN_EXPIRE_MS))
}

/// Return the fields that differ. A removed key maps to null.
pub fn diff(old: &Map<String, Value>, new: &Map<String, Value>) -> Map<String, Value> {
    let mut out = Map::new();
    for (key, value) in new {
        if old.get(key) != Some(value) {
            out.insert(key.clone(), value.clone());
        }
    }
    for key in old.keys() {
        if !new.contains_key(key) {
            out.insert(key.clone(), Value::Null);
        }
    }
    out
}

fn into_map(value: Value) -> Map<String, Value> {
    match value {
        Value::Object(map) => map,
        _ => Map::new(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn note(summary: &str) -> Incoming {
        Incoming { app_name: "app".into(), summary: summary.into(), expire_timeout: -1, ..Incoming::default() }
    }

    fn popup_ids(model: &Model) -> Vec<u32> {
        let mut ids: Vec<u32> = model.notes.iter().filter(|n| n.popup).map(|n| n.id).collect();
        ids.sort_unstable();
        ids
    }

    #[test]
    fn ids_start_at_one_and_never_repeat() {
        let mut model = Model::new();
        assert_eq!(model.notify(note("a"), 0), 1);
        assert_eq!(model.notify(note("b"), 0), 2);
    }

    #[test]
    fn popup_queue_hides_the_oldest() {
        let mut model = Model::new();
        for index in 0..10 {
            model.notify(note(&format!("n{index}")), 0);
        }
        assert_eq!(popup_ids(&model), (3..=10).collect::<Vec<u32>>());
        assert_eq!(model.history_len(), 10);
        let hidden: Vec<u32> = model
            .take_messages()
            .into_iter()
            .filter_map(|m| match m {
                Message::Changed { id: Id::Num(id), fields, .. } if fields.get("popup") == Some(&Value::Bool(false)) => Some(id),
                _ => None,
            })
            .collect();
        assert_eq!(hidden, vec![1, 2]);
    }

    #[test]
    fn history_is_bounded_and_evicts_with_code_four() {
        let mut model = Model::new();
        model.set_dnd(true);
        for index in 0..=HISTORY_LIMIT {
            model.notify(note(&format!("n{index}")), 0);
        }
        assert_eq!(model.history_len(), HISTORY_LIMIT);
        assert!(model.get(1).is_none());
        let signals = model.take_signals();
        assert!(signals.contains(&Signal::Closed { id: 1, code: 4 }));
    }

    #[test]
    fn replacement_keeps_id_and_position() {
        let mut model = Model::new();
        let first = model.notify(note("first"), 0);
        model.notify(note("second"), 0);
        model.take_messages();
        let mut again = note("changed");
        again.replaces_id = first;
        assert_eq!(model.notify(again, 5), first);
        assert_eq!(model.notes[0].id, first);
        assert_eq!(model.notes[0].summary, "changed");
        let messages = model.take_messages();
        assert_eq!(messages.len(), 1);
        match &messages[0] {
            Message::Changed { fields, .. } => {
                assert!(fields.contains_key("summary"));
                assert!(!fields.contains_key("app_name"));
            }
            other => panic!("expected a change, got {other:?}"),
        }
    }

    #[test]
    fn unknown_replaces_id_creates_a_new_entry() {
        let mut model = Model::new();
        let mut inc = note("x");
        inc.replaces_id = 99;
        assert_ne!(model.notify(inc, 0), 99);
    }

    #[test]
    fn sync_tag_replaces_from_the_same_app() {
        let mut model = Model::new();
        let mut first = note("one");
        first.sync_tag = Some("tag".into());
        let id = model.notify(first.clone(), 0);
        let mut second = note("two");
        second.sync_tag = Some("tag".into());
        assert_eq!(model.notify(second, 1), id);
        assert_eq!(model.history_len(), 1);
    }

    #[test]
    fn expiry_pause_freezes_the_countdown() {
        let mut model = Model::new();
        let mut inc = note("timed");
        inc.expire_timeout = 2000;
        let id = model.notify(inc, 0);
        model.set_expiry_paused(id, true).unwrap();
        model.tick(5000);
        assert!(model.get(id).unwrap().popup);
        model.set_expiry_paused(id, false).unwrap();
        model.tick(1500);
        assert!(model.get(id).unwrap().popup);
        model.tick(600);
        assert!(!model.get(id).unwrap().popup);
        assert_eq!(model.history_len(), 1);
    }

    #[test]
    fn critical_and_zero_timeout_never_expire() {
        let mut model = Model::new();
        let mut critical = note("critical");
        critical.urgency = Urgency::Critical;
        critical.expire_timeout = 1000;
        let sticky = model.notify(critical, 0);
        let mut zero = note("zero");
        zero.expire_timeout = 0;
        let never = model.notify(zero, 0);
        model.tick(1_000_000);
        assert!(model.get(sticky).unwrap().popup);
        assert!(model.get(never).unwrap().popup);
        assert_eq!(model.get(sticky).unwrap().timeout_ms, None);
    }

    #[test]
    fn default_and_minimum_timeouts() {
        let mut model = Model::new();
        let default_id = model.notify(note("default"), 0);
        let mut short = note("short");
        short.expire_timeout = 200;
        let short_id = model.notify(short, 0);
        assert_eq!(model.get(default_id).unwrap().timeout_ms, Some(DEFAULT_EXPIRE_MS));
        assert_eq!(model.get(short_id).unwrap().timeout_ms, Some(MIN_EXPIRE_MS));
    }

    #[test]
    fn dnd_keeps_history_and_suppresses_popups() {
        let mut model = Model::new();
        model.set_dnd(true);
        let id = model.notify(note("quiet"), 0);
        assert!(!model.get(id).unwrap().popup);
        assert_eq!(model.history_len(), 1);
        model.set_dnd(false);
        assert!(!model.get(id).unwrap().popup);
    }

    #[test]
    fn dnd_on_hides_existing_popups() {
        let mut model = Model::new();
        let id = model.notify(note("loud"), 0);
        model.set_dnd(true);
        assert!(!model.get(id).unwrap().popup);
        assert_eq!(model.history_len(), 1);
    }

    #[test]
    fn transient_notification_leaves_when_not_shown() {
        let mut model = Model::new();
        model.set_dnd(true);
        let mut inc = note("transient");
        inc.transient = true;
        model.notify(inc, 0);
        assert_eq!(model.history_len(), 0);
        assert!(model.take_signals().contains(&Signal::Closed { id: 1, code: 1 }));
    }

    #[test]
    fn transient_popup_leaves_when_its_timer_ends() {
        let mut model = Model::new();
        let mut inc = note("transient");
        inc.transient = true;
        inc.expire_timeout = 1000;
        model.notify(inc, 0);
        model.tick(1000);
        assert_eq!(model.history_len(), 0);
    }

    #[test]
    fn dismiss_and_close_use_their_reasons() {
        let mut model = Model::new();
        let a = model.notify(note("a"), 0);
        let b = model.notify(note("b"), 0);
        assert!(model.close(a, Reason::Dismissed));
        assert!(model.close(b, Reason::Closed));
        assert!(!model.close(b, Reason::Closed));
        assert_eq!(model.take_signals(), vec![Signal::Closed { id: a, code: 2 }, Signal::Closed { id: b, code: 3 }]);
    }

    #[test]
    fn invoke_checks_the_action_and_dismisses_unless_resident() {
        let mut model = Model::new();
        let mut inc = note("act");
        inc.actions = vec![("default".into(), "Open".into())];
        let id = model.notify(inc, 0);
        assert!(model.invoke(id, "missing").is_err());
        model.invoke(id, "default").unwrap();
        assert!(model.get(id).is_none());
        assert_eq!(
            model.take_signals(),
            vec![Signal::ActionInvoked { id, key: "default".into() }, Signal::Closed { id, code: 2 }]
        );

        let mut resident = note("keep");
        resident.actions = vec![("open".into(), "Open".into())];
        resident.resident = true;
        let kept = model.notify(resident, 0);
        model.invoke(kept, "open").unwrap();
        assert!(model.get(kept).is_some());
    }

    #[test]
    fn clear_history_dismisses_everything() {
        let mut model = Model::new();
        model.notify(note("a"), 0);
        model.notify(note("b"), 0);
        model.clear_history();
        assert_eq!(model.history_len(), 0);
    }

    #[test]
    fn activity_lifecycle() {
        let mut model = Model::new();
        let mut data = Map::new();
        data.insert("title".into(), json!("build"));
        let id = model.activity_start(data, Some(":1.5".into())).unwrap();
        assert_eq!(id, "act-1");
        model.take_messages();

        let mut update = Map::new();
        update.insert("progress".into(), json!(0.5));
        update.insert("title".into(), Value::Null);
        model.activity_update(&id, update).unwrap();
        let messages = model.take_messages();
        match &messages[0] {
            Message::Changed { fields, .. } => {
                assert_eq!(fields.get("progress"), Some(&json!(0.5)));
                assert_eq!(fields.get("title"), Some(&Value::Null));
            }
            other => panic!("expected a change, got {other:?}"),
        }

        model.activity_end(&id).unwrap();
        assert!(model.activity_end(&id).is_err());
        assert!(matches!(model.take_messages()[0], Message::Removed { reason: "ended", .. }));
    }

    #[test]
    fn activity_id_and_bounds() {
        let mut model = Model::new();
        let mut named = Map::new();
        named.insert("id".into(), json!("cc-1"));
        assert_eq!(model.activity_start(named.clone(), None).unwrap(), "cc-1");
        assert!(model.activity_start(named, None).is_err());
        let mut numeric = Map::new();
        numeric.insert("id".into(), json!(3));
        assert!(model.activity_start(numeric, None).is_err());
        for _ in 1..MAX_ACTIVITIES {
            model.activity_start(Map::new(), None).unwrap();
        }
        assert!(model.activity_start(Map::new(), None).is_err());
    }

    #[test]
    fn owner_vanish_ends_its_activities() {
        let mut model = Model::new();
        let mine = model.activity_start(Map::new(), Some(":1.9".into())).unwrap();
        let other = model.activity_start(Map::new(), Some(":1.10".into())).unwrap();
        model.end_owned_by(":1.9");
        assert!(model.activity_end(&mine).is_err());
        assert!(model.activity_end(&other).is_ok());
    }

    #[test]
    fn activity_action_needs_a_known_control() {
        let mut model = Model::new();
        let mut data = Map::new();
        data.insert("controls".into(), json!([{ "id": "stop", "label": "Stop" }]));
        let id = model.activity_start(data, None).unwrap();
        assert!(model.activity_action(&id, "pause").is_err());
        model.activity_action(&id, "stop").unwrap();
        assert_eq!(model.take_signals(), vec![Signal::ActivityAction { id, key: "stop".into() }]);
    }

    #[test]
    fn diff_reports_only_changes() {
        let old = json!({"a": 1, "b": 2, "c": 3}).as_object().cloned().unwrap();
        let new = json!({"a": 1, "b": 5, "d": 4}).as_object().cloned().unwrap();
        let changed = diff(&old, &new);
        assert_eq!(changed, json!({"b": 5, "c": null, "d": 4}).as_object().cloned().unwrap());
    }
}
