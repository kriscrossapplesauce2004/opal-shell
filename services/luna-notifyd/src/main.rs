//! luna-notifyd: freedesktop notifications and live activities for the Opal shell.

mod dbus;
mod model;
mod protocol;
mod service;
mod socket;

use std::sync::mpsc;
use std::thread;

fn main() {
    let mut replace = false;
    for argument in std::env::args().skip(1) {
        match argument.as_str() {
            "--replace" => replace = true,
            "--help" | "-h" => {
                print_usage();
                return;
            }
            other => {
                eprintln!("luna-notifyd: unknown argument {other}");
                std::process::exit(2);
            }
        }
    }
    if let Err(message) = run(replace) {
        eprintln!("luna-notifyd: {message}");
        std::process::exit(1);
    }
}

fn print_usage() {
    println!("usage: luna-notifyd [--replace]");
    println!("  Serve org.freedesktop.Notifications and dev.opal.Activities on the session bus,");
    println!("  and the shell socket at $XDG_RUNTIME_DIR/luna/notifyd.sock.");
    println!("  Without --replace the service refuses to start when a name is already owned.");
    println!("  --replace takes the names from their owner. Use it only on a private test bus.");
}

fn run(replace: bool) -> Result<(), String> {
    let path = socket::socket_path()?;
    let (tx, rx) = mpsc::channel();
    let conn = async_io::block_on(dbus::connect(tx.clone(), replace))?;
    let watcher = conn.clone();
    let owner_tx = tx.clone();
    thread::spawn(move || {
        if let Err(error) = async_io::block_on(dbus::watch_owners(watcher, owner_tx)) {
            eprintln!("luna-notifyd: owner watch stopped: {error}");
        }
    });
    let listener = socket::bind(&path)?;
    eprintln!("luna-notifyd: serving on {}", path.display());
    thread::spawn(move || socket::serve(listener, tx));
    service::run(conn, rx);
    Ok(())
}
