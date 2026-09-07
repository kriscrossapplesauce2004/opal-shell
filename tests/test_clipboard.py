import contextlib
import io
import os
import pathlib
import subprocess
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
from clipboard_service import ClipboardHistory, MAX_BYTES, MAX_ITEMS, capture


class ClipboardTests(unittest.TestCase):
    def setUp(self):
        self.events = []
        self.history = ClipboardHistory(self.events.append)

    def test_dedupe_limit_and_stable_ids(self):
        self.history.add('first')
        identity = self.history.items[0]['id']
        self.history.add('second')
        self.history.add('first')
        self.assertEqual(self.history.items[0]['id'], identity)
        self.assertEqual(len(self.history.items), 2)
        for number in range(40):
            self.history.add(f'entry {number}')
        self.assertEqual(len(self.history.items), MAX_ITEMS)

    def test_preserves_whitespace_but_rejects_binary_large_and_sensitive_data(self):
        self.assertTrue(self.history.add('  exact\ntext\t'))
        self.assertEqual(self.history.items[0]['text'], '  exact\ntext\t')
        for value in ('\0binary', 'x' * (MAX_BYTES + 1), '  \n\t', None):
            self.assertFalse(self.history.add(value))
        self.assertFalse(self.history.add('do not retain', sensitive=True))
        self.assertEqual(len(self.history.items), 1)

    def test_pause_blocks_collection_clear_does_not_clear_system_clipboard(self):
        self.history.add('remember')
        self.history.set_paused(True)
        self.assertFalse(self.history.add('ignore'))
        with patch('clipboard_service.subprocess.run') as run:
            self.history.clear()
            run.assert_not_called()
        self.assertEqual(self.history.items, [])
        self.history.set_paused(False)
        self.assertTrue(self.history.add('resume'))

    def test_copy_uses_exact_text_and_stable_identity_never_shell_or_keystrokes(self):
        text = '  $(not-a-command)\n<plain text>\t'
        self.history.add(text)
        identity = self.history.items[0]['id']
        self.history.add('new item moved the indices')
        with patch('clipboard_service.shutil.which', return_value='/fake/wl-copy'), \
             patch('clipboard_service.subprocess.run') as run:
            self.assertTrue(self.history.copy(identity))
            self.assertEqual(run.call_args.args[0], ['wl-copy', '--type', 'text/plain;charset=utf-8'])
            self.assertEqual(run.call_args.kwargs['input'], text.encode())
            self.assertNotIn('shell', run.call_args.kwargs)
        self.history.delete(identity)
        with patch('clipboard_service.subprocess.run') as run:
            self.assertFalse(self.history.copy(identity))
            run.assert_not_called()

    def test_copy_failure_is_reported_not_claimed_success(self):
        self.history.add('fixture')
        with patch('clipboard_service.shutil.which', return_value='/fake/wl-copy'), \
             patch('clipboard_service.subprocess.run', side_effect=subprocess.TimeoutExpired('wl-copy', 2)):
            self.assertFalse(self.history.copy(self.history.items[0]['id']))
        self.assertFalse(self.events[-1]['success'])

    def test_sensitive_offer_is_not_even_read(self):
        with patch.dict(os.environ, {'CLIPBOARD_STATE':'sensitive'}), \
             patch('clipboard_service.subprocess.check_output') as metadata:
            capture()
            metadata.assert_not_called()
        stream = io.TextIOWrapper(io.BytesIO(b'sensitive fixture'))
        with patch.dict(os.environ, {'CLIPBOARD_STATE':'data'}), \
             patch.object(sys, 'stdin', stream), \
             patch('clipboard_service.subprocess.check_output', return_value=b'text/plain\nx-kde-passwordManagerHint'), \
             contextlib.redirect_stdout(io.StringIO()) as output:
            capture()
            self.assertEqual(stream.buffer.tell(), 0)
            self.assertEqual(output.getvalue(), '')

    def test_no_wayland_no_clipboard_access(self):
        with patch.dict(os.environ, {}, clear=True), \
             patch('clipboard_service.subprocess.Popen') as popen:
            self.history.watch()
            popen.assert_not_called()
        self.assertFalse(self.history.available)


if __name__ == '__main__':
    unittest.main()
