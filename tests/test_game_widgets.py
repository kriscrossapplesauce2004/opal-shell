import json, os, pathlib, sys, tempfile, unittest
from types import SimpleNamespace
from unittest.mock import patch
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'src'))
import game_library as gl
import game_widgets as gw


def manifest(apps, appid, name, flags='4', size='1000', to='0', done='0', played='0'):
    (apps / ('appmanifest_%s.acf' % appid)).write_text(
        '"AppState" { "appid" "%s" "name" "%s" "StateFlags" "%s" "SizeOnDisk" "%s" "BytesToDownload" "%s" "BytesDownloaded" "%s" "LastPlayed" "%s" }'
        % (appid, name, flags, size, to, done, played))


class GameWidgetTests(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory(); self.root = pathlib.Path(self.dir.name)
        self.apps = self.root / 'steamapps'; self.apps.mkdir()
    def tearDown(self): self.dir.cleanup()

    def test_update_states(self):
        self.assertEqual(gw.update_state(4), '')
        self.assertEqual(gw.update_state(6), 'queued')
        self.assertEqual(gw.update_state(516), 'paused')
        self.assertEqual(gw.update_state(4 | 1048576), 'downloading')

    def test_updates_list_pending_games_and_skip_tools(self):
        manifest(self.apps, 1, 'Up To Date')
        manifest(self.apps, 2, 'Universe Sandbox', flags='6', to='700', done='100')
        manifest(self.apps, 3, 'Plasma', flags='516')
        manifest(self.apps, 4, 'Proton 9.0', flags='6')
        items = gw.steam_updates(self.root)
        self.assertEqual([(i['title'], i['state'], i['bytes']) for i in items], [('Universe Sandbox', 'queued', 600), ('Plasma', 'paused', 0)])

    def test_storage_sorts_largest_and_reads_disk(self):
        manifest(self.apps, 1, 'Small', size='10')
        manifest(self.apps, 2, 'Big', size='900')
        fake = lambda path: SimpleNamespace(f_blocks=100, f_frsize=10, f_bavail=40)
        data = gw.storage(self.root, statvfs=fake)
        self.assertEqual((data['total'], data['free'], data['games']), (1000, 400, 910))
        self.assertEqual([g['title'] for g in data['largest']], ['Big', 'Small'])

    def test_captures_newest_first_with_shortcut_ids(self):
        steam = self.root / 'userdata/7/760/remote/281990/screenshots'; steam.mkdir(parents=True)
        shortcut = self.root / ('userdata/7/760/remote/%d/screenshots' % ((5 << 32) | 0x02000000)); shortcut.mkdir(parents=True)
        (steam / 'a.jpg').write_bytes(b'x'); os.utime(steam / 'a.jpg', (1, 1))
        (shortcut / 'b.jpg').write_bytes(b'x'); os.utime(shortcut / 'b.jpg', (2, 2))
        (steam / 'thumbnails').mkdir(); (steam / 'thumbnails/a.jpg').write_bytes(b'x')
        data = gw.captures(self.root)
        self.assertEqual(data['total'], 2)
        self.assertEqual([i['id'] for i in data['items']], ['shortcut:5', 'steam:281990'])
        self.assertEqual(data['perGame'], {'steam:281990': 1, 'shortcut:5': 1})

    def test_prism_instance_details(self):
        inst = self.root / 'prism/instances/pack'; (inst / 'minecraft/mods').mkdir(parents=True)
        (inst / 'instance.cfg').write_text('name=My Pack\ntotalTimePlayed=3600\nlastLaunchTime=5000\n')
        (inst / 'mmc-pack.json').write_text(json.dumps({'components': [{'uid': 'net.minecraft', 'version': '1.21.1'}, {'uid': 'net.neoforged', 'version': '21'}]}))
        (inst / 'minecraft/mods/a.jar').write_bytes(b''); (inst / 'minecraft/mods/b.jar').write_bytes(b''); (inst / 'minecraft/mods/readme.txt').write_bytes(b'')
        [item] = gw.prism_instances([self.root / 'prism'])
        self.assertEqual((item['id'], item['title'], item['version'], item['loader'], item['mods'], item['seconds'], item['lastPlayed']),
                         ('prism:pack', 'My Pack', '1.21.1', 'NeoForge', 2, 3600, 5))

    def test_shortcut_titles_lose_exe(self):
        self.assertEqual(gl.clean_title('factorio.exe'), 'factorio')
        self.assertEqual(gl.clean_title('DELTATALE.EXE '), 'DELTATALE')
        self.assertEqual(gl.clean_title('.exe'), '.exe')


if __name__ == '__main__':
    unittest.main()
