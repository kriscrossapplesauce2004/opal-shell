"""Deterministic Smart Back for Opal Phone & Tablet mode.

Hierarchy when Back is triggered with an app in front:
1. Android (Waydroid) window (`className` starts with `waydroid`) -> `waydroid_bridge.send_back()` (`KEYCODE_BACK`).
2. Transient/modal dialog window -> `Escape` keychord via `hypr_actions.send_shortcut`.
3. Browser / file manager / document reader -> `Alt+Left` via `hypr_actions.send_shortcut`.
4. Fallback -> focus the previous MRU window via `hypr_actions.focus`.
"""
import hypr_actions
import waydroid_bridge

ALT_LEFT_CLASSES = (
    'firefox', 'librewolf', 'zen', 'floorp', 'waterfox',
    'chromium', 'google-chrome', 'brave-browser', 'vivaldi', 'microsoft-edge',
    'org.kde.dolphin', 'dolphin', 'org.gnome.nautilus', 'nautilus',
    'thunar', 'pcmanfm', 'nemo', 'org.gnome.epiphany',
)

DIALOG_WORDS = ('dialog', 'preferences', 'properties', 'confirm', 'open file', 'save as', 'save file', 'choose')


def classify_client(client, all_clients=None):
    """Decide what Back action to take for `client`."""
    if not isinstance(client, dict) or not client.get('address'):
        return {'op': 'none'}
    address = client['address']
    cls = str(client.get('class') or client.get('className') or '').strip().lower()
    title = str(client.get('title') or '').strip().lower()

    if cls.startswith('waydroid'):
        return {'op': 'waydroid', 'address': address}

    # Transient/modal dialog check: floating window whose title looks like a dialog or shares a class with another window on the same workspace.
    if client.get('floating'):
        same_class_peers = [
            c for c in (all_clients or [])
            if c.get('address') != address
            and str(c.get('class') or c.get('className') or '').strip().lower() == cls
        ]
        if same_class_peers or any(w in title for w in DIALOG_WORDS):
            return {'op': 'shortcut', 'mods': [], 'key': 'Escape', 'address': address}

    if any(cls == k or cls.endswith('.' + k) or k in cls for k in ALT_LEFT_CLASSES):
        return {'op': 'shortcut', 'mods': ['ALT'], 'key': 'Left', 'address': address}

    # Fallback to previous window in focus history
    candidates = [
        c for c in (all_clients or [])
        if c.get('address') != address and int(c.get('workspace', {}).get('id', 0)) > 0
    ]
    candidates.sort(key=lambda c: int(c.get('focusHistoryID', 999)))
    if candidates:
        return {'op': 'focus', 'address': candidates[0]['address']}
    return {'op': 'none'}


def execute_back(actions=None, waydroid=None):
    """Inspect Hyprland clients and execute the deterministic back step."""
    act = actions or hypr_actions.HyprActions()
    wd = waydroid or waydroid_bridge.WaydroidBridge(lambda _: None)
    try:
        clients = act.clients()
    except Exception:
        return {'op': 'none'}
    focused = next((c for c in clients if c.get('focusHistoryID') == 0), None)
    if not focused and clients:
        focused = clients[0]
    plan = classify_client(focused, clients)
    op = plan.get('op')
    try:
        if op == 'waydroid':
            wd.send_back()
        elif op == 'shortcut':
            act.send_shortcut(plan['mods'], plan['key'], plan['address'])
        elif op == 'focus':
            act.focus(plan['address'])
    except Exception:
        pass
    return plan
