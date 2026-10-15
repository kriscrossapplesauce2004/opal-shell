#!/usr/bin/env python3
"""The "opal activity" command: push live activities from scripts, wait for a button press, and bridge Claude Code hooks into pills."""
import argparse, json, os, pathlib, subprocess, sys, time

CONFIG = os.environ.get('OPAL_CONFIG_DIR') or str(pathlib.Path(__file__).resolve().parent)
CLAUDE_SETTINGS = pathlib.Path(os.environ.get('CLAUDE_CONFIG_DIR') or pathlib.Path.home() / '.claude') / 'settings.json'
HOOK_MARK = 'activity claude-hook'
OPAL_BIN = os.environ.get('OPAL_BIN') or str(pathlib.Path.home() / '.local/bin/opal')
HOOK_EVENTS = {'UserPromptSubmit': True, 'Notification': True, 'Stop': True, 'SessionEnd': True, 'PermissionRequest': False}


def ipc(function, *args, runner=subprocess.run):
    result = runner(['quickshell', 'ipc', '-p', CONFIG, 'call', 'activity', function, *map(str, args)], capture_output=True, text=True, timeout=10)
    if result.returncode: raise RuntimeError((result.stderr or result.stdout).strip() or 'Opal is not running')
    return result.stdout.strip()


def parse_action(text):
    """Turn "id:Label[:primary|danger]" into a control map."""
    parts = text.split(':')
    control = {'id': parts[0]}
    if len(parts) > 1 and parts[1]: control['label'] = parts[1]
    for flag in parts[2:]:
        if flag in ('primary', 'danger'): control[flag] = True
        elif flag: control['icon'] = flag
    if len(parts) == 1: control['icon'] = parts[0]
    return control


def activity_from(args):
    data = {}
    for key in ('id', 'kind', 'icon', 'title', 'subtitle', 'short', 'meta', 'code', 'ring_text'):
        value = getattr(args, key, None)
        if value is not None: data['ringText' if key == 'ring_text' else key] = value
    if args.progress is not None:
        data['progress'] = -2 if args.progress in ('busy', 'indeterminate') else float(args.progress.rstrip('%')) / (100 if args.progress.endswith('%') else 1)
    if args.text is not None: data['progressText'] = args.text
    if args.app is not None: data['appIcon'] = args.app
    if args.ttl is not None: data['ttl'] = args.ttl
    if args.urgent: data['urgent'] = True
    if args.ring: data['ring'] = True
    if args.action: data['controls'] = [parse_action(a) for a in args.action]
    if args.pid: data['pids'] = process_chain(args.pid)
    return data


def process_chain(pid, proc=pathlib.Path('/proc')):
    """Return the pid and its ancestors, so the shell can find the window that owns the process."""
    chain = []
    while pid and pid > 1 and len(chain) < 16:
        chain.append(pid)
        try: pid = int(pathlib.Path(proc, str(pid), 'stat').read_text().rsplit(')', 1)[1].split()[1])
        except (OSError, ValueError, IndexError): break
    return chain


def wait(ident, timeout, poll=0.3, clock=time.monotonic, sleep=time.sleep, call=ipc):
    """Wait until a button on the activity is pressed. Return the action id, or an empty string on timeout."""
    end = clock() + timeout
    while clock() < end:
        action = call('take', ident)
        if action: return action
        sleep(poll)
    return ''


# Claude Code hooks. One activity per session, named after the session.
def session_id(event):
    return 'cc-' + ''.join(c for c in str(event.get('session_id', 'x')) if c.isalnum())[:12]


def tool_summary(event):
    name = str(event.get('tool_name') or 'a tool')
    data = event.get('tool_input') or {}
    if isinstance(data, dict):
        for key in ('command', 'file_path', 'path', 'url', 'pattern', 'query', 'description'):
            if data.get(key): return name, str(data[key])
    return name, ''


def terminal_focused(chain, runner=subprocess.run):
    """True when the window of this Claude session has focus. Then the user sees the terminal prompt and the pill must not wait."""
    try:
        result = runner(['hyprctl', '-j', 'activewindow'], capture_output=True, text=True, timeout=2)
        return int(json.loads(result.stdout or '{}').get('pid') or 0) in chain
    except (OSError, ValueError, subprocess.SubprocessError, AttributeError):
        return False


def claude_hook(event, call=ipc, focused=terminal_focused, waiter=wait, ppid=None):
    """Turn one Claude Code hook event into an activity change. Return the JSON text that Claude Code reads, or an empty string."""
    name = event.get('hook_event_name', '')
    ident = session_id(event)
    project = pathlib.Path(str(event.get('cwd') or '~')).name or '~'
    chain = process_chain(ppid if ppid is not None else os.getppid())
    base = {'id': ident, 'kind': 'agent', 'icon': 'terminal', 'pids': chain}
    if name == 'UserPromptSubmit':
        call('start', json.dumps(dict(base, title='Claude Code', subtitle=project + ' · working', short='Working', progress=-2,
                                      progressText=str(event.get('prompt') or '')[:80], controls=[{'id': 'open', 'icon': 'open_in_new'}])))
    elif name == 'Notification':
        kind = event.get('notification_type', '')
        if kind in ('permission_prompt', 'idle_prompt', 'agent_needs_input', 'elicitation_dialog'):
            call('start', json.dumps(dict(base, title='Claude Code needs you', subtitle=project + ' · ' + str(event.get('message') or 'Waiting for you'),
                                          short='Needs you', urgent=True, progress=-1, controls=[{'id': 'open', 'label': 'Open', 'primary': True}])))
    elif name == 'PermissionRequest':
        tool, detail = tool_summary(event)
        call('start', json.dumps(dict(base, title='Claude Code needs you', subtitle=project + ' · wants to use ' + tool, short='Needs you', urgent=True,
                                      code=detail[:400], progress=-1, controls=[{'id': 'open', 'icon': 'open_in_new'}, {'id': 'deny', 'label': 'Deny'}, {'id': 'allow', 'label': 'Allow', 'primary': True}])))
        # When the terminal has focus, the user answers there. Do not hold the prompt.
        if focused(chain): return ''
        action = waiter(ident, float(os.environ.get('OPAL_CLAUDE_WAIT', '90')))
        if action in ('allow', 'deny'):
            call('start', json.dumps(dict(base, title='Claude Code', subtitle=project + (' · allowed ' if action == 'allow' else ' · denied ') + tool,
                                          short='Working' if action == 'allow' else 'Denied', progress=-2 if action == 'allow' else -1, controls=[{'id': 'open', 'icon': 'open_in_new'}])))
            decision = {'behavior': action}
            if action == 'deny': decision['message'] = 'The user denied this from the Opal pill.'
            return json.dumps({'hookSpecificOutput': {'hookEventName': 'PermissionRequest', 'decision': decision}})
    elif name == 'Stop':
        call('start', json.dumps(dict(base, title='Claude Code finished', subtitle=project, short='Done', progress=-1, ttl=8,
                                      controls=[{'id': 'open', 'label': 'Open', 'primary': True}])))
    elif name == 'SessionEnd':
        call('end', ident)
    return ''


def hook_command(event_name):
    return {'type': 'command', 'command': OPAL_BIN + ' ' + HOOK_MARK, 'timeout': 120 if event_name == 'PermissionRequest' else 10, **({'async': True} if HOOK_EVENTS[event_name] else {})}


def install_hooks(settings_path=CLAUDE_SETTINGS, remove=False):
    """Add or remove the Opal hooks in Claude Code settings. Other hooks and settings stay as they are."""
    try: settings = json.loads(settings_path.read_text())
    except FileNotFoundError: settings = {}
    hooks = settings.setdefault('hooks', {})
    for event_name in HOOK_EVENTS:
        groups = [g for g in hooks.get(event_name, []) if not any(HOOK_MARK in h.get('command', '') for h in g.get('hooks', []))]
        if not remove: groups.append({'matcher': '', 'hooks': [hook_command(event_name)]})
        if groups: hooks[event_name] = groups
        else: hooks.pop(event_name, None)
    if not hooks: settings.pop('hooks', None)
    settings_path.parent.mkdir(parents=True, exist_ok=True)
    temp = settings_path.with_suffix('.json.opal-tmp')
    temp.write_text(json.dumps(settings, indent=2) + '\n')
    os.replace(temp, settings_path)


def main(argv=None):
    parser = argparse.ArgumentParser(prog='opal activity', description='Show live activities as Opal pills and cards.')
    sub = parser.add_subparsers(dest='verb', required=True)
    for verb in ('start', 'update'):
        p = sub.add_parser(verb)
        p.add_argument('id')
        p.add_argument('--title'); p.add_argument('--subtitle'); p.add_argument('--short'); p.add_argument('--meta'); p.add_argument('--code')
        p.add_argument('--kind', choices=['agent', 'system', 'transfer', 'focus', 'device', 'recording', 'neutral'])
        p.add_argument('--icon', help='Material Symbols name, for example download')
        p.add_argument('--app', help='icon name of the app')
        p.add_argument('--progress', help='0 to 1, a percent like 40%%, or busy')
        p.add_argument('--text', help='text under the progress bar')
        p.add_argument('--ring', action='store_true'); p.add_argument('--ring-text')
        p.add_argument('--action', action='append', help='id:Label[:primary|danger|icon]; repeat for more buttons')
        p.add_argument('--ttl', type=float, help='seconds until the activity goes away')
        p.add_argument('--urgent', action='store_true')
        p.add_argument('--pid', type=int, help='process whose window opens when the card is tapped')
    sub.add_parser('end').add_argument('id')
    w = sub.add_parser('wait'); w.add_argument('id'); w.add_argument('--timeout', type=float, default=300)
    sub.add_parser('list')
    sub.add_parser('claude-hook', help='read one Claude Code hook event on stdin')
    h = sub.add_parser('claude-hooks', help='install or remove the Claude Code hooks'); h.add_argument('mode', choices=['install', 'remove'])
    args = parser.parse_args(argv)
    try:
        if args.verb in ('start', 'update'):
            data = activity_from(args)
            out = ipc('start', json.dumps(data)) if args.verb == 'start' else ipc('update', args.id, json.dumps({k: v for k, v in data.items() if k != 'id'}))
            if not out: print('Opal did not accept the activity', file=sys.stderr); return 1
            print(out)
        elif args.verb == 'end': ipc('end', args.id)
        elif args.verb == 'wait':
            action = wait(args.id, args.timeout)
            if not action: return 1
            print(action)
        elif args.verb == 'list': print(ipc('list'))
        elif args.verb == 'claude-hook':
            try: event = json.load(sys.stdin)
            except ValueError: return 0
            out = claude_hook(event)
            if out: print(out)
        elif args.verb == 'claude-hooks':
            install_hooks(remove=args.mode == 'remove')
            print('Claude Code hooks ' + ('removed from ' if args.mode == 'remove' else 'added to ') + str(CLAUDE_SETTINGS))
    except (RuntimeError, OSError, subprocess.SubprocessError) as error:
        # A hook must never break Claude Code, so it fails quietly.
        if args.verb == 'claude-hook': return 0
        print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
