"""Omarchy themes for Opal: read a theme's colors.toml (or legacy alacritty.toml) and turn it into Opal's light and dark palettes.

A theme is data only. Opal reads colors.toml, alacritty.toml, preview.png and backgrounds/; it never runs or sources anything a theme ships.
"""
import colorsys
import math
import os
import pathlib
import re
import shutil
import tomllib
from urllib.parse import unquote

HEX = re.compile(r'#?([0-9a-fA-F]{6})(?:[0-9a-fA-F]{2})?')
NAME = re.compile(r'[a-z0-9][a-z0-9._-]{0,63}')
IMAGE_SUFFIXES = ('.png', '.jpg', '.jpeg', '.webp', '.bmp')
NAMED = ('red', 'yellow', 'orange', 'green', 'cyan', 'blue', 'magenta')
# Legacy colors.toml and terminal palettes use color0..color15 in ANSI order.
ANSI = ('black', 'red', 'green', 'yellow', 'blue', 'magenta', 'cyan', 'white')
BUNDLED = pathlib.Path(__file__).with_name('omarchy-themes.toml')
# Full themes that ship with Opal: colours, a preview and wallpapers.
BUNDLED_DIR = pathlib.Path(__file__).with_name('themes')
# Material tones (CIE L*) for each role, per mode.
TONES = {
    'dark': dict(primary=80, on_primary=20, primary_container=30, on_primary_container=90, secondary=80, tertiary=80,
                 background=6, on_surface=90, on_surface_variant=80, surface_container=12, surface_container_high=17,
                 outline_variant=30, error=80),
    'light': dict(primary=40, on_primary=100, primary_container=90, on_primary_container=10, secondary=40, tertiary=40,
                  background=98, on_surface=10, on_surface_variant=30, surface_container=94, surface_container_high=92,
                  outline_variant=80, error=40),
}
NEUTRAL = ('background', 'on_surface', 'on_surface_variant', 'surface_container', 'surface_container_high', 'outline_variant')


def home_dir(home=None):
    return pathlib.Path(home) if home else pathlib.Path.home()


def roots(home=None):
    """Theme folders, most personal first. A theme name found earlier hides later copies."""
    home = home_dir(home)
    found = [home/'.config/opal/themes', home/'.config/omarchy/themes']
    if os.environ.get('OMARCHY_PATH'):
        found.append(pathlib.Path(os.environ['OMARCHY_PATH'])/'themes')
    found += [home/'.local/share/omarchy/themes', pathlib.Path('/usr/share/omarchy/themes'), BUNDLED_DIR]
    return found


def current_dir(home=None):
    """Omarchy's applied theme: a staged copy of the theme with the user's overrides."""
    return home_dir(home)/'.local/state/omarchy/current'


# Colour math. sRGB <-> CIELAB (D65) is enough to move a colour to a Material tone and keep its hue.
def hex_rgb(value):
    match = HEX.fullmatch(value.strip()) if isinstance(value, str) else None
    if not match:
        raise ValueError('not a colour')
    h = match.group(1)
    return tuple(int(h[i:i+2], 16)/255 for i in (0, 2, 4))


def rgb_hex(rgb):
    return '#' + ''.join('%02x' % round(max(0, min(1, c))*255) for c in rgb)


def _linear(c):
    return c/12.92 if c <= .04045 else ((c+.055)/1.055)**2.4


def _gamma(c):
    return 12.92*c if c <= .0031308 else 1.055*c**(1/2.4)-.055


def _f(t):
    return t**(1/3) if t > 216/24389 else (24389/27*t+16)/116


def _finv(t):
    return t**3 if t**3 > 216/24389 else (116*t-16)/(24389/27)


WHITE = (.95047, 1.0, 1.08883)


def lab(value):
    r, g, b = (_linear(c) for c in hex_rgb(value))
    xyz = (.4124*r+.3576*g+.1805*b, .2126*r+.7152*g+.0722*b, .0193*r+.1192*g+.9505*b)
    fx, fy, fz = (_f(v/w) for v, w in zip(xyz, WHITE))
    return 116*fy-16, 500*(fx-fy), 200*(fy-fz)


def lab_rgb(L, a, b):
    fy = (L+16)/116
    x, y, z = (w*_finv(t) for w, t in zip(WHITE, (fy+a/500, fy, fy-b/200)))
    rgb = (3.2406*x-1.5372*y-.4986*z, -.9689*x+1.8758*y+.0415*z, .0557*x-.2040*y+1.0570*z)
    return tuple(_gamma(c) if c > 0 else c*12.92 for c in rgb)


def tone(value, L, chroma=None):
    """The colour at CIE lightness L with the same hue; chroma shrinks until it fits in sRGB."""
    _, a, b = lab(value)
    c = math.hypot(a, b) if chroma is None else chroma
    h = math.atan2(b, a)
    for _ in range(40):
        rgb = lab_rgb(L, c*math.cos(h), c*math.sin(h))
        if all(-.001 <= v <= 1.001 for v in rgb):
            return rgb_hex(rgb)
        c *= .9
    return rgb_hex(lab_rgb(L, 0, 0))


def luminance(value):
    r, g, b = (_linear(c) for c in hex_rgb(value))
    return .2126*r+.7152*g+.0722*b


def contrast(a, b):
    la, lb = sorted((luminance(a), luminance(b)), reverse=True)
    return (la+.05)/(lb+.05)


def mix(a, b, amount):
    x, y = hex_rgb(a), hex_rgb(b)
    return rgb_hex(tuple(p+(q-p)*amount for p, q in zip(x, y)))


def hue(value):
    r, g, b = hex_rgb(value)
    h, _, s = colorsys.rgb_to_hls(r, g, b)
    return h*360, s


# Theme files.
def _hex(value):
    try:
        return rgb_hex(hex_rgb(value))
    except (ValueError, TypeError, AttributeError):
        return None


def _read_toml(path):
    try:
        if path.is_symlink() or not path.is_file() or path.stat().st_size > 256*1024:
            return None
        with path.open('rb') as handle:
            return tomllib.load(handle)
    except (OSError, tomllib.TOMLDecodeError, UnicodeDecodeError):
        return None


def from_alacritty(data):
    """Legacy themes only ship an Alacritty palette."""
    colors = data.get('colors') if isinstance(data, dict) else None
    if not isinstance(colors, dict):
        return {}
    primary = colors.get('primary') or {}
    normal, bright = colors.get('normal') or {}, colors.get('bright') or {}
    out = {'background': _hex(primary.get('background')), 'foreground': _hex(primary.get('foreground'))}
    for i, name in enumerate(ANSI):
        out['color%d' % i] = _hex(normal.get(name))
        out['color%d' % (i+8)] = _hex(bright.get(name))
    selection = colors.get('selection') or {}
    out['selection_background'] = _hex(selection.get('background'))
    return {k: v for k, v in out.items() if v}


def normalize(raw):
    """One shape for the semantic format and the older color0..color15 format."""
    if not isinstance(raw, dict):
        return None
    flat = {k: _hex(v) for k, v in raw.items() if isinstance(v, str) and k != 'mode'}
    flat = {k: v for k, v in flat.items() if v}
    bg, fg = flat.get('background'), flat.get('foreground')
    if not bg or not fg:
        return None
    out = {'background': bg, 'foreground': fg}
    for i, name in enumerate(ANSI[1:7], 1):
        out[name] = flat.get(name) or flat.get('color%d' % i)
    out['orange'] = flat.get('orange') or flat.get('bright_yellow') or flat.get('color11') or out.get('yellow')
    out['accent'] = flat.get('accent') or out.get('blue') or flat.get('color12') or fg
    out['selection'] = flat.get('selection') or flat.get('selection_background') or mix(bg, fg, .18)
    out['muted'] = flat.get('muted') or flat.get('color8') or mix(bg, fg, .4)
    out['lighter_background'] = flat.get('lighter_background')
    out['dark_background'] = flat.get('dark_background')
    mode = raw.get('mode')
    out['mode'] = mode if mode in ('light', 'dark') else ('light' if luminance(bg) > .4 else 'dark')
    return {k: v for k, v in out.items() if v}


def _first_image(folder):
    try:
        names = sorted(p for p in folder.iterdir() if p.suffix.lower() in IMAGE_SUFFIXES and p.is_file() and not p.is_symlink())
    except OSError:
        return []
    return names


def read_dir(folder):
    """A theme folder, or None when it has no usable palette."""
    folder = pathlib.Path(folder)
    raw = _read_toml(folder/'colors.toml')
    colors = normalize(raw) if raw else None
    if not colors:
        legacy = _read_toml(folder/'alacritty.toml')
        colors = normalize(from_alacritty(legacy)) if legacy else None
    if not colors:
        return None
    preview = folder/'preview.png'
    return dict(colors=colors,
                preview=preview.as_uri() if preview.is_file() and not preview.is_symlink() else '',
                backgrounds=[p.as_uri() for p in _first_image(folder/'backgrounds')])


def title(name):
    return ' '.join(part.capitalize() for part in re.split(r'[-_ ]+', name) if part)


def bundled():
    """Omarchy's stock palettes (MIT), so the gallery is useful without Omarchy installed."""
    data = _read_toml(BUNDLED) or {}
    return {name: normalize(raw) for name, raw in data.items() if NAME.fullmatch(name) and isinstance(raw, dict)}


def discover(home=None):
    themes, seen = [], set()
    for root in roots(home):
        try:
            entries = sorted(root.iterdir()) if root.is_dir() else []
        except OSError:
            continue
        for folder in entries[:200]:
            name = folder.name.lower()
            if name in seen or not NAME.fullmatch(name) or not folder.is_dir():
                continue
            theme = read_dir(folder)
            if theme:
                seen.add(name)
                themes.append(dict(theme, id=name, name=title(name), path=str(folder), source='bundled' if root == BUNDLED_DIR else 'installed'))
    for name, colors in bundled().items():
        if colors and name not in seen:
            seen.add(name)
            themes.append(dict(id=name, name=title(name), path='', source='bundled', colors=colors, preview='', backgrounds=[]))
    return themes


def find(name, home=None):
    for theme in discover(home):
        if theme['id'] == name:
            return theme
    return None


def current(home=None):
    """The theme Omarchy applied last: its name and a signature that changes on every switch."""
    base = current_dir(home)
    try:
        name = (base/'theme.name').read_text().strip()[:64]
        stamp = (base/'theme').stat().st_mtime_ns
    except OSError:
        return None
    background = base/'background'
    try:
        image = background.resolve(strict=True) if background.is_symlink() else None
    except OSError:
        image = None
    return dict(name=name, signature='%s:%d' % (name, stamp), path=str(base/'theme'),
                background=image.as_uri() if image and image.suffix.lower() in IMAGE_SUFFIXES else '')


# Palettes.
def _distinct(colors, accent, offset):
    """The theme colour whose hue lies nearest to the accent's hue plus offset, skipping colours too close to the accent."""
    target = (hue(accent)[0]+offset) % 360
    best, score = None, 999
    for name in NAMED:
        value = colors.get(name)
        if not value:
            continue
        h, s = hue(value)
        if s < .15 or min(abs(h-hue(accent)[0]), 360-abs(h-hue(accent)[0])) < 25:
            continue
        d = min(abs(h-target), 360-abs(h-target))
        if d < score:
            best, score = value, d
    return best or tone(accent, 70 if luminance(colors['background']) < .4 else 45)


def _ink(fill, *options):
    """The first option with readable contrast on fill, otherwise black or white."""
    for option in options:
        if option and contrast(fill, option) >= 4.5:
            return option
    return '#000000' if contrast(fill, '#000000') >= contrast(fill, '#ffffff') else '#ffffff'


def _subtle(fg, bg):
    """Secondary text: fade toward the background while it stays readable."""
    for amount in (.28, .22, .16, .1, .05):
        if contrast(mix(fg, bg, amount), bg) >= 4.5:
            return mix(fg, bg, amount)
    return fg


def _readable(fg, dark, *fills):
    """Text that reads on every fill: the theme's own foreground, moved toward white or black only as far as needed."""
    target = '#ffffff' if dark else '#000000'
    for amount in (0, .1, .2, .3, .45, .6, .8, 1):
        ink = mix(fg, target, amount) if amount else fg
        if all(contrast(ink, f) >= 4.6 for f in fills):
            return ink
    return target


def native(colors):
    """The theme's own mode, with its real colours."""
    bg, fg, accent = colors['background'], colors['foreground'], colors['accent']
    dark = colors['mode'] == 'dark'
    container = mix(bg, accent, .3 if dark else .34)
    surface = colors.get('lighter_background') if dark and colors.get('lighter_background') else mix(bg, fg, .06 if dark else .045)
    high = mix(surface, fg, .05 if dark else .04)
    fg = _readable(fg, dark, bg, surface, high)
    return dict(primary=accent, on_primary=_ink(accent, bg, colors.get('dark_background')),
                primary_container=container, on_primary_container=_ink(container, mix(accent, fg, .45), fg),
                secondary=_distinct(colors, accent, 50), tertiary=_distinct(colors, accent, 150),
                background=bg, on_surface=fg, on_surface_variant=_subtle(fg, bg),
                surface_container=surface, surface_container_high=high,
                outline_variant=colors['selection'], error=colors.get('red') or ('#ffb4ab' if dark else '#ba1a1a'))


def opposite(roles, mode):
    """The other mode: every role keeps its hue and moves to that mode's Material tone."""
    out = {}
    for role, L in TONES[mode].items():
        source = roles[role]
        if role in NEUTRAL:
            chroma = min(math.hypot(*lab(roles['background'])[1:]), 10)
            out[role] = tone(roles['primary'] if chroma < 1.5 else roles['background'], L, chroma)
        elif role in ('on_primary', 'primary_container', 'on_primary_container'):
            out[role] = tone(roles['primary'], L, None if role == 'primary_container' else min(math.hypot(*lab(roles['primary'])[1:]), 24))
        else:
            out[role] = tone(source, L)
    return out


def palette(colors):
    """{'light': roles, 'dark': roles} in the shape Opal's dynamic palette uses."""
    roles = native(colors)
    mode = colors['mode']
    other = 'light' if mode == 'dark' else 'dark'
    return {mode: roles, other: opposite(roles, other)}


def apply(theme, wallpaper=True):
    """Preference changes that make the shell wear this theme."""
    update = dict(dynamicPalette=palette(theme['colors']), dynamicColors=True,
                  light=theme['colors']['mode'] == 'light', omarchyTheme=theme['id'])
    if wallpaper and theme.get('backgrounds'):
        update['wallpaperPath'] = theme['backgrounds'][0]
    return update


def summary(theme):
    """The small card the gallery draws: name, mode and six swatches."""
    c = theme['colors']
    swatches = [c.get(k) for k in ('accent', 'red', 'green', 'yellow', 'blue', 'magenta', 'cyan')]
    return dict(id=theme['id'], name=theme['name'], source=theme['source'], mode=c['mode'],
                background=c['background'], foreground=c['foreground'], accent=c['accent'],
                swatches=[s for s in swatches if s][:6], preview=theme.get('preview', ''),
                wallpaper=(theme.get('backgrounds') or [''])[0], wallpapers=len(theme.get('backgrounds') or []))


# Opal -> Omarchy.
def to_colors_toml(roles, mode, ansi=None):
    """An Omarchy colors.toml for Opal's current palette, so Omarchy apps (and shells that read Omarchy themes) can wear it."""
    bg, fg, accent = roles['background'], roles['on_surface'], roles['primary']
    dark = mode == 'dark'
    ansi = dict(ansi or {})
    base = {'red': 25, 'yellow': 85, 'orange': 55, 'green': 140, 'cyan': 190, 'blue': 230, 'magenta': 300}
    L = 72 if dark else 45
    for name, angle in base.items():
        if not ansi.get(name):
            ansi[name] = tone(rgb_hex(lab_rgb(L, 45*math.cos(math.radians(angle)), 45*math.sin(math.radians(angle)))), L)
    values = dict(accent=accent, selection=roles.get('outline_variant') or mix(bg, fg, .2), muted=mix(bg, fg, .4),
                  background=bg, dark_background=mix(bg, '#000000', .25), darker_background=mix(bg, '#000000', .45),
                  lighter_background=roles.get('surface_container') or mix(bg, fg, .08),
                  foreground=fg, dark_foreground=mix(fg, bg, .45), light_foreground=mix(fg, '#ffffff' if dark else '#000000', .15),
                  bright_foreground=mix(fg, '#ffffff' if dark else '#000000', .3))
    lines = ['# Exported by Opal from its current palette.', 'mode = "%s"' % mode, '']
    lines += ['%s = "%s"' % (k, values[k]) for k in ('accent', 'selection', 'muted')] + ['']
    lines += ['%s = "%s"' % (k, values[k]) for k in ('background', 'dark_background', 'darker_background', 'lighter_background')] + ['']
    lines += ['%s = "%s"' % (k, values[k]) for k in ('foreground', 'dark_foreground', 'light_foreground', 'bright_foreground')] + ['']
    lines += ['%s = "%s"' % (k, ansi[k]) for k in base] + ['brown = "%s"' % mix(ansi['orange'], bg, .45), '']
    lines += ['bright_%s = "%s"' % (k, mix(ansi[k], '#ffffff' if dark else '#000000', .15)) for k in ('red', 'yellow', 'green', 'cyan', 'blue', 'magenta')]
    return '\n'.join(lines) + '\n'


def export(roles, mode, wallpaper='', name='opal', home=None):
    """Write ~/.config/omarchy/themes/<name>; the folder is Opal's, replaced on each export."""
    if not NAME.fullmatch(name):
        raise ValueError('Theme names use lowercase letters, numbers, dots, dashes and underscores.')
    for role in ('background', 'on_surface', 'primary'):
        if not _hex(roles.get(role)):
            raise ValueError('The current palette is incomplete.')
    target = home_dir(home)/'.config/omarchy/themes'/name
    marker = target/'.opal-export'
    if target.exists() and not marker.exists():
        raise ValueError('%s exists and was not made by Opal; choose another name.' % target)
    temp = target.with_name('.%s.opal-tmp' % name)
    shutil.rmtree(temp, ignore_errors=True)
    (temp/'backgrounds').mkdir(parents=True)
    (temp/'colors.toml').write_text(to_colors_toml(roles, mode))
    marker_text = 'Made by Opal. Exporting again replaces this folder.\n'
    (temp/'.opal-export').write_text(marker_text)
    if mode == 'light':
        (temp/'light.mode').write_text('')
    source = pathlib.Path(unquote(wallpaper[7:])) if isinstance(wallpaper, str) and wallpaper.startswith('file://') else None
    if source and source.is_file() and source.suffix.lower() in IMAGE_SUFFIXES:
        shutil.copyfile(source, temp/'backgrounds'/('1-opal' + source.suffix.lower()))
    if target.exists():
        shutil.rmtree(target)
    temp.rename(target)
    return str(target)


if __name__ == '__main__':
    import sys
    if sys.argv[1:2] == ['list']:
        now = current()
        for t in discover():
            mark = '*' if now and now['name'] == t['id'] else ' '
            print('%s %-20s %-5s %s%s' % (mark, t['id'], t['colors']['mode'], t['source'], ' · %d wallpapers' % len(t['backgrounds']) if t['backgrounds'] else ''))
    else:
        print('Usage: omarchy_themes.py list', file=sys.stderr)
        sys.exit(2)
