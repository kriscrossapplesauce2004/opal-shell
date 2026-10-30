import importlib.util
import pathlib
import unittest


TOOLS = pathlib.Path(__file__).resolve().parents[1] / "tools"
spec = importlib.util.spec_from_file_location("frame_lab", TOOLS / "frame-lab.py")
frame_lab = importlib.util.module_from_spec(spec)
spec.loader.exec_module(frame_lab)


def line(name, intervals, flickable=True):
    """Return one parsed scenario line as the fixture prints it."""
    return {"scenario": name, "surface": name, "cycles": 1, "clock": "Date.now", "flickable": flickable, "intervals_ms": intervals}


class FrameLabStatisticsTests(unittest.TestCase):
    def test_percentile_uses_nearest_rank(self):
        values = list(range(1, 101))
        self.assertEqual(frame_lab.percentile(values, 50), 50)
        self.assertEqual(frame_lab.percentile(values, 95), 95)
        self.assertEqual(frame_lab.percentile(values, 99), 99)
        self.assertEqual(frame_lab.percentile([7.5], 99), 7.5)
        self.assertEqual(frame_lab.percentile([3, 1, 2], 100), 3)

    def test_percentile_rejects_empty_input(self):
        with self.assertRaises(ValueError):
            frame_lab.percentile([], 99)

    def test_summarize_counts_frames_over_budget(self):
        stats = frame_lab.summarize([16, 16, 17, 33, 16, 50], 16.7)
        self.assertEqual(stats["frames"], 6)
        self.assertEqual(stats["over_budget"], 3)
        self.assertEqual(stats["over_budget_pct"], 50.0)
        self.assertEqual(stats["max_ms"], 50)
        self.assertEqual(stats["median_ms"], 16.5)
        self.assertEqual(stats["p99_ms"], 50)

    def test_summarize_handles_no_frames(self):
        stats = frame_lab.summarize([], 16.7)
        self.assertEqual(stats["frames"], 0)
        self.assertIsNone(stats["p99_ms"])
        self.assertEqual(stats["over_budget"], 0)

    def test_budget_is_strict(self):
        stats = frame_lab.summarize([16.7, 16.8], 16.7)
        self.assertEqual(stats["over_budget"], 1)


class FrameLabParsingTests(unittest.TestCase):
    def test_parse_lines_reads_only_prefixed_json(self):
        text = "qml: noise\nqml: FRAMELAB {\"scenario\": \"a\", \"intervals_ms\": [16.0]}\nOFFSCREEN_TESTS_COMPLETE\n"
        parsed = frame_lab.parse_lines(text)
        self.assertEqual(parsed, [{"scenario": "a", "intervals_ms": [16.0]}])

    def test_build_report_uses_schema_and_drops_raw_by_default(self):
        env = {"python": "x"}
        report = frame_lab.build_report([line("a", [16, 17])], 16.7, env)
        self.assertEqual(report["schema"], "opal-framelab-v1")
        self.assertEqual(report["budget_ms"], 16.7)
        self.assertEqual(report["environment"], env)
        self.assertEqual(report["scenarios"][0]["name"], "a")
        self.assertNotIn("intervals_ms", report["scenarios"][0])
        raw = frame_lab.build_report([line("a", [16, 17])], 16.7, env, raw=True)
        self.assertEqual(raw["scenarios"][0]["intervals_ms"], [16, 17])


class FrameLabCompareTests(unittest.TestCase):
    def report(self, **p99):
        return {"scenarios": [{"name": name, "p99_ms": value} for name, value in p99.items()]}

    def test_within_tolerance_is_ok(self):
        rows, regressed = frame_lab.compare(self.report(a=24.0), self.report(a=20.0), 25)
        self.assertFalse(regressed)
        self.assertEqual(rows[0]["status"], "ok")
        self.assertEqual(rows[0]["delta_pct"], 20.0)

    def test_growth_over_tolerance_regresses(self):
        rows, regressed = frame_lab.compare(self.report(a=26.0), self.report(a=20.0), 25)
        self.assertTrue(regressed)
        self.assertEqual(rows[0]["status"], "regressed")
        self.assertEqual(rows[0]["delta_ms"], 6.0)

    def test_faster_run_never_regresses(self):
        rows, regressed = frame_lab.compare(self.report(a=10.0), self.report(a=40.0), 0)
        self.assertFalse(regressed)
        self.assertEqual(rows[0]["delta_pct"], -75.0)

    def test_new_and_missing_scenarios_do_not_fail(self):
        rows, regressed = frame_lab.compare(self.report(new=5.0), self.report(old=5.0), 25)
        statuses = {row["name"]: row["status"] for row in rows}
        self.assertEqual(statuses, {"new": "new", "old": "missing"})
        self.assertFalse(regressed)

    def test_scenario_without_frames_does_not_fail(self):
        rows, regressed = frame_lab.compare(self.report(a=None), self.report(a=20.0), 25)
        self.assertEqual(rows[0]["status"], "no frames")
        self.assertFalse(regressed)

    def test_format_tables_render_every_row(self):
        report = frame_lab.build_report([line("a", [16, 17, 40])], 16.7, {})
        table = frame_lab.format_scenarios(report)
        self.assertIn("a", table)
        rows, _ = frame_lab.compare(report, report, 25)
        self.assertIn("ok", frame_lab.format_compare(rows))


if __name__ == "__main__":
    unittest.main()
