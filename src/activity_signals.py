"""Local signals for live activities: a running pacman transaction and the apps that hold a camera open. Standard library only."""
import os, pathlib, re, time

PACMAN_LOCK = pathlib.Path('/var/lib/pacman/db.lck')
PACMAN_LOG = pathlib.Path('/var/log/pacman.log')
STEP = re.compile(r'\[ALPM\] (upgraded|installed|removed|reinstalled|downgraded) (\S+)')
START = re.compile(r'\[ALPM\] transaction started|\[PACMAN\] Running ')
CAMERA_EVERY = 6.0
_camera_cache = {'at': 0.0, 'value': []}


def parse_pacman_log(text):
    """Count the package steps after the last transaction start. Return (done, current package)."""
    lines = text.splitlines()
    start = 0
    for index in range(len(lines) - 1, -1, -1):
        if START.search(lines[index]):
            start = index
            break
    done, current = 0, ''
    for line in lines[start:]:
        match = STEP.search(line)
        if match:
            done += 1
            current = match.group(2)
    return done, current


def pacman_state(lock=PACMAN_LOCK, log=PACMAN_LOG):
    """Return the running pacman transaction, or an empty dict when pacman does not run."""
    try:
        if not lock.exists(): return {}
        since = lock.stat().st_mtime
    except OSError:
        return {}
    done, current = 0, ''
    try:
        with open(log, 'rb') as handle:
            handle.seek(0, os.SEEK_END)
            size = handle.tell()
            handle.seek(max(0, size - 65536))
            done, current = parse_pacman_log(handle.read().decode('utf-8', 'replace'))
    except OSError:
        pass
    return {'running': True, 'done': done, 'total': 0, 'current': current, 'since': int(since * 1000)}


def camera_users(proc=pathlib.Path('/proc'), now=None):
    """Return the names of processes of this user that hold a /dev/video device open. The result is cached for a few seconds."""
    now = time.monotonic() if now is None else now
    if now - _camera_cache['at'] < CAMERA_EVERY:
        return _camera_cache['value']
    names = []
    uid = os.getuid()
    try:
        entries = [entry for entry in os.scandir(proc) if entry.name.isdigit()]
    except OSError:
        entries = []
    for entry in entries:
        try:
            if entry.stat().st_uid != uid: continue
            for fd in os.scandir(os.path.join(entry.path, 'fd')):
                try:
                    if os.readlink(fd.path).startswith('/dev/video'):
                        name = pathlib.Path(entry.path, 'comm').read_text().strip()
                        if name and name not in names: names.append(name)
                        break
                except OSError:
                    continue
        except OSError:
            continue
    _camera_cache['at'] = now
    _camera_cache['value'] = names
    return names
