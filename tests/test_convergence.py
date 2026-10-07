import json
import pathlib
import sys
import tempfile
import unittest
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'src'))
import convergence_events as ev
import convergence_policy as pol
import convergence_service as svc
import convergence_windows as win
from hypr_actions import HyprActions

PHONE = {'name': 'DSI-1', 'width': 415, 'height': 900, 'builtin': True}
MONITOR = {'name': 'DP-1', 'width': 1920, 'height': 1080, 'builtin': False}
IDLE = {'keyboard': False, 'pointer': False, 'lid': None, 'tablet': None}


def state(outputs, **signals):
    return dict(IDLE, outputs=outputs, **signals)


class PolicyTests(unittest.TestCase):
    def test_phone_stays_touch_and_monitor_is_desktop(self):
        layouts = pol.decide(state([PHONE, MONITOR]), {})['layouts']
        self.assertEqual(layouts, {'DSI-1': 'phone', 'DP-1': 'desktop'})

    def test_tablet_follows_keyboard(self):
        tablet = {'name': 'DSI-1', 'width': 1280, 'height': 800, 'builtin': True}
        self.assertEqual(pol.decide(state([tablet]), {})['layouts']['DSI-1'], 'phone')
        self.assertEqual(pol.decide(state([tablet], keyboard=True), {})['layouts']['DSI-1'], 'desktop')
        self.assertEqual(pol.decide(state([tablet], pointer=True), {})['layouts']['DSI-1'], 'desktop')

    def test_small_phone_ignores_keyboard(self):
        self.assertEqual(pol.decide(state([PHONE], keyboard=True), {})['layouts']['DSI-1'], 'phone')

    def test_convertible_and_lid(self):
        laptop = {'name': 'eDP-1', 'width': 1920, 'height': 1080, 'builtin': True}
        self.assertEqual(pol.decide(state([laptop], lid='open', tablet=True), {})['layouts']['eDP-1'], 'phone')
        self.assertEqual(pol.decide(state([laptop], lid='open', tablet=False), {})['layouts']['eDP-1'], 'desktop')
        self.assertEqual(pol.decide(state([laptop], lid='open'), {})['layouts']['eDP-1'], 'desktop')
        closed = pol.decide(state([laptop, MONITOR], lid='closed'), {})
        self.assertEqual(closed['off'], ['eDP-1'])
        self.assertEqual(pol.decide(state([laptop], lid='closed'), {})['off'], [])

    def test_disabled_trigger_is_ignored(self):
        tablet = {'name': 'DSI-1', 'width': 1280, 'height': 800, 'builtin': True}
        self.assertEqual(pol.decide(state([tablet], keyboard=True), {'convergeKeyboard': False})['layouts']['DSI-1'], 'phone')
        self.assertEqual(pol.decide(state([tablet], keyboard=True), {'convergeAuto': False})['layouts']['DSI-1'], 'phone')

    def test_engine_baseline_then_toast_text(self):
        engine = pol.Engine()
        first = engine.update(state([PHONE]), {})
        self.assertTrue(first['initial'])
        docked = engine.update(state([PHONE, MONITOR]), {})
        self.assertEqual(docked['trigger'], 'Hotplug')
        self.assertEqual(docked['externalAdded'], ['DP-1'])
        self.assertIn('DP-1 connected', docked['text'])
        gone = engine.update(state([PHONE]), {})
        self.assertEqual(gone['removed'], ['DP-1'])
        self.assertIn('disconnected', gone['text'])
        self.assertIsNone(engine.update(state([PHONE]), {}))

    def test_engine_keyboard_change_reports_layout(self):
        tablet = {'name': 'DSI-1', 'width': 1280, 'height': 800, 'builtin': True}
        engine = pol.Engine()
        engine.update(state([tablet]), {})
        result = engine.update(state([tablet], keyboard=True), {})
        self.assertEqual(result['changes'], [{'output': 'DSI-1', 'from': 'phone', 'to': 'desktop'}])
        self.assertEqual(result['text'], 'Keyboard connected · Desktop layout')
        off = engine.update(state([tablet], keyboard=True), {'convergePointer': False, 'convergeKeyboard': False})
        self.assertEqual(off['trigger'], '')


DEVICES = """I: Bus=0003 Vendor=046d Product=c31c Version=0110
N: Name="Logitech USB Keyboard"
H: Handlers=sysrq kbd event3 leds
B: EV=120013
B: KEY=402000000 3803078f800d001 feffffdfffefffff fffffffffffffffe

I: Bus=0003 Vendor=046d Product=c077 Version=0111
N: Name="Logitech USB Optical Mouse"
H: Handlers=mouse0 event4
B: EV=17
B: KEY=70000 0 0 0 0
B: REL=903

I: Bus=0011 Vendor=0001 Product=0001 Version=ab41
N: Name="AT Translated Set 2 keyboard"
H: Handlers=sysrq kbd event0 leds
B: EV=120013
B: KEY=402000000 3803078f800d001 feffffdfffefffff fffffffffffffffe

I: Bus=0019 Vendor=0000 Product=0005 Version=0000
N: Name="Lid Switch"
H: Handlers=event1
B: PROP=0
B: EV=21
B: SW=1

I: Bus=0019 Vendor=0000 Product=0000 Version=0000
N: Name="Intel HID switches"
H: Handlers=event9
B: EV=33
B: SW=2

I: Bus=0006 Vendor=0000 Product=0000 Version=0000
N: Name="ydotoold virtual device"
H: Handlers=sysrq kbd mouse1 event10
B: EV=120017
B: KEY=ffffffffffffffff ffffffffffffffff ffffffffffffffff ffffffffffffffff
B: REL=3
"""


class EventTests(unittest.TestCase):
    def test_parse_classifies_external_only(self):
        devices = ev.parse_devices(DEVICES)
        self.assertEqual(len(devices), 6)
        info = ev.summarize(devices)
        self.assertTrue(info['keyboard'])
        self.assertTrue(info['pointer'])
        self.assertEqual(info['switches'], ['/dev/input/event1', '/dev/input/event9'])

    def test_builtin_and_virtual_devices_do_not_count(self):
        builtin_only = '\n\n'.join(DEVICES.split('\n\n')[2:])
        info = ev.summarize(ev.parse_devices(builtin_only))
        self.assertFalse(info['keyboard'])
        self.assertFalse(info['pointer'])

    def test_switch_state_bits(self):
        self.assertEqual(ev.read_switch_state('x', lambda p: 0b11), {'lid': 'closed', 'tablet': True})
        self.assertEqual(ev.read_switch_state('x', lambda p: 0), {'lid': 'open', 'tablet': False})
        def denied(path):
            raise PermissionError(path)
        self.assertEqual(ev.read_switch_state('x', denied), {})

    def test_snapshot_reads_switches_and_degrades(self):
        snap = ev.snapshot(DEVICES, lambda p: 1 if p.endswith('event1') else 2, lid_root='/nonexistent')
        self.assertEqual((snap['lid'], snap['tablet']), ('closed', True))
        def denied(path):
            raise PermissionError(path)
        snap = ev.snapshot(DEVICES, denied, lid_root='/nonexistent')
        self.assertEqual((snap['lid'], snap['tablet']), (None, None))
        self.assertTrue(snap['keyboard'])

    def test_watch_emits_only_changes(self):
        states = iter([{'a': 1}, {'a': 1}, {'a': 2}])
        seen = []
        stop = {'n': 0}
        def should_stop():
            stop['n'] += 1
            return stop['n'] > 3
        ev.watch(seen.append, 0, sleep=lambda s: None, snap=lambda: next(states), should_stop=should_stop)
        self.assertEqual(seen, [{'a': 1}, {'a': 2}])


class FakeHypr:
    """A tiny stateful stand-in for hyprctl. It accepts the legacy dispatcher path."""

    def __init__(self):
        self.monitors = [
            {'id': 0, 'name': 'DSI-1', 'width': 1080, 'height': 2340, 'x': 0, 'y': 0, 'scale': 2.0, 'transform': 0, 'activeWorkspace': {'id': 1}},
            {'id': 1, 'name': 'DP-1', 'width': 1920, 'height': 1080, 'x': 540, 'y': 0, 'scale': 1.0, 'transform': 0, 'make': 'Dell', 'model': 'U2415', 'serial': 'ABC', 'activeWorkspace': {'id': 5}},
        ]
        self.clients = [
            {'address': '0x1', 'mapped': True, 'class': 'foot', 'title': 'a', 'monitor': 0, 'workspace': {'id': 1}, 'floating': False, 'fullscreen': 0, 'at': [0, 0], 'size': [540, 1000]},
            {'address': '0x2', 'mapped': True, 'class': 'mpv', 'title': 'v', 'monitor': 0, 'workspace': {'id': 1}, 'floating': True, 'fullscreen': 0, 'at': [54, 100], 'size': [270, 200]},
        ]
        self.log = []

    def __call__(self, args):
        self.log.append(args)
        if args[:3] == ['hyprctl', 'eval', 'return true']:
            raise ValueError('unsupported')
        if args[:2] == ['hyprctl', '-j'] and args[2] == 'clients':
            return json.dumps(self.clients)
        if args[:2] == ['hyprctl', '-j'] and args[2] == 'monitors':
            return json.dumps(self.monitors)
        if args[:2] == ['hyprctl', 'dispatch'] and args[2] == 'movetoworkspacesilent':
            number, _, address = args[3].partition(',address:')
            for c in self.clients:
                if c['address'] == address:
                    c['workspace'] = {'id': int(number)}
                    c['monitor'] = next(m['id'] for m in self.monitors if m['activeWorkspace']['id'] == int(number))
        return 'ok'


class WindowTests(unittest.TestCase):
    def test_dock_moves_phone_windows_and_restores_geometry(self):
        fake = FakeHypr()
        with tempfile.TemporaryDirectory() as tmp:
            memory = win.Memory(pathlib.Path(tmp) / 'w.json')
            mover = win.Mover(HyprActions(fake), memory)
            result = mover.dock('DSI-1', 'DP-1')
            self.assertEqual(result['moved'], 2)
            self.assertEqual({c['address']: c['workspace']['id'] for c in fake.clients}, {'0x1': 5, '0x2': 5})
            self.assertIn(['hyprctl', 'dispatch', 'movetoworkspacesilent', '5,address:0x1'], fake.log)
            # The phone placement is remembered for the way back.
            self.assertEqual(len(memory.data['phone']['DSI-1']), 2)
            self.assertTrue(json.loads((pathlib.Path(tmp) / 'w.json').read_text())['phone'])

    def test_monitor_layout_is_remembered_by_edid_and_restored(self):
        fake = FakeHypr()
        with tempfile.TemporaryDirectory() as tmp:
            memory = win.Memory(pathlib.Path(tmp) / 'w.json')
            fake.clients = [{'address': '0x9', 'mapped': True, 'class': 'kate', 'title': 'k', 'monitor': 1, 'workspace': {'id': 5}, 'floating': True,
                             'fullscreen': 0, 'at': [540 + 480, 270], 'size': [960, 540]}]
            mover = win.Mover(HyprActions(fake), memory)
            mover.docked['DP-1'] = win.monitor_key(fake.monitors[1])
            mover.snapshot()
            self.assertIn('Dell-U2415-ABC', memory.data['monitors'])
            saved = memory.data['monitors']['Dell-U2415-ABC'][0]
            self.assertEqual(saved['rel'], [0.25, 0.25, 0.5, 0.5])
            # A later dock puts the matching window back with the same geometry.
            fake.clients = [{'address': '0xA', 'mapped': True, 'class': 'kate', 'title': 'k', 'monitor': 0, 'workspace': {'id': 1}, 'floating': False,
                             'fullscreen': 0, 'at': [0, 0], 'size': [500, 900]}]
            fake.log.clear()
            mover2 = win.Mover(HyprActions(fake), memory)
            mover2.dock('DSI-1', 'DP-1')
            self.assertIn(['hyprctl', 'dispatch', 'resizewindowpixel', 'exact 960 540,address:0xA'], fake.log)
            self.assertIn(['hyprctl', 'dispatch', 'movewindowpixel', 'exact 1020 270,address:0xA'], fake.log)

    def test_undock_gathers_windows_and_undo_reverses(self):
        fake = FakeHypr()
        with tempfile.TemporaryDirectory() as tmp:
            mover = win.Mover(HyprActions(fake), win.Memory(pathlib.Path(tmp) / 'w.json'))
            mover.dock('DSI-1', 'DP-1')
            self.assertEqual({c['workspace']['id'] for c in fake.clients}, {5})
            fake.monitors.pop(1)
            result = mover.undock('DSI-1', ['DP-1'])
            self.assertEqual({c['workspace']['id'] for c in fake.clients}, {1})
            self.assertEqual(result['moved'], 2)

    def test_pixels_clamp_inside_monitor(self):
        monitor = {'width': 1000, 'height': 500, 'scale': 1, 'x': 100, 'y': 0}
        self.assertEqual(win.pixels([0.9, 0.9, 0.5, 0.5], monitor), (600, 250, 500, 250))

    def test_missing_workspace_reports_error(self):
        fake = FakeHypr()
        fake.monitors[1]['activeWorkspace'] = {'id': -1}
        with tempfile.TemporaryDirectory() as tmp:
            mover = win.Mover(HyprActions(fake), win.Memory(pathlib.Path(tmp) / 'w.json'))
            self.assertIn('workspace', mover.dock('DSI-1', 'DP-1')['error'])


class ServiceTests(unittest.TestCase):
    def test_service_waits_for_input_baseline_and_moves_apps(self):
        events = []
        fake = FakeHypr()
        with tempfile.TemporaryDirectory() as tmp:
            service = svc.Service(events.append, HyprActions(fake), win.Memory(pathlib.Path(tmp) / 'w.json'))
            service.set_outputs([PHONE], {})
            self.assertEqual(events, [])
            service.set_input(dict(IDLE))
            self.assertTrue(events[0]['initial'])
            service.set_outputs([PHONE, MONITOR], {})
            docked = events[-1]
            self.assertEqual(docked['trigger'], 'Hotplug')
            self.assertEqual(docked['windows']['moved'], 2)
            self.assertIn('2 apps moved', docked['text'])
            events.clear()
            service.set_outputs([PHONE, MONITOR], {'convergeMoveApps': False})
            service.set_outputs([PHONE], {'convergeMoveApps': False})
            self.assertNotIn('windows', events[-1])

    def test_service_without_hyprland_is_honest(self):
        events = []
        service = svc.Service(events.append)
        service.undo()
        self.assertIn('Hyprland', events[0]['error'])
        service.set_input(dict(IDLE))
        service.set_outputs([PHONE], {})
        service.set_outputs([PHONE, MONITOR], {})
        self.assertNotIn('windows', events[-1])


if __name__ == '__main__':
    unittest.main()
