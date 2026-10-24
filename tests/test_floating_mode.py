import pathlib, sys, tempfile, unittest
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'src'))
import floating_mode as fm


def win(address, cls, floating=False, ws=1, at=(10, 20), size=(800, 600), title='', fullscreen=0):
    return {'address': address, 'class': cls, 'title': title, 'floating': floating, 'workspace': {'id': ws}, 'at': list(at), 'size': list(size), 'fullscreen': fullscreen, 'mapped': True}


USER_CONFIG = '''
hl.window_rule({ match = { class = "^(org\\\\.gnome\\\\.Calculator)$" }, float = true })
hl.window_rule({ match = { class = "^(pavucontrol)$" }, tile = true })
hl.window_rule({
	match = { class = "^(firefox)$", title = "^(Picture-in-Picture)$" },
	float = true,
})
hl.window_rule({ name = "opal-float-all", match = { class = ".*" }, float = true })
'''


class FloatingModeTests(unittest.TestCase):
    def test_enable_floats_tiled_windows_in_place(self):
        clients = [win('0x1', 'kitty'), win('0x2', 'firefox', floating=True), win('0x3', 'steam', ws=-98), win('0x4', 'mpv', fullscreen=2)]
        ops, before = fm.plan_enable(clients, {'kitty': [100, 100, 900, 700]})
        self.assertEqual(before, ['0x2'])
        self.assertEqual(ops, [{'op': 'float', 'address': '0x1', 'value': True}, {'op': 'geometry', 'address': '0x1', 'rect': [100, 100, 900, 700]}])
        ops, _ = fm.plan_enable([win('0x5', 'code', at=(5, 6), size=(700, 500))])
        self.assertEqual(ops[1]['rect'], [5, 6, 700, 500])

    def test_disable_tiles_every_window_the_mode_floated(self):
        rules = fm.user_float_rules(USER_CONFIG)
        self.assertEqual(len(rules), 2)
        clients = [win('0x1', 'kitty', floating=True), win('0x2', 'firefox', floating=True, title='Hyprland Wiki'),
                   win('0x3', 'org.gnome.Calculator', floating=True), win('0x4', 'firefox', floating=True, title='Picture-in-Picture'),
                   win('0x5', 'gimp', floating=True), win('0x6', 'code'), win('0x7', 'scratch', floating=True, ws=-99)]
        ops = fm.plan_disable(clients, before=['0x5'], rules=rules)
        self.assertEqual([o['address'] for o in ops], ['0x1', '0x2'])
        self.assertTrue(all(o['value'] is False for o in ops))

    def test_disable_with_no_rules_tiles_all_floated(self):
        clients = [win('0x1', 'a', floating=True), win('0x2', 'b', floating=True)]
        self.assertEqual(len(fm.plan_disable(clients, [], [])), 2)

    def test_remember_keeps_last_geometry_and_bounds_size(self):
        memory = fm.remember({}, [win('0x1', 'kitty', floating=True, at=(1, 2), size=(640, 480)), win('0x2', 'tiny', floating=True, size=(50, 40)), win('0x3', 'tiled')])
        self.assertEqual(memory, {'kitty': [1, 2, 640, 480]})
        big = fm.remember({str(i): [0, 0, 200, 200] for i in range(fm.MAX_MEMORY)}, [win('0x1', 'new', floating=True)])
        self.assertEqual(len(big), fm.MAX_MEMORY)
        self.assertIn('new', big); self.assertNotIn('0', big)

    def test_snap_math(self):
        mon = {'x': 0, 'y': 0, 'width': 3840, 'height': 2160, 'scale': 2, 'reserved': [0, 0, 0, 72]}
        self.assertEqual(fm.usable_area(mon), (0, 0, 1920.0, 1008.0))
        self.assertEqual(fm.usable_area(dict(mon, reserved=[0, 0, 0, 0]), shelf=72), (0, 0, 1920.0, 1008.0))
        bar = fm.snap_rect(mon, [0, 0, 1, 1], titlebar=36)
        self.assertEqual((bar[1], bar[3]), (44, 956))
        left = fm.snap_rect(mon, [0, 0, .5, 1])
        right = fm.snap_rect(mon, [.5, 0, .5, 1])
        self.assertEqual(left, [8, 8, 948, 992])
        self.assertEqual(right[0], 964)
        self.assertEqual(left[0] + left[2] + fm.GAP, right[0])
        rotated = fm.usable_area({'width': 1080, 'height': 2340, 'scale': 1, 'transform': 1})
        self.assertEqual(rotated[2:], (2340, 1080))
        self.assertTrue(all(fm.valid_cell(c) for layout in fm.LAYOUTS for c in layout))
        self.assertFalse(fm.valid_cell([0, 0, 1.5, 1]))
        self.assertFalse(fm.valid_cell([.6, 0, .6, 1]))

    def test_tablet_outputs_tile_again(self):
        mons = [{'id': 0, 'name': 'HDMI-A-1'}, {'id': 1, 'name': 'eDP-1'}]
        clients = [dict(win('0x1', 'kitty', floating=True), monitor=0), dict(win('0x2', 'firefox', fullscreen=1), monitor=0),
                   dict(win('0x3', 'org.gnome.Calculator', floating=True), monitor=0), dict(win('0x4', 'code', floating=True), monitor=1)]
        ops = fm.plan_tile_outputs(clients, mons, ['HDMI-A-1'], fm.user_float_rules(USER_CONFIG))
        self.assertEqual(ops, [{'op': 'float', 'address': '0x1', 'value': False}, {'op': 'unmaximize', 'address': '0x2'}])

    def test_nested_phone_window_stays_floating(self):
        mons = [{'id': 0, 'name': 'HDMI-A-1'}]
        clients = [dict(win('0x5', 'aquamarine', floating=True), monitor=0)]
        self.assertEqual(fm.plan_tile_outputs(clients, mons, ['HDMI-A-1'], []), [])

    def test_titlebar_colors(self):
        lua = fm.titlebar_colors({'dynamicPalette': {'dark': {'surface_container': '#271d1d', 'on_surface': '#f0dedd', 'error': 'not a colour'}}})
        self.assertIn('bar = "rgba(271d1df2)"', lua)
        self.assertIn('text = "rgb(f0dedd)"', lua)
        self.assertIn('close = "rgb(ffb4ab)"', lua)
        self.assertIn('respect_csd = true', lua)
        self.assertIn('csd_pattern =', lua)
        self.assertIn('bar = "rgba(f3e9e8f2)"', fm.titlebar_colors({'light': True}))
        with_outline = fm.titlebar_colors({'dynamicPalette': {'dark': {'outline_variant': '#464748'}}})
        self.assertIn('button = "rgb(464748)"', with_outline)
        off = fm.titlebar_colors({'respectCsd': False})
        self.assertIn('respect_csd = false', off)

    def test_client_side_decorations_recognition(self):
        self.assertTrue(fm.is_csd({'class': 'google-chrome'}))
        self.assertTrue(fm.is_csd({'class': 'firefox'}))
        self.assertTrue(fm.is_csd({'class': 'org.gnome.Nautilus'}))
        self.assertTrue(fm.is_csd({'class': 'code'}))
        self.assertTrue(fm.is_csd({'class': 'dev.opal.Files'}))
        self.assertTrue(fm.is_csd({'class': 'steam'}))
        self.assertTrue(fm.is_csd({'class': 'Steam'}))
        self.assertFalse(fm.is_csd({'class': 'kitty'}))
        self.assertFalse(fm.is_csd({'class': 'org.kde.dolphin'}))
        self.assertFalse(fm.is_csd({'class': 'steam'}, {'respectCsd': False}))
        self.assertFalse(fm.is_csd({'class': 'google-chrome'}, {'respectCsd': False}))

    def test_plan_resize_group_with_csd_member(self):
        mon = {'name': 'eDP-1', 'x': 0, 'y': 0, 'width': 1920, 'height': 1080, 'scale': 1, 'reserved': [0, 0, 0, 72]}
        snapped = {
            '0xa': {'cell': [0.0, 0.0, 0.5, 1.0], 'monitor': 'eDP-1', 'workspace': 1, 'rect': [10, 10, 800, 600], 'csd': True},
            '0xb': {'cell': [0.5, 0.0, 0.5, 1.0], 'monitor': 'eDP-1', 'workspace': 1, 'rect': [20, 20, 800, 600], 'csd': False},
        }
        updated, ops = fm.plan_resize_group(snapped, mon, 1, 0.5, titlebar=36)
        csd_rect = next(o['rect'] for o in ops if o['address'] == '0xa')
        non_csd_rect = next(o['rect'] for o in ops if o['address'] == '0xb')
        self.assertEqual(csd_rect[1], 8)
        self.assertEqual(non_csd_rect[1], 44)

    def test_fit_rect_keeps_windows_on_screen(self):
        mon = {'x': 0, 'y': 0, 'width': 1920, 'height': 1080, 'scale': 1, 'reserved': [0, 0, 0, 0]}
        big = fm.fit_rect([0, 0, 2400, 1400], mon, titlebar=36)
        self.assertEqual(big, [326, 172, 1267, 699])
        off = fm.fit_rect([1700, 900, 600, 400], mon, titlebar=36)
        self.assertEqual(off, [1312, 600, 600, 400])
        fine = fm.fit_rect([200, 200, 800, 600], mon, titlebar=36)
        self.assertEqual(fine, [200, 200, 800, 600])

    def test_state_round_trip(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = pathlib.Path(tmp, 'f.json')
            self.assertEqual(fm.load(path), {})
            fm.save({'before': ['0x1'], 'memory': {}}, path)
            self.assertEqual(fm.load(path)['before'], ['0x1'])

    def test_snap_groups_and_coupled_resize(self):
        mon = {'name': 'eDP-1', 'x': 0, 'y': 0, 'width': 1920, 'height': 1080, 'scale': 1, 'reserved': [0, 0, 0, 72]}
        snapped = {
            '0xa': {'cell': [0.0, 0.0, 0.5, 1.0], 'monitor': 'eDP-1', 'workspace': 1, 'rect': [10, 10, 800, 600]},
            '0xb': {'cell': [0.5, 0.0, 0.5, 1.0], 'monitor': 'eDP-1', 'workspace': 1, 'rect': [20, 20, 800, 600]},
        }
        groups = fm.snap_groups(snapped, [mon])
        self.assertEqual(len(groups), 1)
        self.assertAlmostEqual(groups[0]['ratio'], 0.5)
        self.assertEqual(fm.group_addresses(snapped, '0xa'), ['0xa', '0xb'])
        updated, ops = fm.plan_resize_group(snapped, mon, 1, 0.65)
        self.assertEqual(len(ops), 2)
        self.assertAlmostEqual(updated['0xa']['cell'][2], 0.65)
        self.assertAlmostEqual(updated['0xb']['cell'][0], 0.65)
        self.assertAlmostEqual(updated['0xb']['cell'][2], 0.35)
        # Left window right edge + GAP == Right window left edge
        left_rect = next(o['rect'] for o in ops if o['address'] == '0xa')
        right_rect = next(o['rect'] for o in ops if o['address'] == '0xb')
        self.assertEqual(left_rect[0] + left_rect[2] + fm.GAP, right_rect[0])



if __name__ == '__main__':
    unittest.main()
