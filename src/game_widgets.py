"""Read-only data for the console home widgets: Steam updates, storage, captures and Prism instances."""
import json
import os
import pathlib

import game_library

HOME = pathlib.Path.home()
# Steam EAppState bits from the app manifest's StateFlags.
UPDATE_REQUIRED = 2
FULLY_INSTALLED = 4
UPDATE_RUNNING = 256
UPDATE_PAUSED = 512
UPDATE_STARTED = 1024
DOWNLOADING = 1048576


def steam_libraries(root=None):
    """Every Steam library folder that exists, the main one first."""
    root = root or game_library.steam_root()
    if not root: return []
    found = [pathlib.Path(root)]
    try:
        folders = game_library.text_vdf((pathlib.Path(root) / 'steamapps/libraryfolders.vdf').read_text(errors='replace')).get('libraryfolders', {})
        for value in folders.values():
            if isinstance(value, dict) and value.get('path'):
                path = pathlib.Path(value['path'])
                if path not in found: found.append(path)
    except (OSError, ValueError):
        pass
    return [p for p in found if (p / 'steamapps').is_dir()]


def manifests(root=None):
    """Installed app manifests as (library, state dict)."""
    out = []
    for library in steam_libraries(root):
        for path in sorted((library / 'steamapps').glob('appmanifest_*.acf')):
            try: state = game_library.text_vdf(path.read_text(errors='replace')).get('AppState', {})
            except (OSError, ValueError): continue
            if state.get('appid', '').isdigit() and state.get('name') and not game_library.TOOL_NAMES.match(state['name']):
                out.append((library, state))
    return out


def _int(value):
    return int(value) if isinstance(value, str) and value.isdigit() else 0


def update_state(flags):
    """One word for a manifest's update state, or '' when it is up to date."""
    if flags & (DOWNLOADING | UPDATE_RUNNING): return 'downloading'
    if flags & UPDATE_PAUSED: return 'paused'
    if flags & (UPDATE_REQUIRED | UPDATE_STARTED): return 'queued'
    return ''


def steam_updates(root=None):
    """Games Steam has an update for, with the bytes still to download."""
    items = []
    for _, state in manifests(root):
        flags = _int(state.get('StateFlags', '0'))
        remaining = max(0, _int(state.get('BytesToDownload', '0')) - _int(state.get('BytesDownloaded', '0')))
        kind = update_state(flags)
        if not kind and remaining == 0: continue
        items.append({'id': 'steam:' + state['appid'], 'title': state['name'], 'state': kind or 'queued', 'bytes': remaining})
    items.sort(key=lambda i: (i['state'] != 'downloading', -i['bytes'], i['title'].lower()))
    return items


def storage(root=None, statvfs=os.statvfs):
    """Free and used space for the disk that holds the main Steam library, and installed games by size."""
    libraries = steam_libraries(root)
    target = str(libraries[0]) if libraries else str(HOME)
    try:
        st = statvfs(target)
        total, free = st.f_blocks * st.f_frsize, st.f_bavail * st.f_frsize
    except OSError:
        total = free = 0
    games = []
    for _, state in manifests(root):
        size = _int(state.get('SizeOnDisk', '0'))
        if size: games.append({'id': 'steam:' + state['appid'], 'title': state['name'], 'bytes': size, 'lastPlayed': _int(state.get('LastPlayed', '0'))})
    games.sort(key=lambda g: -g['bytes'])
    minutes = playtimes(root)
    return {'path': target, 'total': total, 'free': free, 'games': sum(g['bytes'] for g in games), 'largest': games[:8],
            'playtime': {g['id']: minutes[g['id'][6:]] for g in games[:8] if g['id'][6:] in minutes}}


def playtimes(root=None):
    """Minutes played per Steam app id from every local user's localconfig.vdf, read once."""
    root = root or game_library.steam_root()
    out = {}
    if not root: return out
    for path in pathlib.Path(root, 'userdata').glob('*/config/localconfig.vdf'):
        try: data = game_library.text_vdf(path.read_text(errors='replace'))
        except (OSError, ValueError): continue
        apps = data
        for key in ('UserLocalConfigStore', 'Software', 'Valve', 'Steam', 'apps'):
            apps = next((v for k, v in apps.items() if k.lower() == key.lower()), {}) if isinstance(apps, dict) else {}
        for appid, entry in (apps or {}).items():
            if not isinstance(entry, dict): continue
            value = next((v for k, v in entry.items() if k.lower() == 'playtime'), '0')
            if isinstance(value, str) and value.isdigit(): out[appid] = max(out.get(appid, 0), int(value))
    return out


def captures(root=None, limit=30):
    """Steam screenshots, newest first, and a count for each game."""
    root = root or game_library.steam_root()
    if not root: return {'total': 0, 'perGame': {}, 'items': []}
    shots = []
    for folder in pathlib.Path(root, 'userdata').glob('*/760/remote/*/screenshots'):
        appid = folder.parent.name
        for path in folder.glob('*.jpg'):
            try: shots.append((path.stat().st_mtime, appid, path))
            except OSError: continue
    shots.sort(reverse=True)
    counts = {}
    for _, appid, _ in shots: counts[capture_id(appid)] = counts.get(capture_id(appid), 0) + 1
    return {'total': len(shots), 'perGame': counts,
            'items': [{'id': capture_id(appid), 'path': str(path), 'time': int(stamp)} for stamp, appid, path in shots[:limit]]}


def capture_id(folder):
    """Library id for a screenshot folder. Non-Steam shortcuts use their 64-bit game id, whose top half is the shortcut id."""
    number = int(folder) if folder.isdigit() else 0
    return 'shortcut:%d' % (number >> 32) if number >= 1 << 32 else 'steam:' + folder


def prism_instances(roots=None):
    """Prism Launcher instances with game version, loader, mods, playtime and last launch."""
    roots = roots or [HOME / '.local/share/PrismLauncher', HOME / '.var/app/org.prismlauncher.PrismLauncher/data/PrismLauncher']
    out = []
    loaders = {'net.fabricmc.fabric-loader': 'Fabric', 'net.neoforged': 'NeoForge', 'net.minecraftforge': 'Forge', 'org.quiltmc.quilt-loader': 'Quilt'}
    for root in roots:
        for config in sorted(pathlib.Path(root, 'instances').glob('*/instance.cfg')):
            folder = config.parent
            values = {}
            try:
                for line in config.read_text(errors='replace').splitlines():
                    if '=' in line:
                        key, value = line.split('=', 1); values[key.strip()] = value.strip()
            except OSError:
                continue
            version, loader = '', 'Vanilla'
            try:
                for component in json.loads((folder / 'mmc-pack.json').read_text()).get('components', []):
                    uid = component.get('uid', '')
                    if uid == 'net.minecraft': version = component.get('version', '')
                    elif uid in loaders: loader = loaders[uid]
            except (OSError, ValueError, AttributeError):
                pass
            mods_dir = next((d for d in (folder / 'minecraft/mods', folder / '.minecraft/mods') if d.is_dir()), None)
            mods = len(list(mods_dir.glob('*.jar'))) if mods_dir else 0
            out.append({'id': 'prism:' + folder.name, 'title': values.get('name', folder.name), 'version': version, 'loader': loader,
                        'mods': mods, 'modsPath': str(mods_dir or folder), 'seconds': _int(values.get('totalTimePlayed', '0')),
                        'lastPlayed': _int(values.get('lastLaunchTime', '0')) // 1000})
    out.sort(key=lambda i: (-i['lastPlayed'], i['title'].lower()))
    return out


def snapshot(root=None):
    """Everything the widgets show, in one event."""
    return {'event': 'gameWidgets', 'updates': steam_updates(root), 'storage': storage(root),
            'captures': captures(root), 'instances': prism_instances()}
