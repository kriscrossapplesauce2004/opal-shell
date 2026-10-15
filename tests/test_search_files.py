import os, pathlib, sys, tempfile, types, unittest
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'src'))
import search_files as sf


class SearchFilesTests(unittest.TestCase):
    def test_search_filters_and_orders(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = pathlib.Path(tmp)
            keep = home / 'Pictures' / 'dark-wallpaper.png'; keep.parent.mkdir(); keep.write_text('x')
            older = home / 'old-dark.txt'; older.write_text('x'); os.utime(older, (1, 1))
            hidden = home / '.cache' / 'dark.png'; hidden.parent.mkdir(); hidden.write_text('x')
            gone = home / 'dark-missing.txt'
            lines = '\n'.join(map(str, [hidden, older, keep, gone, '/etc/dark.conf', home / 'nomatch.txt']))
            calls = []
            def runner(args, **kw):
                calls.append(args)
                return types.SimpleNamespace(stdout=lines)
            out = sf.search('dark', home=home, runner=runner, which=lambda n: '/usr/bin/plocate' if n == 'plocate' else None)
            self.assertEqual([o['name'] for o in out], ['dark-wallpaper.png', 'old-dark.txt'])
            self.assertEqual(out[0]['folder'], '~/Pictures')
            self.assertEqual(calls[0][:2], ['/usr/bin/plocate', '-i'])
            self.assertEqual(calls[0][-2:], ['--', 'dark'])
            self.assertEqual(sf.search('x', home=home, runner=runner, which=lambda n: '/bin/p'), [])
            self.assertEqual(sf.search('dark', home=home, runner=runner, which=lambda n: None), [])

    def test_openable(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = pathlib.Path(tmp); f = home / 'a.txt'; f.write_text('x')
            self.assertTrue(sf.openable(str(f), home=home))
            self.assertFalse(sf.openable(str(home / 'missing'), home=home))
            self.assertFalse(sf.openable('/etc/passwd', home=home))
            self.assertFalse(sf.openable('relative.txt', home=home))
            self.assertFalse(sf.openable(None, home=home))


if __name__ == '__main__':
    unittest.main()
