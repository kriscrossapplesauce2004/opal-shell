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

SOURCE = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SOURCE))
import hypr_events


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
