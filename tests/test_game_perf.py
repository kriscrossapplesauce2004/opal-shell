import os, pathlib, sys, tempfile, unittest
from unittest.mock import patch
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'src'))
import game_perf as gp
import game_stats as gs


class Result:
    def __init__(self, out, code=0): self.stdout, self.returncode = out, code


class MangoHudConfigTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.home = pathlib.Path(self.tmp.name)
        patcher = patch.dict(os.environ, {'HOME': self.tmp.name})
        patcher.start(); self.addCleanup(patcher.stop); self.addCleanup(self.tmp.cleanup)

    def test_path_follows_home_and_stays_in_opal_state(self):
        self.assertEqual(gp.config_path(), self.home / '.local/state/opal/mangohud/MangoHud.conf')
        self.assertFalse((self.home / '.config/MangoHud').exists())

    def test_missing_file_gives_defaults(self):
        self.assertEqual(gp.read_config(), {'fpsLimit': 0, 'overlay': 'compact', 'exists': False})
        self.assertIsNone(gp.launch_env())

    def test_write_round_trips_and_keeps_foreign_lines(self):
        path = gp.config_path(); path.parent.mkdir(parents=True)
        path.write_text('legacy_layout=0\ncustom_text=Deck\n')
        gp.write_config(fps_limit=60)
        gp.write_config(overlay='full')
        text = path.read_text()
        self.assertIn('legacy_layout=0', text)
        self.assertIn('custom_text=Deck', text)
        self.assertEqual(text.count('# opal:begin'), 1)
        self.assertIn('fps_limit=60', text)
        self.assertIn('gamemode', text)
        self.assertEqual(gp.read_config(), {'fpsLimit': 60, 'overlay': 'full', 'exists': True})
        self.assertEqual(gp.launch_env()['MANGOHUD_CONFIGFILE'], str(path))

    def test_off_level_and_validation(self):
        gp.write_config(overlay='off')
        self.assertIn('no_display', gp.config_path().read_text())
        with self.assertRaises(ValueError): gp.write_config(fps_limit=61)
        with self.assertRaises(ValueError): gp.write_config(overlay='loud')
        self.assertFalse(list(gp.config_path().parent.glob('*.tmp')))

    def test_launch_option_names_the_opal_file(self):
        self.assertIn(str(gp.config_path()), gp.launch_option())
        self.assertTrue(gp.launch_option().endswith('mangohud %command%'))


class SystemProbeTests(unittest.TestCase):
    def test_gamemode(self):
        which = lambda name: '/usr/bin/' + name
        self.assertEqual(gp.gamemode_status(lambda *a, **k: Result('gamemode is active with 2 clients'), which), {'available': True, 'active': True, 'clients': 2})
        self.assertFalse(gp.gamemode_status(lambda *a, **k: Result('gamemode is inactive'), which)['active'])
        self.assertFalse(gp.gamemode_status(lambda *a, **k: Result(''), lambda n: None)['available'])

    def test_power_profiles(self):
        text = '  performance:\n    Driver: x\n\n* balanced:\n    Driver: y\n\n  power-saver:\n    Driver: z\n'
        found = gp.power_profiles(lambda *a, **k: Result(text), lambda n: '/x')
        self.assertEqual(found, {'available': True, 'profiles': ['performance', 'balanced', 'power-saver'], 'active': 'balanced'})
        self.assertFalse(gp.power_profiles(lambda *a, **k: Result(''), lambda n: None)['available'])

    def test_tdp_hidden_when_not_writable(self):
        with tempfile.TemporaryDirectory() as root:
            hw = pathlib.Path(root, 'class/drm/card0/device/hwmon/hwmon3'); hw.mkdir(parents=True)
            (hw / 'power1_cap').write_text('15000000'); (hw / 'power1_cap_min').write_text('4000000'); (hw / 'power1_cap_max').write_text('25000000')
            os.chmod(hw / 'power1_cap', 0o444)
            if os.access(hw / 'power1_cap', os.W_OK): self.skipTest('running as a user that ignores file modes')
            self.assertIsNone(gp.gpu_interfaces(root)['tdp'])
            with self.assertRaises(ValueError): gp.set_tdp(10, root)

    def test_tdp_and_gpu_level_when_writable(self):
        with tempfile.TemporaryDirectory() as root:
            device = pathlib.Path(root, 'class/drm/card0/device'); hw = device / 'hwmon/hwmon3'; hw.mkdir(parents=True)
            (hw / 'power1_cap').write_text('15000000'); (hw / 'power1_cap_min').write_text('4000000'); (hw / 'power1_cap_max').write_text('25000000')
            (device / 'power_dpm_force_performance_level').write_text('auto\n')
            found = gp.gpu_interfaces(root)
            self.assertEqual((found['tdp']['watts'], found['tdp']['min'], found['tdp']['max']), (15, 4, 25))
            self.assertEqual(found['gpu']['level'], 'auto')
            self.assertEqual(gp.set_tdp(99, root), 25)
            self.assertEqual((hw / 'power1_cap').read_text(), '25000000')
            self.assertEqual(gp.set_gpu_level('high', root), 'high')
            with self.assertRaises(ValueError): gp.set_gpu_level('manual', root)

    def test_no_gpu_interface_means_none(self):
        with tempfile.TemporaryDirectory() as root:
            self.assertEqual(gp.gpu_interfaces(root), {'tdp': None, 'gpu': None})

    def test_controller_batteries(self):
        with tempfile.TemporaryDirectory() as root:
            def device(name, **files):
                folder = pathlib.Path(root, name); folder.mkdir()
                for key, value in files.items(): (folder / key).write_text(value)
            device('BAT0', type='Battery', capacity='80', scope='System')
            device('AC', type='Mains')
            device('ps-controller-battery-aa', type='Battery', capacity='64', status='Charging', scope='Device', model_name='DualSense')
            device('hid-xbox-battery', type='Battery', capacity_level='Low', scope='Device')
            device('hid-keyboard-battery', type='Battery', capacity='90', scope='System')
            found = gp.controller_batteries(root)
            self.assertEqual([(b['name'], b['percent'], b['charging']) for b in found], [('hid-xbox-battery', 25, False), ('DualSense', 64, True)])
        self.assertEqual(gp.controller_batteries('/nonexistent-opal-test'), [])


class DispatchTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        patcher = patch.dict(os.environ, {'HOME': self.tmp.name})
        patcher.start(); self.addCleanup(patcher.stop); self.addCleanup(self.tmp.cleanup)
        self.events, self.spawned = [], []

    def run_command(self, command):
        gp.dispatch(command, self.events.append, self.spawned.append, sysfs=self.tmp.name)

    def test_set_fps_limit_emits_snapshot(self):
        self.run_command({'action': 'perf-set', 'key': 'fpsLimit', 'value': 40})
        self.assertEqual(self.events[-1]['event'], 'gamePerf')
        self.assertEqual(self.events[-1]['fpsLimit'], 40)

    def test_bad_values_become_messages(self):
        self.run_command({'action': 'perf-set', 'key': 'fpsLimit', 'value': 'fast'})
        self.run_command({'action': 'perf-set', 'key': 'fpsLimit', 'value': 61})
        self.assertEqual([e['event'] for e in self.events], ['message', 'gamePerf', 'message', 'gamePerf'])

    def test_uninstall_only_steam_ids(self):
        with patch.object(gp.shutil, 'which', return_value='/usr/bin/steam'):
            self.run_command({'action': 'game-uninstall', 'id': 'steam:123'})
            self.run_command({'action': 'game-uninstall', 'id': 'steam:1; rm -rf /'})
            self.run_command({'action': 'game-uninstall', 'id': 'lutris:x'})
        self.assertEqual(self.spawned, [['steam', 'steam://uninstall/123']])
        self.assertEqual(sum(e['event'] == 'message' for e in self.events), 2)


VDF = '''"UserLocalConfigStore" { "Software" { "Valve" { "Steam" { "apps" {
  "123" { "LastPlayed" "1700000000" "Playtime" "754" }
  "9" { "Playtime" "2" }
} } } } }'''


class GameStatsTests(unittest.TestCase):
    def test_playtime_size_and_non_steam(self):
        with tempfile.TemporaryDirectory() as root:
            root = pathlib.Path(root)
            (root / 'userdata/42/config').mkdir(parents=True); (root / 'steamapps').mkdir()
            (root / 'userdata/42/config/localconfig.vdf').write_text(VDF)
            (root / 'steamapps/appmanifest_123.acf').write_text('"AppState" { "appid" "123" "SizeOnDisk" "5000" }')
            found = gs.detail('steam:123', root)
            self.assertEqual((found['playtimeMinutes'], found['lastPlayed'], found['sizeBytes'], found['uninstallable']), (754, 1700000000, 5000, True))
            self.assertIsNone(gs.detail('steam:77', root)['playtimeMinutes'])
        other = gs.detail('prism:abc')
        self.assertEqual((other['playtimeMinutes'], other['uninstallable']), (None, False))

    def test_unreadable_config_is_not_fatal(self):
        with tempfile.TemporaryDirectory() as root:
            (pathlib.Path(root) / 'userdata/1/config').mkdir(parents=True)
            (pathlib.Path(root) / 'userdata/1/config/localconfig.vdf').write_bytes(b'\xff\x00garbage {')
            self.assertIsNone(gs.steam_playtime('1', pathlib.Path(root)))


if __name__ == '__main__':
    unittest.main()
