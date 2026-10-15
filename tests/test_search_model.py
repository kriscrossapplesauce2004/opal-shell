import pathlib, shutil, subprocess, unittest

SRC = pathlib.Path(__file__).resolve().parents[1] / 'src'


def run_js(body):
    script = r'''
const assert = require('node:assert/strict');
const fs = require('node:fs'); const vm = require('node:vm');
const strip = t => t.replace(/^\.pragma library\s*/m, '').replace(/^\.import .*$/m, '');
const ctx = {}; vm.createContext(ctx);
vm.runInContext(strip(fs.readFileSync(process.argv[1], 'utf8')), ctx);
const Rank = {score: ctx.score}; const m = {Rank}; vm.createContext(m);
vm.runInContext(strip(fs.readFileSync(process.argv[2], 'utf8')), m);
''' + body
    return subprocess.run(['node', '-e', script, str(SRC / 'StartSearch.js'), str(SRC / 'SearchModel.js')], capture_output=True, text=True, timeout=30)


@unittest.skipUnless(shutil.which('node'), 'Node is required')
class SearchModelTests(unittest.TestCase):
    def check(self, body):
        result = run_js(body)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_question_heuristic(self):
        self.check(r'''
assert.ok(m.isQuestion('how do i make window gaps smaller'));
assert.ok(m.isQuestion('gaps too big?'));
assert.ok(m.isQuestion('explain what pacman -Syu does'));
assert.ok(!m.isQuestion('firefox'));
assert.ok(!m.isQuestion('dark'));
assert.ok(!m.isQuestion('how'));
assert.ok(!m.isQuestion('what?'));
assert.ok(!m.isQuestion('is it'));
''')

    def test_conversions(self):
        self.check(r'''
assert.equal(m.convert('5 km to mi').text, '3.107 mi');
assert.equal(m.convert('100 f in c').text, '37.778 °C');
assert.equal(m.convert('0 c to k').text, '273.15 °K');
assert.equal(m.convert('2 gib to mb').text, '2147.484 mb');
assert.equal(m.convert('90 min to h').text, '1.5 h');
assert.equal(m.convert('1,5 kg to lb').text, '3.307 lb');
assert.equal(m.convert('5 km to kg'), null);
assert.equal(m.convert('firefox'), null);
assert.equal(m.convert('5 parsecs to mi'), null);
''')

    def test_settings_and_sections(self):
        self.check(r'''
const index = [{id: 'light', title: 'Dark theme', path: 'Settings › Appearance', keywords: 'night mode colors'},
  {id: 'motion', title: 'Reduced motion', path: 'Settings › Accessibility', keywords: 'animations'},
  {id: 'dnd', title: 'Do not disturb', path: 'Quick settings', keywords: 'quiet notifications silence'}];
const r = m.settings('dark', index);
assert.equal(r[0].id, 'light'); assert.equal(r.length, 1);
assert.equal(m.settings('animations', index)[0].id, 'motion');
assert.equal(m.settings('quiet', index)[0].id, 'dnd');
const out = m.sections({app: [{key: 'a1', title: 'Darktable', score: 1000}, {key: 'a2', title: 'D', score: 300}], setting: r.map(x => Object.assign({key: 's:' + x.id}, x)), file: [{key: 'f', title: 'dark.png', score: 900}]}, 3);
assert.equal(out.best.key, 'a1');
assert.equal(JSON.stringify(out.sections.map(s => s.id)), JSON.stringify(['app', 'setting', 'file']));
assert.equal(out.sections[0].items.length, 1);
const none = m.sections({app: [{key: 'x', title: 'X', score: 100}]});
assert.equal(none.best, null);
''')


if __name__ == '__main__':
    unittest.main()
