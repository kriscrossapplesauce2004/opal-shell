import json, pathlib, re, sys, tempfile, unittest
import xml.etree.ElementTree as ET
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'src'))
import system_tools as st
import theme_export as te

DARK = dict(primary='#cfbdff', onPrimary='#31205f', primaryContainer='#4b3a79', onPrimaryContainer='#eaddff', secondary='#c6d6ae', tertiary='#efb8c8',
            base='#17141f', surface='#302b39', surfaceHigh='#403849', text='#f0e9f7', subtext='#c5bccf', error='#ffb4ab')
LIGHT = dict(DARK, primary='#7355ad', onPrimary='#ffffff', base='#f7f0ff', surface='#ebe4f1', surfaceHigh='#dfd6e8', text='#211d29', subtext='#635c6d')


class Result:
    def __init__(self, out='', code=0): self.stdout, self.returncode = out, code


class Fake:
    """Fake command runner with a small gsettings store."""
    def __init__(self, gs=None, fail=()):
        self.calls = []; self.gs = dict(gs or {}); self.fail = fail
    def __call__(self, args, timeout=20):
        self.calls.append(list(args))
        if args[0] in self.fail: return Result('', 1)
        if args[:2] == ['gsettings', 'get']:
            key = args[3]
            return Result(self.gs[key]) if key in self.gs else Result('', 1)
        if args[:2] == ['gsettings', 'set']: self.gs[args[3]] = args[4]
        if args[:3] == ['flatpak', 'list', '--runtime']: return Result('org.kde.KStyle.Kvantum\n')
        return Result('')
    def find(self, *prefix): return [c for c in self.calls if c[:len(prefix)] == list(prefix)]


def tools(*names): return lambda n: '/usr/bin/' + n if n in names else None
ALL = tools('gsettings', 'kitty', 'pkill', 'dbus-send', 'plasma-apply-colorscheme', 'hyprctl', 'flatpak', 'fc-list')
GS = {'color-scheme': "'prefer-light'", 'gtk-theme': "'Adwaita'", 'accent-color': "'blue'", 'font-name': "'Cantarell 11'", 'icon-theme': "'Adwaita'", 'cursor-theme': "'Adwaita'", 'cursor-size': '24', 'text-scaling-factor': '1.0'}
OPTS = {'font': 'Google Sans Flex', 'iconTheme': 'Papirus', 'cursorTheme': 'Bibata', 'cursorSize': 32, 'scale': 1.25}


def tree(root):
    return {str(p.relative_to(root)): p.read_text() for p in sorted(root.rglob('*')) if p.is_file()}


class ThemeExportTests(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory(); self.home = pathlib.Path(self.dir.name)
    def tearDown(self): self.dir.cleanup()
    def run_export(self, colors=DARK, targets=te.TARGETS, runner=None, **kw):
        runner = runner or Fake(GS)
        kw.setdefault('options', OPTS); kw.setdefault('which', ALL); kw.setdefault('kvantum', lambda: True)
        return te.export(colors, targets, home=self.home, runner=runner, **kw), runner

    def test_all_files_written(self):
        done, _ = self.run_export()
        self.assertEqual(set(done), set(te.TARGETS))
        files = tree(self.home)
        for rel in ('.config/gtk-3.0/opal.css', '.config/gtk-4.0/opal.css', '.config/kitty/opal-theme.conf', '.config/qt6ct/colors/Opal.conf',
                    '.local/share/color-schemes/Opal.colors', '.config/Kvantum/Opal/Opal.kvconfig', '.config/Kvantum/Opal/Opal.svg', '.icons/default/index.theme',
                    '.config/environment.d/opal-cursor.conf', '.config/gtk-4.0/settings.ini', '.config/kdeglobals'):
            self.assertIn(rel, files)
        self.assertIn('@define-color accent_bg_color #cfbdff;', files['.config/gtk-4.0/opal.css'])
        self.assertIn('@define-color theme_bg_color #17141f;', files['.config/gtk-3.0/opal.css'])
        self.assertIn('border-radius: %dpx' % te.SHAPES['md'], files['.config/gtk-4.0/opal.css'])
        self.assertIn('Inherits=Bibata', files['.icons/default/index.theme'])
        self.assertEqual(te.ini_get(files['.config/kdeglobals'], 'General', 'ColorScheme'), 'Opal')
        self.assertEqual(te.ini_get(files['.config/kdeglobals'], 'Icons', 'Theme'), 'Papirus')
        self.assertEqual(te.ini_get(files['.config/kdeglobals'], 'Colors:Selection', 'BackgroundNormal'), '207,189,255')
        self.assertEqual(te.ini_get(files['.config/qt6ct/qt6ct.conf'], 'Appearance', 'style'), 'kvantum')
        self.assertEqual(te.ini_get(files['.config/Kvantum/kvantum.kvconfig'], 'General', 'theme'), 'Opal')
        self.assertEqual(te.ini_get(files['.config/gtk-3.0/settings.ini'], 'Settings', 'gtk-cursor-theme-size'), '32')

    def test_kde_makes_kvantum_and_opal_the_default_for_all_qt_apps(self):
        which = tools('systemctl', 'dbus-update-activation-environment', 'hyprctl', 'dbus-send')
        done, runner = self.run_export(targets=('kde',), which=which, options=dict(OPTS, platformTheme='kde'))
        files = tree(self.home)
        self.assertEqual(te.ini_get(files['.config/kdeglobals'], 'KDE', 'widgetStyle'), 'kvantum')
        self.assertIn('QT_QPA_PLATFORMTHEME=kde', files['.config/environment.d/opal-qt.conf'])
        self.assertTrue(runner.find('systemctl', '--user', 'set-environment', 'QT_QPA_PLATFORMTHEME=kde'))
        self.assertTrue(runner.find('dbus-update-activation-environment', '--systemd', 'QT_QPA_PLATFORMTHEME=kde'))
        self.assertTrue(any('hl.env("QT_QPA_PLATFORMTHEME", "kde")' in ' '.join(c) for c in runner.find('hyprctl', 'eval')))
        # A temporary home must never change this process.
        import os
        self.assertNotEqual(os.environ.get('QT_QPA_PLATFORMTHEME'), 'kde-from-test')
        runner2 = Fake(GS)
        te.revert(('kde',), home=self.home, runner=runner2, which=which, kvantum=lambda: True)
        self.assertNotIn('.config/environment.d/opal-qt.conf', tree(self.home))
        self.assertTrue(runner2.find('systemctl', '--user', 'unset-environment', 'QT_QPA_PLATFORMTHEME'))

    def test_ini_set_inserts_after_last_real_line(self):
        text = '[General]\nfont=Inter\n\n[KDE]\ncontrast=4\n'
        self.assertEqual(te.ini_set(text, 'General', 'ColorScheme', 'Opal'), '[General]\nfont=Inter\nColorScheme=Opal\n\n[KDE]\ncontrast=4\n')

    def test_kde_keeps_user_widget_style_when_kvantum_missing(self):
        (self.home / '.config').mkdir(parents=True)
        (self.home / '.config/kdeglobals').write_text('[KDE]\nwidgetStyle=Breeze\n')
        self.run_export(targets=('kde',), kvantum=lambda: False, options=dict(OPTS, platformTheme=''))
        files = tree(self.home)
        self.assertEqual(te.ini_get(files['.config/kdeglobals'], 'KDE', 'widgetStyle'), 'Breeze')
        self.assertNotIn('.config/environment.d/opal-qt.conf', files)

    def test_kvantum_svg_is_valid_with_all_slices(self):
        svg = te.kv_svg(DARK, False)
        root = ET.fromstring(svg)
        ids = {e.get('id') for e in root.iter() if e.get('id')}
        for base in ('button-normal', 'button-pressed', 'lineedit-focused', 'tab-toggled', 'progress-pattern-normal'):
            for part in ('', '-top', '-bottom', '-left', '-right', '-topleft', '-topright', '-bottomleft', '-bottomright'):
                self.assertIn(base + part, ids)
        self.assertIn('checkbox-checked', ids); self.assertIn('radio-normal', ids)
        self.assertNotIn('#MARK#', svg)
        config = te.kv_config(LIGHT, True)
        self.assertIn('[%General]', config); self.assertIn('window.color=#f7f0ff', config)

    def test_kvantum_skipped_when_missing(self):
        self.run_export(kvantum=lambda: False)
        files = tree(self.home)
        self.assertNotIn('.config/Kvantum/Opal/Opal.svg', files)
        self.assertIsNone(te.ini_get(files['.config/qt6ct/qt6ct.conf'], 'Appearance', 'style'))

    def test_live_switching_gsettings_and_notify(self):
        _, run = self.run_export(DARK)
        self.assertEqual(run.gs['color-scheme'], "'prefer-dark'")
        self.assertEqual(run.gs['accent-color'], "'purple'")
        self.assertEqual(run.gs['font-name'], "'Google Sans Flex 10'")
        self.assertEqual(run.gs['gtk-theme'], "'Adwaita'")
        self.assertTrue(run.find('gsettings', 'set', te.IFACE, 'gtk-theme', "'Adwaita-dark'"))
        self.assertTrue(run.find('dbus-send', '--session', '--type=signal', '/KGlobalSettings', 'org.kde.KGlobalSettings.notifyChange', 'int32:0', 'int32:0'))
        self.assertTrue(run.find('plasma-apply-colorscheme', 'Opal'))
        self.assertTrue(run.find('hyprctl', 'setcursor', 'Bibata', '32'))
        self.assertTrue(run.find('kitty', '@', 'set-colors', '--all', '--configured'))
        self.assertFalse(run.find('pkill'))
        self.run_export(LIGHT, runner=run)
        self.assertEqual(run.gs['color-scheme'], "'default'")

    def test_kitty_falls_back_to_signal(self):
        run = Fake(GS, fail=('kitty',))
        self.run_export(targets=['kitty'], runner=run)
        self.assertTrue(run.find('pkill', '-USR1', '-x', 'kitty'))

    def test_missing_tools_degrade(self):
        done, run = self.run_export(which=tools(), kvantum=lambda: False)
        self.assertNotIn('hyprland', done); self.assertNotIn('flatpak', done)
        self.assertEqual(run.calls, [])
        self.assertTrue((self.home / '.config/gtk-4.0/opal.css').exists())

    def test_no_clobber_and_exact_revert(self):
        cfg = self.home / '.config'
        (cfg / 'kitty').mkdir(parents=True); (cfg / 'kitty/kitty.conf').write_text('font_size 12\n')
        (cfg / 'gtk-4.0').mkdir(); (cfg / 'gtk-4.0/gtk.css').write_text('/* mine */\n')
        (cfg / 'gtk-3.0').mkdir(); (cfg / 'gtk-3.0/settings.ini').write_text('[Settings]\ngtk-theme-name=Mine\ngtk-font-name=Old 9\n')
        (cfg / 'kdeglobals').write_text('[General]\nfont=Old,9\nColorScheme=BreezeDark\n[KDE]\nSingleClick=false\n')
        (cfg / 'qt6ct').mkdir(); (cfg / 'qt6ct/qt6ct.conf').write_text('[Appearance]\nstyle=Fusion\nicon_theme=breeze\n')
        (cfg / 'Kvantum').mkdir(); (cfg / 'Kvantum/kvantum.kvconfig').write_text('[General]\ntheme=KvAdapta\n')
        (self.home / '.icons/default').mkdir(parents=True); (self.home / '.icons/default/index.theme').write_text('[Icon Theme]\nInherits=breeze_cursors\nName=mine\n')
        before = tree(self.home)
        run = Fake(GS)
        self.run_export(runner=run)
        mid = tree(self.home)
        self.assertEqual(te.ini_get(mid['.config/kdeglobals'], 'KDE', 'SingleClick'), 'false')
        self.assertEqual(te.ini_get(mid['.config/gtk-3.0/settings.ini'], 'Settings', 'gtk-theme-name'), 'Mine')
        self.assertIn('font_size 12', mid['.config/kitty/kitty.conf'])
        self.assertIn('/* mine */', mid['.config/gtk-4.0/gtk.css'])
        self.assertEqual(te.ini_get(mid['.icons/default/index.theme'], 'Icon Theme', 'Name'), 'mine')
        self.run_export(runner=run)
        self.assertEqual(tree(self.home).keys(), mid.keys())
        te.revert(te.TARGETS, home=self.home, runner=run, which=ALL, kvantum=lambda: True)
        after = tree(self.home)
        after.pop('.local/state/opal/theme-export-state.json', None)
        self.assertEqual({k: v for k, v in after.items() if k in before}.keys(), before.keys())
        for rel, text in before.items():
            self.assertEqual(after[rel].replace('\n\n', '\n').strip(), text.strip(), rel)
        self.assertEqual(set(after), set(before))
        self.assertEqual(run.gs['font-name'], "'Cantarell 11'"); self.assertEqual(run.gs['color-scheme'], "'prefer-light'")
        self.assertEqual(run.gs['accent-color'], "'blue'"); self.assertEqual(run.gs['cursor-size'], '24')
        self.assertFalse((self.home / '.local/state/opal/theme-export-state.json').exists())

    def test_revert_leaves_user_changes(self):
        run = Fake(GS)
        self.run_export(runner=run)
        path = self.home / '.config/kdeglobals'
        path.write_text(te.ini_set(path.read_text(), 'Icons', 'Theme', 'UserPick'))
        run.gs['font-name'] = "'User Font 12'"
        te.revert(te.TARGETS, home=self.home, runner=run, which=ALL)
        self.assertEqual(te.ini_get(path.read_text(), 'Icons', 'Theme'), 'UserPick')
        self.assertEqual(run.gs['font-name'], "'User Font 12'")

    def test_flatpak_overrides_and_revert(self):
        ov = self.home / '.local/share/flatpak/overrides'; ov.mkdir(parents=True)
        (ov / 'global').write_text('[Context]\nfilesystems=xdg-config/gtk-3.0:ro;\n')
        (self.home / '.themes/Mine').mkdir(parents=True)
        done, run = self.run_export(targets=['flatpak'], options={'gtkTheme': 'Mine'})
        self.assertEqual(done, ['flatpak'])
        fs = [c[3] for c in run.find('flatpak', 'override')]
        self.assertNotIn('--filesystem=xdg-config/gtk-3.0:ro', fs)
        self.assertIn('--filesystem=xdg-config/gtk-4.0:ro', fs); self.assertIn('--filesystem=~/.themes:ro', fs)
        self.assertIn('--env=GTK_THEME=Mine', fs); self.assertIn('--env=QT_STYLE_OVERRIDE=kvantum', fs)
        run.calls.clear()
        te.revert(['flatpak'], home=self.home, runner=run, which=ALL)
        reverted = [c[3] for c in run.find('flatpak', 'override')]
        self.assertIn('--nofilesystem=xdg-config/gtk-4.0', reverted); self.assertNotIn('--nofilesystem=xdg-config/gtk-3.0', reverted)
        self.assertIn('--unset-env=GTK_THEME', reverted)

    def test_flatpak_no_unsafe_env(self):
        _, run = self.run_export(targets=['flatpak'], options={'gtkTheme': 'Missing'}, kvantum=lambda: False)
        self.assertFalse([c for c in run.calls if any(a.startswith('--env') for a in c)])

    def test_invalid_input(self):
        with self.assertRaises(ValueError): te.export(dict(DARK, primary='red'), ['gtk'], home=self.home)
        _, run = self.run_export(targets=['sync'], options={'font': 'x\ny', 'cursorSize': 'big', 'iconTheme': 5})
        self.assertFalse(run.find('gsettings', 'set'))

    def test_discover(self):
        for name, cursor in (('Papirus', False), ('Bibata', True)):
            d = self.home / '.icons' / name; d.mkdir(parents=True)
            (d / 'index.theme').write_text('[Icon Theme]\nName=%s\n%s' % (name, '' if cursor else 'Directories=16x16\n'))
            if cursor: (d / 'cursors').mkdir()
        run = lambda a, timeout=20: Result('Inter,Inter Display\nGoogle Sans Flex\n')
        found = te.discover(self.home, runner=run, which=ALL, roots=[self.home / '.icons'])
        self.assertEqual(found, {'icons': ['Papirus'], 'cursors': ['Bibata'], 'fonts': ['Google Sans Flex', 'Inter']})

    def test_system_tools_api_delegates(self):
        run = Fake(GS)
        self.assertEqual(st.export_theme(DARK, ['gtk'], self.home, runner=run), ['gtk'])
        st.remove_export(['gtk'], self.home, runner=run)
        self.assertFalse((self.home / '.config/gtk-4.0/opal.css').exists())

    def test_shapes_match_theme_qml(self):
        qml = (pathlib.Path(__file__).resolve().parents[1] / 'src/Theme.qml').read_text()
        for key, name in (('xs', 'Xs'), ('sm', 'Sm'), ('md', 'Md'), ('lg', 'Lg'), ('xl', 'Xl')):
            self.assertEqual(int(re.search(r'shape%s: (\d+)' % name, qml).group(1)), te.SHAPES[key])

    def test_debounce_keeps_last(self):
        import threading
        out, event = [], threading.Event()
        d = te.Debounce(.05)
        d.submit(lambda: out.append(1)); d.submit(lambda: (out.append(2), event.set()))
        self.assertTrue(event.wait(2)); self.assertEqual(out, [2])


if __name__ == '__main__': unittest.main()
