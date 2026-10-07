import pathlib
import sys
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'src'))

from hypr_events import _drain_events, fullscreen_monitors, new_state


class HyprEventTests(unittest.TestCase):
    def test_burst_keeps_order_and_defers_one_refresh(self):
        emitted = []
        queries = []
        buffer = bytearray(
            b'activewindow>>kitty,First\n'
            b'openwindow>>0x1,1,kitty,First\n'
            b'activewindowv2>>0x1\n'
            b'focusedmonv2>>DP-1,3\n'
        )

        def query(name):
            queries.append(name)
            return {'id': 99}

        self.assertTrue(_drain_events(buffer, emitted.append, query))
        self.assertEqual(buffer, b'')
        self.assertEqual(queries, [])
        self.assertEqual(emitted, [
            {'title': 'First'},
            {'activeAddress': '0x1'},
            {'workspace': 3, 'activeMonitor': 'DP-1'},
        ])

    def test_fullscreen_is_output_and_workspace_specific(self):
        monitors = [{'id': 0, 'name': 'DP-1', 'activeWorkspace': {'id': 1}},
                    {'id': 1, 'name': 'DP-2', 'activeWorkspace': {'id': 2}}]
        client = {'mapped': True, 'monitor': 0, 'workspace': {'id': 1}, 'fullscreen': 2}
        self.assertEqual(fullscreen_monitors(monitors, [client]), ['DP-1'])
        for change in ({'fullscreen': 1}, {'mapped': False}, {'workspace': {'id': 3}}, {'hidden': True}):
            self.assertEqual(fullscreen_monitors(monitors, [dict(client, **change)]), [])
        monitors[0]['specialWorkspace'] = {'id': -99}
        self.assertEqual(fullscreen_monitors(monitors, [client]), [])

    def test_fullscreen_event_requests_refresh(self):
        self.assertTrue(_drain_events(bytearray(b'fullscreen>>1\n'), lambda _: None, lambda _: None))

    def test_incomplete_line_waits_for_the_next_burst(self):
        emitted = []
        buffer = bytearray(b'activewindow>>foot,Part')
        self.assertFalse(_drain_events(buffer, emitted.append, lambda _: None))
        self.assertEqual(emitted, [])
        self.assertEqual(buffer, b'activewindow>>foot,Part')
        buffer.extend(b'ial\nactivewindowv2>>\n')
        self.assertFalse(_drain_events(buffer, emitted.append, lambda _: None))
        self.assertEqual(buffer, b'')
        self.assertEqual(emitted, [{'title': 'Partial'}, {'activeAddress': ''}])

    def test_legacy_focus_queries_workspace_once(self):
        emitted = []
        queries = []

        def query(name):
            queries.append(name)
            return {'id': 7}

        self.assertTrue(_drain_events(bytearray(b'focusedmon>>HDMI-A-1,unused\n'), emitted.append, query))
        self.assertEqual(queries, ['activeworkspace'])
        self.assertEqual(emitted, [{'workspace': 7, 'activeMonitor': 'HDMI-A-1'}])

    def test_large_mixed_burst_preserves_every_event_in_order(self):
        event_count = 4_096
        titles = [f'Window {index}' for index in range(event_count)]
        buffer = bytearray(b''.join(
            f'activewindow>>app,{title}\nactivewindowv2>>0x{index:x}\n'.encode()
            for index, title in enumerate(titles)
        ))
        emitted = []

        self.assertFalse(_drain_events(buffer, emitted.append, lambda _: None))
        self.assertEqual(buffer, b'')
        self.assertEqual(len(emitted), event_count * 2)
        self.assertEqual(
            emitted,
            [item for index, title in enumerate(titles) for item in (
                {'title': title}, {'activeAddress': f'0x{index:x}'},
            )],
        )

    def drain(self, data, state=None):
        emitted = []
        refresh = _drain_events(bytearray(data), emitted.append, lambda _: {'id': 1}, state)
        return emitted, refresh

    def test_urgent_clears_on_focus_and_close(self):
        state = new_state()
        emitted, refresh = self.drain(b'urgent>>abc\nurgent>>abc\nurgent>>def\nactivewindowv2>>abc\nclosewindow>>def\n', state)
        self.assertTrue(refresh)
        self.assertEqual(emitted, [{'urgent': ['0xabc']}, {'urgent': ['0xabc', '0xdef']},
                                   {'activeAddress': '0xabc'}, {'urgent': ['0xdef']}, {'urgent': []}])
        self.assertEqual(state['urgent'], [])

    def test_submap_is_published_without_refresh(self):
        emitted, refresh = self.drain(b'submap>>resize\nsubmap>>\n')
        self.assertFalse(refresh)
        self.assertEqual(emitted, [{'submap': 'resize'}, {'submap': ''}])

    def test_special_workspace_per_monitor(self):
        state = new_state()
        emitted, refresh = self.drain(b'activespecialv2>>-98,special:magic,DP-1\nactivespecialv2>>0,,DP-1\n'
                                    b'activespecial>>special:term,HDMI-A-1\n', state)
        self.assertTrue(refresh)
        self.assertEqual(emitted[0], {'special': {'DP-1': 'special:magic'}})
        self.assertEqual(emitted[1], {'special': {'DP-1': ''}})
        self.assertEqual(emitted[2], {'special': {'DP-1': '', 'HDMI-A-1': 'special:term'}})

    def test_title_update_skips_refresh(self):
        emitted, refresh = self.drain(b'windowtitlev2>>1f,Hello, world\n')
        self.assertFalse(refresh)
        self.assertEqual(emitted, [{'windowTitle': {'address': '0x1f', 'title': 'Hello, world'}}])

    def test_minimized_toggles(self):
        state = new_state()
        emitted, _ = self.drain(b'minimized>>a1,1\nminimized>>a1,1\nminimized>>a1,0\n', state)
        self.assertEqual(emitted, [{'minimized': ['0xa1']}, {'minimized': []}])


if __name__ == '__main__':
    unittest.main()
