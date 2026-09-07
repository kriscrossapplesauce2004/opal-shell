import pathlib
import sys
import tempfile
import unittest
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]))
from wallpaper_service import image_library


class WallpaperLibraryTests(unittest.TestCase):
    def test_local_gallery_and_symlinks(self):
        with tempfile.TemporaryDirectory() as folder:
            root=pathlib.Path(folder)
            (root/'one.png').write_bytes(b'fixture')
            (root/'two.txt').write_text('not an image')
            (root/'.hidden.jpg').write_bytes(b'fixture')
            (root/'nested').mkdir()
            (root/'nested'/'two.webp').write_bytes(b'fixture')
            (root/'loop').symlink_to(root,target_is_directory=True)
            items=image_library(root.as_uri())
            self.assertEqual([i['name'] for i in items],['one','two'])
            self.assertTrue(all(i['path'].startswith('file:') for i in items))

    def test_remote_rejected(self):
        for folder in ('https://example.com/images','file://remote/images','relative/path'):
            with self.assertRaises(ValueError):image_library(folder)

    def test_bounded_and_no_writes(self):
        with tempfile.TemporaryDirectory() as folder:
            root=pathlib.Path(folder)
            for i in range(140):(root/f'{i:03}.jpg').write_bytes(b'fixture')
            before=sorted(p.name for p in root.iterdir())
            self.assertEqual(len(image_library(folder)),120)
            self.assertEqual(sorted(p.name for p in root.iterdir()),before)

    def test_current_deduplicated(self):
        with tempfile.TemporaryDirectory() as folder:
            path=pathlib.Path(folder,'a.png');path.write_bytes(b'fixture')
            self.assertEqual(len(image_library(folder,path.as_uri())),1)


if __name__=='__main__':unittest.main()
