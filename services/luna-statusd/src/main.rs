//! luna-statusd: typed, incremental system status for the lunaOS shell.

mod protocol;
mod server;
mod sources;

use std::io;
use std::process::exit;
use std::thread;
use std::time::{Duration, Instant};

use protocol::{diff, Message, Status};
use server::Hub;

const TICK: Duration = Duration::from_millis(100);
const BATTERY_EVERY: Duration = Duration::from_secs(10);
const FAST_EVERY: Duration = Duration::from_secs(2);

/// Fixed-rate timer. The first call is always due.
struct Timer {
    every: Duration,
    last: Option<Instant>,
}

impl Timer {
    fn new(every: Duration) -> Self {
        Timer { every, last: None }
    }

    fn due(&mut self, now: Instant) -> bool {
        match self.last {
            Some(last) if now.duration_since(last) < self.every => false,
            _ => {
                self.last = Some(now);
                true
            }
        }
    }
}

/// One timer per source. Polling moves to event sources later.
struct Schedule {
    power: Timer,
    profile: Timer,
    network: Timer,
    audio: Timer,
}

impl Schedule {
    fn new() -> Self {
        Schedule {
            power: Timer::new(BATTERY_EVERY),
            profile: Timer::new(FAST_EVERY),
            network: Timer::new(FAST_EVERY),
            audio: Timer::new(FAST_EVERY),
        }
    }
}

/// Read each source that is due. Sources that are not due keep their values.
fn poll_due(status: &mut Status, schedule: &mut Schedule, now: Instant) {
    if schedule.power.due(now) {
        let (battery, ac_online) = sources::read_power_supplies();
        status.battery = battery;
        status.power.ac_online = ac_online;
    }
    if schedule.profile.due(now) {
        status.power.profile = sources::read_power_profile();
    }
    if schedule.network.due(now) {
        status.network = sources::read_network();
    }
    if schedule.audio.due(now) {
        status.audio = sources::read_audio();
    }
}

fn usage() -> ! {
    eprintln!("usage: luna-statusd [--stdout]");
    eprintln!("  default: serve on $XDG_RUNTIME_DIR/luna/statusd.sock");
    eprintln!("  --stdout: write the protocol to stdout for testing");
    exit(2);
}

fn main() {
    let mut stdout_mode = false;
    for arg in std::env::args().skip(1) {
        match arg.as_str() {
            "--stdout" => stdout_mode = true,
            "-h" | "--help" => usage(),
            other => {
                eprintln!("luna-statusd: unknown argument {other}");
                usage();
            }
        }
    }

    let mut hub = if stdout_mode {
        Hub::new(None)
    } else {
        match Hub::bind_socket() {
            Ok(hub) => hub,
            Err(message) => {
                eprintln!("luna-statusd: {message}");
                exit(1);
            }
        }
    };

    let mut status = Status::default();
    let mut schedule = Schedule::new();
    // Read every source once, so the first snapshot is complete.
    poll_due(&mut status, &mut schedule, Instant::now());
    if stdout_mode && !hub.add_client(Box::new(io::stdout()), &status) {
        exit(0);
    }

    loop {
        let before = status.clone();
        poll_due(&mut status, &mut schedule, Instant::now());
        let changes = diff(&before, &status);
        if !changes.is_empty() {
            hub.broadcast(&Message::Delta { changes });
        }
        hub.accept_pending(&status);
        if stdout_mode && !hub.has_clients() {
            // The stdout reader went away.
            exit(0);
        }
        thread::sleep(TICK);
    }
}
