"""Optional floating window mode. Pure planning: it returns operations, and the backend runs them through HyprActions.

Turning the mode on floats the tiled windows where they are. Turning it off tiles every window that the mode floated,
but not windows that floated before, and not windows that the user's own Hyprland rules float."""
import json, os, pathlib, re

STATE = pathlib.Path(os.environ.get('XDG_STATE_HOME') or pathlib.Path.home() / '.local/state') / 'opal' / 'floating.json'
HYPR_CONFIG = pathlib.Path(os.environ.get('XDG_CONFIG_HOME') or pathlib.Path.home() / '.config') / 'hypr' / 'hyprland.lua'
MINIMIZED = 'special:opal-minimized'
GAP = 8
MAX_MEMORY = 200


def load(path=STATE):
    try:
        data = json.loads(path.read_text())
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


def save(state, path=STATE):
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix('.tmp')
    temp.write_text(json.dumps(state))
    os.replace(temp, path)


def regular(client):
    """A mapped window on a normal workspace. Special workspaces (scratchpads, minimized) are not touched."""
    return client.get('mapped', True) and int((client.get('workspace') or {}).get('id', 0)) > 0


def user_float_rules(text):
    """Return (class, title) regex pairs from window rules in the user's Lua config that float windows."""
    rules = []
    for block in re.findall(r'hl\.window_rule\s*\(\s*\{(.*?)\}\s*\)', text or '', re.S):
        if not re.search(r'\bfloat\s*=\s*true', block): continue
        if re.search(r'name\s*=\s*"opal-', block): continue
        cls = re.search(r'class\s*=\s*"((?:[^"\\]|\\.)*)"', block)
        title = re.search(r'title\s*=\s*"((?:[^"\\]|\\.)*)"', block)
        unescape = lambda s: s.replace('\\\\', '\\') if s else s
        rules.append((unescape(cls.group(1)) if cls else None, unescape(title.group(1)) if title else None))
    return rules


def floats_by_rule(client, rules):
    for cls, title in rules:
        try:
            if cls is not None and cls != '.*' and not re.search(cls, client.get('class', '')): continue
            if cls == '.*': continue
            if title is not None and not re.search(title, client.get('title', '')): continue
            return True
        except re.error:
            continue
    return False


def plan_enable(clients, memory=None):
    """Float every tiled window where it is now. Return (operations, addresses that were already floating)."""
    memory = memory or {}
    ops, before = [], []
    for c in filter(regular, clients):
        if c.get('floating'):
            before.append(c['address'])
            continue
        if c.get('fullscreen'): continue
        x, y = c.get('at', [0, 0]); w, h = c.get('size', [800, 600])
        saved = memory.get(c.get('class', ''))
        rect = saved if saved and len(saved) == 4 else [x, y, w, h]
        ops.append({'op': 'float', 'address': c['address'], 'value': True})
        ops.append({'op': 'geometry', 'address': c['address'], 'rect': [int(v) for v in rect]})
    return ops, before


def plan_disable(clients, before, rules):
    """Tile every floating window, except the ones that floated before the mode and the ones that the user's rules float."""
    keep = set(before or [])
    ops = []
    for c in filter(regular, clients):
        if not c.get('floating') or c['address'] in keep or floats_by_rule(c, rules): continue
        ops.append({'op': 'float', 'address': c['address'], 'value': False})
    return ops


def remember(memory, clients):
    """Keep the last floating size and place of each app class. The newest entries win when the list is full."""
    out = dict(memory or {})
    for c in filter(regular, clients):
        if not c.get('floating') or c.get('fullscreen') or not c.get('class'): continue
        x, y = c.get('at', [0, 0]); w, h = c.get('size', [0, 0])
        if w < 120 or h < 80: continue
        out.pop(c['class'], None)
        out[c['class']] = [int(x), int(y), int(w), int(h)]
    while len(out) > MAX_MEMORY: out.pop(next(iter(out)))
    return out


def usable_area(monitor):
    """The part of a monitor that windows may use, in layout pixels: the size divided by the scale, less reserved bars."""
    scale = monitor.get('scale') or 1
    transform = monitor.get('transform', 0) or 0
    width, height = monitor.get('width', 1920) / scale, monitor.get('height', 1080) / scale
    if transform % 2: width, height = height, width
    left, top, right, bottom = (monitor.get('reserved') or [0, 0, 0, 0])[:4]
    return monitor.get('x', 0) + left, monitor.get('y', 0) + top, width - left - right, height - top - bottom


def snap_rect(monitor, cell, gap=GAP):
    """Place a window in a fraction of the monitor: cell is [x, y, width, height] from 0 to 1. Gaps stay between neighbours."""
    fx, fy, fw, fh = [max(0.0, min(1.0, float(v))) for v in cell]
    ax, ay, aw, ah = usable_area(monitor)
    x0 = ax + gap + fx * (aw - gap) ; y0 = ay + gap + fy * (ah - gap)
    w = fw * (aw - gap) - gap; h = fh * (ah - gap) - gap
    return [int(round(x0)), int(round(y0)), max(120, int(round(w))), max(80, int(round(h)))]


# Snap layouts offered by the picker: each is a list of cells.
LAYOUTS = [
    [[0, 0, .5, 1], [.5, 0, .5, 1]],
    [[0, 0, 2 / 3, 1], [2 / 3, 0, 1 / 3, 1]],
    [[0, 0, 1 / 3, 1], [1 / 3, 0, 1 / 3, 1], [2 / 3, 0, 1 / 3, 1]],
    [[0, 0, .5, 1], [.5, 0, .5, .5], [.5, .5, .5, .5]],
    [[0, 0, .5, .5], [.5, 0, .5, .5], [0, .5, .5, .5], [.5, .5, .5, .5]],
    [[0, 0, .25, 1], [.25, 0, .5, 1], [.75, 0, .25, 1]],
]


def valid_cell(cell):
    return isinstance(cell, list) and len(cell) == 4 and all(isinstance(v, (int, float)) and 0 <= v <= 1 for v in cell) and cell[2] > 0 and cell[3] > 0 and cell[0] + cell[2] <= 1.001 and cell[1] + cell[3] <= 1.001
