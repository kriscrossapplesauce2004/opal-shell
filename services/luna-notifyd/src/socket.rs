//! Unix socket for shell clients. Each direction carries one JSON object per line.

use std::fs;
use std::io::{BufRead, BufReader, Read, Write};
use std::os::unix::fs::PermissionsExt;
use std::os::unix::net::{UnixListener, UnixStream};
use std::path::{Path, PathBuf};
use std::sync::mpsc::{sync_channel, Sender};
use std::thread;

use crate::protocol::{parse_request, MAX_LINE};
use crate::service::{Command, CLIENT_QUEUE};

/// Return $XDG_RUNTIME_DIR/luna/notifyd.sock.
pub fn socket_path() -> Result<PathBuf, String> {
    let runtime = std::env::var_os("XDG_RUNTIME_DIR").ok_or("XDG_RUNTIME_DIR is not set")?;
    Ok(PathBuf::from(runtime).join("luna").join("notifyd.sock"))
}

/// Bind the socket. Refuse to start when another instance answers.
pub fn bind(path: &Path) -> Result<UnixListener, String> {
    let dir = path.parent().ok_or("socket path has no parent")?;
    fs::create_dir_all(dir).map_err(|error| format!("create {}: {error}", dir.display()))?;
    fs::set_permissions(dir, fs::Permissions::from_mode(0o700)).map_err(|error| format!("chmod {}: {error}", dir.display()))?;
    if UnixStream::connect(path).is_ok() {
        return Err(format!("another instance is running on {}", path.display()));
    }
    // A socket with no listener is stale. Remove it before binding.
    let _ = fs::remove_file(path);
    UnixListener::bind(path).map_err(|error| format!("bind {}: {error}", path.display()))
}

/// Accept clients forever. Each client gets a reader thread and a writer thread.
pub fn serve(listener: UnixListener, tx: Sender<Command>) {
    let mut next: u64 = 1;
    for stream in listener.incoming() {
        let Ok(stream) = stream else { continue };
        let id = next;
        next += 1;
        let tx = tx.clone();
        thread::spawn(move || client(id, stream, tx));
    }
}

fn client(id: u64, stream: UnixStream, tx: Sender<Command>) {
    let (Ok(writer_stream), Ok(keeper)) = (stream.try_clone(), stream.try_clone()) else { return };
    let (out, lines) = sync_channel::<String>(CLIENT_QUEUE);
    thread::spawn(move || {
        let mut writer = writer_stream;
        for line in lines {
            if writeln!(writer, "{line}").and_then(|_| writer.flush()).is_err() {
                break;
            }
        }
    });
    if tx.send(Command::ClientConnected { id, out, stream: keeper }).is_err() {
        return;
    }
    let mut reader = BufReader::new(stream);
    loop {
        let mut buf = Vec::new();
        match (&mut reader).take(MAX_LINE as u64 + 1).read_until(b'\n', &mut buf) {
            Ok(0) | Err(_) => break,
            Ok(_) => {}
        }
        if buf.last() != Some(&b'\n') {
            // A line that is too long, or an incomplete line at end of file.
            let _ = tx.send(Command::ClientLine { id, request: Err("line is too long or incomplete".into()) });
            break;
        }
        let text = String::from_utf8_lossy(&buf);
        let line = text.trim_end_matches(['\r', '\n']);
        if line.trim().is_empty() {
            continue;
        }
        if tx.send(Command::ClientLine { id, request: parse_request(line) }).is_err() {
            break;
        }
    }
    let _ = tx.send(Command::ClientGone { id });
}
