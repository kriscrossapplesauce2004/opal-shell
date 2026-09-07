import os
import pathlib
import shutil
import subprocess
import sys
import tempfile
import unittest
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]))
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

    def test_selector_injection_rejected(self):
        with tempfile.TemporaryDirectory() as runtime:
            with self.assertRaises(ValueError):publish(runtime,'phone',[{'name':'x] w[1','mode':'phone'}])

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
            local dismiss=false; local cards=false
            for _,r in ipairs(layers) do
                if r.match.namespace=="^opal-(audio|shade)-dismiss$" then dismiss=r.blur==false end
                if r.match.namespace=="^opal-(audio|shade)$" then cards=r.blur==true end
            end
            assert(dismiss and cards, "New panels must not blur their click-away surfaces")
            '''
            test=pathlib.Path(home,'test.lua');test.write_text(script)
            subprocess.run(['lua',str(test),str(pathlib.Path(__file__).resolve().parents[1]/'hyprland.lua')],check=True,env={**os.environ,'HOME':home,'XDG_RUNTIME_DIR':home})


if __name__=='__main__':unittest.main()
