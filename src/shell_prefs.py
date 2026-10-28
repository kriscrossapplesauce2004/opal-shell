"""Validators for the pill, Quick Settings tile, named space and lock screen preferences."""
import re

PILL_LEVELS = ('full', 'calm', 'off')
TILE_SIZES = ('round', 'wide', 'big')
# Tiles that carry a live control and may be 2x2.
BIG_TILES = ('media', 'devices', 'focus')
LOCK_FACES = ('stacked', 'thin')
LOCK_COLORS = ('primary', 'tertiary', 'white')
LOCK_WIDGETS = ('media', 'timers', 'calendar', 'devices')
SYMBOL = re.compile(r'^[a-z0-9_]{1,40}$')
COLOR = re.compile(r'^#[0-9a-fA-F]{6}$')
APP_ID = re.compile(r'^[A-Za-z0-9._@+-]{1,200}$')
MAX_SPACES = 32
MAX_SAVED = 24
MAX_SAVED_APPS = 24


def text(value, limit):
    return isinstance(value, str) and 0 < len(value.strip()) <= limit


def valid_space(value):
    """{name, icon, color}: every field optional, at least one set."""
    if not isinstance(value, dict) or not value or set(value) - {'name', 'icon', 'color'}: return False
    if 'name' in value and not (value['name'] == '' or text(value['name'], 40)): return False
    if 'icon' in value and not (value['icon'] == '' or SYMBOL.match(str(value['icon']))): return False
    if 'color' in value and not (value['color'] == '' or COLOR.match(str(value['color']))): return False
    return True


def valid_saved_app(value):
    if not isinstance(value, dict) or set(value) - {'app', 'cls', 'title', 'x', 'y', 'w', 'h', 'floating'}: return False
    if not (APP_ID.match(str(value.get('app', ''))) or APP_ID.match(str(value.get('cls', '')))): return False
    if 'title' in value and not (isinstance(value['title'], str) and len(value['title']) <= 300): return False
    if any(k in value and not (type(value[k]) in (int, float) and -100000 < value[k] < 100000) for k in ('x', 'y', 'w', 'h')): return False
    return 'floating' not in value or type(value['floating']) is bool


def valid_saved(value):
    if not isinstance(value, list) or len(value) > MAX_SAVED: return False
    ids = set()
    for s in value:
        if not isinstance(s, dict) or set(s) - {'id', 'name', 'icon', 'color', 'apps', 'saved'}: return False
        if not text(s.get('id'), 64) or s['id'] in ids or not text(s.get('name'), 40): return False
        ids.add(s['id'])
        if not valid_space({k: s[k] for k in ('name', 'icon', 'color') if k in s}): return False
        apps = s.get('apps', [])
        if not isinstance(apps, list) or len(apps) > MAX_SAVED_APPS or not all(valid_saved_app(a) for a in apps): return False
        if 'saved' in s and type(s['saved']) not in (int, float): return False
    return True


def valid_shortcut(value):
    return value == '' or isinstance(value, str) and (value.startswith('tile:') and SYMBOL.match(value[5:]) is not None
                                                     or value.startswith('app:') and APP_ID.match(value[4:]) is not None)


def valid_preference(key, value, tile_ids=()):
    """Check one preference from this group. Unknown keys are not valid here."""
    if key == 'pillLevel': return value in PILL_LEVELS
    if key in ('pillsCollapsed', 'lockGlance', 'lockActivities', 'lockQuickSettings', 'lockReply'): return type(value) is bool
    if key == 'worldClocks':
        return isinstance(value, list) and len(value) <= 8 and all(text(v, 64) and re.match(r'^[A-Za-z0-9_+/-]+$', v) for v in value) and len(set(value)) == len(value)
    if key == 'calendarPaths':
        return isinstance(value, list) and len(value) <= 16 and all(text(v, 300) for v in value)
    if key == 'quickTileSizes':
        return (isinstance(value, dict) and len(value) <= 64 and all(k in tile_ids and v in TILE_SIZES and (v != 'big' or k in BIG_TILES) for k, v in value.items()))
    if key == 'spaces':
        return isinstance(value, dict) and len(value) <= MAX_SPACES and all(re.match(r'^-?\d{1,4}$', k) and valid_space(v) for k, v in value.items())
    if key == 'savedSpaces': return valid_saved(value)
    if key == 'lockFace': return value in LOCK_FACES
    if key == 'lockColor': return value in LOCK_COLORS or isinstance(value, str) and COLOR.match(value) is not None
    if key == 'lockWidgets':
        return isinstance(value, list) and all(v in LOCK_WIDGETS for v in value) and len(set(value)) == len(value)
    if key == 'lockShortcuts':
        return isinstance(value, dict) and set(value) <= {'left', 'right'} and all(valid_shortcut(v) for v in value.values())
    return False
