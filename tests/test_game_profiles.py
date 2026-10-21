import pathlib, sys, unittest
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'src'))
import game_profiles as gp
import gamescope_bridge as gb


class ProfileTests(unittest.TestCase):
    def test_next_game_preset_and_own_profiles(self):
        self.assertEqual(gp.resolve({}, 'steam:1')['preset'], 'balanced')
        self.assertEqual(gp.resolve({'gameProfileNext': 'saver'}, 'steam:1'), {'power': 'power-saver', 'fpsLimit': 40, 'preset': 'saver', 'own': False})
        prefs = {'gameProfiles': {'steam:1': {'preset': 'max'}, 'steam:2': {'preset': 'custom', 'fpsLimit': 45, 'power': 'balanced', 'tdp': 12, 'overlay': 'fps'}}}
        self.assertEqual(gp.resolve(prefs, 'steam:1')['fpsLimit'], 0)
        self.assertEqual(gp.resolve(prefs, 'steam:2'), {'preset': 'custom', 'own': True, 'power': 'balanced', 'fpsLimit': 45, 'tdp': 12, 'overlay': 'fps'})

    def test_custom_values_are_checked(self):
        prefs = {'gameProfiles': {'steam:3': {'preset': 'custom', 'fpsLimit': 9999, 'power': 'turbo', 'tdp': -1}}}
        self.assertEqual(gp.resolve(prefs, 'steam:3'), {'preset': 'custom', 'own': True, 'power': 'balanced', 'fpsLimit': 0})

    def test_applier_restores_what_was_there_before_the_first_game(self):
        state = {'power': 'balanced', 'fps': 0}
        a = gp.Applier(lambda: state['power'], lambda v: state.__setitem__('power', v), lambda: state['fps'], lambda v: state.__setitem__('fps', v))
        a.apply('steam:1', {'power': 'power-saver', 'fpsLimit': 40})
        a.apply('steam:2', {'power': 'performance', 'fpsLimit': 0})
        self.assertEqual(state, {'power': 'performance', 'fps': 0})
        self.assertTrue(a.restore())
        self.assertEqual(state, {'power': 'balanced', 'fps': 0})
        self.assertFalse(a.restore())


class GamescopeBridgeTests(unittest.TestCase):
    def test_app_ids_from_environment(self):
        self.assertEqual(gb.appid_from_environ(b'HOME=/h\0SteamAppId=220200\0'), 220200)
        self.assertEqual(gb.appid_from_environ(b'OPAL_APPID=5\0SteamAppId=9\0'), 5)
        self.assertEqual(gb.appid_from_environ(b'SteamAppId=769\0'), 0)
        self.assertEqual(gb.appid_from_environ(b'SteamAppId=abc\0'), 0)

    def test_parent_walk(self):
        import tempfile
        with tempfile.TemporaryDirectory() as proc:
            for pid, ppid, env in ((30, 20, b'A=1'), (20, 10, b'SteamGameId=42'), (10, 1, b'')):
                d = pathlib.Path(proc, str(pid)); d.mkdir()
                (d / 'environ').write_bytes(env); (d / 'stat').write_text('%d (some game) S %d 0 0' % (pid, ppid))
            self.assertEqual(gb.appid_for_pid(30, proc), 42)
            self.assertEqual(gb.appid_for_pid(10, proc), 0)

    def test_roles_and_baselayer(self):
        self.assertEqual([gb.role(t) for t in ('opal-home', 'opal-overlay', 'Stellaris')], ['home', 'overlay', 'app'])
        self.assertEqual(gb.baselayer(220200), [220200, 769])
        self.assertEqual(gb.baselayer(769), [769])
        own = gb.own_appid('kitty', 4)
        self.assertTrue(own >= gb.OWN_BASE and own == gb.own_appid('KITTY', 9))


if __name__ == '__main__':
    unittest.main()
