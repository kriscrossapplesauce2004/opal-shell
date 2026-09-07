"""Local wallpaper validation and shell-only Matugen colors (no template hooks)."""
import json
import pathlib
import re
import shutil
import subprocess
import tempfile
from urllib.parse import unquote, urlparse

ROLES = ('primary', 'on_primary', 'primary_container', 'on_primary_container',
         'secondary', 'tertiary', 'background', 'on_surface', 'on_surface_variant',
         'surface_container', 'surface_container_high', 'outline_variant')
SCHEMES = ('scheme-tonal-spot', 'scheme-expressive', 'scheme-vibrant', 'scheme-neutral')
DEFAULTS = dict(wallpaperPath='', wallpaperFit='crop', wallpaperDim=0.15,
                desktopWidgets=True, dynamicColors=False, dynamicPalette={},
                colorScheme='scheme-tonal-spot')

def local_image(value):
    if not isinstance(value, str) or not value or len(value) > 4096:
        raise ValueError('Choose a local image path.')
    if value.startswith('file:'):
        url = urlparse(value)
        if url.netloc not in ('', 'localhost'):
            raise ValueError('Only local wallpapers are supported.')
        value = unquote(url.path)
    path = pathlib.Path(value).expanduser()
    if not path.is_absolute() or not path.is_file():
        raise ValueError('Wallpaper must be an existing absolute path (or ~/path).')
    if path.suffix.lower() not in ('.png', '.jpg', '.jpeg', '.webp', '.bmp'):
        raise ValueError('Choose a PNG, JPEG, WebP or BMP image.')
    if path.stat().st_size > 64 * 1024 * 1024:
        raise ValueError('Choose an image smaller than 64 MiB.')
    return path.resolve()

def image_library(folder='', current='', home=None):
    """Bounded, local-only discovery; no recursive symlink traversal or downloads."""
    home = pathlib.Path(home) if home else pathlib.Path.home()
    if folder:
        if not isinstance(folder, str) or len(folder) > 4096:
            raise ValueError('Choose a local folder.')
        url = urlparse(folder)
        if url.scheme and url.scheme != 'file' or url.netloc not in ('', 'localhost'):
            raise ValueError('Choose a local folder.')
        root = pathlib.Path(unquote(url.path) if url.scheme else folder).expanduser()
        if not root.is_absolute() or not root.is_dir():
            raise ValueError('Folder is unavailable.')
        roots = [root]
    else:
        roots = [home/'Pictures/Wallpapers', home/'Pictures', home/'wallpapers', pathlib.Path('/usr/share/backgrounds'), pathlib.Path('/usr/share/wallpapers')]
    result, seen, scanned = [], set(), 0
    if current:
        try:
            p = local_image(current)
            result.append({'path':p.as_uri(), 'name':p.stem}); seen.add(p)
        except (ValueError, OSError): pass
    queue = [(p, 0) for p in roots]
    while queue and len(result) < 120 and scanned < 3000:
        directory, depth = queue.pop(0)
        try:
            for p in directory.iterdir():
                scanned += 1
                if scanned > 3000 or len(result) >= 120: break
                if p.name.startswith('.') or p.is_symlink(): continue
                if p.is_dir():
                    if depth < 3: queue.append((p, depth+1))
                    continue
                if p.suffix.lower() not in ('.png','.jpg','.jpeg','.webp','.bmp'): continue
                try: p = local_image(str(p))
                except (ValueError, OSError): continue
                if p not in seen:
                    seen.add(p)
                    name=p.stem
                    if p.parent.name in ('images','images_dark') and p.parent.parent.name=='contents':
                        name=p.parents[2].name+(' · dark' if p.parent.name=='images_dark' else '')+' · '+p.stem
                    result.append({'path':p.as_uri(), 'name':name})
        except OSError: continue
    return sorted(result, key=lambda item:item['name'].casefold())


def normalize_colors(data):
    colors = data['colors']
    result = {}
    for mode in ('light', 'dark'):
        result[mode] = {}
        for role in ROLES:
            # Matugen 4 and older JSON formats.
            value = colors[role][mode] if role in colors else colors[mode][role]
            if isinstance(value, dict):
                value = value.get('color')
            if not isinstance(value, str) or not re.fullmatch(r'#[0-9a-fA-F]{6}', value):
                raise ValueError('Matugen returned an invalid palette.')
            result[mode][role] = value
    return result

def generate(path, scheme):
    if scheme not in SCHEMES:
        raise ValueError('Unsupported color scheme.')
    if not shutil.which('matugen'):
        raise ValueError('Install Matugen to generate wallpaper colors. Your wallpaper still works without it.')
    # Isolated config plus dry-run: never run user hooks, reload apps or set wallpaper.
    # Matugen v4 rejects an empty config, so write the smallest valid one (no templates).
    with tempfile.NamedTemporaryFile(suffix='.toml', mode='w') as config:
        config.write('[config]\nversion_check = false\n\n[templates]\n')
        config.flush()
        proc = subprocess.run(['matugen', 'image', '--config', config.name, '--dry-run',
                               '--json', 'hex', '--type', scheme, '--source-color-index', '0',
                               str(path)], capture_output=True, text=True, timeout=30, check=True)
    return normalize_colors(json.loads(proc.stdout))

def valid_preference(key, value):
    return (key in ('desktopWidgets', 'dynamicColors') and type(value) is bool
            or key == 'wallpaperFit' and value in ('crop', 'fit')
            or key == 'wallpaperDim' and type(value) in (int, float) and 0 <= value <= .8
            or key == 'colorScheme' and value in SCHEMES)
