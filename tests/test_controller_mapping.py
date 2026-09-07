import pathlib
import sys
import unittest
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
from controller_mapping import button_action, axis_orientation


class ControllerMappingTests(unittest.TestCase):
    def test_kernel_order_overrides_index(self):
        self.assertEqual(button_action(0, codes=[315]), 'home')
        self.assertEqual(button_action(2, codes=[304, 305, 307, 308]), 'search')
        self.assertEqual(button_action(3, codes=[304, 305, 307, 308]), 'pin')

    def test_swapped_layout(self):
        for code, action in [(304, 'back'), (305, 'accept'), (307, 'pin'), (308, 'search')]:
            self.assertEqual(button_action(0, 'nintendo', [code]), action)

    def test_unknown_buttons_do_not_activate(self):
        self.assertIsNone(button_action(0, codes=[999]))
        self.assertIsNone(button_action(99))

    def test_fallback(self):
        self.assertEqual(button_action(0), 'accept')
        self.assertEqual(button_action(6), 'menu')
        self.assertEqual(axis_orientation(6), 'horizontal')

    def test_axes_ignore_triggers_and_right_stick(self):
        self.assertEqual(axis_orientation(0, [16]), 'horizontal')
        self.assertEqual(axis_orientation(0, [17]), 'vertical')
        for code in (2, 3, 4, 5):
            self.assertIsNone(axis_orientation(0, [code]))
