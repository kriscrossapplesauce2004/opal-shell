import json
import pathlib
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'src'))
from state_journal import Journal, default_path


class JournalTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.path = pathlib.Path(self.temp.name) / 'opal' / 'journal.jsonl'

    def tearDown(self):
        self.temp.cleanup()

    def test_replay_returns_the_latest_value_per_kind(self):
        journal = Journal(self.path)
        journal.record('panel', 'launcher')
        journal.record('space', 2)
        journal.record('panel', 'shade')
        journal.record('toasts', ['saved'])
        self.assertEqual(journal.replay(), {'panel': 'shade', 'space': 2, 'toasts': ['saved']})

    def test_state_survives_reopen_and_open_compacts_the_file(self):
        journal = Journal(self.path)
        for number in range(20):
            journal.record('layout', f'mode-{number}')
        journal.record('space', 4)
        reopened = Journal(self.path)
        self.assertEqual(reopened.replay(), {'layout': 'mode-19', 'space': 4})
        lines = self.path.read_text().splitlines()
        self.assertEqual(len(lines), 2)
        self.assertEqual(json.loads(lines[0]), {'kind': 'layout', 'data': 'mode-19'})

    def test_size_stays_bounded_under_many_records(self):
        journal = Journal(self.path, max_bytes=1024)
        for number in range(500):
            journal.record('toasts', {'n': number, 'text': 'x' * 40})
        self.assertLessEqual(self.path.stat().st_size, 1024)
        self.assertEqual(journal.replay()['toasts']['n'], 499)

    def test_torn_or_foreign_lines_are_skipped(self):
        journal = Journal(self.path)
        journal.record('space', 1)
        with open(self.path, 'a', encoding='utf-8') as handle:
            handle.write('{"kind":"panel","da')
            handle.write('\nnot json\n')
            handle.write('{"other":true}\n')
        self.assertEqual(journal.replay(), {'space': 1})

    def test_missing_file_replays_empty(self):
        self.assertEqual(Journal(self.path).replay(), {})

    def test_invalid_records_are_rejected(self):
        journal = Journal(self.path)
        with self.assertRaises(ValueError):
            journal.record('', 1)
        with self.assertRaises(TypeError):
            journal.record('space', object())
        with self.assertRaises(ValueError):
            journal.record('toasts', 'x' * 20000)

    def test_default_path_uses_runtime_dir(self):
        with patch.dict('os.environ', {'XDG_RUNTIME_DIR': '/run/user/test'}):
            self.assertEqual(default_path(), pathlib.Path('/run/user/test/opal/journal.jsonl'))


if __name__ == '__main__':
    unittest.main()
