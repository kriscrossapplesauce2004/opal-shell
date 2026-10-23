#!/usr/bin/env python3
"""Root half of the Opal Waydroid installer: pkexec runs it once per install and it reports each stage as JSON lines on stdout."""
import json, os, pathlib, re, shutil, signal, subprocess, sys, threading, time

STAGES = ('package', 'binder', 'firewall', 'init', 'service', 'arm', 'androidid', 'reset', 'remove')
IMAGES = ('VANILLA', 'GAPPS')
MANAGERS = {
    'pacman': (['pacman', '-S', '--needed', '--noconfirm', 'waydroid'], ['pacman', '-Rns', '--noconfirm', 'waydroid']),
    'apt': (['apt-get', 'install', '-y', 'waydroid'], ['apt-get', 'remove', '-y', 'waydroid']),
    'dnf': (['dnf', 'install', '-y', 'waydroid'], ['dnf', 'remove', '-y', 'waydroid']),
    'zypper': (['zypper', '--non-interactive', 'install', 'waydroid'], ['zypper', '--non-interactive', 'remove', 'waydroid']),
    'apk': (['apk', 'add', 'waydroid'], ['apk', 'del', 'waydroid']),
}
SCRIPT_REPO = 'https://github.com/casualsnek/waydroid_script'
SCRIPT_DIR = pathlib.Path('/var/cache/opal/waydroid_script')
GSF_QUERY = "select value from main where name='android_id';"
UNITS = {'B': 1, 'KB': 1024, 'MB': 1024 ** 2, 'GB': 1024 ** 3}
DOWNLOAD_RE = re.compile(r'\[Downloading\]\s*([\d.]+)\s*([KMG]?B)\s*/\s*([\d.]+)\s*([KMG]?B)(?:\s+([\d.]+\s*\S+?)\s*\(approx)?', re.I)
URL_RE = re.compile(r'Downloading\s+(https?://\S+)', re.I)

cancelled = threading.Event()
current = {'proc': None}

def say(**fields):
    """Write one JSON line for the backend. The backend reads stdout only."""
    sys.stdout.write(json.dumps(fields) + '\n')
    sys.stdout.flush()

def watch_stdin():
    """A 'cancel' line or a closed stdin stops the running child, so the user half can cancel a root process it cannot signal."""
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

def parse_download(line):
    """Return (done_bytes, total_bytes, speed_text) for a waydroid '[Downloading]' line, or None."""
    m = DOWNLOAD_RE.search(line)
    if not m:
        return None
    done = float(m.group(1)) * UNITS.get(m.group(2).upper(), 1)
    total = float(m.group(3)) * UNITS.get(m.group(4).upper(), 1)
    return int(done), int(total), (m.group(5) or '').strip()

def image_kind(url):
    low = url.lower()
    return 'vendor' if '/vendor/' in low or 'vendor' in low.rsplit('/', 2)[-2:][0] else 'system'

def stream(stage, args, on_line=None, env=None):
    """Run args and forward each line (split on CR as well as LF) as a log event. Return the exit code."""
    try:
        proc = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL,
                                start_new_session=True, env=env or dict(os.environ, LC_ALL='C'))
    except OSError as error:
        say(stage=stage, log=f'{args[0]}: {error}')
        return 127
    current['proc'] = proc
    buf = b''
    last_log = 0.0
    while True:
        chunk = proc.stdout.read1(4096) if hasattr(proc.stdout, 'read1') else proc.stdout.read(4096)
        if not chunk:
            break
        buf += chunk
        parts = re.split(rb'[\r\n]', buf)
        buf = parts.pop()
        for raw in parts:
            line = raw.decode('utf-8', 'replace').strip()
            if not line:
                continue
            handled = on_line(line) if on_line else False
            # Progress lines repeat many times a second; only every half second reaches the log.
            now = time.monotonic()
            if not handled or now - last_log > .5:
                say(stage=stage, log=line[:400])
                last_log = now
    if buf.strip():
        say(stage=stage, log=buf.decode('utf-8', 'replace').strip()[:400])
    code = proc.wait()
    current['proc'] = None
    return code

def binder_ready():
    try:
        if 'binder' in pathlib.Path('/proc/filesystems').read_text():
            return True
    except OSError:
        pass
    return pathlib.Path('/dev/binder').exists() or pathlib.Path('/dev/anbox-binder').exists()

def firewall_kind():
    if shutil.which('firewall-cmd') and subprocess.run(['systemctl', 'is-active', '--quiet', 'firewalld']).returncode == 0:
        return 'firewalld'
    if shutil.which('ufw'):
        try:
            out = subprocess.run(['ufw', 'status'], capture_output=True, text=True, timeout=5).stdout
            if 'Status: active' in out:
                return 'ufw'
        except (OSError, subprocess.SubprocessError):
            pass
    return ''

def run_package(opts):
    if shutil.which('waydroid'):
        say(stage='package', log='Waydroid is already installed')
        return 0
    manager = opts.get('pm', '')
    if manager not in MANAGERS:
        say(stage='package', log='No supported package manager was found')
        return 2
    def progress(line):
        m = re.search(r'\((\d+)/(\d+)\)', line)
        if m and int(m.group(2)) > 0:
            say(stage='package', progress=int(m.group(1)) / int(m.group(2)), detail=line[:120])
            return True
        return False
    return stream('package', MANAGERS[manager][0], progress)

def run_binder(opts):
    if binder_ready():
        say(stage='binder', log='The kernel already has binder')
        return 0
    if not shutil.which('modprobe'):
        return 2
    code = stream('binder', ['modprobe', 'binder_linux', 'devices=binder,hwbinder,vndbinder'])
    if code == 0:
        # Load the module on every boot too.
        try:
            pathlib.Path('/etc/modules-load.d/opal-waydroid.conf').write_text('binder_linux\n')
            pathlib.Path('/etc/modprobe.d/opal-waydroid.conf').write_text('options binder_linux devices=binder,hwbinder,vndbinder\n')
        except OSError as error:
            say(stage='binder', log=f'Could not save the module settings: {error}')
    return code

def run_firewall(opts):
    kind = firewall_kind()
    if kind == 'firewalld':
        code = stream('firewall', ['firewall-cmd', '--zone=trusted', '--add-interface=waydroid0'])
        return code or stream('firewall', ['firewall-cmd', '--permanent', '--zone=trusted', '--add-interface=waydroid0'])
    if kind == 'ufw':
        for args in (['ufw', 'allow', 'in', 'on', 'waydroid0'], ['ufw', 'route', 'allow', 'in', 'on', 'waydroid0'], ['ufw', 'route', 'allow', 'out', 'on', 'waydroid0']):
            code = stream('firewall', args)
            if code:
                return code
        return 0
    say(stage='firewall', log='No active firewall blocks Waydroid')
    return 0

def run_init(opts):
    image = opts.get('image', 'VANILLA')
    state = {'files': 0, 'kind': 'system', 'last': -1}
    def progress(line):
        url = URL_RE.search(line)
        if url:
            state['kind'] = image_kind(url.group(1))
            state['files'] += 1
            say(stage='init', detail=f'Downloading the Android {state["kind"]} image', progress=-1)
            return False
        got = parse_download(line)
        if got:
            done, total, speed = got
            frac = done / total if total else 0
            # Two images: system is the first half of the bar and vendor the second.
            whole = (.5 * frac) if state['kind'] == 'system' else (.5 + .5 * frac)
            say(stage='init', progress=round(whole, 4), done=done, total=total, speed=speed, part=state['kind'])
            return True
        low = line.lower()
        if 'validating' in low or 'extracting' in low:
            say(stage='init', detail=line[:120], progress=-1)
        return False
    args = ['waydroid', 'init', '-s', image]
    if opts.get('force'):
        args.append('-f')
    return stream('init', args, progress)

def run_service(opts):
    if not shutil.which('systemctl'):
        return stream('service', ['rc-service', 'waydroid-container', 'start']) if shutil.which('rc-service') else 2
    return stream('service', ['systemctl', 'enable', '--now', 'waydroid-container.service'])

def run_arm(opts):
    if os.uname().machine not in ('x86_64', 'amd64'):
        say(stage='arm', log='This CPU runs ARM apps natively')
        return 0
    try:
        intel = 'GenuineIntel' in pathlib.Path('/proc/cpuinfo').read_text()
    except OSError:
        intel = False
    lib = 'libhoudini' if intel else 'libndk'
    say(stage='arm', detail=f'Adding {lib} for ARM apps', progress=-1)
    if not shutil.which('git'):
        say(stage='arm', log='git is needed for ARM app support')
        return 2
    SCRIPT_DIR.parent.mkdir(parents=True, exist_ok=True)
    if (SCRIPT_DIR / '.git').exists():
        code = stream('arm', ['git', '-C', str(SCRIPT_DIR), 'pull', '--ff-only'])
    else:
        code = stream('arm', ['git', 'clone', '--depth', '1', SCRIPT_REPO, str(SCRIPT_DIR)])
    if code:
        return code
    venv = SCRIPT_DIR / 'venv'
    if not (venv / 'bin/python').exists():
        code = stream('arm', [sys.executable, '-m', 'venv', str(venv)])
        if code:
            return code
    code = stream('arm', [str(venv / 'bin/pip'), 'install', '-q', '-r', str(SCRIPT_DIR / 'requirements.txt')])
    if code:
        return code
    return stream('arm', [str(venv / 'bin/python'), str(SCRIPT_DIR / 'main.py'), 'install', lib])

def run_androidid(opts):
    db = '/data/data/com.google.android.gsf/databases/gservices.db'
    try:
        res = subprocess.run(['waydroid', 'shell', '--', 'sqlite3', db, GSF_QUERY], capture_output=True, text=True, timeout=20)
        out = (res.stdout or '').strip()
        if not re.fullmatch(r'\d{6,25}', out):
            # Older Waydroid reads the shell command from stdin.
            res = subprocess.run(['waydroid', 'shell'], input=f'sqlite3 {db} "{GSF_QUERY}"\n', capture_output=True, text=True, timeout=20)
            out = (res.stdout or '').strip().splitlines()[-1:] or ['']
            out = out[0].strip()
    except (OSError, subprocess.SubprocessError) as error:
        say(stage='androidid', log=str(error))
        return 2
    if re.fullmatch(r'\d{6,25}', out):
        say(stage='androidid', androidId=out)
        return 0
    say(stage='androidid', log='Google services are not ready yet. Open the Play Store once, wait a minute, then try again.')
    return 3

def run_reset(opts):
    if shutil.which('waydroid'):
        stream('reset', ['waydroid', 'container', 'stop'])
    if shutil.which('systemctl'):
        stream('reset', ['systemctl', 'disable', '--now', 'waydroid-container.service'])
    for path in ('/var/lib/waydroid', '/etc/modules-load.d/opal-waydroid.conf', '/etc/modprobe.d/opal-waydroid.conf'):
        p = pathlib.Path(path)
        try:
            if p.is_dir() and not p.is_symlink():
                shutil.rmtree(p)
            elif p.exists():
                p.unlink()
            say(stage='reset', log=f'Removed {path}')
        except OSError as error:
            say(stage='reset', log=f'Could not remove {path}: {error}')
    return 0

def run_remove(opts):
    manager = opts.get('pm', '')
    if not shutil.which('waydroid'):
        return 0
    if manager not in MANAGERS:
        return 2
    return stream('remove', MANAGERS[manager][1])

RUNNERS = {'package': run_package, 'binder': run_binder, 'firewall': run_firewall, 'init': run_init, 'service': run_service,
           'arm': run_arm, 'androidid': run_androidid, 'reset': run_reset, 'remove': run_remove}

def parse_args(argv):
    """Accept only --stages a,b --image X --pm Y --force. Anything else stops the helper."""
    opts = {'stages': [], 'image': 'VANILLA', 'pm': '', 'force': False}
    i = 0
    while i < len(argv):
        key = argv[i]
        if key == '--force':
            opts['force'] = True
            i += 1
            continue
        if i + 1 >= len(argv):
            raise ValueError(f'{key} needs a value')
        value = argv[i + 1]
        if key == '--stages':
            stages = [s for s in value.split(',') if s]
            if not stages or any(s not in STAGES for s in stages):
                raise ValueError('Unknown stage')
            opts['stages'] = stages
        elif key == '--image':
            if value not in IMAGES:
                raise ValueError('Unknown image')
            opts['image'] = value
        elif key == '--pm':
            if value not in MANAGERS:
                raise ValueError('Unknown package manager')
            opts['pm'] = value
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
