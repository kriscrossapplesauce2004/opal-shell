#!/usr/bin/env python3
"""Compat Lab skeleton: fetch, install, launch and smoke-test Android apps (moonshot 13.1)."""
import argparse
import datetime
import hashlib
import html
import json
import os
import pathlib
import re
import struct
import subprocess
import sys
import time
import tomllib
import urllib.request
import zipfile
import zlib
from dataclasses import asdict, dataclass

HERE = pathlib.Path(__file__).resolve().parent
# Reuse the F-Droid index logic from the Opal tree; appended so stdlib names win.
sys.path.append(str(HERE.parent.parent / 'src'))
try:
    import android_store as store
except ImportError:  # the Opal source tree is not next to this folder
    store = None

SCHEMA = 1
VERDICTS = ('pass', 'fail', 'crash', 'anr', 'no-launch', 'skipped')
# Higher rank is worse. Skipped apps do not count either way.
RANK = {'pass': 0, 'skipped': 0, 'fail': 2, 'no-launch': 2, 'anr': 3, 'crash': 4}
SOURCES = ('fdroid', 'apk-url', 'play-placeholder')
ABIS = ('x86_64-capable', 'arm-only')
CATEGORIES = ('browser', 'maps', 'messaging', 'media', 'notes', 'keyboard', 'files', 'game', 'system', 'other')
PACKAGE_RE = re.compile(r'^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z0-9_]+)+$')
SHA_RE = re.compile(r'^[0-9a-f]{64}$')
ACCOUNT_RE = re.compile(r'^[a-z0-9][a-z0-9-]{0,62}$')
STEP_RE = re.compile(r'^(launch|settle:\d{1,3}|monkey:\d{1,4})$')
DEFAULT_SMOKE = ('launch', 'settle:8')
LAUNCHER = 'android.intent.category.LAUNCHER'
X86_ABIS = ['x86_64', 'x86']
INDEX_MAX_AGE = 24 * 3600
MONKEY_SEED = 4242
TIMEOUT_CMD = 60
TIMEOUT_INSTALL = 300
TIMEOUT_SHOT = 30
PNG_MAGIC = b'\x89PNG\r\n\x1a\n'
CRASH_HEAD = 'FATAL EXCEPTION'
FIXTURE = HERE / 'fixtures' / 'fake-default.json'
APPS = HERE / 'apps.toml'


class LabError(Exception):
    """A problem the user must fix; reported without a traceback."""


def cache_root(override=None):
    """Cache folder under XDG_CACHE_HOME, or the override."""
    base = override or os.environ.get('XDG_CACHE_HOME') or pathlib.Path.home() / '.cache'
    return pathlib.Path(base) / 'compat-lab'


# ---------- app list ----------

@dataclass(frozen=True)
class App:
    package: str
    name: str
    source: str
    abi: str
    category: str
    test_account: str
    smoke: tuple
    url: str = ''
    sha256: str = ''


def parse_step(step):
    """Split one smoke step into (kind, argument)."""
    if step == 'launch':
        return 'launch', 0
    kind, _, arg = step.partition(':')
    return kind, int(arg)


def parse_app(raw, index):
    """Validate one [[app]] table."""
    where = f'app #{index}'
    package = str(raw.get('package', ''))
    if not PACKAGE_RE.match(package):
        raise LabError(f'{where}: bad package id {package!r}')
    where = package
    source, abi, category = raw.get('source'), raw.get('abi'), raw.get('category')
    if source not in SOURCES:
        raise LabError(f'{where}: source must be one of {", ".join(SOURCES)}')
    if abi not in ABIS:
        raise LabError(f'{where}: abi must be one of {", ".join(ABIS)}')
    if category not in CATEGORIES:
        raise LabError(f'{where}: category must be one of {", ".join(CATEGORIES)}')
    account = str(raw.get('test_account', 'none'))
    if not ACCOUNT_RE.match(account):
        raise LabError(f'{where}: test_account must be a placeholder name, not a credential')
    smoke = tuple(str(s) for s in (raw.get('smoke') or DEFAULT_SMOKE))
    for step in smoke:
        if not STEP_RE.match(step):
            raise LabError(f'{where}: unknown smoke step {step!r}')
    if 'launch' not in smoke:
        smoke = ('launch',) + smoke
    url, sha = str(raw.get('url', '')), str(raw.get('sha256', '')).lower()
    if source == 'apk-url':
        if not url.startswith(('https://', 'file://')):
            raise LabError(f'{where}: apk-url needs an https:// url')
        if not SHA_RE.match(sha):
            raise LabError(f'{where}: apk-url needs a 64 character sha256')
    elif url or sha:
        raise LabError(f'{where}: url and sha256 only apply to apk-url entries')
    return App(package, str(raw.get('name', package)), source, abi, category, account, smoke, url, sha)


def load_apps(path):
    """Read and validate apps.toml; return App rows in file order."""
    try:
        with open(path, 'rb') as f:
            data = tomllib.load(f)
    except (OSError, tomllib.TOMLDecodeError) as error:
        raise LabError(f'cannot read {path}: {error}')
    if data.get('schema') != SCHEMA:
        raise LabError(f'{path}: schema must be {SCHEMA}')
    apps, seen = [], set()
    for i, raw in enumerate(data.get('app') or [], 1):
        app = parse_app(raw, i)
        if app.package in seen:
            raise LabError(f'duplicate package {app.package}')
        seen.add(app.package)
        apps.append(app)
    return apps


def select(apps, only):
    """Keep the named packages, or all apps when none are named."""
    if not only:
        return apps
    known = {a.package for a in apps}
    missing = [p for p in only if p not in known]
    if missing:
        raise LabError('not in the app list: ' + ', '.join(missing))
    wanted = set(only)
    return [a for a in apps if a.package in wanted]


def shard_apps(apps, containers):
    """Split apps into one shard per container; shards run one after another for now."""
    n = max(1, int(containers))
    return [apps[i::n] for i in range(n)]


# ---------- logcat and monkey parsing ----------

PROCESS_RE = re.compile(r'Process:\s*([A-Za-z0-9_.:]+),\s*PID:\s*\d+')
ANR_RE = re.compile(r'ANR in\s+([A-Za-z0-9_.:]+)')
REASON_RE = re.compile(r'Reason:\s*(.+)$')
NATIVE_RE = re.compile(r'Fatal signal \d+ \((SIG\w+)\).*\bpid \d+ \(([^)]+)\)\s*$')
MONKEY_CRASH_RE = re.compile(r'// CRASH: (\S+) \(pid \d+\)')
MONKEY_ANR_RE = re.compile(r'// NOT RESPONDING: (\S+) \(pid \d+\)')


@dataclass(frozen=True)
class Finding:
    kind: str
    process: str
    detail: str


def message(line):
    """Text after the logcat tag and level."""
    return line.split(': ', 1)[1] if ': ' in line else line


def parse_logcat(text):
    """Find Java crashes, ANRs and native crashes in logcat text."""
    lines = str(text or '').splitlines()
    found = []
    for i, line in enumerate(lines):
        if CRASH_HEAD in line:
            window = lines[i + 1:i + 6]
            process = next((m.group(1) for m in (PROCESS_RE.search(message(w)) for w in window) if m), '')
            detail = next((message(w).strip() for w in window
                           if message(w).strip() and not PROCESS_RE.search(message(w))), '')
            found.append(Finding('crash', process, detail[:200]))
        elif 'ANR in ' in line:
            m = ANR_RE.search(line)
            if m:
                reason = next((r.group(1) for r in (REASON_RE.search(message(w)) for w in lines[i + 1:i + 5]) if r), '')
                found.append(Finding('anr', m.group(1), reason[:200]))
        else:
            m = NATIVE_RE.search(line)
            if m:
                found.append(Finding('crash', m.group(2), m.group(1)))
    return found


def parse_monkey(text):
    """Find crash and no-response lines that monkey prints."""
    found = []
    for line in str(text or '').splitlines():
        m = MONKEY_CRASH_RE.search(line)
        if m:
            found.append(Finding('crash', m.group(1), 'monkey reported a crash'))
        m = MONKEY_ANR_RE.search(line)
        if m:
            found.append(Finding('anr', m.group(1), 'monkey reported no response'))
    return found


def findings_for(findings, package):
    """Keep findings for the app and its sub-processes (package:name)."""
    return [f for f in findings if f.process == package or f.process.startswith(package + ':')]


def verdict(install_ok, launch_ok, running, findings, smoke_ok=True):
    """Map one app's measurements to one verdict, most severe first."""
    if not install_ok:
        return 'fail'
    kinds = {f.kind for f in findings}
    if 'crash' in kinds:
        return 'crash'
    if 'anr' in kinds:
        return 'anr'
    if not launch_ok or not running:
        return 'no-launch'
    if not smoke_ok:
        return 'fail'
    return 'pass'


# ---------- devices ----------

def run_cmd(args, timeout):
    """Run one command from an argument array; None when it cannot run or times out."""
    try:
        return subprocess.run(list(args), capture_output=True, timeout=timeout, check=False)
    except (OSError, subprocess.SubprocessError):
        return None


def _text(res):
    if res is None or res.stdout is None:
        return ''
    return res.stdout.decode('utf-8', 'replace') if isinstance(res.stdout, bytes) else str(res.stdout)


def _ok(res):
    return res is not None and res.returncode == 0


class WaydroidDevice:
    """Real backend: waydroid for install and remove, adb for the rest."""

    name = 'waydroid'
    needs_apk = True

    def __init__(self, serial='', installer='waydroid', runner=run_cmd):
        self.serial = serial
        self.installer = installer
        self.runner = runner

    def _adb(self, *args):
        cmd = ['adb']
        if self.serial:
            cmd += ['-s', self.serial]
        return cmd + list(args)

    def installed(self, package):
        res = self.runner(self._adb('shell', 'pm', 'path', package), TIMEOUT_CMD)
        return _ok(res) and 'package:' in _text(res)

    def install(self, package, apk):
        if self.installer == 'waydroid':
            cmd = ['waydroid', 'app', 'install', str(apk)]
        else:
            cmd = self._adb('install', '-r', str(apk))
        res = self.runner(cmd, TIMEOUT_INSTALL)
        return _ok(res), (_text(res) or 'could not run the installer')[-300:]

    def launch(self, package):
        res = self.runner(self._adb('shell', 'monkey', '-p', package, '-c', LAUNCHER, '1'), TIMEOUT_CMD)
        out = _text(res)
        return _ok(res) and 'No activities found' not in out, out[-300:]

    def pid(self, package):
        res = self.runner(self._adb('shell', 'pidof', package), TIMEOUT_CMD)
        if not _ok(res):
            return None
        return next((int(t) for t in _text(res).split() if t.isdigit()), None)

    def logcat_clear(self):
        self.runner(self._adb('logcat', '-c'), TIMEOUT_CMD)

    def logcat_dump(self):
        return _text(self.runner(self._adb('logcat', '-d'), TIMEOUT_CMD))

    def monkey(self, package, events, seed):
        timeout = TIMEOUT_CMD + events * 0.5
        res = self.runner(self._adb('shell', 'monkey', '-p', package, '-s', str(seed), '--throttle', '100',
                                    '--pct-syskeys', '0', str(events)), timeout)
        return _ok(res), _text(res)

    def screenshot(self, package):
        res = self.runner(self._adb('exec-out', 'screencap', '-p'), TIMEOUT_SHOT)
        if not _ok(res) or not res.stdout.startswith(PNG_MAGIC):
            return None
        return res.stdout

    def uninstall(self, package):
        if self.installer == 'waydroid':
            cmd = ['waydroid', 'app', 'remove', package]
        else:
            cmd = self._adb('uninstall', package)
        return _ok(self.runner(cmd, TIMEOUT_CMD))


def make_png(width=16, height=24, rgb=(40, 44, 52)):
    """Solid colour PNG built with the standard library only."""
    raw = b''.join(b'\x00' + bytes(rgb) * width for _ in range(height))

    def chunk(tag, data):
        return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', zlib.crc32(tag + data) & 0xffffffff)
    ihdr = struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)
    return PNG_MAGIC + chunk(b'IHDR', ihdr) + chunk(b'IDAT', zlib.compress(raw)) + chunk(b'IEND', b'')


class FakeDevice:
    """Simulated backend driven by a fixture; it touches no real device."""

    name = 'fake'
    needs_apk = False
    DEFAULTS = {'install': 'ok', 'launch': 'ok', 'running': True, 'logcat': '', 'monkey': 'ok',
                'monkey_output': '', 'preinstalled': False}

    def __init__(self, fixture):
        self.spec = dict(self.DEFAULTS, **(fixture.get('defaults') or {}))
        self.apps = fixture.get('apps') or {}
        self.installed_set = {p for p in self.apps if self._spec(p)['preinstalled']}
        self.running = set()
        self.current = ''

    def _spec(self, package):
        return dict(self.spec, **(self.apps.get(package) or {}))

    def installed(self, package):
        return package in self.installed_set

    def install(self, package, apk):
        self.current = package
        ok = self._spec(package)['install'] == 'ok'
        if ok:
            self.installed_set.add(package)
        return ok, '' if ok else 'INSTALL_FAILED_FIXTURE: refused by the fixture'

    def launch(self, package):
        s = self._spec(package)
        ok = package in self.installed_set and s['launch'] == 'ok'
        if ok and s['running']:
            self.running.add(package)
        return ok, '' if ok else 'Error: fixture launch failed'

    def pid(self, package):
        if package not in self.running:
            return None
        return 1000 + zlib.crc32(package.encode()) % 30000

    def logcat_clear(self):
        self.current = ''

    def logcat_dump(self):
        return self._spec(self.current)['logcat'] if self.current else ''

    def monkey(self, package, events, seed):
        s = self._spec(package)
        ok = package in self.running and s['monkey'] == 'ok'
        return ok, s['monkey_output'] if package in self.running else ''

    def screenshot(self, package):
        rgb = tuple(zlib.crc32(package.encode()).to_bytes(4, 'big')[1:])
        return make_png(rgb=rgb)

    def uninstall(self, package):
        self.installed_set.discard(package)
        self.running.discard(package)
        return True


def load_fixture(path):
    try:
        with open(path, encoding='utf-8') as f:
            return json.load(f)
    except (OSError, ValueError) as error:
        raise LabError(f'cannot read fixture {path}: {error}')


# ---------- fetch ----------

def sha256_file(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def download(url, dest, opener=urllib.request.urlopen, timeout=60):
    """Stream url to dest through a .part file."""
    dest.parent.mkdir(parents=True, exist_ok=True)
    part = dest.with_name(dest.name + '.part')
    req = urllib.request.Request(url, headers={'User-Agent': 'compat-lab/0.1'})
    try:
        with opener(req, timeout=timeout) as res, open(part, 'wb') as out:
            while True:
                chunk = res.read(256 * 1024)
                if not chunk:
                    break
                out.write(chunk)
        os.replace(part, dest)
    except (OSError, ValueError) as error:
        part.unlink(missing_ok=True)
        raise LabError(f'download failed for {url}: {error}')
    return dest


def fresh(path, max_age):
    return path.exists() and time.time() - path.stat().st_mtime < max_age


def load_index(cache, refresh=False, opener=urllib.request.urlopen):
    """Download (when stale) and read the F-Droid index-v1.jar."""
    if store is None:
        raise LabError('android_store.py is not importable from opal/src; fdroid entries cannot resolve')
    jar = cache / 'index-v1.jar'
    if refresh or not fresh(jar, INDEX_MAX_AGE):
        download(store.INDEX_URL, jar, opener, timeout=120)
    try:
        with zipfile.ZipFile(jar) as z:
            return json.loads(z.read('index-v1.json'))
    except (OSError, KeyError, ValueError, zipfile.BadZipFile) as error:
        raise LabError(f'bad F-Droid index at {jar}: {error}')


def fdroid_catalog(index):
    """Map package to the newest x86_64-or-Java APK entry, using android_store.build_catalog."""
    if store is None:
        raise LabError('android_store.py is not importable from opal/src')
    return {a['package']: a for a in store.build_catalog(index, X86_ABIS)}


def fetch_app(app, cache, catalog, opener=urllib.request.urlopen):
    """Download one APK, verify its sha256 and return its manifest entry."""
    if app.source == 'fdroid':
        entry = catalog.get(app.package)
        if entry is None:
            raise LabError('no x86_64 or Java build in the F-Droid index')
        digest, name, url = entry['hash'], entry['apk'], f"{store.REPO}/{entry['apk']}"
        version, code = entry['version'], entry['versionCode']
    else:
        digest, url = app.sha256, app.url
        name = f'{app.package}-{digest[:12]}.apk'
        version, code = '', 0
    if not re.fullmatch(r'[0-9a-f]{64}', digest or ''):
        raise LabError('no sha256 to verify against')
    target = cache / 'apk' / name
    if not (target.exists() and sha256_file(target) == digest):
        download(url, target, opener)
        got = sha256_file(target)
        if got != digest:
            target.unlink(missing_ok=True)
            raise LabError(f'checksum mismatch: expected {digest[:12]}, got {got[:12]}')
    return {'source': app.source, 'path': str(target), 'sha256': digest, 'version': version,
            'versionCode': code, 'fetched': utc_now()}


def read_manifest(cache):
    try:
        return json.loads((cache / 'manifest.json').read_text(encoding='utf-8'))
    except (OSError, ValueError):
        return {}


def write_manifest(cache, data):
    cache.mkdir(parents=True, exist_ok=True)
    tmp = cache / 'manifest.json.part'
    tmp.write_text(json.dumps(data, indent=2, sort_keys=True) + '\n', encoding='utf-8')
    os.replace(tmp, cache / 'manifest.json')


def utc_now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat(timespec='seconds')


def cmd_fetch(args):
    apps = select(load_apps(args.apps), args.only)
    cache = cache_root(args.cache)
    cache.mkdir(parents=True, exist_ok=True)
    manifest = read_manifest(cache)
    catalog = {}
    if any(a.source == 'fdroid' for a in apps):
        catalog = fdroid_catalog(load_index(cache, args.refresh_index))
    failures = 0
    for app in apps:
        if app.source == 'play-placeholder':
            print(f'skip    {app.package}: play-placeholder')
            continue
        try:
            manifest[app.package] = fetch_app(app, cache, catalog)
            print(f'ok      {app.package}  {manifest[app.package]["sha256"][:12]}  {manifest[app.package]["version"]}')
        except LabError as error:
            failures += 1
            print(f'FAILED  {app.package}: {error}')
    write_manifest(cache, manifest)
    print(f'cache: {cache}')
    return 1 if failures else 0


# ---------- run ----------

@dataclass
class RunOptions:
    seed: int = MONKEY_SEED
    settle_scale: float = 1.0
    sleep: object = time.sleep


def run_one(app, device, manifest, out, opts):
    """Install, launch, smoke-test, screenshot and remove one app."""
    rec = {'package': app.package, 'name': app.name, 'category': app.category, 'abi': app.abi,
           'source': app.source, 'test_account': app.test_account, 'version': '', 'verdict': 'skipped',
           'note': '', 'screenshot': '', 'log': '', 'findings': []}
    if app.source == 'play-placeholder':
        rec['note'] = 'Play apps are not run yet'
        return rec
    if app.abi == 'arm-only':
        rec['note'] = 'arm-only: needs the phone lane, which is not built'
        return rec
    apk = ''
    if device.needs_apk:
        entry = manifest.get(app.package)
        if not entry:
            rec['note'] = 'not in the cache: run fetch first'
            return rec
        apk, rec['version'] = entry['path'], entry.get('version', '')
        try:
            if sha256_file(apk) != entry['sha256']:
                rec['note'] = 'cached APK fails its checksum: run fetch again'
                return rec
        except OSError:
            rec['note'] = 'cached APK is missing: run fetch again'
            return rec
    if device.installed(app.package):
        rec['note'] = 'already installed on the device: left alone'
        return rec
    device.logcat_clear()
    install_ok, install_out = False, ''
    launch_ok = running = False
    smoke_ok = True
    monkey_text, logcat, shot = '', '', None
    try:
        install_ok, install_out = device.install(app.package, apk)
        if install_ok:
            checked = False
            for step in app.smoke:
                kind, arg = parse_step(step)
                if kind == 'launch':
                    launch_ok, launch_out = device.launch(app.package)
                    if not launch_ok:
                        rec['note'] = launch_out.strip()[:200]
                        break
                elif kind == 'settle':
                    opts.sleep(arg * opts.settle_scale)
                    if not checked:
                        running, checked = device.pid(app.package) is not None, True
                elif kind == 'monkey':
                    ok, text = device.monkey(app.package, arg, opts.seed)
                    monkey_text += text
                    smoke_ok = smoke_ok and ok
            if not checked:
                running = device.pid(app.package) is not None
            logcat = device.logcat_dump()
            shot = device.screenshot(app.package)
    finally:
        # Only remove what this run installed.
        if install_ok:
            device.uninstall(app.package)
    findings = findings_for(parse_logcat(logcat) + parse_monkey(monkey_text), app.package)
    rec['findings'] = [asdict(f) for f in findings]
    rec['verdict'] = verdict(install_ok, launch_ok, running, findings, smoke_ok)
    if not install_ok:
        rec['note'] = install_out.strip()[-200:]
    if shot:
        (out / 'shots').mkdir(parents=True, exist_ok=True)
        (out / 'shots' / f'{app.package}.png').write_bytes(shot)
        rec['screenshot'] = f'shots/{app.package}.png'
    if rec['verdict'] != 'pass' and (install_ok or logcat):
        write_log(out, app, findings, logcat, monkey_text)
        rec['log'] = f'logs/{app.package}.log'
    return rec


def write_log(out, app, findings, logcat, monkey_text):
    """Write the findings and the logcat lines that mention the app."""
    keep = [line for line in logcat.splitlines()
            if app.package in line or CRASH_HEAD in line or 'ANR in' in line or 'Fatal signal' in line]
    lines = [f'{f.kind}: {f.process}: {f.detail}' for f in findings]
    lines += ['--- logcat excerpt ---'] + keep[-300:] + ['--- monkey ---', monkey_text[-2000:]]
    (out / 'logs').mkdir(parents=True, exist_ok=True)
    (out / 'logs' / f'{app.package}.log').write_text('\n'.join(lines) + '\n', encoding='utf-8')


def count(records):
    return {v: sum(1 for r in records if r['verdict'] == v) for v in VERDICTS}


def make_device(args):
    if args.device == 'fake':
        return FakeDevice(load_fixture(args.fixture))
    # Without a serial, adb can pick a USB phone instead of the container.
    if not args.serial:
        raise SystemExit('compat-lab: --device waydroid needs --serial (the Waydroid adb address, e.g. 192.168.240.112:5555).')
    return WaydroidDevice(serial=args.serial, installer=args.installer)


def cmd_run(args):
    apps = select(load_apps(args.apps), args.only)
    out = pathlib.Path(args.out) if args.out else cache_root(args.cache) / 'runs' / datetime.datetime.now().strftime('%Y%m%d-%H%M%S')
    out.mkdir(parents=True, exist_ok=True)
    device = make_device(args)
    manifest = read_manifest(cache_root(args.cache)) if device.needs_apk else {}
    opts = RunOptions(seed=args.seed, settle_scale=args.settle_scale)
    if args.containers > 1:
        print('note: --containers > 1 is designed in but not parallel yet; shards run one after another')
    started = utc_now()
    records = []
    for shard in shard_apps(apps, args.containers):
        for app in shard:
            rec = run_one(app, device, manifest, out, opts)
            records.append(rec)
            print(f'{rec["verdict"]:<10} {app.package}  {rec["note"]}'.rstrip())
    doc = {'schema': SCHEMA, 'started': started, 'finished': utc_now(), 'device': device.name,
           'containers': args.containers, 'seed': args.seed, 'counts': count(records), 'apps': records}
    (out / 'results.json').write_text(json.dumps(doc, indent=2) + '\n', encoding='utf-8')
    print(f'results: {out / "results.json"}')
    print('counts: ' + ', '.join(f'{k} {v}' for k, v in doc['counts'].items() if v))
    return 0


# ---------- report ----------

def load_results(path):
    """Read a results.json or report.json with a valid schema."""
    try:
        doc = json.loads(pathlib.Path(path).read_text(encoding='utf-8'))
    except (OSError, ValueError) as error:
        raise LabError(f'cannot read {path}: {error}')
    if doc.get('schema') != SCHEMA or not isinstance(doc.get('apps'), list):
        raise LabError(f'{path}: not a Compat Lab result file')
    for rec in doc['apps']:
        if rec.get('verdict') not in VERDICTS or not rec.get('package'):
            raise LabError(f'{path}: bad row for {rec.get("package", "?")}')
    return doc


BADGE_CSS = """
:root{--bg:#fbfaf7;--fg:#1d1c1a;--muted:#6b675f;--line:#ddd8cc;--pass:#1f7a3a;--bad:#b3261e;--warn:#8a5a00;--skip:#6b675f}
@media (prefers-color-scheme: dark){:root:not([data-theme="light"]){--bg:#171614;--fg:#eceae4;--muted:#a19d93;--line:#3a3833;--pass:#6fd08c;--bad:#ff8a80;--warn:#f0c060;--skip:#a19d93}}
:root[data-theme="dark"]{--bg:#171614;--fg:#eceae4;--muted:#a19d93;--line:#3a3833;--pass:#6fd08c;--bad:#ff8a80;--warn:#f0c060;--skip:#a19d93}
body{margin:0;padding:16px;background:var(--bg);color:var(--fg);font:14px/1.45 system-ui,sans-serif}
h1{font-size:20px;margin:0 0 8px}
.muted{color:var(--muted)}
table{border-collapse:collapse;width:100%}
th,td{border-bottom:1px solid var(--line);padding:8px;text-align:left;vertical-align:top}
img{width:96px;border:1px solid var(--line);border-radius:8px}
.v{font-weight:600}
.pass{color:var(--pass)}.crash,.fail{color:var(--bad)}.anr,.no-launch{color:var(--warn)}.skipped{color:var(--skip)}
@media (max-width:700px){table,thead,tbody,tr,td{display:block}thead{display:none}td{border:0;padding:3px 0}tr{border-bottom:1px solid var(--line);padding:8px 0}img{width:72px}}
"""


def render_html(doc, base_dir, html_dir):
    """Build a standalone HTML table of verdicts and screenshots."""
    summary = ' · '.join(f'{v} {n}' for v, n in count(doc['apps']).items() if n) or 'no apps'
    rows = []
    for rec in doc['apps']:
        shot = ''
        if rec.get('screenshot'):
            src = pathlib.Path(os.path.relpath(base_dir / rec['screenshot'], html_dir)).as_posix()
            shot = f'<img src="{html.escape(src)}" alt="screenshot of {html.escape(rec["package"])}">'
        findings = ''.join(f'<div class="muted">{html.escape(f["kind"])}: {html.escape(f["detail"])}</div>'
                           for f in rec.get('findings', []))
        note = html.escape(rec.get('note', ''))
        rows.append(
            '<tr>'
            f'<td><b>{html.escape(rec.get("name", rec["package"]))}</b><br><span class="muted">{html.escape(rec["package"])}</span></td>'
            f'<td>{html.escape(rec.get("category", ""))}</td>'
            f'<td>{html.escape(rec.get("abi", ""))}</td>'
            f'<td><span class="v {rec["verdict"]}">{rec["verdict"]}</span></td>'
            f'<td>{html.escape(rec.get("version", ""))}</td>'
            f'<td>{note}{findings}</td>'
            f'<td>{shot}</td>'
            '</tr>')
    return ('<!doctype html><html lang="en"><head><meta charset="utf-8">'
            '<meta name="viewport" content="width=device-width, initial-scale=1"><title>Compat Lab report</title>'
            f'<style>{BADGE_CSS}</style></head><body>'
            f'<h1>Compat Lab report</h1><p class="muted">{html.escape(doc.get("started", ""))} · '
            f'device {html.escape(str(doc.get("device", "")))} · {html.escape(summary)}</p>'
            '<table><thead><tr><th>App</th><th>Category</th><th>ABI</th><th>Verdict</th><th>Version</th>'
            '<th>Notes</th><th>Screenshot</th></tr></thead><tbody>'
            + ''.join(rows) + '</tbody></table></body></html>\n')


def cmd_report(args):
    results = pathlib.Path(args.results)
    doc = load_results(results)
    base = results.parent
    html_path = pathlib.Path(args.html) if args.html else base / 'report.html'
    json_path = pathlib.Path(args.json) if args.json else base / 'report.json'
    summary = {'schema': SCHEMA, 'source': str(results), 'counts': count(doc['apps']), 'apps': doc['apps']}
    json_path.write_text(json.dumps(summary, indent=2) + '\n', encoding='utf-8')
    html_path.write_text(render_html(doc, base, html_path.parent), encoding='utf-8')
    print(f'json: {json_path}')
    print(f'html: {html_path}')
    return 0


# ---------- compare ----------

def compare_apps(base_apps, new_apps):
    """Return (regressions, improvements) as (package, old, new) rows."""
    old = {a['package']: a for a in base_apps}
    new = {a['package']: a for a in new_apps}
    regressions, improvements = [], []
    for pkg, before in old.items():
        after = new.get(pkg)
        if after is None:
            if before['verdict'] != 'skipped':
                regressions.append((pkg, before['verdict'], 'missing'))
            continue
        if before['verdict'] != 'skipped' and after['verdict'] == 'skipped':
            regressions.append((pkg, before['verdict'], 'skipped'))
        elif RANK[after['verdict']] > RANK[before['verdict']]:
            regressions.append((pkg, before['verdict'], after['verdict']))
        elif RANK[after['verdict']] < RANK[before['verdict']]:
            improvements.append((pkg, before['verdict'], after['verdict']))
    for pkg, after in new.items():
        if pkg not in old and RANK[after['verdict']] > 0:
            regressions.append((pkg, 'new', after['verdict']))
    return regressions, improvements


def cmd_compare(args):
    base, new = load_results(args.base), load_results(args.new)
    regressions, improvements = compare_apps(base['apps'], new['apps'])
    for pkg, old, now in improvements:
        print(f'improved    {pkg}: {old} -> {now}')
    for pkg, old, now in regressions:
        print(f'REGRESSION  {pkg}: {old} -> {now}')
    print(f'{len(regressions)} regression(s), {len(improvements)} improvement(s)')
    return 1 if regressions else 0


# ---------- CLI ----------

def build_parser():
    p = argparse.ArgumentParser(prog='lab.py', description='Compat Lab skeleton: Android app smoke tests (moonshot 13.1).')
    sub = p.add_subparsers(dest='command', required=True)

    f = sub.add_parser('fetch', help='download and sha256-verify APKs into the cache')
    f.add_argument('--apps', default=str(APPS))
    f.add_argument('--cache', help='cache folder (default $XDG_CACHE_HOME/compat-lab)')
    f.add_argument('--only', nargs='*', default=[], metavar='PKG')
    f.add_argument('--refresh-index', action='store_true', help='download the F-Droid index again')
    f.set_defaults(func=cmd_fetch)

    r = sub.add_parser('run', help='install, launch and smoke-test the apps')
    r.add_argument('--apps', default=str(APPS))
    r.add_argument('--device', choices=('waydroid', 'fake'), required=True)
    r.add_argument('--fixture', default=str(FIXTURE), help='outcomes for --device fake')
    r.add_argument('--serial', default='', help='adb serial for --device waydroid (required with it)')
    r.add_argument('--installer', choices=('waydroid', 'adb'), default='waydroid')
    r.add_argument('--cache', help='cache folder (default $XDG_CACHE_HOME/compat-lab)')
    r.add_argument('--out', help='run folder (default: a timestamped folder in the cache)')
    r.add_argument('--only', nargs='*', default=[], metavar='PKG')
    r.add_argument('--seed', type=int, default=MONKEY_SEED, help='fixed monkey seed')
    r.add_argument('--settle-scale', type=float, default=1.0, help='scale settle waits; 0 for fast fake runs')
    r.add_argument('--containers', type=int, default=1,
                   help='future: one Waydroid container per worker; runs serially now')
    r.set_defaults(func=cmd_run)

    rp = sub.add_parser('report', help='write report.json and report.html from a run')
    rp.add_argument('results', help='results.json from a run')
    rp.add_argument('--html')
    rp.add_argument('--json')
    rp.set_defaults(func=cmd_report)

    c = sub.add_parser('compare', help='exit 1 when NEW has regressions against BASE')
    c.add_argument('base')
    c.add_argument('new')
    c.set_defaults(func=cmd_compare)
    return p


def main(argv=None):
    args = build_parser().parse_args(argv)
    try:
        return args.func(args)
    except LabError as error:
        print(f'lab: {error}', file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
