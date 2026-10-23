import pathlib, sys, unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'src'))
import routines_engine


class RoutinesEngineTests(unittest.TestCase):
    def test_reversible_state_snapshot_and_restore(self):
        events = []
        state = {'dnd': False, 'light': True, 'profile': 'balanced', 'nightLight': False}
        engine = routines_engine.RoutinesEngine(
            events.append,
            get_state=lambda k: state.get(k),
            apply_effect=lambda k, v: state.__setitem__(k, v),
        )
        routines = [
            {
                'id': 'work-focus',
                'name': 'Work & Code Focus',
                'icon': 'code',
                'enabled': True,
                'when': {'kind': 'app', 'value': 'code'},
                'do': {'dnd': True, 'profile': 'performance'},
            }
        ]
        # Trigger activates when 'code' is focused
        changed = engine.evaluate(routines, {'active_class': 'code', 'charging': True, 'battery': 80})
        self.assertTrue(changed)
        self.assertEqual(state['dnd'], True)
        self.assertEqual(state['profile'], 'performance')
        self.assertTrue(any(e.get('event') == 'activity' and e.get('op') == 'start' for e in events))

        # When 'firefox' is focused instead, the routine deactivates and restores baseline state
        events.clear()
        changed = engine.evaluate(routines, {'active_class': 'firefox', 'charging': True, 'battery': 80})
        self.assertTrue(changed)
        self.assertEqual(state['dnd'], False)
        self.assertEqual(state['profile'], 'balanced')
        self.assertTrue(any(e.get('event') == 'activity' and e.get('op') == 'end' and e.get('id') == 'routine-work-focus' for e in events))

    def test_battery_and_manual_triggers(self):
        r_bat = {
            'id': 'low-bat',
            'name': 'Battery Guardian',
            'icon': 'battery_saver',
            'enabled': True,
            'when': {'kind': 'battery', 'value': 20},
            'do': {'profile': 'power-saver'},
        }
        self.assertTrue(routines_engine.matches(r_bat, {'battery': 15, 'charging': False}))
        self.assertFalse(routines_engine.matches(r_bat, {'battery': 15, 'charging': True}))
        self.assertTrue(routines_engine.matches(r_bat, {'battery': 90, 'charging': True, 'manual_ids': ['low-bat']}))

    def test_preference_validation(self):
        self.assertTrue(routines_engine.valid_preference('routines', routines_engine.DEFAULT_ROUTINES))
        self.assertFalse(routines_engine.valid_preference('routines', [{'id': 'bad;rm', 'name': 'x', 'enabled': True, 'when': {'kind': 'app', 'value': 'a'}, 'do': {'dnd': True}}]))
        self.assertTrue(routines_engine.valid_preference('activeModes', ['work-focus']))


if __name__ == '__main__':
    unittest.main()
