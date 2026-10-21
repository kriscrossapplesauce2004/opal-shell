import contextlib
import io
import os
import pathlib
import subprocess
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'src'))
import struct
import tempfile
from clipboard_service import ClipboardHistory, MAX_BYTES, MAX_IMAGES, MAX_ITEMS, MAX_PINS, capture, image_size, kind_of


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
        for number in range(MAX_ITEMS + 20):
            self.history.add(f'entry {number}')
        self.assertEqual(len(self.history.items), MAX_ITEMS)
        self.assertEqual(len(self.history._by_text), MAX_ITEMS)
        self.assertEqual(len(self.history._by_id), MAX_ITEMS)

    def test_large_ingest_keeps_indexes_bounded_and_exact(self):
        values = [
            f'generated {number % 211:03d} :: https://example.test/{number % 211}'
            if number % 4 == 0 else
            f'generated {number:06d}\nline {number % 19}'
            for number in range(10_000)
        ]
        for value in values:
            self.history.add(value)
        self.assertEqual(len(self.history.items), MAX_ITEMS)
        self.assertEqual(len(self.history._by_text), MAX_ITEMS)
        self.assertEqual(len(self.history._by_id), MAX_ITEMS)
        for entry in self.history.items:
            self.assertIs(self.history._by_text[entry['text']], entry)
            self.assertIs(self.history._by_id[entry['id']], entry)

        exact = '  generated exact\nline\t'
        self.assertTrue(self.history.add(exact))
        identity = self.history.items[0]['id']
        self.assertTrue(self.history.add(exact))
        self.assertEqual(self.history.items[0]['id'], identity)
        self.assertEqual(self.history.items[0]['text'], exact)

    def test_delete_and_clear_release_bounded_indexes(self):
        for number in range(MAX_ITEMS):
            self.history.add(f'entry {number}')
        removed = self.history.items[5]['id']
        self.history.delete(removed)
        self.assertNotIn(removed, self.history._by_id)
        self.assertEqual(len(self.history.items), len(self.history._by_id))
        self.assertEqual(len(self.history.items), len(self.history._by_text))
        self.history.clear()
        self.assertEqual(self.history.items, [])
        self.assertEqual(self.history._by_id, {})
        self.assertEqual(self.history._by_text, {})

    def test_published_items_are_snapshots(self):
        self.history.add('snapshot value')
        self.events[-1]['items'][0]['text'] = 'changed event only'
        self.assertEqual(self.history.items[0]['text'], 'snapshot value')

    def test_preserves_whitespace_but_rejects_binary_large_and_sensitive_data(self):
        self.assertTrue(self.history.add('  exact\ntext\t'))
        self.assertEqual(self.history.items[0]['text'], '  exact\ntext\t')
        for value in ('\0binary', 'x' * (MAX_BYTES + 1), '  \n\t', None):
            self.assertFalse(self.history.add(value))
        self.assertFalse(self.history.add('do not retain', sensitive=True))
        self.assertEqual(len(self.history.items), 1)

    def test_filtering_uses_encoded_size_and_keeps_unicode_exact(self):
        value = 'é' * (MAX_BYTES // 2)
        self.assertTrue(self.history.add(value))
        self.assertEqual(self.history.items[0]['text'], value)
        self.assertFalse(self.history.add(value + 'é'))
        self.assertFalse(self.history.add('x' * MAX_BYTES + 'é'))

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

    def test_kinds_for_icons_and_filters(self):
        cases = {'https://example.test/a': 'Link', 'me@example.test': 'Email', '#7c5cff': 'Color',
                 'rgb(1, 2, 3)': 'Color', 'hsl(250 100% 60%)': 'Color', '~/Pictures/a.png': 'Path',
                 '/etc/hosts': 'Path', '/shrug': 'Text', 'a\nb': 'Snippet', 'plain words': 'Text'}
        for text, kind in cases.items():
            self.assertEqual(kind_of(text), kind, text)
        self.history.add('https://www.example.test/page')
        self.assertEqual(self.history.items[0]['host'], 'example.test')

    def test_pins_survive_eviction_and_clear_and_keep_their_identity(self):
        self.history.add('keep me')
        identity = self.history.items[0]['id']
        self.assertTrue(self.history.pin(identity, True))
        for number in range(MAX_ITEMS + 10):
            self.history.add(f'entry {number}')
        self.assertIn(identity, self.history._by_id)
        self.assertEqual(len(self.history.items), MAX_ITEMS + 1)
        self.history.add('keep me')
        self.assertTrue(self.history.items[0]['pinned'])
        self.assertEqual(self.history.items[0]['id'], identity)
        self.history.clear()
        self.assertEqual([e['id'] for e in self.history.items], [identity])
        self.history.clear(pinned=True)
        self.assertEqual(self.history.items, [])

    def test_pin_limit(self):
        for number in range(MAX_PINS + 1):
            self.history.add(f'pin {number}')
            self.history.pin(self.history.items[0]['id'], True)
        self.assertEqual(sum(1 for e in self.history.items if e['pinned']), MAX_PINS)

    def test_source_is_recorded_and_kept_on_recopy(self):
        apps = iter(['kitty', 'firefox'])
        history = ClipboardHistory(self.events.append, source=lambda: next(apps))
        history.add('from the terminal')
        history.add('from the terminal')
        self.assertEqual(history.items[0]['source'], 'kitty')
        broken = ClipboardHistory(self.events.append, source=lambda: 1 / 0)
        self.assertTrue(broken.add('still captured'))
        self.assertEqual(broken.items[0]['source'], '')

    def test_published_items_hide_internal_keys(self):
        self.history.add('visible')
        self.assertNotIn('key', self.events[-1]['items'][0])

    def test_images_are_bounded_deduplicated_copied_and_removed(self):
        with tempfile.TemporaryDirectory() as folder:
            self.history.folder = folder
            paths = []
            for number in range(MAX_IMAGES + 2):
                path = os.path.join(folder, f'{number}.png')
                pathlib.Path(path).write_bytes(b'png %d' % number)
                paths.append(path)
                self.assertTrue(self.history.add_image(path, 'image/png', 5, f'hash{number}', 4, 3))
            images = [e for e in self.history.items if e['kind'] == 'Image']
            self.assertEqual(len(images), MAX_IMAGES)
            self.assertFalse(os.path.exists(paths[0]))
            self.assertEqual(images[0]['width'], 4)
            first = images[0]['id']
            self.assertTrue(self.history.add_image(paths[-1], 'image/png', 5, f'hash{MAX_IMAGES + 1}'))
            self.assertEqual(self.history.items[0]['id'], first)
            with patch('clipboard_service.shutil.which', return_value='/fake/wl-copy'), \
                 patch('clipboard_service.subprocess.run') as run:
                self.assertTrue(self.history.copy(first))
                self.assertEqual(run.call_args.args[0], ['wl-copy', '--type', 'image/png'])
                self.assertEqual(run.call_args.kwargs['input'], pathlib.Path(paths[-1]).read_bytes())
            self.history.delete(first)
            self.assertFalse(os.path.exists(paths[-1]))
            # A file outside the private folder is never registered.
            outside = tempfile.NamedTemporaryFile(suffix='.png', delete=False)
            outside.close()
            try:
                self.assertFalse(self.history.add_image(outside.name, 'image/png', 1, 'other'))
                self.assertFalse(self.history.add_image(paths[3], 'text/html', 1, 'html'))
            finally:
                os.unlink(outside.name)

    def test_image_size_headers(self):
        png = b'\x89PNG\r\n\x1a\n' + struct.pack('>I', 13) + b'IHDR' + struct.pack('>II', 640, 360)
        self.assertEqual(tuple(image_size(png)), (640, 360))
        self.assertEqual(tuple(image_size(b'GIF89a' + struct.pack('<HH', 12, 7))), (12, 7))
        jpeg = b'\xff\xd8\xff\xe0' + struct.pack('>H', 4) + b'JF' + b'\xff\xc0' + struct.pack('>HBHH', 17, 8, 90, 160) + b'\0' * 12
        self.assertEqual(tuple(image_size(jpeg)), (160, 90))
        self.assertEqual(tuple(image_size(b'not an image')), (0, 0))

    def test_copy_text_is_bounded_and_reported(self):
        with patch('clipboard_service.shutil.which', return_value='/fake/wl-copy'), \
             patch('clipboard_service.subprocess.run') as run:
            self.assertTrue(self.history.copy_text('one line'))
            self.assertEqual(run.call_args.kwargs['input'], b'one line')
            self.assertFalse(self.history.copy_text('x' * (MAX_BYTES + 1)))
            self.assertFalse(self.history.copy_text(''))
        self.assertEqual(self.events[-1], {'event': 'clipboardCopied', 'id': 'text', 'success': False})

    def test_image_offer_is_written_privately(self):
        png = b'\x89PNG\r\n\x1a\n' + struct.pack('>I', 13) + b'IHDR' + struct.pack('>II', 2, 3)
        with tempfile.TemporaryDirectory() as folder:
            stream = io.TextIOWrapper(io.BytesIO(b'ignored'))
            with patch.dict(os.environ, {'CLIPBOARD_STATE': 'data', 'OPAL_CLIPBOARD_DIR': folder}), \
                 patch.object(sys, 'stdin', stream), \
                 patch('clipboard_service.subprocess.check_output', return_value=b'text/html\nimage/png'), \
                 patch('clipboard_service.subprocess.run', return_value=subprocess.CompletedProcess([], 0, png)), \
                 contextlib.redirect_stdout(io.StringIO()) as output:
                capture()
            event = __import__('json').loads(output.getvalue())
            self.assertEqual((event['mime'], event['width'], event['height']), ('image/png', 2, 3))
            self.assertEqual(pathlib.Path(event['image']).read_bytes(), png)
            self.assertEqual(os.stat(event['image']).st_mode & 0o777, 0o600)


if __name__ == '__main__':
    unittest.main()
