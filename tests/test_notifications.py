"""Real notification protocol tests on a private DBus and offscreen Qt.
Run directly: python3 tests/test_notifications.py (never touches the desktop).
"""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time


def run():
    source = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix='opal-notifications-') as tmp:
        # Keep imports inside Quickshell's config root in an isolated copy.
        config = Path(tmp) / 'fixture'
        shutil.copytree(source / 'src', config / 'src', ignore=shutil.ignore_patterns('__pycache__'))
        fixture = str(config / 'notifications-test.qml')
        shutil.copy2(source / 'tests' / 'notifications-test.qml', fixture)
        env = dict(os.environ, HOME=tmp, XDG_CONFIG_HOME=tmp+'/config',
                   XDG_DATA_HOME=tmp+'/data', XDG_RUNTIME_DIR=tmp+'/runtime',
                   QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software')
        for key in ('DISPLAY', 'WAYLAND_DISPLAY', 'HYPRLAND_INSTANCE_SIGNATURE'):
            env.pop(key, None)
        os.mkdir(env['XDG_RUNTIME_DIR'], 0o700)
        with open(tmp+'/log', 'w+') as log:
            proc = subprocess.Popen(['quickshell', '-p', fixture], env=env, stdout=log, stderr=log)
            def ipc(method, *args):
                return subprocess.check_output(['quickshell','ipc','-p',fixture,'call','test',method,*map(str,args)], env=env, stderr=subprocess.DEVNULL, text=True).strip()
            def state():
                return json.loads(ipc('inspect'))
            def notify(summary='Message', body='Body', replace=0, timeout=1200, hints="{}", actions='[]'):
                result = subprocess.check_output(['gdbus','call','--session','--dest','org.freedesktop.Notifications',
                    '--object-path','/org/freedesktop/Notifications','--method','org.freedesktop.Notifications.Notify',
                    'Test app',str(replace),'dialog-information',summary,body,actions,hints,str(timeout)], env=env, text=True)
                return int(re.search(r'uint32 (\d+)', result)[1])
            try:
                for _ in range(60):
                    try:
                        state()
                        break
                    except (subprocess.CalledProcessError, json.JSONDecodeError):
                        time.sleep(.1)
                else:
                    raise AssertionError('Fixture did not start')
                first = notify('Original')
                assert state()['unread'] == 1
                assert state()['popups'] == 1
                notify('Replacement', replace=first)
                time.sleep(.15)
                assert state()['count'] == 1, 'Replacement duplicated the inbox'
                assert state()['entries'][0]['summary'] == 'Replacement'
                ipc('hover', 'true')
                time.sleep(1.4)
                assert state()['popups'] == 1, 'Hover did not pause expiry'
                ipc('hover', 'false')
                time.sleep(1.4)
                assert state()['popups'] == 0 and state()['count'] == 1, 'Popup expiry lost history'
                ipc('dnd', 'true')
                notify('Silent')
                notify('Transient', hints="{'transient': <true>}")
                assert state()['count'] == 2 and state()['popups'] == 0
                time.sleep(.15)
                assert len(state()['entries']) == 2, 'Suppressed transient leaked: '+str(state())
                ipc('dnd', 'false')
                critical = notify('Important', timeout=1000, hints="{'urgency': <byte 2>}")
                time.sleep(1.3)
                assert state()['popups'] == 1, 'Critical popup expired automatically'
                ipc('centerOpen', 'true')
                assert state()['popups'] == 0 and state()['unread'] == 0
                ipc('centerOpen', 'false')
                notify('While open?', timeout=0)
                subprocess.check_call(['gdbus','call','--session','--dest','org.freedesktop.Notifications',
                    '--object-path','/org/freedesktop/Notifications','--method','org.freedesktop.Notifications.CloseNotification',str(critical)], env=env, stdout=subprocess.DEVNULL)
                assert all(e['id'] != critical for e in state()['entries']), 'Client closure left a dangling entry'
                ipc('clear')
                for i in range(12):
                    notify('Burst '+str(i), timeout=0)
                result = state()
                assert result['count'] == 12 and result['popups'] == 3
                assert sum(e['popup'] for e in result['entries']) == 8, 'Popup queue is unbounded'
                ipc('clear')
                copying = notify('Copying', 'photos.zip', timeout=0, hints="{'value': <int32 30>}")
                time.sleep(1.4)
                found = [a for a in state()['activities'] if a['kind'] == 'transfer']
                assert [a['id'] for a in found] == ['n:%d' % copying] and found[0]['progress'] == 0.3, 'Progress hint did not become an activity: '+str(found)
                notify('Copying', 'photos.zip', replace=copying, timeout=0, hints="{'value': <int32 80>}")
                time.sleep(1.4)
                found = [a for a in state()['activities'] if a['kind'] == 'transfer']
                assert len(found) == 1 and found[0]['progress'] == 0.8, 'Progress was not replaced in place: '+str(found)
                ipc('clear')
                time.sleep(1.4)
                assert [a for a in state()['activities'] if a['kind'] == 'transfer'] == [], 'Activity outlived its notification'
                notify('Design review', 'The updated layout is ready.\nPlease check the spacing before publishing.', timeout=0, actions="['default', 'Open review', 'later', 'Remind me later']")
                notify('Download complete', 'Project assets · 24 MB', timeout=0)
                notify('Low battery', 'Connect your charger. 9% remaining.', timeout=0, hints="{'urgency': <byte 2>}")
                output = Path('/tmp/opal-notification-previews')
                output.mkdir(exist_ok=True)
                for light in (False, True):
                    ipc('theme', str(light).lower())
                    for show_center in (False, True):
                        ipc('centerOpen', str(show_center).lower())
                        time.sleep(.35)
                        ipc('capture', output / f'{"light" if light else "dark"}-{"center" if show_center else "popups"}.png')
                        time.sleep(.15)
                    # Re-present via replacements, rather than replaying on center close.
                    ipc('centerOpen','false')
                    for entry in state()['entries']:
                        notify(entry['summary']+' ', replace=entry['id'], timeout=0)
                ipc('clear')
                assert state()['count'] == 0 and state()['popups'] == 0
                ipc('quit')
                proc.wait(timeout=4)
                log.seek(0)
                text = log.read()
                errors = [line for line in text.splitlines() if re.search(r'TypeError|ReferenceError|ERROR|Unable to assign|Binding loop', line) and 'Failed to connect pipewire context' not in line]
                assert not errors, '\n'.join(errors)
                print('PASS: progress activities, replacement, hover, expiry/history, DND, transient, critical, read state, client close, burst bounds, clear; previews:', output)
            finally:
                if proc.poll() is None:
                    proc.terminate()
                    proc.wait(timeout=4)
                log.seek(0)
                if sys.exc_info()[0]:
                    print(log.read(), file=sys.stderr)


if __name__ == '__main__':
    if '--private-bus' not in sys.argv:
        # No service directories: tests must not activate host portals/services.
        with tempfile.NamedTemporaryFile(mode='w', suffix='.conf') as config:
            config.write('<busconfig><type>session</type><listen>unix:tmpdir=/tmp</listen><policy context="default"><allow send_destination="*"/><allow receive_sender="*"/><allow own="*"/></policy></busconfig>')
            config.flush()
            raise SystemExit(subprocess.call(['dbus-run-session', '--config-file='+config.name, '--', sys.executable, __file__, '--private-bus']))
    run()
