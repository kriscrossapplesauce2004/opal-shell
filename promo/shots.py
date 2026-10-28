"""Promo shot list: each function records one clip of the real shell in a nested session.

Usage: shots.py desktop|tablet|phone|console [CLIP...]
Coordinates are logical pixels; the desktop and console sessions are 4K at scale 2, so 1920x1080 logical.
"""
import json, sys, time
from session import Session, SRC

APPS = '/home/melissa/.local/state/opal/apps/build/apps/'
WALLS = '/home/melissa/.local/state/opal/promo-home/Pictures/Space/'


def wait(seconds):
    time.sleep(seconds)


def activity(s, fn, *args):
    return s.run(['quickshell', 'ipc', '-p', str(SRC / 'shell.qml'), 'call', 'activity', fn, *args])


def clip(name):
    """Decorator: reset overlays, record the body as one clip."""
    def wrap(body):
        def run(s):
            print('recording', name, flush=True)
            for fn in ('close', 'powerMenuClose'):
                s.ipc(fn, check=False)
            wait(.6)
            s.record(name)
            wait(.6)
            try:
                body(s)
            finally:
                wait(.4)
                s.stop_recording()
        run.clip = name
        return run
    return wrap


# ---------------------------------------------------------------- desktop

def desktop_prepare(s):
    # Warm every overlay once so first-open hitches stay off camera.
    for fn in ('launcher', 'controls', 'notifications', 'clipboard', 'assistant', 'settings'):
        s.ipc(fn, check=False); wait(1.0); s.ipc('close', check=False); wait(.5)
    s.ipc('switcherOpen'); wait(.8); s.ipc('switcherOpen'); wait(.5)
    # Clipboard history: a link, a hex colour, a command and a picture.
    for text in ('https://github.com/kriscrossapplesauce2004/opal-shell', '#cbb5ed', 'curl -fsSL https://raw.githubusercontent.com/kriscrossapplesauce2004/opal-shell/main/get.sh | sh', 'Meet at the observatory at 9'):
        s.spawn(['wl-copy', text]); wait(.5)
    s.spawn(['sh', '-c', f'exec wl-copy --type image/jpeg < "{WALLS}0j1z5q.jpeg"']); wait(.5)
    s.move(960, 640)


@clip('d01-apps')
def d01_apps(s):
    # The empty desktop, then three real Opal apps tile in one by one; the terminal runs fastfetch.
    wait(1.6)
    s.spawn([APPS + 'files/opal-files']); wait(1.5)
    s.spawn([APPS + 'terminal/opal-terminal']); wait(1.5)
    s.spawn([APPS + 'photos/opal-photos']); wait(1.6)
    s.glide(480, 780, .6, click=True); wait(.3)
    s.type('fastfetch\n', cps=18); wait(2.2)


@clip('d02-launcher')
def d02_launcher(s):
    s.glide(44, 1047, .7, click=True); wait(1.2)
    s.type('media', cps=10); wait(1.6)
    s.tap('Escape'); wait(.8)


@clip('d03-quick-settings')
def d03_quick_settings(s):
    s.glide(1838, 1047, .7, click=True); wait(1.4)
    s.glide(1650, 590, .5, click=True); wait(.9)   # Do not disturb on
    s.glide(1650, 590, .2, click=True); wait(.9)   # and off again
    s.glide(1757, 790, .5); wait(1.2)
    s.ipc('close'); wait(.6)


@clip('d04-activity')
def d04_activity(s):
    wait(.6)
    s.notify('Calendar', 'Launch review', 'In 10 minutes · Studio 5', 'x-office-calendar'); wait(2.0)
    activity(s, 'start', json.dumps({'id': 'cc', 'kind': 'agent', 'icon': 'terminal', 'title': 'Claude Code needs you',
                                     'short': 'Needs you', 'subtitle': '~/opal · wants to run Bash', 'code': '$ git push origin main',
                                     'controls': [{'id': 'deny', 'label': 'Deny'}, {'id': 'allow', 'label': 'Allow', 'primary': True}]}))
    wait(2.4)
    activity(s, 'end', 'cc'); wait(1.0)


@clip('d05-switcher')
def d05_switcher(s):
    s.ipc('switcherOpen'); wait(1.0)
    for _ in range(3):
        s.tap('Right'); wait(.55)
    s.tap('Return'); wait(1.2)


@clip('d06-snap')
def d06_snap(s):
    s.ipc('snaplayouts'); wait(.9)
    for x, y in ((1590, 95), (1700, 95), (1850, 95), (1700, 170)):
        s.glide(x, y, .35); wait(.35)
    s.click(); wait(1.2)


@clip('d07-clipboard')
def d07_clipboard(s):
    s.ipc('clipboard'); wait(1.4)
    s.tap('Down'); wait(.5); s.tap('Down'); wait(.5); s.tap('Down'); wait(.9)
    s.ipc('close'); wait(.5)


@clip('d08-capture')
def d08_capture(s):
    s.ipc('capture'); wait(1.4)
    s.drag(560, 300, 1340, 760, .9); wait(1.4)
    s.tap('Escape'); wait(.6); s.tap('Escape'); wait(.4)


@clip('d09-assistant')
def d09_assistant(s):
    s.ipc('assistant'); wait(1.2)
    s.type('Tile my windows and play some music', cps=16); wait(1.4)
    s.ipc('close'); wait(.5)


@clip('d10-power')
def d10_power(s):
    s.ipc('powerMenu'); wait(1.1)
    for key in ('Down', 'Down', 'Up'):
        s.tap(key); wait(.6)
    s.ipc('powerMenuClose'); wait(.6)


@clip('d11-themes')
def d11_themes(s):
    s.ipc('appearance'); wait(1.2)
    s.glide(600, 255, .6, click=True); wait(.3)
    s.type('themes', cps=9); wait(.8)
    s.glide(600, 370, .5, click=True); wait(1.4)
    for x, y in ((1238, 518), (886, 518), (1414, 665), (1238, 665)):
        s.glide(x, y, .45, click=True); wait(1.9)
    s.ipc('close'); wait(1.0)


@clip('d12-lock')
def d12_lock(s):
    wait(.5)
    s.ipc('lock'); wait(2.6)
    s.move(960, 300); s.glide(960, 700, .5); wait(1.6)


DESKTOP = [d01_apps, d02_launcher, d03_quick_settings, d04_activity, d05_switcher, d06_snap, d07_clipboard,
           d08_capture, d09_assistant, d10_power, d11_themes, d12_lock]


def run_desktop(names):
    s = Session('desk4k', 3840, 2160, 2)
    with s:
        desktop_prepare(s)
        for shot in DESKTOP:
            if not names or shot.clip in names or shot.clip.split('-')[0] in names:
                shot(s)


if __name__ == '__main__':
    which, names = sys.argv[1], sys.argv[2:]
    {'desktop': run_desktop}[which](names)
