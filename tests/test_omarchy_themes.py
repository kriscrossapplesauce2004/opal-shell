import os, pathlib, sys, tempfile, unittest
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'src'))
import omarchy_themes as ot

SEMANTIC = '''mode = "dark"
accent = "#7aa2f7"
selection = "#292e42"
background = "#1a1b26"
lighter_background = "#24283b"
foreground = "#a9b1d6"
red = "#f7768e"
green = "#9ece6a"
yellow = "#e0af68"
blue = "#7aa2f7"
magenta = "#ad8ee6"
cyan = "#449dab"
'''
LEGACY = '''background = "#fbf1c7"
foreground = "#3c3836"
color1 = "#cc241d"
color2 = "#98971a"
color4 = "#458588"
color5 = "#b16286"
color6 = "#689d6a"
'''
ALACRITTY = '''[colors.primary]
background = "#2e3440"
foreground = "#d8dee9"
[colors.normal]
red = "#bf616a"
green = "#a3be8c"
blue = "#81a1c1"
magenta = "#b48ead"
'''


def theme(root, name, colors=None, alacritty=None, backgrounds=()):
    folder = pathlib.Path(root) / name
    (folder / 'backgrounds').mkdir(parents=True)
    if colors: (folder / 'colors.toml').write_text(colors)
    if alacritty: (folder / 'alacritty.toml').write_text(alacritty)
    for image in backgrounds: (folder / 'backgrounds' / image).write_bytes(b'x')
    return folder


class Parsing(unittest.TestCase):
    def test_semantic_format(self):
        c = ot.normalize(__import__('tomllib').loads(SEMANTIC))
        self.assertEqual((c['mode'], c['accent'], c['background']), ('dark', '#7aa2f7', '#1a1b26'))

    def test_legacy_ansi_format_guesses_light_mode_and_accent(self):
        c = ot.normalize(__import__('tomllib').loads(LEGACY))
        self.assertEqual(c['mode'], 'light')
        self.assertEqual(c['accent'], '#458588')
        self.assertEqual(c['green'], '#98971a')

    def test_alacritty_only_theme(self):
        with tempfile.TemporaryDirectory() as root:
            t = ot.read_dir(theme(root, 'nordish', alacritty=ALACRITTY))
        self.assertEqual((t['colors']['background'], t['colors']['accent']), ('#2e3440', '#81a1c1'))

    def test_incomplete_and_hostile_files_are_rejected(self):
        self.assertIsNone(ot.normalize({'accent': '#ffffff'}))
        self.assertIsNone(ot.normalize({'background': 'red', 'foreground': '#000000'}))
        with tempfile.TemporaryDirectory() as root:
            folder = theme(root, 'linked')
            secret = pathlib.Path(root) / 'secret.toml'; secret.write_text(SEMANTIC)
            os.symlink(secret, folder / 'colors.toml')
            self.assertIsNone(ot.read_dir(folder))


class Palettes(unittest.TestCase):
    def test_every_bundled_theme_is_readable_in_both_modes(self):
        themes = ot.bundled()
        self.assertGreaterEqual(len(themes), 20)
        pairs = (('on_surface', 'background'), ('on_primary', 'primary'), ('on_primary_container', 'primary_container'),
                 ('on_surface', 'surface_container_high'), ('on_surface_variant', 'background'))
        for name, colors in themes.items():
            p = ot.palette(colors)
            self.assertEqual(set(p), {'light', 'dark'}, name)
            for mode, roles in p.items():
                self.assertEqual(set(roles), set(ot.TONES[mode]), name)
                for fg, bg in pairs:
                    self.assertGreaterEqual(ot.contrast(roles[fg], roles[bg]), 4.5, '%s %s %s/%s' % (name, mode, fg, bg))

    def test_native_mode_keeps_the_theme_colours(self):
        c = ot.normalize(__import__('tomllib').loads(SEMANTIC))
        dark = ot.palette(c)['dark']
        self.assertEqual((dark['primary'], dark['background'], dark['on_surface'], dark['surface_container']), ('#7aa2f7', '#1a1b26', '#a9b1d6', '#24283b'))

    def test_opposite_mode_keeps_hue(self):
        c = ot.normalize(__import__('tomllib').loads(SEMANTIC))
        light = ot.palette(c)['light']
        self.assertGreater(ot.luminance(light['background']), .85)
        self.assertLess(abs(ot.hue(light['primary'])[0] - ot.hue('#7aa2f7')[0]), 12)

    def test_apply_sets_mode_palette_and_first_wallpaper(self):
        with tempfile.TemporaryDirectory() as root:
            t = ot.read_dir(theme(root, 'tn', SEMANTIC, backgrounds=('2-b.webp', '1-a.jpg', 'notes.txt')))
            t.update(id='tn', name='Tn')
            update = ot.apply(t)
            self.assertTrue(update['wallpaperPath'].endswith('/1-a.jpg'))
            self.assertNotIn('wallpaperPath', ot.apply(t, wallpaper=False))
        self.assertEqual((update['light'], update['dynamicColors'], update['omarchyTheme']), (False, True, 'tn'))


class Discovery(unittest.TestCase):
    def test_personal_themes_hide_bundled_ones(self):
        with tempfile.TemporaryDirectory() as home:
            theme(pathlib.Path(home) / '.config/opal/themes', 'tokyo-night', SEMANTIC.replace('#1a1b26', '#000000'))
            theme(pathlib.Path(home) / '.config/omarchy/themes', 'tokyo-night', SEMANTIC)
            found = [t for t in ot.discover(home) if t['id'] == 'tokyo-night']
        self.assertEqual(len(found), 1)
        self.assertEqual((found[0]['source'], found[0]['colors']['background']), ('installed', '#000000'))

    def test_current_omarchy_theme(self):
        with tempfile.TemporaryDirectory() as home:
            self.assertIsNone(ot.current(home))
            base = pathlib.Path(home) / '.local/state/omarchy/current'
            theme(base, 'theme', SEMANTIC, backgrounds=('1.png',))
            (base / 'theme.name').write_text('tokyo-night\n')
            os.symlink(base / 'theme/backgrounds/1.png', base / 'background')
            now = ot.current(home)
        self.assertEqual(now['name'], 'tokyo-night')
        self.assertTrue(now['signature'].startswith('tokyo-night:'))
        self.assertTrue(now['background'].endswith('/1.png'))


class Export(unittest.TestCase):
    ROLES = dict(primary='#cfbdff', on_primary='#31205f', primary_container='#4b3a79', on_primary_container='#eaddff',
                 secondary='#c6d6ae', tertiary='#efb8c8', background='#17141f', on_surface='#f0e9f7', on_surface_variant='#c5bccf',
                 surface_container='#302b39', surface_container_high='#403849', outline_variant='#4a4458', error='#ffb4ab')

    def test_round_trip(self):
        with tempfile.TemporaryDirectory() as home:
            wall = pathlib.Path(home) / 'my wall.png'; wall.write_bytes(b'png')
            path = ot.export(self.ROLES, 'dark', wall.as_uri(), home=home)
            back = ot.read_dir(path)
            self.assertTrue(back['backgrounds'][0].endswith('1-opal.png'))
            # A second export replaces Opal's own folder.
            ot.export(self.ROLES, 'dark', home=home)
        c = back['colors']
        self.assertEqual((c['mode'], c['background'], c['accent'], c['foreground']), ('dark', '#17141f', '#cfbdff', '#f0e9f7'))
        for name in ('red', 'green', 'yellow', 'blue', 'magenta', 'cyan'):
            self.assertIn(name, c)

    def test_never_overwrites_a_foreign_theme(self):
        with tempfile.TemporaryDirectory() as home:
            theme(pathlib.Path(home) / '.config/omarchy/themes', 'opal', SEMANTIC)
            with self.assertRaises(ValueError):
                ot.export(self.ROLES, 'dark', home=home)
            with self.assertRaises(ValueError):
                ot.export(self.ROLES, 'dark', name='../escape', home=home)


if __name__ == '__main__':
    unittest.main()
