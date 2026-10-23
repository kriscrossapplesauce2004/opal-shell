import pathlib, sys, unittest
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'src'))
import android_shell


class Result:
    def __init__(self, stdout='', returncode=0, stderr=''):
        self.stdout, self.returncode, self.stderr = stdout, returncode, stderr


class AndroidShellTests(unittest.TestCase):
    def test_versions_parser(self):
        text = 'package:org.videolan.vlc versionCode:13050407\npackage:com.aurora.store versionCode:62\nnoise\n'
        self.assertEqual(android_shell.parse_versions(text), {'org.videolan.vlc': 13050407, 'com.aurora.store': 62})

    def test_connects_once_and_reconnects_after_restart(self):
        runs, drops = [], [True]
        def run(cmd, **kw):
            runs.append(cmd)
            if cmd[1] == 'connect':
                return Result('connected to ' + cmd[2])
            if drops and drops.pop():
                return Result('', 1, "error: device '192.168.240.112:5555' not found")
            return Result('ok')
        sh = android_shell.AndroidShell(lambda: '192.168.240.112', run=run, which=lambda n: '/usr/bin/' + n, euid=lambda: 1000)
        self.assertTrue(sh.ok(['input', 'keyevent', '4']))
        self.assertEqual(sum(1 for c in runs if c[1] == 'connect'), 2)
        self.assertTrue(sh.ok(['input', 'keyevent', '4']))
        self.assertEqual(sum(1 for c in runs if c[1] == 'connect'), 2)

    def test_no_session_means_no_command(self):
        sh = android_shell.AndroidShell(lambda: '', run=lambda *a, **k: Result('x'), which=lambda n: '/usr/bin/' + n, euid=lambda: 1000)
        self.assertIsNone(sh.shell(['true']))

    def test_root_falls_back_to_waydroid_shell(self):
        runs = []
        def run(cmd, **kw):
            runs.append(cmd)
            return Result('')
        sh = android_shell.AndroidShell(lambda: '', run=run, which=lambda n: '/usr/bin/waydroid' if n == 'waydroid' else None, euid=lambda: 0)
        self.assertTrue(sh.ok(['true']))
        self.assertEqual(runs, [['waydroid', 'shell', '--', 'true']])


if __name__ == '__main__':
    unittest.main()
