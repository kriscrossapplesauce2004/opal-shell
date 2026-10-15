import datetime, json, os, pathlib, sys, tempfile, time, types, unittest
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'src'))
import home_data as hd
import weather


class WeatherTests(unittest.TestCase):
    def fake(self, calls):
        def fetch(url):
            calls.append(url)
            if 'geocoding' in url: return {'results': [{'name': 'Lisbon', 'country_code': 'PT', 'latitude': 38.72, 'longitude': -9.14}]}
            return {'current': {'temperature_2m': 18.4, 'weather_code': 2, 'is_day': 1}, 'current_units': {'temperature_2m': '°C'},
                    'daily': {'temperature_2m_max': [21.2], 'temperature_2m_min': [13.9]}}
        return fetch

    def test_update_geocodes_once_and_caches(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = pathlib.Path(tmp, 'w.json'); calls = []
            data = weather.update('Lisbon', now=1000, fetch=self.fake(calls), path=path)
            self.assertEqual((data['temp'], data['text'], data['icon'], data['high'], data['low'], data['place']), (18, 'Partly cloudy', 'partly_cloudy_day', 21, 14, 'Lisbon'))
            self.assertEqual(len(calls), 2)
            weather.update('Lisbon', now=1000 + 60, fetch=self.fake(calls), path=path)
            self.assertEqual(len(calls), 2)
            weather.update('Lisbon', now=1000 + weather.REFRESH + 1, fetch=self.fake(calls), path=path)
            self.assertEqual(len(calls), 3)
            self.assertNotIn('geocoding', calls[-1])

    def test_network_failure_keeps_last_value(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = pathlib.Path(tmp, 'w.json')
            weather.update('Lisbon', now=0, fetch=self.fake([]), path=path)
            def broken(url): raise OSError('offline')
            self.assertEqual(weather.update('Lisbon', now=weather.REFRESH * 3, fetch=broken, path=path)['temp'], 18)
            self.assertIsNone(weather.update('Paris', now=weather.REFRESH * 3, fetch=broken, path=path))
            self.assertIsNone(weather.update('', fetch=broken, path=path))

    def test_unknown_city_and_bad_payload(self):
        self.assertIsNone(weather.geocode('Nowhere', fetch=lambda url: {'results': []}))
        self.assertIsNone(weather.geocode('x' * 90, fetch=lambda url: {}))
        self.assertIsNone(weather.parse_forecast({'current': {}}, {}))


class HomeDataTests(unittest.TestCase):
    def test_desktop_listing(self):
        with tempfile.TemporaryDirectory() as tmp:
            d = pathlib.Path(tmp)
            (d / 'Prints').mkdir(); (d / 'notes.md').write_text('x'); (d / '.hidden').write_text('x'); (d / 'shot.png').write_text('x')
            (d / 'kitty.desktop').write_text('[Desktop Entry]\nType=Application\nName=Terminal\nIcon=kitty\nExec=kitty\n')
            (d / 'broken.desktop').write_text('nonsense')
            items = hd.list_desktop(d)
            self.assertEqual([i['name'] for i in items], ['Prints', 'broken.desktop', 'Terminal', 'notes.md', 'shot.png'])
            self.assertTrue(items[0]['dir']); self.assertTrue(items[2]['app']); self.assertEqual(items[2]['icon'], 'kitty')
            self.assertTrue(items[4]['thumb'].startswith('file://')); self.assertEqual(items[4]['icon'], 'image-png'); self.assertEqual(items[0]['icon'], 'folder')
            self.assertTrue(hd.inside(str(d / 'notes.md'), d)); self.assertFalse(hd.inside('/etc/passwd', d)); self.assertFalse(hd.inside(None, d))

    def test_desktop_dir_from_user_dirs(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = pathlib.Path(tmp); (home / '.config').mkdir()
            self.assertEqual(hd.desktop_dir(home), home / 'Desktop')
            (home / '.config/user-dirs.dirs').write_text('XDG_DESKTOP_DIR="$HOME/Schreibtisch"\n')
            self.assertEqual(hd.desktop_dir(home), home / 'Schreibtisch')

    def test_memory_prefers_this_week_in_earlier_years(self):
        today = datetime.date(2026, 10, 15)
        ts = lambda y, m, d: time.mktime(datetime.date(y, m, d).timetuple()) + 3600
        images = [('/p/old.jpg', ts(2024, 10, 14)), ('/p/recent.jpg', ts(2026, 9, 1)), ('/p/far.jpg', ts(2023, 3, 1))]
        self.assertEqual(hd.memory(images, today), {'path': '/p/old.jpg', 'caption': '2 years ago', 'detail': 'Memories'})
        self.assertEqual(hd.memory(images[1:], today)['caption'], 'Recently')
        self.assertIsNone(hd.memory([('/p/far.jpg', ts(2023, 3, 1))], today))

    def test_pending_updates(self):
        run = lambda args, **kw: types.SimpleNamespace(returncode=0, stdout='mesa 1 -> 2\nlinux 3 -> 4\n')
        self.assertEqual(hd.pending_updates(runner=run, which=lambda n: '/usr/bin/checkupdates'), 2)
        self.assertEqual(hd.pending_updates(runner=lambda *a, **k: types.SimpleNamespace(returncode=2, stdout=''), which=lambda n: '/x'), 0)
        self.assertEqual(hd.pending_updates(which=lambda n: None), -1)

    def test_preferences(self):
        good = [{'id': 'g1', 'kind': 'glance', 'x': 10, 'y': 0, 'w': 5, 'h': 1}]
        self.assertTrue(hd.valid_preference('desktopCanvas', good))
        self.assertFalse(hd.valid_preference('desktopCanvas', good + good))
        self.assertFalse(hd.valid_preference('desktopCanvas', [dict(good[0], kind='evil')]))
        self.assertFalse(hd.valid_preference('desktopCanvas', [dict(good[0], w=0)]))
        self.assertTrue(hd.valid_preference('desktopSlots', {'notes.md': 3}))
        self.assertFalse(hd.valid_preference('desktopSlots', {'a/b': 1}))
        self.assertTrue(hd.valid_preference('weatherCity', 'Lisbon'))
        self.assertFalse(hd.valid_preference('weatherCity', 5))
        self.assertFalse(hd.valid_preference('other', 1))


if __name__ == '__main__':
    unittest.main()
