import importlib.util
import io
import json
import os
import pathlib
import queue
import socket
import sys
import tempfile
import threading
import time
import unittest
from unittest.mock import patch

SOURCE = pathlib.Path(__file__).resolve().parents[1] / 'src'
sys.path.insert(0, str(SOURCE))
import hypr_events
import status as status_worker


class BackendTests(unittest.TestCase):
    def setUp(self):
        self.home = tempfile.TemporaryDirectory(prefix='opal-unit-')
        with patch.dict(os.environ, {'HOME': self.home.name}):
            spec = importlib.util.spec_from_file_location('tested_backend', SOURCE / 'backend.py')
            self.backend = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(self.backend)
        self.messages = []
        self.backend.emit = self.messages.append

    def tearDown(self):
        self.home.cleanup()

    def command(self, data):
        with patch.object(sys, 'stdin', io.StringIO(json.dumps(data) + '\n')):
            self.backend.commands()

    def test_calculator_is_bounded_not_eval(self):
        self.assertEqual(self.backend.calculate('(18+4)*3'), '66')
        for expr in ('__import__("os").system("true")', '2**10000000', '1/0', '[1,2]', 'float("inf")'):
            self.assertEqual(self.backend.calculate(expr), '')

    def test_calculator_handles_a_large_expression_batch(self):
        pairs = [(number, number + 3, number % 9 + 1, number % 5) for number in range(512)]
        expressions = [f'({left}+{right})*{factor}-{offset}' for left, right, factor, offset in pairs]
        expected = [str((left + right) * factor - offset) for left, right, factor, offset in pairs]
        self.assertEqual([self.backend.calculate(expr) for expr in expressions], expected)

    def test_pins_can_be_empty_and_defaults_preserved_on_first_edit(self):
        self.command({'action':'pin','id':'one','initial':['one','two']})
        self.assertEqual(self.backend.prefs['favorites'], ['two'])
        self.command({'action':'pin','id':'two'})
        self.assertEqual(self.backend.prefs['favorites'], [])
        self.assertTrue(self.backend.prefs['pinsConfigured'])
        self.assertEqual(json.loads(self.backend.STORE.read_text())['favorites'], [])

    def test_layout_and_taskbar_preferences_are_validated(self):
        self.command({'action':'preference','key':'mode','value':'auto'})
        self.command({'action':'preference','key':'taskbarAutoHide','value':True})
        self.command({'action':'preference','key':'controllerLayout','value':'nintendo'})
        self.assertEqual(self.backend.prefs['mode'], 'auto')
        self.assertTrue(self.backend.prefs['taskbarAutoHide'])
        self.assertEqual(self.backend.prefs['controllerLayout'], 'nintendo')
        self.command({'action':'preference','key':'glass','value':0})
        self.assertEqual(self.backend.prefs['glass'], .78)

    def test_rooms_preferences_are_validated(self):
        self.command({'action':'preference','key':'phoneStyle','value':'rooms'})
        self.assertEqual(self.backend.prefs['phoneStyle'],'rooms')
        self.command({'action':'preference','key':'phoneStyle','value':'grid'})
        self.assertEqual(self.backend.prefs['phoneStyle'],'rooms')
        self.command({'action':'preference','key':'roomNames','value':{'1':'Code','2':'Play'}})
        self.assertEqual(self.backend.prefs['roomNames'],{'1':'Code','2':'Play'})
        for bad in ({'x':'Code'},{'1':''},{'1':'a'*41},['Code']):
            self.command({'action':'preference','key':'roomNames','value':bad})
            self.assertEqual(self.backend.prefs['roomNames'],{'1':'Code','2':'Play'})

    def test_quick_access_guide_preference_is_boolean(self):
        self.command({'action':'preference','key':'quickAccessGuide','value':False})
        self.assertIs(self.backend.prefs['quickAccessGuide'], False)
        self.command({'action':'preference','key':'quickAccessGuide','value':'no'})
        self.assertIs(self.backend.prefs['quickAccessGuide'], False)

    def test_preference_stream_persists_each_valid_update(self):
        values = [.45 + (number % 56) / 100 for number in range(96)]
        stream = ''.join(json.dumps({'action':'preference', 'key':'glass', 'value':value}) + '\n' for value in values)
        with patch.object(sys, 'stdin', io.StringIO(stream)):
            self.backend.commands()
        stored = json.loads(self.backend.STORE.read_text())
        events = [message['data']['glass'] for message in self.messages if message['event'] == 'preferences']
        self.assertEqual(stored['glass'], values[-1])
        self.assertEqual(events, values)

    def test_quick_tiles_keep_order_and_allow_an_empty_panel(self):
        for order in (['theme', 'wifi', 'capture'], []):
            self.command({'action':'preference','key':'quickTiles','value':order})
            self.assertEqual(self.backend.load()['quickTiles'], order)
        for invalid in (['wifi', 'wifi'], ['unknown'], [None], [{}], 'wifi'):
            self.command({'action':'preference','key':'quickTiles','value':invalid})
            self.assertEqual(self.backend.prefs['quickTiles'], [])

    def test_phone_density_and_taskbar_options_validate_types(self):
        self.command({'action':'preference','key':'phoneRows','value':6})
        for invalid in (True, 3, 8, '5', 5.5):
            self.command({'action':'preference','key':'phoneRows','value':invalid})
            self.assertEqual(self.backend.prefs['phoneRows'], 6)
        for key in ('taskbarCenter', 'taskbarClockDate'):
            self.command({'action':'preference','key':key,'value':True})
            self.command({'action':'preference','key':key,'value':'false'})
            self.assertIs(self.backend.load()[key], True)

    def test_taskbar_order_persists_without_changing_pins(self):
        original=list(self.backend.prefs['favorites'])
        self.command({'action':'preference','key':'taskbarOrder','value':['two','one']})
        self.assertEqual(json.loads(self.backend.STORE.read_text())['taskbarOrder'],['two','one'])
        self.assertEqual(self.backend.prefs['favorites'],original)
        for invalid in (['one','one'],[''],[{}],['a']*129):
            self.command({'action':'preference','key':'taskbarOrder','value':invalid})
            self.assertEqual(self.backend.prefs['taskbarOrder'],['two','one'])

    def test_status_poll_cannot_overwrite_event_driven_workspaces(self):
        with patch.object(self.backend, 'run', return_value=''):
            result = self.backend.status()
        self.assertFalse({'workspace','workspaces','windows','title','activeAddress'} & result.keys())

    def test_cached_art_index_accepts_old_and_new_steam_layouts(self):
        cache = pathlib.Path(self.home.name) / '.local/share/Steam/appcache/librarycache'
        modern = cache / '1091500/hash/library_capsule.jpg'
        modern.parent.mkdir(parents=True)
        modern.write_bytes(b'fixture')
        old = cache / '945360_library_header.jpg'
        old.write_bytes(b'fixture')
        result = self.backend.library_art()
        self.assertEqual(result['1091500']['cover'], modern.as_uri())
        self.assertEqual(result['945360']['header'], old.as_uri())

    def test_art_index_scans_a_large_mixed_cache_without_deep_files(self):
        cache = pathlib.Path(self.home.name) / '.local/share/Steam/appcache/librarycache'
        for number in range(96):
            appid = str(800000 + number)
            folder = cache / appid / 'hash'
            folder.mkdir(parents=True)
            (folder / 'library_capsule.jpg').write_bytes(b'cover')
            (folder / 'library_hero.jpg').write_bytes(b'hero')
            (folder / 'ignore.txt').write_bytes(b'ignore')
            deep = folder / 'extra'
            deep.mkdir()
            (deep / 'library_header.jpg').write_bytes(b'deep')
        invalid = cache / 'not-an-app' / 'hash'
        invalid.mkdir(parents=True)
        (invalid / 'library_capsule.jpg').write_bytes(b'invalid')
        result = self.backend.library_art()
        self.assertEqual(len(result), 96)
        self.assertNotIn('not-an-app', result)
        self.assertTrue(all(set(art) == {'cover', 'hero'} for art in result.values()))

    def test_status_worker_fetches_media_fields_with_one_command(self):
        calls = []

        def fake_run(*args):
            calls.append(args)
            if args[:2] == ('wpctl', 'get-volume'):
                return 'Volume: 0.42'
            if args[:2] == ('nmcli', '-t'):
                return 'Home:wifi'
            if args[:2] == ('playerctl', 'metadata'):
                return 'Track\x1fArtist'
            return ''

        with patch.object(status_worker, 'run', side_effect=fake_run), \
                patch.object(status_worker.glob, 'glob', return_value=[]), \
                patch.dict(os.environ, {}, clear=True):
            result = status_worker.collect_status()

        self.assertEqual(result['track'], 'Track')
        self.assertEqual(result['artist'], 'Artist')
        media_calls = [call for call in calls if call[:2] == ('playerctl', 'metadata')]
        self.assertEqual(media_calls, [('playerctl', 'metadata', '--format', '{{title}}\x1f{{artist}}')])

    def test_system_osk_reads_and_controls_session_service(self):
        osk = self.backend.SystemOsk()
        process = type('Process', (), {'poll':lambda self:None})()
        osk.process = process
        with patch.object(self.backend, 'command_available', side_effect=lambda name:name == 'busctl'), \
                patch.object(self.backend.subprocess, 'check_output', return_value='b false') as query:
            self.assertFalse(osk.visible())
            self.assertEqual(query.call_args.args[0][:3], ['busctl','--user','get-property'])
        with patch.object(osk, 'visible', return_value=False), \
                patch.object(self.backend, 'command_available', side_effect=lambda name:name == 'busctl'), \
                patch.object(self.backend.subprocess, 'run') as control:
            self.assertTrue(osk.set_visible(True))
            self.assertEqual(control.call_args.args[0][-3:], ['SetVisible','b','true'])
        event = self.messages[-1]
        self.assertEqual(event['event'], 'systemOsk')
        self.assertTrue(event['running'])
        self.assertTrue(event['visible'])

    def test_system_osk_command_routes_show_hide_and_toggle(self):
        class FakeOsk:
            def __init__(self): self.calls=[]
            def toggle(self): self.calls.append('toggle')
            def set_visible(self, visible): self.calls.append('show' if visible else 'hide')
        fake=FakeOsk()
        self.backend.system_osk=fake
        stream=''.join(json.dumps({'action':'system-osk','verb':verb})+'\n' for verb in ('show','hide','toggle'))
        with patch.object(sys, 'stdin', io.StringIO(stream)):
            self.backend.commands()
        self.assertEqual(fake.calls, ['show','hide','toggle'])


class WorkspaceEventTests(unittest.TestCase):
    def test_switches_arrive_directly_without_a_poll_or_focus_change(self):
        with tempfile.TemporaryDirectory(prefix='op-ipc-') as runtime:
            base = pathlib.Path(runtime) / 'hypr/test'
            base.mkdir(parents=True)
            command_socket = socket.socket(socket.AF_UNIX)
            event_socket = socket.socket(socket.AF_UNIX)
            command_socket.bind(str(base / '.socket.sock'))
            event_socket.bind(str(base / '.socket2.sock'))
            command_socket.listen()
            event_socket.listen()
            command_socket.settimeout(.1)
            stopped = threading.Event()
            state = {'workspaces':[{'id':1},{'id':2}], 'clients':[],
                     'monitors':[{'id':0,'name':'TEST-1','activeWorkspace':{'id':1},'specialWorkspace':{'id':0}}],
                     'activeworkspace':{'id':1,'monitor':'TEST-1'},
                     'activewindow':{'title':'Initial','address':'0x123'}}

            def serve_queries():
                while not stopped.is_set():
                    try:
                        client, _ = command_socket.accept()
                        with client:
                            request = client.recv(1024).decode().removeprefix('j/')
                            client.sendall(json.dumps(state[request]).encode())
                    except socket.timeout:
                        continue
                    except OSError:
                        break

            threading.Thread(target=serve_queries, daemon=True).start()
            events = queue.Queue()
            with patch.dict(os.environ, {'XDG_RUNTIME_DIR':runtime, 'HYPRLAND_INSTANCE_SIGNATURE':'test'}):
                threading.Thread(target=hypr_events.listen, args=(events.put,), daemon=True).start()
                stream, _ = event_socket.accept()
                initial = events.get(timeout=1)['data']
                self.assertEqual(initial['workspace'], 1)
                start = time.monotonic()
                stream.sendall(b'workspacev2>>2,2\nactivewindow>>test,Title, with commas\n')
                self.assertEqual(events.get(timeout=.2)['data'], {'workspace':2})
                self.assertEqual(events.get(timeout=.2)['data']['title'], 'Title, with commas')
                elapsed = (time.monotonic()-start)*1000
                self.assertLess(elapsed, 150)
                stream.sendall(b'focusedmonv2>>TEST-2,4\nactivewindowv2>>abc\n')
                self.assertEqual(events.get(timeout=.2)['data']['workspace'], 4)
                self.assertEqual(events.get(timeout=.2)['data']['activeAddress'], '0xabc')
                print(f'\nFake-socket workspace + title delivery: {elapsed:.2f} ms (no real desktop touched)')
                stream.close()
            stopped.set()
            command_socket.close()
            event_socket.close()


if __name__ == '__main__':
    unittest.main()

