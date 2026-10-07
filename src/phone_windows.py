"""Optional Hyprland adapter for phone and tablet window fit, split view and slide-over. Without Hyprland every call does nothing."""
import json
import re
import subprocess

_OUTPUT = re.compile(r'[A-Za-z0-9._-]{1,64}')
_ADDRESS = re.compile(r'0x[0-9a-fA-F]+')
# Dialogs and tool windows keep their own size and are only kept inside the screen.
SMALL_DIALOG = 0.8
MODES = ('maximize', 'fullscreen', 'float', 'none')


def is_tablet(width, height):
    """A wide output is a tablet when its shorter side is at least 600 logical pixels."""
    return min(width, height) >= 600


def usable_rect(monitor, top=48, bottom=0, keyboard=0):
    """Return x, y, w, h of the area below the status bar and above navigation and keyboard, in global pixels."""
    scale = monitor.get('scale') or 1
    width, height = int(monitor['width'] / scale), int(monitor['height'] / scale)
    if monitor.get('transform', 0) % 2:
        width, height = height, width
    return (monitor['x'] + 0, monitor['y'] + top, width, max(1, height - top - bottom - keyboard))


def split_rects(rect, ratio=0.5, gap=8, minimum=0.25):
    """Return left and right rectangles for a split view. The divider ratio stays within bounds."""
    x, y, width, height = rect
    ratio = max(minimum, min(1 - minimum, float(ratio)))
    left = int((width - gap) * ratio)
    return (x, y, left, height), (x + left + gap, y, width - gap - left, height)


def slide_over_rect(rect, fraction=0.38, margin=12, side='right'):
    """Return the floating slide-over rectangle at one edge of the usable area."""
    x, y, width, height = rect
    w = int(width * fraction)
    h = height - margin * 2
    return ((x + width - w - margin) if side == 'right' else (x + margin), y + margin, w, h)


def plan_fit(clients, monitors, phone_outputs, modes=None):
    """Return window actions for clients on phone outputs. Desktop outputs are never touched."""
    modes = modes or {}
    by_id = {m['id']: m for m in monitors if m.get('name') in phone_outputs}
    plan = []
    for client in clients:
        monitor = by_id.get(client.get('monitor'))
        if not monitor or not client.get('mapped') or client.get('hidden') or not _ADDRESS.fullmatch(client.get('address', '')):
            continue
        cls = (client.get('class') or client.get('initialClass') or '').lower()
        mode = modes.get(cls, 'maximize')
        if mode not in MODES or mode == 'none':
            continue
        width, height = client.get('size', [0, 0])
        small = client.get('floating') and width < monitor['width'] * SMALL_DIALOG and height < monitor['height'] * SMALL_DIALOG
        state = client.get('fullscreen', 0)
        if mode == 'float':
            continue
        if small:
            plan.append({'address': client['address'], 'do': 'clamp'})
        elif state != (2 if mode == 'fullscreen' else 1) and not client.get('floating'):
            plan.append({'address': client['address'], 'do': mode})
    return plan


def plan_lift(clients, monitor, keyboard, top=48):
    """Return moves that lift focused floating windows above the keyboard. Tiled and maximized windows are resized by the compositor."""
    if keyboard <= 0:
        return []
    scale = monitor.get('scale') or 1
    height = int(monitor['height'] / scale)
    if monitor.get('transform', 0) % 2:
        height = int(monitor['width'] / scale)
    limit = monitor['y'] + height - keyboard
    moves = []
    for client in clients:
        if client.get('monitor') != monitor.get('id') or not client.get('floating') or not client.get('mapped') or client.get('focusHistoryID', 1) != 0:
            continue
        x, y = client['at']
        bottom = y + client['size'][1]
        if bottom > limit and _ADDRESS.fullmatch(client.get('address', '')):
            moves.append({'address': client['address'], 'x': x, 'y': max(monitor['y'] + top, y - (bottom - limit))})
    return moves


class PhoneWindows:
    """Applies plans with hyprctl. The runner is replaceable for tests."""

    def __init__(self, runner=None):
        self.runner = runner or self._run
        self.available = None

    @staticmethod
    def _run(args):
        result = subprocess.run(args, capture_output=True, text=True, timeout=3)
        if result.returncode:
            raise ValueError(result.stderr.strip()[:200] or 'hyprctl failed')
        return result.stdout

    def _json(self, what):
        return json.loads(self.runner(['hyprctl', '-j', what]))

    def _try(self, args):
        try:
            self.runner(args)
            return True
        except (ValueError, OSError, subprocess.SubprocessError):
            return False

    def probe(self):
        if self.available is None:
            self.available = self._try(['hyprctl', 'version'])
        return self.available

    def fit(self, phone_outputs, modes=None):
        """Maximize or fullscreen windows on phone outputs. Returns how many windows changed."""
        names = [n for n in phone_outputs if isinstance(n, str) and _OUTPUT.fullmatch(n)]
        if not names or not self.probe():
            return 0
        plan = plan_fit(self._json('clients'), self._json('monitors'), set(names), modes)
        changed = 0
        for step in plan:
            address = 'address:' + step['address']
            if step['do'] == 'clamp':
                ok = self._try(['hyprctl', 'dispatch', 'focuswindow', address]) and self._try(['hyprctl', 'dispatch', 'centerwindow'])
            else:
                value = '2' if step['do'] == 'fullscreen' else '1'
                ok = self._try(['hyprctl', 'dispatch', 'fullscreenstate', value + ' ' + value + ',' + address])
            changed += bool(ok)
        return changed

    def place(self, address, rect, floating=True):
        """Float a window and set its exact rectangle. Used by split view and slide-over."""
        if not self.probe() or not _ADDRESS.fullmatch(address or ''):
            return False
        x, y, w, h = (int(v) for v in rect)
        target = 'address:' + address
        if floating:
            self._try(['hyprctl', 'dispatch', 'setfloating', target])
        return (self._try(['hyprctl', 'dispatch', 'resizewindowpixel', f'exact {w} {h},{target}'])
                and self._try(['hyprctl', 'dispatch', 'movewindowpixel', f'exact {x} {y},{target}']))

    def split(self, output, left, right, ratio=0.5, top=48, bottom=0, keyboard=0):
        """Put two windows side by side on one output."""
        if not isinstance(output, str) or not _OUTPUT.fullmatch(output) or not self.probe():
            return False
        monitor = next((m for m in self._json('monitors') if m.get('name') == output), None)
        if not monitor:
            return False
        a, b = split_rects(usable_rect(monitor, top, bottom, keyboard), ratio)
        return self.place(left, a) and self.place(right, b)

    def slide_over(self, output, address, fraction=0.38, top=48, bottom=0, side='right'):
        """Float one window over the others at an edge."""
        monitor = next((m for m in self._json('monitors') if m.get('name') == output), None) if self.probe() and _OUTPUT.fullmatch(output or '') else None
        if not monitor:
            return False
        ok = self.place(address, slide_over_rect(usable_rect(monitor, top, bottom), fraction, side=side))
        return ok and self._try(['hyprctl', 'dispatch', 'alterzorder', 'top,address:' + address])

    def lift(self, output, keyboard):
        """Move the focused floating window above the on-screen keyboard."""
        if not self.probe() or not _OUTPUT.fullmatch(output or ''):
            return 0
        monitor = next((m for m in self._json('monitors') if m.get('name') == output), None)
        if not monitor:
            return 0
        done = 0
        for move in plan_lift(self._json('clients'), monitor, keyboard):
            done += self._try(['hyprctl', 'dispatch', 'movewindowpixel', f"exact {move['x']} {move['y']},address:{move['address']}"])
        return done

    def unsplit(self, addresses, phone_outputs):
        """Return split windows to the tiled layout and fit them again."""
        if not self.probe():
            return 0
        for address in addresses:
            if _ADDRESS.fullmatch(address or ''):
                self._try(['hyprctl', 'dispatch', 'settiled', 'address:' + address])
        return self.fit(phone_outputs)

    def go_home(self):
        """Show the home screen by switching to an empty workspace. Returns false without Hyprland."""
        if not self.probe():
            return False
        if self._try(['hyprctl', 'eval', 'return true']):
            return self._try(['hyprctl', 'eval', 'hl.dispatch(hl.dsp.focus({workspace="empty"}))'])
        return self._try(['hyprctl', 'dispatch', 'workspace', 'empty'])
