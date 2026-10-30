"""Unit and end-to-end tests for the Compat Lab skeleton (tools/compat-lab)."""
import contextlib
import io
import json
import os
import pathlib
import shutil
import sys
import tempfile
import threading
import unittest
import urllib.request

HERE = pathlib.Path(__file__).resolve().parent
LAB_DIR = HERE.parent / 'tools' / 'compat-lab'
sys.path.insert(0, str(LAB_DIR))
import lab  # noqa: E402

ANDROID_JAVA_CRASH = """05-14 10:22:31.407 12881 12881 E AndroidRuntime: FATAL EXCEPTION: main
05-14 10:22:31.407 12881 12881 E AndroidRuntime: Process: chat.fluffy.fluffychat, PID: 12881
05-14 10:22:31.407 12881 12881 E AndroidRuntime: java.lang.NullPointerException: Attempt to invoke virtual method
05-14 10:22:31.407 12881 12881 E AndroidRuntime: \tat chat.fluffy.fluffychat.MainActivity.onCreate(MainActivity.kt:41)"""

ANDROID_ANR = """05-14 10:24:02.118  1342  1790 E ActivityManager: ANR in net.osmand.plus (net.osmand.plus/.MapActivity)
05-14 10:24:02.118  1342  1790 E ActivityManager: PID: 13055
05-14 10:24:02.118  1342  1790 E ActivityManager: Reason: Input dispatching timed out (Waiting to send non-key event)"""

ANDROID_NATIVE = ("05-14 10:25:10.552 13201 13201 F libc    : Fatal signal 11 (SIGSEGV), code 1 (SEGV_MAPERR), "
                  "fault addr 0x0 in tid 13201 (org.connectbot), pid 13201 (org.connectbot)")

MONKEY_CRASH = ":Monkey: seed=4242 count=200\n// CRASH: org.schabi.newpipe (pid 14022)\n// Monkey finished"
MONKEY_ANR = "// NOT RESPONDING: de.danoeh.antennapod (pid 15001)"

APPS_TOML = LAB_DIR / 'apps.toml'
FIXTURE = LAB_DIR / 'fixtures' / 'fake-default.json'


def quiet(fn, *args):
    """Call fn while swallowing stdout; return (result, text)."""
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf), contextlib.redirect_stderr(buf):
        result = fn(*args)
    return result, buf.getvalue()


class VerdictTests(unittest.TestCase):
    def crash(self):
        return [lab.Finding('crash', 'org.x', 'boom')]

    def anr(self):
        return [lab.Finding('anr', 'org.x', 'stuck')]

    def test_pass(self):
        self.assertEqual(lab.verdict(True, True, True, []), 'pass')

    def test_install_failure_is_fail(self):
        self.assertEqual(lab.verdict(False, False, False, []), 'fail')

    def test_crash_beats_no_launch(self):
        self.assertEqual(lab.verdict(True, True, False, self.crash()), 'crash')

    def test_anr_beats_no_launch(self):
        self.assertEqual(lab.verdict(True, True, False, self.anr()), 'anr')

    def test_crash_beats_anr(self):
        self.assertEqual(lab.verdict(True, True, True, self.anr() + self.crash()), 'crash')

    def test_not_running_is_no_launch(self):
        self.assertEqual(lab.verdict(True, True, False, []), 'no-launch')

    def test_launch_error_is_no_launch(self):
        self.assertEqual(lab.verdict(True, False, True, []), 'no-launch')

    def test_failed_smoke_step_is_fail(self):
        self.assertEqual(lab.verdict(True, True, True, [], smoke_ok=False), 'fail')


class LogcatTests(unittest.TestCase):
    def test_java_crash_is_attributed_to_process(self):
        found = lab.parse_logcat(ANDROID_JAVA_CRASH)
        self.assertEqual(len(found), 1)
        self.assertEqual((found[0].kind, found[0].process), ('crash', 'chat.fluffy.fluffychat'))
        self.assertIn('NullPointerException', found[0].detail)

    def test_anr_reads_reason(self):
        found = lab.parse_logcat(ANDROID_ANR)
        self.assertEqual((found[0].kind, found[0].process), ('anr', 'net.osmand.plus'))
        self.assertIn('Input dispatching timed out', found[0].detail)

    def test_native_crash(self):
        found = lab.parse_logcat(ANDROID_NATIVE)
        self.assertEqual((found[0].kind, found[0].process, found[0].detail), ('crash', 'org.connectbot', 'SIGSEGV'))

    def test_monkey_lines(self):
        self.assertEqual(lab.parse_monkey(MONKEY_CRASH)[0].process, 'org.schabi.newpipe')
        self.assertEqual(lab.parse_monkey(MONKEY_ANR)[0].kind, 'anr')

    def test_crash_without_process_line_is_not_attributed(self):
        text = "05-14 10:22:31.407 1 1 E AndroidRuntime: FATAL EXCEPTION: main\n05-14 10:22:31.407 1 1 E AndroidRuntime: java.lang.Error: x"
        found = lab.parse_logcat(text)
        self.assertEqual(lab.findings_for(found, 'chat.fluffy.fluffychat'), [])

    def test_findings_for_matches_subprocess_only(self):
        found = lab.parse_logcat(ANDROID_JAVA_CRASH) + lab.parse_logcat(ANDROID_ANR)
        mine = lab.findings_for(found, 'chat.fluffy.fluffychat')
        self.assertEqual([f.process for f in mine], ['chat.fluffy.fluffychat'])
        sub = [lab.Finding('crash', 'chat.fluffy.fluffychat:push', 'x')]
        self.assertEqual(len(lab.findings_for(sub, 'chat.fluffy.fluffychat')), 1)
        self.assertEqual(lab.findings_for(sub, 'chat.fluffy'), [])

    def test_clean_logcat_has_no_findings(self):
        self.assertEqual(lab.parse_logcat("05-14 10:00:00.000 1 1 I ActivityManager: Start proc"), [])


class AppListTests(unittest.TestCase):
    def test_seed_list_is_valid_and_covers_categories(self):
        apps = lab.load_apps(APPS_TOML)
        self.assertGreaterEqual(len(apps), 30)
        self.assertEqual(len({a.package for a in apps}), len(apps))
        self.assertTrue(all(a.source == 'fdroid' for a in apps))
        cats = {a.category for a in apps}
        for want in ('browser', 'maps', 'messaging', 'media', 'notes', 'keyboard', 'files', 'game'):
            self.assertIn(want, cats)
        for a in apps:
            self.assertTrue(lab.ACCOUNT_RE.match(a.test_account), a.test_account)
            self.assertEqual(a.smoke[0], 'launch')

    def write_toml(self, body):
        d = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, d, True)
        path = pathlib.Path(d) / 'apps.toml'
        path.write_text('schema = 1\n' + body, encoding='utf-8')
        return path

    def test_rejects_bad_source(self):
        p = self.write_toml('[[app]]\npackage = "org.a.b"\nsource = "play"\nabi = "x86_64-capable"\ncategory = "game"\n')
        with self.assertRaises(lab.LabError):
            lab.load_apps(p)

    def test_rejects_credential_like_account(self):
        p = self.write_toml('[[app]]\npackage = "org.a.b"\nsource = "fdroid"\nabi = "x86_64-capable"\n'
                            'category = "game"\ntest_account = "user@example.com:hunter2"\n')
        with self.assertRaises(lab.LabError):
            lab.load_apps(p)

    def test_rejects_unknown_smoke_step(self):
        p = self.write_toml('[[app]]\npackage = "org.a.b"\nsource = "fdroid"\nabi = "x86_64-capable"\n'
                            'category = "game"\nsmoke = ["launch", "tap:3"]\n')
        with self.assertRaises(lab.LabError):
            lab.load_apps(p)

    def test_apk_url_needs_sha256(self):
        p = self.write_toml('[[app]]\npackage = "org.a.b"\nsource = "apk-url"\nurl = "https://example.org/a.apk"\n'
                            'abi = "x86_64-capable"\ncategory = "game"\n')
        with self.assertRaises(lab.LabError):
            lab.load_apps(p)

    def test_fdroid_rejects_pinned_url(self):
        p = self.write_toml('[[app]]\npackage = "org.a.b"\nsource = "fdroid"\nurl = "https://example.org/a.apk"\n'
                            'abi = "x86_64-capable"\ncategory = "game"\n')
        with self.assertRaises(lab.LabError):
            lab.load_apps(p)

    def test_duplicate_package_rejected(self):
        one = '[[app]]\npackage = "org.a.b"\nsource = "fdroid"\nabi = "x86_64-capable"\ncategory = "game"\n'
        with self.assertRaises(lab.LabError):
            lab.load_apps(self.write_toml(one + one))

    def test_launch_is_added_first_when_missing(self):
        p = self.write_toml('[[app]]\npackage = "org.a.b"\nsource = "fdroid"\nabi = "x86_64-capable"\n'
                            'category = "game"\nsmoke = ["monkey:50"]\n')
        self.assertEqual(lab.load_apps(p)[0].smoke, ('launch', 'monkey:50'))


class FdroidResolveTests(unittest.TestCase):
    def index(self):
        return {
            'apps': [
                {'packageName': 'org.fast.app', 'suggestedVersionCode': 20, 'name': 'Fast'},
                {'packageName': 'org.arm.only', 'suggestedVersionCode': 5, 'name': 'Arm'},
            ],
            'packages': {
                'org.fast.app': [
                    {'versionCode': 10, 'versionName': '1.0', 'apkName': 'org.fast.app_10.apk', 'hash': 'a' * 64,
                     'hashType': 'sha256', 'size': 1, 'nativecode': ['x86_64']},
                    {'versionCode': 20, 'versionName': '2.0', 'apkName': 'org.fast.app_20.apk', 'hash': 'b' * 64,
                     'hashType': 'sha256', 'size': 2, 'nativecode': ['arm64-v8a']},
                    {'versionCode': 30, 'versionName': '3.0', 'apkName': 'org.fast.app_30.apk', 'hash': 'c' * 64,
                     'hashType': 'sha256', 'size': 3, 'nativecode': ['x86_64']},
                ],
                'org.arm.only': [
                    {'versionCode': 5, 'versionName': '0.5', 'apkName': 'org.arm.only_5.apk', 'hash': 'd' * 64,
                     'hashType': 'sha256', 'size': 4, 'nativecode': ['arm64-v8a']},
                ],
            },
        }

    def test_picks_newest_x86_build_not_above_suggested(self):
        cat = lab.fdroid_catalog(self.index())
        self.assertEqual(cat['org.fast.app']['versionCode'], 10)
        self.assertEqual(cat['org.fast.app']['hash'], 'a' * 64)

    def test_arm_only_app_has_no_entry(self):
        self.assertNotIn('org.arm.only', lab.fdroid_catalog(self.index()))


class FetchTests(unittest.TestCase):
    def setUp(self):
        self.tmp = pathlib.Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, True)
        self.payload = self.tmp / 'src.apk'
        self.payload.write_bytes(b'PK\x03\x04 test payload ' * 64)
        self.digest = lab.sha256_file(self.payload)
        self.cache = self.tmp / 'cache'

    def app(self, sha):
        return lab.App('org.test.app', 'Test', 'apk-url', 'x86_64-capable', 'game', 'none',
                       ('launch',), self.payload.as_uri(), sha)

    def test_verified_download_is_kept(self):
        entry = lab.fetch_app(self.app(self.digest), self.cache, {})
        self.assertEqual(entry['sha256'], self.digest)
        self.assertEqual(lab.sha256_file(entry['path']), self.digest)

    def test_checksum_mismatch_is_refused_and_removed(self):
        wrong = 'f' * 64
        with self.assertRaises(lab.LabError) as ctx:
            lab.fetch_app(self.app(wrong), self.cache, {})
        self.assertIn('checksum mismatch', str(ctx.exception))
        self.assertEqual(list((self.cache / 'apk').glob('*.apk')), [])

    def test_play_placeholder_is_not_fetched(self):
        app = lab.App('com.play.app', 'Play', 'play-placeholder', 'x86_64-capable', 'game', 'none', ('launch',))
        with self.assertRaises(lab.LabError):
            lab.fetch_app(app, self.cache, {})

    def test_download_failure_is_lab_error(self):
        with self.assertRaises(lab.LabError):
            lab.download((self.tmp / 'missing.apk').as_uri(), self.tmp / 'x.apk')


class DeviceTests(unittest.TestCase):
    def test_waydroid_commands_are_argument_arrays_with_timeouts(self):
        calls = []

        class Res:
            returncode = 0
            stdout = b'12345\n'

        def runner(args, timeout):
            calls.append((args, timeout))
            return Res()

        dev = lab.WaydroidDevice(runner=runner)
        dev.launch('org.a.b')
        dev.pid('org.a.b')
        dev.monkey('org.a.b', 200, 4242)
        dev.screenshot('org.a.b')
        dev.uninstall('org.a.b')
        self.assertTrue(calls)
        for args, timeout in calls:
            self.assertIsInstance(args, list)
            self.assertTrue(all(isinstance(a, str) for a in args))
            self.assertIsNotNone(timeout)
        self.assertEqual(calls[0][0], ['adb', 'shell', 'monkey', '-p', 'org.a.b', '-c', 'android.intent.category.LAUNCHER', '1'])
        self.assertEqual(calls[-1][0], ['waydroid', 'app', 'remove', 'org.a.b'])

    def test_run_cmd_times_out_to_none(self):
        self.assertIsNone(lab.run_cmd(['sleep', '5'], 0.2))

    def test_run_cmd_missing_binary_is_none(self):
        self.assertIsNone(lab.run_cmd(['no-such-binary-compat-lab'], 1))

    def test_png_helper_produces_png(self):
        self.assertTrue(lab.make_png().startswith(lab.PNG_MAGIC))

    def test_shard_apps_round_robin(self):
        self.assertEqual(lab.shard_apps(list(range(5)), 2), [[0, 2, 4], [1, 3]])
        self.assertEqual(lab.shard_apps([1, 2], 1), [[1, 2]])


class FakeRunTests(unittest.TestCase):
    def setUp(self):
        self.tmp = pathlib.Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, True)

    def run_fake(self, out, fixture=FIXTURE, only=()):
        argv = ['run', '--device', 'fake', '--fixture', str(fixture), '--out', str(out), '--settle-scale', '0']
        if only:
            argv += ['--only', *only]
        return quiet(lab.main, argv)

    def test_end_to_end_verdicts(self):
        out = self.tmp / 'run'
        code, _ = self.run_fake(out)
        self.assertEqual(code, 0)
        doc = json.loads((out / 'results.json').read_text())
        by = {a['package']: a for a in doc['apps']}
        self.assertEqual(len(by), 30)
        self.assertEqual(by['chat.fluffy.fluffychat']['verdict'], 'crash')
        self.assertEqual(by['net.osmand.plus']['verdict'], 'anr')
        self.assertEqual(by['org.connectbot']['verdict'], 'crash')
        self.assertEqual(by['org.schabi.newpipe']['verdict'], 'crash')
        self.assertEqual(by['com.github.libretube']['verdict'], 'fail')
        self.assertEqual(by['org.qownnotes.mobile']['verdict'], 'no-launch')
        self.assertEqual(by['de.westnordost.streetcomplete']['verdict'], 'skipped')
        self.assertEqual(by['org.mozilla.fennec_fdroid']['verdict'], 'pass')
        self.assertEqual(doc['counts']['pass'], 23)
        self.assertEqual(sum(doc['counts'].values()), 30)

    def test_screenshots_and_logs_written(self):
        out = self.tmp / 'run'
        self.run_fake(out)
        shot = out / 'shots' / 'org.mozilla.fennec_fdroid.png'
        self.assertTrue(shot.read_bytes().startswith(lab.PNG_MAGIC))
        log = (out / 'logs' / 'chat.fluffy.fluffychat.log').read_text()
        self.assertIn('IllegalStateException', log)

    def test_report_writes_json_and_html(self):
        out = self.tmp / 'run'
        self.run_fake(out)
        code, _ = quiet(lab.main, ['report', str(out / 'results.json')])
        self.assertEqual(code, 0)
        rep = json.loads((out / 'report.json').read_text())
        self.assertEqual(rep['counts']['crash'], 3)
        page = (out / 'report.html').read_text()
        self.assertIn('class="v crash"', page)
        self.assertIn('shots/org.mozilla.fennec_fdroid.png', page)

    def test_compare_same_run_is_clean(self):
        out = self.tmp / 'run'
        self.run_fake(out)
        path = str(out / 'results.json')
        code, text = quiet(lab.main, ['compare', path, path])
        self.assertEqual(code, 0)
        self.assertIn('0 regression(s)', text)

    def test_compare_flags_new_crash(self):
        base = self.tmp / 'base'
        self.run_fake(base)
        fixture = json.loads(FIXTURE.read_text())
        crash = ANDROID_JAVA_CRASH.replace('chat.fluffy.fluffychat', 'org.mozilla.fennec_fdroid')
        fixture['apps']['org.mozilla.fennec_fdroid'] = {'logcat': crash}
        changed = self.tmp / 'changed.json'
        changed.write_text(json.dumps(fixture))
        new = self.tmp / 'new'
        self.run_fake(new, fixture=changed)
        code, text = quiet(lab.main, ['compare', str(base / 'results.json'), str(new / 'results.json')])
        self.assertEqual(code, 1)
        self.assertIn('REGRESSION  org.mozilla.fennec_fdroid: pass -> crash', text)

    def test_preinstalled_app_is_left_alone(self):
        out = self.tmp / 'run'
        self.run_fake(out, only=['de.westnordost.streetcomplete'])
        doc = json.loads((out / 'results.json').read_text())
        self.assertIn('left alone', doc['apps'][0]['note'])

    def test_unknown_only_package_is_error(self):
        code, _ = quiet(lab.main, ['run', '--device', 'fake', '--out', str(self.tmp / 'x'), '--only', 'org.nope.nope'])
        self.assertEqual(code, 2)


class CompareTests(unittest.TestCase):
    def rows(self, **verdicts):
        return [{'package': p, 'verdict': v} for p, v in verdicts.items()]

    def test_pass_to_crash_is_regression(self):
        reg, imp = lab.compare_apps(self.rows(a='pass'), self.rows(a='crash'))
        self.assertEqual(reg, [('a', 'pass', 'crash')])
        self.assertEqual(imp, [])

    def test_crash_to_pass_is_improvement(self):
        reg, imp = lab.compare_apps(self.rows(a='crash'), self.rows(a='pass'))
        self.assertEqual(reg, [])
        self.assertEqual(imp, [('a', 'crash', 'pass')])

    def test_missing_passing_app_is_regression(self):
        reg, _ = lab.compare_apps(self.rows(a='pass', b='pass'), self.rows(a='pass'))
        self.assertEqual(reg, [('b', 'pass', 'missing')])

    def test_pass_to_skipped_is_regression(self):
        reg, _ = lab.compare_apps(self.rows(a='pass'), self.rows(a='skipped'))
        self.assertEqual(reg, [('a', 'pass', 'skipped')])

    def test_new_failing_app_is_regression(self):
        reg, _ = lab.compare_apps(self.rows(a='pass'), self.rows(a='pass', c='anr'))
        self.assertEqual(reg, [('c', 'new', 'anr')])

    def test_same_verdicts_are_clean(self):
        reg, imp = lab.compare_apps(self.rows(a='pass', b='fail'), self.rows(a='pass', b='fail'))
        self.assertEqual((reg, imp), ([], []))

    def test_compare_exit_codes_from_files(self):
        d = pathlib.Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, d, True)
        good = d / 'good.json'
        bad = d / 'bad.json'
        good.write_text(json.dumps({'schema': 1, 'apps': self.rows(a='pass')}))
        bad.write_text(json.dumps({'schema': 1, 'apps': self.rows(a='crash')}))
        self.assertEqual(quiet(lab.main, ['compare', str(good), str(good)])[0], 0)
        self.assertEqual(quiet(lab.main, ['compare', str(good), str(bad)])[0], 1)
        bogus = d / 'bogus.json'
        bogus.write_text(json.dumps({'schema': 9, 'apps': []}))
        self.assertEqual(quiet(lab.main, ['compare', str(good), str(bogus)])[0], 2)


if __name__ == '__main__':
    unittest.main()
