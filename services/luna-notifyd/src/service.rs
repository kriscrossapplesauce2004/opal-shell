//! Core loop: owns the model, applies commands, then broadcasts events and emits bus signals.

use std::collections::HashMap;
use std::net::Shutdown;
use std::os::unix::net::UnixStream;
use std::sync::mpsc::{Receiver, RecvTimeoutError, SyncSender};
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

use futures_channel::oneshot;
use serde_json::{Map, Value};
use zbus::Connection;

use crate::dbus;
use crate::model::{Incoming, Model, Reason, Signal};
use crate::protocol::{encode, Message, Request, PROTOCOL_VERSION};

/// How often popup timers advance when no command arrives.
pub const TICK: Duration = Duration::from_millis(100);
/// Lines queued for one client before the client is dropped.
pub const CLIENT_QUEUE: usize = 1024;

/// Work for the core loop. Replies go back through one-shot channels.
pub enum Command {
    Notify { note: Incoming, reply: oneshot::Sender<Result<u32, String>> },
    Close { id: u32, reply: oneshot::Sender<Result<(), String>> },
    ActivityStart { data: Map<String, Value>, owner: Option<String>, reply: oneshot::Sender<Result<String, String>> },
    ActivityUpdate { id: String, data: Map<String, Value>, reply: oneshot::Sender<Result<(), String>> },
    ActivityEnd { id: String, reply: oneshot::Sender<Result<(), String>> },
    BusNameGone { name: String },
    ClientConnected { id: u64, out: SyncSender<String>, stream: UnixStream },
    ClientLine { id: u64, request: Result<Request, String> },
    ClientGone { id: u64 },
}

struct Client {
    out: SyncSender<String>,
    stream: UnixStream,
}

struct Service {
    model: Model,
    clients: HashMap<u64, Client>,
    conn: Connection,
}

/// Run the core loop until every sender is gone.
pub fn run(conn: Connection, rx: Receiver<Command>) {
    let mut service = Service { model: Model::new(), clients: HashMap::new(), conn };
    let mut last = Instant::now();
    loop {
        match rx.recv_timeout(TICK) {
            Ok(command) => service.handle(command),
            Err(RecvTimeoutError::Timeout) => {}
            Err(RecvTimeoutError::Disconnected) => break,
        }
        let now = Instant::now();
        let elapsed = i64::try_from(now.duration_since(last).as_millis()).unwrap_or(i64::MAX);
        last = now;
        service.model.tick(elapsed);
        service.flush();
    }
}

impl Service {
    fn handle(&mut self, command: Command) {
        match command {
            Command::Notify { note, reply } => {
                let id = self.model.notify(note, now_ms());
                let _ = reply.send(Ok(id));
            }
            Command::Close { id, reply } => {
                self.model.close(id, Reason::Closed);
                let _ = reply.send(Ok(()));
            }
            Command::ActivityStart { data, owner, reply } => {
                let _ = reply.send(self.model.activity_start(data, owner));
            }
            Command::ActivityUpdate { id, data, reply } => {
                let _ = reply.send(self.model.activity_update(&id, data));
            }
            Command::ActivityEnd { id, reply } => {
                let _ = reply.send(self.model.activity_end(&id));
            }
            Command::BusNameGone { name } => self.model.end_owned_by(&name),
            Command::ClientConnected { id, out, stream } => self.connect(id, out, stream),
            Command::ClientLine { id, request } => self.request(id, request),
            Command::ClientGone { id } => self.drop_client(id),
        }
        self.flush();
    }

    /// Send hello and the snapshot to a new client. Flush first so that the snapshot is current.
    fn connect(&mut self, id: u64, out: SyncSender<String>, stream: UnixStream) {
        self.flush();
        let _ = out.try_send(encode(&Message::Hello { version: PROTOCOL_VERSION, server: "luna-notifyd" }));
        let _ = out.try_send(encode(&self.model.snapshot()));
        self.clients.insert(id, Client { out, stream });
    }

    fn request(&mut self, client: u64, request: Result<Request, String>) {
        let outcome: Result<(), String> = match request {
            Err(message) => Err(message),
            Ok(Request::Dismiss { id }) => {
                if self.model.close(id, Reason::Dismissed) {
                    Ok(())
                } else {
                    Err("no such notification".into())
                }
            }
            Ok(Request::Invoke { id, action }) => self.model.invoke(id, &action),
            Ok(Request::PauseExpiry { id }) => self.model.set_expiry_paused(id, true),
            Ok(Request::ResumeExpiry { id }) => self.model.set_expiry_paused(id, false),
            Ok(Request::SetDnd { on }) => {
                self.model.set_dnd(on);
                Ok(())
            }
            Ok(Request::ClearHistory) => {
                self.model.clear_history();
                Ok(())
            }
            Ok(Request::InvokeActivity { id, action }) => self.model.activity_action(&id, &action),
        };
        if let Err(message) = outcome {
            self.send_to(client, Message::Error { message });
        }
        self.flush();
    }

    /// Send every queued message to all clients and emit every queued bus signal.
    fn flush(&mut self) {
        for message in self.model.take_messages() {
            let line = encode(&message);
            self.broadcast(&line);
        }
        for signal in self.model.take_signals() {
            self.emit(signal);
        }
    }

    fn broadcast(&mut self, line: &str) {
        let dead: Vec<u64> = self
            .clients
            .iter()
            .filter(|(_, client)| client.out.try_send(line.to_string()).is_err())
            .map(|(id, _)| *id)
            .collect();
        for id in dead {
            self.drop_client(id);
        }
    }

    fn send_to(&mut self, id: u64, message: Message) {
        let line = encode(&message);
        let failed = self.clients.get(&id).is_some_and(|client| client.out.try_send(line).is_err());
        if failed {
            self.drop_client(id);
        }
    }

    fn drop_client(&mut self, id: u64) {
        if let Some(client) = self.clients.remove(&id) {
            let _ = client.stream.shutdown(Shutdown::Both);
        }
    }

    fn emit(&self, signal: Signal) {
        let result = match signal {
            Signal::Closed { id, code } => async_io::block_on(dbus::emit_closed(&self.conn, id, code)),
            Signal::ActionInvoked { id, key } => async_io::block_on(dbus::emit_action(&self.conn, id, &key)),
            Signal::ActivityAction { id, key } => async_io::block_on(dbus::emit_activity_action(&self.conn, &id, &key)),
        };
        if let Err(error) = result {
            eprintln!("luna-notifyd: signal failed: {error}");
        }
    }
}

fn now_ms() -> u64 {
    SystemTime::now().duration_since(UNIX_EPOCH).ok().and_then(|d| u64::try_from(d.as_millis()).ok()).unwrap_or(0)
}
