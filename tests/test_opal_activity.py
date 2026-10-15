import json, pathlib, sys, tempfile, types, unittest
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'src'))
import opal_activity as oa


class Calls:
    def __init__(self, take=()):
        self.log = []; self.take = list(take)
    def __call__(self, function, *args):
        self.log.append((function,) + args)
        if function == 'take': return self.take.pop(0) if self.take else ''
        return args[0] if function == 'start' else ''
    def started(self): return [json.loads(c[1]) for c in self.log if c[0] == 'start']


class CliTests(unittest.TestCase):
    def test_actions_and_progress(self):
        self.assertEqual(oa.parse_action('allow:Allow:primary'), {'id': 'allow', 'label': 'Allow', 'primary': True})
        self.assertEqual(oa.parse_action('stop'), {'id': 'stop', 'icon': 'stop'})
        self.assertEqual(oa.parse_action('x:Delete:danger:delete'), {'id': 'x', 'label': 'Delete', 'danger': True, 'icon': 'delete'})
        args = types.SimpleNamespace(id='b', kind='system', icon=None, title='Build', subtitle=None, short=None, meta=None, code=None, ring_text=None,
                                     progress='40%', text='2 of 5', app=None, ttl=None, urgent=False, ring=False, action=['cancel:Cancel'], pid=None)
        data = oa.activity_from(args)
        self.assertAlmostEqual(data['progress'], .4)
        self.assertEqual(data['controls'][0]['label'], 'Cancel')
        args.progress = 'busy'
        self.assertEqual(oa.activity_from(args)['progress'], -2)

    def test_wait_polls_until_a_press_or_timeout(self):
        t = [0.0]
        calls = Calls(take=['', '', 'allow'])
        self.assertEqual(oa.wait('job', 5, clock=lambda: t[0], sleep=lambda s: t.__setitem__(0, t[0] + s), call=calls), 'allow')
        t[0] = 0.0
        self.assertEqual(oa.wait('job', 1, clock=lambda: t[0], sleep=lambda s: t.__setitem__(0, t[0] + s), call=Calls()), '')

    def test_process_chain(self):
        with tempfile.TemporaryDirectory() as tmp:
            for pid, parent in ((30, 20), (20, 10), (10, 1)):
                pathlib.Path(tmp, str(pid)).mkdir()
                pathlib.Path(tmp, str(pid), 'stat').write_text(f'{pid} (a b) S {parent} 0 0')
            self.assertEqual(oa.process_chain(30, proc=pathlib.Path(tmp)), [30, 20, 10])


class ClaudeHookTests(unittest.TestCase):
    event = {'session_id': 'abc-123', 'cwd': '/home/u/opal'}

    def test_prompt_and_stop_and_end(self):
        calls = Calls()
        oa.claude_hook(dict(self.event, hook_event_name='UserPromptSubmit', prompt='fix it'), call=calls, ppid=0)
        oa.claude_hook(dict(self.event, hook_event_name='Stop'), call=calls, ppid=0)
        oa.claude_hook(dict(self.event, hook_event_name='SessionEnd'), call=calls, ppid=0)
        started = calls.started()
        self.assertEqual(started[0]['id'], 'cc-abc123'); self.assertEqual(started[0]['progress'], -2)
        self.assertEqual(started[1]['ttl'], 8)
        self.assertEqual(calls.log[-1], ('end', 'cc-abc123'))

    def test_permission_request_allow_from_the_pill(self):
        calls = Calls()
        event = dict(self.event, hook_event_name='PermissionRequest', tool_name='Bash', tool_input={'command': 'git push'})
        out = oa.claude_hook(event, call=calls, focused=lambda chain: False, waiter=lambda ident, timeout: 'allow', ppid=0)
        self.assertEqual(json.loads(out)['hookSpecificOutput']['decision'], {'behavior': 'allow'})
        self.assertEqual(calls.started()[0]['code'], 'git push')
        deny = oa.claude_hook(event, call=Calls(), focused=lambda chain: False, waiter=lambda ident, timeout: 'deny', ppid=0)
        self.assertEqual(json.loads(deny)['hookSpecificOutput']['decision']['behavior'], 'deny')

    def test_permission_request_steps_aside_when_the_terminal_has_focus_or_on_timeout(self):
        event = dict(self.event, hook_event_name='PermissionRequest', tool_name='Edit', tool_input={'file_path': '/x'})
        waited = []
        self.assertEqual(oa.claude_hook(event, call=Calls(), focused=lambda chain: True, waiter=lambda *a: waited.append(a) or 'allow', ppid=0), '')
        self.assertEqual(waited, [])
        self.assertEqual(oa.claude_hook(event, call=Calls(), focused=lambda chain: False, waiter=lambda *a: '', ppid=0), '')

    def test_install_and_remove_keep_other_hooks(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = pathlib.Path(tmp, 'settings.json')
            path.write_text(json.dumps({'model': 'x', 'hooks': {'Stop': [{'matcher': '', 'hooks': [{'type': 'command', 'command': 'mine'}]}]}}))
            oa.install_hooks(path); oa.install_hooks(path)
            data = json.loads(path.read_text())
            self.assertEqual(len(data['hooks']['Stop']), 2)
            self.assertEqual(data['hooks']['PermissionRequest'][0]['hooks'][0]['timeout'], 120)
            self.assertTrue(data['hooks']['Notification'][0]['hooks'][0]['async'])
            oa.install_hooks(path, remove=True)
            data = json.loads(path.read_text())
            self.assertEqual(data['hooks'], {'Stop': [{'matcher': '', 'hooks': [{'type': 'command', 'command': 'mine'}]}]})
            self.assertEqual(data['model'], 'x')


if __name__ == '__main__':
    unittest.main()
