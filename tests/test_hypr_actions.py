import json
import pathlib
import subprocess
import sys
import unittest
from unittest.mock import Mock,patch
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]))
from hypr_actions import HyprActions


class HyprActionsTests(unittest.TestCase):
    def test_lua_uses_live_window_and_native_dispatchers(self):
        run=Mock(return_value='ok');actions=HyprActions(run)
        actions.focus('0x123abc')
        code=run.call_args.args[0][2]
        self.assertEqual(run.call_args.args[0][:2],['hyprctl','eval'])
        self.assertIn('hl.get_window("address:0x123abc")',code)
        self.assertLess(code.index('workspace=w.workspace'),code.index('window=w'))
        self.assertIn('monitor=w.monitor',code)
        actions.workspace(4)
        self.assertIn('hl.dsp.focus({workspace="4"})',run.call_args.args[0][2])
        self.assertEqual(sum(c.args[0]==['hyprctl','eval','return true'] for c in run.call_args_list),1)

    def test_legacy_reads_current_workspace(self):
        run=Mock(side_effect=[ValueError('unsupported'),json.dumps([{'address':'0x123','mapped':True,'workspace':{'id':9,'name':'9'}}]),'ok','ok'])
        HyprActions(run).focus('0x123')
        self.assertEqual(run.call_args_list[-2].args[0],['hyprctl','dispatch','workspace','9'])
        self.assertEqual(run.call_args_list[-1].args[0],['hyprctl','dispatch','focuswindow','address:0x123'])

    def test_input_validation(self):
        run=Mock();actions=HyprActions(run)
        for value in ('0x123;exit','bad',None):
            with self.assertRaises(ValueError):actions.focus(value)
        for value in (True,0,'2',1.5):
            with self.assertRaises(ValueError):actions.workspace(value)
        run.assert_not_called()

    def test_compositor_error_despite_zero_exit(self):
        with patch('hypr_actions.subprocess.run',return_value=subprocess.CompletedProcess([],0,'error: bad dispatcher','')):
            with self.assertRaises(ValueError):HyprActions._run(['hyprctl','dispatch','bad'])


if __name__=='__main__':unittest.main()
