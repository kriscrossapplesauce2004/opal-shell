import pathlib
import sys
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'src'))

from hypr_events import _drain_events, fullscreen_monitors


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


if __name__ == '__main__':
    unittest.main()
