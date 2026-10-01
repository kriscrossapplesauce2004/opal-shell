import json, pathlib, sqlite3, struct, sys, tempfile, unittest
from unittest.mock import patch
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'src'))
import game_library as gl


def binary_shortcuts(entries):
    def s(key, value): return b'\x01' + key.encode() + b'\0' + value.encode() + b'\0'
    def i(key, value): return b'\x02' + key.encode() + b'\0' + struct.pack('<i', value)
    body = b''
    for index, (appid, name) in enumerate(entries):
        body += b'\x00' + str(index).encode() + b'\0' + i('appid', appid) + s('AppName', name) + s('Exe', '"/x"') + b'\x08'
    return b'\x00shortcuts\0' + body + b'\x08\x08'


class GameLibraryTests(unittest.TestCase):
    def test_text_vdf(self):
        data = gl.text_vdf('"AppState"\n{\n "appid" "220200"\n "name" "Kerbal \\"Space\\""\n "UserConfig" { "language" "english" }\n}')
        self.assertEqual(data['AppState']['appid'], '220200')
        self.assertEqual(data['AppState']['UserConfig'], {'language': 'english'})

    def test_steam_skips_tools_and_uses_art(self):
        with tempfile.TemporaryDirectory() as root:
            root = pathlib.Path(root)
            apps = root / 'steamapps'; apps.mkdir()
            (apps / 'appmanifest_1.acf').write_text('"AppState" { "appid" "1" "name" "Deltarune" "LastPlayed" "50" }')
            (apps / 'appmanifest_2.acf').write_text('"AppState" { "appid" "2" "name" "Proton 9.0" }')
            with patch.object(gl, 'STEAM_ROOTS', [root]):
                games = gl.steam_games({'1': {'cover': 'file:///c.jpg'}})
        self.assertEqual([g['title'] for g in games], ['Deltarune'])
        self.assertEqual(games[0]['launch'], ['steam', 'steam://rungameid/1'])
        self.assertEqual(games[0]['cover'], 'file:///c.jpg')
        self.assertEqual(games[0]['lastPlayed'], 50)

    def test_shortcuts_binary_vdf_and_rungameid(self):
        with tempfile.TemporaryDirectory() as root:
            root = pathlib.Path(root)
            (root / 'steamapps').mkdir()
            config = root / 'userdata/42/config'; config.mkdir(parents=True)
            (config / 'shortcuts.vdf').write_bytes(binary_shortcuts([(-36025372, 'StellarDrive')]))
            with patch.object(gl, 'STEAM_ROOTS', [root]):
                games = gl.steam_shortcuts()
        unsigned = -36025372 & 0xffffffff
        self.assertEqual(games[0]['title'], 'StellarDrive')
        self.assertEqual(games[0]['launch'][1], 'steam://rungameid/%d' % ((unsigned << 32) | 0x02000000))

    def test_prism_instances(self):
        with tempfile.TemporaryDirectory() as home:
            home = pathlib.Path(home)
            folder = home / '.local/share/PrismLauncher/instances/JevCraft'; folder.mkdir(parents=True)
            (folder / 'instance.cfg').write_text('[General]\nname=JevCraft — Survival\nlastLaunchTime=1790000000000\n')
            with patch.object(gl, 'HOME', home):
                games = gl.prism_instances()
        self.assertEqual(games[0]['title'], 'JevCraft — Survival')
        self.assertEqual(games[0]['launch'], ['prismlauncher', '--launch', 'JevCraft'])
        self.assertEqual(games[0]['lastPlayed'], 1790000000)

    def test_lutris_reads_installed_only(self):
        with tempfile.TemporaryDirectory() as home:
            home = pathlib.Path(home)
            db = home / '.local/share/lutris/pga.db'; db.parent.mkdir(parents=True)
            connection = sqlite3.connect(db)
            connection.execute('CREATE TABLE games (slug TEXT, name TEXT, runner TEXT, lastplayed INTEGER, installed INTEGER)')
            connection.executemany('INSERT INTO games VALUES (?,?,?,?,?)', [('celeste', 'Celeste', 'linux', 5, 1), ('gone', 'Gone', 'wine', 0, 0)])
            connection.commit(); connection.close()
            with patch.object(gl, 'HOME', home):
                games = gl.lutris_games()
        self.assertEqual([g['title'] for g in games], ['Celeste'])
        self.assertEqual(games[0]['launch'], ['lutris', 'lutris:rungame/celeste'])

    def test_library_survives_broken_sources(self):
        with patch.object(gl, 'steam_shortcuts', side_effect=RuntimeError('boom')), patch.object(gl, 'STEAM_ROOTS', []), patch.object(gl, 'HOME', pathlib.Path('/nonexistent')):
            self.assertEqual(gl.library({}), [])


if __name__ == '__main__':
    unittest.main()
