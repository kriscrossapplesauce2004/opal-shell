"""AI-free mode: one preference turns every Claude surface off, and removing AI also disconnects Opal from Claude Code."""
import json, os, pathlib, shutil, subprocess

KEY = 'aiFeatures'
# Ids of AI entries in other preferences. The scrub removes them so no menu, gesture or widget still points at the assistant.
WIDGET = 'claude'
ACTION = 'assistant'
HOOK_MARK = 'activity claude-hook'


def enabled(prefs):
    return prefs.get(KEY) is not False


def valid_preference(key, value):
    return key == KEY and type(value) is bool


def _strip_nodes(nodes):
    out = []
    for node in nodes:
        if not isinstance(node, dict) or node.get('action') == ACTION:
            continue
        if node.get('action') == 'folder' and isinstance(node.get('items'), list):
            node = dict(node, items=_strip_nodes(node['items']))
        out.append(node)
    return out


def scrub(prefs):
    """Return the preference changes that take AI entries out of widgets, gestures and the power key menu."""
    changes = {}
    widgets = prefs.get('consoleWidgets')
    if isinstance(widgets, list) and WIDGET in widgets:
        changes['consoleWidgets'] = [w for w in widgets if w != WIDGET]
    gestures = prefs.get('phoneGestures')
    if isinstance(gestures, dict) and ACTION in gestures.values():
        changes['phoneGestures'] = {k: ('none' if v == ACTION else v) for k, v in gestures.items()}
    menu = prefs.get('powerMenu')
    if isinstance(menu, list):
        stripped = _strip_nodes(menu)
        if stripped != menu:
            changes['powerMenu'] = stripped
    if prefs.get('powerMenuStart') == ACTION:
        changes['powerMenuStart'] = 'sleep'
    press = prefs.get('powerPress')
    if isinstance(press, dict) and any(isinstance(v, dict) and v.get('action') == ACTION for v in press.values()):
        changes['powerPress'] = {k: (None if isinstance(v, dict) and v.get('action') == ACTION else v) for k, v in press.items()}
    return changes


def claude_settings(home=None):
    base = os.environ.get('CLAUDE_CONFIG_DIR') or str(pathlib.Path(home or pathlib.Path.home()) / '.claude')
    return pathlib.Path(base) / 'settings.json'


def has_hooks(path):
    try:
        return HOOK_MARK in path.read_text()
    except OSError:
        return False


def mcp_registered(run=subprocess.run, which=shutil.which):
    if not which('claude'):
        return False
    try:
        return run(['claude', 'mcp', 'get', 'opal'], capture_output=True, timeout=15).returncode == 0
    except (OSError, subprocess.SubprocessError):
        return False


def disconnect(run=subprocess.run, which=shutil.which, home=None, remove_hooks=None):
    """Unregister the Opal MCP server and remove the Opal hooks from Claude Code. Claude Code itself stays installed. Return the steps done."""
    done = []
    if mcp_registered(run, which):
        try:
            if run(['claude', 'mcp', 'remove', '--scope', 'user', 'opal'], capture_output=True, timeout=20).returncode == 0:
                done.append('mcp')
        except (OSError, subprocess.SubprocessError):
            pass
    path = claude_settings(home)
    if has_hooks(path):
        try:
            if remove_hooks is None:
                import opal_activity
                remove_hooks = lambda p: opal_activity.install_hooks(settings_path=p, remove=True)
            remove_hooks(path)
            done.append('hooks')
        except (OSError, ValueError):
            pass
    return done


def connect(server, run=subprocess.run, which=shutil.which):
    """Register the Opal MCP server with Claude Code again. Return True when it is registered."""
    if not which('claude'):
        return False
    if mcp_registered(run, which):
        return True
    try:
        return run(['claude', 'mcp', 'add', '--scope', 'user', 'opal', '--', 'python3', str(server)], capture_output=True, timeout=20).returncode == 0
    except (OSError, subprocess.SubprocessError):
        return False


def status(run=subprocess.run, which=shutil.which, home=None):
    return {'claude': bool(which('claude')), 'mcp': mcp_registered(run, which), 'hooks': has_hooks(claude_settings(home))}
