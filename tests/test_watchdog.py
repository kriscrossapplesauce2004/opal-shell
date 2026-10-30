import importlib.machinery
import importlib.util
import io
import json
import os
import pathlib
import signal
import subprocess
import sys
import tempfile
import threading
import time
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
WATCHDOG = ROOT / 'tools' / 'luna-watchdog'
loader = importlib.machinery.SourceFileLoader('luna_watchdog', str(WATCHDOG))
spec = importlib.util.spec_from_loader('luna_watchdog', loader)
watchdog = importlib.util.module_from_spec(spec)
loader.exec_module(watchdog)

PY = sys.executable
CRASH_BOOM = 'import sys; print("boom", file=sys.stderr); sys.exit(1)'
SLEEP_LONG = 'import time; time.sleep(60)'
# Crash four times, then exit cleanly. The counter file lives in argv[1].
COUNTED = ('import pathlib, sys; p = pathlib.Path(sys.argv[1]); '
           'n = int(p.read_text()) if p.exists() else 0; p.write_text(str(n + 1)); '
           'sys.exit(1 if n < 4 else 0)')


class FakeClock:
    def __init__(self):
        self.now = 1000.0

    def __call__(self):
        return self.now

    def sleep(self, seconds):
        self.now += seconds

    def sleep_past_window(self, seconds):
        self.now += 61.0


class WindowRuleTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        root = pathlib.Path(self.temp.name)
        self.dog = watchdog.Watchdog([PY, '-c', 'pass'], [PY, '-c', 'pass'], root / 'state', root / 'retry',
                                     forward=io.StringIO())

    def tearDown(self):
        self.temp.cleanup()

    def test_three_crashes_inside_a_minute_reach_the_limit(self):
        counts = [self.dog.count_crash(t) for t in (0, 30, 59)]
        self.assertEqual(counts, [1, 2, 3])

    def test_a_crash_older_than_a_minute_leaves_the_window(self):
        counts = [self.dog.count_crash(t) for t in (0, 30, 61)]
        self.assertEqual(counts, [1, 2, 2])


class SupervisionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.temp.name)
        self.events = []
        self.forward = io.StringIO()

    def tearDown(self):
        self.temp.cleanup()

    def make(self, command, safe_command, clock=time.monotonic, sleep=time.sleep):
        return watchdog.Watchdog(command, safe_command, self.root / 'state', self.root / 'retry',
                                 clock=clock, sleep=sleep, forward=self.forward,
                                 on_event=lambda *e: self.events.append(e))

    def names(self):
        return [event[0] for event in self.events]

    def test_clean_exit_does_not_restart(self):
        dog = self.make([PY, '-c', 'pass'], [PY, '-c', 'pass'])
        dog.run()
        self.assertEqual(self.names(), ['spawn', 'stop'])
        self.assertFalse((self.root / 'state' / 'crashes').exists())

    def test_backoff_then_safe_mode_with_crash_report(self):
        env_file = self.root / 'safe-env.txt'
        safe = [PY, '-c', 'import os, pathlib, sys; '
                'pathlib.Path(sys.argv[1]).write_text(os.environ.get("OPAL_CRASH_REPORT", "") + "|" + '
                'os.environ.get("OPAL_WATCHDOG_RETRY", ""))', str(env_file)]
        clock = FakeClock()
        dog = self.make([PY, '-c', CRASH_BOOM], safe, clock=clock, sleep=clock.sleep)
        dog.run()
        backoffs = [e[1] for e in self.events if e[0] == 'backoff']
        self.assertEqual(backoffs, [1.0, 2.0])
        self.assertIn(('safe',), self.events)
        self.assertEqual(dog.total_crashes, 3)
        report_text, retry_text = env_file.read_text().split('|')
        self.assertEqual(pathlib.Path(report_text).parent, self.root / 'state' / 'crashes')
        self.assertEqual(retry_text, str(self.root / 'retry'))
        report = pathlib.Path(report_text)
        info = json.loads((report / 'report.json').read_text())
        self.assertEqual(info['exit_code'], 1)
        self.assertIsNone(info['signal'])
        self.assertIn('boom', (report / 'log.txt').read_text())
        self.assertEqual(info['source'], 'unknown')

    def test_crashes_spaced_past_the_window_never_reach_safe_mode(self):
        counter = self.root / 'count.txt'
        clock = FakeClock()
        dog = self.make([PY, '-c', COUNTED, str(counter)], [PY, '-c', 'pass'],
                        clock=clock, sleep=clock.sleep_past_window)
        dog.run()
        self.assertNotIn('safe', self.names())
        self.assertEqual(dog.total_crashes, 4)
        self.assertEqual(counter.read_text(), '5')

    def test_retry_request_leaves_safe_mode(self):
        healthy = self.root / 'healthy'
        normal = [PY, '-c', 'import pathlib, sys, time; '
                  'time.sleep(60) if pathlib.Path(sys.argv[1]).exists() else sys.exit(1)', str(healthy)]
        dog = self.make(normal, [PY, '-c', SLEEP_LONG])
        thread = threading.Thread(target=dog.run)
        thread.start()
        try:
            self.wait_for(lambda: ('safe',) in self.events)
            healthy.touch()
            (self.root / 'retry').touch()
            self.wait_for(lambda: self.names().count('spawn') >= 5 and self.events[-1][0] == 'spawn'
                          and self.events[-1][1] == 'normal')
        finally:
            dog.stop()
            thread.join(10)
        self.assertFalse(thread.is_alive())
        self.assertIn(('retry',), self.events)
        self.assertFalse((self.root / 'retry').exists())

    def test_stop_terminates_the_child(self):
        dog = self.make([PY, '-c', SLEEP_LONG], [PY, '-c', 'pass'])
        thread = threading.Thread(target=dog.run)
        thread.start()
        self.wait_for(lambda: 'spawn' in self.names())
        pid = dog.child.pid
        dog.stop()
        thread.join(10)
        self.assertFalse(thread.is_alive())
        self.assertIsNotNone(dog.child.poll())
        with self.assertRaises(ProcessLookupError):
            os.kill(pid, 0)

    def test_sigterm_stops_the_watchdog_and_its_child(self):
        state = self.root / 'state'
        proc = subprocess.Popen([PY, str(WATCHDOG), '--state-dir', str(state), '--retry-file',
                                 str(self.root / 'retry'), '--safe-entry', '/nonexistent', '--',
                                 PY, '-c', SLEEP_LONG], stderr=subprocess.DEVNULL)
        try:
            pid = self.wait_for_state(state)
            proc.send_signal(signal.SIGTERM)
            self.assertEqual(proc.wait(timeout=10), 0)
        finally:
            if proc.poll() is None:
                proc.kill()
                proc.wait()
        with self.assertRaises(ProcessLookupError):
            os.kill(pid, 0)
        self.assertFalse(json.loads((state / 'watchdog.json').read_text())['running'])

    def wait_for_state(self, state):
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            try:
                data = json.loads((state / 'watchdog.json').read_text())
            except (OSError, ValueError):
                data = {}
            if data.get('running') and data.get('pid'):
                return data['pid']
            time.sleep(0.05)
        self.fail('watchdog did not start its child')

    def wait_for(self, predicate, timeout=15):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if predicate():
                return
            time.sleep(0.05)
        self.fail('condition not reached; events: %r' % (self.events,))


if __name__ == '__main__':
    unittest.main()
