import json
import pathlib
import subprocess
import sys
import unittest
from unittest.mock import Mock,patch
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1] / 'src'))
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

    def test_lua_fullscreen_uses_string_modes_and_window_target(self):
        run=Mock(return_value='ok');actions=HyprActions(run)
        actions.fullscreen('0xabc',1)
        code=run.call_args.args[0][2]
        self.assertIn('mode="maximized",action="set",window=w',code)
        actions.fullscreen('0xabc',2)
        self.assertIn('mode="fullscreen",action="set",window=w',run.call_args.args[0][2])
        actions.fullscreen('0xabc',0)
        self.assertIn('fullscreen_state({internal=0,client=0,action="set",window=w})',run.call_args.args[0][2])
        self.assertFalse(any('hl.dsp.focus' in str(c) for c in run.call_args_list))

    def test_move_uses_native_window_move_and_validates(self):
        run=Mock(return_value='ok');actions=HyprActions(run)
        actions.move('0xabc',3,follow=True)
        code=run.call_args.args[0][2]
        self.assertIn('hl.dsp.window.move({workspace="3",window=w})',code)
        self.assertIn('hl.dsp.focus({window=w})',code)
        legacy=Mock(side_effect=[ValueError('unsupported'),'ok'])
        HyprActions(legacy).move('0xabc',5)
        self.assertEqual(legacy.call_args.args[0],['hyprctl','dispatch','movetoworkspacesilent','5,address:0xabc'])
        with self.assertRaises(ValueError):actions.move('0xabc;x',2)
        with self.assertRaises(ValueError):actions.move('0xabc',0)

    def test_legacy_reads_current_workspace(self):
        run=Mock(side_effect=[ValueError('unsupported'),json.dumps([{'address':'0x123','mapped':True,'workspace':{'id':9,'name':'9'}}]),'ok','ok'])
        HyprActions(run).focus('0x123')
        self.assertEqual(run.call_args_list[-2].args[0],['hyprctl','dispatch','workspace','9'])
        self.assertEqual(run.call_args_list[-1].args[0],['hyprctl','dispatch','focuswindow','address:0x123'])

    def test_legacy_scans_volume_and_reads_live_workspace_each_time(self):
        clients=[{'address':f'0x{i:x}','mapped':True,'workspace':{'id':(i%23)+1,'name':str((i%23)+1)}} for i in range(2048)]
        address='0x7ff'
        responses=[]
        def run(command):
            responses.append(command)
            if command==['hyprctl','-j','clients']:
                return json.dumps(clients)
            return 'ok'
        actions=HyprActions(run)
        actions.is_lua=lambda:False
        actions.focus(address)
        clients[-1]['workspace']['id']=31
        actions.focus(address)
        workspace_commands=[command for command in responses if command[:3]==['hyprctl','dispatch','workspace']]
        self.assertEqual(workspace_commands, [
            ['hyprctl','dispatch','workspace','1'],
            ['hyprctl','dispatch','workspace','31'],
        ])
        self.assertEqual(len([command for command in responses if command==['hyprctl','-j','clients']]),2)

    def test_input_validation(self):
        run=Mock();actions=HyprActions(run)
        for value in ('0x123;exit','0x123\nexit','0X123','bad',None):
            with self.assertRaises(ValueError):actions.focus(value)
        for value in (True,0,2147483648,'2',1.5):
            with self.assertRaises(ValueError):actions.workspace(value)
        run.assert_not_called()

    def test_command_builders_keep_native_syntax_and_reject_injection(self):
        self.assertEqual(
            HyprActions._lua_focus_code('0xabc'),
            'local w=hl.get_window("address:0xabc"); '
            'assert(w and w.mapped,"Window is no longer available"); '
            'if w.monitor then hl.dispatch(hl.dsp.focus({monitor=w.monitor})) end; '
            'if w.workspace then hl.dispatch(hl.dsp.focus({workspace=w.workspace})) end; '
            'hl.dispatch(hl.dsp.focus({window=w}))')
        self.assertEqual(
            HyprActions._lua_workspace_code(7),
            'hl.dispatch(hl.dsp.focus({workspace="7"}))')
        with self.assertRaises(ValueError):
            HyprActions._validate_address('0xabc"; os.execute("bad")')

    def test_compositor_error_despite_zero_exit(self):
        with patch('hypr_actions.subprocess.run',return_value=subprocess.CompletedProcess([],0,'error: bad dispatcher','')):
            with self.assertRaises(ValueError):HyprActions._run(['hyprctl','dispatch','bad'])


if __name__=='__main__':unittest.main()
