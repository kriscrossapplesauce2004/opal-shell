"""User half of the Opal Waydroid installer: checks, plan, one pkexec run of waydroid_root.py, first boot and Play certification."""
import json, os, pathlib, platform, shutil, subprocess, sys, threading, time

HERE = pathlib.Path(__file__).resolve().parent
ROOT_HELPER = HERE / 'waydroid_root.py'
MANAGERS = ('pacman', 'apt', 'dnf', 'zypper', 'apk')
MANAGER_BIN = {'pacman': 'pacman', 'apt': 'apt-get', 'dnf': 'dnf', 'zypper': 'zypper', 'apk': 'apk'}
TITLES = {
    'package': 'Install Waydroid', 'binder': 'Turn on Android support in the kernel', 'firewall': 'Let Android reach the network',
    'init': 'Download Android', 'service': 'Start the Android container', 'arm': 'Add ARM app support',
    'boot': 'Start Android for the first time', 'configure': 'Fit Android to Opal',
    'reset': 'Remove Android data', 'remove': 'Uninstall Waydroid', 'androidid': 'Read the Android ID',
}
ROOT_STAGES = ('package', 'binder', 'firewall', 'init', 'service', 'arm', 'reset', 'remove')
USER_STAGES = ('boot', 'configure')
IMAGE_SIZE = {'VANILLA': 830 * 1024 ** 2, 'GAPPS': 1100 * 1024 ** 2}
NEED_FREE = 4 * 1024 ** 3
CERTIFY_URL = 'https://www.google.com/android/uncertified'


def package_manager(which=shutil.which):
    for name in MANAGERS:
        if which(MANAGER_BIN[name]):
            return name
    return ''


def binder_state(read=None, exists=os.path.exists, run=subprocess.run):
    """Return 'ready' when the kernel has binder, 'module' when a module can add it, or 'missing'."""
    try:
        text = read('/proc/filesystems') if read else pathlib.Path('/proc/filesystems').read_text()
        if 'binder' in text:
            return 'ready'
    except OSError:
        pass
    if exists('/dev/binder') or exists('/dev/anbox-binder'):
        return 'ready'
    try:
        if run(['modinfo', 'binder_linux'], capture_output=True, timeout=4).returncode == 0:
            return 'module'
    except (OSError, subprocess.SubprocessError):
        pass
    return 'missing'


def firewall_state(run=subprocess.run, which=shutil.which):
    try:
        if which('firewall-cmd') and run(['systemctl', 'is-active', '--quiet', 'firewalld'], timeout=4).returncode == 0:
            return 'firewalld'
    except (OSError, subprocess.SubprocessError):
        pass
    # ufw status needs root. An enabled ufw unit is a good enough hint.
    try:
        if which('ufw') and run(['systemctl', 'is-active', '--quiet', 'ufw'], timeout=4).returncode == 0:
            return 'ufw'
    except (OSError, subprocess.SubprocessError):
        pass
    return ''


def package_available(manager, run=subprocess.run):
    """Ask the package manager whether it knows the waydroid package. None means it could not tell."""
    queries = {'pacman': ['pacman', '-Si', 'waydroid'], 'apt': ['apt-cache', 'show', 'waydroid'], 'dnf': ['dnf', '-q', 'info', 'waydroid'],
               'zypper': ['zypper', '--non-interactive', 'info', 'waydroid'], 'apk': ['apk', 'info', 'waydroid']}
    if manager not in queries:
        return None
    try:
        res = run(queries[manager], capture_output=True, text=True, timeout=12, env=dict(os.environ, LC_ALL='C'))
    except (OSError, subprocess.SubprocessError):
        return None
    if manager == 'zypper':
        return res.returncode == 0 and 'not found' not in (res.stdout or '').lower()
    return res.returncode == 0 and bool((res.stdout or '').strip())


def cpu_vendor(read=None):
    try:
        text = read('/proc/cpuinfo') if read else pathlib.Path('/proc/cpuinfo').read_text()
    except OSError:
        return ''
    return 'intel' if 'GenuineIntel' in text else 'amd' if 'AuthenticAMD' in text else ''


def plan(checks, options):
    """Stage list for an install. Options: image VANILLA|GAPPS, arm bool, reinstall bool."""
    stages = []
    if not checks.get('installed'):
        stages.append('package')
    if checks.get('binder') != 'ready':
        stages.append('binder')
    if checks.get('firewall'):
        stages.append('firewall')
    if not checks.get('initialized') or options.get('reinstall'):
        stages.append('init')
    if not checks.get('serviceActive') or 'init' in stages:
        stages.append('service')
    if options.get('arm') and checks.get('arch') in ('x86_64', 'amd64'):
        stages.append('arm')
    stages += ['boot', 'configure']
    return stages


class Installer:
    def __init__(self, emit, bridge, run=subprocess.run, popen=subprocess.Popen, which=shutil.which, home=None, sleep=time.sleep):
        self.emit = emit
        self.bridge = bridge
        self.run = run
        self.popen = popen
        self.which = which
        self.home = pathlib.Path(home or pathlib.Path.home())
        self.sleep = sleep
        self.lock = threading.Lock()
        self.proc = None
        self.cancel_requested = False
        self.state = {'phase': 'idle', 'checks': {}, 'stages': [], 'log': [], 'error': '', 'androidId': '', 'image': 'VANILLA', 'arm': False, 'busy': False}

    # ---------- state ----------
    def publish(self, **changes):
        self.state.update(changes)
        self.emit({'event': 'waydroidSetup', 'data': self.state})

    def log(self, text):
        lines = self.state['log'] + [str(text)[:400]]
        self.state['log'] = lines[-240:]

    def stage(self, sid, **fields):
        stages = []
        for s in self.state['stages']:
            stages.append(dict(s, **fields) if s['id'] == sid else s)
        self.state['stages'] = stages

    def activity(self, title, subtitle, progress=-2, icon='android', ttl=0):
        payload = {'id': 'waydroid-setup', 'kind': 'transfer', 'icon': icon, 'title': title, 'subtitle': subtitle, 'progress': progress}
        if ttl:
            payload['ttl'] = ttl
        self.emit({'event': 'activity', 'op': 'start', 'data': payload})

    def activity_end(self):
        self.emit({'event': 'activity', 'op': 'end', 'id': 'waydroid-setup'})

    # ---------- checks ----------
    def service_active(self):
        if not self.which('systemctl'):
            return False
        try:
            return self.run(['systemctl', 'is-active', '--quiet', 'waydroid-container.service'], timeout=4).returncode == 0
        except (OSError, subprocess.SubprocessError):
            return False

    def free_space(self):
        for path in ('/var/lib', '/'):
            try:
                return shutil.disk_usage(path).free
            except OSError:
                continue
        return 0

    def check(self):
        manager = package_manager(self.which)
        installed = bool(self.which('waydroid'))
        checks = {
            'arch': platform.machine(),
            'cpu': cpu_vendor(),
            'wayland': bool(os.environ.get('WAYLAND_DISPLAY')),
            'binder': binder_state(),
            'firewall': firewall_state(self.run, self.which),
            'manager': manager,
            'installed': installed,
            'available': True if installed else package_available(manager, self.run),
            'initialized': installed and self.bridge.initialized(),
            'serviceActive': installed and self.service_active(),
            'free': self.free_space(),
            'need': NEED_FREE,
            'pkexec': bool(self.which('pkexec')),
        }
        checks['session'] = self.bridge.status().get('session', 'stopped') if installed else 'stopped'
        problems = []
        if checks['arch'] not in ('x86_64', 'amd64', 'aarch64', 'arm64'):
            problems.append('Waydroid images exist for x86_64 and arm64 only')
        if checks['binder'] == 'missing':
            problems.append('This kernel has no binder support. Use a kernel with ANDROID_BINDER_IPC, such as linux-zen or a CachyOS kernel')
        if not checks['wayland']:
            problems.append('Waydroid needs a Wayland session')
        if not installed and not manager:
            problems.append('No supported package manager was found')
        if not installed and checks['available'] is False:
            problems.append('Your package manager has no waydroid package. Add the Waydroid repository from docs.waydro.id first')
        if not checks['pkexec']:
            problems.append('pkexec (polkit) is needed to install system parts')
        if not checks['initialized'] and checks['free'] and checks['free'] < NEED_FREE:
            problems.append('Free at least 4 GB on the system disk for the Android images')
        checks['problems'] = problems
        checks['ready'] = installed and checks['initialized'] and checks['serviceActive']
        return checks

    def refresh(self):
        if self.state['busy']:
            self.publish()
            return
        self.publish(phase='checking', error='')
        checks = self.check()
        phase = 'installed' if checks['ready'] else 'ready'
        self.publish(phase=phase, checks=checks)

    # ---------- root helper ----------
    def helper_command(self, stages, image='VANILLA', force=False):
        args = [self.which('pkexec') or 'pkexec', sys.executable or '/usr/bin/python3', '-I', str(ROOT_HELPER), '--stages', ','.join(stages)]
        manager = self.state['checks'].get('manager') or package_manager(self.which)
        if manager:
            args += ['--pm', manager]
        args += ['--image', image]
        if force:
            args.append('--force')
        return args

    def run_root(self, stages, image='VANILLA', force=False):
        """Run the root stages in one pkexec call. Return True when every stage finished."""
        if not stages:
            return True
        try:
            self.proc = self.popen(self.helper_command(stages, image, force), stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT, text=True, bufsize=1)
        except OSError as error:
            self.publish(error=f'Could not start pkexec: {error}')
            return False
        failed = ''
        started = False
        last_publish = 0.0
        for raw in self.proc.stdout:
            line = raw.strip()
            if not line:
                continue
            try:
                msg = json.loads(line)
            except ValueError:
                # pkexec writes its own errors as plain text.
                self.log(line)
                continue
            if not isinstance(msg, dict):
                continue
            if msg.get('error'):
                self.log(msg['error'])
                failed = failed or 'helper'
                continue
            sid = msg.get('stage')
            if sid not in TITLES:
                continue
            started = True
            if 'log' in msg:
                self.log(msg['log'])
            if msg.get('state'):
                st = msg['state']
                self.stage(sid, state=st, progress=1 if st == 'done' else -1)
                if st == 'failed':
                    failed = sid
                if st == 'running':
                    self.activity('Setting up Android', TITLES[sid])
            if 'progress' in msg:
                fields = {'progress': msg['progress']}
                for k in ('done', 'total', 'speed', 'part'):
                    if k in msg:
                        fields[k] = msg[k]
                self.stage(sid, **fields)
                if msg['progress'] >= 0:
                    self.activity('Downloading Android' if sid == 'init' else 'Setting up Android', TITLES[sid], progress=msg['progress'])
            if 'detail' in msg:
                self.stage(sid, detail=msg['detail'])
            if 'androidId' in msg:
                self.state['androidId'] = msg['androidId']
            now = time.monotonic()
            if msg.get('state') or now - last_publish > .25:
                self.publish()
                last_publish = now
        code = self.proc.wait()
        self.proc = None
        if self.cancel_requested:
            return False
        if code in (126, 127) and not started:
            self.publish(error='The password prompt was cancelled')
            return False
        if code or failed:
            title = TITLES.get(failed, 'Setup')
            tail = next((l for l in reversed(self.state['log']) if l.strip()), '')
            self.publish(error=f'{title} failed' + (f': {tail}' if tail else ''))
            return False
        return True

    # ---------- user stages ----------
    def boot(self, light):
        self.stage('boot', state='running', progress=-1, detail='The first start takes a minute')
        self.activity('Setting up Android', 'Starting Android for the first time')
        self.publish()
        ok = self.bridge.ensure_session(label='Android', light=light, max_polls=240)
        self.stage('boot', state='done' if ok else 'failed', progress=1 if ok else -1)
        if not ok:
            self.publish(error='Android did not start. Open Details for the log, or try Restart Android in Settings')
        return ok

    def configure(self, prefs):
        self.stage('configure', state='running', progress=-1)
        self.publish()
        mode = prefs.get('mode', 'desktop')
        self.bridge.set_prop('multiWindows', mode != 'phone')
        self.bridge.set_prop('cursor', True)
        if prefs.get('waydroidSyncTheme') is not False:
            self.bridge.sync_theme(bool(prefs.get('light')))
        self.stage('configure', state='done', progress=1)
        return True

    # ---------- flows ----------
    def install(self, options, prefs):
        if not self.lock.acquire(False):
            return False
        try:
            self.cancel_requested = False
            image = 'GAPPS' if options.get('image') == 'GAPPS' else 'VANILLA'
            arm = options.get('arm') is True
            checks = self.check()
            if checks['problems'] and not (checks['installed'] and checks['initialized']):
                self.publish(phase='ready', checks=checks, error=checks['problems'][0])
                return False
            stages = plan(checks, {'image': image, 'arm': arm, 'reinstall': options.get('reinstall') is True})
            self.state['log'] = []
            self.publish(phase='running', busy=True, checks=checks, image=image, arm=arm, error='', androidId='',
                         stages=[{'id': s, 'title': TITLES[s], 'state': 'waiting', 'progress': -1, 'detail': ''} for s in stages])
            root = [s for s in stages if s in ROOT_STAGES]
            if root and not self.run_root(root, image, force=options.get('reinstall') is True):
                self.finish(False)
                return False
            if 'boot' in stages and not self.boot(bool(prefs.get('light'))):
                self.finish(False)
                return False
            if 'configure' in stages:
                self.configure(prefs)
            self.finish(True)
            return True
        finally:
            self.lock.release()

    def finish(self, ok):
        self.proc = None
        if self.cancel_requested:
            self.activity_end()
            self.publish(phase='ready', busy=False, error='Setup was cancelled', checks=self.check())
            return
        if ok:
            self.activity('Android is ready', 'Open Android apps from Start', progress=1, icon='check_circle', ttl=6)
            self.publish(phase='done', busy=False, checks=self.check())
            self.bridge.publish_status(refresh_props=True)
        else:
            self.activity_end()
            self.publish(phase='failed', busy=False)

    def cancel(self):
        self.cancel_requested = True
        proc = self.proc
        if proc and proc.poll() is None:
            try:
                proc.stdin.write('cancel\n')
                proc.stdin.flush()
            except (OSError, ValueError):
                pass

    def android_id(self):
        if not self.lock.acquire(False):
            return False
        try:
            self.publish(busy=True, error='')
            stages = [{'id': 'androidid', 'title': TITLES['androidid'], 'state': 'waiting', 'progress': -1, 'detail': ''}]
            saved = self.state['stages']
            self.state['stages'] = stages
            ok = self.run_root(['androidid'])
            self.state['stages'] = saved
            if not ok and not self.state['error']:
                self.state['error'] = 'Google services are not ready yet. Open the Play Store once, wait a minute, then try again'
            self.publish(busy=False)
            return ok
        finally:
            self.lock.release()

    def remove(self, uninstall, prefs):
        """Stop Android, delete its images and data, and optionally uninstall the package."""
        if not self.lock.acquire(False):
            return False
        try:
            self.cancel_requested = False
            stages = ['reset'] + (['remove'] if uninstall else [])
            self.state['log'] = []
            self.publish(phase='removing', busy=True, error='', stages=[{'id': s, 'title': TITLES[s], 'state': 'waiting', 'progress': -1, 'detail': ''} for s in stages])
            if self.which('waydroid'):
                try:
                    self.run(['waydroid', 'session', 'stop'], capture_output=True, timeout=10)
                except (OSError, subprocess.SubprocessError):
                    pass
            ok = self.run_root(stages, 'VANILLA')
            if ok:
                self.clean_user_data()
            self.publish(phase='ready' if ok else 'failed', busy=False, checks=self.check())
            self.bridge.publish_status()
            return ok
        finally:
            self.lock.release()

    def clean_user_data(self):
        apps = self.home / '.local/share/applications'
        try:
            for entry in apps.glob('waydroid.*.desktop'):
                entry.unlink()
        except OSError:
            pass
        data = self.home / '.local/share/waydroid'
        if data.is_dir() and not data.is_symlink():
            shutil.rmtree(data, ignore_errors=True)

    def handle(self, c, prefs):
        action = c.get('action')
        if action == 'waydroid-setup-check':
            self.refresh()
        elif action == 'waydroid-setup-install':
            self.install({'image': c.get('image'), 'arm': c.get('arm'), 'reinstall': c.get('reinstall')}, prefs)
        elif action == 'waydroid-setup-cancel':
            self.cancel()
        elif action == 'waydroid-setup-android-id':
            self.android_id()
        elif action == 'waydroid-setup-remove':
            self.remove(c.get('uninstall') is True, prefs)
        elif action == 'waydroid-setup-certify':
            self.popen(['xdg-open', CERTIFY_URL], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        else:
            return False
        return True
