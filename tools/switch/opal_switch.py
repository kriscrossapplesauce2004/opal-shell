#!/usr/bin/env python3
"""Switch to Opal from another desktop: checks this computer, brings the old desktop's look and apps along, installs Opal and adds an Opal login session.

The same engine serves the terminal assistant ("opal-switch") and the window assistant (src/switch.qml), which talks to "opal_switch.py serve" in JSON lines.
"""
import argparse, configparser, json, os, pathlib, platform, re, shutil, subprocess, sys, threading, time, urllib.parse, urllib.request

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parent.parent
ROOT_HELPER = HERE / 'switch_root.py'
HOME = pathlib.Path.home()
CONFIG = pathlib.Path(os.environ.get('XDG_CONFIG_HOME') or HOME / '.config')
STATE = pathlib.Path(os.environ.get('XDG_STATE_HOME') or HOME / '.local/state') / 'opal'
DATA = pathlib.Path(os.environ.get('XDG_DATA_HOME') or HOME / '.local/share')
HYPR_LUA = CONFIG / 'hypr/hyprland.lua'
STOCK_LUA = pathlib.Path('/usr/share/hypr/hyprland.lua')
OPAL_CONFIG = CONFIG / 'quickshell/opal'
SESSION_FILE = pathlib.Path('/usr/share/wayland-sessions/opal.desktop')
MANAGERS = ('pacman', 'dnf', 'zypper', 'apt')
MANAGER_BIN = {'pacman': 'pacman', 'dnf': 'dnf', 'zypper': 'zypper', 'apt': 'apt-get'}
# Opal and its helpers, per package manager. "quickshell" on Fedora comes from a COPR that the root helper enables.
PACKAGES = {
    'pacman': ['hyprland', 'quickshell', 'python', 'wireplumber', 'playerctl', 'networkmanager', 'bluez', 'bluez-utils', 'brightnessctl',
               'power-profiles-daemon', 'grim', 'slurp', 'wl-clipboard', 'libnotify', 'xdg-desktop-portal-hyprland', 'xdg-desktop-portal-gtk',
               'polkit', 'cmake', 'make', 'gcc', 'git'],
    'dnf': ['hyprland', 'quickshell', 'python3', 'wireplumber', 'playerctl', 'NetworkManager', 'bluez', 'brightnessctl', 'power-profiles-daemon',
            'grim', 'slurp', 'wl-clipboard', 'libnotify', 'xdg-desktop-portal-hyprland', 'polkit', 'cmake', 'make', 'gcc-c++', 'git'],
    'zypper': ['hyprland', 'quickshell', 'python3', 'wireplumber', 'playerctl', 'NetworkManager', 'bluez', 'brightnessctl', 'power-profiles-daemon',
               'grim', 'slurp', 'wl-clipboard', 'libnotify-tools', 'xdg-desktop-portal-hyprland', 'polkit', 'cmake', 'make', 'gcc-c++', 'git'],
    'apt': ['hyprland', 'quickshell', 'python3', 'wireplumber', 'playerctl', 'network-manager', 'bluez', 'brightnessctl', 'power-profiles-daemon',
            'grim', 'slurp', 'wl-clipboard', 'libnotify-bin', 'xdg-desktop-portal-hyprland', 'polkitd', 'cmake', 'make', 'g++', 'git'],
}
# Commands that show a package is already there, so the plan only installs what is missing.
PROVIDES = {'hyprland': 'Hyprland', 'quickshell': 'quickshell', 'python': 'python3', 'python3': 'python3', 'wireplumber': 'wpctl', 'playerctl': 'playerctl',
            'networkmanager': 'nmcli', 'NetworkManager': 'nmcli', 'network-manager': 'nmcli', 'bluez': 'bluetoothctl', 'bluez-utils': 'bluetoothctl',
            'brightnessctl': 'brightnessctl', 'power-profiles-daemon': 'powerprofilesctl', 'grim': 'grim', 'slurp': 'slurp', 'wl-clipboard': 'wl-copy',
            'libnotify': 'notify-send', 'libnotify-bin': 'notify-send', 'libnotify-tools': 'notify-send', 'cmake': 'cmake', 'make': 'make',
            'gcc': 'gcc', 'gcc-c++': 'g++', 'g++': 'g++', 'git': 'git', 'polkit': 'pkexec', 'polkitd': 'pkexec'}
PORTALS = {'xdg-desktop-portal-hyprland': '/usr/share/xdg-desktop-portal/portals/hyprland.portal',
           'xdg-desktop-portal-gtk': '/usr/share/xdg-desktop-portal/portals/gtk.portal'}
FONTS = {
    'Material Symbols Rounded': 'https://raw.githubusercontent.com/google/material-design-icons/master/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf',
    'Google Sans Flex': 'https://raw.githubusercontent.com/google/fonts/main/ofl/googlesansflex/GoogleSansFlex%5BROND%2Copsz%2Cslnt%2Cwdth%2Cwght%5D.ttf',
}
# The window assistant loads these from the cache before they are installed: short names, so QML can load them by URL.
FONT_CACHE = pathlib.Path(os.environ.get('XDG_CACHE_HOME') or HOME / '.cache') / 'opal-switch/fonts'
FONT_CACHE_NAMES = {'Material Symbols Rounded': 'symbols.ttf', 'Google Sans Flex': 'sans.ttf'}
TERMINALS = ('kitty', 'ghostty', 'foot', 'alacritty', 'wezterm', 'ptyxis', 'kgx', 'gnome-terminal', 'konsole', 'xfce4-terminal', 'tilix')
FILE_MANAGERS = ('nautilus', 'dolphin', 'thunar', 'nemo', 'pcmanfm-qt', 'pcmanfm')
# Opal's four palettes by hue: Iris (violet), Tide (teal), Peach (orange) and Sky (blue).
GNOME_ACCENTS = {'purple': 0, 'pink': 0, 'teal': 1, 'green': 1, 'orange': 2, 'yellow': 2, 'red': 2, 'blue': 3, 'slate': 3}
TITLES = {
    'packages': 'Install Hyprland, Quickshell and helpers',
    'session': 'Add Opal to the login screen',
    'fonts': 'Get the Opal fonts',
    'hyprland': 'Write a Hyprland setup',
    'opal': 'Install Opal',
    'settings': 'Bring your desktop along',
    'remove-session': 'Remove Opal from the login screen',
    'restore': 'Put your settings back',
}
ROOT_STAGES = ('packages', 'session', 'remove-session')


# ---------- small helpers ----------
def run_text(args, timeout=8, env=None):
    try:
        res = subprocess.run(args, capture_output=True, text=True, timeout=timeout, env=env or dict(os.environ, LC_ALL='C'))
    except (OSError, subprocess.SubprocessError):
        return None
    return res.stdout if res.returncode == 0 else None


def os_release(path='/etc/os-release'):
    info = {}
    try:
        for line in pathlib.Path(path).read_text().splitlines():
            if '=' in line:
                k, v = line.split('=', 1)
                info[k.strip()] = v.strip().strip('"')
    except OSError:
        pass
    return {'id': info.get('ID', ''), 'name': info.get('PRETTY_NAME') or info.get('NAME', 'Linux'), 'like': info.get('ID_LIKE', '').split()}


def package_manager(which=shutil.which):
    return next((m for m in MANAGERS if which(MANAGER_BIN[m])), '')


def package_available(manager, name):
    """True when the repositories know the package, False when they do not, None when the package manager could not tell."""
    queries = {'pacman': ['pacman', '-Si', name], 'dnf': ['dnf', '-q', 'info', name], 'zypper': ['zypper', '--non-interactive', 'info', name], 'apt': ['apt-cache', 'show', name]}
    if manager not in queries:
        return None
    try:
        res = subprocess.run(queries[manager], capture_output=True, text=True, timeout=20, env=dict(os.environ, LC_ALL='C'))
    except (OSError, subprocess.SubprocessError):
        return None
    out = (res.stdout or '').lower()
    return res.returncode == 0 and bool(out.strip()) and 'not found' not in out


def desktop_name(env=os.environ):
    raw = env.get('XDG_CURRENT_DESKTOP') or env.get('DESKTOP_SESSION') or ''
    parts = [p for p in raw.replace(';', ':').split(':') if p]
    names = {'gnome': 'GNOME', 'kde': 'KDE Plasma', 'plasma': 'KDE Plasma', 'xfce': 'Xfce', 'x-cinnamon': 'Cinnamon', 'cinnamon': 'Cinnamon',
             'mate': 'MATE', 'lxqt': 'LXQt', 'budgie': 'Budgie', 'pantheon': 'Pantheon', 'cosmic': 'COSMIC', 'hyprland': 'Hyprland',
             'sway': 'Sway', 'niri': 'niri', 'unity': 'Unity', 'deepin': 'Deepin', 'opal': 'Opal'}
    for p in parts:
        if p.lower() in names:
            return names[p.lower()]
    return parts[0] if parts else ''


def display_manager():
    try:
        target = os.readlink('/etc/systemd/system/display-manager.service')
    except OSError:
        return ''
    name = pathlib.Path(target).stem
    return {'gdm': 'GDM', 'gdm3': 'GDM', 'sddm': 'SDDM', 'lightdm': 'LightDM', 'greetd': 'greetd', 'ly': 'Ly', 'plasmalogin': 'Plasma Login',
            'cosmic-greeter': 'COSMIC Greeter', 'lxdm': 'LXDM'}.get(name, name)


def gpu_info(root='/sys/class/drm'):
    vendors = set()
    try:
        for node in pathlib.Path(root).glob('card*/device/vendor'):
            try:
                vendors.add(node.read_text().strip().lower())
            except OSError:
                pass
    except OSError:
        pass
    modeset = ''
    try:
        modeset = pathlib.Path('/sys/module/nvidia_drm/parameters/modeset').read_text().strip()
    except OSError:
        pass
    return {'nvidia': '0x10de' in vendors, 'other': bool(vendors - {'0x10de'}), 'modeset': modeset == 'Y'}


def hypr_version():
    out = run_text(['Hyprland', '--version']) if shutil.which('Hyprland') else None
    m = re.search(r'Hyprland\s+(\d+\.\d+(?:\.\d+)?)', out or '')
    return m.group(1) if m else ''


def font_installed(family):
    out = run_text(['fc-list', ':', 'family'])
    return out is not None and family.lower() in out.lower()


def first_command(names, which=shutil.which):
    return next((n for n in names if which(n)), '')


# ---------- the old desktop's settings ----------
def gsettings(schema, key):
    out = run_text(['gsettings', 'get', schema, key], timeout=4) if shutil.which('gsettings') else None
    return out.strip() if out else ''


def gvariant_list(text):
    return re.findall(r"'([^']*)'", text or '')


def gvariant_pairs(text):
    return re.findall(r"\('([^']*)',\s*'([^']*)'\)", text or '')


def local_file(uri):
    """A wallpaper path from a file:// URI or a plain path, when the file exists."""
    if not uri:
        return ''
    path = urllib.parse.unquote(uri[7:]) if uri.startswith('file://') else uri
    path = os.path.expanduser(path)
    return path if os.path.isfile(path) else ''


def read_ini(path):
    parser = configparser.ConfigParser(interpolation=None, strict=False)
    parser.optionxform = str
    try:
        parser.read(path, encoding='utf-8')
    except (configparser.Error, OSError, UnicodeDecodeError):
        pass
    return parser


def hue_palette(r, g, b):
    """Nearest Opal palette for an accent colour."""
    mx, mn = max(r, g, b), min(r, g, b)
    if mx == mn:
        return 3
    if mx == r:
        h = (60 * ((g - b) / (mx - mn)) + 360) % 360
    elif mx == g:
        h = 60 * ((b - r) / (mx - mn)) + 120
    else:
        h = 60 * ((r - g) / (mx - mn)) + 240
    if h < 70 or h >= 330:
        return 2 if h < 70 else 0
    if h < 190:
        return 1
    if h < 255:
        return 3
    return 0


def desktop_id(name):
    name = str(name or '').strip()
    if name.startswith('applications:'):
        name = name[13:]
    if name.startswith('file://'):
        name = pathlib.Path(urllib.parse.unquote(name[7:])).name
    if name.endswith('.desktop'):
        name = name[:-8]
    return name if re.fullmatch(r'[A-Za-z0-9._+-]{1,200}', name) else ''


def import_gnome(prefix='org.gnome'):
    found = {}
    bg = 'org.cinnamon.desktop.background' if prefix == 'org.cinnamon' else 'org.gnome.desktop.background'
    scheme = gsettings('org.gnome.desktop.interface', 'color-scheme')
    if scheme:
        found['light'] = 'dark' not in scheme
    uri = gsettings(bg, 'picture-uri-dark' if found.get('light') is False else 'picture-uri').strip("'") or gsettings(bg, 'picture-uri').strip("'")
    found['wallpaper'] = local_file(uri)
    accent = gsettings('org.gnome.desktop.interface', 'accent-color').strip("'")
    if accent in GNOME_ACCENTS:
        found['palette'] = GNOME_ACCENTS[accent]
        found['accent'] = accent
    pins = gvariant_list(gsettings('org.cinnamon' if prefix == 'org.cinnamon' else 'org.gnome.shell', 'favorite-apps'))
    found['pins'] = [p for p in (desktop_id(x) for x in pins) if p]
    layouts = [v.split('+')[0] for k, v in gvariant_pairs(gsettings('org.gnome.desktop.input-sources', 'sources')) if k == 'xkb']
    variants = [v.split('+')[1] if '+' in v else '' for k, v in gvariant_pairs(gsettings('org.gnome.desktop.input-sources', 'sources')) if k == 'xkb']
    if layouts:
        found['keyboard'] = ','.join(layouts)
        if any(variants):
            found['keyboardVariant'] = ','.join(variants)
    natural = gsettings('org.gnome.desktop.peripherals.touchpad', 'natural-scroll')
    if natural in ('true', 'false'):
        found['naturalScroll'] = natural == 'true'
    found['icons'] = gsettings('org.gnome.desktop.interface', 'icon-theme').strip("'")
    found['clock24'] = gsettings('org.gnome.desktop.interface', 'clock-format').strip("'") != '12h'
    return found


def import_kde():
    found = {}
    globals_ = read_ini(CONFIG / 'kdeglobals')
    look = globals_.get('KDE', 'LookAndFeelPackage', fallback='')
    scheme = globals_.get('General', 'ColorScheme', fallback='')
    if look or scheme:
        found['light'] = 'dark' not in (look + scheme).lower()
    accent = globals_.get('General', 'AccentColor', fallback='')
    m = re.fullmatch(r'\s*(\d+),(\d+),(\d+)\s*', accent)
    if m:
        found['palette'] = hue_palette(*(int(x) for x in m.groups()))
        found['accent'] = '#%02x%02x%02x' % tuple(int(x) for x in m.groups())
    found['icons'] = globals_.get('Icons', 'Theme', fallback='')
    try:
        applets = (CONFIG / 'plasma-org.kde.plasma.desktop-appletsrc').read_text(errors='replace')
    except OSError:
        applets = ''
    for uri in re.findall(r'^Image=(.+)$', applets, re.M):
        path = local_file(uri.strip())
        if path:
            found['wallpaper'] = path
            break
    launchers = re.search(r'^launchers=(.+)$', applets, re.M)
    if launchers:
        found['pins'] = [p for p in (desktop_id(x) for x in launchers.group(1).split(',')) if p]
    kxkb = read_ini(CONFIG / 'kxkbrc')
    layouts = kxkb.get('Layout', 'LayoutList', fallback='')
    if layouts:
        found['keyboard'] = layouts
        variants = kxkb.get('Layout', 'VariantList', fallback='')
        if variants.strip(','):
            found['keyboardVariant'] = variants
    inputs = read_ini(CONFIG / 'kcminputrc')
    for section in inputs.sections():
        if section.startswith('Libinput') and inputs.has_option(section, 'NaturalScroll'):
            found['naturalScroll'] = inputs.get(section, 'NaturalScroll').lower() == 'true'
            break
    return found


def import_xfce():
    found = {}
    out = run_text(['xfconf-query', '-c', 'xfce4-desktop', '-l', '-v']) if shutil.which('xfconf-query') else None
    for line in (out or '').splitlines():
        if '/last-image' in line:
            path = local_file(line.split(None, 1)[1].strip() if len(line.split(None, 1)) > 1 else '')
            if path:
                found['wallpaper'] = path
                break
    theme = run_text(['xfconf-query', '-c', 'xsettings', '-p', '/Net/ThemeName']) if shutil.which('xfconf-query') else None
    if theme:
        found['light'] = 'dark' not in theme.lower()
    icons = run_text(['xfconf-query', '-c', 'xsettings', '-p', '/Net/IconThemeName']) if shutil.which('xfconf-query') else None
    if icons:
        found['icons'] = icons.strip()
    return found


def import_desktop(desktop):
    """Read the current desktop's wallpaper, theme, accent, pinned apps, keyboard layouts and scroll direction."""
    if desktop in ('GNOME', 'Budgie', 'Pantheon', 'Unity', 'COSMIC'):
        found = import_gnome()
    elif desktop == 'Cinnamon':
        found = import_gnome('org.cinnamon')
    elif desktop == 'KDE Plasma':
        found = import_kde()
    elif desktop == 'Xfce':
        found = import_xfce()
    else:
        # Unknown desktops: GTK settings are a fair guess for the theme and keyboard.
        found = import_gnome() if shutil.which('gsettings') else {}
    # Pins only count when the app is installed here.
    apps = installed_apps()
    found['pins'] = [p for p in found.get('pins', []) if p in apps][:12]
    return {k: v for k, v in found.items() if v not in ('', None, [])}


def installed_apps():
    ids = set()
    dirs = [DATA / 'applications', pathlib.Path('/usr/share/applications'), pathlib.Path('/usr/local/share/applications'),
            pathlib.Path('/var/lib/flatpak/exports/share/applications'), DATA / 'flatpak/exports/share/applications']
    for d in dirs:
        try:
            ids.update(p.stem for p in d.glob('*.desktop'))
        except OSError:
            pass
    return ids


# ---------- checks and plan ----------
def detect(full=True):
    distro = os_release()
    manager = package_manager()
    desktop = desktop_name()
    gpu = gpu_info()
    have = {name: bool(shutil.which(cmd)) for name, cmd in (('hyprland', 'Hyprland'), ('quickshell', 'quickshell'), ('python', 'python3'),
                                                             ('git', 'git'), ('pkexec', 'pkexec'), ('curl', 'curl'))}
    have['hyprlandLua'] = STOCK_LUA.exists() or HYPR_LUA.exists()
    available = {}
    if full and manager:
        for name in ('hyprland', 'quickshell'):
            available[name] = True if have[name] else package_available(manager, name)
        if manager == 'dnf' and available.get('quickshell') is False:
            # Fedora gets Quickshell from the errornointernet/quickshell COPR, which the root helper turns on.
            available['quickshell'] = 'copr'
    missing = missing_packages(manager)
    fonts = {f: font_installed(f) for f in FONTS}
    found = import_desktop(desktop) if full else {}
    data = {
        'distro': distro, 'manager': manager, 'arch': platform.machine(), 'desktop': desktop,
        'session': os.environ.get('XDG_SESSION_TYPE', ''), 'dm': display_manager(), 'gpu': gpu,
        'have': have, 'available': available, 'missing': missing, 'fonts': fonts,
        'hyprVersion': hypr_version(), 'hyprConfig': HYPR_LUA.exists(),
        'opalInstalled': (OPAL_CONFIG / 'shell.qml').exists(), 'sessionInstalled': SESSION_FILE.exists(),
        'terminal': first_command(TERMINALS), 'files': first_command(FILE_MANAGERS),
        'found': found, 'source': str(REPO), 'free': free_space(),
    }
    data['problems'], data['warnings'] = problems(data)
    return data


def free_space():
    try:
        return shutil.disk_usage(str(HOME)).free
    except OSError:
        return 0


def missing_packages(manager):
    out = []
    for name in PACKAGES.get(manager, []):
        cmd = PROVIDES.get(name)
        if name in PORTALS:
            if not os.path.exists(PORTALS[name]):
                out.append(name)
        elif cmd and not shutil.which(cmd):
            out.append(name)
    return out


def problems(d):
    """Blocking problems, then warnings that do not stop the switch."""
    stop, warn = [], []
    if d['arch'] not in ('x86_64', 'aarch64'):
        warn.append('Opal is tested on x86_64 and arm64 only')
    if not d['manager'] and d['missing']:
        stop.append('No supported package manager was found (pacman, dnf, zypper or apt). Install Hyprland and Quickshell yourself, then run this again')
    if d['manager'] and not d['have']['pkexec'] and d['missing']:
        stop.append('pkexec (polkit) is needed to install packages and the login session')
    if not d['have']['quickshell'] and d['available'].get('quickshell') is False:
        stop.append('Your distribution has no Quickshell package. Build it from quickshell.org, then run this again')
    if not d['have']['hyprland'] and d['available'].get('hyprland') is False:
        stop.append('Your distribution has no Hyprland package. Install Hyprland, then run this again')
    if d['have']['hyprland'] and not d['have']['hyprlandLua']:
        stop.append('Opal needs a Hyprland that reads hyprland.lua. Update Hyprland, then run this again')
    if d['manager'] == 'apt':
        warn.append('Debian and Ubuntu ship an older Hyprland. If it has no Lua config, Opal will not load')
    if d['gpu']['nvidia'] and not d['gpu']['other'] and not d['gpu']['modeset']:
        warn.append('NVIDIA: Hyprland needs the proprietary driver with nvidia-drm.modeset=1 on the kernel command line')
    if not d['dm']:
        warn.append('No login screen was found. Start Opal from a terminal with "opal-session"')
    if d['free'] and d['free'] < 2 * 1024 ** 3:
        warn.append('Less than 2 GB is free in your home folder')
    return stop, warn


def plan(d, options):
    stages = []
    if d['missing']:
        stages.append('packages')
    if not d['sessionInstalled'] or options.get('reinstallSession'):
        stages.append('session')
    if options.get('fonts', True) and not all(d['fonts'].values()):
        stages.append('fonts')
    if not d['hyprConfig']:
        stages.append('hyprland')
    stages.append('opal')
    stages.append('settings')
    return stages


# ---------- user stages ----------
def hyprland_config(d, options, stock=STOCK_LUA):
    """A starter hyprland.lua from Hyprland's own example, with this computer's terminal, file manager, keyboard and touchpad."""
    try:
        text = stock.read_text()
    except OSError:
        text = '-- Opal starter config\nhl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })\n'
    found = d.get('found', {}) if options.get('importKeyboard', True) else {}
    terminal = d.get('terminal') or 'kitty'
    files = d.get('files') or 'nautilus'
    text = re.sub(r'^local terminal\s*=.*$', f'local terminal    = "{terminal}"', text, count=1, flags=re.M)
    text = re.sub(r'^local fileManager\s*=.*$', f'local fileManager = "{files}"', text, count=1, flags=re.M)
    if found.get('keyboard'):
        text = re.sub(r'kb_layout\s*=\s*"[^"]*"', f'kb_layout  = "{lua_text(found["keyboard"])}"', text, count=1)
        if found.get('keyboardVariant'):
            text = re.sub(r'kb_variant\s*=\s*"[^"]*"', f'kb_variant = "{lua_text(found["keyboardVariant"])}"', text, count=1)
    if 'naturalScroll' in found:
        text = re.sub(r'natural_scroll\s*=\s*(true|false)', 'natural_scroll = ' + ('true' if found['naturalScroll'] else 'false'), text, count=1)
    header = ('-- Written by the Opal switch assistant from Hyprland\'s example config.\n'
              '-- Opal adds its own keys and rules below (OPAL_INSTALL_HOOK). Edit the rest freely.\n\n')
    return header + text


def lua_text(value):
    return re.sub(r'[^A-Za-z0-9_,()+-]', '', str(value))[:120]


def settings_changes(d, options, current):
    """Preference changes for the first Opal login. The setup screen still opens there, with these choices already made."""
    found = d.get('found', {})
    out = {}
    if options.get('importLook', True):
        if 'light' in found:
            out['light'] = found['light']
        if 'palette' in found:
            out['palette'] = found['palette']
            out['dynamicColors'] = False
        if found.get('wallpaper'):
            out['wallpaperPath'] = pathlib.Path(found['wallpaper']).as_uri()
    if options.get('importPins', True) and found.get('pins'):
        out['favorites'] = found['pins']
        out['pinsConfigured'] = True
    windows = options.get('windows', 'floating')
    out['floatingMode'] = windows == 'floating'
    if options.get('mode') in ('auto', 'desktop', 'phone', 'console'):
        out['mode'] = options['mode']
    if options.get('ai') is False:
        out['aiFeatures'] = False
    # A first login on Opal shows the setup screen.
    if 'onboarded' not in current:
        out['onboarded'] = False
    return out


class Switch:
    def __init__(self, emit, run=subprocess.run, popen=subprocess.Popen, which=shutil.which, fetch=urllib.request.urlopen):
        self.emit = emit
        self.run = run
        self.popen = popen
        self.which = which
        self.fetch = fetch
        self.proc = None
        self.cancelled = False
        self.lock = threading.Lock()
        self.stages = []
        self.checks = {}

    def stage(self, sid, **fields):
        for s in self.stages:
            if s['id'] == sid:
                s.update(fields)
        self.emit({'event': 'stage', 'id': sid, **fields})

    def log(self, sid, text):
        self.emit({'event': 'log', 'id': sid, 'text': str(text)[:400]})

    def detect(self):
        self.checks = detect()
        self.emit({'event': 'detect', 'data': self.checks})
        return self.checks

    # Root stages run in one pkexec call, like the Waydroid installer.
    def run_root(self, stages, d):
        if not stages:
            return True
        args = [self.which('pkexec') or 'pkexec', sys.executable or '/usr/bin/python3', '-I', str(ROOT_HELPER), '--stages', ','.join(stages),
                '--pm', d['manager'] or 'none', '--user', os.environ.get('USER') or pathlib.Path.home().name]
        if d['missing']:
            args += ['--packages', ','.join(d['missing'])]
        try:
            self.proc = self.popen(args, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
        except OSError as error:
            self.emit({'event': 'error', 'text': f'Could not start pkexec: {error}'})
            return False
        failed, started = '', False
        for raw in self.proc.stdout:
            line = raw.strip()
            if not line:
                continue
            try:
                msg = json.loads(line)
            except ValueError:
                self.log('packages', line)
                continue
            if not isinstance(msg, dict):
                continue
            if msg.get('error'):
                self.log(stages[0], msg['error'])
                failed = failed or stages[0]
                continue
            sid = msg.get('stage')
            if sid not in TITLES:
                continue
            started = True
            if 'log' in msg:
                self.log(sid, msg['log'])
            fields = {k: msg[k] for k in ('state', 'progress', 'detail') if k in msg}
            if fields:
                self.stage(sid, **fields)
            if msg.get('state') == 'failed':
                failed = sid
        code = self.proc.wait()
        self.proc = None
        if self.cancelled:
            return False
        if code in (126, 127) and not started:
            self.emit({'event': 'error', 'text': 'The password prompt was cancelled'})
            return False
        if code or failed:
            self.emit({'event': 'error', 'text': TITLES.get(failed, 'Setup') + ' failed. Open the details for the log'})
            return False
        return True

    def fonts(self, d):
        target = DATA / 'fonts/opal'
        target.mkdir(parents=True, exist_ok=True)
        todo = [f for f, ok in d['fonts'].items() if not ok]
        for i, family in enumerate(todo):
            self.stage('fonts', detail=family, progress=i / max(1, len(todo)))
            name = urllib.parse.unquote(FONTS[family].rsplit('/', 1)[1])
            part = target / (name + '.part')
            cached = FONT_CACHE / FONT_CACHE_NAMES[family]
            if cached.is_file() and cached.stat().st_size > 100_000:
                shutil.copyfile(cached, part)
                os.replace(part, target / name)
                continue
            try:
                req = urllib.request.Request(FONTS[family], headers={'User-Agent': 'Opal-switch/1.0'})
                with self.fetch(req, timeout=60) as res, open(part, 'wb') as out:
                    shutil.copyfileobj(res, out)
                os.replace(part, target / name)
            except OSError as error:
                part.unlink(missing_ok=True)
                self.log('fonts', f'{family}: {error}')
                return False
        if self.which('fc-cache'):
            self.run(['fc-cache', '-f', str(target)], capture_output=True, timeout=120)
        return True

    def hyprland(self, d, options):
        HYPR_LUA.parent.mkdir(parents=True, exist_ok=True)
        if HYPR_LUA.exists():
            self.log('hyprland', 'Keeping your hyprland.lua')
            return True
        tmp = HYPR_LUA.with_suffix('.lua.opal-tmp')
        tmp.write_text(hyprland_config(d, options))
        os.replace(tmp, HYPR_LUA)
        # Remember that Opal wrote it, so undo can remove it.
        STATE.mkdir(parents=True, exist_ok=True)
        (STATE / 'switch-wrote-hyprland').write_text(str(HYPR_LUA) + '\n')
        self.log('hyprland', f'Wrote {HYPR_LUA}')
        return True

    def install_opal(self, d):
        script = REPO / 'tools/install.sh'
        if not script.exists():
            self.log('opal', f'Opal source not found at {REPO}')
            return False
        args = ['bash', str(script), '--no-deps']
        if not self.which('cmake'):
            args.append('--no-keyboard')
        try:
            self.proc = self.popen(args, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
        except OSError as error:
            self.log('opal', str(error))
            return False
        steps = ('Building the Borealis keyboard', 'Installed Borealis', 'Installed windowing plugin', 'Added reversible Opal hook', 'Installed Opal to')
        for raw in self.proc.stdout:
            line = raw.rstrip()
            if line:
                self.log('opal', line)
                hit = next((i for i, s in enumerate(steps) if line.startswith(s)), -1)
                if hit >= 0:
                    self.stage('opal', progress=(hit + 1) / len(steps), detail=line[:120])
        code = self.proc.wait()
        self.proc = None
        return code == 0

    def settings(self, d, options):
        path = STATE / 'preferences.json'
        try:
            current = json.loads(path.read_text())
        except (OSError, ValueError):
            current = {}
        changes = settings_changes(d, options, current)
        if current and not (STATE / 'switch-preferences-before.json').exists():
            (STATE / 'switch-preferences-before.json').write_text(json.dumps(current))
        merged = dict(current, **changes)
        STATE.mkdir(parents=True, exist_ok=True)
        tmp = path.with_suffix('.switch-tmp')
        tmp.write_text(json.dumps(merged, separators=(',', ':')))
        os.replace(tmp, path)
        for k, v in changes.items():
            self.log('settings', f'{k}: {json.dumps(v)[:80]}')
        return True

    def switch(self, options):
        if not self.lock.acquire(False):
            return False
        try:
            self.cancelled = False
            d = detect()
            self.checks = d
            if d['problems']:
                self.emit({'event': 'error', 'text': d['problems'][0]})
                self.emit({'event': 'done', 'ok': False})
                return False
            ids = plan(d, options)
            self.stages = [{'id': s, 'title': TITLES[s], 'state': 'waiting', 'progress': -1, 'detail': ''} for s in ids]
            self.emit({'event': 'plan', 'stages': self.stages})
            root = [s for s in ids if s in ROOT_STAGES]
            if root and not self.run_root(root, d):
                return self.finish(False)
            # Packages may have brought Hyprland's example config and new commands.
            d = dict(d, missing=missing_packages(d['manager']), terminal=first_command(TERMINALS), files=first_command(FILE_MANAGERS))
            for sid in ids:
                if sid in ROOT_STAGES or self.cancelled:
                    continue
                self.stage(sid, state='running', progress=-1)
                ok = {'fonts': lambda: self.fonts(d), 'hyprland': lambda: self.hyprland(d, options), 'opal': lambda: self.install_opal(d),
                      'settings': lambda: self.settings(d, options)}[sid]()
                if not ok and sid != 'fonts':
                    self.stage(sid, state='failed')
                    self.emit({'event': 'error', 'text': TITLES[sid] + ' failed. Open the details for the log'})
                    return self.finish(False)
                self.stage(sid, state='done' if ok else 'skipped', progress=1)
            return self.finish(True)
        finally:
            self.lock.release()

    def finish(self, ok):
        self.emit({'event': 'done', 'ok': ok and not self.cancelled, 'cancelled': self.cancelled})
        return ok

    def undo(self):
        """Remove the Opal login session and restore what the switch changed. Opal itself and the packages stay."""
        d = detect(full=False)
        self.stages = [{'id': s, 'title': TITLES[s], 'state': 'waiting', 'progress': -1, 'detail': ''} for s in ('remove-session', 'restore')]
        self.emit({'event': 'plan', 'stages': self.stages})
        if SESSION_FILE.exists() and not self.run_root(['remove-session'], dict(d, missing=[])):
            return self.finish(False)
        self.stage('remove-session', state='done', progress=1)
        self.stage('restore', state='running')
        marker = STATE / 'switch-wrote-hyprland'
        if marker.exists():
            backup = HYPR_LUA.with_suffix('.lua.opal-switch')
            if HYPR_LUA.exists():
                os.replace(HYPR_LUA, backup)
                self.log('restore', f'Moved the Opal hyprland.lua to {backup}')
            marker.unlink()
        before = STATE / 'switch-preferences-before.json'
        if before.exists():
            os.replace(before, STATE / 'preferences.json')
            self.log('restore', 'Put your earlier Opal settings back')
        self.stage('restore', state='done', progress=1)
        return self.finish(True)

    def cancel(self):
        self.cancelled = True
        proc = self.proc
        if proc and proc.poll() is None:
            try:
                if proc.stdin:
                    proc.stdin.write('cancel\n')
                    proc.stdin.flush()
                else:
                    proc.terminate()
            except (OSError, ValueError):
                pass

    def logout(self):
        """Log out of the current desktop so the login screen can start Opal."""
        desktop = desktop_name()
        commands = {'GNOME': ['gnome-session-quit', '--logout', '--no-prompt'], 'KDE Plasma': ['qdbus6', 'org.kde.Shutdown', '/Shutdown', 'logout'],
                    'Xfce': ['xfce4-session-logout', '--logout'], 'Cinnamon': ['cinnamon-session-quit', '--logout', '--no-prompt'],
                    'Hyprland': ['hyprctl', 'dispatch', 'exit']}
        args = commands.get(desktop)
        if args and self.which(args[0]):
            self.popen(args, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
            return True
        self.emit({'event': 'message', 'text': 'Log out from your desktop menu, then choose Opal on the login screen'})
        return False


# ---------- JSON-lines server for the window assistant ----------
def serve():
    out_lock = threading.Lock()
    def emit(event):
        with out_lock:
            sys.stdout.write(json.dumps(event) + '\n')
            sys.stdout.flush()
    sw = Switch(emit)
    for line in sys.stdin:
        try:
            c = json.loads(line)
        except ValueError:
            continue
        action = c.get('action') if isinstance(c, dict) else None
        if action == 'detect':
            threading.Thread(target=sw.detect, daemon=True).start()
        elif action == 'switch':
            threading.Thread(target=sw.switch, args=(c.get('options') if isinstance(c.get('options'), dict) else {},), daemon=True).start()
        elif action == 'undo':
            threading.Thread(target=sw.undo, daemon=True).start()
        elif action == 'cancel':
            sw.cancel()
        elif action == 'logout':
            sw.logout()


# ---------- terminal assistant ----------
class Term:
    def __init__(self, stream=sys.stdout):
        self.out = stream
        self.color = stream.isatty() and os.environ.get('NO_COLOR') is None

    def c(self, code, text):
        return f'\033[{code}m{text}\033[0m' if self.color else text

    def line(self, text=''):
        print(text, file=self.out, flush=True)

    def mark(self, kind):
        return {'ok': self.c('32', '✓'), 'fail': self.c('31', '✗'), 'info': self.c('36', '•'), 'warn': self.c('33', '!')}[kind]


def ask(prompt, default=True, tty=None):
    hint = 'Y/n' if default else 'y/N'
    try:
        stream = tty or open('/dev/tty')
    except OSError:
        return default
    print(f'{prompt} [{hint}] ', end='', flush=True)
    answer = stream.readline().strip().lower()
    return default if not answer else answer in ('y', 'yes')


def choose(prompt, options, default, tty=None):
    labels = ' / '.join(f'[{k}] {v}' for k, v in options)
    try:
        stream = tty or open('/dev/tty')
    except OSError:
        return default
    print(f'{prompt}  {labels}  (Enter: {default}) ', end='', flush=True)
    answer = stream.readline().strip().lower()
    keys = [k for k, _ in options]
    return answer if answer in keys else default


def report(t, d):
    t.line()
    t.line(t.c('1;35', '  ◆ Switch to Opal'))
    t.line(t.c('2', '  A Material 3 Expressive shell on Hyprland. Your current desktop stays installed.'))
    t.line()
    here = d['desktop'] or 'an unknown desktop'
    t.line(f"  You're on {t.c('1', here)} · {d['distro']['name']}" + (f" · {d['session']}" if d['session'] else ''))
    rows = []
    rows.append(('ok' if d['have']['hyprland'] else 'info', 'Hyprland ' + (d['hyprVersion'] or 'is installed') if d['have']['hyprland'] else 'Hyprland will be installed'))
    rows.append(('ok' if d['have']['quickshell'] else 'info', 'Quickshell is installed' if d['have']['quickshell'] else
                 'Quickshell will be installed' + (' from the COPR' if d['available'].get('quickshell') == 'copr' else '')))
    other = [m for m in d['missing'] if m not in ('hyprland', 'quickshell')]
    if other:
        rows.append(('info', f'{len(other)} helpers will be installed: ' + ', '.join(other[:6]) + ('…' if len(other) > 6 else '')))
    rows.append(('ok' if d['sessionInstalled'] else 'info', 'Opal is on the login screen' if d['sessionInstalled'] else
                 f"Opal will be added to {d['dm'] or 'the login screen'}"))
    if not all(d['fonts'].values()):
        rows.append(('info', 'Opal will download Google Sans Flex and Material Symbols to ~/.local/share/fonts'))
    rows.append(('ok' if d['hyprConfig'] else 'info', 'Your hyprland.lua stays as it is' if d['hyprConfig'] else 'A Hyprland setup will be written from its example'))
    for kind, text in rows:
        t.line(f'  {t.mark(kind)} {text}')
    for text in d['warnings']:
        t.line(f'  {t.mark("warn")} {t.c("33", text)}')
    for text in d['problems']:
        t.line(f'  {t.mark("fail")} {t.c("31", text)}')
    f = d['found']
    if f:
        t.line()
        t.line(t.c('1', f"  From {d['desktop'] or 'your desktop'}:"))
        if f.get('wallpaper'):
            t.line(f"    wallpaper   {pathlib.Path(f['wallpaper']).name}")
        if 'light' in f:
            t.line(f"    theme       {'light' if f['light'] else 'dark'}" + (f" · {f['accent']} accent" if f.get('accent') else ''))
        if f.get('pins'):
            t.line(f"    pinned      {', '.join(f['pins'][:6])}" + ('…' if len(f['pins']) > 6 else ''))
        if f.get('keyboard'):
            t.line(f"    keyboard    {f['keyboard']}")
        if 'naturalScroll' in f:
            t.line(f"    touchpad    {'natural' if f['naturalScroll'] else 'traditional'} scrolling")


def cli(args):
    t = Term()
    if args.undo:
        events = []
        sw = Switch(lambda e: print_event(t, e, events))
        if not args.yes and not ask('Remove Opal from the login screen and restore your earlier settings?', True):
            return 1
        return 0 if sw.undo() else 1
    d = detect()
    if args.json:
        print(json.dumps(d, indent=2))
        return 0
    report(t, d)
    if d['problems']:
        t.line()
        return 2
    if args.check:
        return 0
    t.line()
    options = {'fonts': not args.no_fonts, 'importLook': True, 'importPins': True, 'importKeyboard': True,
               'windows': args.windows or 'floating', 'mode': 'auto'}
    if not args.yes:
        if d['found'] and not ask('Bring your wallpaper, theme, pinned apps and keyboard along?', True):
            options.update(importLook=False, importPins=False, importKeyboard=False)
        options['windows'] = args.windows or {'f': 'floating', 't': 'tiling'}[choose('Windows:', [('f', 'floating, like ' + (d['desktop'] or 'most desktops')), ('t', 'tiling')], 'f')]
        if not ask('Turn on Opal\'s AI features (Claude)?', False):
            options['ai'] = False
        t.line()
        stages = plan(d, options)
        t.line('  Steps: ' + ' → '.join(TITLES[s] for s in stages))
        if any(s in ROOT_STAGES for s in stages):
            t.line(t.c('2', '  You will be asked for your password once.'))
        if not ask('Switch to Opal now?', True):
            return 1
    elif args.no_ai:
        options['ai'] = False
    events = []
    sw = Switch(lambda e: print_event(t, e, events, verbose=args.verbose))
    ok = sw.switch(options)
    t.line()
    if ok:
        t.line(t.c('1;32', '  Opal is installed.'))
        t.line(f"  Log out, then choose {t.c('1', 'Opal')} on the login screen. Your old desktop is still there if you want it back.")
        t.line(t.c('2', '  Undo any time with: opal-switch --undo'))
        if not args.yes and d['desktop'] and ask('Log out now?', False):
            sw.logout()
    else:
        t.line(t.c('31', '  The switch stopped. Run again with --verbose for every log line.'))
    return 0 if ok else 1


def cache_fonts(fetch=urllib.request.urlopen, log=lambda text: None):
    """Download missing Opal fonts into the cache only, so the window assistant draws its icons. Installing them stays a choice in the window."""
    FONT_CACHE.mkdir(parents=True, exist_ok=True)
    ok = True
    for family, url in FONTS.items():
        target = FONT_CACHE / FONT_CACHE_NAMES[family]
        if font_installed(family) or target.is_file():
            continue
        part = target.with_suffix('.part')
        try:
            req = urllib.request.Request(url, headers={'User-Agent': 'Opal-switch/1.0'})
            with fetch(req, timeout=60) as res, open(part, 'wb') as out:
                shutil.copyfileobj(res, out)
            os.replace(part, target)
        except OSError as error:
            part.unlink(missing_ok=True)
            log(f'{family}: {error}')
            ok = False
    return ok


def prepare_gui():
    """The window assistant runs on Quickshell. Install only Quickshell first, so the window can open; everything else is chosen in it."""
    t = Term()
    if not all(font_installed(f) for f in FONTS):
        t.line('  Getting the fonts the assistant window uses…')
        cache_fonts(log=lambda text: t.line(t.c('2', '  ' + text)))
    if shutil.which('quickshell'):
        return 0
    manager = package_manager()
    if not manager or package_available(manager, 'quickshell') is False and manager != 'dnf':
        t.line('  Quickshell is not in your repositories, so the window assistant cannot open. Use the terminal assistant: opal-switch')
        return 2
    t.line('  The assistant window needs Quickshell. You will be asked for your password to install it.')
    sw = Switch(lambda e: print_event(t, e, []))
    ok = sw.run_root(['packages'], {'manager': manager, 'missing': [n for n in ('quickshell', 'python3' if manager != 'pacman' else 'python') if not shutil.which(PROVIDES[n])]})
    return 0 if ok and shutil.which('quickshell') else 1


def print_event(t, e, events, verbose=False):
    events.append(e)
    kind = e.get('event')
    if kind == 'stage' and e.get('state') == 'running':
        t.line(f"  {t.c('36', '→')} {TITLES.get(e['id'], e['id'])}…")
    elif kind == 'stage' and e.get('state') == 'done':
        t.line(f"  {t.mark('ok')} {TITLES.get(e['id'], e['id'])}")
    elif kind == 'stage' and e.get('state') in ('failed', 'skipped'):
        t.line(f"  {t.mark('fail' if e['state'] == 'failed' else 'warn')} {TITLES.get(e['id'], e['id'])} {e['state']}")
    elif kind == 'log' and verbose:
        t.line(t.c('2', '      ' + e.get('text', '')))
    elif kind in ('error', 'message'):
        t.line(f"  {t.c('33', e.get('text', ''))}")


def main(argv=None):
    p = argparse.ArgumentParser(prog='opal-switch', description='Switch to Opal from another desktop. Your current desktop stays installed.')
    p.add_argument('command', nargs='?', choices=['serve', 'prepare-gui'], help=argparse.SUPPRESS)
    p.add_argument('--check', action='store_true', help='only show what would happen')
    p.add_argument('--json', action='store_true', help='print the checks as JSON')
    p.add_argument('--yes', '-y', action='store_true', help='do not ask; use the defaults')
    p.add_argument('--windows', choices=['floating', 'tiling'], help='window mode for the first login')
    p.add_argument('--no-fonts', action='store_true', help='do not download the Opal fonts')
    p.add_argument('--no-ai', action='store_true', help='turn off Opal\'s AI features (with --yes)')
    p.add_argument('--undo', action='store_true', help='remove the Opal login session and restore your settings')
    p.add_argument('--verbose', '-v', action='store_true', help='show every log line')
    args = p.parse_args(argv)
    if args.command == 'serve':
        serve()
        return 0
    if args.command == 'prepare-gui':
        return prepare_gui()
    try:
        return cli(args)
    except KeyboardInterrupt:
        print()
        return 130


if __name__ == '__main__':
    sys.exit(main())
