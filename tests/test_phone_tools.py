import json, pathlib, sys, tempfile, unittest
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'src'))
import battery_stats, phone_commands, phone_windows as pw, torch

class Torch(unittest.TestCase):
    def test_absent(self):
        with tempfile.TemporaryDirectory() as d:
            (pathlib.Path(d) / 'input3::capslock').mkdir()
            self.assertFalse(torch.status(d)['available'])
            self.assertFalse(torch.set_state(True, d)['available'])
            self.assertFalse(torch.status('/nonexistent')['available'])

    def test_toggle(self):
        with tempfile.TemporaryDirectory() as d:
            led = pathlib.Path(d) / 'white:flash'; led.mkdir()
            (led / 'brightness').write_text('0'); (led / 'max_brightness').write_text('255')
            self.assertEqual(torch.set_state(True, d)['on'], True)
            self.assertEqual((led / 'brightness').read_text(), '255')
            self.assertEqual(torch.set_state(False, d)['on'], False)

class Battery(unittest.TestCase):
    def make(self, d, **files):
        bat = pathlib.Path(d) / 'BAT0'; bat.mkdir()
        for k, v in dict(type='Battery', **files).items():
            (bat / k).write_text(str(v))

    def test_energy(self):
        with tempfile.TemporaryDirectory() as d:
            self.make(d, status='Discharging', capacity=50, energy_now=10_000_000, energy_full=20_000_000, energy_full_design=25_000_000,
                      power_now=5_000_000, voltage_now=4_000_000, cycle_count=120, temp=312)
            r = battery_stats.read(d)
            self.assertEqual((r['percent'], r['hours'], r['health'], r['celsius'], r['watts']), (50, 2.0, 80, 31.2, 5.0))

    def test_charge_units_and_charging(self):
        with tempfile.TemporaryDirectory() as d:
            self.make(d, status='Charging', capacity=40, charge_now=2_000_000, charge_full=4_000_000, charge_full_design=4_000_000,
                      current_now=-1_000_000, voltage_now=4_000_000)
            r = battery_stats.read(d)
            self.assertEqual(r['hours'], 2.0)
            self.assertEqual(r['health'], 100)

    def test_none(self):
        self.assertFalse(battery_stats.read('/nonexistent')['available'])
        self.assertIsNone(battery_stats.estimate_hours('Full', 1, 1, 1))

class Geometry(unittest.TestCase):
    MON = {'id': 0, 'name': 'DSI-1', 'x': 0, 'y': 0, 'width': 1280, 'height': 800, 'scale': 1, 'transform': 0}

    def test_tablet(self):
        self.assertTrue(pw.is_tablet(1280, 800)); self.assertFalse(pw.is_tablet(412, 915))

    def test_split_and_clamp(self):
        rect = pw.usable_rect(self.MON, top=48, bottom=48)
        self.assertEqual(rect, (0, 48, 1280, 704))
        a, b = pw.split_rects(rect, .5, gap=8)
        self.assertEqual(a[0] + a[2] + 8, b[0]); self.assertEqual(b[0] + b[2], 1280)
        a, b = pw.split_rects(rect, 0.01)
        self.assertGreaterEqual(a[2], 300)
        a, b = pw.split_rects(rect, 5)
        self.assertGreaterEqual(b[2], 300)

    def test_rotation_swaps(self):
        self.assertEqual(pw.usable_rect(dict(self.MON, transform=1), top=0)[2:], (800, 1280))

    def test_slide_over(self):
        x, y, w, h = pw.slide_over_rect((0, 48, 1000, 700), .4)
        self.assertEqual((x + w + 12, w), (1000, 400)); self.assertEqual(h, 676)

    def clients(self):
        return [{'address': '0x1', 'class': 'firefox', 'monitor': 0, 'mapped': True, 'floating': False, 'fullscreen': 0, 'size': [500, 500]},
                {'address': '0x2', 'class': 'kate', 'monitor': 0, 'mapped': True, 'floating': False, 'fullscreen': 1, 'size': [500, 500]},
                {'address': '0x3', 'class': 'dlg', 'monitor': 0, 'mapped': True, 'floating': True, 'fullscreen': 0, 'size': [300, 200]},
                {'address': '0x4', 'class': 'x', 'monitor': 1, 'mapped': True, 'floating': False, 'fullscreen': 0, 'size': [1, 1]},
                {'address': '0x5', 'class': 'game', 'monitor': 0, 'mapped': True, 'floating': False, 'fullscreen': 0, 'size': [1, 1]},
                {'address': 'bad', 'class': 'y', 'monitor': 0, 'mapped': True}]

    def test_plan(self):
        mons = [self.MON, dict(self.MON, id=1, name='DP-1')]
        plan = pw.plan_fit(self.clients(), mons, {'DSI-1'}, {'game': 'fullscreen'})
        # Only the front tiled window is fitted (no focus history here, so the first one); the small dialog is clamped.
        self.assertEqual(plan, [{'address': '0x1', 'do': 'maximize'}, {'address': '0x3', 'do': 'clamp'}])
        self.assertEqual(pw.plan_fit(self.clients(), mons, set()), [])

    def test_two_windows_do_not_take_turns(self):
        mons = [dict(self.MON, activeWorkspace={'id': 1})]
        a = {'address': '0xa', 'class': 'kitty', 'monitor': 0, 'workspace': {'id': 1}, 'mapped': True, 'floating': False, 'fullscreen': 1, 'size': [1, 1], 'focusHistoryID': 1}
        b = {'address': '0xb', 'class': 'chrome', 'monitor': 0, 'workspace': {'id': 1}, 'mapped': True, 'floating': False, 'fullscreen': 0, 'size': [1, 1], 'focusHistoryID': 0}
        # The focused window takes the place once.
        self.assertEqual(pw.plan_fit([a, b], mons, {'DSI-1'}), [{'address': '0xb', 'do': 'maximize'}])
        # After that, Hyprland has moved the state over and nothing more is planned, so the windows never swap again.
        self.assertEqual(pw.plan_fit([dict(a, fullscreen=0), dict(b, fullscreen=1)], mons, {'DSI-1'}), [])
        # Windows on a hidden workspace are left alone.
        c = dict(b, address='0xc', workspace={'id': 2}, focusHistoryID=2)
        self.assertEqual(pw.plan_fit([dict(a, fullscreen=0), dict(b, fullscreen=1), c], mons, {'DSI-1'}), [])

class Adapter(unittest.TestCase):
    def test_fit_calls_and_graceful_absence(self):
        calls = []
        def runner(args):
            calls.append(args)
            if args[:2] == ['hyprctl', '-j']:
                return json.dumps(Geometry().clients() if args[2] == 'clients' else [Geometry.MON])
            # This answers like a Lua-config Hyprland, which refuses legacy dispatch commands.
            if args[:2] == ['hyprctl', 'eval']:
                return 'ok'
            assert args[1] not in ('dispatch', 'keyword'), args
            return ''
        w = pw.PhoneWindows(runner)
        self.assertEqual(w.fit(['DSI-1']), 2)
        self.assertTrue(any('hl.dsp.window.fullscreen' in ' '.join(a) or 'hl.dsp.window.center' in ' '.join(a) for a in calls))
        self.assertEqual(w.fit(['bad name!']), 0)
        def broken(args): raise OSError('no hyprctl')
        self.assertEqual(pw.PhoneWindows(broken).fit(['DSI-1']), 0)
        self.assertFalse(pw.PhoneWindows(broken).split('DSI-1', '0x1', '0x2'))

    def test_split_places_both(self):
        calls = []
        def runner(args):
            calls.append(args); return json.dumps([Geometry.MON]) if args[:2] == ['hyprctl', '-j'] else ''
        self.assertTrue(pw.PhoneWindows(runner).split('DSI-1', '0x1', '0x2', .5))
        self.assertEqual(sum(1 for a in calls if 'resizewindowpixel' in a), 2)
        self.assertFalse(pw.PhoneWindows(runner).split('DSI-1', 'evil;rm', '0x2'))

    def test_split_gathers_both_windows_on_the_shown_workspace(self):
        calls = []
        def runner(args):
            calls.append(args)
            if args[:2] == ['hyprctl', '-j']: return json.dumps([Geometry.MON])
            return 'ok' if args[:2] == ['hyprctl', 'eval'] else ''
        self.assertTrue(pw.PhoneWindows(runner).split('DSI-1', '0x1', '0x2', .5, workspace=3))
        moves = [a[2] for a in calls if a[:2] == ['hyprctl', 'eval'] and 'workspace="3"' in a[2]]
        self.assertEqual(len(moves), 2)

class Commands(unittest.TestCase):
    def test_unknown_and_torch_validation(self):
        out = []
        self.assertFalse(phone_commands.handle({'action': 'nope'}, out.append))
        self.assertTrue(phone_commands.handle({'action': 'torch', 'on': 'yes'}, out.append))
        self.assertEqual(out[0]['event'], 'torch')
        self.assertTrue(phone_commands.handle({'action': 'battery-stats'}, out.append))
        self.assertEqual(out[1]['event'], 'batteryStats')

if __name__ == '__main__':
    unittest.main()

class Extras(unittest.TestCase):
    def test_lift(self):
        mon = Geometry.MON
        c = [{'address': '0x9', 'monitor': 0, 'floating': True, 'mapped': True, 'focusHistoryID': 0, 'at': [100, 500], 'size': [400, 250]},
             {'address': '0x8', 'monitor': 0, 'floating': False, 'mapped': True, 'focusHistoryID': 0, 'at': [0, 0], 'size': [10, 10]}]
        self.assertEqual(pw.plan_lift(c, mon, 300), [{'address': '0x9', 'x': 100, 'y': 250}])
        self.assertEqual(pw.plan_lift(c, mon, 0), [])

    def test_go_home_and_unsplit(self):
        calls = []
        def runner(args):
            calls.append(args); return ''
        w = pw.PhoneWindows(runner)
        self.assertTrue(w.go_home())
        self.assertTrue(any('empty' in ' '.join(a) for a in calls))
        w.unsplit(['0x1', 'bad'], [])
        self.assertEqual(sum(1 for a in calls if 'settiled' in a), 1)

    def test_preferences(self):
        v = phone_commands.valid_preference
        self.assertTrue(v('lockNotifications', 'title')); self.assertFalse(v('lockNotifications', 'all'))
        self.assertTrue(v('phoneSplitRatio', .4)); self.assertFalse(v('phoneSplitRatio', .9))
        self.assertTrue(v('phoneAppModes', {'firefox': 'fullscreen'})); self.assertFalse(v('phoneAppModes', {'a': 'x'}))
        self.assertFalse(v('other', True)); self.assertFalse(v('phoneFitApps', 1))
