//! Output hub: a Unix socket for shell clients, or stdout for tests.

use std::fs::{self, Permissions};
use std::io::{self, Write};
use std::os::unix::fs::PermissionsExt;
use std::os::unix::net::{UnixListener, UnixStream};
use std::path::PathBuf;
use std::time::Duration;

use crate::protocol::{encode_line, Message, Status, PROTOCOL_VERSION};

const WRITE_TIMEOUT: Duration = Duration::from_millis(500);

/// Socket path: $XDG_RUNTIME_DIR/luna/statusd.sock.
pub fn socket_path() -> Result<PathBuf, String> {
    let runtime = std::env::var_os("XDG_RUNTIME_DIR")
        .ok_or("XDG_RUNTIME_DIR is not set; use --stdout to test")?;
    Ok(PathBuf::from(runtime).join("luna").join("statusd.sock"))
}

pub struct Hub {
    listener: Option<UnixListener>,
    clients: Vec<Box<dyn Write>>,
}

impl Hub {
    /// Create a hub with no socket. Add clients with `add_client`.
    pub fn new(listener: Option<UnixListener>) -> Self {
        Hub {
            listener,
            clients: Vec::new(),
        }
    }

    /// Bind the socket. Refuse to start when another instance answers.
    pub fn bind_socket() -> Result<Self, String> {
        let path = socket_path()?;
        let dir = path.parent().ok_or("socket path has no parent")?;
        fs::create_dir_all(dir).map_err(|e| format!("create {}: {e}", dir.display()))?;
        fs::set_permissions(dir, Permissions::from_mode(0o700))
            .map_err(|e| format!("chmod {}: {e}", dir.display()))?;
        if UnixStream::connect(&path).is_ok() {
            return Err(format!("another instance is running on {}", path.display()));
        }
        // A socket with no listener is stale. Remove it before binding.
        let _ = fs::remove_file(&path);
        let listener =
            UnixListener::bind(&path).map_err(|e| format!("bind {}: {e}", path.display()))?;
        listener
            .set_nonblocking(true)
            .map_err(|e| format!("nonblocking: {e}"))?;
        eprintln!("luna-statusd: listening on {}", path.display());
        Ok(Hub::new(Some(listener)))
    }

    /// Send hello and the snapshot to a new client, then keep it. Return false when the client fails.
    pub fn add_client(&mut self, mut writer: Box<dyn Write>, status: &Status) -> bool {
        let hello = Message::Hello {
            version: PROTOCOL_VERSION,
        };
        let snapshot = Message::Snapshot {
            state: status.clone(),
        };
        let ok = write_message(writer.as_mut(), &hello).is_ok()
            && write_message(writer.as_mut(), &snapshot).is_ok();
        if ok {
            self.clients.push(writer);
        }
        ok
    }

    /// Accept waiting socket clients and send each one the current snapshot.
    pub fn accept_pending(&mut self, status: &Status) {
        let Some(listener) = self.listener.as_ref() else {
            return;
        };
        let mut fresh = Vec::new();
        while let Ok((stream, _)) = listener.accept() {
            fresh.push(stream);
        }
        for stream in fresh {
            // Accepted streams may inherit non-blocking mode. Clear it and bound writes.
            let _ = stream.set_nonblocking(false);
            let _ = stream.set_write_timeout(Some(WRITE_TIMEOUT));
            self.add_client(Box::new(stream), status);
        }
    }

    /// Send one message to every client. Drop the clients that fail.
    pub fn broadcast(&mut self, message: &Message) {
        let line = encode_line(message);
        self.clients.retain_mut(|client| {
            client
                .write_all(line.as_bytes())
                .and_then(|_| client.flush())
                .is_ok()
        });
    }

    pub fn has_clients(&self) -> bool {
        !self.clients.is_empty()
    }
}

fn write_message(writer: &mut dyn Write, message: &Message) -> io::Result<()> {
    writer.write_all(encode_line(message).as_bytes())?;
    writer.flush()
}
