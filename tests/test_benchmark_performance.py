import json
import pathlib
import statistics
import subprocess
import sys
import tempfile
import unittest


TESTS = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(TESTS))
import benchmark_performance as performance


class PerformanceHarnessTests(unittest.TestCase):
    def test_generated_workload_is_repeatable_and_not_constant(self):
        first = performance.generated_operations(64, 17, "test-seed")
        second = performance.generated_operations(64, 17, "test-seed")
        changed = performance.generated_operations(64, 17, "other-seed")
        self.assertEqual(first, second)
        self.assertNotEqual(first, changed)
        self.assertGreater(len(set(first)), 10)
        self.assertTrue(all(value.startswith("clip-") and "\nline=" in value for value in first))

    def test_real_workload_records_each_raw_sample_and_summary(self):
        result = performance.benchmark(samples=5, operations=80, unique_count=31, seed="unit")
        samples = result["results"]["raw_samples_ms"]
        self.assertEqual(result["schema"], "opal-performance-v1")
        self.assertEqual(result["workload"]["operations_per_sample"], 80)
        self.assertEqual(len(samples), 5)
        self.assertTrue(all(sample > 0 for sample in samples))
        self.assertEqual(result["results"]["median_ms"], statistics.median(samples))
        self.assertIn(result["results"]["p95_ms"], samples)

    def test_cli_writes_machine_readable_data(self):
        with tempfile.TemporaryDirectory() as directory:
            destination = pathlib.Path(directory) / "run.json"
            exit_code = performance.main(["--samples", "3", "--operations", "40", "--unique-texts", "19", "--output", str(destination)])
            payload = json.loads(destination.read_text(encoding="utf-8"))
        self.assertEqual(exit_code, 0)
        self.assertEqual(payload["workload"]["operations_per_sample"], 40)
        self.assertEqual(len(payload["results"]["raw_samples_ms"]), 3)

    def test_invalid_workload_counts_fail_before_measurement(self):
        with self.assertRaises(ValueError):
            performance.generated_operations(0, 1, "unit")
        with self.assertRaises(ValueError):
            performance.generated_operations(1, 0, "unit")

    def test_summary_keeps_the_standard_even_sample_median(self):
        result = performance.summarize([8.0, 1.0, 6.0, 3.0])
        self.assertEqual(result["median_ms"], statistics.median(result["raw_samples_ms"]))
        self.assertEqual(result["p95_ms"], max(result["raw_samples_ms"]))

    def test_event_audit_rejects_an_invalid_application_event(self):
        audit = performance.EventAudit()
        with self.assertRaises(RuntimeError):
            audit({"event": "other", "items": []})

    def test_audit_rejects_trivial_assertions(self):
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / "bad_test.py"
            path.write_text("assert True\nself.assertEqual(value, value)\nfixture = 'assert True'\n", encoding="utf-8")
            failures = performance.audit_assertions(path)
        self.assertEqual([failure[1:] for failure in failures], [(1, "assert True"), (2, "assertEqual self assertion")])

    def test_tree_audit_and_command_fail_for_an_executable_vacuous_assertion(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            nested = root / "nested"
            nested.mkdir()
            bad = nested / "test_bad.py"
            bad.write_text("self.assertTrue(True)\n", encoding="utf-8")
            ignored = root / "helper.py"
            ignored.write_text("assert True\n", encoding="utf-8")
            failures = performance.audit_test_tree(root)
            command = [sys.executable, str(TESTS / "benchmark_performance.py"), "--audit-tests", "--tests-root", str(root)]
            result = subprocess.run(command, text=True, capture_output=True, check=False)
        self.assertEqual([(path.name, line, reason) for path, line, reason in failures], [("test_bad.py", 1, "assertTrue(True)")])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("test_bad.py:1: assertTrue(True)", result.stderr)

    def test_report_rejects_reports_without_raw_samples(self):
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / "bad.json"
            path.write_text('{"schema":"opal-performance-v1","workload":{},"results":{"raw_samples_ms":[]}}', encoding="utf-8")
            command = [sys.executable, str(TESTS.parent / "tools" / "performance-report.py"), str(path)]
            result = subprocess.run(command, text=True, capture_output=True, check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("no usable raw samples", result.stderr)

    def test_this_suite_has_no_trivial_assertions(self):
        self.assertEqual(performance.audit_test_tree(TESTS), [])


if __name__ == "__main__":
    unittest.main()
