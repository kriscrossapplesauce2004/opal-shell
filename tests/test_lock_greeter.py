import io, json, os, pathlib, sys, tempfile, unittest
from unittest.mock import patch
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'src'))
import backend, greeter_info


class LockAndGreeterTests(unittest.TestCase):
    def test_session_path_encoding(self):
        self.assertEqual(backend.session_object_path('8'), '/org/freedesktop/login1/session/_38')
        self.assertEqual(backend.session_object_path('c2'), '/org/freedesktop/login1/session/c2')
        self.assertEqual(backend.session_object_path(''), '')

    def test_logind_lock_and_unlock_for_this_session_only(self):
        path = backend.session_object_path('8')
        lines = [
            f"{backend.session_object_path('9')}: org.freedesktop.login1.Session.Lock ()\n",
            f"{path}: org.freedesktop.login1.Session.Lock ()\n",
            f"{path}: org.freedesktop.login1.Session.Unlock ()\n",
        ]
        class Fake: stdout = io.StringIO(''.join(lines))
        events = []
        with patch.object(backend, 'emit', events.append), patch.object(backend.shutil, 'which', return_value='/usr/bin/gdbus'):
            backend.logind_locks('8', Fake())
        self.assertEqual(events, [{'event': 'lock'}, {'event': 'unlock'}])

    def test_greeter_theme_sync_copies_wallpaper_and_roles(self):
        with tempfile.TemporaryDirectory() as root:
            root = pathlib.Path(root)
            cache = root / 'cache'; cache.mkdir()
            image = root / 'wall.png'; image.write_bytes(b'png')
            values = {'light': True, 'palette': 2, 'wallpaperPath': image.as_uri(), 'favorites': ['secret-app']}
            self.assertTrue(backend.sync_greeter_theme(values, cache))
            theme = json.loads((cache / 'theme.json').read_text())
            self.assertEqual(theme['light'], True)
            self.assertNotIn('favorites', theme)
            self.assertEqual(theme['wallpaperPath'], (cache / 'wallpaper.png').as_uri())
            self.assertEqual((cache / 'wallpaper.png').read_bytes(), b'png')

    def test_greeter_theme_sync_skips_missing_cache(self):
        self.assertFalse(backend.sync_greeter_theme({}, pathlib.Path('/nonexistent/opal-greeter')))

    def test_desktop_entry_parsing(self):
        with tempfile.TemporaryDirectory() as root:
            root = pathlib.Path(root)
            (root / 'a.desktop').write_text('[Desktop Entry]\nName=Alpha\nExec=alpha --flag %U\n[Desktop Action x]\nExec=nope\n')
            (root / 'b.desktop').write_text('[Desktop Entry]\nName=Hidden\nExec=b\nNoDisplay=true\n')
            (root / 'c.desktop').write_text('[Desktop Entry]\nName=Broken\nExec="unterminated\n')
            with patch.object(greeter_info, 'SESSION_DIRS', [root]):
                self.assertEqual(greeter_info.sessions(), [{'id': 'a', 'name': 'Alpha', 'desktop': 'a', 'command': ['alpha', '--flag']}])

    def test_desktop_identity_uses_desktop_names_not_display_name(self):
        with tempfile.TemporaryDirectory() as root:
            path = pathlib.Path(root) / 'plasma.desktop'
            path.write_text('[Desktop Entry]\nName=Plasma (Wayland)\nDesktopNames=KDE;Other;\nExec=startplasma-wayland\n')
            self.assertEqual(greeter_info.desktop_entry(path)['desktop'], 'KDE:Other')

    def test_remember_round_trip(self):
        with tempfile.TemporaryDirectory() as root:
            state = pathlib.Path(root) / 'state.json'
            with patch.object(greeter_info, 'STATE', state):
                greeter_info.remember('melissa', 'hyprland')
                self.assertEqual(greeter_info.remembered(), {'user': 'melissa', 'session': 'hyprland'})


class PhoneHomeValidationTests(unittest.TestCase):
    def test_accepts_pages_widgets_and_folders(self):
        layout = {'pages': [{'widgets': ['glance', 'stack'], 'items': ['firefox', {'folder': 'Games', 'apps': ['steam', 'prism']}]}, {'widgets': [], 'items': []}]}
        self.assertTrue(backend.valid_phone_home(layout))

    def test_accepts_empty_cells_for_free_placement(self):
        layout = {'pages': [{'widgets': [], 'items': ['firefox', None, None, 'steam']}]}
        self.assertTrue(backend.valid_phone_home(layout))
        self.assertFalse(backend.valid_phone_home({'pages': [{'widgets': [], 'items': [None] * 97}]}))

    def test_accepts_desktop_files_as_home_items(self):
        self.assertTrue(backend.valid_phone_home({'pages': [{'widgets': [], 'items': [{'path': '/home/u/Desktop/notes.md'}, 'firefox']}]}))
        self.assertTrue(backend.valid_phone_home({'pages': [{'widgets': [], 'items': [{'pair': ['firefox', 'kitty'], 'ratio': 0.5}]}]}))
        self.assertFalse(backend.valid_phone_home({'pages': [{'widgets': [], 'items': [{'pair': ['firefox'], 'ratio': 0.5}]}]}))
        self.assertFalse(backend.valid_phone_home({'pages': [{'widgets': [], 'items': [{'path': 'relative.md'}]}]}))
        self.assertFalse(backend.valid_phone_home({'pages': [{'widgets': [], 'items': [{'path': '/x', 'run': 'rm'}]}]}))

    def test_rejects_unknown_widgets_and_bad_folders(self):
        self.assertFalse(backend.valid_phone_home({'pages': [{'widgets': ['evil'], 'items': []}]}))
        self.assertFalse(backend.valid_phone_home({'pages': [{'widgets': [], 'items': [{'folder': 'x', 'apps': []}]}]}))
        self.assertFalse(backend.valid_phone_home({'pages': [{'widgets': [], 'items': [{'folder': 'x', 'apps': ['a'], 'run': 'rm'}]}]}))
        self.assertFalse(backend.valid_phone_home({'pages': []}))


if __name__ == '__main__':
    unittest.main()
