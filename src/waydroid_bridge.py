"""First-class Waydroid integration for Opal: session lifecycle, cold-boot Live Activities, theme/DPI sync, APK install, per-app window framing and Android key events."""
import configparser, os, pathlib, re, shutil, subprocess, threading, time
import hypr_actions
from android_shell import AndroidShell

PACKAGE_RE = re.compile(r'^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$')
PROP_KEYS = {
    'multiWindows': 'persist.waydroid.multi_windows',
    'suspend': 'persist.waydroid.suspend',
    'cursor': 'persist.waydroid.cursor_on_subsurface',
    'uevent': 'persist.waydroid.uevent',
}
ASPECT_PRESETS = {
    'phone': (412, 915),
    'tablet': (1180, 820),
    'freeform': (0, 0),
}

def is_waydroid_id(value):
    """Return the validated Android package name if value is 'waydroid.<pkg>' or 'waydroid.<pkg>.desktop'."""
    text = str(value or '').strip()
    if text.lower().endswith('.desktop'):
        text = text[:-8]
    if text.startswith('waydroid.'):
        pkg = text[9:]
        if PACKAGE_RE.fullmatch(pkg):
            return pkg
    return ''

def valid_package(value):
    return isinstance(value, str) and bool(PACKAGE_RE.fullmatch(value.strip()))

def valid_preference(key, value):
    if key in ('waydroidSyncTheme', 'waydroidAutoPosture', 'waydroidBadge'):
        return type(value) is bool
    if key == 'waydroidAspects':
        return (isinstance(value, dict) and len(value) <= 256 and
                all(valid_package(k) and v in ASPECT_PRESETS for k, v in value.items()))
    return False

def parse_status_text(text):
    """Parse 'waydroid status' stdout into a normalized dictionary."""
    info = {'session': 'stopped', 'container': 'stopped', 'ip': '', 'display': ''}
    for raw in str(text or '').splitlines():
        if ':' not in raw:
            continue
        k, v = [part.strip() for part in raw.split(':', 1)]
        kl, vl = k.lower(), v.lower()
        if kl == 'session':
            info['session'] = 'running' if 'running' in vl else 'stopped'
        elif kl == 'container':
            info['container'] = 'running' if 'running' in vl else ('frozen' if 'frozen' in vl else 'stopped')
        elif kl == 'ip address' and vl not in ('unknown', 'none', ''):
            info['ip'] = v
        elif kl == 'wayland display' and vl not in ('unknown', 'none', ''):
            info['display'] = v
    return info

def discover_android_apps(home=None):
    """List Waydroid desktop entries from ~/.local/share/applications."""
    base = pathlib.Path(home or pathlib.Path.home()) / '.local/share/applications'
    apps = []
    try:
        files = sorted(base.glob('waydroid.*.desktop'))
    except OSError:
        return apps
    for path in files:
        pkg = is_waydroid_id(path.name)
        if not pkg:
            continue
        parser = configparser.ConfigParser(interpolation=None, strict=False)
        parser.optionxform = str
        try:
            parser.read(path, encoding='utf-8')
        except (configparser.Error, OSError, UnicodeDecodeError):
            continue
        if not parser.has_section('Desktop Entry'):
            continue
        entry = parser['Desktop Entry']
        if entry.get('NoDisplay', '').lower() == 'true':
            continue
        apps.append({
            'id': path.name,
            'package': pkg,
            'name': entry.get('Name', pkg),
            'icon': entry.get('Icon', ''),
            'path': str(path),
        })
    return apps


class WaydroidBridge:
    def __init__(self, emit, run=subprocess.run, popen=subprocess.Popen, which=shutil.which, home=None, actions=None, sleep=time.sleep):
        self.emit = emit
        self.run = run
        self.popen = popen
        self.which = which
        self.home = pathlib.Path(home or pathlib.Path.home())
        self.actions = actions
        self.sleep = sleep
        self.lock = threading.Lock()
        self.props_cache = {'multiWindows': True, 'suspend': False, 'cursor': True}
        # Commands inside Android go over ADB; "waydroid shell" needs root.
        self.ip = ('', 0.0)
        self.adb = AndroidShell(self.container_ip, run=run, which=which)

    def container_ip(self):
        """The container's address from the last status, read again when it is older than ten seconds."""
        ip, when = self.ip
        if time.monotonic() - when > 10:
            self.status()
            ip = self.ip[0]
        return ip

    def installed(self):
        return bool(self.which('waydroid'))

    def initialized(self):
        if not self.installed():
            return False
        for candidate in (pathlib.Path('/var/lib/waydroid/waydroid.cfg'),
                          pathlib.Path('/var/lib/waydroid/images/system.img'),
                          self.home / '.local/share/waydroid/data'):
            try:
                if candidate.exists():
                    return True
            except OSError:
                continue
        return False

    def shared_folder(self):
        media = self.home / '.local/share/waydroid/data/media/0'
        return str(media) if media.exists() else str(self.home / '.local/share/waydroid')

    def read_prop(self, key):
        prop = PROP_KEYS.get(key)
        if not prop or not self.installed():
            return self.props_cache.get(key, False)
        try:
            res = self.run(['waydroid', 'prop', 'get', prop], capture_output=True, text=True, timeout=1.5)
            val = (res.stdout or '').strip().lower()
            if val in ('true', '1', 'yes'):
                self.props_cache[key] = True
            elif val in ('false', '0', 'no'):
                self.props_cache[key] = False
        except (OSError, subprocess.SubprocessError):
            pass
        return self.props_cache.get(key, False)

    def status(self, refresh_props=False):
        installed = self.installed()
        apps = discover_android_apps(self.home)
        if not installed:
            return {
                'installed': False, 'initialized': False, 'session': 'stopped', 'container': 'stopped',
                'ip': '', 'multiWindows': False, 'suspend': False, 'cursor': False,
                'appCount': len(apps), 'sharedFolder': self.shared_folder(),
            }
        parsed = {'session': 'stopped', 'container': 'stopped', 'ip': '', 'display': ''}
        try:
            res = self.run(['waydroid', 'status'], capture_output=True, text=True, timeout=2.0)
            parsed = parse_status_text(res.stdout)
        except (OSError, subprocess.SubprocessError):
            pass
        self.ip = (parsed['ip'] if parsed['session'] == 'running' else '', time.monotonic())
        if refresh_props and parsed['session'] == 'running':
            for k in ('multiWindows', 'suspend', 'cursor'):
                self.read_prop(k)
        return {
            'installed': True,
            'initialized': self.initialized(),
            'session': parsed['session'],
            'container': parsed['container'],
            'ip': parsed['ip'],
            'multiWindows': self.props_cache.get('multiWindows', True),
            'suspend': self.props_cache.get('suspend', False),
            'cursor': self.props_cache.get('cursor', True),
            'appCount': len(apps),
            'sharedFolder': self.shared_folder(),
            'adb': self.adb.available(),
        }

    def publish_status(self, refresh_props=False):
        state = self.status(refresh_props=refresh_props)
        self.emit({'event': 'waydroidStatus', 'data': state})
        return state

    def activity_start(self, act_id, title, subtitle, kind='system', icon='smartphone', progress=-2, ttl=0):
        payload = {'id': act_id, 'kind': kind, 'icon': icon, 'title': title, 'subtitle': subtitle, 'progress': progress}
        if ttl > 0:
            payload['ttl'] = ttl
        self.emit({'event': 'activity', 'op': 'start', 'data': payload})

    def activity_end(self, act_id):
        self.emit({'event': 'activity', 'op': 'end', 'id': act_id})

    def ensure_session(self, label='Android', light=False, max_polls=36):
        """Ensure the Waydroid session is running, showing a Live Activity during cold boot."""
        state = self.status()
        if not state['installed']:
            self.emit({'event': 'message', 'text': 'Waydroid is not installed'})
            return False
        if state['session'] == 'running':
            return True
        self.activity_start('waydroid-boot', 'Starting Android', f'Launching {label}…', kind='system', icon='smartphone', progress=-2)
        try:
            self.popen(['waydroid', 'session', 'start'], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        except OSError as error:
            self.activity_end('waydroid-boot')
            self.emit({'event': 'message', 'text': f'Could not start Waydroid: {error}'})
            return False
        for step in range(max_polls):
            self.sleep(0.5)
            state = self.status()
            if state['session'] == 'running':
                self.sync_theme(light)
                self.publish_status(refresh_props=True)
                self.activity_start('waydroid-boot', 'Android ready', f'Opening {label}', kind='system', icon='smartphone', progress=1, ttl=3)
                return True
        self.activity_end('waydroid-boot')
        self.publish_status()
        self.emit({'event': 'message', 'text': 'Waydroid session timed out while starting'})
        return False

    def launch_app(self, package, name='', light=False, aspect='freeform'):
        pkg = is_waydroid_id(package) or (package.strip() if valid_package(package) else '')
        if not pkg:
            self.emit({'event': 'message', 'text': 'Invalid Android package name'})
            return False
        label = str(name or pkg).strip()[:80]
        if not self.ensure_session(label=label, light=light):
            return False
        try:
            self.popen(['waydroid', 'app', 'launch', pkg], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        except OSError as error:
            self.emit({'event': 'message', 'text': f'Failed to launch {label}: {error}'})
            return False
        if aspect in ('phone', 'tablet'):
            threading.Thread(target=self.wait_and_frame_window, args=(pkg, aspect), daemon=True).start()
        return True

    def wait_and_frame_window(self, package, preset, polls=20):
        """Wait for 'waydroid.<package>' to map in Hyprland and apply its aspect preset."""
        for _ in range(polls):
            if self.apply_window_aspect(package, preset):
                return True
            self.sleep(0.35)
        return False

    def apply_window_aspect(self, package, preset, actions=None):
        """Resize and center a mapped Waydroid window to Phone (412x915), Tablet (1180x820), or Freeform."""
        pkg = is_waydroid_id(package) or (package.strip() if valid_package(package) else '')
        if not pkg or preset not in ASPECT_PRESETS:
            return False
        act = actions or self.actions or hypr_actions.HyprActions()
        try:
            clients = act.clients()
            monitors = act.monitors()
        except (OSError, ValueError, subprocess.SubprocessError):
            return False
        target_class = f'waydroid.{pkg}'.lower()
        matches = [c for c in clients if str(c.get('class') or '').lower() == target_class]
        if not matches:
            return False
        win = matches[0]
        address = win.get('address', '')
        if not address:
            return False
        if preset == 'freeform':
            return True
        req_w, req_h = ASPECT_PRESETS[preset]
        mon = monitors[0] if monitors else {'x': 0, 'y': 0, 'width': 1920, 'height': 1080}
        mx, my = int(mon.get('x', 0)), int(mon.get('y', 0))
        mw, mh = int(mon.get('width', 1920)), int(mon.get('height', 1080))
        scale = min(1.0, (mw - 64) / max(1, req_w), (mh - 96) / max(1, req_h))
        w, h = max(320, int(req_w * scale)), max(480, int(req_h * scale))
        x, y = mx + (mw - w) // 2, my + max(32, (mh - h) // 2)
        try:
            if not win.get('floating'):
                act.set_floating(address, True)
            act.geometry(address, x, y, w, h)
            return True
        except (OSError, ValueError, subprocess.SubprocessError):
            return False

    def session_control(self, verb, light=False):
        if not self.installed():
            self.emit({'event': 'message', 'text': 'Waydroid is not installed'})
            return False
        if verb == 'start':
            return self.ensure_session(label='Android session', light=light)
        if verb == 'stop':
            self.run(['waydroid', 'session', 'stop'], capture_output=True, text=True, timeout=8)
            self.activity_end('waydroid-boot')
            self.publish_status()
            self.emit({'event': 'message', 'text': 'Android session stopped'})
            return True
        if verb == 'restart':
            self.run(['waydroid', 'session', 'stop'], capture_output=True, text=True, timeout=8)
            self.sleep(0.5)
            return self.ensure_session(label='Android session', light=light)
        if verb == 'full-ui':
            if not self.ensure_session(label='Android home', light=light):
                return False
            self.popen(['waydroid', 'show-full-ui'], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
            return True
        return False

    def set_prop(self, key, enabled):
        prop = PROP_KEYS.get(key)
        if not prop or not self.installed():
            return False
        val = 'true' if enabled else 'false'
        try:
            res = self.run(['waydroid', 'prop', 'set', prop, val], capture_output=True, text=True, timeout=4)
            if getattr(res, 'returncode', 0) == 0:
                self.props_cache[key] = bool(enabled)
                self.publish_status()
                return True
        except (OSError, subprocess.SubprocessError):
            pass
        return False

    def sync_theme(self, light, dpi=0):
        """Sync Opal's dark/light mode and optional DPI density into the running Android container."""
        if not self.installed():
            return False
        night = 'no' if light else 'yes'
        ok = self.adb.ok(['cmd', 'uimode', 'night', night])
        if ok and isinstance(dpi, int) and 120 <= dpi <= 640:
            self.adb.ok(['wm', 'density', str(dpi)])
        return ok

    def sync_posture(self, layout_mode):
        """In phone layout, disable multi_windows so Android apps fill the screen; on desktop/tablet enable freeform windows."""
        if not self.installed():
            return False
        multi = layout_mode != 'phone'
        return self.set_prop('multiWindows', multi)

    def force_stop(self, package):
        pkg = is_waydroid_id(package) or (package.strip() if valid_package(package) else '')
        if not pkg or not self.installed():
            return False
        if self.adb.ok(['am', 'force-stop', pkg]):
            self.emit({'event': 'message', 'text': f'Force-stopped {pkg}'})
            return True
        self.emit({'event': 'message', 'text': 'Android did not answer. Install android-tools (adb) so Opal can reach it'})
        return False

    def open_app_info(self, package, light=False):
        pkg = is_waydroid_id(package) or (package.strip() if valid_package(package) else '')
        if not pkg or not self.ensure_session(label='App settings', light=light):
            return False
        return self.adb.ok(['am', 'start', '-a', 'android.settings.APPLICATION_DETAILS_SETTINGS', '-d', f'package:{pkg}'])

    def install_apk(self, raw_path, light=False):
        text = str(raw_path or '').strip()
        if text.startswith('file://'):
            text = text[7:]
        path = pathlib.Path(text).expanduser()
        if not path.is_file() or path.suffix.lower() != '.apk':
            self.emit({'event': 'message', 'text': 'Choose a valid .apk file'})
            return False
        if not self.ensure_session(label=path.name, light=light):
            return False
        self.activity_start('waydroid-apk', 'Installing Android app', path.name, kind='transfer', icon='install_mobile', progress=-2)
        try:
            res = self.run(['waydroid', 'app', 'install', str(path.resolve())], capture_output=True, text=True, timeout=120)
            ok = getattr(res, 'returncode', 0) == 0
        except (OSError, subprocess.SubprocessError):
            ok = False
        if ok:
            self.activity_start('waydroid-apk', 'Android app installed', path.stem, kind='transfer', icon='check_circle', progress=1, ttl=5)
            self.emit({'event': 'message', 'text': f'Installed {path.name}'})
            self.publish_status()
            return True
        self.activity_end('waydroid-apk')
        self.emit({'event': 'message', 'text': f'Failed to install {path.name}'})
        return False

    def uninstall_app(self, package):
        pkg = is_waydroid_id(package) or (package.strip() if valid_package(package) else '')
        if not pkg or not self.installed():
            return False
        try:
            res = self.run(['waydroid', 'app', 'remove', pkg], capture_output=True, text=True, timeout=30)
            if getattr(res, 'returncode', 0) == 0:
                self.emit({'event': 'message', 'text': f'Uninstalled {pkg}'})
                self.publish_status()
                return True
        except (OSError, subprocess.SubprocessError):
            pass
        self.emit({'event': 'message', 'text': f'Could not uninstall {pkg}'})
        return False

    def send_back(self):
        """Send Android KEYCODE_BACK (4) to the container."""
        if not self.installed():
            return False
        return self.adb.ok(['input', 'keyevent', '4'], timeout=2)

    def handle(self, c, prefs=None):
        prefs = prefs or {}
        light = bool(prefs.get('light'))
        action = c.get('action', '')
        if action == 'waydroid-status':
            self.publish_status(refresh_props=bool(c.get('refresh')))
            return True
        if action == 'waydroid-session' and c.get('verb') in ('start', 'stop', 'restart', 'full-ui'):
            self.session_control(c['verb'], light=light)
            return True
        if action == 'waydroid-launch':
            pkg = is_waydroid_id(c.get('package')) or str(c.get('package') or '')
            aspects = prefs.get('waydroidAspects') if isinstance(prefs.get('waydroidAspects'), dict) else {}
            aspect = c.get('aspect') if c.get('aspect') in ASPECT_PRESETS else aspects.get(pkg, 'freeform')
            self.launch_app(pkg, name=str(c.get('name') or ''), light=light, aspect=aspect)
            return True
        if action == 'waydroid-prop' and c.get('key') in PROP_KEYS:
            self.set_prop(c['key'], bool(c.get('value')))
            return True
        if action == 'waydroid-force-stop':
            self.force_stop(c.get('package'))
            return True
        if action == 'waydroid-app-info':
            self.open_app_info(c.get('package'), light=light)
            return True
        if action == 'waydroid-install-apk':
            self.install_apk(c.get('path'), light=light)
            return True
        if action == 'waydroid-uninstall':
            self.uninstall_app(c.get('package'))
            return True
        if action == 'waydroid-aspect' and c.get('aspect') in ASPECT_PRESETS:
            self.apply_window_aspect(c.get('package'), c['aspect'])
            return True
        if action == 'waydroid-back':
            self.send_back()
            return True
        return False
