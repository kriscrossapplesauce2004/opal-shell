#!/usr/bin/env python3
"""Runs the Luna desktop suite. Automated tasks run in a nested Hyprland only."""
import argparse, datetime, json, os, re, shlex, signal, subprocess, sys, time, tomllib
from dataclasses import dataclass, field
from pathlib import Path

HERE = Path(__file__).resolve().parent
OPAL = HERE.parents[1]
TASKS_FILE = HERE / 'tasks.toml'
SHELL_SRC = OPAL / 'src' / 'shell.qml'
DEFAULT_STATE = Path(os.environ.get('XDG_STATE_HOME', str(Path.home() / '.local/state'))) / 'opal' / 'desktop-suite'

AREAS = ('windows', 'spaces', 'shelf', 'displays', 'sessions', 'apps', 'printing', 'network', 'bluetooth',
         'audio', 'brightness', 'power', 'accessibility', 'input', 'portal', 'notifications', 'clipboard',
         'capture', 'day-one')
NEEDS = ('nested-hyprland', 'real-hw', 'vm', 'rig-devices')
AUTOMATION = ('auto', 'semi', 'manual')
STATUSES = ('pass', 'fail', 'blocked', 'error', 'skipped', 'not-automated')
ID_PATTERN = re.compile(r'[a-z0-9]+(?:-[a-z0-9]+)*')
NESTED_OUTPUT = re.compile(r'(WAYLAND|HEADLESS)-\d+')
SIGNATURE = re.compile(r'[0-9a-f]{20,}_\d+_\d+')
ACTION_VERBS = ('spawn', 'workspace', 'window', 'layout', 'output', 'ipc', 'notify', 'clip-set',
                'screenshot', 'sleep', 'wait')
WINDOW_ACTIONS = ('float', 'fullscreen', 'move', 'close', 'minimize', 'restore', 'place', 'focus', 'to-monitor')
OUTPUT_NAME = re.compile(r'[A-Za-z0-9-]{1,32}')
QUERY_ROOTS = ('active', 'clients', 'monitors', 'monitor', 'window', 'workspace', 'layout', 'ipc',
               'clipboard', 'shot')
FIELD_ROOTS = ('active', 'clients', 'monitors', 'monitor', 'window', 'workspace', 'shot')
CHECK_SPLIT = re.compile(r'(.+?)\s+(==|!=|>=|<=|>|<|contains)\s+(.+)')
PATH_SEGMENT = re.compile(r'([A-Za-z_0-9][A-Za-z0-9_-]*)(?:\[([^\]]*)\])?')
ADDRESS = re.compile(r'0x[0-9a-fA-F]+')
ANSWER_TIMEOUT = 30.0
PNG = b'\x89PNG\r\n\x1a\n'


class TaskError(ValueError):
    """A task entry or check line is not valid."""


class Blocked(RuntimeError):
    """The environment lacks a tool or service the task needs."""


class Fail(AssertionError):
    """A check did not hold."""


class HyprError(RuntimeError):
    """Hyprland rejected a call."""


@dataclass
class Task:
    id: str
    area: str
    title: str
    steps: list
    expected: list
    needs: list
    automation: str
    actions: list = field(default_factory=list)
    checks: list = field(default_factory=list)


def check_signature(signature, live):
    # Refuse an empty, malformed or live signature before any call is made.
    if not signature or not SIGNATURE.fullmatch(signature):
        raise SystemExit('Refusing: %r is not a Hyprland instance signature.' % signature)
    if live and signature == live:
        raise SystemExit('Refusing: this is the live Hyprland session. Use a nested instance.')


def parse_action(line):
    # Return (verb, rest) for one action line, or raise TaskError.
    parts = line.strip().split(None, 1)
    if not parts or parts[0] not in ACTION_VERBS:
        raise TaskError('unknown action: %r' % line)
    verb, rest = parts[0], (parts[1] if len(parts) > 1 else '')
    try:
        args = shlex.split(rest)
    except ValueError as problem:
        raise TaskError('bad quoting in %r: %s' % (line, problem))
    if verb in ('spawn', 'ipc', 'notify', 'clip-set') and not args:
        raise TaskError('%s needs arguments: %r' % (verb, line))
    if verb == 'workspace' and not (len(args) == 1 and re.fullmatch(r'\d+|empty|name:[A-Za-z0-9_-]+', args[0])):
        raise TaskError('workspace takes N, empty or name:X: %r' % line)
    if verb == 'window' and (len(args) < 2 or args[1] not in WINDOW_ACTIONS):
        raise TaskError('window needs SELECTOR and one of %s: %r' % (WINDOW_ACTIONS, line))
    if verb == 'window' and args[1] == 'to-monitor' and not (len(args) == 3 and
                                                             (args[2] == 'last' or OUTPUT_NAME.fullmatch(args[2]))):
        raise TaskError('window to-monitor takes SELECTOR to-monitor NAME|last: %r' % line)
    if verb == 'layout' and args not in (['dwindle'], ['master']):
        raise TaskError('layout takes dwindle or master: %r' % line)
    if verb == 'output':
        ok = (args[:2] == ['create', 'headless'] or (len(args) == 2 and args[0] == 'remove')
              or (len(args) == 3 and args[0] == 'rotate' and args[2] in ('0', '1', '2', '3')))
        if not ok:
            raise TaskError('output takes create headless, remove NAME or rotate NAME 0-3: %r' % line)
    if verb == 'screenshot' and len(args) != 1:
        raise TaskError('screenshot takes one name: %r' % line)
    if verb == 'sleep' and not (len(args) == 1 and re.fullmatch(r'\d+(\.\d+)?', args[0])):
        raise TaskError('sleep takes seconds: %r' % line)
    if verb == 'wait':
        if not re.fullmatch(r'\d+(\.\d+)?\s+.+', rest):
            raise TaskError('wait takes SECONDS and a check: %r' % line)
        parse_check(rest.split(None, 1)[1])
    return verb, rest


def parse_check(text):
    # Return (path, op, rhs); op and rhs are None for a bare query.
    text = text.strip()
    match = CHECK_SPLIT.fullmatch(text)
    if match:
        path, op, rhs = match.group(1).strip(), match.group(2), match.group(3).strip()
    else:
        path, op, rhs = text, None, None
    segments = []
    pos = 0
    while pos < len(path):
        found = PATH_SEGMENT.match(path, pos)
        if not found:
            raise TaskError('bad query: %r' % text)
        segments.append((found.group(1), found.group(2)))
        pos = found.end()
        if pos < len(path):
            if path[pos] != '.':
                raise TaskError('bad query: %r' % text)
            pos += 1
    if segments[0][0] not in QUERY_ROOTS:
        raise TaskError('unknown query root in %r' % text)
    if segments[0][0] in FIELD_ROOTS and len(segments) < 2:
        raise TaskError('%r needs a field, for example %s.width' % (text, segments[0][0]))
    return path, op, rhs


def load_tasks(path=TASKS_FILE):
    # Load and validate every task in the file.
    data = tomllib.loads(Path(path).read_text())
    return [validate_task(raw) for raw in data.get('task', [])]


def validate_task(raw):
    # Check one [[task]] table. Raise TaskError on the first problem.
    tid = raw.get('id', '?')
    for key in ('id', 'area', 'title', 'steps', 'expected', 'needs', 'automation'):
        if key not in raw:
            raise TaskError('%s: missing %s' % (tid, key))
    if not ID_PATTERN.fullmatch(str(raw['id'])):
        raise TaskError('%s: id must be lowercase words joined by hyphens' % tid)
    if raw['area'] not in AREAS:
        raise TaskError('%s: unknown area %r' % (tid, raw['area']))
    if raw['automation'] not in AUTOMATION:
        raise TaskError('%s: unknown automation %r' % (tid, raw['automation']))
    needs = raw['needs']
    if not isinstance(needs, list) or not needs or any(n not in NEEDS for n in needs):
        raise TaskError('%s: needs must be a non-empty list of %s' % (tid, ', '.join(NEEDS)))
    for key in ('steps', 'expected'):
        value = raw[key]
        if not isinstance(value, list) or not value or not all(isinstance(s, str) for s in value):
            raise TaskError('%s: %s must be a non-empty list of strings' % (tid, key))
    actions = list(raw.get('actions', []))
    checks = list(raw.get('checks', []))
    if raw['automation'] == 'auto':
        if not actions or not checks:
            raise TaskError('%s: auto tasks need actions and checks' % tid)
        for line in actions:
            try:
                parse_action(line)
            except TaskError as problem:
                raise TaskError('%s: %s' % (tid, problem))
        for line in checks:
            try:
                parse_check(line)
            except TaskError as problem:
                raise TaskError('%s: %s' % (tid, problem))
    elif actions or checks:
        raise TaskError('%s: only auto tasks may have actions and checks' % tid)
    return Task(raw['id'], raw['area'], raw['title'], raw['steps'], raw['expected'], needs,
                raw['automation'], actions, checks)


def select(tasks, only=(), areas=(), needs=(), automation=()):
    # Keep tasks that match every given filter.
    chosen = []
    for task in tasks:
        if only and task.id not in only:
            continue
        if areas and task.area not in areas:
            continue
        if needs and not set(task.needs) & set(needs):
            continue
        if automation and task.automation not in automation:
            continue
        chosen.append(task)
    return chosen


def run_cmd(args, env=None, timeout=5.0):
    # Run one command and return (returncode, stdout, stderr). Missing tools raise Blocked.
    full = dict(os.environ)
    full.update(env or {})
    try:
        done = subprocess.run(args, env=full, capture_output=True, text=True, timeout=timeout,
                              stdin=subprocess.DEVNULL)
    except FileNotFoundError as problem:
        raise Blocked('%s is not installed' % args[0]) from problem
    except subprocess.TimeoutExpired:
        return 124, '', 'timed out'
    return done.returncode, done.stdout.strip(), done.stderr.strip()


def lua_window(address, body):
    # Wrap a Lua body that acts on one window by address.
    if not ADDRESS.fullmatch(address):
        raise TaskError('bad window address %r' % address)
    return 'local w=hl.get_window("address:%s"); assert(w and w.mapped,"window gone"); %s' % (address, body)


FOCUS_BODY = ('if w.monitor then hl.dispatch(hl.dsp.focus({monitor=w.monitor})) end; '
              'if w.workspace then hl.dispatch(hl.dsp.focus({workspace=w.workspace})) end; '
              'hl.dispatch(hl.dsp.focus({window=w}))')


class Hypr:
    """Calls hyprctl for one explicit Hyprland instance signature."""

    def __init__(self, signature, runner=run_cmd):
        self.signature = signature
        self.runner = runner

    def call(self, args):
        code, out, err = self.runner(args, {'HYPRLAND_INSTANCE_SIGNATURE': self.signature})
        if code:
            raise HyprError('%s failed: %s' % (' '.join(args[:3]), err or out))
        return out

    def json(self, *args):
        return json.loads(self.call(['hyprctl', '-j', *args]) or 'null')

    def eval(self, code):
        out = self.call(['hyprctl', 'eval', code])
        if out.strip() != 'ok':
            raise HyprError(out[:240])
        return out

    def monitors(self):
        return self.json('monitors')

    def clients(self):
        return [c for c in self.json('clients') if c.get('mapped')]


def window_code(address, action, args):
    # Build the Lua code for one window action.
    if action == 'float':
        mode = {'on': 'enable', 'off': 'disable', 'toggle': 'toggle'}[args[0]]
        return lua_window(address, 'hl.dispatch(hl.dsp.window.float({action="%s",window=w}))' % mode)
    if action == 'fullscreen':
        mode = int(args[0])
        if mode == 0:
            body = 'hl.dispatch(hl.dsp.window.fullscreen_state({internal=0,client=0,action="set",window=w}))'
        else:
            kind = 'fullscreen' if mode == 2 else 'maximized'
            body = 'hl.dispatch(hl.dsp.window.fullscreen({mode="%s",action="set",window=w}))' % kind
        return lua_window(address, body)
    if action == 'move':
        target = args[0]
        body = 'hl.dispatch(hl.dsp.window.move({workspace="%s",follow=false,window=w}))' % target
        if len(args) > 1 and args[1] == 'follow':
            body += '; hl.dispatch(hl.dsp.focus({workspace="%s"})); hl.dispatch(hl.dsp.focus({window=w}))' % target
        return lua_window(address, body)
    if action == 'close':
        return lua_window(address, 'hl.dispatch(hl.dsp.window.close({window=w}))')
    if action == 'minimize':
        return lua_window(address, 'hl.dispatch(hl.dsp.window.move({workspace="special:opal-minimized",'
                                   'follow=false,window=w}))')
    if action == 'restore':
        return window_code(address, 'move', [args[0], 'follow'])
    if action == 'place':
        x, y, width, height = (int(v) for v in args[:4])
        return lua_window(address, 'hl.dispatch(hl.dsp.window.resize({x=%d,y=%d,exact=true,window=w})); '
                                   'hl.dispatch(hl.dsp.window.move({x=%d,y=%d,exact=true,window=w}))'
                          % (width, height, x, y))
    if action == 'focus':
        return lua_window(address, FOCUS_BODY)
    if action == 'to-monitor':
        return lua_window(address, 'hl.dispatch(hl.dsp.window.move({monitor="%s",window=w}))' % args[0])
    raise TaskError('unknown window action %s' % action)


def normalize(value):
    # Convert a value to the text that checks compare.
    if value is None:
        return ''
    if isinstance(value, bool):
        return 'true' if value else 'false'
    return str(value)


def unquote(text):
    if len(text) >= 2 and text[0] == text[-1] and text[0] in '"\'':
        return text[1:-1]
    return text


def compare(lhs, op, rhs_text):
    # Return (holds, shown) for one comparison.
    rhs = unquote(rhs_text)
    shown = normalize(lhs)
    if op == 'contains':
        return rhs in shown, shown
    if op in ('==', '!='):
        equal = shown == rhs
        return (equal if op == '==' else not equal), shown
    try:
        left, right = float(shown), float(rhs)
    except ValueError:
        return False, shown
    holds = {'>': left > right, '<': left < right, '>=': left >= right, '<=': left <= right}[op]
    return holds, shown


def parse_bracket(text):
    # Parse [a=b,c=d] or [bare] into a dict.
    out = {}
    for item in (text or '').split(','):
        if not item:
            continue
        if '=' in item:
            key, value = item.split('=', 1)
            out[key.strip()] = value.strip()
        else:
            out['_'] = item.strip()
    return out


class Session:
    """Nested Hyprland plus the commands the tasks use. Holds only handles the harness started."""

    def __init__(self, signature, socket, bus, state_dir, owned):
        self.signature = signature
        self.hypr = Hypr(signature)
        self.socket = socket
        self.bus = bus
        self.state_dir = Path(state_dir)
        self.owned = owned
        self.procs = []
        self.clients = []
        self.bus_pid = None
        self.shell = None
        self.shell_pid = None
        self.baseline = set()

    def env(self):
        env = dict(os.environ)
        env.pop('DISPLAY', None)
        env['HYPRLAND_INSTANCE_SIGNATURE'] = self.signature
        if self.socket:
            env['WAYLAND_DISPLAY'] = self.socket
        if self.bus:
            env['DBUS_SESSION_BUS_ADDRESS'] = self.bus
        return env

    def spawn(self, args):
        # Start a client on the nested session. Teardown closes its window and stops the process.
        self.clients.append(subprocess.Popen(args, env=self.env(), stdin=subprocess.DEVNULL,
                                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                             start_new_session=True))

    def need(self, what, value):
        if not value:
            raise Blocked('%s is not available in this session' % what)

    def ipc(self, args):
        # Call the opal IPC on the nested shell. args is [function, arg...].
        self.need('the Opal shell', self.shell_pid)
        self.need('a private DBus', self.bus)
        command = ['quickshell', 'ipc', '--pid', str(self.shell_pid), 'call', 'opal', *args]
        code, out, err = run_cmd(command, self.env(), timeout=10)
        if code:
            raise Blocked('Opal IPC did not answer: %s' % (err or out)[:200])
        return out

    def notify(self, args):
        self.need('a private DBus', self.bus)
        code, _, err = run_cmd(['notify-send', '-a', args[0], *args[1:]], self.env())
        if code:
            raise Blocked('notify-send failed: %s' % err[:200])

    def clipboard_set(self, text):
        self.need('a Wayland socket', self.socket)
        # wl-copy forks to keep serving the selection, so its output must not be piped.
        copier = subprocess.Popen(['wl-copy', '--', text], env=self.env(), stdin=subprocess.DEVNULL,
                                  stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            code = copier.wait(timeout=5)
        except subprocess.TimeoutExpired:
            copier.kill()
            raise Blocked('wl-copy did not return')
        if code:
            raise Blocked('wl-copy failed with code %d' % code)

    def clipboard_get(self):
        self.need('a Wayland socket', self.socket)
        code, out, _ = run_cmd(['wl-paste', '--no-newline'], self.env(), timeout=3)
        return out if code == 0 else ''

    def screenshot(self, name, task_id):
        self.need('a Wayland socket', self.socket)
        out_dir = self.state_dir / 'shots'
        out_dir.mkdir(parents=True, exist_ok=True)
        path = out_dir / ('%s-%s.png' % (task_id, name))
        monitors = self.hypr.monitors()
        output = next((m['name'] for m in monitors if m['name'] == 'WAYLAND-1'), monitors[0]['name'])
        code, _, err = run_cmd(['grim', '-o', output, str(path)], self.env(), timeout=10)
        if code:
            raise Blocked('grim failed: %s' % err[:200])
        return str(path)

    def stop(self):
        # Stop only the processes this harness started.
        for proc in self.clients:
            if proc.poll() is None:
                proc.terminate()
        if self.shell is not None and self.owned:
            stop_group(self.shell)
        if self.owned:
            for proc in self.procs:
                stop_group(proc)
            if self.bus_pid:
                try:
                    os.kill(self.bus_pid, signal.SIGTERM)
                except OSError:
                    pass


def stop_group(proc):
    # Stop a process started with start_new_session, then its group.
    try:
        os.killpg(proc.pid, signal.SIGTERM)
    except OSError:
        pass
    try:
        proc.wait(timeout=3)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except OSError:
            pass
        proc.wait()


class TaskRun:
    """Runs one task against a session and tracks what it created."""

    def __init__(self, session, task):
        self.session = session
        self.task = task
        self.created_outputs = []
        self.shots = {}
        self.log = []

    @property
    def hypr(self):
        return self.session.hypr

    def resolve_window(self, selector):
        # Return the address for a selector: active, address=X, or key=value.
        if selector == 'active':
            active = self.hypr.json('activewindow')
            return active.get('address') if active else None
        if selector.startswith('address='):
            return selector.split('=', 1)[1]
        if '=' not in selector:
            raise TaskError('selector needs key=value or active: %s' % selector)
        key, value = selector.split('=', 1)
        for client in self.hypr.clients():
            if str(client.get(key)) == value:
                return client['address']
        return None

    def require_window(self, selector):
        address = self.resolve_window(selector)
        if not address:
            raise Fail('no window matches %s' % selector)
        return address

    def resolve_output(self, name):
        if name == 'last':
            if not self.created_outputs:
                raise Fail('no headless output was created in this task')
            return self.created_outputs[-1]
        return name

    def act(self, line):
        # Run one action line.
        verb, rest = parse_action(line)
        args = shlex.split(rest)
        if verb == 'spawn':
            self.session.spawn(args)
        elif verb == 'workspace':
            self.hypr.eval('hl.dispatch(hl.dsp.focus({workspace="%s"}))' % args[0])
        elif verb == 'window':
            address = self.require_window(args[0])
            if args[1] == 'to-monitor':
                args = [args[0], 'to-monitor', self.resolve_output(args[2])]
            if args[1] == 'place':
                self.hypr.eval(lua_window(address, 'hl.dispatch(hl.dsp.window.float({action="enable",window=w}))'))
            self.hypr.eval(window_code(address, args[1], args[2:]))
        elif verb == 'layout':
            self.hypr.eval('hl.config({general={["layout"]="%s"}})' % args[0])
        elif verb == 'output':
            self.output(args)
        elif verb == 'ipc':
            self.session.ipc(args)
        elif verb == 'notify':
            self.session.notify(args)
        elif verb == 'clip-set':
            self.session.clipboard_set(' '.join(args))
        elif verb == 'screenshot':
            self.shots[args[0]] = self.session.screenshot(args[0], self.task.id)
        elif verb == 'sleep':
            time.sleep(float(args[0]))
        elif verb == 'wait':
            seconds, check = rest.split(None, 1)
            self.expect(check, float(seconds))
        self.log.append('ok: %s' % line)

    def output(self, args):
        if args[:2] == ['create', 'headless']:
            before = {m['name'] for m in self.hypr.monitors()}
            self.hypr.call(['hyprctl', 'output', 'create', 'headless'])
            new = [m['name'] for m in self.hypr.monitors() if m['name'] not in before]
            if not new:
                raise Fail('headless output did not appear')
            self.created_outputs.append(new[-1])
        elif args[0] == 'remove':
            name = self.resolve_output(args[1])
            self.hypr.call(['hyprctl', 'output', 'remove', name])
            if name in self.created_outputs:
                self.created_outputs.remove(name)
        else:
            name = self.resolve_output(args[1])
            self.hypr.eval('hl.monitor({output="%s",mode="preferred",position="auto",scale="auto",transform=%d})'
                           % (name, int(args[2])))

    def expect(self, text, timeout):
        # Poll one check until it holds or the timeout ends.
        deadline = time.monotonic() + timeout
        while True:
            holds, shown = self.evaluate(text)
            if holds:
                self.log.append('check ok: %s' % text)
                return
            if time.monotonic() >= deadline:
                raise Fail('%s (got %s)' % (text, shown))
            time.sleep(0.2)

    def evaluate(self, text):
        # Return (holds, shown) for one check line.
        path, op, rhs = parse_check(text)
        value = self.query(path)
        if op is None:
            shown = normalize(value)
            return shown not in ('', 'false', '0'), shown
        if re.match(r'(%s)[.\[]' % '|'.join(QUERY_ROOTS), rhs):
            rhs = normalize(self.query(rhs))
        return compare(value, op, rhs)

    def query(self, path):
        # Resolve one dotted query against the nested compositor state. Missing things give None.
        parts = [(name, args or None) for name, args in PATH_SEGMENT.findall(path)]
        root, root_args = parts[0]
        rest = parts[1:]
        try:
            return self.resolve(root, root_args, rest)
        except Fail:
            return None

    def resolve(self, root, root_args, rest):
        if root == 'active':
            address = self.require_window('active')
            return self.window_field(address, rest[0][0])
        if root == 'clients':
            field_name, filters = rest[0][0], parse_bracket(rest[0][1])
            selected = [c for c in self.hypr.clients() if self.matches(c, filters)]
            if field_name == 'count':
                return len(selected)
            if field_name == 'outside':
                return sum(1 for c in selected if not self.inside_monitor(c))
            raise TaskError('unknown clients field %s' % field_name)
        if root == 'monitors':
            monitors = self.hypr.monitors()
            if rest[0][0] == 'count':
                return len(monitors)
            if rest[0][0] == 'names':
                return ','.join(m['name'] for m in monitors)
            raise TaskError('unknown monitors field %s' % rest[0][0])
        if root == 'monitor':
            return self.monitor_field(self.resolve_output(root_args), rest[0][0])
        if root == 'window':
            return self.window_field(self.require_window(root_args), rest[0][0])
        if root == 'workspace':
            return self.workspace_field(root_args, rest[0][0])
        if root == 'layout':
            return self.hypr.json('getoption', 'general:layout').get('str')
        if root == 'ipc':
            if root_args is None:
                raise TaskError('ipc needs a function, for example ipc[inspect]')
            text = self.session.ipc([root_args])
            if not rest:
                return text
            return resolve_path(json.loads(text), [name for name, _ in rest])
        if root == 'clipboard':
            return self.session.clipboard_get()
        if root == 'shot':
            return self.shot_field(root_args, rest[0][0])
        raise TaskError('unknown query root %s' % root)

    def matches(self, client, filters):
        for key, value in filters.items():
            if key == 'ws':
                if value not in (str(client['workspace']['id']), client['workspace']['name']):
                    return False
            elif key == 'floating':
                if normalize(bool(client.get('floating'))) != value:
                    return False
            elif key == 'fullscreen':
                if normalize(bool(client.get('fullscreen'))) != value:
                    return False
            elif key == 'monitor':
                if self.monitor_name(client.get('monitor')) != value:
                    return False
            elif key in ('class', 'title'):
                if client.get(key) != value:
                    return False
            else:
                raise TaskError('unknown client filter %s' % key)
        return True

    def monitor_name(self, monitor_id):
        for monitor in self.hypr.monitors():
            if monitor.get('id') == monitor_id:
                return monitor['name']
        return ''

    def inside_monitor(self, client):
        monitor = next((m for m in self.hypr.monitors() if m.get('id') == client.get('monitor')), None)
        if not monitor:
            return False
        scale = monitor.get('scale') or 1
        width, height = monitor['width'] / scale, monitor['height'] / scale
        x, y = client['at']
        w, h = client['size']
        return (monitor['x'] <= x and monitor['y'] <= y
                and x + w <= monitor['x'] + width and y + h <= monitor['y'] + height)

    def window_field(self, address, field_name):
        client = next((c for c in self.hypr.clients() if c['address'] == address), None)
        if client is None:
            raise Fail('window is gone')
        fields = {
            'x': lambda c: c['at'][0], 'y': lambda c: c['at'][1],
            'width': lambda c: c['size'][0], 'height': lambda c: c['size'][1],
            'floating': lambda c: c.get('floating'), 'fullscreen': lambda c: c.get('fullscreen'),
            'workspace': lambda c: c['workspace']['id'], 'workspace_name': lambda c: c['workspace']['name'],
            'monitor_name': lambda c: self.monitor_name(c.get('monitor')),
            'class': lambda c: c.get('class'), 'title': lambda c: c.get('title'),
            'address': lambda c: c.get('address'),
        }
        if field_name not in fields:
            raise TaskError('unknown window field %s' % field_name)
        return fields[field_name](client)

    def monitor_field(self, name, field_name):
        monitor = next((m for m in self.hypr.monitors() if m['name'] == name), None)
        if monitor is None:
            raise Fail('no monitor named %s' % name)
        if field_name not in ('width', 'height', 'x', 'y', 'scale', 'transform', 'name'):
            raise TaskError('unknown monitor field %s' % field_name)
        return monitor[field_name]

    def workspace_field(self, args, field_name):
        monitors = self.hypr.monitors()
        focused = next((m for m in monitors if m.get('focused')), monitors[0])
        if args is None:
            if field_name == 'current':
                return focused['activeWorkspace']['id']
            if field_name == 'name':
                return focused['activeWorkspace']['name']
            raise TaskError('unknown workspace field %s' % field_name)
        for ws in self.hypr.json('workspaces'):
            if args in (str(ws['id']), ws['name']) and field_name == 'windows':
                return ws['windows']
        return 0

    def shot_field(self, name, field_name):
        path = self.shots.get(name)
        if not path:
            raise Fail('no screenshot named %s' % name)
        data = Path(path).read_bytes()
        if field_name == 'bytes':
            return len(data)
        if data[:8] != PNG:
            raise Fail('screenshot is not a PNG')
        if field_name == 'png':
            return True
        offset = {'width': 16, 'height': 20}.get(field_name)
        if offset is None:
            raise TaskError('unknown shot field %s' % field_name)
        return int.from_bytes(data[offset:offset + 4], 'big')

    def teardown(self):
        # Close windows and outputs this task made, then return to workspace 1.
        for client in self.hypr.clients():
            if client['address'] not in self.session.baseline:
                try:
                    self.hypr.eval(lua_window(client['address'], 'hl.dispatch(hl.dsp.window.close({window=w}))'))
                except (HyprError, Blocked, TaskError):
                    pass
        for name in list(self.created_outputs):
            try:
                self.hypr.call(['hyprctl', 'output', 'remove', name])
            except (HyprError, Blocked):
                pass
        self.created_outputs = []
        if self.session.shell_pid:
            try:
                self.session.ipc(['close'])
            except Blocked:
                pass
        for code in ('hl.dispatch(hl.dsp.focus({workspace="1"}))',
                     'hl.config({general={["layout"]="dwindle"}})'):
            try:
                self.hypr.eval(code)
            except (HyprError, Blocked):
                pass
        for proc in self.session.clients:
            if proc.poll() is None:
                proc.terminate()
        self.session.clients = []


def resolve_path(data, segments):
    # Walk a JSON value with dotted segments; digits index lists.
    for segment in segments:
        if isinstance(data, dict):
            data = data.get(segment)
        elif isinstance(data, list) and segment.isdigit() and int(segment) < len(data):
            data = data[int(segment)]
        else:
            return None
    return data


def wait_for(predicate, timeout, step=0.2):
    # Poll until predicate returns a truthy value or the timeout ends.
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        value = predicate()
        if value:
            return value
        time.sleep(step)
    return None


def start_bus():
    # Start a private session bus. Returns (address, pid) or (None, None).
    try:
        done = subprocess.run(['dbus-daemon', '--session', '--fork', '--print-address=1', '--print-pid=1'],
                              capture_output=True, text=True, timeout=10)
    except FileNotFoundError:
        return None, None
    lines = done.stdout.split()
    if done.returncode or len(lines) < 2:
        return None, None
    return lines[0], int(lines[1])


def start_nested(state_dir, width, height, shell, shell_src):
    # Start virtual KWin and a Hyprland inside it. Returns a Session that owns those processes.
    runtime = os.environ.get('XDG_RUNTIME_DIR') or '/run/user/%d' % os.getuid()
    state_dir = Path(state_dir)
    state_dir.mkdir(parents=True, exist_ok=True)
    bus, bus_pid = start_bus()
    socket_name = 'opal-suite-%d' % os.getpid()
    kwin_env = dict(os.environ)
    kwin_env.pop('DISPLAY', None)
    kwin_env.pop('HYPRLAND_INSTANCE_SIGNATURE', None)
    kwin_env.pop('WAYLAND_DISPLAY', None)
    if bus:
        kwin_env['DBUS_SESSION_BUS_ADDRESS'] = bus
    kwin_log = open(state_dir / 'kwin.log', 'w')
    kwin = subprocess.Popen(['kwin_wayland', '--virtual', '--socket', socket_name, '--width', str(width + 40),
                             '--height', str(height + 40), '--no-lockscreen'], env=kwin_env, stdout=kwin_log,
                            stderr=subprocess.STDOUT, start_new_session=True)
    session = Session(None, socket_name, bus, state_dir, owned=True)
    session.procs = [kwin]
    session.bus_pid = bus_pid
    if not wait_for(lambda: os.path.exists(os.path.join(runtime, socket_name)) or kwin.poll() is not None, 10):
        session.stop()
        raise Blocked('virtual KWin did not start; see %s' % (state_dir / 'kwin.log'))
    before_hypr = set(os.listdir(os.path.join(runtime, 'hypr')))
    before_sockets = set(os.listdir(runtime))
    config = state_dir / 'hyprland.lua'
    config.write_text('hl.monitor({ output = "WAYLAND-1", mode = "%dx%d", position = "0x0", scale = 1 })\n'
                      'hl.config({ misc = { disable_hyprland_logo = true, disable_splash_rendering = true },'
                      ' cursor = { no_warps = true } })\n' % (width, height))
    hypr_env = dict(os.environ)
    hypr_env.pop('DISPLAY', None)
    hypr_env.pop('HYPRLAND_INSTANCE_SIGNATURE', None)
    hypr_env['WAYLAND_DISPLAY'] = socket_name
    if bus:
        hypr_env['DBUS_SESSION_BUS_ADDRESS'] = bus
    hypr_log = open(state_dir / 'hyprland.log', 'w')
    hyprland = subprocess.Popen(['Hyprland', '-c', str(config)], env=hypr_env, stdout=hypr_log,
                                stderr=subprocess.STDOUT, start_new_session=True)
    session.procs.append(hyprland)

    def new_signature():
        for name in sorted(set(os.listdir(os.path.join(runtime, 'hypr'))) - before_hypr):
            if os.path.exists(os.path.join(runtime, 'hypr', name, 'hyprland.lock')):
                return name
        return None

    signature = wait_for(new_signature, 20)
    if not signature:
        session.stop()
        raise Blocked('Hyprland did not start; see %s' % (state_dir / 'hyprland.log'))
    check_signature(signature, os.environ.get('HYPRLAND_INSTANCE_SIGNATURE'))
    session.signature = signature
    session.hypr = Hypr(signature)
    fresh = [n for n in os.listdir(runtime) if n.startswith('wayland-') and n.endswith('.lock')
             and n not in before_sockets]
    if fresh:
        session.socket = fresh[0][:-len('.lock')]
    if not wait_for(lambda: _answers(session.hypr), 15):
        session.stop()
        raise Blocked('nested Hyprland does not answer hyprctl')
    if shell:
        try:
            start_shell(session, shell_src)
        except Blocked:
            session.stop()
            raise
    return session


def _answers(hypr):
    try:
        hypr.monitors()
        return True
    except (HyprError, Blocked, ValueError):
        return False


def start_shell(session, shell_src):
    # Start the Opal shell in the foreground so the harness owns its process.
    shell_state = session.state_dir / 'opal-state'
    shell_state.mkdir(parents=True, exist_ok=True)
    (shell_state / 'preferences.json').write_text(json.dumps(
        {'mode': 'desktop', 'floatingMode': True, 'linkEnabled': False, 'themeExport': [], 'onboarded': True},
        indent=1))
    env = session.env()
    env.update({'OPAL_STATE_DIR': str(shell_state), 'OPAL_NESTED': '1'})
    log = open(session.state_dir / 'shell.log', 'w')
    shell = subprocess.Popen(['quickshell', '-n', '-p', str(shell_src)], env=env, stdout=log,
                             stderr=subprocess.STDOUT, start_new_session=True)
    session.shell = shell
    session.shell_pid = shell.pid
    session.owned_shell = True
    if not wait_for(lambda: _shell_answers(session), ANSWER_TIMEOUT):
        raise Blocked('Opal shell did not answer IPC; see %s' % (session.state_dir / 'shell.log'))


def _shell_answers(session):
    try:
        session.ipc(['inspect'])
        return True
    except Blocked:
        return False


def attach(signature, allow_real, shell_pid=None):
    # Attach to an existing Hyprland. The harness owns nothing and signals nothing in it.
    live = os.environ.get('HYPRLAND_INSTANCE_SIGNATURE')
    if not signature:
        raise SystemExit('Refusing: an empty signature.')
    if signature == live and not allow_real:
        raise SystemExit('Refusing: this is the live Hyprland session. Use a nested instance or pass '
                         '--i-know-this-is-my-session.')
    hypr = Hypr(signature)
    try:
        monitors = hypr.monitors()
    except (HyprError, Blocked, ValueError) as problem:
        raise SystemExit('Cannot reach Hyprland %s: %s' % (signature, problem))
    if not all(NESTED_OUTPUT.fullmatch(m.get('name', '')) for m in monitors) and not allow_real:
        raise SystemExit('Refusing: outputs %s look like a real session. Pass '
                         '--i-know-this-is-my-session to allow it.'
                         % ', '.join(m.get('name', '?') for m in monitors))
    session = Session(signature, None, None, DEFAULT_STATE, owned=False)
    session.shell_pid = shell_pid
    return session


def task_rows(tasks):
    return [(t.id, t.area, t.automation, ','.join(t.needs), t.title) for t in tasks]


def print_table(headers, rows):
    # Print a compact aligned table.
    widths = [len(h) for h in headers]
    for row in rows:
        for i, cell in enumerate(row):
            widths[i] = max(widths[i], len(str(cell)))
    print('  '.join(h.ljust(widths[i]) for i, h in enumerate(headers)))
    print('  '.join('-' * w for w in widths))
    for row in rows:
        print('  '.join(str(cell).ljust(widths[i]) for i, cell in enumerate(row)))


def dry_run(tasks):
    # Print the plan for each task without touching Hyprland.
    for task in tasks:
        print('%s [%s/%s] %s' % (task.id, task.area, task.automation, task.title))
        if task.automation == 'auto':
            for line in task.actions:
                print('    do:    %s' % line)
            for line in task.checks:
                print('    check: %s' % line)
        else:
            print('    manual steps: %d, expected: %d (not automated)' % (len(task.steps), len(task.expected)))


def run_one(session, task):
    # Run one task and always tear down afterwards.
    if task.automation != 'auto':
        return {'id': task.id, 'area': task.area, 'status': 'not-automated', 'seconds': 0.0,
                'detail': task.automation, 'log': []}
    extra = set(task.needs) - {'nested-hyprland'}
    if extra:
        return {'id': task.id, 'area': task.area, 'status': 'skipped', 'seconds': 0.0,
                'detail': 'needs %s' % ','.join(sorted(extra)), 'log': []}
    run = TaskRun(session, task)
    started = time.monotonic()
    status, detail = 'pass', ''
    try:
        for line in task.actions:
            run.act(line)
        for line in task.checks:
            run.expect(line, 5.0)
    except Fail as problem:
        status, detail = 'fail', str(problem)
    except Blocked as problem:
        status, detail = 'blocked', str(problem)
    except (HyprError, TaskError, OSError, ValueError, KeyError, IndexError) as problem:
        status, detail = 'error', '%s: %s' % (type(problem).__name__, problem)
    finally:
        run.teardown()
    return {'id': task.id, 'area': task.area, 'status': status, 'seconds': round(time.monotonic() - started, 2),
            'detail': detail, 'log': run.log}


def summarize(results):
    counts = {status: 0 for status in STATUSES}
    for result in results:
        counts[result['status']] += 1
    return counts


def main(argv=None):
    parser = argparse.ArgumentParser(description='Luna desktop suite runner.')
    parser.add_argument('--list', action='store_true', help='list selected tasks and exit')
    parser.add_argument('--dry-run', action='store_true', help='print the plan and exit; nothing runs')
    parser.add_argument('--only', action='append', default=[], help='task id (repeatable or comma list)')
    parser.add_argument('--area', action='append', default=[], help='area (repeatable or comma list)')
    parser.add_argument('--needs', action='append', default=[], help='needs value (repeatable or comma list)')
    parser.add_argument('--automation', action='append', default=[], help='auto, semi or manual')
    parser.add_argument('--signature', help='attach to this nested Hyprland instead of starting one')
    parser.add_argument('--shell-pid', type=int, help='PID of the Opal shell in an attached session')
    parser.add_argument('--i-know-this-is-my-session', action='store_true',
                        help='allow attaching to a session that does not look nested')
    parser.add_argument('--no-shell', action='store_true', help='do not start the Opal shell')
    parser.add_argument('--shell-path', default=str(SHELL_SRC), help='shell.qml to run in the nested session')
    parser.add_argument('--keep-session', action='store_true', help='leave a started nested session running')
    parser.add_argument('--state-dir', default=str(DEFAULT_STATE / time.strftime('run-%Y%m%d-%H%M%S')))
    parser.add_argument('--report', help='JSON report path (default: state dir report.json)')
    parser.add_argument('--width', type=int, default=1600)
    parser.add_argument('--height', type=int, default=1000)
    args = parser.parse_args(argv)

    def split(values):
        return [v for item in values for v in item.split(',') if v]

    try:
        tasks = load_tasks()
    except TaskError as problem:
        print('Task file is invalid: %s' % problem, file=sys.stderr)
        return 2
    chosen = select(tasks, only=split(args.only), areas=split(args.area), needs=split(args.needs),
                    automation=split(args.automation))
    if args.list:
        print_table(['id', 'area', 'auto', 'needs', 'title'], task_rows(chosen))
        print('%d tasks' % len(chosen))
        return 0
    if args.dry_run:
        dry_run(chosen)
        return 0
    autos = [t for t in chosen if t.automation == 'auto']
    if not autos:
        print('No automated tasks selected; use --list or --dry-run for the rest.')
        return 0
    session = None
    mode = 'attach' if args.signature else 'start'
    results = []
    try:
        if args.signature:
            session = attach(args.signature, args.i_know_this_is_my_session, args.shell_pid)
        else:
            session = start_nested(args.state_dir, args.width, args.height, not args.no_shell, args.shell_path)
        session.baseline = {c['address'] for c in session.hypr.clients()}
        for task in autos:
            results.append(run_one(session, task))
    except SystemExit as problem:
        print(problem, file=sys.stderr)
        return 2
    except Blocked as problem:
        print('Blocked: %s' % problem, file=sys.stderr)
        return 2
    finally:
        if session is not None and mode == 'start' and session.owned:
            if args.keep_session:
                print('Kept nested session: HYPRLAND_INSTANCE_SIGNATURE=%s' % session.signature)
            else:
                session.stop()
    report = {'started': datetime.datetime.now().isoformat(timespec='seconds'), 'mode': mode,
              'signature': session.signature, 'summary': summarize(results), 'results': results}
    report_path = Path(args.report) if args.report else Path(args.state_dir) / 'report.json'
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, indent=1))
    print_table(['id', 'area', 'status', 's', 'detail'],
                [(r['id'], r['area'], r['status'], r['seconds'], r['detail'][:90]) for r in results])
    print('Summary: %s' % ', '.join('%s=%d' % kv for kv in report['summary'].items() if kv[1]))
    print('Report: %s' % report_path)
    return 1 if report['summary']['fail'] or report['summary']['error'] else 0


if __name__ == '__main__':
    sys.exit(main())
