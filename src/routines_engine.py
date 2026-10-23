"""Reversible Modes & Routines Engine for Opal.

Evaluates `When -> Do` automations against live system state (focused app class, charging state, battery level, Wi-Fi network, or manual Mode toggles).
When a routine activates, it snapshots the user's prior settings before applying changes, and restores them cleanly when the trigger ends.
"""
import re

VALID_TRIGGERS = ('app', 'charging', 'battery', 'wifi', 'manual')
VALID_PROFILES = ('power-saver', 'balanced', 'performance')
ID_RE = re.compile(r'^[A-Za-z0-9_-]{1,48}$')

DEFAULT_ROUTINES = [
    {
        'id': 'work-focus',
        'name': 'Work & Code Focus',
        'icon': 'code',
        'enabled': False,
        'when': {'kind': 'app', 'value': 'code'},
        'do': {'dnd': True, 'profile': 'balanced'},
    },
    {
        'id': 'battery-guardian',
        'name': 'Low Battery Guardian',
        'icon': 'battery_saver',
        'enabled': True,
        'when': {'kind': 'battery', 'value': 20},
        'do': {'profile': 'power-saver'},
    },
    {
        'id': 'docked-power',
        'name': 'Charging Performance',
        'icon': 'bolt',
        'enabled': False,
        'when': {'kind': 'charging', 'value': True},
        'do': {'profile': 'performance'},
    },
    {
        'id': 'reading-night',
        'name': 'Evening Reading Mode',
        'icon': 'menu_book',
        'enabled': False,
        'when': {'kind': 'manual', 'value': True},
        'do': {'dnd': True, 'nightLight': True},
    },
]


def valid_routine(r):
    if not isinstance(r, dict):
        return False
    if not set(r) <= {'id', 'name', 'icon', 'enabled', 'when', 'do'}:
        return False
    if not isinstance(r.get('id'), str) or not ID_RE.fullmatch(r['id']):
        return False
    if not isinstance(r.get('name'), str) or not 0 < len(r['name']) <= 60:
        return False
    if not isinstance(r.get('icon', ''), str) or len(r.get('icon', '')) > 40:
        return False
    if type(r.get('enabled')) is not bool:
        return False
    when = r.get('when')
    if not isinstance(when, dict) or when.get('kind') not in VALID_TRIGGERS:
        return False
    kind, val = when.get('kind'), when.get('value')
    if kind in ('app', 'wifi') and (not isinstance(val, str) or not 0 < len(val) <= 120):
        return False
    if kind == 'charging' and type(val) is not bool:
        return False
    if kind == 'battery' and (type(val) is not int or not 5 <= val <= 80):
        return False
    do = r.get('do')
    if not isinstance(do, dict) or not do or not set(do) <= {'dnd', 'light', 'profile', 'nightLight'}:
        return False
    if 'dnd' in do and type(do['dnd']) is not bool:
        return False
    if 'light' in do and type(do['light']) is not bool:
        return False
    if 'nightLight' in do and type(do['nightLight']) is not bool:
        return False
    if 'profile' in do and do['profile'] not in VALID_PROFILES:
        return False
    return True


def valid_preference(key, value):
    if key == 'routines':
        return isinstance(value, list) and len(value) <= 32 and all(valid_routine(r) for r in value)
    if key == 'activeModes':
        return isinstance(value, list) and len(value) <= 32 and all(isinstance(x, str) and ID_RE.fullmatch(x) for x in value)
    return False


def matches(routine, context):
    """Return True if `routine` should be active given `context`."""
    if not routine.get('enabled'):
        return False
    rid = routine.get('id', '')
    if rid in (context.get('manual_ids') or ()):
        return True
    when = routine.get('when') or {}
    kind = when.get('kind')
    val = when.get('value')
    if kind == 'manual':
        return rid in (context.get('manual_ids') or ())
    if kind == 'app':
        active_cls = str(context.get('active_class') or '').lower()
        target = str(val or '').lower().strip()
        return bool(active_cls and target and (active_cls == target or target in active_cls))
    if kind == 'charging':
        return bool(context.get('charging')) is bool(val)
    if kind == 'battery':
        bat = context.get('battery', -1)
        return isinstance(bat, int) and 0 <= bat <= int(val) and not context.get('charging')
    if kind == 'wifi':
        net = str(context.get('network') or '').lower().strip()
        target = str(val or '').lower().strip()
        return bool(net and target and net == target)
    return False


class RoutinesEngine:
    def __init__(self, emit, get_state, apply_effect):
        """
        `get_state(key)` returns the current value for 'dnd', 'light', 'profile', or 'nightLight'.
        `apply_effect(key, value)` applies that setting.
        """
        self.emit = emit
        self.get_state = get_state
        self.apply_effect = apply_effect
        self.active_ids = set()
        self.baseline = {}  # key -> original value before any routine touched it

    def evaluate(self, routines, context):
        routines = routines if isinstance(routines, list) else DEFAULT_ROUTINES
        now_matching = [r for r in routines if valid_routine(r) and matches(r, context)]
        now_ids = {r['id'] for r in now_matching}

        started = [r for r in now_matching if r['id'] not in self.active_ids]
        stopped_ids = self.active_ids - now_ids

        if not started and not stopped_ids:
            return False

        # Compute desired keys across all currently matching routines
        desired = {}
        for r in now_matching:
            for k, v in (r.get('do') or {}).items():
                desired[k] = v

        # Snapshot baseline values for any newly controlled keys
        for k, v in desired.items():
            if k not in self.baseline:
                self.baseline[k] = self.get_state(k)

        # Restore keys that are no longer controlled by any active routine
        for k in list(self.baseline.keys()):
            if k not in desired:
                orig = self.baseline.pop(k)
                self.apply_effect(k, orig)

        # Apply desired values for active routines
        for k, v in desired.items():
            if self.get_state(k) != v:
                self.apply_effect(k, v)

        self.active_ids = now_ids

        # Emit Live Activities and status updates
        for r in started:
            self.emit({'event': 'activity', 'op': 'start', 'data': {
                'id': 'routine-' + r['id'], 'kind': 'routine', 'icon': r.get('icon') or 'bolt',
                'title': r['name'], 'subtitle': 'Routine active', 'short': r['name'][:10],
                'progress': -1,
            }})
        for rid in stopped_ids:
            self.emit({'event': 'activity', 'op': 'end', 'id': 'routine-' + rid})

        self.emit({'event': 'routinesState', 'active': sorted(self.active_ids)})
        return True
