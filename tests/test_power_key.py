import json
import pathlib
import subprocess
import sys
import tempfile
import unittest
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'src'))
import power_key
from power_key import PowerKey, valid_preference, parse_vcards, load_contacts, layout


class FakeHypr:
    def is_lua(self): return True


class Result:
    def __init__(self, stdout='', returncode=0): self.stdout, self.returncode = stdout, returncode


class FakeProcess:
    def __init__(self): self.alive, self.signals = True, []
    def poll(self): return None if self.alive else 0
    def terminate(self): self.alive = False
    def send_signal(self, sig): self.signals.append(sig); self.alive = False


def service(prefs=None, monitors=None, now=100.0):
    events, calls, spawned = [], [], []
    def runner(args, **kw):
        calls.append(args)
        if args[:2] == ['hyprctl', 'monitors']: return Result(json.dumps(monitors or [{'name': 'DSI-1', 'dpmsStatus': True}]))
        return Result('')
    def popen(args, **kw):
        spawned.append(args)
        return FakeProcess()
    clock = [now]
    key = PowerKey(events.append, prefs if prefs is not None else {'powerKey': 'on'}, FakeHypr(), runner=runner, popen=popen, clock=lambda: clock[0])
    return key, events, calls, spawned, clock


class Preferences(unittest.TestCase):
    def test_menu_tree(self):
        self.assertTrue(valid_preference('powerMenu', [{'action': 'sleep'}, {'action': 'folder', 'label': 'Toggles', 'items': [{'action': 'dnd'}]}]))
        self.assertTrue(valid_preference('powerMenu', [{'action': 'command', 'command': 'notify-send hi', 'label': 'Hi'}]))
        self.assertFalse(valid_preference('powerMenu', [{'action': 'rm-rf'}]))
        self.assertFalse(valid_preference('powerMenu', [{'action': 'command'}]))
        self.assertFalse(valid_preference('powerMenu', [{'action': 'link', 'url': 'javascript:alert(1)'}]))
        self.assertFalse(valid_preference('powerMenu', [{'action': 'folder', 'items': []}]), 'a folder needs a label')
        deep = {'action': 'folder', 'label': 'a', 'items': []}
        node = deep
        for _ in range(5):
            child = {'action': 'folder', 'label': 'a', 'items': []}
            node['items'].append(child); node = child
        self.assertFalse(valid_preference('powerMenu', [deep]))

    def test_other_keys(self):
        self.assertTrue(valid_preference('powerMenuCountdown', 2000))
        self.assertFalse(valid_preference('powerMenuCountdown', 2500))
        self.assertTrue(valid_preference('powerPress', {'double': {'action': 'flashlight'}, 'hold': None}))
        self.assertFalse(valid_preference('powerPress', {'triple': {'action': 'flashlight'}}))
        self.assertTrue(valid_preference('powerKey', 'auto'))
        self.assertFalse(valid_preference('powerKey', 'yes'))
        self.assertTrue(valid_preference('powerKeyLayout', {'power': {'edge': 'right', 'at': .3}, 'volume': {'edge': 'left', 'at': .2}}))
        self.assertFalse(valid_preference('powerKeyLayout', {'power': {'edge': 'top', 'at': .3}, 'volume': {'edge': 'left', 'at': .2}}))
        self.assertFalse(valid_preference('somethingElse', 1))


class Layouts(unittest.TestCase):
    def test_known_device_and_override(self):
        self.assertEqual(layout({}, ['oneplus,guacamoleb', 'qcom,sm8150'])['volume']['edge'], 'left')
        self.assertEqual(layout({}, ['acme,unknown']), power_key.GENERIC_LAYOUT)
        custom = {'power': {'edge': 'left', 'at': .5}, 'volume': {'edge': 'left', 'at': .2}}
        self.assertEqual(layout({'powerKeyLayout': custom}, ['oneplus,guacamoleb']), custom)


class Contacts(unittest.TestCase):
    CARD = 'BEGIN:VCARD\r\nVERSION:3.0\r\nUID:abc\r\nFN:Ada Lovelace\r\nTEL;TYPE=cell:+44 20 7946\r\n 0000\r\nEMAIL:ada@example.org\r\nCATEGORIES:Friends,Favorites\r\nEND:VCARD\r\n'

    def test_parse_folded_card(self):
        card = parse_vcards(self.CARD, 'x.vcf')[0]
        self.assertEqual((card['uid'], card['name'], card['phones'], card['emails'], card['favourite']),
                         ('abc', 'Ada Lovelace', ['+44 20 79460000'], ['ada@example.org'], True))

    def test_name_from_n_and_generated_uid(self):
        card = parse_vcards('BEGIN:VCARD\nN:Hopper;Grace;;;\nEND:VCARD\n', 'g.vcf')[0]
        self.assertEqual(card['name'], 'Grace Hopper')
        self.assertTrue(card['uid'])

    def test_load_vdir_without_duplicates(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = pathlib.Path(tmp)
            folder = home / '.local/share/contacts/default'; folder.mkdir(parents=True)
            (folder / 'a.vcf').write_text(self.CARD)
            (folder / 'b.vcf').write_text(self.CARD)
            (folder / 'c.vcf').write_text('BEGIN:VCARD\nUID:z\nFN:Alan Turing\nEND:VCARD\n')
            self.assertEqual([c['name'] for c in load_contacts(home)], ['Ada Lovelace', 'Alan Turing'])


class Keys(unittest.TestCase):
    def test_tap_reaches_the_shell(self):
        key, events, *_ = service()
        key.edge(True); key.edge(False)
        self.assertEqual(events, [{'event': 'powerKey', 'down': True}, {'event': 'powerKey', 'down': False}])

    def test_wake_press_is_swallowed_with_its_release(self):
        key, events, calls, *_ = service(monitors=[{'name': 'DSI-1', 'dpmsStatus': False}])
        key.edge(True); key.edge(False)
        self.assertEqual(events, [])
        self.assertIn(['hyprctl', 'eval', 'hl.dispatch(hl.dsp.dpms({action="on"}))'], calls)

    def test_press_right_after_resume_is_swallowed(self):
        key, events, _, _, clock = service()
        key.resumed_at = 99.5
        key.edge(True); key.edge(False)
        self.assertEqual(events, [])
        clock[0] = 103
        key.edge(True)
        self.assertEqual(events, [{'event': 'powerKey', 'down': True}])

    def test_desktop_keeps_its_key(self):
        key, events, *_ = service(prefs={'powerKey': 'auto'})
        key.handset = False
        key.edge(True); key.chord()
        self.assertEqual(events, [])

    def test_grab_switches_submap(self):
        key, _, calls, *_ = service()
        key.grab(True); key.grab(False)
        self.assertEqual(calls[-2:], [['hyprctl', 'eval', 'hl.dispatch(hl.dsp.submap("opal-power"))'], ['hyprctl', 'eval', 'hl.dispatch(hl.dsp.submap("reset"))']])


class Ownership(unittest.TestCase):
    def test_inhibitor_follows_the_preference(self):
        prefs = {'powerKey': 'on'}
        key, events, _, spawned, _ = service(prefs=prefs)
        original = power_key.shutil.which
        power_key.shutil.which = lambda name: '/usr/bin/' + name
        try:
            key.apply()
            self.assertEqual(spawned[-1][:2], ['systemd-inhibit', '--what=handle-power-key'])
            process = key.inhibitor
            prefs['powerKey'] = 'off'
            key.apply()
            self.assertFalse(process.alive)
            self.assertIsNone(key.inhibitor)
            self.assertFalse(events[-1]['device']['enabled'])
        finally:
            power_key.shutil.which = original


class Actions(unittest.TestCase):
    def test_only_stored_commands_run(self):
        prefs = {'powerKey': 'on', 'powerMenu': [{'action': 'folder', 'label': 'Mine', 'items': [{'action': 'command', 'command': 'echo ok'}]}]}
        key, _, _, spawned, _ = service(prefs=prefs)
        key.run_command('echo ok')
        key.run_command('rm -rf ~')
        self.assertEqual(spawned, [['sh', '-c', 'echo ok']])

    def test_only_stored_links_open(self):
        prefs = {'powerKey': 'on', 'powerPress': {'double': {'action': 'link', 'url': 'https://example.org'}}}
        key, _, _, spawned, _ = service(prefs=prefs)
        key.open_link('https://example.org'); key.open_link('https://evil.example')
        self.assertEqual(spawned, [['xdg-open', 'https://example.org']])

    def test_call_on_a_phone_and_through_a_linked_phone(self):
        key, events, _, spawned, _ = service()
        key.contacts = [{'uid': 'a', 'name': 'Ada', 'phones': ['+44 (20) 1'], 'emails': []}]
        key.handset = True
        key.contact('call', '+44 (20) 1')
        self.assertEqual(spawned[-1], ['xdg-open', 'tel:+44201'])
        sent = []
        key.handset, key.link_url = False, lambda url: sent.append(url) or True
        key.contact('text', '+44 (20) 1')
        self.assertEqual(sent, ['sms:+44201'])
        key.contact('call', '+1 555 0000')
        self.assertEqual(sent, ['sms:+44201'], 'numbers outside the address book are ignored')

    def test_unknown_actions_fall_through(self):
        key, *_ = service()
        self.assertFalse(key.handle({'action': 'powerkey-nope'}))
        self.assertTrue(key.handle({'action': 'powerkey-grab', 'on': False}))


if __name__ == '__main__':
    unittest.main()
