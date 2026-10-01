import pathlib
import sys
import tempfile
import unittest
from unittest.mock import patch
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1] / 'src'))
import wallpaper_service
from wallpaper_service import browse_images, image_library, local_image


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

    def test_in_shell_browser_lists_directories_and_images(self):
        with tempfile.TemporaryDirectory() as folder:
            root=pathlib.Path(folder)
            (root/'Landscapes').mkdir()
            (root/'photo.png').write_bytes(b'fixture')
            (root/'.hidden').mkdir()
            (root/'other.txt').write_text('not an image')
            (root/'loop').symlink_to(root,target_is_directory=True)
            listing=browse_images(root.as_uri())
            self.assertEqual(listing['folder'],root.as_uri())
            self.assertEqual(listing['parent'],root.parent.as_uri())
            self.assertEqual([i['name'] for i in listing['folders']],['Landscapes'])
            self.assertTrue(listing['folders'][0]['directory'])
            self.assertEqual([i['name'] for i in listing['items']],['photo'])
            self.assertFalse(listing['items'][0]['directory'])
            for remote in ('https://example.com','file://remote/tmp','relative/path'):
                with self.assertRaises(ValueError):browse_images(remote)

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

    def test_local_image_resolves_regular_symlink(self):
        with tempfile.TemporaryDirectory() as folder:
            root=pathlib.Path(folder)
            image=root/'source.png'
            image.write_bytes(b'fixture')
            link=root/'linked.png'
            link.symlink_to(image)
            self.assertEqual(local_image(str(link)),image.resolve())
            with self.assertRaises(ValueError):
                local_image(str(root))

    def test_browser_handles_3000_real_entries(self):
        with tempfile.TemporaryDirectory() as folder:
            root=pathlib.Path(folder)
            expected_folders=[]
            expected_images=[]
            for index in range(200):
                name=f'folder-{index:03}'
                (root/name).mkdir()
                expected_folders.append(name)
            for index in range(120):
                name=f'image-{index:03}'
                (root/f'{name}.jpg').write_bytes(b'fixture')
                expected_images.append(name)
            for index in range(2680):
                (root/f'document-{index:04}.txt').write_text('not an image')
            listing=browse_images(str(root))
            self.assertEqual([item['name'] for item in listing['folders']],expected_folders)
            self.assertEqual([item['name'] for item in listing['items']],expected_images)

    def test_deep_non_images_do_not_create_path_objects(self):
        with tempfile.TemporaryDirectory() as folder:
            root=pathlib.Path(folder)
            for branch in range(10):
                nested=root/f'branch-{branch}'/'one'/'two'
                nested.mkdir(parents=True)
                for item in range(300):
                    (nested/f'entry-{item:03}.txt').write_text('not an image')
            original_path=wallpaper_service.pathlib.Path
            with patch.object(wallpaper_service.pathlib, 'Path', wraps=original_path) as path_type:
                self.assertEqual(image_library(folder),[])
            self.assertLess(path_type.call_count, 100)


if __name__=='__main__':unittest.main()
