import contextlib
import importlib.util
import io
import pathlib
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
_spec = importlib.util.spec_from_file_location('feel_lint', ROOT / 'tools' / 'feel-lint.py')
feel_lint = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(feel_lint)


def counts(source):
    return feel_lint.count_file(source)


def zero(**values):
    result = {key: 0 for key in feel_lint.RULE_KEYS}
    result.update(values)
    return result


class ParserTests(unittest.TestCase):
    def test_async_in_child_does_not_count_for_loader(self):
        source = 'Loader {\n    sourceComponent: Item {\n        asynchronous: true\n    }\n}\n'
        result = counts(source)
        self.assertEqual(result['loaders'], 1)
        self.assertEqual(result['sync_loader'], 1)

    def test_async_on_loader_counts_as_async(self):
        result = counts('Loader { asynchronous: true; source: "A.qml" }\nLoader { }\n')
        self.assertEqual(result['loaders'], 2)
        self.assertEqual(result['sync_loader'], 1)

    def test_commented_and_quoted_canvas_do_not_count(self):
        source = '// Canvas { }\n/* Canvas {\n} */\nText { text: "Canvas {" }\n'
        self.assertEqual(counts(source)['canvas'], 0)

    def test_real_canvas_counts(self):
        self.assertEqual(counts('Item {\n    Canvas { }\n}\n')['canvas'], 1)

    def test_repeater_models(self):
        cases = {
            'Repeater { model: 3 }': 0,
            'Repeater { model: 0 }': 0,
            'Repeater { model: ["a", "b"] }': 0,
            'Repeater {\n    model: [\n        {v: 1},\n        {v: 2}\n    ]\n}': 0,
            'Repeater { model: 3; Item {} }': 0,
            'Repeater { model: Hub.status.windows }': 1,
            'Repeater { model: "abc" }': 1,
            'Repeater { model: root.steps\n    delegate: Item {} }': 1,
            'Repeater { model: [1].concat(root.extra) }': 1,
            'Repeater { delegate: Item {} }': 0,
        }
        for source, expected in cases.items():
            with self.subTest(source=source):
                self.assertEqual(counts(source)['dynamic_repeater'], expected)

    def test_child_model_does_not_change_repeater(self):
        self.assertEqual(counts('Repeater { model: 3; Item { model: root.things } }')['dynamic_repeater'], 0)

    def test_json_calls_ignore_comments_and_strings(self):
        source = '// JSON.parse(x)\nfunction f() { return JSON.parse(a) + JSON.stringify(b) + "JSON.parse(" }\n'
        result = counts(source)
        self.assertEqual(result['json_parse'], 1)
        self.assertEqual(result['json_stringify'], 1)

    def test_animation_and_list_kinds(self):
        source = (
            'Item {\n'
            '    Behavior on x { NumberAnimation { duration: 1 } }\n'
            '    Behavior { }\n'
            '    OpacityAnimator { }\n'
            '    SpringAnimation { }\n'
            '    Timer { }\n'
            '    MultiEffect { }\n'
            '    ListView { }\n'
            '    GridView { }\n'
            '    ListModel { }\n'
            '    onClicked: { x = 1 }\n'
            '}\n'
        )
        result = counts(source)
        self.assertEqual(result['behaviors'], 2)
        self.assertEqual(result['number_animations'], 1)
        self.assertEqual(result['animators'], 1)
        self.assertEqual(result['spring_animations'], 1)
        self.assertEqual(result['timers'], 1)
        self.assertEqual(result['multi_effects'], 1)
        self.assertEqual(result['list_views'], 2)
        self.assertEqual(result['list_models'], 1)


class RatchetTests(unittest.TestCase):
    def baseline(self, **extra):
        data = {'files': {'src/A.qml': {'canvas': 1, 'sync_loader': 0, 'dynamic_repeater': 0}}, 'allowlist': []}
        data.update(extra)
        return data

    def test_increase_fails(self):
        violations, _ = feel_lint.check({'src/A.qml': zero(canvas=2)}, self.baseline())
        self.assertEqual(len(violations), 1)
        self.assertIn('src/A.qml canvas', violations[0])

    def test_new_file_with_bad_count_fails(self):
        violations, _ = feel_lint.check({'src/B.qml': zero(sync_loader=1)}, self.baseline())
        self.assertEqual(len(violations), 1)
        self.assertIn('src/B.qml sync_loader', violations[0])
        self.assertIn('new file', violations[0])

    def test_decrease_passes_with_note(self):
        violations, notes = feel_lint.check({'src/A.qml': zero(canvas=0)}, self.baseline())
        self.assertEqual(violations, [])
        self.assertTrue(any('src/A.qml canvas' in note for note in notes))

    def test_allowlist_max_is_the_limit(self):
        allow = [{'file': 'src/A.qml', 'rule': 'canvas', 'max': 2, 'reason': 'Test.'}]
        ok, _ = feel_lint.check({'src/A.qml': zero(canvas=2)}, self.baseline(allowlist=allow))
        self.assertEqual(ok, [])
        bad, _ = feel_lint.check({'src/A.qml': zero(canvas=3)}, self.baseline(allowlist=allow))
        self.assertEqual(len(bad), 1)

    def test_update_then_check_round_trip(self):
        with tempfile.TemporaryDirectory() as tmp:
            baseline = pathlib.Path(tmp) / 'baseline.json'
            args = ['--root', str(ROOT), '--baseline', str(baseline)]
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(feel_lint.main(args + ['--update-baseline']), 0)
                self.assertEqual(feel_lint.main(args + ['--check']), 0)


class RepoTests(unittest.TestCase):
    def test_src_does_not_exceed_baseline(self):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = feel_lint.main(['--check'])
        self.assertEqual(code, 0, out.getvalue())


if __name__ == '__main__':
    unittest.main()
