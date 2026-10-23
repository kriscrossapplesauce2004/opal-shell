"""Desktop actions for the Opal assistant: apps, windows, URLs, files, screen capture, clipboard and shortcuts. Pure helpers with injectable runners."""
import configparser, os, pathlib, re, shutil, subprocess, tempfile, time, urllib.parse
import hypr_actions

OPEN_SCHEMES = ('http', 'https', 'mailto')
SENSITIVE_MIMES = ('passwordmanagerhint', 'keepass', 'sensitive', 'secret')
MOD_MAP = {'alt': 'ALT', 'ctrl': 'CTRL', 'control': 'CTRL', 'shift': 'SHIFT', 'super': 'SUPER', 'meta': 'SUPER', 'win': 'SUPER'}


def desktop_dirs(env=None):
    env = os.environ if env is None else env
    home = env.get('XDG_DATA_HOME') or str(pathlib.Path(env.get('HOME', '~')).expanduser() / '.local/share')
    dirs = [home] + (env.get('XDG_DATA_DIRS') or '/usr/local/share:/usr/share').split(':')
    return [pathlib.Path(d) / 'applications' for d in dirs if d]

def installed_apps(dirs=None):
    """Return visible desktop applications as dictionaries with id, name and path."""
    seen, apps = set(), []
    for directory in dirs if dirs is not None else desktop_dirs():
        try: files = sorted(directory.glob('*.desktop'))
        except OSError: continue
        for path in files:
            if path.name in seen: continue
            parser = configparser.ConfigParser(interpolation=None, strict=False)
            parser.optionxform = str
            try: parser.read(path, encoding='utf-8')
            except (configparser.Error, OSError, UnicodeDecodeError): continue
            entry = parser['Desktop Entry'] if parser.has_section('Desktop Entry') else None
            if not entry or entry.get('Type', 'Application') != 'Application' or not entry.get('Name'): continue
            seen.add(path.name)
            if entry.get('NoDisplay', '').lower() == 'true' or entry.get('Hidden', '').lower() == 'true': continue
            apps.append({'id': path.name, 'name': entry['Name'], 'generic': entry.get('GenericName', ''), 'path': str(path)})
    return apps

def find_app(query, apps):
    """Pick the best application for a name. Raise ValueError when nothing or several equal matches fit."""
    needle = str(query or '').strip().casefold()
    if not needle: raise ValueError('Give an app name')
    scored = []
    for app in apps:
        name, ident, generic = app['name'].casefold(), app['id'].casefold().removesuffix('.desktop'), app.get('generic', '').casefold()
        score = 100 if needle in (name, ident) else 80 if name.startswith(needle) else 60 if needle in name else 40 if needle in ident else 20 if needle in generic else 0
        if score: scored.append((score, app))
    if not scored: raise ValueError('No app matches "%s"' % query)
    scored.sort(key=lambda item: (-item[0], item[1]['name'].casefold()))
    top = [a for s, a in scored if s == scored[0][0]]
    if len(top) > 1 and scored[0][0] < 100: raise ValueError('Several apps match "%s": %s' % (query, ', '.join(a['name'] for a in top[:6])))
    return top[0]

def launch_app(query, apps=None, popen=subprocess.Popen, which=shutil.which):
    app = find_app(query, installed_apps() if apps is None else apps)
    command = ['gtk-launch', app['id']] if which('gtk-launch') else ['gio', 'launch', app['path']]
    popen(command, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    return 'Launched ' + app['name']

def open_target(target, popen=subprocess.Popen):
    """Open a web URL, mail link or existing file with the default app."""
    text = str(target or '').strip()
    if not text or len(text) > 2048 or '\0' in text: raise ValueError('Give a URL or file path')
    scheme = urllib.parse.urlparse(text).scheme.lower()
    if scheme in OPEN_SCHEMES: value = text
    elif scheme in ('', 'file'):
        path = pathlib.Path(urllib.parse.unquote(urllib.parse.urlparse(text).path) if scheme == 'file' else text).expanduser()
        if not path.exists(): raise ValueError('That file does not exist')
        value = str(path.resolve())
    else: raise ValueError('Only web links, mail links and files can be opened')
    popen(['xdg-open', value], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    return 'Opened ' + value

def windows(actions=None):
    """Return the open windows as short dictionaries."""
    actions = actions or hypr_actions.HyprActions()
    try: clients = actions.clients()
    except (OSError, ValueError, subprocess.SubprocessError) as error: raise RuntimeError('Hyprland is not available: %s' % error)
    return [{'address': c.get('address', ''), 'app': c.get('class', ''), 'title': c.get('title', ''), 'workspace': (c.get('workspace') or {}).get('id', 0)} for c in clients]

def resolve_window(query, items):
    """Find one window by address or by part of its app name or title."""
    needle = str(query or '').strip().casefold()
    if not needle: raise ValueError('Give a window address, app or title')
    exact = [w for w in items if w['address'].casefold() == needle]
    matches = exact or [w for w in items if needle in w['app'].casefold() or needle in w['title'].casefold()]
    if not matches: raise ValueError('No window matches "%s"' % query)
    if len(matches) > 1: raise ValueError('Several windows match "%s": %s' % (query, '; '.join('%s "%s" (%s)' % (w['app'], w['title'][:40], w['address']) for w in matches[:6])))
    return matches[0]

def focus_window(query, actions=None):
    actions = actions or hypr_actions.HyprActions()
    target = resolve_window(query, windows(actions)); actions.focus(target['address'])
    return 'Focused %s "%s"' % (target['app'], target['title'])

def close_window(query, actions=None):
    actions = actions or hypr_actions.HyprActions()
    target = resolve_window(query, windows(actions)); actions.close(target['address'])
    return 'Closed %s "%s"' % (target['app'], target['title'])

def move_window(query, workspace, follow=False, actions=None):
    actions = actions or hypr_actions.HyprActions()
    target = resolve_window(query, windows(actions)); actions.move(target['address'], workspace, follow)
    return 'Moved %s to workspace %d' % (target['app'], workspace)

def switch_workspace(number, actions=None):
    (actions or hypr_actions.HyprActions()).workspace(number)
    return 'Workspace %d' % number

def capture_screen(mode='active', window='', actions=None, run=subprocess.run, runtime_dir=None):
    """Capture the active window, a named window or the full screen with grim. Return the PNG path."""
    folder = pathlib.Path(runtime_dir or os.environ.get('XDG_RUNTIME_DIR') or tempfile.gettempdir()) / 'opal-captures'
    folder.mkdir(parents=True, exist_ok=True)
    dest = folder / ('capture-%d.png' % int(time.time() * 1000))
    cmd = ['grim']
    if mode in ('active', 'window'):
        actions = actions or hypr_actions.HyprActions()
        try:
            clients = actions.clients()
            target = None
            if window:
                info = resolve_window(window, [{'address': c.get('address', ''), 'app': c.get('class', ''), 'title': c.get('title', ''), 'workspace': (c.get('workspace') or {}).get('id', 0)} for c in clients])
                target = next((c for c in clients if c.get('address') == info['address']), None)
            else:
                focused = [c for c in clients if c.get('focusHistoryID') == 0]
                target = focused[0] if focused else (clients[0] if clients else None)
            if target:
                at, size = target.get('at') or [0, 0], target.get('size') or [0, 0]
                if len(at) == 2 and len(size) == 2 and int(size[0]) > 0 and int(size[1]) > 0:
                    cmd += ['-g', '%d,%d %dx%d' % (int(at[0]), int(at[1]), int(size[0]), int(size[1]))]
        except (OSError, ValueError, RuntimeError, subprocess.SubprocessError):
            if mode == 'window' and window: raise
    cmd.append(str(dest))
    result = run(cmd, capture_output=True, text=True, timeout=5)
    if getattr(result, 'returncode', 0) != 0:
        raise RuntimeError((getattr(result, 'stderr', '') or 'Screen capture failed').strip())
    return str(dest)

def clipboard_get(primary=False, run=subprocess.run):
    """Read text from the Wayland clipboard, refusing password-manager secrets."""
    if not primary:
        try:
            mimes = run(['wl-paste', '--list-types'], capture_output=True, text=True, timeout=1.5)
            if getattr(mimes, 'returncode', 0) == 0 and any(h in (mimes.stdout or '').lower() for h in SENSITIVE_MIMES):
                raise ValueError('Clipboard contains sensitive password data')
        except (OSError, subprocess.SubprocessError) as error:
            raise RuntimeError('Clipboard unavailable: %s' % error)
    cmd = ['wl-paste', '--no-newline', '--type', 'text'] + (['--primary'] if primary else [])
    result = run(cmd, capture_output=True, text=True, timeout=1.5)
    if getattr(result, 'returncode', 0) != 0: return ''
    return (result.stdout or '')[:4000]

def clipboard_set(text, run=subprocess.run):
    """Copy plain text to the Wayland clipboard."""
    value = str(text or '')
    if not value or len(value) > 65536: raise ValueError('Give non-empty text up to 64 KB')
    result = run(['wl-copy', '--', value], input='', capture_output=True, text=True, timeout=2)
    if getattr(result, 'returncode', 0) != 0:
        raise RuntimeError((getattr(result, 'stderr', '') or 'Failed to set clipboard').strip())
    return 'Copied %d characters' % len(value)

def parse_shortcut(shortcut):
    """Parse 'Alt+Left', 'Ctrl+Shift+T' or 'Escape' into (mods_string, key_name)."""
    parts = [p.strip() for p in str(shortcut or '').replace('-', '+').split('+') if p.strip()]
    if not parts: raise ValueError('Give a shortcut like "Alt+Left" or "Escape"')
    mods, key = [], parts[-1]
    for p in parts[:-1]:
        mapped = MOD_MAP.get(p.lower())
        if not mapped: raise ValueError('Unknown modifier "%s"' % p)
        if mapped not in mods: mods.append(mapped)
    if not re.fullmatch(r'[A-Za-z0-9_]{1,32}', key): raise ValueError('Invalid key "%s"' % key)
    return ' '.join(mods), key

def send_shortcut(shortcut, window='', actions=None):
    """Send a keyboard shortcut to the focused or matched window."""
    actions = actions or hypr_actions.HyprActions()
    mods, key = parse_shortcut(shortcut)
    address = ''
    if window:
        address = resolve_window(window, windows(actions))['address']
    actions.send_shortcut(mods, key, address)
    return 'Sent %s%s' % (shortcut, (' to ' + window) if window else '')

