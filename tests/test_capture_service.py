import pathlib, sys, tempfile, unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'src'))
import capture_service


class FakeResult:
    def __init__(self, returncode=0, stdout='', stderr=''):
        self.returncode = returncode
        self.stdout = stdout
        self.stderr = stderr


class FakeProcess:
    def __init__(self):
        self.signals = []
        self.terminated = False
        self.alive = True

    def poll(self):
        return None if self.alive else 0

    def send_signal(self, sig):
        self.signals.append(sig)
        self.alive = False

    def wait(self, timeout=None):
        return 0

    def terminate(self):
        self.terminated = True
        self.alive = False


class FakeActions:
    def clients(self):
        return [{'address': '0xabc', 'at': [120, 80], 'size': [900, 600], 'focusHistoryID': 0}]


class CaptureServiceTests(unittest.TestCase):
    def test_region_screenshot_and_ocr(self):
        events = []
        calls = []
        with tempfile.TemporaryDirectory() as tmp:
            def fake_run(cmd, **kw):
                calls.append(cmd)
                if cmd[0] == 'grim':
                    pathlib.Path(cmd[-1]).write_bytes(b'\x89PNG\r\n')
                    return FakeResult(0)
                if cmd[0] == 'tesseract':
                    return FakeResult(0, stdout='Hello from OCR\n')
                return FakeResult(0)

            svc = capture_service.CaptureService(
                events.append,
                run=fake_run,
                which=lambda b: '/usr/bin/' + b,
                home=tmp,
                actions=FakeActions(),
                sleep=lambda _: None,
            )
            path = svc.screenshot(mode='region', geometry='10,20 300x200', ocr=True)
            self.assertIsNotNone(path)
            self.assertIn(['-g', '10,20 300x200'], [calls[0][1:3]])
            done = next(e for e in events if e.get('event') == 'captureDone')
            self.assertEqual(done['ocr'], 'Hello from OCR')
            self.assertTrue(svc.delete_capture(path))
            self.assertFalse(pathlib.Path(path).exists())

    def test_window_screenshot_resolves_geometry(self):
        events = []
        calls = []
        with tempfile.TemporaryDirectory() as tmp:
            def fake_run(cmd, **kw):
                calls.append(cmd)
                if cmd[0] == 'grim':
                    pathlib.Path(cmd[-1]).write_bytes(b'\x89PNG\r\n')
                return FakeResult(0)

            svc = capture_service.CaptureService(
                events.append,
                run=fake_run,
                which=lambda b: '/usr/bin/' + b,
                home=tmp,
                actions=FakeActions(),
                sleep=lambda _: None,
            )
            svc.screenshot(mode='window', address='0xabc')
            self.assertEqual(calls[0][:3], ['grim', '-g', '120,80 900x600'])

    def test_screen_recording_lifecycle_emits_live_activity(self):
        events = []
        proc = FakeProcess()
        with tempfile.TemporaryDirectory() as tmp:
            svc = capture_service.CaptureService(
                events.append,
                popen=lambda cmd, **kw: proc,
                which=lambda b: '/usr/bin/' + b if b == 'wf-recorder' else None,
                home=tmp,
                sleep=lambda _: None,
            )
            self.assertTrue(svc.start_recording(output='DP-1', audio=True))
            self.assertTrue(svc.recording_active())
            self.assertTrue(any(e.get('event') == 'activity' and e.get('data', {}).get('id') == 'screen-recording' for e in events))
            self.assertTrue(svc.stop_recording())
            self.assertFalse(svc.recording_active())


if __name__ == '__main__':
    unittest.main()
