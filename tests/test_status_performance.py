import os
import pathlib
import stat
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'src'))
import status


class StatusPerformanceTests(unittest.TestCase):
    def test_status_schedules_independent_probes_together(self):
        calls = []

        def fake_run(*args):
            calls.append(args[0])
            return {
                'wpctl': 'Volume: 0.42',
                'nmcli': 'Home:wifi',
                'playerctl': 'Track\x1fArtist',
            }[args[0]]

        with patch.object(status, 'run', side_effect=fake_run), patch.dict(os.environ, {}, clear=True):
            result = status.collect_status()

        self.assertEqual(sorted(calls), ['nmcli', 'playerctl', 'wpctl'])
        self.assertEqual(result['volume'], 42)
        self.assertEqual(result['network'], 'Home')
        self.assertEqual((result['track'], result['artist']), ('Track', 'Artist'))

    def test_hyprland_probe_keeps_compositor_fields_and_all_probes(self):
        responses = {
            'wpctl': 'Volume: 0.42',
            'nmcli': 'Home:wifi',
            'playerctl': 'Track\x1fArtist',
            'activeworkspace': '{"id": 4}',
            'workspaces': '[{"id": 1}, {"id": 4}]',
            'activewindow': '{"title": "Editor"}',
        }
        calls = []

        def fake_run(*args):
            calls.append(args[0])
            return responses[args[1] if args[0] == 'hyprctl' else args[0]]

        with patch.object(status, 'run', side_effect=fake_run), patch.dict(
                os.environ, {'HYPRLAND_INSTANCE_SIGNATURE': 'test'}, clear=True):
            result = status.collect_status()

        self.assertEqual(sorted(calls), ['hyprctl'] * 3 + ['nmcli', 'playerctl', 'wpctl'])
        self.assertEqual(result['workspace'], 4)
        self.assertEqual(result['workspaces'], [1, 4])
        self.assertEqual(result['title'], 'Editor')

    def test_fake_commands_count_invocations_and_parse_fields(self):
        with tempfile.TemporaryDirectory(prefix='opal-status-') as directory:
            root = pathlib.Path(directory)
            bindir = root / 'bin'
            bindir.mkdir()
            counter = root / 'invocations'
            commands = {
                'wpctl': 'printf "Volume: 0.42\\n"',
                'nmcli': 'printf "Home:wifi\\n"',
                'playerctl': 'printf "Track\\037Artist\\n"',
            }
            for name, output in commands.items():
                command = bindir / name
                command.write_text(
                    '#!/bin/sh\n'
                    'printf "%s\\n" "$0" >> "$OPAL_STATUS_COUNTER"\n'
                    'sleep 0.01\n'
                    + output + '\n'
                )
                command.chmod(command.stat().st_mode | stat.S_IXUSR)

            environment = {
                'PATH': str(bindir) + os.pathsep + os.environ['PATH'],
                'OPAL_STATUS_COUNTER': str(counter),
            }
            with patch.dict(os.environ, environment, clear=True):
                started = time.perf_counter()
                result = status.collect_status()
                elapsed = time.perf_counter() - started

            self.assertEqual(len(counter.read_text().splitlines()), 3)
            self.assertEqual(result['volume'], 42)
            self.assertFalse(result['muted'])
            self.assertEqual(result['network'], 'Home')
            self.assertEqual(result['track'], 'Track')
            self.assertEqual(result['artist'], 'Artist')
            self.assertGreater(elapsed, 0)

    def test_one_failed_probe_does_not_cancel_other_probes(self):
        calls = []

        def fake_run(*args):
            calls.append(args[0])
            if args[0] == 'wpctl':
                raise RuntimeError('probe failed')
            return 'Home:wifi' if args[0] == 'nmcli' else 'Track\x1fArtist'

        with patch.object(status, 'run', side_effect=fake_run), patch.dict(os.environ, {}, clear=True):
            result = status.collect_status()

        self.assertEqual(sorted(calls), ['nmcli', 'playerctl', 'wpctl'])
        self.assertEqual(result['volume'], 0)
        self.assertEqual(result['network'], 'Home')
        self.assertEqual(result['track'], 'Track')

    def test_battery_scan_keeps_all_real_capacity_values(self):
        with tempfile.TemporaryDirectory(prefix='opal-battery-') as directory:
            paths = []
            for index in range(512):
                capacity = pathlib.Path(directory) / f'BAT{index}'
                capacity.write_text(str(index % 101))
                paths.append(str(capacity))

            with patch.object(status, 'run', return_value=''), \
                    patch.object(status.glob, 'iglob', return_value=iter(paths)), \
                    patch.dict(os.environ, {}, clear=True):
                result = status.collect_status()

        self.assertEqual(result['battery'], 511 % 101)


if __name__ == '__main__':
    unittest.main()
