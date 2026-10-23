import hashlib, io, json, pathlib, sys, tempfile, unittest
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'src'))
import waydroid_root, waydroid_setup, android_store


class FakeBridge:
    def __init__(self, installed=True, session='running'):
        self._installed = installed
        self.session = session
        self.calls = []
    def installed(self): return self._installed
    def initialized(self): return False
    def status(self, refresh_props=False): return {'session': self.session}
    def ensure_session(self, **kw): self.calls.append(('boot', kw)); return True
    def set_prop(self, k, v): self.calls.append(('prop', k, v)); return True
    def sync_theme(self, light, dpi=0): self.calls.append(('theme', light)); return True
    def publish_status(self, refresh_props=False): self.calls.append(('publish',))
    def activity_start(self, *a, **kw): self.calls.append(('activity',) + a)
    def activity_end(self, *a): self.calls.append(('end',) + a)
    def uninstall_app(self, pkg): return True


class FakeProc:
    def __init__(self, lines, code=0):
        self.stdout = io.StringIO(''.join(l + '\n' for l in lines))
        self.stdin = io.StringIO()
        self.code = code
    def wait(self): return self.code
    def poll(self): return None


class RootHelperTests(unittest.TestCase):
    def test_arguments_are_allowlisted(self):
        opts = waydroid_root.parse_args(['--stages', 'package,init', '--image', 'GAPPS', '--pm', 'pacman', '--force'])
        self.assertEqual(opts['stages'], ['package', 'init'])
        self.assertTrue(opts['force'])
        for bad in (['--stages', 'package;rm'], ['--stages', 'init', '--image', 'x'], ['--stages', 'init', '--pm', 'sh'], ['--stages', 'init', '--evil', '1'], []):
            with self.assertRaises(ValueError):
                waydroid_root.parse_args(bad)

    def test_download_progress_parsing(self):
        self.assertEqual(waydroid_root.parse_download('[Downloading] 412.00 MB/1100.00 MB    8.4 MB/s(approx.)')[:2], (412 * 1024 ** 2, 1100 * 1024 ** 2))
        self.assertIsNone(waydroid_root.parse_download('Extracting to /var/lib/waydroid/images'))
        self.assertEqual(waydroid_root.image_kind('https://sourceforge.net/projects/waydroid/files/images/vendor/waydroid_x86_64/x.zip/download'), 'vendor')
        self.assertEqual(waydroid_root.image_kind('https://sourceforge.net/projects/waydroid/files/images/system/lineage/waydroid_x86_64/x.zip/download'), 'system')


class InstallerTests(unittest.TestCase):
    def test_plan_for_a_fresh_and_a_ready_system(self):
        fresh = {'installed': False, 'binder': 'module', 'firewall': 'ufw', 'initialized': False, 'serviceActive': False, 'arch': 'x86_64'}
        self.assertEqual(waydroid_setup.plan(fresh, {'arm': True}), ['package', 'binder', 'firewall', 'init', 'service', 'arm', 'boot', 'configure'])
        ready = {'installed': True, 'binder': 'ready', 'firewall': '', 'initialized': True, 'serviceActive': True, 'arch': 'aarch64'}
        self.assertEqual(waydroid_setup.plan(ready, {'arm': True}), ['boot', 'configure'])
        self.assertEqual(waydroid_setup.plan(ready, {'reinstall': True}), ['init', 'service', 'boot', 'configure'])

    def test_root_run_streams_progress_and_reports_failure(self):
        events = []
        lines = [json.dumps({'stage': 'init', 'state': 'running'}),
                 json.dumps({'stage': 'init', 'progress': .25, 'done': 1, 'total': 4, 'part': 'system'}),
                 'Error executing command as another user: Not authorized',
                 json.dumps({'stage': 'init', 'log': 'urlopen error'}),
                 json.dumps({'stage': 'init', 'state': 'failed', 'code': 1})]
        inst = waydroid_setup.Installer(events.append, FakeBridge(), popen=lambda *a, **kw: FakeProc(lines, 1), which=lambda n: '/usr/bin/' + n)
        inst.state['stages'] = [{'id': 'init', 'title': 'Download Android', 'state': 'waiting', 'progress': -1, 'detail': ''}]
        self.assertFalse(inst.run_root(['init'], 'GAPPS'))
        self.assertIn('Download Android failed', inst.state['error'])
        self.assertIn('urlopen error', inst.state['error'])
        progress = [e for e in events if e.get('event') == 'activity' and e['data'].get('progress', -2) >= 0]
        self.assertTrue(progress)
        self.assertIn('Not authorized', '\n'.join(inst.state['log']))

    def test_cancelled_password_prompt(self):
        inst = waydroid_setup.Installer(lambda e: None, FakeBridge(), popen=lambda *a, **kw: FakeProc([], 126), which=lambda n: '/usr/bin/' + n)
        self.assertFalse(inst.run_root(['package']))
        self.assertEqual(inst.state['error'], 'The password prompt was cancelled')

    def test_helper_command_is_an_argument_list(self):
        inst = waydroid_setup.Installer(lambda e: None, FakeBridge(), which=lambda n: '/usr/bin/' + n if n in ('pkexec', 'pacman') else None)
        cmd = inst.helper_command(['package', 'init'], 'VANILLA')
        self.assertEqual(cmd[0], '/usr/bin/pkexec')
        self.assertIn('-I', cmd)
        self.assertEqual(cmd[cmd.index('--stages') + 1], 'package,init')
        self.assertEqual(cmd[cmd.index('--pm') + 1], 'pacman')

    def test_cancel_writes_to_the_helper(self):
        inst = waydroid_setup.Installer(lambda e: None, FakeBridge())
        inst.proc = FakeProc([])
        inst.cancel()
        self.assertEqual(inst.proc.stdin.getvalue(), 'cancel\n')
        self.assertTrue(inst.cancel_requested)


class StoreTests(unittest.TestCase):
    INDEX = {'apps': [
        {'packageName': 'org.example.java', 'suggestedVersionCode': '20', 'icon': 'j.png', 'categories': ['Internet'], 'lastUpdated': 2, 'localized': {'en-US': {'name': 'Java App', 'summary': 'A browser'}}},
        {'packageName': 'org.example.arm', 'suggestedVersionCode': '5', 'categories': ['Games'], 'lastUpdated': 1, 'name': 'Arm Game', 'summary': 'Only ARM'},
        {'packageName': 'bad;pkg', 'name': 'Bad'}],
        'packages': {
            'org.example.java': [{'apkName': 'j_30.apk', 'versionCode': 30, 'hash': 'a' * 64, 'hashType': 'sha256'}, {'apkName': 'j_20.apk', 'versionCode': 20, 'versionName': '2.0', 'hash': 'b' * 64, 'hashType': 'sha256', 'size': 1000}],
            'org.example.arm': [{'apkName': 'a.apk', 'versionCode': 5, 'nativecode': ['arm64-v8a'], 'hash': 'c' * 64, 'hashType': 'sha256'}]}}

    def test_catalogue_respects_abi_and_suggested_version(self):
        x86 = android_store.build_catalog(self.INDEX, ['x86_64', 'x86'])
        self.assertEqual([a['package'] for a in x86], ['org.example.java'])
        self.assertEqual(x86[0]['apk'], 'j_20.apk')
        self.assertEqual(x86[0]['name'], 'Java App')
        with_arm = android_store.build_catalog(self.INDEX, ['x86_64', 'x86', 'arm64-v8a'])
        arm = next(a for a in with_arm if a['package'] == 'org.example.arm')
        self.assertTrue(arm['arm'])

    def test_search_and_app_list(self):
        st = android_store.Store(lambda e: None, FakeBridge())
        st.set_catalog(android_store.build_catalog(self.INDEX, ['x86_64', 'arm64-v8a']))
        self.assertEqual([a['package'] for a in st.search('browser')], ['org.example.java'])
        self.assertEqual(st.search('nothing here'), [])
        self.assertEqual(android_store.parse_app_list('Name: VLC\npackageName: org.videolan.vlc\ncategories:\n'), ['org.videolan.vlc'])

    def test_install_rejects_a_bad_checksum(self):
        events = []
        payload = b'apk-bytes'
        class Res(io.BytesIO):
            headers = {'Content-Length': str(len(payload))}
            def __enter__(self): return self
            def __exit__(self, *a): return False
        with tempfile.TemporaryDirectory() as cache:
            st = android_store.Store(events.append, FakeBridge(), cache=cache, fetch=lambda *a, **kw: Res(payload), run=lambda *a, **kw: type('R', (), {'returncode': 0, 'stdout': ''})())
            entry = {'package': 'org.example.java', 'name': 'Java App', 'apk': 'j.apk', 'hash': '0' * 64, 'size': len(payload), 'summary': '', 'categories': [], 'icon': '', 'updated': 0}
            st.set_catalog([entry])
            self.assertFalse(st.install('org.example.java'))
            self.assertEqual(st.jobs['org.example.java']['state'], 'failed')
            entry['hash'] = hashlib.sha256(payload).hexdigest()
            self.assertTrue(st.install('org.example.java'))
            self.assertIn('org.example.java', st.installed)


if __name__ == '__main__':
    unittest.main()
