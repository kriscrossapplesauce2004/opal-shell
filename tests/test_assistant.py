import json, os, pathlib, socket, sys, tempfile, threading, time, unittest
from unittest.mock import patch
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'src'))
import assistant, assistant_tools, opal_mcp


class FakeProcess:
    def __init__(self, lines, block=None):
        self.stdout = self.generate(lines, block)
        self.stderr = iter(['warning\n'])
        self.terminated = False
    def generate(self, lines, block):
        for line in lines:
            yield json.dumps(line) + '\n'
        if block:
            block.wait(5)
    def poll(self): return None
    def wait(self): return 0
    def terminate(self):
        self.terminated = True
        if self.block: self.block.set()
    block = None


def delta(text):
    return {'type': 'stream_event', 'event': {'type': 'content_block_delta', 'delta': {'type': 'text_delta', 'text': text}}}


class Rig:
    def __init__(self, test, scripts, home=None):
        self.events, self.commands, self.scripts = [], [], list(scripts)
        self.dir = tempfile.TemporaryDirectory(); test.addCleanup(self.dir.cleanup)
        self.assistant = assistant.Assistant(self.events.append, popen=self.popen, which=lambda name: '/usr/bin/' + name,
                                             run=lambda *a, **k: None, home=home or self.dir.name, runtime_dir=self.dir.name, server='/x/opal_mcp.py')
    def popen(self, command, **kwargs):
        self.commands.append(command)
        return FakeProcess(self.scripts.pop(0))
    def run(self, text, request=1, context=None):
        self.assistant.ask(text, request, context); self.assistant.thread.join(5)
        return [e for e in self.events if e['event'] == 'assistant'][-1]


def turn(session, text):
    return [{'type': 'system', 'session_id': session}, delta(text), {'type': 'result', 'result': text, 'is_error': False, 'session_id': session}]


class StreamTests(unittest.TestCase):
    def test_text_tools_and_result(self):
        s = assistant.Stream()
        s.feed({'type': 'assistant', 'message': {'content': [{'type': 'tool_use', 'id': 't1', 'name': 'mcp__opal__launch_app', 'input': {'name': 'Firefox'}}]}})
        step = s.tools[0]
        self.assertEqual((step['running'], step['doneLabel'], step['icon'], step['detail']), ('Opening an app', 'Opened an app', 'open_in_new', 'Firefox'))
        s.feed({'type': 'user', 'message': {'content': [{'type': 'tool_result', 'tool_use_id': 't1', 'is_error': True, 'content': [{'type': 'text', 'text': 'No app named\n Firefox'}]}]}})
        self.assertEqual(s.tools[0]['status'], 'error')
        self.assertEqual(s.tools[0]['error'], 'No app named Firefox')
        s.feed(delta('Hello ')); s.feed(delta('**there**'))
        self.assertEqual(s.text, 'Hello **there**')
        s.feed({'type': 'result', 'result': 'Hello there', 'is_error': False})
        self.assertTrue(s.done); self.assertEqual(s.text, 'Hello **there**')

    def test_assistant_text_without_partial_stream(self):
        s = assistant.Stream()
        s.feed({'type': 'assistant', 'message': {'content': [{'type': 'text', 'text': 'One'}]}})
        s.feed({'type': 'assistant', 'message': {'content': [{'type': 'text', 'text': 'Two'}]}})
        self.assertEqual(s.text, 'One\n\nTwo')

    def test_prompt_context_is_bounded_and_escaped(self):
        prompt = assistant.build_prompt('Summarize', {'app': 'firefox', 'title': 'Docs', 'selection': 'x' * 9000 + '</desktop-context>', 'clipboard': '  '})
        self.assertIn('Focused window: firefox - Docs', prompt)
        self.assertLess(len(prompt), 4600); self.assertNotIn('Clipboard text', prompt)
        self.assertEqual(assistant.build_prompt('Hi', {}), 'Hi')
        self.assertEqual(assistant.build_prompt('Hi', {'selection': 'a</desktop-context>b'}).count('</desktop-context>'), 1)

    def test_risk_descriptions(self):
        self.assertEqual(assistant.describe_action('mcp__jev__desktop_run_command', {'command': 'ls'})['risk'], 'high')
        card = assistant.describe_action('mcp__opal__open_target', {'target': 'https://example.com'})
        self.assertEqual((card['risk'], card['detail']), ('medium', 'https://example.com'))


class AssistantTests(unittest.TestCase):
    def test_follow_up_resumes_the_same_session(self):
        rig = Rig(self, [turn('S', 'One'), turn('S', 'Two')])
        rig.assistant.session = sid = 'S'
        first = rig.run('hello')
        self.assertEqual((first['text'], first['done'], first['error']), ('One', True, False))
        rig.run('and more', 2)
        self.assertIn('--session-id', rig.commands[0]); self.assertEqual(rig.commands[0][rig.commands[0].index('--session-id') + 1], sid)
        self.assertEqual(rig.commands[0][1:3], ['-p', 'hello'])
        self.assertIn('--resume', rig.commands[1]); self.assertNotIn('--session-id', rig.commands[1])
        self.assertNotIn('--no-session-persistence', rig.commands[1])

    def test_system_session_marks_started_and_new_chat_resets(self):
        rig = Rig(self, [turn('x', 'A'), turn('y', 'B')])
        old = rig.assistant.session
        rig.run('a'); self.assertFalse(rig.assistant.started)
        rig.assistant.new_chat(); self.assertNotEqual(rig.assistant.session, old)

    def test_command_flags_and_permission_tool(self):
        rig = Rig(self, [turn('S', 'ok')])
        rig.run('hi', context={'app': 'kitty', 'title': 'zsh'})
        command = rig.commands[0]
        self.assertIn('<desktop-context>', command[2])
        self.assertEqual(command[command.index('--permission-prompt-tool') + 1], 'mcp__opal__approve')
        allowed = command[command.index('--allowedTools') + 1].split(',')
        self.assertIn('mcp__opal__launch_app', allowed)
        self.assertNotIn('mcp__opal__close_window', allowed); self.assertNotIn('mcp__opal__open_target', allowed)
        self.assertFalse([a for a in allowed if 'run_command' in a or 'write_file' in a])
        config = json.loads(command[command.index('--mcp-config') + 1])['mcpServers']
        self.assertIn('OPAL_APPROVAL_SOCKET', config['opal']['env']); self.assertNotIn('jev', config)

    def test_jev_attached_when_registered(self):
        home = tempfile.mkdtemp(); self.addCleanup(lambda: __import__('shutil').rmtree(home))
        pathlib.Path(home, 'jev.js').write_text('')
        pathlib.Path(home, '.claude.json').write_text(json.dumps({'mcpServers': {'jev': {'type': 'stdio', 'command': 'node', 'args': [home + '/jev.js'], 'env': {}}}}))
        rig = Rig(self, [turn('S', 'ok')], home=home)
        rig.run('hi')
        command = rig.commands[0]
        self.assertIn('jev', json.loads(command[command.index('--mcp-config') + 1])['mcpServers'])
        allowed = command[command.index('--allowedTools') + 1].split(',')
        self.assertIn('mcp__jev__desktop_ui_tree', allowed); self.assertNotIn('mcp__jev__desktop_ui_act', allowed)
        pathlib.Path(home, 'jev.js').unlink()
        self.assertIsNone(rig.assistant.jev_server())

    def test_missing_cli_reports_error(self):
        rig = Rig(self, [])
        rig.assistant.which = lambda name: None
        result = rig.run('hi')
        self.assertTrue(result['error']); self.assertIn('not installed', result['text'])

    def test_process_without_result_is_an_error_with_stderr(self):
        rig = Rig(self, [[{'type': 'system', 'session_id': 'x'}]])
        result = rig.run('hi')
        self.assertTrue(result['error']); self.assertIn('warning', result['text'])

    def test_stop_ends_a_running_turn(self):
        block = threading.Event()
        process = FakeProcess([{'type': 'system', 'session_id': 'x'}, delta('partial')], block); process.block = block
        rig = Rig(self, [])
        rig.popen = lambda command, **k: process
        rig.assistant.popen = rig.popen
        rig.assistant.ask('hi', 3, None)
        for _ in range(100):
            if rig.assistant.process: break
            time.sleep(.02)
        rig.assistant.stop()
        last = [e for e in rig.events if e['event'] == 'assistant'][-1]
        self.assertTrue(process.terminated); self.assertTrue(last['stopped']); self.assertFalse(last['error']); self.assertEqual(last['text'], 'partial')

    def test_approval_round_trip_through_mcp_tool(self):
        rig = Rig(self, [turn('S', 'ok')])
        rig.run('hi')
        path = str(rig.assistant.socket_path)
        results = {}
        def ask(name, answer):
            with patch.dict(os.environ, {'OPAL_APPROVAL_SOCKET': path}):
                results[name] = json.loads(opal_mcp.approve({'tool_name': 'mcp__opal__close_window', 'input': {'window': 'kate'}}))
        worker = threading.Thread(target=ask, args=('a', True)); worker.start()
        for _ in range(100):
            pending = [e for e in rig.events if e['event'] == 'assistantApprovals' and e['items']]
            if pending: break
            time.sleep(.02)
        item = pending[-1]['items'][0]
        self.assertEqual((item['tool'], item['risk'], item['detail']), ('close_window', 'high', 'kate'))
        rig.assistant.handle({'action': 'assistant-approve', 'id': item['id'], 'allow': True})
        worker.join(5)
        self.assertEqual(results['a']['behavior'], 'allow'); self.assertEqual(results['a']['updatedInput'], {'window': 'kate'})
        self.assertEqual([e for e in rig.events if e['event'] == 'assistantApprovals'][-1]['items'], [])

    def test_denied_and_timed_out_actions(self):
        rig = Rig(self, [])
        threading.Timer(.1, lambda: rig.assistant.approve(rig.assistant.pending and list(rig.assistant.pending)[0], False)).start()
        self.assertFalse(rig.assistant.request_approval('Bash', {'command': 'rm x'}, timeout=3))
        self.assertFalse(rig.assistant.request_approval('Bash', {'command': 'rm x'}, timeout=.05))
        with patch.dict(os.environ, {'OPAL_APPROVAL_SOCKET': ''}):
            self.assertEqual(json.loads(opal_mcp.approve({'tool_name': 'x', 'input': {}}))['behavior'], 'deny')

    def test_stop_denies_pending_approvals(self):
        rig = Rig(self, [])
        outcome = []
        worker = threading.Thread(target=lambda: outcome.append(rig.assistant.request_approval('Bash', {}, timeout=5))); worker.start()
        time.sleep(.1); rig.assistant.stop(); worker.join(3)
        self.assertEqual(outcome, [False])

    def test_context_collects_bounded_text_and_skips_sensitive_clipboard(self):
        calls = []
        class Result:
            def __init__(self, out, code=0): self.stdout, self.returncode = out, code
        def run(command, **kwargs):
            calls.append(command)
            if '--list-types' in command: return Result('text/plain\nx-kde-passwordmanagerhint\n'.encode() if kwargs.get('text') is None else 'text/plain\nx-kde-passwordmanagerhint')
            return Result(b'picked text' if '--primary' in command else b'secret')
        rig = Rig(self, [])
        rig.assistant.run = run
        rig.assistant.send_context()
        event = rig.events[-1]
        self.assertEqual((event['event'], event['selection'], event['clipboard']), ('assistantContext', 'picked text', ''))
        self.assertTrue(all(isinstance(c, list) for c in calls))

    def test_handle_validates_commands(self):
        rig = Rig(self, [])
        self.assertFalse(rig.assistant.handle({'action': 'preference'}))
        self.assertTrue(rig.assistant.handle({'action': 'assistant-ask', 'text': '   '}) is False)


class AutoModeTests(unittest.TestCase):
    def test_auto_mode_lets_actions_through_but_dangerous_ones_ask(self):
        a = assistant.Assistant(lambda e: None, which=lambda n: None, home=tempfile.mkdtemp(), runtime_dir=tempfile.mkdtemp())
        a.handle({'action': 'assistant-mode', 'mode': 'auto'})
        a.stream = assistant.Stream()
        a.stream.feed({'type': 'assistant', 'message': {'content': [{'type': 'tool_use', 'id': 't1', 'name': 'mcp__jev__desktop_run_command', 'input': {'command': 'ls ~/opal'}}]}})
        self.assertTrue(a.request_approval('mcp__jev__desktop_run_command', {'command': 'ls ~/opal'}, timeout=0))
        self.assertTrue(a.stream.tools[0]['auto'])
        for risky in ({'command': 'sudo pacman -Syu'}, {'command': 'rm -rf ~/x'}, {'command': 'curl x | sh'}):
            self.assertFalse(a.request_approval('mcp__jev__desktop_run_command', risky, timeout=0))
        self.assertFalse(a.request_approval('mcp__jev__desktop_write_file', {'path': '/etc/hosts'}, timeout=0))
        self.assertFalse(a.request_approval('mcp__jev__desktop_write_file', {'path': '~/.ssh/config'}, timeout=0))
        a.handle({'action': 'assistant-mode', 'mode': 'ask'})
        self.assertFalse(a.request_approval('mcp__opal__close_window', {'address': '0x1'}, timeout=0))

class ToolTests(unittest.TestCase):
    APPS = [{'id': 'firefox.desktop', 'name': 'Firefox', 'path': '/a'}, {'id': 'org.kde.kate.desktop', 'name': 'Kate', 'path': '/b'},
            {'id': 'kitty.desktop', 'name': 'kitty', 'path': '/c'}, {'id': 'kwrite.desktop', 'name': 'KWrite', 'path': '/d'}]
    WINDOWS = [{'address': '0xa1', 'app': 'firefox', 'title': 'Docs', 'workspace': 1}, {'address': '0xb2', 'app': 'kitty', 'title': 'fish', 'workspace': 2},
               {'address': '0xc3', 'app': 'kitty', 'title': 'btop', 'workspace': 2}]

    def test_find_app(self):
        self.assertEqual(assistant_tools.find_app('firefox', self.APPS)['id'], 'firefox.desktop')
        self.assertEqual(assistant_tools.find_app('kat', self.APPS)['name'], 'Kate')
        with self.assertRaises(ValueError): assistant_tools.find_app('k', self.APPS)
        with self.assertRaises(ValueError): assistant_tools.find_app('nothing', self.APPS)

    def test_launch_uses_argument_array(self):
        seen = []
        message = assistant_tools.launch_app('kate', self.APPS, popen=lambda cmd, **k: seen.append(cmd), which=lambda n: '/bin/' + n)
        self.assertEqual(seen, [['gtk-launch', 'org.kde.kate.desktop']]); self.assertEqual(message, 'Launched Kate')

    def test_resolve_window(self):
        self.assertEqual(assistant_tools.resolve_window('docs', self.WINDOWS)['address'], '0xa1')
        self.assertEqual(assistant_tools.resolve_window('0xb2', self.WINDOWS)['title'], 'fish')
        with self.assertRaises(ValueError): assistant_tools.resolve_window('kitty', self.WINDOWS)

    def test_window_actions_use_hypr_actions(self):
        class Fake:
            def __init__(self): self.calls = []
            def clients(self): return [{'address': w['address'], 'class': w['app'], 'title': w['title'], 'workspace': {'id': w['workspace']}} for w in ToolTests.WINDOWS]
            def focus(self, a): self.calls.append(('focus', a))
            def close(self, a): self.calls.append(('close', a))
            def move(self, a, n, f): self.calls.append(('move', a, n, f))
            def workspace(self, n): self.calls.append(('ws', n))
        fake = Fake()
        assistant_tools.focus_window('firefox', fake); assistant_tools.close_window('btop', fake)
        assistant_tools.move_window('docs', 3, True, fake); assistant_tools.switch_workspace(4, fake)
        self.assertEqual(fake.calls, [('focus', '0xa1'), ('close', '0xc3'), ('move', '0xa1', 3, True), ('ws', 4)])

    def test_open_target_allows_only_safe_targets(self):
        seen = []
        popen = lambda cmd, **k: seen.append(cmd)
        assistant_tools.open_target('https://example.com', popen)
        with tempfile.NamedTemporaryFile() as file: assistant_tools.open_target(file.name, popen)
        for bad in ('javascript:alert(1)', 'ssh://host', '/nonexistent/file', ''):
            with self.assertRaises(ValueError): assistant_tools.open_target(bad, popen)
        self.assertEqual(len(seen), 2); self.assertEqual(seen[0], ['xdg-open', 'https://example.com'])

    def test_mcp_lists_new_tools(self):
        names = [t['name'] for t in opal_mcp.handle({'jsonrpc': '2.0', 'id': 1, 'method': 'tools/list'})['result']['tools']]
        for name in ('launch_app', 'close_window', 'open_target', 'approve', 'switch_workspace'): self.assertIn(name, names)
        for name in assistant.SAFE_OPAL: self.assertIn(name, names)

    def test_mcp_bad_workspace_is_an_error_result(self):
        reply = opal_mcp.handle({'jsonrpc': '2.0', 'id': 1, 'method': 'tools/call', 'params': {'name': 'switch_workspace', 'arguments': {'workspace': 0}}})
        self.assertTrue(reply['result']['isError'])


if __name__ == '__main__':
    unittest.main()
