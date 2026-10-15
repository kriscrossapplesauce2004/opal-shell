"""Home data from local sources: the ~/Desktop folder, a photo memory from ~/Pictures and the count of waiting updates."""
import configparser, datetime, mimetypes, os, pathlib, random, shutil, subprocess

HOME = pathlib.Path.home()
IMAGE_TYPES = ('.jpg', '.jpeg', '.png', '.webp', '.heic', '.avif', '.gif')
MAX_SCAN = 6000


def desktop_dir(home=HOME):
    """The XDG desktop folder, from user-dirs.dirs when it is set, else ~/Desktop."""
    try:
        for line in (home / '.config/user-dirs.dirs').read_text().splitlines():
            if line.startswith('XDG_DESKTOP_DIR='):
                value = line.split('=', 1)[1].strip().strip('"').replace('$HOME', str(home))
                if value and value != str(home): return pathlib.Path(value)
    except OSError:
        pass
    return home / 'Desktop'


def glyph_for(path, is_dir):
    if is_dir: return 'folder'
    mime = mimetypes.guess_type(str(path))[0] or ''
    for prefix, name in (('image/', 'image'), ('video/', 'movie'), ('audio/', 'music_note'), ('application/pdf', 'picture_as_pdf'),
                         ('text/', 'description'), ('application/zip', 'folder_zip'), ('application/x-', 'draft')):
        if mime.startswith(prefix): return name
    return 'draft'


def read_desktop_entry(path):
    """Return the name and icon of a .desktop launcher, or None when it is not a valid application entry."""
    parser = configparser.ConfigParser(interpolation=None, strict=False)
    try:
        parser.read(path, encoding='utf-8')
        entry = parser['Desktop Entry']
    except (KeyError, OSError, configparser.Error, UnicodeDecodeError):
        return None
    if entry.get('Type', 'Application') not in ('Application', 'Link') or entry.get('Hidden', '').lower() == 'true': return None
    return {'name': entry.get('Name', path.stem)[:80], 'icon': entry.get('Icon', '')[:200]}


def list_desktop(folder=None):
    """Return the visible entries of the desktop folder. Folders come first, then files by name."""
    folder = pathlib.Path(folder or desktop_dir())
    items = []
    try:
        entries = sorted(os.scandir(folder), key=lambda e: (not e.is_dir(), e.name.lower()))
    except OSError:
        return []
    for entry in entries[:200]:
        if entry.name.startswith('.'): continue
        path = pathlib.Path(entry.path)
        is_dir = entry.is_dir()
        mime = '' if is_dir else (mimetypes.guess_type(str(path))[0] or '')
        # Freedesktop icon names for the file type, with a generic one as the fallback.
        theme_icon = 'folder' if is_dir else (mime.replace('/', '-') if mime else 'text-x-generic')
        item = {'path': str(path), 'name': entry.name, 'dir': is_dir, 'glyph': glyph_for(path, is_dir), 'icon': theme_icon, 'app': False}
        if not is_dir and entry.name.endswith('.desktop'):
            launcher = read_desktop_entry(path)
            if launcher: item.update({'name': launcher['name'], 'icon': launcher['icon'], 'app': True, 'glyph': 'apps'})
        elif not is_dir and path.suffix.lower() in IMAGE_TYPES:
            item['thumb'] = path.as_uri()
        items.append(item)
    return items


def signature(folder=None):
    """A cheap value that changes when the desktop folder changes."""
    folder = pathlib.Path(folder or desktop_dir())
    try:
        return (folder.stat().st_mtime_ns, tuple(sorted(os.listdir(folder))))
    except OSError:
        return None


def inside(path, folder):
    try:
        real = os.path.realpath(path)
        return os.path.dirname(real) == os.path.realpath(folder) and os.path.exists(real)
    except (TypeError, ValueError):
        return False


def launch_command(path):
    """The command that opens one desktop item: launchers run with gio, everything else opens with xdg-open."""
    if path.endswith('.desktop') and shutil.which('gio'): return ['gio', 'launch', path]
    return ['xdg-open', path]


def pictures(root=None, limit=MAX_SCAN):
    """Images under ~/Pictures to a bounded depth, without hidden or cache folders."""
    root = pathlib.Path(root or HOME / 'Pictures')
    found = []
    for base, dirs, files in os.walk(root):
        depth = len(pathlib.Path(base).relative_to(root).parts)
        dirs[:] = [d for d in dirs if not d.startswith('.') and depth < 4 and d.lower() not in ('thumbnails', 'cache')]
        for name in files:
            if name.lower().endswith(IMAGE_TYPES) and not name.startswith('.'):
                path = os.path.join(base, name)
                try: found.append((path, os.stat(path).st_mtime))
                except OSError: continue
                if len(found) >= limit: return found
    return found


def memory(images, today=None, rng=None):
    """Pick one photo: one from this week in an earlier year ("N years ago"), else one from the last months. Return {path, caption} or None."""
    today = today or datetime.date.today()
    rng = rng or random.Random(today.toordinal())
    earlier, recent = [], []
    for path, mtime in images:
        day = datetime.date.fromtimestamp(mtime)
        if day.year < today.year:
            try: anniversary = day.replace(year=today.year)
            except ValueError: anniversary = day.replace(year=today.year, day=28)
            if abs((anniversary - today).days) <= 3: earlier.append((today.year - day.year, path))
        if 7 <= (today - day).days <= 120: recent.append(path)
    if earlier:
        years, path = rng.choice(sorted(earlier))
        return {'path': path, 'caption': f'{years} year{"s" if years > 1 else ""} ago', 'detail': 'Memories'}
    if recent:
        return {'path': rng.choice(sorted(recent)), 'caption': 'Recently', 'detail': 'From your photos'}
    return None


def pending_updates(runner=subprocess.run, which=shutil.which):
    """Count waiting package updates with checkupdates. Return -1 when the tool is missing or fails."""
    tool = which('checkupdates')
    if not tool: return -1
    try:
        result = runner([tool, '--nocolor'], capture_output=True, text=True, timeout=120)
    except (OSError, subprocess.SubprocessError):
        return -1
    if result.returncode not in (0, 2): return -1
    return len([line for line in result.stdout.splitlines() if line.strip()])


# Preference validation for the new home layouts.
WIDGET_KINDS = ('glance', 'media', 'photos', 'devices', 'clock', 'live', 'calendar')


def valid_canvas(value):
    """Desktop widget canvas: up to 16 widgets placed on a grid of cells."""
    if not isinstance(value, list) or len(value) > 16: return False
    ids = set()
    for w in value:
        if not isinstance(w, dict) or set(w) != {'id', 'kind', 'x', 'y', 'w', 'h'}: return False
        if not isinstance(w['id'], str) or not 0 < len(w['id']) <= 32 or w['id'] in ids: return False
        ids.add(w['id'])
        if w['kind'] not in WIDGET_KINDS: return False
        if not all(type(w[k]) is int for k in ('x', 'y', 'w', 'h')): return False
        if not (0 <= w['x'] <= 63 and 0 <= w['y'] <= 39 and 1 <= w['w'] <= 12 and 1 <= w['h'] <= 10): return False
    return True


def valid_slots(value):
    """Desktop icon slots: file name to slot index."""
    return isinstance(value, dict) and len(value) <= 400 and all(isinstance(k, str) and 0 < len(k) <= 255 and '/' not in k and type(v) is int and 0 <= v < 2000 for k, v in value.items())


def valid_preference(key, value):
    if key == 'desktopCanvas': return valid_canvas(value)
    if key == 'desktopSlots': return valid_slots(value)
    if key == 'weatherCity': return isinstance(value, str) and len(value) <= 80
    if key == 'weatherFahrenheit': return type(value) is bool
    return False
