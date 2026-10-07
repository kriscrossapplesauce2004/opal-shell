import datetime, pathlib, sys, tempfile, unittest
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'src'))
import system_tools as t

COLORS = {r: '#336699' for r in t.ROLES}
COLORS.update(base='#15121a', text='#e7e0eb', primary='#84d7b0')


class Result:
    returncode = 0; stdout = 'ok'


class SystemToolsTests(unittest.TestCase):
    def test_export_writes_files_and_include_once(self):
        with tempfile.TemporaryDirectory() as home:
            home = pathlib.Path(home)
            (home / '.config/kitty').mkdir(parents=True)
            (home / '.config/kitty/kitty.conf').write_text('font_size 12\n')
            calls = []
            for _ in range(2): t.export_theme(COLORS, ['gtk', 'kitty', 'qt'], home, runner=lambda a: calls.append(a) or Result())
            kitty = (home / '.config/kitty/kitty.conf').read_text()
            self.assertEqual(kitty.count('include opal-theme.conf'), 1)
            self.assertIn('font_size 12', kitty)
            self.assertIn('background #15121a', (home / '.config/kitty/opal-theme.conf').read_text())
            self.assertIn('@define-color accent_color #84d7b0;', (home / '.config/gtk-4.0/opal.css').read_text())
            self.assertEqual((home / '.config/gtk-3.0/gtk.css').read_text().count('@import "opal.css";'), 1)
            self.assertTrue((home / '.config/qt6ct/colors/Opal.conf').exists())
            t.remove_export(['gtk', 'kitty', 'qt'], home, runner=lambda a: calls.append(a) or Result())
            self.assertNotIn('opal-theme', (home / '.config/kitty/kitty.conf').read_text())
            self.assertFalse((home / '.config/gtk-4.0/opal.css').exists())

    def test_export_rejects_bad_colours(self):
        with self.assertRaises(ValueError): t.export_theme(dict(COLORS, primary='red; rm -rf'), ['gtk'], pathlib.Path('/nonexistent'))

    def test_zone_coordinates_and_sun(self):
        with tempfile.NamedTemporaryFile('w', suffix='.tab', delete=False) as table:
            table.write('GB,GG,IM,JE\t+513030-0000731\tEurope/London\n')
        lat, lon = t.zone_coordinates('Europe/London', pathlib.Path(table.name))
        self.assertAlmostEqual(lat, 51.508, places=2); self.assertAlmostEqual(lon, -0.125, places=2)
        sunrise, sunset = t.sun_times(lat, lon, datetime.date(2026, 6, 21))
        self.assertTrue('03:00' < sunrise < '06:00' and '19:00' < sunset < '22:30', (sunrise, sunset))
        self.assertIsNone(t.sun_times(78.2, 15.6, datetime.date(2026, 6, 21)))

    def test_monitor_lua_validation(self):
        self.assertEqual(t.monitor_lua({'name': 'DP-1', 'mode': '1920x1080@60.00Hz', 'x': 1920, 'y': 0, 'scale': 1.5, 'transform': 1}),
                         'hl.monitor({output="DP-1",mode="1920x1080@60.00",position="1920x0",scale=1.5,transform=1})')
        for bad in ({'name': 'DP-1"); os.exit(', 'mode': 'preferred'}, {'name': 'DP-1', 'mode': '1920x1080; x'}, {'name': 'DP-1', 'scale': 9}, {'name': 'DP-1', 'mirror': 'a"b'}):
            with self.assertRaises(ValueError): t.monitor_lua(bad)
        with self.assertRaises(ValueError): t.apply_monitors([{'name': 'DP-1', 'disabled': True}], runner=lambda a: Result())

    def test_temperatures(self):
        with tempfile.TemporaryDirectory() as root:
            chip = pathlib.Path(root) / 'hwmon0'; chip.mkdir()
            (chip / 'name').write_text('k10temp\n'); (chip / 'temp1_input').write_text('54250\n'); (chip / 'temp2_input').write_text('61000\n')
            self.assertEqual(t.temperatures(pathlib.Path(root)), {'k10temp': 61})


if __name__ == '__main__':
    unittest.main()
