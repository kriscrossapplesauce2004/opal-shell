import pathlib
import shutil
import subprocess
import unittest


@unittest.skipUnless(shutil.which('node'), 'Node is required for the pure JavaScript search tests')
class StartSearchTests(unittest.TestCase):
    def test_ranking_scopes_unicode_and_bounded_results(self):
        source = pathlib.Path(__file__).resolve().parents[1] / 'src' / 'StartSearch.js'
        script = r'''
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const context = {};
vm.createContext(context);
vm.runInContext(fs.readFileSync(process.argv[1], 'utf8').replace(/^\.pragma library\s*/, ''), context);
const apps = [
    {app:{id:'firefox',name:'Firefox',genericName:'Web browser'},hay:'firefox web browser internet'},
    {app:{id:'other',name:'Firefox Developer Edition'},hay:'firefox developer web browser'},
    {app:{id:'code',name:'Visual Studio Code'},hay:'visual studio code editor development'},
    {app:{id:'cafe',name:'Café'},hay:'café work notes'}
];
const windows = [{title:'Browser notes',className:'Firefox',address:'one',workspace:2}];
const actions = [{id:'network',name:'Wi-Fi settings',detail:'Network',keywords:'internet wireless',icon:'wifi'}];
const search = (query, scope='all', pins=[]) => context.search(query,scope,apps,windows,actions,pins,[]);
assert.equal(search('firefox')[0].data.id,'firefox');
assert.equal(search('firefx')[0].data.id,'firefox');
assert.equal(search('cafe')[0].data.id,'cafe');
assert.equal(search('vsc')[0].data.id,'code');
assert.equal(search('visual editor')[0].data.id,'code');
assert.equal(search('firefox nonsense').length,0);
assert.equal(search('@ browser')[0].kind,'window');
assert.ok(search('>', 'all').every(row=>row.kind==='action'));
assert.equal(search('wireless')[0].data.id,'network');
assert.equal(search('firefox','action').length,0);
assert.equal(search('firefox','all',['other'])[0].data.id,'firefox');
assert.equal(search('zzzzzzzz').length,0);
assert.ok(search('? private query').every(row=>row.kind!=='web'));
const many=Array.from({length:200},(_,i)=>({app:{id:String(i),name:'App '+i},hay:'app'}));
assert.equal(context.search('app','all',many,[],[],[],[]).length,60);
assert.equal(context.oneEdit('firefox','firefx'),true);
assert.equal(context.oneEdit('firefox','firexxz'),false);
assert.equal(search('firefox').map(x=>x.key).join(),search('firefox').map(x=>x.key).join());
'''
        subprocess.run(['node', '-e', script, str(source)], check=True, capture_output=True, text=True)


if __name__ == '__main__':
    unittest.main()
