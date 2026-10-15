import os
import pathlib
import shutil
import subprocess
import sys
import tempfile
import unittest
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1] / 'src'))
from display_layouts import publish


class DisplayLayoutsTests(unittest.TestCase):
    def test_output_scope_and_restore(self):
        with tempfile.TemporaryDirectory() as runtime:
            displays=[{'name':'eDP-1','mode':'phone'},{'name':'HDMI-A-1','mode':'desktop'}]
            self.assertTrue(publish(runtime,'auto',displays))
            self.assertFalse(publish(runtime,'auto',displays))
            self.assertEqual(pathlib.Path(runtime,'opal-phone-displays').read_text(),'mode=auto\neDP-1\n')
            self.assertTrue(publish(runtime,'desktop',[{'name':'HDMI-A-1','mode':'desktop'}]))
            self.assertEqual(pathlib.Path(runtime,'opal-phone-displays').read_text(),'mode=desktop\n')

    def test_duplicate_phone_names_publish_once(self):
        with tempfile.TemporaryDirectory() as runtime:
            displays=[{'name':'eDP-1','mode':'phone'},{'name':'eDP-1','mode':'phone'}]
            self.assertTrue(publish(runtime,'phone',displays))
            self.assertEqual(pathlib.Path(runtime,'opal-phone-displays').read_text(),'mode=phone\neDP-1\n')

    def test_selector_injection_rejected(self):
        with tempfile.TemporaryDirectory() as runtime:
            with self.assertRaises(ValueError):publish(runtime,'phone',[{'name':'x] w[1','mode':'phone'}])

    def test_invalid_data_never_replaces_a_published_layout(self):
        with tempfile.TemporaryDirectory() as runtime:
            self.assertTrue(publish(runtime, 'phone', [{'name': 'eDP-1', 'mode': 'phone'}]))
            path = pathlib.Path(runtime, 'opal-phone-displays')
            with self.assertRaises(ValueError):
                publish(runtime, 'tablet', [{'name': 'eDP-1', 'mode': 'phone'}])
            self.assertEqual(path.read_text(), 'mode=phone\neDP-1\n')

    def test_large_no_write_publish_keeps_file_identity(self):
        with tempfile.TemporaryDirectory() as runtime:
            displays = [
                {'name': f'DP-{index}', 'mode': 'phone' if index % 2 else 'desktop'}
                for index in range(32)
            ]
            path = pathlib.Path(runtime, 'opal-phone-displays')
            self.assertTrue(publish(runtime, 'auto', displays))
            before = path.stat()
            outcomes = [publish(runtime, 'auto', displays) for _ in range(128)]
            after = path.stat()
            expected = 'mode=auto\n' + ''.join(
                name + '\n' for name in sorted(
                    display['name'] for display in displays if display['mode'] == 'phone'
                )
            )
            self.assertEqual(outcomes, [False] * len(outcomes))
            self.assertEqual(path.read_text(), expected)
            self.assertEqual(after.st_ino, before.st_ino)
            self.assertEqual(after.st_mtime_ns, before.st_mtime_ns)

    def test_external_change_is_replaced_on_the_next_publish(self):
        with tempfile.TemporaryDirectory() as runtime:
            displays = [{'name': 'eDP-1', 'mode': 'phone'}]
            path = pathlib.Path(runtime, 'opal-phone-displays')
            self.assertTrue(publish(runtime, 'phone', displays))
            path.write_text('mode=desktop\n')
            self.assertTrue(publish(runtime, 'phone', displays))
            self.assertEqual(path.read_text(), 'mode=phone\neDP-1\n')

    @unittest.skipUnless(shutil.which('lua'),'Lua not installed')
    def test_lua_only_squares_phone_workspace_selector(self):
        with tempfile.TemporaryDirectory() as home:
            prefs=pathlib.Path(home,'.local/state/opal/preferences.json');prefs.parent.mkdir(parents=True);prefs.write_text('{"mode":"phone"}')
            publish(home,'phone',[{'name':'eDP-1','mode':'phone'},{'name':'DP-1','mode':'desktop'}])
            script='''local rules={}; local layers={}
            hl={config=function(c) assert(c.decoration.rounding==16) end,
            workspace_rule=function(r) table.insert(rules,r) end,
            layer_rule=function(r) table.insert(layers,r) end,unbind=function() end,bind=function() end,dsp={exec_cmd=function() end}}
            dofile(arg[1])
            assert(#rules==1 and rules[1].workspace=="m[eDP-1]" and rules[1].no_rounding==true)
            local dismiss=false; local cards=false; local taskbar_menu=false
            for _,r in ipairs(layers) do
                if r.match.namespace=="^opal-(audio|shade|activity)-dismiss$" then dismiss=r.blur==false end
                if r.match.namespace=="^opal-(audio|shade)$" then cards=r.blur==true end
                if r.match.namespace=="^opal-taskbar-menu$" then taskbar_menu=r.blur==true and r.ignore_alpha==0.1 end
            end
            assert(dismiss and cards and taskbar_menu, "Panel blur rules must keep click-away regions clear")
            '''
            test=pathlib.Path(home,'test.lua');test.write_text(script)
            subprocess.run(['lua',str(test),str(pathlib.Path(__file__).resolve().parents[1]/'src'/'hyprland.lua')],check=True,env={**os.environ,'HOME':home,'XDG_RUNTIME_DIR':home})


if __name__=='__main__':unittest.main()
