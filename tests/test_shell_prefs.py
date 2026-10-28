import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'src'))
import shell_prefs as sp

TILES = ('wifi', 'media', 'focus', 'dnd')


class ShellPrefsTests(unittest.TestCase):
    def test_pills(self):
        self.assertTrue(sp.valid_preference('pillLevel', 'calm'))
        self.assertFalse(sp.valid_preference('pillLevel', 'loud'))
        self.assertTrue(sp.valid_preference('pillsCollapsed', True))
        self.assertFalse(sp.valid_preference('pillsCollapsed', 1))

    def test_tile_sizes_only_big_where_allowed(self):
        self.assertTrue(sp.valid_preference('quickTileSizes', {'wifi': 'wide', 'media': 'big'}, TILES))
        self.assertFalse(sp.valid_preference('quickTileSizes', {'wifi': 'big'}, TILES))
        self.assertFalse(sp.valid_preference('quickTileSizes', {'nope': 'round'}, TILES))

    def test_spaces(self):
        self.assertTrue(sp.valid_preference('spaces', {'2': {'name': 'Opal', 'icon': 'palette', 'color': '#c7a7ff'}}))
        self.assertFalse(sp.valid_preference('spaces', {'2': {'name': 'x' * 41}}))
        self.assertFalse(sp.valid_preference('spaces', {'2': {'icon': 'Bad Icon'}}))
        self.assertFalse(sp.valid_preference('spaces', {'two': {'name': 'Opal'}}))

    def test_saved_spaces(self):
        good = [{'id': 'quantlab', 'name': 'Quantlab', 'icon': 'science', 'color': '#ffb38a', 'apps': [{'app': 'code-oss', 'cls': 'code-oss', 'x': 0, 'y': 0, 'w': 800, 'h': 600}], 'saved': 1}]
        self.assertTrue(sp.valid_preference('savedSpaces', good))
        self.assertFalse(sp.valid_preference('savedSpaces', good + good))
        self.assertFalse(sp.valid_preference('savedSpaces', [{'id': 'x', 'name': 'X', 'apps': [{'app': 'rm -rf /'}]}]))

    def test_lock(self):
        self.assertTrue(sp.valid_preference('lockFace', 'thin'))
        self.assertFalse(sp.valid_preference('lockFace', 'shapes'))
        self.assertTrue(sp.valid_preference('lockColor', '#ffffff'))
        self.assertTrue(sp.valid_preference('lockWidgets', ['media', 'calendar']))
        self.assertFalse(sp.valid_preference('lockWidgets', ['media', 'media']))
        self.assertTrue(sp.valid_preference('lockShortcuts', {'left': 'tile:dnd', 'right': 'app:org.gnome.Calculator'}))
        self.assertFalse(sp.valid_preference('lockShortcuts', {'left': 'sh:reboot'}))

    def test_world_clocks(self):
        self.assertTrue(sp.valid_preference('worldClocks', ['Asia/Tokyo', 'America/New_York']))
        self.assertFalse(sp.valid_preference('worldClocks', ['Asia/Tokyo; rm']))


if __name__ == '__main__':
    unittest.main()
