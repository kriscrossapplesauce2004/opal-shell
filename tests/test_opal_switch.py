import io, json, os, pathlib, sys, tempfile, unittest
from unittest import mock
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'tools/switch'))
import opal_switch, switch_root


class FakeProc:
    def __init__(self, lines, code=0):
        self.stdout = io.StringIO(''.join(l + '\n' for l in lines))
        self.stdin = io.StringIO()
        self.code = code
    def wait(self): return self.code
    def poll(self): return None


def checks(**over):
    d = {'distro': {'id': 'fedora', 'name': 'Fedora', 'like': []}, 'manager': 'dnf', 'arch': 'x86_64', 'desktop': 'GNOME', 'session': 'wayland', 'dm': 'GDM',
         'gpu': {'nvidia': False, 'other': True, 'modeset': False}, 'have': {'hyprland': False, 'quickshell': False, 'python': True, 'git': True, 'pkexec': True, 'curl': True, 'hyprlandLua': False},
         'available': {'hyprland': True, 'quickshell': 'copr'}, 'missing': ['hyprland', 'quickshell'], 'fonts': {'Material Symbols Rounded': True, 'Google Sans Flex': False},
         'hyprVersion': '', 'hyprConfig': False, 'opalInstalled': False, 'sessionInstalled': False, 'terminal': 'ptyxis', 'files': 'nautilus', 'found': {}, 'source': '/src', 'free': 50 * 1024 ** 3}
    d.update(over)
    d['problems'], d['warnings'] = opal_switch.problems(d)
    return d


class DetectTests(unittest.TestCase):
    def test_desktop_names(self):
        self.assertEqual(opal_switch.desktop_name({'XDG_CURRENT_DESKTOP': 'ubuntu:GNOME'}), 'GNOME')
        self.assertEqual(opal_switch.desktop_name({'XDG_CURRENT_DESKTOP': 'KDE'}), 'KDE Plasma')
        self.assertEqual(opal_switch.desktop_name({'DESKTOP_SESSION': 'xfce'}), 'Xfce')
        self.assertEqual(opal_switch.desktop_name({}), '')

    def test_accent_maps_to_nearest_palette(self):
        self.assertEqual(opal_switch.hue_palette(61, 174, 233), 3)   # Breeze blue → Sky
        self.assertEqual(opal_switch.hue_palette(230, 97, 0), 2)     # orange → Peach
        self.assertEqual(opal_switch.hue_palette(38, 162, 105), 1)   # green → Tide
        self.assertEqual(opal_switch.hue_palette(145, 65, 172), 0)   # purple → Iris

    def test_desktop_ids_are_cleaned(self):
        self.assertEqual(opal_switch.desktop_id('firefox.desktop'), 'firefox')
        self.assertEqual(opal_switch.desktop_id('applications:org.kde.dolphin.desktop'), 'org.kde.dolphin')
        self.assertEqual(opal_switch.desktop_id('file:///usr/share/applications/kitty.desktop'), 'kitty')
        self.assertEqual(opal_switch.desktop_id('evil;rm -rf'), '')

    def test_kde_import(self):
        with tempfile.TemporaryDirectory() as tmp:
            cfg = pathlib.Path(tmp)
            wall = cfg / 'wall.jpg'; wall.write_bytes(b'x')
            (cfg / 'kdeglobals').write_text('[General]\nColorScheme=BreezeDark\nAccentColor=61,174,233\n[Icons]\nTheme=Papirus\n')
            (cfg / 'plasma-org.kde.plasma.desktop-appletsrc').write_text(f'[Wallpaper]\nImage=file://{wall}\n[Applet]\nlaunchers=applications:firefox.desktop,applications:org.kde.dolphin.desktop\n')
            (cfg / 'kxkbrc').write_text('[Layout]\nLayoutList=de,us\nVariantList=nodeadkeys,\n')
            (cfg / 'kcminputrc').write_text('[Libinput][1267][12345][Touchpad]\nNaturalScroll=true\n')
            with mock.patch.object(opal_switch, 'CONFIG', cfg):
                found = opal_switch.import_kde()
        self.assertFalse(found['light'])
        self.assertEqual(found['palette'], 3)
        self.assertEqual(found['wallpaper'], str(wall))
        self.assertEqual(found['pins'], ['firefox', 'org.kde.dolphin'])
        self.assertEqual(found['keyboard'], 'de,us')
        self.assertTrue(found['naturalScroll'])

    def test_problems_block_without_quickshell(self):
        d = checks(available={'hyprland': True, 'quickshell': False})
        self.assertTrue(any('Quickshell' in p for p in d['problems']))
        self.assertFalse(checks()['problems'])

    def test_nvidia_without_modeset_warns(self):
        d = checks(gpu={'nvidia': True, 'other': False, 'modeset': False})
        self.assertTrue(any('NVIDIA' in w for w in d['warnings']))


class PlanTests(unittest.TestCase):
    def test_plan_only_does_what_is_missing(self):
        self.assertEqual(opal_switch.plan(checks(), {}), ['packages', 'session', 'fonts', 'hyprland', 'opal', 'settings'])
        done = checks(missing=[], sessionInstalled=True, hyprConfig=True, fonts={'Material Symbols Rounded': True, 'Google Sans Flex': True})
        self.assertEqual(opal_switch.plan(done, {}), ['opal', 'settings'])
        self.assertNotIn('fonts', opal_switch.plan(checks(), {'fonts': False}))

    def test_settings_changes(self):
        d = checks(found={'light': True, 'palette': 2, 'wallpaper': '/home/a/b c.png', 'pins': ['firefox']})
        out = opal_switch.settings_changes(d, {'windows': 'tiling', 'ai': False}, {})
        self.assertEqual(out['light'], True)
        self.assertEqual(out['palette'], 2)
        self.assertFalse(out['dynamicColors'])
        self.assertEqual(out['wallpaperPath'], 'file:///home/a/b%20c.png')
        self.assertEqual(out['favorites'], ['firefox'])
        self.assertFalse(out['floatingMode'])
        self.assertFalse(out['aiFeatures'])
        self.assertFalse(out['onboarded'])
        # Choices left off keep Opal's own defaults, and a returning user is not sent through setup again.
        out = opal_switch.settings_changes(d, {'importLook': False, 'importPins': False}, {'onboarded': True})
        self.assertNotIn('light', out); self.assertNotIn('favorites', out); self.assertNotIn('onboarded', out); self.assertNotIn('aiFeatures', out)

    def test_hyprland_config_uses_this_computer(self):
        with tempfile.TemporaryDirectory() as tmp:
            stock = pathlib.Path(tmp) / 'hyprland.lua'
            stock.write_text('local terminal    = "kitty"\nlocal fileManager = "dolphin"\nhl.config({ input = { kb_layout  = "us", kb_variant = "", touchpad = { natural_scroll = false } } })\n')
            text = opal_switch.hyprland_config({'terminal': 'ptyxis', 'files': 'nautilus', 'found': {'keyboard': 'gb,us', 'keyboardVariant': 'extd,', 'naturalScroll': True}}, {}, stock)
        self.assertIn('local terminal    = "ptyxis"', text)
        self.assertIn('local fileManager = "nautilus"', text)
        self.assertIn('kb_layout  = "gb,us"', text)
        self.assertIn('kb_variant = "extd,"', text)
        self.assertIn('natural_scroll = true', text)
        self.assertNotIn('"', opal_switch.lua_text('us"); os.execute("x'))


class SwitchRunTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = pathlib.Path(self.tmp.name)
        self.patches = [mock.patch.object(opal_switch, 'STATE', root / 'state'), mock.patch.object(opal_switch, 'HYPR_LUA', root / 'hypr/hyprland.lua'),
                        mock.patch.object(opal_switch, 'DATA', root / 'data'), mock.patch.object(opal_switch, 'FONT_CACHE', root / 'cache'),
                        mock.patch.object(opal_switch, 'SESSION_FILE', root / 'opal.desktop'), mock.patch.object(opal_switch, 'STOCK_LUA', root / 'missing.lua')]
        for p in self.patches: p.start()
        self.root = root

    def tearDown(self):
        for p in self.patches: p.stop()
        self.tmp.cleanup()

    def test_full_switch_runs_root_once_then_user_stages(self):
        events, calls = [], []
        def popen(args, **kw):
            calls.append(args)
            if 'pkexec' in args[0]:
                return FakeProc([json.dumps({'stage': 'packages', 'state': 'running'}), json.dumps({'stage': 'packages', 'state': 'done'}),
                                 json.dumps({'stage': 'session', 'state': 'running'}), json.dumps({'stage': 'session', 'state': 'done'})])
            return FakeProc(['Installed windowing plugin to x', 'Installed Opal to y'])
        cache = self.root / 'cache'; cache.mkdir()
        (cache / 'sans.ttf').write_bytes(b'f' * 200_000)
        sw = opal_switch.Switch(events.append, popen=popen, which=lambda n: '/usr/bin/' + n, run=lambda *a, **k: None)
        with mock.patch.object(opal_switch, 'detect', return_value=checks(found={'light': False, 'pins': ['firefox']})), \
             mock.patch.object(opal_switch, 'missing_packages', return_value=[]):
            self.assertTrue(sw.switch({'windows': 'floating', 'ai': False}))
        self.assertEqual(len([c for c in calls if 'pkexec' in c[0]]), 1)
        root_call = calls[0]
        self.assertIn('packages,session', root_call)
        self.assertIn('hyprland,quickshell', root_call)
        self.assertEqual([e['ok'] for e in events if e['event'] == 'done'], [True])
        # The font came from the cache, not the network.
        self.assertTrue((self.root / 'data/fonts/opal/GoogleSansFlex[ROND,opsz,slnt,wdth,wght].ttf').exists())
        prefs = json.loads((self.root / 'state/preferences.json').read_text())
        self.assertEqual(prefs['favorites'], ['firefox'])
        self.assertFalse(prefs['aiFeatures'])
        self.assertTrue((self.root / 'hypr/hyprland.lua').exists())
        self.assertTrue((self.root / 'state/switch-wrote-hyprland').exists())

    def test_cancelled_password_prompt_stops(self):
        events = []
        sw = opal_switch.Switch(events.append, popen=lambda args, **kw: FakeProc([], code=126), which=lambda n: '/usr/bin/' + n)
        with mock.patch.object(opal_switch, 'detect', return_value=checks()):
            self.assertFalse(sw.switch({}))
        self.assertIn('The password prompt was cancelled', [e.get('text') for e in events])
        self.assertFalse((self.root / 'state/preferences.json').exists())

    def test_problems_stop_before_anything_runs(self):
        events = []
        sw = opal_switch.Switch(events.append, popen=lambda *a, **k: self.fail('nothing may run'))
        with mock.patch.object(opal_switch, 'detect', return_value=checks(available={'quickshell': False})):
            self.assertFalse(sw.switch({}))
        self.assertEqual(events[-1], {'event': 'done', 'ok': False})

    def test_undo_restores_what_the_switch_changed(self):
        state = self.root / 'state'; state.mkdir()
        (state / 'preferences.json').write_text('{"onboarded":false}')
        (state / 'switch-preferences-before.json').write_text('{"palette":3}')
        (state / 'switch-wrote-hyprland').write_text('x')
        lua = self.root / 'hypr/hyprland.lua'; lua.parent.mkdir(); lua.write_text('-- opal')
        events = []
        sw = opal_switch.Switch(events.append)
        with mock.patch.object(opal_switch, 'detect', return_value=checks()):
            self.assertTrue(sw.undo())
        self.assertEqual(json.loads((state / 'preferences.json').read_text()), {'palette': 3})
        self.assertFalse(lua.exists())
        self.assertTrue(lua.with_suffix('.lua.opal-switch').exists())

    def test_fonts_are_cached_for_the_window(self):
        fetched = []
        def fetch(req, timeout=0):
            fetched.append(req.full_url)
            return io.BytesIO(b'font')
        with mock.patch.object(opal_switch, 'font_installed', side_effect=lambda f: f == 'Google Sans Flex'):
            self.assertTrue(opal_switch.cache_fonts(fetch=fetch))
        self.assertEqual(len(fetched), 1)
        self.assertEqual((self.root / 'cache/symbols.ttf').read_bytes(), b'font')


class RootHelperTests(unittest.TestCase):
    def test_arguments_are_allowlisted(self):
        opts = switch_root.parse_args(['--stages', 'packages,session', '--pm', 'dnf', '--user', 'sam', '--packages', 'hyprland,quickshell'])
        self.assertEqual(opts['stages'], ['packages', 'session'])
        self.assertEqual(opts['packages'], ['hyprland', 'quickshell'])
        for bad in (['--stages', 'packages;rm'], ['--stages', 'session', '--pm', 'sh'], ['--stages', 'session', '--user', 'root;x'],
                    ['--stages', 'packages', '--packages', 'a b'], ['--stages', 'session', '--evil', '1'], ['--stages'], []):
            with self.assertRaises(ValueError):
                switch_root.parse_args(bad)

    def test_session_entry_starts_opal(self):
        self.assertIn('Exec=/usr/local/bin/opal-session', switch_root.SESSION_TEXT)
        self.assertIn('export OPAL_SESSION=1', switch_root.LAUNCHER_TEXT)

    def test_session_files_written_and_removed(self):
        with tempfile.TemporaryDirectory() as tmp:
            session, launcher = pathlib.Path(tmp) / 'opal.desktop', pathlib.Path(tmp) / 'bin/opal-session'
            out = io.StringIO()
            with mock.patch.object(switch_root, 'SESSION_FILE', session), mock.patch.object(switch_root, 'LAUNCHER', launcher), mock.patch('sys.stdout', out):
                self.assertEqual(switch_root.run_session({}), 0)
                self.assertTrue(os.access(launcher, os.X_OK))
                self.assertEqual(oct(session.stat().st_mode & 0o777), '0o644')
                self.assertEqual(switch_root.run_remove_session({}), 0)
            self.assertFalse(session.exists() or launcher.exists())


if __name__ == '__main__':
    unittest.main()
