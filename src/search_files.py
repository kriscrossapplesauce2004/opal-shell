"""File search for Opal search: name matches from the plocate index inside the home folder, and safe opening of local paths."""
import os, pathlib, shutil, subprocess

HOME = pathlib.Path.home()
# Private, generated and throwaway places stay out of results.
HIDDEN = ('/.', '/node_modules/', '/__pycache__/', '/.cache/', '/.local/share/Trash/', '/target/debug/', '/build/')
MAX_QUERY = 80


def visible(path, home=HOME):
    text = str(path)
    if not text.startswith(str(home) + '/'): return False
    rest = text[len(str(home)):]
    return not any(part in rest for part in HIDDEN)


def search(text, limit=8, home=HOME, runner=subprocess.run, which=shutil.which):
    """Return up to limit files and folders whose name contains every word. Newest first among equals."""
    words = [w for w in str(text or '').strip().split()[:4] if w]
    if not words or len(' '.join(words)) > MAX_QUERY or len(''.join(words)) < 2: return []
    tool = which('plocate') or which('locate')
    if not tool: return []
    try:
        result = runner([tool, '-i', '-b', '-l', '400', '--', *words], capture_output=True, text=True, timeout=3)
    except (OSError, subprocess.SubprocessError):
        return []
    found = []
    for line in result.stdout.splitlines():
        path = pathlib.Path(line)
        if not visible(path, home): continue
        name = path.name.lower()
        if not all(w.lower() in name for w in words): continue
        try: stat = path.stat()
        except OSError: continue
        found.append((0 if name.startswith(words[0].lower()) else 1, -stat.st_mtime, str(path), path.is_dir()))
    found.sort()
    out = []
    for _, mtime, text_path, is_dir in found[:limit]:
        path = pathlib.Path(text_path)
        parent = str(path.parent).replace(str(home), '~', 1)
        out.append({'path': text_path, 'name': path.name, 'folder': parent, 'dir': is_dir, 'mtime': int(-mtime)})
    return out


def openable(path, home=HOME):
    """True for an existing local file or folder in the home folder or on mounted media."""
    if not isinstance(path, str) or not path.startswith('/') or len(path) > 4096 or '\0' in path: return False
    resolved = os.path.realpath(path)
    allowed = (str(home) + '/', '/media/', '/run/media/', '/mnt/')
    return resolved.startswith(allowed) and os.path.exists(resolved)
