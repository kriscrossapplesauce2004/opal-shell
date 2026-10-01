import os, pathlib, stat, sys, tempfile, unittest
from unittest import mock

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'src'))
import backend


class KeyboardChoiceTest(unittest.TestCase):
    def executable(self, folder, name):
        path = pathlib.Path(folder) / name
        path.write_text('#!/bin/sh\n')
        path.chmod(path.stat().st_mode | stat.S_IXUSR)
        return str(path)

    def test_borealis_is_preferred_over_squeekboard(self):
        with tempfile.TemporaryDirectory() as folder:
            borealis = self.executable(folder, 'opal-keyboard')
            squeek = self.executable(folder, 'squeekboard')
            which = {'opal-keyboard': borealis, 'squeekboard': squeek}
            with mock.patch.object(backend.shutil, 'which', side_effect=lambda n: which.get(n)), mock.patch.dict(os.environ, {'OPAL_KEYBOARD': ''}):
                command, name = backend.keyboard_command()
        self.assertEqual(name, 'Borealis')
        self.assertEqual(command, [borealis])

    def test_squeekboard_is_the_fallback(self):
        with tempfile.TemporaryDirectory() as folder:
            squeek = self.executable(folder, 'squeekboard')
            with mock.patch.object(backend.shutil, 'which', side_effect=lambda n: squeek if n == 'squeekboard' else None), \
                 mock.patch.object(backend, 'HOME', pathlib.Path(folder)), mock.patch.dict(os.environ, {'OPAL_KEYBOARD': ''}):
                command, name = backend.keyboard_command()
        self.assertEqual(name, 'Squeekboard')
        self.assertEqual(command[-1], squeek)

    def test_nothing_installed_is_reported(self):
        with tempfile.TemporaryDirectory() as folder:
            with mock.patch.object(backend.shutil, 'which', return_value=None), mock.patch.object(backend, 'HOME', pathlib.Path(folder)), mock.patch.dict(os.environ, {'OPAL_KEYBOARD': ''}):
                command, name = backend.keyboard_command()
        self.assertIsNone(command)
        self.assertIn('No system keyboard', name)


KEYBOARD = 'I: Bus=0003\nN: Name="Razer Ornata V3 X"\nH: Handlers=sysrq kbd leds event5\nB: EV=120013\n'
VIRTUAL = 'I: Bus=0006\nN: Name="ydotoold virtual device"\nH: Handlers=sysrq kbd leds event9\nB: EV=120013\n'
BUTTONS = 'I: Bus=0019\nN: Name="gpio-keys"\nH: Handlers=kbd event1\nB: EV=3\n'


class HardwareKeyboardTest(unittest.TestCase):
    def test_real_keyboard_is_detected(self):
        self.assertTrue(backend.physical_keyboard_present(BUTTONS + '\n' + KEYBOARD))

    def test_virtual_devices_and_buttons_are_ignored(self):
        self.assertFalse(backend.physical_keyboard_present(VIRTUAL + '\n' + BUTTONS))

    def test_empty_device_list(self):
        self.assertFalse(backend.physical_keyboard_present(''))


if __name__ == '__main__':
    unittest.main()
