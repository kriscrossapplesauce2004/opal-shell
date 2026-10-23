import json, pathlib, sys, tempfile, unittest
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'src'))
import ai_features


class Result:
    def __init__(self, code):
        self.returncode = code


class AiFeaturesTest(unittest.TestCase):
    def test_preference(self):
        self.assertTrue(ai_features.valid_preference('aiFeatures', False))
        self.assertFalse(ai_features.valid_preference('aiFeatures', 'no'))
        self.assertFalse(ai_features.valid_preference('other', False))
        self.assertTrue(ai_features.enabled({}))
        self.assertFalse(ai_features.enabled({'aiFeatures': False}))

    def test_scrub_removes_ai_entries(self):
        prefs = {
            'consoleWidgets': ['music', 'claude'],
            'phoneGestures': {'left': 'back', 'bottomHold': 'assistant'},
            'powerMenu': [{'action': 'lock'}, {'action': 'assistant'}, {'action': 'folder', 'label': 'More', 'items': [{'action': 'assistant'}, {'action': 'search'}]}],
            'powerMenuStart': 'assistant',
            'powerPress': {'double': {'action': 'assistant'}, 'hold': {'action': 'power'}},
        }
        out = ai_features.scrub(prefs)
        self.assertEqual(out['consoleWidgets'], ['music'])
        self.assertEqual(out['phoneGestures'], {'left': 'back', 'bottomHold': 'none'})
        self.assertEqual(out['powerMenu'], [{'action': 'lock'}, {'action': 'folder', 'label': 'More', 'items': [{'action': 'search'}]}])
        self.assertEqual(out['powerMenuStart'], 'sleep')
        self.assertEqual(out['powerPress'], {'double': None, 'hold': {'action': 'power'}})
        self.assertEqual(ai_features.scrub({'consoleWidgets': ['music']}), {})

    def test_disconnect_removes_mcp_and_hooks(self):
        calls = []
        def run(args, **kw):
            calls.append(args)
            return Result(0)
        with tempfile.TemporaryDirectory() as home:
            settings = pathlib.Path(home) / '.claude/settings.json'
            settings.parent.mkdir()
            settings.write_text(json.dumps({'hooks': {'Stop': [{'hooks': [{'command': 'opal activity claude-hook'}]}]}}))
            removed = []
            done = ai_features.disconnect(run=run, which=lambda n: '/usr/bin/' + n, home=home, remove_hooks=removed.append)
        self.assertEqual(done, ['mcp', 'hooks'])
        self.assertIn(['claude', 'mcp', 'remove', '--scope', 'user', 'opal'], calls)
        self.assertEqual(removed, [settings])

    def test_disconnect_without_claude(self):
        with tempfile.TemporaryDirectory() as home:
            self.assertEqual(ai_features.disconnect(run=lambda *a, **k: Result(1), which=lambda n: None, home=home), [])
            self.assertFalse(ai_features.connect('/x/opal_mcp.py', which=lambda n: None))


if __name__ == '__main__':
    unittest.main()
