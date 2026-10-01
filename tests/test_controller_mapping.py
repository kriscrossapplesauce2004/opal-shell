import pathlib
import sys
import unittest
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'src'))
from controller_mapping import NavigationState, axis_orientation, button_action


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
        self.assertIsNone(button_action(0, codes=[999], profile='stadia'))
        self.assertEqual(button_action(0, codes=[704], profile='stadia'), 'menu')

    def test_fallback(self):
        self.assertEqual(button_action(0), 'accept')
        self.assertEqual(button_action(6), 'menu')
        self.assertEqual(axis_orientation(6), 'horizontal')

    def test_axes_ignore_triggers_and_right_stick(self):
        self.assertEqual(axis_orientation(0, [16]), 'horizontal')
        self.assertEqual(axis_orientation(0, [17]), 'vertical')
        for code in (2, 3, 4, 5):
            self.assertIsNone(axis_orientation(0, [code]))

    def test_repeat_keeps_each_held_axis_and_deduplicates_keys(self):
        navigation = NavigationState()
        navigation.held = {(2, 0): ('left', 0), (2, 1): ('left', 0), (2, 2): ('right', 2)}
        self.assertEqual(navigation.repeat(1), ['left'])
        self.assertEqual(navigation.held[(2, 0)], ('left', 1.13))
        self.assertEqual(navigation.held[(2, 1)], ('left', 1.13))
        self.assertEqual(navigation.held[(2, 2)], ('right', 2))

    def test_cached_dispatch_preserves_startup_and_trigger_edges(self):
        navigation = NavigationState(buttons=[304], axes=[2], profile='xbox')
        self.assertEqual(navigation.feed(0x82, 0, 26000, 0), [])
        self.assertEqual(navigation.feed(2, 0, 0, 1), [])
        self.assertEqual(navigation.feed(2, 0, 26000, 2), ['pageUp'])
        self.assertEqual(navigation.feed(0x81, 0, 1, 3), [])
        self.assertEqual(navigation.feed(1, 0, 0, 4), [])
        self.assertEqual(navigation.feed(1, 0, 1, 5), ['accept'])

    def test_cached_axis_descriptor_keeps_unknown_axis_safe(self):
        navigation = NavigationState(axes=[99])
        self.assertEqual(navigation.feed(2, 0, 32767, 0), [])
        self.assertEqual(navigation.feed(2, 0, -32767, 1), [])

    def test_large_event_stream_keeps_edges_and_startup_safety(self):
        cycles = 4000
        events = []
        for cycle in range(cycles):
            events.extend(((0x82, 0, 26000), (2, 0, 0), (2, 0, 26000),
                           (2, 0, 0), (0x81, 0, 1), (1, 0, 0),
                           (1, 0, 1), (1, 0, 0)))

        navigation = NavigationState(buttons=[304], axes=[2], profile='xbox')
        actions = []
        for index, (kind, number, value) in enumerate(events):
            actions.extend(navigation.feed(kind, number, value, index * .001))

        expected_edges = sum(1 for kind, _, value in events
                             if kind == 2 and not kind & 0x80 and value == 26000)
        expected_buttons = sum(1 for kind, _, value in events
                               if kind == 1 and not kind & 0x80 and value)
        self.assertEqual(actions.count('pageUp'), expected_edges)
        self.assertEqual(actions.count('accept'), expected_buttons)
        self.assertEqual(len(actions), expected_edges + expected_buttons)
