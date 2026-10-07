import pathlib
import shutil
import subprocess
import unittest

SOURCE = pathlib.Path(__file__).resolve().parents[1] / 'src' / 'ActivityModel.js'


def run_js(body):
    script = r'''
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const m = {};
vm.createContext(m);
vm.runInContext(fs.readFileSync(process.argv[1], 'utf8').replace(/^\.pragma library\s*/, ''), m);
const eq = (a, b) => assert.equal(JSON.stringify(a), JSON.stringify(b));
''' + body
    return subprocess.run(['node', '-e', script, str(SOURCE)], capture_output=True, text=True, timeout=30)


@unittest.skipUnless(shutil.which('node'), 'Node is required for the pure JavaScript activity tests')
class ActivityModelTests(unittest.TestCase):
    def check(self, body):
        result = run_js(body)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_notification_progress_and_replacement(self):
        self.check(r'''
const n = (extra) => Object.assign({id: 7, appName: 'Files', summary: 'Copying', body: 'photos.zip', received: 1000, hints: {value: 42}}, extra);
const a = m.fromNotification(n(), 2000);
assert.equal(a.kind, 'transfer'); assert.equal(a.progress, 0.42); assert.equal(a.id, 'n:7');
assert.equal(m.fromNotification(n({hints: {value: 250}}), 2000).progress, 1);
assert.equal(m.fromNotification(n({hints: {value: 'x'}}), 2000), null);
assert.equal(m.fromNotification(n({hints: {}}), 2000), null);
assert.equal(m.fromNotification(n({hints: {category: 'transfer'}}), 2000).progress, -1);
assert.equal(m.fromNotification(n({hints: {category: 'transfer.complete', value: 100}}), 2000), null);
assert.equal(m.fromNotification(n({hints: {category: 'transfer', value: 10}, transient: true}), 2000).kind, 'transfer');
assert.equal(m.fromNotification(n({hints: {category: 'transfer'}, transient: true}), 2000), null);
assert.equal(m.fromNotification(n({hints: {category: 'call.ongoing'}, resident: true}), 2000).kind, 'call');
assert.equal(m.fromNotification({id: 1, summary: 'Hi', hints: {}}, 5), null);
const first = m.merge([], [a], 2000);
const updated = m.merge(first, [Object.assign({}, a, {progress: 0.8, since: 9000})], 2500);
assert.equal(updated.length, 1); assert.equal(updated[0].progress, 0.8); assert.equal(updated[0].since, 1000);
''')

    def test_finished_transfer_expires_and_stays_gone(self):
        self.check(r'''
const note = {id: 3, appName: 'Files', summary: 'Done', received: 1000, hints: {value: 100}};
const a = m.fromNotification(note, 1100);
assert.ok(a.until > 1000);
assert.equal(m.merge([], [a], 1100).length, 1);
const later = m.fromNotification(note, a.until + 5);
assert.equal(m.merge([], [later], a.until + 5).length, 0);
''')

    def test_ranking_cap_and_summary(self):
        self.check(r'''
const base = {media: {track: 'Song', artist: 'Band', playing: true}, focus: {running: true, seconds: 600, total: 1500}, notifications: [
  {id: 1, appName: 'Files', summary: 'Copy', received: 5, hints: {value: 10}},
  {id: 2, appName: 'Phone', summary: 'Call', received: 6, resident: true, hints: {category: 'call.ongoing'}}]};
const list = m.merge([], m.fromSignals(base, 10000), 10000);
eq(list.map(a => a.kind), ['call', 'transfer', 'focus', 'media']);
const s = m.summary(list);
assert.equal(s.extra, 3); assert.equal(s.primary.kind, 'call'); assert.match(s.label, /plus 3 more/);
assert.equal(m.summary([]).primary, null);
const many = []; for (let i = 0; i < 20; i++) many.push({id: 'x' + i, kind: 'transfer', priority: 70, since: i, until: 0});
assert.equal(m.merge([], many, 0).length, m.MAX_ACTIVITIES);
assert.equal(m.merge([], many, 0)[0].id, 'x19');
const paused = m.fromSignals({media: {track: 'Song', playing: false}}, 1)[0];
assert.ok(paused.priority < 50);
assert.equal(m.fromSignals({media: {track: ''}, focus: {running: false, seconds: 5}}, 1).length, 0);
''')

    def test_charging_and_connectivity_are_brief(self):
        self.check(r'''
const plug = (percent, changedAt) => ({battery: {percent, charging: true, changedAt}});
assert.equal(m.fromSignals(plug(60, 1000), 2000).length, 1);
assert.equal(m.fromSignals(plug(60, 1000), 1000 + m.CHARGE_SHOW_MS + 1).length, 0);
assert.equal(m.fromSignals(plug(10, 1000), 999999).length, 1);
assert.equal(m.fromSignals({battery: {percent: 10, charging: false}}, 5).length, 0);
const net = (wifi, changedAt) => ({network: {wifi, name: 'Home', changedAt}});
assert.equal(m.fromSignals(net(false, 100), 200)[0].title, 'Offline');
assert.equal(m.fromSignals(net(true, 100), 100 + m.LINK_SHOW_MS + 1).length, 0);
assert.equal(m.fromSignals(net(true, 0), 200).length, 0);
const rec = m.fromSignals({recording: true}, 5);
assert.equal(rec[0].kind, 'recording');
''')

    def test_find_codes(self):
        self.check(r'''
eq(m.findCodes('Your verification code is 482913. Do not share.'), ['482913']);
eq(m.findCodes('G-123456 is your Google code'), ['123456']);
eq(m.findCodes('Code: 123 456'), ['123456']);
eq(m.findCodes('1234'), ['1234']);
eq(m.findCodes('Your code 12345678'), ['12345678']);
eq(m.findCodes('Your code 123456789'), []);
eq(m.findCodes('Your code 123'), []);
eq(m.findCodes('Meet at 10:30 or pay 1234.56'), []);
eq(m.findCodes('See you in 2026 at the big long lunch place downtown near the river ok'), []);
eq(m.findCodes('Your login code for 2026 is 998877'), ['998877']);
eq(m.findCodes('Order 2024-11-03 shipped'), []);
eq(m.findCodes(null), []);
''')

    def test_suggestions(self):
        self.check(r'''
const sig = {dnd: false, dock: {name: 'HDMI-A-1'}, codes: [{id: 4, app: 'Bank', body: 'Your code is 554433'}],
  sessions: [{device: 'abc', deviceName: 'Phone', app: 'firefox', appName: 'Firefox'}], battery: {percent: 12, charging: false, saver: false, canSave: true}};
let chips = m.suggestions(sig, []);
eq(chips.map(c => c.kind), ['code', 'dock', 'saver']);
assert.equal(chips[0].arg, '554433');
assert.equal(m.suggestions(Object.assign({}, sig, {dnd: true}), []).length, 0);
chips = m.suggestions(Object.assign({}, sig, {battery: {percent: 50}}), [chips[0].id]);
eq(chips.map(c => c.kind), ['dock', 'continue']);
assert.equal(m.suggestions(Object.assign({}, sig, {dock: {name: 'X', handled: true}, codes: [], battery: {percent: 90}}), [])[0].label, 'Continue Firefox');
assert.equal(m.suggestions({battery: {percent: 5, charging: true, canSave: true}}, []).length, 0);
assert.equal(m.suggestions({battery: {percent: 5, saver: true, canSave: true}}, []).length, 0);
assert.equal(m.suggestions(null, []).length, 0);
''')


if __name__ == '__main__':
    unittest.main()
