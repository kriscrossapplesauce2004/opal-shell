import pathlib, sys, tempfile, unittest
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'src'))
import waydroid_bridge


class FakeResult:
    def __init__(self, stdout='', returncode=0, stderr=''):
        self.stdout = stdout
        self.returncode = returncode
        self.stderr = stderr


class FakeActions:
    def __init__(self, clients=None, monitors=None):
        self._clients = clients or []
        self._monitors = monitors or [{'x': 0, 'y': 0, 'width': 1920, 'height': 1080}]
        self.calls = []
    def clients(self): return self._clients
    def monitors(self): return self._monitors
    def set_floating(self, addr, fl): self.calls.append(('float', addr, fl))
    def geometry(self, addr, x, y, w, h): self.calls.append(('geom', addr, x, y, w, h))


class WaydroidBridgeTests(unittest.TestCase):
    def test_package_id_parsing_and_preferences(self):
        self.assertEqual(waydroid_bridge.is_waydroid_id('waydroid.org.fdroid.fdroid.desktop'), 'org.fdroid.fdroid')
        self.assertEqual(waydroid_bridge.is_waydroid_id('waydroid.com.discord'), 'com.discord')
        self.assertEqual(waydroid_bridge.is_waydroid_id('firefox.desktop'), '')
        self.assertEqual(waydroid_bridge.is_waydroid_id('waydroid.;rm -rf /'), '')
        self.assertTrue(waydroid_bridge.valid_preference('waydroidSyncTheme', True))
        self.assertTrue(waydroid_bridge.valid_preference('waydroidAspects', {'org.fdroid.fdroid': 'phone'}))
        self.assertFalse(waydroid_bridge.valid_preference('waydroidAspects', {'bad': 'phone'}))
        self.assertFalse(waydroid_bridge.valid_preference('waydroidAspects', {'org.fdroid.fdroid': 'huge'}))

    def test_status_parser_and_app_discovery(self):
        parsed = waydroid_bridge.parse_status_text('Session:\tRUNNING\nContainer:\tRUNNING\nIP address:\t192.168.240.112\nWayland display:\twall-0\n')
        self.assertEqual(parsed, {'session': 'running', 'container': 'running', 'ip': '192.168.240.112', 'display': 'wall-0'})
        with tempfile.TemporaryDirectory() as home:
            apps_dir = pathlib.Path(home) / '.local/share/applications'
            apps_dir.mkdir(parents=True)
            (apps_dir / 'waydroid.org.fdroid.fdroid.desktop').write_text('[Desktop Entry]\nType=Application\nName=F-Droid\nIcon=fdroid\n')
            (apps_dir / 'waydroid.hidden.app.desktop').write_text('[Desktop Entry]\nType=Application\nName=Hidden\nNoDisplay=true\n')
            apps = waydroid_bridge.discover_android_apps(home)
            self.assertEqual(len(apps), 1)
            self.assertEqual((apps[0]['package'], apps[0]['name']), ('org.fdroid.fdroid', 'F-Droid'))

    def test_cold_boot_launch_emits_live_activity_and_syncs_theme(self):
        events, runs, popens = [], [], []
        states = [
            'Session:\tSTOPPED\nContainer:\tSTOPPED\n',
            'Session:\tSTOPPED\nContainer:\tRUNNING\n',
            'Session:\tRUNNING\nContainer:\tRUNNING\nIP address:\t192.168.240.112\n',
        ]
        def fake_run(cmd, **kw):
            runs.append(cmd)
            if cmd[:2] == ['waydroid', 'status']:
                return FakeResult(states.pop(0) if len(states) > 1 else states[0])
            if cmd[:2] == ['adb', 'connect']:
                return FakeResult('connected to ' + cmd[2] + '\n')
            return FakeResult('true\n')
        def fake_popen(cmd, **kw):
            popens.append(cmd)
        with tempfile.TemporaryDirectory() as home:
            bridge = waydroid_bridge.WaydroidBridge(events.append, run=fake_run, popen=fake_popen, which=lambda n: '/usr/bin/' + n, home=home, sleep=lambda _: None)
            ok = bridge.launch_app('waydroid.org.fdroid.fdroid', name='F-Droid', light=False)
            self.assertTrue(ok)
            self.assertIn(['waydroid', 'session', 'start'], popens)
            self.assertIn(['waydroid', 'app', 'launch', 'org.fdroid.fdroid'], popens)
            # "waydroid shell" needs root, so the theme goes over ADB to the container address.
            self.assertIn(['adb', '-s', '192.168.240.112:5555', 'shell', 'cmd', 'uimode', 'night', 'yes'], runs)
            self.assertFalse(any(c[:2] == ['waydroid', 'shell'] for c in runs))
            act_events = [e for e in events if e.get('event') == 'activity']
            self.assertGreaterEqual(len(act_events), 2)
            self.assertEqual(act_events[0]['data']['id'], 'waydroid-boot')
            self.assertEqual(act_events[-1]['data']['progress'], 1)

    def test_window_aspect_preset_frames_floating_window(self):
        actions = FakeActions(clients=[{'address': '0xabc', 'class': 'waydroid.org.fdroid.fdroid', 'floating': False, 'mapped': True}])
        bridge = waydroid_bridge.WaydroidBridge(lambda _: None, which=lambda _: '/usr/bin/waydroid', actions=actions)
        self.assertTrue(bridge.apply_window_aspect('org.fdroid.fdroid', 'phone'))
        self.assertEqual(actions.calls[0], ('float', '0xabc', True))
        self.assertEqual(actions.calls[1][0:2], ('geom', '0xabc'))
        self.assertEqual(actions.calls[1][4:6], (412, 915))

    def test_apk_install_and_back_key(self):
        events, runs = [], []
        def fake_run(cmd, **kw):
            runs.append(cmd)
            if cmd[:2] == ['waydroid', 'status']:
                return FakeResult('Session:\tRUNNING\nContainer:\tRUNNING\nIP address:\t192.168.240.112\n')
            if cmd[:2] == ['adb', 'connect']:
                return FakeResult('already connected to ' + cmd[2] + '\n')
            return FakeResult('', 0)
        with tempfile.TemporaryDirectory() as tmp:
            apk = pathlib.Path(tmp) / 'Aurora.apk'
            apk.write_bytes(b'PK\x03\x04')
            bridge = waydroid_bridge.WaydroidBridge(events.append, run=fake_run, which=lambda n: '/usr/bin/' + n, home=tmp)
            self.assertTrue(bridge.install_apk(str(apk)))
            self.assertTrue(any(c[:3] == ['waydroid', 'app', 'install'] for c in runs))
            self.assertTrue(bridge.send_back())
            self.assertIn(['adb', '-s', '192.168.240.112:5555', 'shell', 'input', 'keyevent', '4'], runs)

    def test_shell_without_adb_or_root_does_nothing(self):
        runs = []
        def fake_run(cmd, **kw):
            runs.append(cmd)
            return FakeResult('Session:\tRUNNING\nIP address:\t192.168.240.112\n')
        bridge = waydroid_bridge.WaydroidBridge(lambda _: None, run=fake_run, which=lambda n: '/usr/bin/waydroid' if n == 'waydroid' else None)
        bridge.adb.euid = lambda: 1000
        self.assertFalse(bridge.send_back())
        self.assertFalse(any(c[:2] == ['waydroid', 'shell'] for c in runs))
        self.assertFalse(bridge.status()['adb'])


if __name__ == '__main__':
    unittest.main()
