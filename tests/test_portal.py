import json, os, pathlib, shutil, socket, subprocess, sys, tempfile, textwrap, threading, time, unittest
SRC = pathlib.Path(__file__).resolve().parents[1] / 'src'
sys.path.insert(0, str(SRC))
import file_browse as fb


class Browsing(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(); self.root = pathlib.Path(self.tmp.name)
        for name in ('b.png', 'a.txt', '.secret', 'Photo.JPG'): (self.root / name).write_text('x')
        (self.root / 'Folder').mkdir()

    def tearDown(self): self.tmp.cleanup()

    def test_listing_puts_folders_first_and_hides_dotfiles(self):
        data = fb.listing(str(self.root))
        self.assertEqual([e['name'] for e in data['entries']], ['Folder', 'a.txt', 'b.png', 'Photo.JPG'])
        self.assertEqual(data['crumbs'][-1]['name'], self.root.name)
        self.assertEqual([c['name'] for c in fb.listing(str(self.root / 'Folder'), home=self.root)['crumbs']], ['Home', 'Folder'])
        self.assertIn('.secret', [e['name'] for e in fb.listing(str(self.root), hidden=True)['entries']])

    def test_portal_filters_match_globs_case_insensitively_and_mimes(self):
        images = {'globs': ['*.png', '*.jpg'], 'mimes': []}
        self.assertEqual([e['name'] for e in fb.listing(self.root.as_uri(), rule=images)['entries']], ['Folder', 'b.png', 'Photo.JPG'])
        self.assertTrue(fb.matches('x.png', {'globs': [], 'mimes': ['image/*']}))
        self.assertFalse(fb.matches('x.txt', {'globs': [], 'mimes': ['image/png']}))
        self.assertEqual([e['name'] for e in fb.listing(str(self.root), directories_only=True)['entries']], ['Folder'])

    def test_bad_input(self):
        for value in ('relative/path', 'http://example.com/x', 'file://host/x', str(self.root / 'missing')):
            with self.assertRaises(ValueError): fb.listing(value)
        with self.assertRaises(ValueError): fb.make_folder(str(self.root), '../escape')
        with self.assertRaises(ValueError): fb.save_target(str(self.root), 'a/b')

    def test_save_target_and_new_folder(self):
        self.assertTrue(fb.save_target(str(self.root), 'a.txt')['exists'])
        self.assertFalse(fb.save_target(str(self.root), 'new name.txt')['exists'])
        self.assertTrue(fb.make_folder(str(self.root), 'New').endswith('/New'))

    def test_recent_files_skip_missing_and_filtered(self):
        share = self.root / 'home/.local/share'; share.mkdir(parents=True)
        keep = self.root / 'b.png'
        (share / 'recently-used.xbel').write_text(textwrap.dedent(f'''<?xml version="1.0"?>
            <xbel version="1.0"><bookmark href="{keep.as_uri()}" visited="2026-10-21T10:00:00Z"/>
            <bookmark href="{(self.root / 'a.txt').as_uri()}" visited="2026-10-21T11:00:00Z"/>
            <bookmark href="file:///nope/gone.png" visited="2026-10-21T12:00:00Z"/></xbel>'''))
        names = [e['name'] for e in fb.recent(self.root / 'home')]
        self.assertEqual(names, ['a.txt', 'b.png'])
        self.assertEqual([e['name'] for e in fb.recent(self.root / 'home', rule={'globs': ['*.png']})], ['b.png'])


@unittest.skipUnless(shutil.which('dbus-run-session') and shutil.which('gdbus'), 'needs dbus-run-session and gdbus')
class PortalOverDBus(unittest.TestCase):
    """The real portal service on a private bus. A fake quickshell plays the shell: it shows the picker or declines."""

    def run_case(self, shell_answer, method='OpenFile'):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = pathlib.Path(tmp)
            runtime = tmp / 'run'; runtime.mkdir(mode=0o700)
            bin_dir = tmp / 'bin'; bin_dir.mkdir()
            # The fake shell answers "shown" and then picks a file through the backend's socket helper.
            (bin_dir / 'quickshell').write_text(textwrap.dedent(f'''\
                #!/usr/bin/env python3
                import base64, json, sys, threading, time
                sys.path.insert(0, {str(SRC)!r})
                import file_browse
                if sys.argv[-2] != 'portalPick': sys.exit(0)
                request = json.loads(base64.b64decode(sys.argv[-1]))
                open({str(tmp / 'request.json')!r}, 'w').write(json.dumps(request))
                print({shell_answer!r})
                sys.stdout.flush()
                if {shell_answer!r} == 'shown':
                    time.sleep(.3)
                    file_browse.send_answer(dict(token=request['token'], uris=['file:///tmp/picked%20one.png'], filter=1))
                '''))
            (bin_dir / 'quickshell').chmod(0o755)
            # A stand-in fallback backend records that the call was forwarded.
            fallback = tmp / 'fallback.py'
            fallback.write_text(textwrap.dedent('''\
                import gi; gi.require_version('Gio', '2.0'); from gi.repository import Gio, GLib
                import sys; sys.path.insert(0, %r); import opal_portal
                def call(c, s, p, i, m, params, inv): inv.return_value(GLib.Variant('(ua{sv})', (0, {'uris': GLib.Variant('as', ['file:///from/fallback'])})))
                def acquired(c, n): c.register_object(opal_portal.OBJECT, Gio.DBusNodeInfo.new_for_xml(opal_portal.XML).interfaces[0], call, None, None)
                Gio.bus_own_name(Gio.BusType.SESSION, 'org.freedesktop.impl.portal.desktop.gtk', 0, acquired, None, None)
                GLib.MainLoop().run()
                ''' % str(SRC)))
            options = "{'filters': <[('Text', [(uint32 0, '*.txt')]), ('Images', [(uint32 0, '*.png'), (uint32 1, 'image/png')])]>, 'multiple': <true>, 'current_folder': <[byte 0x2f, 0x74, 0x6d, 0x70, 0x00]>}"
            script = textwrap.dedent(f'''\
                python3 {fallback} & python3 {SRC / 'opal_portal.py'} &
                for i in $(seq 50); do gdbus introspect --session -d org.freedesktop.impl.portal.desktop.opal -o /org/freedesktop/portal/desktop >/dev/null 2>&1 && break; sleep .1; done
                gdbus call --session -d org.freedesktop.impl.portal.desktop.opal -o /org/freedesktop/portal/desktop \
                  -m org.freedesktop.impl.portal.FileChooser.{method} /org/freedesktop/portal/desktop/request/1_1/t "app.test" "" "Pick" "{options}"
                kill %1 %2
                ''')
            env = dict(os.environ, PATH=f'{bin_dir}:{os.environ["PATH"]}', XDG_RUNTIME_DIR=str(runtime), XDG_STATE_HOME=str(tmp / 'state'))
            out = subprocess.run(['dbus-run-session', '--', 'bash', '-c', script], env=env, capture_output=True, text=True, timeout=30)
            request = json.loads((tmp / 'request.json').read_text()) if (tmp / 'request.json').exists() else None
            return out.stdout, request

    def test_shell_picks_the_file(self):
        out, request = self.run_case('shown')
        self.assertIn("file:///tmp/picked%20one.png", out)
        self.assertIn("'current_filter': <('Images', [(uint32 0, '*.png'), (1, 'image/png')])>", out)
        self.assertEqual((request['kind'], request['multiple'], request['folder']), ('open', True, '/tmp'))
        self.assertEqual(request['filters'][1], {'name': 'Images', 'globs': ['*.png'], 'mimes': ['image/png']})

    def test_declined_dialogs_go_to_the_fallback(self):
        out, _ = self.run_case('declined', 'SaveFile')
        self.assertIn('file:///from/fallback', out)


if __name__ == '__main__':
    unittest.main()
