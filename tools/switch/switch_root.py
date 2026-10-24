#!/usr/bin/env python3
"""Root half of the Opal switch assistant: pkexec runs it once. It installs packages and adds or removes the Opal login session, reporting JSON lines."""
import json, os, pathlib, re, signal, subprocess, sys, threading

STAGES = ('packages', 'session', 'remove-session')
INSTALL = {
    'pacman': ['pacman', '-S', '--needed', '--noconfirm'],
    'dnf': ['dnf', 'install', '-y'],
    'zypper': ['zypper', '--non-interactive', 'install'],
    'apt': ['apt-get', 'install', '-y'],
}
QUERY = {'pacman': ['pacman', '-Si'], 'dnf': ['dnf', '-q', 'info'], 'zypper': ['zypper', '--non-interactive', 'info'], 'apt': ['apt-cache', 'show']}
CORE = ('hyprland', 'quickshell')
COPR = 'errornointernet/quickshell'
SESSION_FILE = pathlib.Path('/usr/share/wayland-sessions/opal.desktop')
LAUNCHER = pathlib.Path('/usr/local/bin/opal-session')
SESSION_TEXT = '''[Desktop Entry]
Name=Opal
Comment=Opal, a Material 3 Expressive shell on Hyprland
Exec=/usr/local/bin/opal-session
Type=Application
DesktopNames=Hyprland;Opal
Keywords=opal;hyprland;wayland;
'''
LAUNCHER_TEXT = '''#!/bin/sh
# Opal login session: Hyprland with Opal as its shell. "opal login" starts Opal when OPAL_SESSION is set.
export OPAL_SESSION=1
export XDG_CURRENT_DESKTOP=Hyprland:Opal
export XDG_SESSION_DESKTOP=opal
if command -v start-hyprland >/dev/null 2>&1; then
    exec start-hyprland "$@"
fi
exec Hyprland "$@"
'''
PACKAGE_RE = re.compile(r'^[A-Za-z0-9][A-Za-z0-9.+_-]{0,80}$')

cancelled = threading.Event()
current = {'proc': None}


def say(**fields):
    sys.stdout.write(json.dumps(fields) + '\n')
    sys.stdout.flush()


def watch_stdin():
    for line in sys.stdin:
        if line.strip() == 'cancel':
            break
    cancelled.set()
    proc = current['proc']
    if proc and proc.poll() is None:
        try:
            os.killpg(proc.pid, signal.SIGTERM)
        except (OSError, ProcessLookupError):
            pass


def stream(stage, args, on_line=None):
    try:
        proc = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL, start_new_session=True,
                                env=dict(os.environ, LC_ALL='C', DEBIAN_FRONTEND='noninteractive'))
    except OSError as error:
        say(stage=stage, log=f'{args[0]}: {error}')
        return 127
    current['proc'] = proc
    buf = b''
    while True:
        chunk = proc.stdout.read1(4096) if hasattr(proc.stdout, 'read1') else proc.stdout.read(4096)
        if not chunk:
            break
        buf += chunk
        parts = re.split(rb'[\r\n]', buf)
        buf = parts.pop()
        for raw in parts:
            line = raw.decode('utf-8', 'replace').strip()
            if line:
                if on_line:
                    on_line(line)
                say(stage=stage, log=line[:400])
    code = proc.wait()
    current['proc'] = None
    return code


def available(manager, name):
    try:
        res = subprocess.run(QUERY[manager] + [name], capture_output=True, text=True, timeout=30, env=dict(os.environ, LC_ALL='C'))
    except (OSError, subprocess.SubprocessError):
        return False
    out = (res.stdout or '').lower()
    return res.returncode == 0 and bool(out.strip()) and 'not found' not in out


def run_packages(opts):
    manager, packages = opts['pm'], opts['packages']
    if not packages:
        say(stage='packages', log='Nothing to install')
        return 0
    if manager not in INSTALL:
        say(stage='packages', log='No supported package manager')
        return 2
    if manager == 'apt':
        stream('packages', ['apt-get', 'update'])
    if manager == 'dnf' and 'quickshell' in packages and not available('dnf', 'quickshell'):
        say(stage='packages', detail='Turning on the Quickshell COPR', progress=-1)
        stream('packages', ['dnf', 'install', '-y', 'dnf-plugins-core'])
        if stream('packages', ['dnf', 'copr', 'enable', '-y', COPR]):
            return 3
    # Helpers the repositories lack are left out; Hyprland and Quickshell are required.
    keep = []
    for name in packages:
        if available(manager, name):
            keep.append(name)
        elif name in CORE:
            say(stage='packages', log=f'{name} is not in your repositories')
            return 4
        else:
            say(stage='packages', log=f'Skipping {name}: not in your repositories')
    def progress(line):
        m = re.search(r'\((\d+)/(\d+)\)', line)
        if m and int(m.group(2)) > 0:
            say(stage='packages', progress=int(m.group(1)) / int(m.group(2)), detail=line[:120])
    return stream('packages', INSTALL[manager] + keep, progress)


def write(path, text, mode):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + '.opal-tmp')
    tmp.write_text(text)
    os.chmod(tmp, mode)
    os.replace(tmp, path)


def run_session(opts):
    try:
        write(LAUNCHER, LAUNCHER_TEXT, 0o755)
        write(SESSION_FILE, SESSION_TEXT, 0o644)
    except OSError as error:
        say(stage='session', log=str(error))
        return 2
    say(stage='session', log=f'Added {SESSION_FILE} and {LAUNCHER}')
    return 0


def run_remove_session(opts):
    for path in (SESSION_FILE, LAUNCHER):
        try:
            path.unlink()
            say(stage='remove-session', log=f'Removed {path}')
        except FileNotFoundError:
            pass
        except OSError as error:
            say(stage='remove-session', log=f'Could not remove {path}: {error}')
            return 2
    return 0


RUNNERS = {'packages': run_packages, 'session': run_session, 'remove-session': run_remove_session}


def parse_args(argv):
    """Accept only --stages, --pm, --user and --packages. Anything else stops the helper."""
    opts = {'stages': [], 'pm': '', 'user': '', 'packages': []}
    i = 0
    while i < len(argv):
        key = argv[i]
        if i + 1 >= len(argv):
            raise ValueError(f'{key} needs a value')
        value = argv[i + 1]
        if key == '--stages':
            stages = [s for s in value.split(',') if s]
            if not stages or any(s not in STAGES for s in stages):
                raise ValueError('Unknown stage')
            opts['stages'] = stages
        elif key == '--pm':
            if value not in INSTALL and value != 'none':
                raise ValueError('Unknown package manager')
            opts['pm'] = value
        elif key == '--user':
            if not re.fullmatch(r'[a-z_][a-z0-9_-]{0,31}\$?', value):
                raise ValueError('Bad user name')
            opts['user'] = value
        elif key == '--packages':
            names = [n for n in value.split(',') if n]
            if len(names) > 64 or any(not PACKAGE_RE.fullmatch(n) for n in names):
                raise ValueError('Bad package list')
            opts['packages'] = names
        else:
            raise ValueError(f'Unknown option {key}')
        i += 2
    if not opts['stages']:
        raise ValueError('No stages')
    return opts


def main(argv):
    try:
        opts = parse_args(argv)
    except ValueError as error:
        say(error=str(error))
        return 64
    if os.geteuid() != 0:
        say(error='The helper must run as root')
        return 77
    threading.Thread(target=watch_stdin, daemon=True).start()
    for stage in opts['stages']:
        if cancelled.is_set():
            say(stage=stage, state='cancelled')
            return 130
        say(stage=stage, state='running')
        code = RUNNERS[stage](opts)
        if cancelled.is_set():
            say(stage=stage, state='cancelled')
            return 130
        if code:
            say(stage=stage, state='failed', code=code)
            return code
        say(stage=stage, state='done')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
