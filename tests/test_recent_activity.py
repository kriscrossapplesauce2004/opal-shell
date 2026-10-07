import os, pathlib, sys, tempfile, time, unittest
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'src'))
import recent_activity as ra

XBEL = '''<?xml version="1.0"?><xbel version="1.0" xmlns:mime="http://www.freedesktop.org/standards/shared-mime-info">
<bookmark href="file:///home/x/opal-a%20b.txt" visited="2026-10-01T10:00:00Z" modified="2026-10-01T09:00:00Z"><info><metadata><mime:mime-type type="text/plain"/></metadata></info></bookmark>
<bookmark href="file:///home/x/new.pdf" visited="2026-10-05T10:00:00Z"><info><metadata><mime:mime-type type="application/pdf"/></metadata></info></bookmark>
<bookmark href="https://example.com/" visited="2026-10-06T10:00:00Z"/>
<bookmark href="file:///home/x/.cache/skip.png" visited="2026-10-06T10:00:00Z"/>
<bookmark href="file:///home/x/gone.txt" visited="2026-10-07T10:00:00Z"/>
</xbel>'''

class RecentActivity(unittest.TestCase):
    def test_parse_orders_filters_and_decodes(self):
        out = ra.parse_xbel(XBEL, exists=lambda p: not p.endswith('gone.txt'))
        self.assertEqual([f['title'] for f in out], ['new.pdf', 'opal-a b.txt'])
        self.assertEqual(out[0]['icon'], 'picture_as_pdf')
        self.assertEqual(out[1]['mime'], 'text/plain')

    def test_limit_and_bad_input(self):
        self.assertEqual(len(ra.parse_xbel(XBEL, limit=1, exists=lambda p: True)), 1)
        self.assertEqual(ra.parse_xbel('<not xml'), [])
        self.assertEqual(ra.parse_xbel('<!ENTITY x "y"><xbel/>'), [])
        self.assertEqual(ra.parse_xbel(None), [])

    def test_missing_file(self):
        self.assertEqual(ra.recent_files(path=pathlib.Path('/nonexistent/x.xbel')), [])

    def test_games_recent_only_without_launch(self):
        now = 1_800_000_000
        games = [{'id': 'a', 'title': 'A', 'lastPlayed': now - 100, 'launch': ['x']}, {'id': 'b', 'title': 'B', 'lastPlayed': now - 10**8},
                 {'id': 'c', 'title': 'C', 'lastPlayed': 0}, {'id': 'd', 'title': 'D', 'lastPlayed': now - 5}]
        out = ra.recent_games(games, now=now)
        self.assertEqual([g['id'] for g in out], ['d', 'a'])
        self.assertNotIn('launch', out[0])
        self.assertEqual(ra.recent_games('bad'), [])

    def test_relative(self):
        self.assertEqual(ra.relative(100, now=130), 'Just now')
        self.assertEqual(ra.relative(0, now=130), '')
        self.assertEqual(ra.relative(1000, now=1000 + 7200), '2 h ago')
        self.assertEqual(ra.relative(1000, now=1000 + 86400 * 3), '3 d ago')

    def test_snapshot(self):
        snap = ra.snapshot(games=[], files=[{'when': 5, 'title': 't'}])
        self.assertEqual(snap['games'], [])
        self.assertIn('ago', snap['files'][0])

if __name__ == '__main__':
    unittest.main()
