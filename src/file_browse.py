"""Folder listings for Opal's file picker: entries, places, bookmarks and recent files. Read-only."""
import fnmatch
import mimetypes
import os
import pathlib
import json
import re
import socket
import stat
import xml.etree.ElementTree as ET
from urllib.parse import unquote, urlparse

LIMIT = 2000
# The running portal (opal_portal.py) listens here for the picker's answer.
SOCKET = pathlib.Path(os.environ.get('XDG_RUNTIME_DIR', '/tmp'))/'opal-portal.sock'
IMAGE = ('.png', '.jpg', '.jpeg', '.webp', '.gif', '.bmp', '.svg', '.avif')
KINDS = (('image', IMAGE), ('video', ('.mp4', '.mkv', '.webm', '.mov', '.avi')), ('audio', ('.mp3', '.flac', '.ogg', '.opus', '.wav', '.m4a')),
         ('archive', ('.zip', '.tar', '.gz', '.xz', '.zst', '.7z', '.rar')), ('document', ('.pdf', '.odt', '.docx', '.doc', '.epub', '.md', '.txt', '.rtf')),
         ('code', ('.py', '.js', '.qml', '.c', '.cpp', '.h', '.rs', '.go', '.sh', '.lua', '.json', '.toml', '.yaml', '.yml', '.html', '.css')))
XDG_DIRS = (('DESKTOP', 'Desktop', 'desktop_windows'), ('DOCUMENTS', 'Documents', 'description'), ('DOWNLOAD', 'Downloads', 'download'),
            ('PICTURES', 'Pictures', 'image'), ('MUSIC', 'Music', 'music_note'), ('VIDEOS', 'Videos', 'movie'))


def to_path(value, home=None):
    """A local absolute path from a path or file:// URI; '' means home."""
    home = pathlib.Path(home) if home else pathlib.Path.home()
    if not value:
        return home
    if not isinstance(value, str) or len(value) > 4096 or '\0' in value:
        raise ValueError('Choose a local folder.')
    if value.startswith('file:'):
        url = urlparse(value)
        if url.netloc not in ('', 'localhost'):
            raise ValueError('Only local files are supported.')
        value = unquote(url.path)
    path = pathlib.Path(value).expanduser()
    if not path.is_absolute():
        raise ValueError('Use an absolute path.')
    return path


def kind(name):
    suffix = os.path.splitext(name)[1].lower()
    for label, suffixes in KINDS:
        if suffix in suffixes:
            return label
    return 'file'


def matches(name, rule):
    """A portal filter: {'globs': [...], 'mimes': [...]}; no rule means everything."""
    if not rule or not (rule.get('globs') or rule.get('mimes')):
        return True
    lower = name.lower()
    if any(fnmatch.fnmatch(lower, g.lower()) for g in rule.get('globs') or []):
        return True
    mime = mimetypes.guess_type(name)[0] or ''
    for pattern in rule.get('mimes') or []:
        if pattern == '*/*' or pattern == mime or pattern.endswith('/*') and mime.startswith(pattern[:-1]):
            return True
    return False


def listing(value='', hidden=False, rule=None, directories_only=False, home=None):
    folder = to_path(value, home)
    try:
        folder = folder.resolve(strict=True)
    except OSError:
        raise ValueError('That folder is unavailable.') from None
    if not folder.is_dir():
        raise ValueError('That folder is unavailable.')
    entries, skipped = [], 0
    try:
        with os.scandir(folder) as scan:
            for count, entry in enumerate(scan):
                if count >= LIMIT:
                    skipped += 1
                    continue
                if not hidden and entry.name.startswith('.'):
                    continue
                try:
                    info = entry.stat()
                except OSError:
                    continue
                directory = stat.S_ISDIR(info.st_mode)
                if not directory and (directories_only or not stat.S_ISREG(info.st_mode) or not matches(entry.name, rule)):
                    continue
                path = pathlib.Path(entry.path)
                entries.append(dict(name=entry.name, uri=path.as_uri(), path=str(path), dir=directory,
                                    size=0 if directory else info.st_size, modified=int(info.st_mtime),
                                    kind='folder' if directory else kind(entry.name), link=entry.is_symlink()))
    except PermissionError:
        raise ValueError('You do not have permission to open this folder.') from None
    entries.sort(key=lambda e: (not e['dir'], e['name'].casefold()))
    # Inside home the path starts at Home, not at /.
    top = (pathlib.Path(home) if home else pathlib.Path.home()).resolve()
    crumbs, part = [], folder
    while True:
        crumbs.insert(0, dict(name='Home' if part == top else part.name or '/', uri=part.as_uri()))
        if part.parent == part or part == top:
            break
        part = part.parent
    return dict(folder=folder.as_uri(), path=str(folder), parent=folder.parent.as_uri() if folder.parent != folder else '',
                writable=os.access(folder, os.W_OK), entries=entries, crumbs=crumbs, truncated=skipped)


def user_dirs(home):
    found = {}
    try:
        text = (home/'.config/user-dirs.dirs').read_text()
    except OSError:
        text = ''
    for key, value in re.findall(r'^XDG_([A-Z]+)_DIR="([^"]*)"', text, re.M):
        found[key] = pathlib.Path(value.replace('$HOME', str(home)))
    return found


def places(home=None):
    home = pathlib.Path(home) if home else pathlib.Path.home()
    configured = user_dirs(home)
    out = [dict(name='Home', uri=home.as_uri(), icon='home')]
    for key, fallback, icon in XDG_DIRS:
        path = configured.get(key, home/fallback)
        if path.is_dir() and path != home:
            out.append(dict(name=path.name, uri=path.as_uri(), icon=icon))
    for source in (home/'.config/gtk-3.0/bookmarks', home/'.local/share/user-places.xbel'):
        try:
            lines = source.read_text().splitlines()[:40] if source.suffix != '.xbel' else []
        except OSError:
            lines = []
        for line in lines:
            uri, _, label = line.partition(' ')
            if uri.startswith('file://'):
                path = pathlib.Path(unquote(urlparse(uri).path))
                if path.is_dir() and all(p['uri'] != path.as_uri() for p in out):
                    out.append(dict(name=label or path.name, uri=path.as_uri(), icon='bookmark'))
    for root in (pathlib.Path('/run/media')/home.name, pathlib.Path('/media')):
        try:
            for drive in sorted(root.iterdir())[:8]:
                if drive.is_dir():
                    out.append(dict(name=drive.name, uri=drive.as_uri(), icon='usb'))
        except OSError:
            pass
    return out


def recent(home=None, rule=None, limit=40):
    """Files from the shared recently-used list that still exist."""
    home = pathlib.Path(home) if home else pathlib.Path.home()
    try:
        root = ET.parse(home/'.local/share/recently-used.xbel').getroot()
    except (OSError, ET.ParseError):
        return []
    items = []
    for bookmark in root.iter('bookmark'):
        uri = bookmark.get('href', '')
        if not uri.startswith('file://'):
            continue
        path = pathlib.Path(unquote(urlparse(uri).path))
        try:
            info = path.stat()
        except OSError:
            continue
        if not stat.S_ISREG(info.st_mode) or not matches(path.name, rule):
            continue
        items.append(dict(name=path.name, uri=path.as_uri(), path=str(path), dir=False, size=info.st_size,
                          modified=int(info.st_mtime), kind=kind(path.name), link=False, folder=str(path.parent),
                          visited=bookmark.get('visited') or bookmark.get('modified') or ''))
    items.sort(key=lambda e: e['visited'], reverse=True)
    seen, out = set(), []
    for item in items:
        if item['uri'] not in seen:
            seen.add(item['uri'])
            out.append(item)
    return out[:limit]


def make_folder(parent, name):
    folder = to_path(parent)
    if not isinstance(name, str) or not name.strip() or '/' in name or name in ('.', '..') or len(name) > 255:
        raise ValueError('Folder names cannot contain "/".')
    target = folder/name.strip()
    target.mkdir()
    return target.as_uri()


def save_target(folder, name):
    """The file a Save dialog will write, and whether it already exists."""
    base = to_path(folder)
    if not isinstance(name, str) or not name.strip() or '/' in name or name in ('.', '..') or len(name) > 255:
        raise ValueError('File names cannot contain "/".')
    target = base/name.strip()
    return dict(uri=target.as_uri(), exists=target.exists())


def send_answer(data, path=None):
    """Hand one picker answer to the running portal."""
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
        client.settimeout(2)
        client.connect(str(path or SOCKET))
        client.sendall(json.dumps(data).encode())
