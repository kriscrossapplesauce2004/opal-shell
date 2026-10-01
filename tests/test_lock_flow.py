"""Run the lock controller against pam_permit and pam_deny configs; no real password is used."""
import os, shutil, subprocess, tempfile, unittest
from pathlib import Path


@unittest.skipUnless(shutil.which('quickshell') and Path('/usr/lib/security/pam_permit.so').exists(), 'quickshell or pam_permit missing')
class LockFlowTest(unittest.TestCase):
    def run_with(self, rule, passwords=None, files=()):
        source = Path(__file__).resolve().parents[1]
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            config = tmp / 'fixture'
            shutil.copytree(source / 'src', config / 'src', ignore=shutil.ignore_patterns('__pycache__'))
            shutil.copy(source / 'tests' / 'lock-test.qml', config / 'lock-test.qml')
            pam = tmp / 'pam'; pam.mkdir()
            for name, text in files:
                (tmp / name).write_text(text); (tmp / name).chmod(0o755)
            (pam / 'opal-test').write_text(f'auth {rule.format(tmp=tmp)}\naccount required pam_permit.so\n')
            runtime = tmp / 'runtime'; runtime.mkdir(mode=0o700)
            env = dict(os.environ, HOME=str(tmp), XDG_RUNTIME_DIR=str(runtime), XDG_CONFIG_HOME=str(tmp / 'config'),
                       QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software', QT_LOGGING_RULES='qml.debug=true',
                       OPAL_PAM_DIR=str(pam), OPAL_PAM_CONFIG='opal-test', OPAL_GREETER='1', OPAL_GREETER_THEME=str(tmp / 'none.json'),
                       DBUS_SESSION_BUS_ADDRESS='unix:path=' + str(tmp / 'no-bus'))
            if passwords: env['OPAL_TEST_PASSWORDS'] = ','.join(passwords)
            for key in ('DISPLAY', 'WAYLAND_DISPLAY', 'HYPRLAND_INSTANCE_SIGNATURE'): env.pop(key, None)
            result = subprocess.run(['quickshell', '-p', str(config / 'lock-test.qml')], env=env, capture_output=True, text=True, timeout=30)
            return result.stdout + result.stderr

    def test_permit_unlocks(self):
        output = self.run_with('required pam_permit.so')
        self.assertIn('LOCK_UNLOCKED', output, output[-1500:])

    def test_deny_shows_error_and_stays_locked(self):
        output = self.run_with('required pam_deny.so')
        self.assertIn('LOCK_ERROR', output, output[-1500:])
        self.assertNotIn('LOCK_UNLOCKED', output)


    def test_password_prompt_wrong_then_right(self):
        check = ('check.sh', '#!/bin/sh\nread -r password\n[ "$password" = right ]\n')
        output = self.run_with('required pam_exec.so expose_authtok quiet {tmp}/check.sh', ['wrong', 'right'], [check])
        self.assertIn('LOCK_ERROR', output, output[-1500:])
        self.assertIn('LOCK_UNLOCKED 1', output, output[-1500:])


if __name__ == '__main__':
    unittest.main()
