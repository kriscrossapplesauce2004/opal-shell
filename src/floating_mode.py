"""Optional floating window mode. Pure planning: it returns operations, and the backend runs them through HyprActions.

Turning the mode on floats the tiled windows where they are. Turning it off tiles every window that the mode floated,
but not windows that floated before, and not windows that the user's own Hyprland rules float."""
import json, os, pathlib, re

STATE = (pathlib.Path(os.environ['OPAL_STATE_DIR']) if os.environ.get('OPAL_STATE_DIR') else pathlib.Path(os.environ.get('XDG_STATE_HOME') or pathlib.Path.home() / '.local/state') / 'opal') / 'floating.json'
HYPR_CONFIG = pathlib.Path(os.environ.get('XDG_CONFIG_HOME') or pathlib.Path.home() / '.config') / 'hypr' / 'hyprland.lua'
MINIMIZED = 'special:opal-minimized'
GAP = 8
TITLEBAR = 36
SHELF = 72
MAX_MEMORY = 200
# Patterns for window classes that draw their own client decorations.
CSD_PATTERNS = [
    r'^(google-chrome.*|chromium.*|brave-browser.*|vivaldi.*|opera.*|microsoft-edge.*)$',
    r'^(firefox.*|thunderbird.*|floorp.*|zen-browser.*|zen.*|librewolf.*|tor-browser.*|mullvad-browser.*)$',
    r'^(org\.gnome\..*|gnome-.*|nautilus.*|evince.*|loupe.*|totem.*|epiphany.*|baobab.*|geary.*|simple-scan.*)$',
    r'^(io\.github\..*|com\.github\..*|io\.gitlab\..*)$',
    r'^(code.*|Code.*|vscode.*|vscodium.*|cursor.*|zed.*|zed-editor.*)$',
    r'^(discord.*|vesktop.*|equibop.*|webcord.*|equicord.*|obsidian.*|slack.*|spotify.*|signal.*|telegram-desktop.*|chatgpt.*|steam.*|Steam.*)$',
    r'^(dev\.opal\..*)$',
]


def is_csd(client, prefs=None):
    """Return True when the window draws its own client-side decorations."""
    if prefs and prefs.get('respectCsd') is False: return False
    cls = client.get('class') if isinstance(client, dict) else (client or '')
    if not cls or not isinstance(cls, str): return False
    custom = (prefs or {}).get('csdClasses')
    if isinstance(custom, list):
        for pattern in custom:
            try:
                if re.search(pattern, cls): return True
            except re.error: continue
    for pat in CSD_PATTERNS:
        try:
            if re.search(pat, cls): return True
        except re.error: continue
    return False


def csd_lua_pattern(prefs=None):
    """Return a combined regular expression for Hyprland window rules."""
    patterns = list(CSD_PATTERNS)
    custom = (prefs or {}).get('csdClasses')
    if isinstance(custom, list):
        patterns.extend([p for p in custom if isinstance(p, str)])
    inner = '|'.join(p.strip('^$()') for p in patterns)
    return f'^({inner})$'


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


# Windows of nested compositors, such as the nested phone session, keep the size their own screen needs.
NESTED_COMPOSITORS = ('aquamarine',)


def plan_tile_outputs(clients, monitors, outputs, rules):
    """Tile the floating and maximized windows on the named outputs, except windows that the user's rules float. Tablets use desktop tiling."""
    ids = {m.get('id') for m in monitors if m.get('name') in set(outputs or [])}
    ops = []
    for c in filter(regular, clients):
        if c.get('monitor') not in ids or floats_by_rule(c, rules) or c.get('class') in NESTED_COMPOSITORS: continue
        if c.get('fullscreen') == 1: ops.append({'op': 'unmaximize', 'address': c['address']})
        if c.get('floating'): ops.append({'op': 'float', 'address': c['address'], 'value': False})
    return ops


def remember(memory, clients, snapped=None):
    """Keep the last floating size and place of each app class. The newest entries win when the list is full.
    A snapped or maximized window is remembered at the size it had before the snap."""
    out = dict(memory or {})
    snapped = snapped or {}
    for c in filter(regular, clients):
        if not c.get('floating') or c.get('fullscreen') or not c.get('class'): continue
        x, y = c.get('at', [0, 0]); w, h = c.get('size', [0, 0])
        before = (snapped.get(c.get('address')) or {}).get('rect')
        if before and len(before) == 4: x, y, w, h = before
        if w < 120 or h < 80: continue
        out.pop(c['class'], None)
        out[c['class']] = [int(x), int(y), int(w), int(h)]
    while len(out) > MAX_MEMORY: out.pop(next(iter(out)))
    return out


def usable_area(monitor, shelf=0):
    """The part of a monitor that windows may use, in layout pixels: the size divided by the scale, less reserved bars.
    When nothing reserves the bottom edge, the floating Shelf still covers it, so shelf pixels stay free there."""
    scale = monitor.get('scale') or 1
    transform = monitor.get('transform', 0) or 0
    width, height = monitor.get('width', 1920) / scale, monitor.get('height', 1080) / scale
    if transform % 2: width, height = height, width
    left, top, right, bottom = (monitor.get('reserved') or [0, 0, 0, 0])[:4]
    bottom = max(bottom, shelf)
    return monitor.get('x', 0) + left, monitor.get('y', 0) + top, width - left - right, height - top - bottom


def snap_rect(monitor, cell, gap=GAP, titlebar=0, shelf=SHELF):
    """Place a window in a fraction of the monitor: cell is [x, y, width, height] from 0 to 1. Gaps stay between neighbours.
    The rectangle is the window body: a titlebar above it takes titlebar pixels of the cell, so the whole window fills the cell exactly."""
    fx, fy, fw, fh = [max(0.0, min(1.0, float(v))) for v in cell]
    ax, ay, aw, ah = usable_area(monitor, shelf)
    x0 = ax + gap + fx * (aw - gap); y0 = ay + gap + fy * (ah - gap)
    w = fw * (aw - gap) - gap; h = fh * (ah - gap) - gap
    return [int(round(x0)), int(round(y0 + titlebar)), max(120, int(round(w))), max(80, int(round(h - titlebar)))]


def fit_rect(rect, monitor, titlebar=0, shelf=SHELF, gap=GAP):
    """Keep a floating window on screen. A window larger than the area opens at two thirds of it, centred; any window is moved fully inside."""
    ax, ay, aw, ah = usable_area(monitor, shelf)
    ay += titlebar; ah -= titlebar
    x, y, w, h = [int(v) for v in rect]
    if w > aw - 2 * gap or h > ah - 2 * gap:
        w, h = int(aw * .66), int(ah * .72)
        x, y = int(ax + (aw - w) / 2), int(ay + (ah - h) / 2)
    x = int(max(ax + gap, min(x, ax + aw - gap - w)))
    y = int(max(ay + gap, min(y, ay + ah - gap - h)))
    return [x, y, w, h]


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


def titlebar_colors(prefs):
    """Lua source for the titlebar colours, from the saved Opal palette. It falls back to calm dark roles."""
    light = prefs.get('light') is True
    roles = ((prefs.get('dynamicPalette') or {}).get('light' if light else 'dark') or {}) if prefs.get('dynamicColors') is not False else {}
    def hexa(key, fallback, alpha=''):
        value = str(roles.get(key) or fallback).lstrip('#')
        if not re.fullmatch(r'[0-9a-fA-F]{6}', value): value = fallback.lstrip('#')
        return ('rgba(' + value + alpha + ')') if alpha else ('rgb(' + value + ')')
    bar = hexa('surface_container', '#f3e9e8' if light else '#271d1d', 'f2')
    text = hexa('on_surface', '#231919' if light else '#f0dedd')
    close = hexa('error', '#ba1a1a' if light else '#ffb4ab')
    button = hexa('surface_container_highest', roles.get('outline_variant') or roles.get('surface_container_high') or ('#e2d8d7' if light else '#3d3231'))
    ink = hexa('on_error', '#ffffff' if light else '#690005')
    respect = 'false' if (prefs or {}).get('respectCsd') is False else 'true'
    # Escape backslashes for the Lua string literal.
    csd_pat = csd_lua_pattern(prefs).replace('\\', '\\\\\\\\')
    return ('return { bar = "%s", text = "%s", close = "%s", button = "%s", ink = "%s", font = "Google Sans Flex", respect_csd = %s, csd_pattern = "%s" }\n' % (bar, text, close, button, ink, respect, csd_pat))


# Drag snapping: the opal-windowing plugin names the zone under the cursor.
FULL = [0, 0, 1, 1]
ZONES = {
    'left': [0, 0, .5, 1], 'right': [.5, 0, .5, 1], 'top': FULL,
    'topleft': [0, 0, .5, .5], 'topright': [.5, 0, .5, .5], 'bottomleft': [0, .5, .5, .5], 'bottomright': [.5, .5, .5, .5],
}
HALVES = LAYOUTS[0]
QUARTERS = LAYOUTS[4]


def same_cell(a, b):
    return bool(a) and bool(b) and len(a) == 4 and len(b) == 4 and all(abs(float(x) - float(y)) < .01 for x, y in zip(a, b))


def layout_for(cell):
    """The snap layout that a cell belongs to, for Snap Assist. The whole screen has none."""
    if not cell or same_cell(cell, FULL): return None
    for layout in LAYOUTS:
        if any(same_cell(cell, c) for c in layout): return layout
    return None


def assist_cells(cell, filled):
    """The cells of the snapped cell's layout that are still empty: Snap Assist offers windows for them."""
    layout = layout_for(cell)
    if not layout: return []
    taken = [cell] + list(filled or [])
    return [c for c in layout if not any(same_cell(c, t) for t in taken)]


# Keyboard snapping cycles a side through these widths, like the pickers on other desktops.
LEFT_CYCLE = [[0, 0, .5, 1], [0, 0, 2 / 3, 1], [0, 0, 1 / 3, 1]]
RIGHT_CYCLE = [[.5, 0, .5, 1], [1 / 3, 0, 2 / 3, 1], [2 / 3, 0, 1 / 3, 1]]


def next_cell(cell, direction):
    """The next snap for Super+Alt+arrow. Returns a cell, 'restore' or 'minimize'.
    Left and right cycle the side's widths and move a quarter across. Up and down walk a side's ladder: top quarter, half, bottom quarter;
    up from the top quarter maximizes, down from the bottom quarter or from a maximized window restores, and down on a free window minimizes."""
    half = cell and len(cell) == 4 and abs(cell[1]) < .01 and abs(cell[3] - 1) < .01 and abs(cell[2] - .5) < .01
    quarter = cell and len(cell) == 4 and abs(cell[2] - .5) < .01 and abs(cell[3] - .5) < .01
    top = quarter and cell[1] < .01
    if direction in ('left', 'right'):
        if quarter:
            return [0 if direction == 'left' else .5, cell[1], .5, .5]
        cycle = LEFT_CYCLE if direction == 'left' else RIGHT_CYCLE
        for i, c in enumerate(cycle):
            if same_cell(cell, c): return cycle[(i + 1) % len(cycle)]
        return cycle[0]
    if direction == 'up':
        if half: return [cell[0], 0, .5, .5]
        if quarter and not top: return [cell[0], 0, .5, 1]
        return FULL
    if direction == 'down':
        if half: return [cell[0], .5, .5, .5]
        if top: return [cell[0], 0, .5, 1]
        if cell: return 'restore'
        return 'minimize'
    return None


def cascade(rect, others, monitor, titlebar=0, step=32):
    """Move a new window down and right while another window on its workspace starts at the same place, then keep it on screen."""
    x, y, w, h = [int(v) for v in rect]
    spots = {(int(o[0]), int(o[1])) for o in others}
    for _ in range(12):
        if not any(abs(x - ox) < 12 and abs(y - oy) < 12 for ox, oy in spots): break
        x += step; y += step
    return fit_rect([x, y, w, h], monitor, titlebar=titlebar)


def desktop_toggle(clients, workspace, shown):
    """Show desktop: minimize every window on the workspace, or bring back the ones it minimized.
    Returns (operation, addresses): ('restore', the minimized ones that still exist) or ('minimize', the workspace's windows)."""
    live = {c.get('address') for c in clients}
    back = [a for a in (shown or []) if a in live and any(c.get('address') == a and int((c.get('workspace') or {}).get('id', 0)) <= 0 for c in clients)]
    if back: return 'restore', back
    return 'minimize', [c['address'] for c in filter(regular, clients) if int((c.get('workspace') or {}).get('id', 0)) == int(workspace)]


def snap_frame(monitor, cell, titlebar=0, shelf=SHELF):
    """Where a snapped window will be drawn, titlebar included, relative to the monitor's top left corner. The shell draws previews there."""
    x, y, w, h = snap_rect(monitor, cell, titlebar=titlebar, shelf=shelf)
    return [x - monitor.get('x', 0), y - titlebar - monitor.get('y', 0), w, h + titlebar]


def snap_groups(snapped, monitors=None, shelf=SHELF, gap=GAP):
    """Group non-full snapped windows by (monitor, workspace) and compute their shared vertical split seam."""
    by_space = {}
    for address, entry in (snapped or {}).items():
        if not isinstance(entry, dict):
            continue
        cell = entry.get('cell')
        if not valid_cell(cell) or same_cell(cell, FULL):
            continue
        key = (str(entry.get('monitor') or ''), int(entry.get('workspace') or 0))
        by_space.setdefault(key, []).append({'address': address, 'cell': [float(v) for v in cell]})
    mon_map = {m.get('name'): m for m in (monitors or []) if isinstance(m, dict) and m.get('name')}
    groups = []
    for (mon_name, ws), members in sorted(by_space.items()):
        if len(members) < 2:
            continue
        # Find a shared vertical seam x in (0.15..0.85) where left cells end and right cells begin.
        seam = None
        for m in members:
            edge = round(m['cell'][0] + m['cell'][2], 4)
            if 0.15 <= edge <= 0.85 and any(abs(o['cell'][0] - edge) < 0.03 for o in members if o is not m):
                seam = edge
                break
        if seam is None:
            seam = 0.5
        divider = None
        mon = mon_map.get(mon_name)
        if mon:
            ax, ay, aw, ah = usable_area(mon, shelf)
            dx = int(round(ax - mon.get('x', 0) + gap + seam * (aw - gap) - gap / 2))
            dy = int(round(ay - mon.get('y', 0) + gap))
            dh = max(80, int(round(ah - 2 * gap)))
            divider = [dx, dy, gap, dh]
        groups.append({
            'id': f'{mon_name}:{ws}',
            'monitor': mon_name,
            'workspace': ws,
            'ratio': seam,
            'divider': divider,
            'members': members,
        })
    return groups


def plan_resize_group(snapped, monitor, workspace, ratio, titlebar=0, shelf=SHELF, gap=GAP):
    """Resize all snapped windows sharing the vertical seam on (monitor['name'], workspace) to the new ratio (0.25..0.75)."""
    ratio = max(0.25, min(0.75, float(ratio)))
    mon_name = str((monitor or {}).get('name') or '')
    ws = int(workspace or 0)
    groups = [g for g in snap_groups(snapped, [monitor] if monitor else [], shelf=shelf, gap=gap)
              if g['monitor'] == mon_name and g['workspace'] == ws]
    if not groups:
        return dict(snapped or {}), []
    old_seam = groups[0]['ratio']
    updated = {k: dict(v) for k, v in (snapped or {}).items() if isinstance(v, dict)}
    ops = []
    for member in groups[0]['members']:
        addr = member['address']
        fx, fy, fw, fh = member['cell']
        right_edge = fx + fw
        if abs(right_edge - old_seam) < 0.04 and fx < ratio - 0.1:
            new_cell = [fx, fy, round(ratio - fx, 4), fh]
        elif abs(fx - old_seam) < 0.04 and right_edge > ratio + 0.1:
            new_cell = [round(ratio, 4), fy, round(right_edge - ratio, 4), fh]
        else:
            continue
        updated[addr]['cell'] = new_cell
        tb = 0 if updated[addr].get('csd') else titlebar
        rect = snap_rect(monitor, new_cell, gap=gap, titlebar=tb, shelf=shelf)
        ops.append({'op': 'geometry', 'address': addr, 'rect': rect})
    return updated, ops


def group_addresses(snapped, address):
    """Return all addresses in the same Snap Group as address (including address), or [] if not in a multi-window group."""
    for group in snap_groups(snapped):
        addrs = [m['address'] for m in group['members']]
        if address in addrs:
            return addrs
    return []

