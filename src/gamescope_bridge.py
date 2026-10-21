"""Opal as the gamescope shell, the way Steam's gamepad UI is: window roles, app focus, frame limit and screenshots through gamescope's X11 atoms.

Gamescope (run with -e) shows one base-layer app at a time, picked from GAMESCOPECTRL_BASELAYER_APPID, and composites overlay windows above it.
Opal's home is app 769, the id Steam's own UI uses. Every other window gets an app id from its process (Steam's SteamAppId, or Opal's OPAL_APPID),
or a stable id of its own. A window that already has STEAM_GAME keeps it.
"""
import os
import pathlib
import shutil
import threading
import time
import zlib

HOME_APPID = 769
HOME_TITLE = 'opal-home'
OVERLAY_TITLE = 'opal-overlay'
# Ids Opal invents for windows without a Steam app id: high, so they never meet a real Steam app.
OWN_BASE = 0x7f000000


def appid_from_environ(data):
    """The app id in one process environment (bytes, NUL separated), or 0."""
    for entry in data.split(b'\0'):
        for key in (b'OPAL_APPID=', b'SteamAppId=', b'SteamGameId='):
            if entry.startswith(key):
                value = entry[len(key):]
                if value.isdigit() and 0 < int(value) < 1 << 32 and int(value) != HOME_APPID: return int(value)
    return 0


def appid_for_pid(pid, proc='/proc'):
    """Walk up from a window's process to the first ancestor that carries an app id."""
    for _ in range(12):
        if pid <= 1: return 0
        try: found = appid_from_environ(pathlib.Path(proc, str(pid), 'environ').read_bytes())
        except OSError: found = 0
        if found: return found
        try: pid = int(pathlib.Path(proc, str(pid), 'stat').read_text().rsplit(')', 1)[1].split()[1])
        except (OSError, ValueError, IndexError): return 0
    return 0


def own_appid(window_class, pid):
    """A stable id for a window with no app id: from its class, else its process."""
    seed = (window_class or ('pid:%d' % pid)).lower().encode()
    return OWN_BASE + (zlib.crc32(seed) & 0x00ffffff)


def role(title):
    """Opal's own windows say what they are in their title."""
    if title == HOME_TITLE: return 'home'
    if title == OVERLAY_TITLE: return 'overlay'
    return 'app'


def baselayer(focused):
    """The base-layer list: the focused app first, then the home under it."""
    return [focused, HOME_APPID] if focused and focused != HOME_APPID else [HOME_APPID]


class Bridge:
    """Watches gamescope's X display and carries out Opal's focus, overlay, frame-limit and screenshot requests."""
    def __init__(self, emit, display_name=None):
        from Xlib import X, Xatom, display
        self.X, self.Xatom = X, Xatom
        # One connection carries requests (under the lock); a second one only reads events, so neither thread blocks the other.
        self.display = display.Display(display_name)
        self.root = self.display.screen().root
        self.events = display.Display(display_name)
        self.event_root = self.events.screen().root
        self.emit = emit
        self.lock = threading.RLock()
        self.apps = {}
        self.overlay = None
        self.focused = HOME_APPID
        self.event_root.change_attributes(event_mask=X.SubstructureNotifyMask | X.PropertyChangeMask)
        self.events.flush()
        self.screenshots = 0

    def atom(self, name):
        return self.display.intern_atom(name)

    def cardinals(self, window, name):
        try:
            prop = window.get_full_property(self.atom(name), self.Xatom.CARDINAL)
            return list(prop.value) if prop else []
        except Exception:
            return []

    def set_cardinals(self, window, name, values):
        window.change_property(self.atom(name), self.Xatom.CARDINAL, 32, values)

    def describe(self, window):
        try:
            attrs = window.get_attributes()
            if attrs.map_state != self.X.IsViewable or attrs.override_redirect: return None
            title = window.get_wm_name() or ''
            if isinstance(title, bytes): title = title.decode(errors='replace')
            cls = window.get_wm_class() or ('', '')
            pid = (self.cardinals(window, '_NET_WM_PID') or [0])[0]
            return {'title': title, 'class': cls[1] or cls[0], 'pid': pid}
        except Exception:
            return None

    def tag(self, window):
        """Give one top-level window its role and app id."""
        info = self.describe(window)
        if not info: return
        kind = role(info['title'])
        if kind == 'home':
            self.set_cardinals(window, 'STEAM_GAME', [HOME_APPID])
            return
        if kind == 'overlay':
            self.overlay = window
            self.set_cardinals(window, 'STEAM_GAME', [HOME_APPID])
            self.set_cardinals(window, 'STEAM_OVERLAY', [1])
            self.set_cardinals(window, '_NET_WM_WINDOW_OPACITY', [0xffffffff])
            return
        appid = (self.cardinals(window, 'STEAM_GAME') or [0])[0]
        if not appid:
            appid = appid_for_pid(info['pid']) or own_appid(info['class'], info['pid'])
            self.set_cardinals(window, 'STEAM_GAME', [appid])
        app = self.apps.setdefault(appid, {'windows': [], 'title': info['title'], 'class': info['class'], 'pid': info['pid']})
        if window.id not in app['windows']: app['windows'].append(window.id)
        if info['title']: app['title'] = info['title']

    def scan(self):
        with self.lock:
            before = set(self.apps)
            self.apps = {}
            for child in self.root.query_tree().children: self.tag(child)
            self.display.flush()
            # A new app comes to the front, as a launch does under Steam. When the app in front goes away, the home comes back.
            new = [a for a in self.apps if a not in before]
            if new: self.focus(new[-1])
            elif self.focused != HOME_APPID and self.focused not in self.apps: self.home()
        self.publish()

    def windows(self):
        """Apps as Opal window entries, so the shell's window code works unchanged."""
        out = []
        for appid, app in self.apps.items():
            out.append({'address': 'gamescope:%d' % appid, 'appid': appid, 'className': app['class'], 'title': app['title'],
                        'pid': app['pid'], 'workspace': 1, 'focused': appid == self.focused})
        return out

    def publish(self):
        # The app whose picture is on screen. Input focus moves to the overlay while it is open, so FOCUSED_APP would say home.
        with self.lock:
            focused = (self.cardinals(self.root, 'GAMESCOPE_FOCUSED_APP_GFX') or self.cardinals(self.root, 'GAMESCOPE_FOCUSED_APP') or [HOME_APPID])[0]
        self.focused = focused
        app = self.apps.get(focused)
        self.emit({'event': 'compositor', 'data': {'hypr': False, 'gamescope': True, 'windows': self.windows(),
                                                    'gamescopeFocused': focused, 'homeShown': focused == HOME_APPID or not app,
                                                    'title': app['title'] if app else 'Home'}})

    # Requests from the shell.
    def focus(self, appid):
        with self.lock:
            self.set_cardinals(self.root, 'GAMESCOPECTRL_BASELAYER_APPID', baselayer(int(appid)))
            self.display.flush()

    def home(self):
        self.focus(HOME_APPID)

    def overlay_input(self, on):
        """While Quick Access is open the overlay takes keyboard and pointer input, as Steam's overlay does."""
        with self.lock:
            if self.overlay is not None:
                self.set_cardinals(self.overlay, 'STEAM_INPUT_FOCUS', [1 if on else 0])
                self.display.flush()

    def fps_limit(self, fps):
        with self.lock:
            self.set_cardinals(self.root, 'GAMESCOPE_FPS_LIMIT', [max(0, int(fps))])
            self.display.flush()

    def close(self, appid):
        app = self.apps.get(int(appid))
        if not app: return
        with self.lock:
            for wid in app['windows']:
                window = self.display.create_resource_object('window', wid)
                try:
                    from Xlib.protocol import event
                    message = event.ClientMessage(window=window, client_type=self.atom('WM_PROTOCOLS'),
                                                  data=(32, [self.atom('WM_DELETE_WINDOW'), self.X.CurrentTime, 0, 0, 0]))
                    window.send_event(message)
                except Exception:
                    continue
            self.display.flush()

    def screenshot(self, folder=None):
        """Ask gamescope for a composited screenshot and move it into Pictures. Returns the saved path or ''."""
        source = pathlib.Path('/tmp/gamescope.png')
        try: before = source.stat().st_mtime
        except OSError: before = 0
        # Gamescope acts when the request value changes, so each request uses a new value.
        with self.lock:
            self.screenshots = self.screenshots % 1000 + 1
            self.set_cardinals(self.root, 'GAMESCOPECTRL_REQUEST_SCREENSHOT', [self.screenshots])
            self.display.flush()
        for _ in range(30):
            time.sleep(.1)
            try:
                if source.stat().st_mtime > before: break
            except OSError: continue
        else:
            return ''
        time.sleep(.2)
        target_dir = pathlib.Path(folder or pathlib.Path.home() / 'Pictures/Screenshots')
        target_dir.mkdir(parents=True, exist_ok=True)
        target = target_dir / time.strftime('Opal_%Y-%m-%d_%H-%M-%S.png')
        shutil.move(str(source), target)
        return str(target)

    def run(self):
        self.scan()
        X = self.X
        watched = {self.events.intern_atom(n) for n in ('GAMESCOPE_FOCUSED_APP', 'GAMESCOPE_FOCUSED_APP_GFX', 'GAMESCOPE_FOCUSABLE_APPS')}
        while True:
            event = self.events.next_event()
            if event.type in (X.MapNotify, X.UnmapNotify, X.DestroyNotify):
                self.scan()
            elif event.type == X.PropertyNotify and event.atom in watched:
                self.publish()


def active():
    """True inside an Opal gamescope session."""
    return os.environ.get('OPAL_COMPOSITOR') == 'gamescope'
