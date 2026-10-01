import os
import pathlib
import tempfile
import unittest
from unittest import mock

from importlib.util import module_from_spec, spec_from_file_location


SPEC = spec_from_file_location('osk_theme', pathlib.Path(__file__).parents[1] / 'src' / 'osk_theme.py')
osk_theme = module_from_spec(SPEC)
SPEC.loader.exec_module(osk_theme)


class OskThemeTests(unittest.TestCase):
    def test_dynamic_dark_palette_reaches_squeekboard_css(self):
        preferences = {
            'light': False,
            'dynamicColors': True,
            'dynamicPalette': {'dark': {
                'primary': '#112233',
                'on_primary': '#ffffff',
                'primary_container': '#334455',
                'on_primary_container': '#ddeeff',
                'background': '#010203',
                'on_surface': '#f1f2f3',
                'on_surface_variant': '#c1c2c3',
                'surface_container': '#202122',
                'surface_container_high': '#303132',
                'outline_variant': '#505152',
            }},
        }
        css = osk_theme.css_for(preferences)
        self.assertIn('background: #112233;', css)
        self.assertIn('background-color: #202122;', css)
        self.assertIn('border-radius: 15px;', css)
        self.assertIn('font-family: "Google Sans Flex", "Inter", sans-serif;', css)
        self.assertNotIn('button {', css.replace('sq_button {', ''))

    def test_runtime_theme_is_isolated_from_normal_gtk_config(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            runtime = root / 'runtime'
            config = root / 'config'
            state = root / 'preferences.json'
            runtime.mkdir()
            (config / 'dconf').mkdir(parents=True)
            (config / 'gtk-3.0').mkdir(parents=True)
            (config / 'gtk-3.0' / 'settings.ini').write_text('[Settings]\ngtk-theme-name=Adwaita\n')
            state.write_text('{"light":true}')
            environment = {'XDG_RUNTIME_DIR': str(runtime), 'XDG_CONFIG_HOME': str(config)}
            with mock.patch.dict(os.environ, environment, clear=False):
                generated = osk_theme.prepare_runtime(state)
            self.assertEqual(generated, runtime / 'opal-osk-config')
            self.assertTrue((generated / 'gtk-3.0' / 'gtk.css').is_file())
            self.assertTrue((generated / 'gtk-3.0' / 'settings.ini').is_symlink())
            self.assertTrue((generated / 'dconf').is_symlink())
            self.assertFalse((config / 'gtk-3.0' / 'gtk.css').exists())


if __name__ == '__main__':
    unittest.main()
