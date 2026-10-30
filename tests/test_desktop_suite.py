"""Checks the desktop suite task file and its step primitives against a fake hyprctl."""
import importlib.util, json, os, pathlib, subprocess, stat, sys, tempfile, unittest
from unittest import mock

HERE = pathlib.Path(__file__).resolve().parent / 'desktop-suite'
SPEC = importlib.util.spec_from_file_location('desktop_suite_run', HERE / 'run.py')
run = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(run)

FAKE_SIG = 'efb50993780079460b0cbed1363e2166a2de1d9f_1793244901_1963158323'
FAKE_HYPRCTL = '''#!%s
import json, os, sys
state = json.load(open(os.environ["FAKE_HYPRCTL_STATE"]))
args = sys.argv[1:]
with open(os.environ["FAKE_HYPRCTL_LOG"], "a") as log:
    log.write(json.dumps({"argv": args, "sig": os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")}) + "\\n")
if args[:2] == ["-j", "clients"]:
    print(json.dumps(state["clients"]))
elif args[:2] == ["-j", "monitors"]:
    print(json.dumps(state["monitors"]))
elif args[:2] == ["-j", "workspaces"]:
    print(json.dumps(state["workspaces"]))
elif args[:2] == ["-j", "activewindow"]:
    print(json.dumps(state["clients"][0] if state["clients"] else {}))
elif args[:3] == ["-j", "getoption", "general:layout"]:
    print(json.dumps({"option": "general:layout", "str": state["layout"]}))
else:
    print("ok")
''' % sys.executable

MONITORS = [{'id': 0, 'name': 'WAYLAND-1', 'x': 0, 'y': 0, 'width': 1600, 'height': 1000, 'scale': 1,
             'focused': True, 'transform': 0, 'activeWorkspace': {'id': 2, 'name': '2'}}]
CLIENTS = [
    {'address': '0x1', 'mapped': True, 'at': [0, 0], 'size': [800, 900], 'monitor': 0, 'floating': False,
     'fullscreen': 0, 'workspace': {'id': 2, 'name': '2'}, 'class': 'kitty', 'title': 'suite-1'},
    {'address': '0x2', 'mapped': True, 'at': [810, 0], 'size': [790, 900], 'monitor': 0, 'floating': False,
     'fullscreen': 0, 'workspace': {'id': 2, 'name': '2'}, 'class': 'kitty', 'title': 'suite-2'},
    {'address': '0x3', 'mapped': True, 'at': [1700, 0], 'size': [100, 100], 'monitor': 0, 'floating': True,
     'fullscreen': 0, 'workspace': {'id': 1, 'name': '1'}, 'class': 'kitty', 'title': 'suite-3'},
]


class TaskFileTests(unittest.TestCase):
    def setUp(self):
        self.tasks = run.load_tasks()

    def test_exactly_100_unique_tasks(self):
        self.assertEqual(len(self.tasks), 100)
        self.assertEqual(len({t.id for t in self.tasks}), 100)

    def test_required_fields_and_enums(self):
        for task in self.tasks:
            self.assertIn(task.area, run.AREAS, task.id)
            self.assertIn(task.automation, run.AUTOMATION, task.id)
            self.assertTrue(task.title, task.id)
            self.assertTrue(task.steps and task.expected, task.id)
            self.assertTrue(set(task.needs) <= set(run.NEEDS), task.id)
            self.assertTrue(task.needs, task.id)

    def test_auto_tasks_have_actions_and_checks(self):
        auto = [t for t in self.tasks if t.automation == 'auto']
        self.assertGreaterEqual(len(auto), 20)
        for task in auto:
            self.assertTrue(task.actions and task.checks, task.id)
        for task in self.tasks:
            if task.automation != 'auto':
                self.assertEqual((task.actions, task.checks), ([], []), task.id)

    def test_every_area_has_a_task(self):
        self.assertEqual({t.area for t in self.tasks}, set(run.AREAS))

    def test_bad_task_entries_are_refused(self):
        good = {'id': 'x-one', 'area': 'windows', 'title': 't', 'steps': ['s'], 'expected': ['e'],
                'needs': ['vm'], 'automation': 'semi'}
        run.validate_task(dict(good))
        for key, value in (('area', 'bogus'), ('automation', 'sometimes'), ('needs', ['laptop']),
                           ('id', 'Bad_ID')):
            with self.assertRaises(run.TaskError):
                run.validate_task(dict(good, **{key: value}))
        with self.assertRaises(run.TaskError):
            run.validate_task({k: v for k, v in good.items() if k != 'expected'})
        with self.assertRaises(run.TaskError):
            run.validate_task(dict(good, automation='auto'))
        with self.assertRaises(run.TaskError):
            run.validate_task(dict(good, actions=['workspace 1']))

    def test_filters_select_by_area_needs_and_automation(self):
        vm = run.select(self.tasks, needs=['vm'])
        self.assertTrue(vm and all('vm' in t.needs for t in vm))
        autos = run.select(self.tasks, automation=['auto'], areas=['clipboard'])
        self.assertEqual({t.id for t in autos}, {'clip-copy-paste-roundtrip', 'clip-history-ipc'})
        self.assertEqual([t.id for t in run.select(self.tasks, only=['win-tile-three'])], ['win-tile-three'])


class ParserTests(unittest.TestCase):
    def test_bad_actions_are_refused(self):
        for line in ('jump 2', 'workspace one', 'window title=x explode', 'layout grid', 'output create real',
                     'sleep soon', 'spawn', 'wait 5', 'window title=x to-monitor', 'output rotate last 4'):
            with self.assertRaises(run.TaskError, msg=line):
                run.parse_action(line)

    def test_good_actions_parse(self):
        self.assertEqual(run.parse_action('workspace 2'), ('workspace', '2'))
        self.assertEqual(run.parse_action('wait 5 clients.count[ws=2] == 1')[0], 'wait')
        run.parse_action('window title=suite-1 place 1 2 3 4')
        run.parse_action('output remove last')

    def test_bad_checks_are_refused(self):
        for text in ('bogus.field == 1', 'window[title=x] == 1', 'monitor[WAYLAND-1]..width == 1',
                     'monitor[WAYLAND-1] == 1'):
            with self.assertRaises(run.TaskError, msg=text):
                run.parse_check(text)

    def test_compare_handles_bools_numbers_and_text(self):
        self.assertEqual(run.compare(True, '==', 'true'), (True, 'true'))
        self.assertEqual(run.compare(3, '>=', '2'), (True, '3'))
        self.assertEqual(run.compare(None, '==', '""'), (True, ''))
        self.assertEqual(run.compare('HEADLESS-2', 'contains', 'HEADLESS')[0], True)
        self.assertEqual(run.compare('abc', '<', '2')[0], False)

    def test_window_code_uses_lua_dispatchers(self):
        self.assertIn('window.float({action="enable"', run.window_code('0x1', 'float', ['on']))
        self.assertIn('fullscreen_state', run.window_code('0x1', 'fullscreen', ['0']))
        code = run.window_code('0x1', 'move', ['4', 'follow'])
        self.assertIn('workspace="4",follow=false', code)
        self.assertIn('focus({workspace="4"})', code)
        self.assertIn('exact=true', run.window_code('0x1', 'place', ['1', '2', '3', '4']))
        with self.assertRaises(run.TaskError):
            run.lua_window('0x1; os.exit()', 'x')


class FakeHyprctlTests(unittest.TestCase):
    """Runs the real subprocess path against a fake hyprctl on PATH."""

    def setUp(self):
        self.dir = tempfile.mkdtemp()
        script = pathlib.Path(self.dir, 'hyprctl')
        script.write_text(FAKE_HYPRCTL)
        script.chmod(script.stat().st_mode | stat.S_IEXEC)
        self.state = pathlib.Path(self.dir, 'state.json')
        self.log = pathlib.Path(self.dir, 'log.jsonl')
        self.state.write_text(json.dumps({'clients': CLIENTS, 'monitors': MONITORS, 'layout': 'dwindle',
                                          'workspaces': [{'id': 2, 'name': '2', 'windows': 2}]}))
        env = {'PATH': self.dir + os.pathsep + os.environ['PATH'], 'FAKE_HYPRCTL_STATE': str(self.state),
               'FAKE_HYPRCTL_LOG': str(self.log)}
        self.patch = mock.patch.dict(os.environ, env)
        self.patch.start()
        self.session = run.Session(FAKE_SIG, None, None, self.dir, owned=False)
        self.run_ = run.TaskRun(self.session, run.Task('t-one', 'windows', 'x', ['s'], ['e'], ['nested-hyprland'],
                                                       'auto'))

    def tearDown(self):
        self.patch.stop()

    def calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []

    def test_every_call_carries_the_explicit_signature(self):
        self.run_.act('workspace 2')
        self.assertTrue(self.calls())
        self.assertTrue(all(c['sig'] == FAKE_SIG for c in self.calls()))

    def test_workspace_action_sends_lua_focus(self):
        self.run_.act('workspace 3')
        last = self.calls()[-1]['argv']
        self.assertEqual(last[0], 'eval')
        self.assertEqual(last[1], 'hl.dispatch(hl.dsp.focus({workspace="3"}))')

    def test_queries_read_the_fake_state(self):
        self.assertTrue(self.run_.evaluate('clients.count[ws=2] == 2')[0])
        self.assertTrue(self.run_.evaluate('clients.count[ws=2,floating=false] == 2')[0])
        self.assertTrue(self.run_.evaluate('active.title == suite-1')[0])
        self.assertTrue(self.run_.evaluate('window[title=suite-3].floating == true')[0])
        self.assertTrue(self.run_.evaluate('clients.outside[ws=2] == 0')[0])
        self.assertTrue(self.run_.evaluate('monitor[WAYLAND-1].width == 1600')[0])

    def test_workspace_query_reads_the_focused_space(self):
        # Regression: an empty bracket group once made workspace.current read 0.
        self.assertEqual(self.run_.query('workspace.current'), 2)
        self.assertEqual(self.run_.query('workspace.name'), '2')
        self.assertEqual(self.run_.query('layout'), 'dwindle')

    def test_check_side_can_be_a_query(self):
        self.assertTrue(self.run_.evaluate('window[title=suite-1].width < monitor[WAYLAND-1].width')[0])

    def test_clients_outside_counts_windows_past_the_edge(self):
        state = json.loads(self.state.read_text())
        state['clients'][0]['at'] = [1500, 0]
        self.state.write_text(json.dumps(state))
        self.assertEqual(self.run_.query('clients.outside[ws=2]'), 1)

    def test_missing_window_reads_none_and_polls_to_failure(self):
        self.assertIsNone(self.run_.query('window[title=nope].width'))
        with self.assertRaises(run.Fail):
            self.run_.expect('window[title=nope].width == 1', 0.2)

    def test_headless_output_create_and_remove(self):
        state = json.loads(self.state.read_text())
        original = list(state['monitors'])

        def fake_create(args, env=None, timeout=5.0):
            # Simulate hyprctl adding a headless monitor.
            current = json.loads(self.state.read_text())
            current['monitors'].append(dict(original[0], id=1, name='HEADLESS-1', x=1600))
            self.state.write_text(json.dumps(current))
            return 0, 'ok', ''

        real_call = run.Hypr.call

        def routed(hypr, args):
            # Only the output create call is faked; reads go to the fake hyprctl.
            if args[:3] == ['hyprctl', 'output', 'create']:
                return fake_create(args)[1]
            return real_call(hypr, args)

        with mock.patch.object(run.Hypr, 'call', routed):
            self.run_.act('output create headless')
        self.assertEqual(self.run_.created_outputs, ['HEADLESS-1'])
        self.assertEqual(self.run_.query('monitors.count'), 2)
        self.assertEqual(self.run_.query('monitors.names'), 'WAYLAND-1,HEADLESS-1')

    def test_teardown_closes_only_new_windows(self):
        self.session.baseline = {'0x1', '0x2'}
        self.run_.teardown()
        closes = [c for c in self.calls() if c['argv'][:1] == ['eval'] and 'window.close' in c['argv'][1]]
        self.assertEqual(len(closes), 1)
        self.assertIn('address:0x3', closes[0]['argv'][1])

    def test_missing_tool_is_blocked_not_crashed(self):
        self.session.socket = 'wayland-9'
        with mock.patch.dict(os.environ, {'PATH': self.dir}):
            with self.assertRaises(run.Blocked):
                self.session.clipboard_get()

    def test_no_socket_means_clipboard_is_blocked(self):
        with self.assertRaises(run.Blocked):
            self.session.clipboard_set('x')

    def test_ipc_without_a_shell_is_blocked(self):
        with self.assertRaises(run.Blocked):
            self.session.ipc(['inspect'])

    def test_run_one_reports_fail_and_still_tears_down(self):
        task = run.Task('t-two', 'windows', 'x', ['s'], ['e'], ['nested-hyprland'], 'auto',
                        ['workspace 1'], ['clients.count[ws=9] == 1'])
        result = run.run_one(self.session, task)
        self.assertEqual(result['status'], 'fail')
        self.assertIn('clients.count[ws=9] == 1', result['detail'])
        self.assertTrue(any('window.close' in c['argv'][1] for c in self.calls() if c['argv'][:1] == ['eval']))

    def test_run_one_skips_tasks_needing_hardware(self):
        task = run.Task('t-three', 'audio', 'x', ['s'], ['e'], ['vm'], 'auto', ['workspace 1'], ['layout == dwindle'])
        self.assertEqual(run.run_one(self.session, task)['status'], 'skipped')


class CleanupAndSafetyTests(unittest.TestCase):
    def test_empty_signature_is_refused(self):
        with self.assertRaises(SystemExit):
            run.check_signature('', None)
        with self.assertRaises(SystemExit):
            run.attach('', False)

    def test_malformed_signature_is_refused(self):
        for value in ('wayland-2', '../../etc', 'abc def', '*'):
            with self.assertRaises(SystemExit, msg=value):
                run.check_signature(value, None)

    def test_live_signature_is_refused_without_the_flag(self):
        with mock.patch.dict(os.environ, {'HYPRLAND_INSTANCE_SIGNATURE': FAKE_SIG}):
            with self.assertRaises(SystemExit):
                run.check_signature(FAKE_SIG, FAKE_SIG)
            with self.assertRaises(SystemExit):
                run.attach(FAKE_SIG, False)

    def test_the_live_signature_is_refused_even_when_nested_looking(self):
        # The live session check runs before any hyprctl call, so no call reaches it.
        with mock.patch.object(run, 'Hypr') as hypr:
            with mock.patch.dict(os.environ, {'HYPRLAND_INSTANCE_SIGNATURE': FAKE_SIG}):
                with self.assertRaises(SystemExit):
                    run.attach(FAKE_SIG, False)
            hypr.assert_not_called()

    def test_valid_nested_signature_passes_the_guard(self):
        run.check_signature(FAKE_SIG, 'something_else_1_2')

    def test_stop_signals_only_processes_the_harness_started(self):
        mine = subprocess.Popen(['sleep', '30'], start_new_session=True)
        session = run.Session(FAKE_SIG, None, None, tempfile.mkdtemp(), owned=True)
        session.procs = [mine]
        with mock.patch.object(run.os, 'kill') as kill, \
                mock.patch.object(run.os, 'killpg', wraps=os.killpg) as killpg:
            session.stop()
        kill.assert_not_called()
        self.assertEqual([c.args[0] for c in killpg.call_args_list], [mine.pid])
        self.assertIsNotNone(mine.poll())

    def test_attached_sessions_own_nothing_to_stop(self):
        session = run.Session(FAKE_SIG, None, None, tempfile.mkdtemp(), owned=False)
        session.procs = [mock.Mock(pid=4242)]
        with mock.patch.object(run.os, 'killpg') as killpg, mock.patch.object(run.os, 'kill') as kill:
            session.stop()
        killpg.assert_not_called()
        kill.assert_not_called()


class CommandLineTests(unittest.TestCase):
    def cli(self, *args):
        return subprocess.run([sys.executable, str(HERE / 'run.py'), *args], capture_output=True, text=True,
                              timeout=60)

    def test_list_counts_one_hundred(self):
        done = self.cli('--list')
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertIn('100 tasks', done.stdout)

    def test_dry_run_prints_plan_without_hyprctl(self):
        done = self.cli('--dry-run', '--only', 'win-snap-left')
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertIn('check: window[title=suite-snap].x <= 16', done.stdout)

    def test_attach_refuses_the_live_signature(self):
        env = dict(os.environ, HYPRLAND_INSTANCE_SIGNATURE=FAKE_SIG)
        done = subprocess.run([sys.executable, str(HERE / 'run.py'), '--signature', FAKE_SIG, '--only',
                               'win-tile-three'], capture_output=True, text=True, timeout=60, env=env)
        self.assertEqual(done.returncode, 2)
        self.assertIn('Refusing', done.stderr)


if __name__ == '__main__':
    unittest.main()
