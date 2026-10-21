"""Power key menu backend: the logind inhibitor, key edges, the menu's key grab, device toggles, contacts and fast user switching."""
import ctypes, json, os, pathlib, re, shutil, signal, sqlite3, subprocess, threading, time, urllib.parse

HOME = pathlib.Path.home()
SUBMAP = 'opal-power'
# Wake presses that land this soon after resume only woke the device.
RESUME_GRACE = 1.5
# Catalogue ids the menu may hold. Kept in step with PowerKey.qml.
ACTIONS = ('sleep', 'power', 'lock', 'switch-user', 'displays', 'contacts', 'media', 'flashlight', 'rotation-lock', 'airplane', 'dnd',
           'hotspot', 'keep-awake', 'screenshot', 'record', 'camera', 'assistant', 'search', 'notifications', 'quick-settings', 'clipboard',
           'game-mode', 'app', 'command', 'link', 'folder')
LINK_SCHEMES = ('http', 'https', 'mailto', 'tel', 'sms', 'geo', 'file')
# Physical key places by device-tree compatible: edge and centre along that edge, 0 at the top.
LAYOUTS = {
    'oneplus,guacamoleb': {'power': {'edge': 'right', 'at': .3}, 'volume': {'edge': 'left', 'at': .26}},
    'oneplus,guacamole': {'power': {'edge': 'right', 'at': .3}, 'volume': {'edge': 'left', 'at': .26}},
    'oneplus,hotdogb': {'power': {'edge': 'right', 'at': .3}, 'volume': {'edge': 'left', 'at': .26}},
    'oneplus,enchilada': {'power': {'edge': 'right', 'at': .32}, 'volume': {'edge': 'left', 'at': .26}},
    'oneplus,fajita': {'power': {'edge': 'right', 'at': .32}, 'volume': {'edge': 'left', 'at': .26}},
    'google,sargo': {'power': {'edge': 'right', 'at': .3}, 'volume': {'edge': 'right', 'at': .46}},
    'pine64,pinephone': {'power': {'edge': 'right', 'at': .38}, 'volume': {'edge': 'right', 'at': .22}},
    'pine64,pinephone-pro': {'power': {'edge': 'right', 'at': .38}, 'volume': {'edge': 'right', 'at': .22}},
    'purism,librem5': {'power': {'edge': 'right', 'at': .3}, 'volume': {'edge': 'right', 'at': .45}},
}
GENERIC_LAYOUT = {'power': {'edge': 'right', 'at': .32}, 'volume': {'edge': 'right', 'at': .48}}
CAMERAS = ('org.gnome.Snapshot', 'org.postmarketos.Megapixels', 'megapixels', 'org.kde.kamoso', 'org.gnome.Cheese')
CONTACT_APPS = ('org.gnome.Contacts', 'org.kde.kpeoplevcard', 'org.kde.kaddressbook')


def _node_ok(node, depth=0):
    if not isinstance(node, dict) or depth > 3 or len(node) > 8: return False
    action = node.get('action')
    if action not in ACTIONS: return False
    for key in ('label', 'icon'):
        if key in node and not (isinstance(node[key], str) and 0 < len(node[key]) <= 64): return False
    if action == 'app' and not (isinstance(node.get('app'), str) and 0 < len(node['app']) <= 300): return False
    if action == 'command' and not (isinstance(node.get('command'), str) and 0 < len(node['command']) <= 1000): return False
    if action == 'link' and not valid_url(node.get('url')): return False
    if action == 'folder':
        items = node.get('items')
        if not isinstance(items, list) or len(items) > 32 or not all(_node_ok(i, depth + 1) for i in items): return False
        if not isinstance(node.get('label'), str): return False
    return True


def valid_url(url):
    if not isinstance(url, str) or not 0 < len(url) <= 2000: return False
    return urllib.parse.urlparse(url).scheme.lower() in LINK_SCHEMES


def valid_preference(key, value):
    if key == 'powerMenu':
        return isinstance(value, list) and len(value) <= 32 and all(_node_ok(n) for n in value)
    if key == 'powerMenuStart': return value in ACTIONS
    if key == 'powerMenuCountdown': return type(value) is int and value in (0, 1000, 2000, 3000)
    if key == 'powerPress':
        return isinstance(value, dict) and set(value) <= {'double', 'hold', 'chord'} and all(v is None or _node_ok(v) for v in value.values())
    if key == 'powerContacts':
        return isinstance(value, list) and len(value) <= 24 and all(isinstance(v, str) and 0 < len(v) <= 300 for v in value) and len(set(value)) == len(value)
    if key == 'powerKey': return value in ('auto', 'on', 'off')
    if key == 'powerKeyLayout':
        return value is None or isinstance(value, dict) and set(value) == {'power', 'volume'} and all(
            isinstance(k, dict) and k.get('edge') in ('left', 'right') and type(k.get('at')) in (int, float) and 0 <= k['at'] <= 1 for k in value.values())
    return False


def walk(nodes):
    """Every stored node, folders included, depth first."""
    for node in nodes or []:
        if isinstance(node, dict):
            yield node
            yield from walk(node.get('items'))


def stored_nodes(prefs):
    presses = prefs.get('powerPress') or {}
    return list(walk(prefs.get('powerMenu'))) + list(walk([v for v in presses.values() if v]))


# ---------- Device ----------
def _read(path):
    try: return pathlib.Path(path).read_bytes().decode('utf-8', 'replace').strip('\0\n ')
    except OSError: return ''


def chassis(runner=subprocess.run):
    """handset, tablet, laptop, desktop, ... from the device tree, systemd or DMI."""
    dt = _read('/sys/firmware/devicetree/base/chassis-type')
    if dt: return dt
    try:
        out = runner(['hostnamectl', 'chassis'], capture_output=True, text=True, timeout=3).stdout.strip()
        if out: return out
    except (OSError, subprocess.SubprocessError): pass
    dmi = _read('/sys/class/dmi/id/chassis_type')
    return {'30': 'tablet', '31': 'convertible', '32': 'tablet', '8': 'handset', '9': 'laptop', '10': 'laptop', '3': 'desktop'}.get(dmi, '')


def layout(prefs, compatible=None):
    custom = prefs.get('powerKeyLayout')
    if custom and valid_preference('powerKeyLayout', custom): return custom
    names = compatible if compatible is not None else _read('/sys/firmware/devicetree/base/compatible').split('\0')
    return next((LAYOUTS[n] for n in names if n in LAYOUTS), GENERIC_LAYOUT)


# ---------- Contacts ----------
def _unfold(text):
    return re.sub(r'\r?\n[ \t]', '', text)


def parse_vcards(text, source=''):
    cards = []
    for block in re.findall(r'BEGIN:VCARD(.*?)END:VCARD', _unfold(text), re.S | re.I):
        card = {'uid': '', 'name': '', 'phones': [], 'emails': [], 'favourite': False, 'avatar': ''}
        for line in block.splitlines():
            if ':' not in line: continue
            head, value = line.split(':', 1)
            name = head.split(';', 1)[0].split('.')[-1].upper()
            value = value.strip().replace('\\,', ',').replace('\\;', ';')
            if name == 'FN': card['name'] = value
            elif name == 'N' and not card['name']: card['name'] = ' '.join(p for p in reversed(value.split(';')[:2]) if p).strip()
            elif name == 'UID': card['uid'] = value
            elif name == 'TEL' and value: card['phones'].append(value.replace('tel:', ''))
            elif name == 'EMAIL' and value: card['emails'].append(value)
            elif name == 'CATEGORIES' and re.search(r'favou?rite|starred', value, re.I): card['favourite'] = True
            elif name in ('X-STARRED', 'X-FAVORITE', 'X-FAVOURITE') and value.lower() in ('1', 'true', 'yes'): card['favourite'] = True
            elif name == 'PHOTO' and value.startswith('file://'): card['avatar'] = value
        if not card['name']: continue
        if not card['uid']: card['uid'] = source + '#' + card['name']
        card['source'] = source
        cards.append(card)
    return cards


def load_contacts(home=HOME):
    """Contacts from vdir folders (vdirsyncer, khard) and Evolution address books, sorted by name, without duplicates."""
    found = []
    for root in (home / '.local/share/contacts', home / '.contacts', home / '.local/share/vdirsyncer/contacts'):
        if root.is_dir():
            for path in sorted(root.rglob('*.vcf'))[:4000]:
                try: found += parse_vcards(path.read_text(errors='replace'), str(path))
                except OSError: pass
    books = home / '.local/share/evolution/addressbook'
    if books.is_dir():
        for db in books.glob('*/contacts.db'):
            try:
                with sqlite3.connect('file:' + str(db) + '?mode=ro', uri=True, timeout=1) as con:
                    for (vcard,) in con.execute('SELECT vcard FROM folder_id LIMIT 4000'):
                        if vcard: found += parse_vcards(vcard, str(db))
            except sqlite3.Error: pass
    seen, result = set(), []
    for card in sorted(found, key=lambda c: c['name'].lower()):
        if card['uid'] in seen: continue
        seen.add(card['uid']); result.append(card)
    return result


def _pdeathsig():
    # The child dies with the backend, so a crashed Opal never leaves the key inhibited.
    try: ctypes.CDLL('libc.so.6').prctl(1, signal.SIGTERM)
    except OSError: pass


class PowerKey:
    def __init__(self, emit, prefs, hypr, runner=subprocess.run, popen=subprocess.Popen, link_url=None, home=HOME, clock=time.monotonic):
        self.emit, self.prefs, self.hypr, self.runner, self.popen = emit, prefs, hypr, runner, popen
        self.link_url, self.home, self.clock = link_url, home, clock
        self.inhibitor, self.recorder = None, None
        self.resumed_at, self.swallow = -1e9, False
        self.handset = False
        self.contacts, self.last_haptic = [], 0.0
        self.lock = threading.RLock()

    # ---------- Ownership of the key ----------
    def wanted(self):
        choice = self.prefs.get('powerKey', 'auto')
        return choice == 'on' or choice == 'auto' and self.handset

    def start(self):
        self.handset = chassis(self.runner) in ('handset', 'tablet', 'convertible', 'watch')
        self.apply()
        threading.Thread(target=self.watch_sleep, daemon=True).start()

    def apply(self):
        """Hold the logind power key inhibitor exactly while Opal owns the key."""
        with self.lock:
            want = self.wanted()
            alive = self.inhibitor is not None and self.inhibitor.poll() is None
            if want and not alive and shutil.which('systemd-inhibit'):
                try:
                    self.inhibitor = self.popen(['systemd-inhibit', '--what=handle-power-key', '--who=Opal', '--why=Power key menu', '--mode=block', 'sleep', 'infinity'],
                                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, preexec_fn=_pdeathsig)
                except OSError: self.inhibitor = None
            elif not want and alive:
                self.inhibitor.terminate(); self.inhibitor = None
        self.publish()

    def stop(self):
        with self.lock:
            if self.inhibitor is not None and self.inhibitor.poll() is None: self.inhibitor.terminate()
            self.inhibitor = None
        self.grab(False)

    def watch_sleep(self):
        """Note each resume, so the press that woke the device does not open the menu."""
        if not shutil.which('gdbus'): return
        try:
            process = self.popen(['gdbus', 'monitor', '--system', '--dest', 'org.freedesktop.login1', '--object-path', '/org/freedesktop/login1'],
                                 stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, preexec_fn=_pdeathsig)
        except OSError: return
        for line in process.stdout:
            if 'PrepareForSleep (false' in line: self.resumed_at = self.clock()

    # ---------- Key edges ----------
    def screen_off(self):
        try: monitors = json.loads(self.runner(['hyprctl', 'monitors', '-j'], capture_output=True, text=True, timeout=2).stdout or '[]')
        except (OSError, ValueError, subprocess.SubprocessError): return False
        return any(m.get('dpmsStatus') is False for m in monitors)

    def wake(self):
        try:
            if self.hypr.is_lua(): self.runner(['hyprctl', 'eval', 'hl.dispatch(hl.dsp.dpms({action="on"}))'], capture_output=True, timeout=2)
            else: self.runner(['hyprctl', 'dispatch', 'dpms', 'on'], capture_output=True, timeout=2)
        except (OSError, subprocess.SubprocessError): pass

    def edge(self, down):
        """A key edge from Hyprland. A press that only wakes the screen, and its release, never reach the menu."""
        if not self.wanted(): return
        if down:
            off = self.screen_off()
            if off or self.clock() - self.resumed_at < RESUME_GRACE:
                if off: self.wake()
                self.swallow = True
                return
            self.swallow = False
        elif self.swallow:
            self.swallow = False
            return
        self.emit({'event': 'powerKey', 'down': bool(down)})

    def chord(self):
        if self.wanted(): self.emit({'event': 'powerKeyChord'})

    def grab(self, on):
        """While the menu is open an empty submap is active, so the volume and power keys reach the menu surface."""
        try:
            if self.hypr.is_lua(): self.runner(['hyprctl', 'eval', 'hl.dispatch(hl.dsp.submap("' + (SUBMAP if on else 'reset') + '"))'], capture_output=True, timeout=2)
            else: self.runner(['hyprctl', 'dispatch', 'submap', SUBMAP if on else 'reset'], capture_output=True, timeout=2)
        except (OSError, ValueError, subprocess.SubprocessError): pass

    # ---------- Live state ----------
    def _out(self, args):
        try: return self.runner(args, capture_output=True, text=True, timeout=3).stdout or ''
        except (OSError, subprocess.SubprocessError): return ''

    def airplane(self):
        if not shutil.which('rfkill'): return False
        try: devices = json.loads(self._out(['rfkill', '-J']) or '{}').get('rfkilldevices', [])
        except ValueError: return False
        radios = [d for d in devices if d.get('type') in ('wlan', 'bluetooth', 'wwan')]
        return bool(radios) and all(d.get('soft') == 'blocked' for d in radios)

    def hotspot(self):
        if not shutil.which('nmcli'): return False
        return any(line.split(':')[0] == 'Hotspot' for line in self._out(['nmcli', '-t', '-f', 'NAME', 'connection', 'show', '--active']).splitlines())

    def live(self):
        return {'airplane': self.airplane(), 'hotspot': self.hotspot(), 'recording': self.recorder is not None and self.recorder.poll() is None,
                'feedback': bool(shutil.which('fbcli'))}

    def publish(self, contacts=False):
        data = {'event': 'powerKeyState', 'device': {'enabled': self.wanted(), 'handset': self.handset, **layout(self.prefs)}}
        if contacts: data['live'] = self.live(); data['contacts'] = self.contacts
        self.emit(data)

    def refresh(self):
        self.contacts = load_contacts(self.home)
        self.publish(contacts=True)

    # ---------- Actions ----------
    def spawn(self, args):
        try: self.popen(args, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        except OSError: self.emit({'event': 'message', 'text': 'Could not start ' + args[0]})

    def toggle(self, what, on):
        if what == 'airplane' and shutil.which('rfkill'):
            self._out(['rfkill', 'block' if on else 'unblock', 'all'])
            self.emit({'event': 'message', 'text': 'Airplane mode on' if on else 'Airplane mode off'})
        elif what == 'hotspot' and shutil.which('nmcli'):
            if on: result = self._out(['nmcli', 'device', 'wifi', 'hotspot', 'con-name', 'Hotspot', 'ssid', os.uname().nodename + ' Opal'])
            else: result = self._out(['nmcli', 'connection', 'down', 'Hotspot'])
            self.emit({'event': 'message', 'text': ('Hotspot on' if on else 'Hotspot off') if result else 'Hotspot did not change'})
        elif what == 'record':
            if on and shutil.which('wf-recorder') and (self.recorder is None or self.recorder.poll() is not None):
                folder = self.home / 'Videos/Recordings'; folder.mkdir(parents=True, exist_ok=True)
                dest = str(folder / time.strftime('Opal-%Y%m%d-%H%M%S.mp4'))
                try: self.recorder = self.popen(['wf-recorder', '-f', dest], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                except OSError: self.recorder = None
                self.emit({'event': 'message', 'text': 'Recording the screen' if self.recorder else 'Could not start recording'})
            elif not on and self.recorder is not None:
                self.recorder.send_signal(signal.SIGINT); self.recorder = None
                self.emit({'event': 'message', 'text': 'Recording saved to Videos/Recordings'})
        self.publish(contacts=True)

    def haptic(self, kind):
        now = self.clock()
        if now - self.last_haptic < .04 or not shutil.which('fbcli'): return
        self.last_haptic = now
        self.spawn(['fbcli', '-E', 'button-pressed' if kind == 'pick' else 'keyboard-key-pressed'])

    def first_app(self, ids):
        roots = [self.home / '.local/share/applications', pathlib.Path('/usr/share/applications'), pathlib.Path('/var/lib/flatpak/exports/share/applications'),
                 self.home / '.local/share/flatpak/exports/share/applications']
        return next((i for i in ids for r in roots if (r / (i + '.desktop')).exists()), None)

    def camera(self):
        app = self.first_app(CAMERAS)
        if app and shutil.which('gtk-launch'): self.spawn(['gtk-launch', app])
        else: self.emit({'event': 'message', 'text': 'No camera app installed'})

    def run_command(self, command):
        """Only commands the user stored in their menu or presses may run."""
        if any(n.get('action') == 'command' and n.get('command') == command for n in stored_nodes(self.prefs)):
            self.spawn(['sh', '-c', command])

    def open_link(self, url):
        if valid_url(url) and any(n.get('action') == 'link' and n.get('url') == url for n in stored_nodes(self.prefs)):
            self.spawn(['xdg-open', url])

    def contact(self, verb, target):
        if not isinstance(target, str) or not 0 < len(target) <= 300: return
        known = next((c for c in self.contacts if target in c['phones'] or target in c['emails'] or target == c['uid']), None)
        if not known: return
        number = re.sub(r'[^0-9+*#]', '', target)
        if verb in ('call', 'text') and number:
            url = ('tel:' if verb == 'call' else 'sms:') + number
            if self.handset: self.spawn(['xdg-open', url])
            elif self.link_url and self.link_url(url): self.emit({'event': 'message', 'text': ('Calling ' if verb == 'call' else 'Texting ') + known['name'] + ' on your phone'})
            else: self.emit({'event': 'message', 'text': 'Link a phone in Settings to call and text from here'})
        elif verb == 'email' and '@' in target: self.spawn(['xdg-email', target] if shutil.which('xdg-email') else ['xdg-open', 'mailto:' + target])
        elif verb == 'share-shot' and '@' in target and shutil.which('grim'):
            folder = self.home / 'Pictures/Screenshots'; folder.mkdir(parents=True, exist_ok=True)
            dest = str(folder / time.strftime('Opal-%Y%m%d-%H%M%S.png'))
            time.sleep(.4)
            try:
                self.runner(['grim', dest], check=True, timeout=5)
                self.spawn(['xdg-email', '--attach', dest, target])
            except (OSError, subprocess.SubprocessError): self.emit({'event': 'message', 'text': 'Screenshot failed'})
        elif verb == 'copy' and shutil.which('wl-copy'):
            self.spawn(['wl-copy', target]); self.emit({'event': 'message', 'text': 'Number copied'})
        elif verb == 'open-contact':
            app = self.first_app(CONTACT_APPS)
            if app and shutil.which('gtk-launch'): self.spawn(['gtk-launch', app])
            elif known.get('source', '').endswith('.vcf'): self.spawn(['xdg-open', known['source']])

    def output_off(self, name):
        if not isinstance(name, str) or not re.fullmatch(r'[A-Za-z0-9_.:-]{1,64}', name): return
        try:
            if self.hypr.is_lua(): self.runner(['hyprctl', 'eval', 'hl.monitor({output="' + name + '",disabled=true})'], capture_output=True, timeout=2)
            else: self.runner(['hyprctl', 'keyword', 'monitor', name + ',disable'], capture_output=True, timeout=2)
        except (OSError, subprocess.SubprocessError): pass

    def switch_user(self):
        """Start a second greeter on a new VT. This session keeps running, locked, behind it."""
        unit = 'opal-switch-greeter@' + str(int(time.time()) % 100000) + '.service'
        installed = pathlib.Path('/etc/systemd/system/opal-switch-greeter@.service').exists()
        if not installed:
            self.emit({'event': 'message', 'text': 'Fast user switching needs a one-time setup: run sudo opal-fast-user-switch-setup'})
            return False
        try: result = self.runner(['systemctl', 'start', '--no-block', unit], capture_output=True, text=True, timeout=10)
        except (OSError, subprocess.SubprocessError): result = None
        if not result or result.returncode != 0:
            self.emit({'event': 'message', 'text': 'Could not start another login screen'})
            return False
        return True

    # ---------- Commands from the shell ----------
    def handle(self, c):
        action = c.get('action')
        if action == 'powerkey-edge': self.edge(c.get('down') is True)
        elif action == 'powerkey-chord': self.chord()
        elif action == 'powerkey-grab': self.grab(c.get('on') is True)
        elif action == 'powerkey-refresh': threading.Thread(target=self.refresh, daemon=True).start()
        elif action == 'powerkey-haptic': self.haptic(c.get('kind'))
        elif action == 'powerkey-toggle' and c.get('what') in ('airplane', 'hotspot', 'record') and type(c.get('on')) is bool:
            threading.Thread(target=self.toggle, args=(c['what'], c['on']), daemon=True).start()
        elif action == 'powerkey-camera': self.camera()
        elif action == 'powerkey-run' and isinstance(c.get('command'), str): self.run_command(c['command'])
        elif action == 'powerkey-open' and isinstance(c.get('url'), str): self.open_link(c['url'])
        elif action == 'powerkey-contact' and c.get('verb') in ('call', 'text', 'email', 'share-shot', 'copy', 'open-contact'):
            threading.Thread(target=self.contact, args=(c['verb'], c.get('target')), daemon=True).start()
        elif action == 'powerkey-output-off': self.output_off(c.get('name'))
        elif action == 'switch-user': threading.Thread(target=self.switch_user, daemon=True).start()
        else: return False
        return True
