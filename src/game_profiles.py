"""Per-game performance profiles. A profile applies when its game starts and the previous settings come back when it quits."""

PRESETS = {
    'saver': {'power': 'power-saver', 'fpsLimit': 40},
    'balanced': {'power': 'balanced', 'fpsLimit': 60},
    'max': {'power': 'performance', 'fpsLimit': 0},
}
FPS_CHOICES = (0, 30, 40, 45, 60, 72, 90, 120, 144)


def resolve(prefs, game_id):
    """The settings for one game: its own profile, else the 'next game' preset. Returns {preset, power, fpsLimit, tdp?, overlay?}."""
    profiles = prefs.get('gameProfiles') if isinstance(prefs.get('gameProfiles'), dict) else {}
    own = profiles.get(game_id) if isinstance(game_id, str) else None
    if isinstance(own, dict) and own.get('preset') in PRESETS:
        return dict(PRESETS[own['preset']], preset=own['preset'], own=True)
    if isinstance(own, dict) and own.get('preset') == 'custom':
        out = {'preset': 'custom', 'own': True, 'power': own.get('power') if own.get('power') in ('power-saver', 'balanced', 'performance') else 'balanced',
               'fpsLimit': own.get('fpsLimit') if own.get('fpsLimit') in FPS_CHOICES else 0}
        if type(own.get('tdp')) is int and own['tdp'] > 0: out['tdp'] = own['tdp']
        if own.get('overlay') in ('off', 'fps', 'compact', 'full'): out['overlay'] = own['overlay']
        return out
    preset = prefs.get('gameProfileNext') if prefs.get('gameProfileNext') in PRESETS else 'balanced'
    return dict(PRESETS[preset], preset=preset, own=False)


class Applier:
    """Applies a profile through injected setters and remembers what to put back."""
    def __init__(self, read_power, set_power, read_fps, set_fps, set_tdp=None, set_overlay=None):
        self.read_power, self.set_power = read_power, set_power
        self.read_fps, self.set_fps = read_fps, set_fps
        self.set_tdp, self.set_overlay = set_tdp, set_overlay
        self.saved = None
        self.game = ''

    def apply(self, game_id, profile):
        # Settings saved before the first game return after the last one, even across a switch between games.
        if self.saved is None: self.saved = {'power': self.read_power(), 'fpsLimit': self.read_fps()}
        self.game = game_id
        if profile.get('power'): self.set_power(profile['power'])
        self.set_fps(int(profile.get('fpsLimit') or 0))
        if self.set_tdp and profile.get('tdp'): self.set_tdp(profile['tdp'])
        if self.set_overlay and profile.get('overlay'): self.set_overlay(profile['overlay'])

    def restore(self):
        saved, self.saved, self.game = self.saved, None, ''
        if not saved: return False
        if saved.get('power'): self.set_power(saved['power'])
        self.set_fps(int(saved.get('fpsLimit') or 0))
        return True

WIDGETS = ('music', 'devices', 'updates', 'storage', 'captures', 'next', 'minecraft', 'playtime', 'toggles', 'claude')
WIDGET_DEFAULT = ['updates', 'devices', 'music', 'storage', 'captures', 'next']


def valid_profile(value):
    if not isinstance(value, dict) or len(value) > 6: return False
    if value.get('preset') not in tuple(PRESETS) + ('custom',): return False
    if 'fpsLimit' in value and value['fpsLimit'] not in FPS_CHOICES: return False
    if 'power' in value and value['power'] not in ('power-saver', 'balanced', 'performance'): return False
    if 'tdp' in value and not (type(value['tdp']) is int and 0 < value['tdp'] <= 300): return False
    if 'overlay' in value and value['overlay'] not in ('off', 'fps', 'compact', 'full'): return False
    return set(value) <= {'preset', 'fpsLimit', 'power', 'tdp', 'overlay'}


def valid_preference(key, value):
    """Preferences owned by game mode: profiles, the next-game preset and the home's widgets."""
    if key == 'gameProfileNext': return value in PRESETS
    if key == 'gameProfiles':
        return isinstance(value, dict) and len(value) <= 512 and all(isinstance(k, str) and 0 < len(k) < 300 and valid_profile(v) for k, v in value.items())
    if key == 'consoleWidgets':
        return isinstance(value, list) and len(value) <= len(WIDGETS) and all(v in WIDGETS for v in value) and len(set(value)) == len(value)
    return False
