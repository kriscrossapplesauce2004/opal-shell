#!/usr/bin/env python3
"""Measure real clipboard history work with repeatable generated input."""
import argparse
import ast
import hashlib
import json
import pathlib
import platform
import sys
import time


ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

from clipboard_service import ClipboardHistory, MAX_ITEMS


def generated_operations(count, unique_count, seed):
    """Return valid and invalid clipboard input in a fixed order."""
    if count < 1 or unique_count < 1:
        raise ValueError("Operation counts must be positive.")
    values = [
        f"clip-{index:05d}-{hashlib.sha256(f'{seed}:{index}'.encode()).hexdigest()[:48]}\nline={index % 7}"
        for index in range(unique_count)
    ]
    # Reuse old values. This tests duplicate promotion and list scanning.
    return [values[(index * 7 + index // 3) % unique_count] for index in range(count)]


class EventAudit:
    """Check emitted data without retaining every copied history payload."""
    __slots__ = ("count", "largest_history")

    def __init__(self):
        self.count = 0
        self.largest_history = 0

    def __call__(self, event):
        items = event.get("items")
        if event.get("event") != "clipboard" or not isinstance(items, list):
            raise RuntimeError("Clipboard history changed its event payload.")
        self.count += 1
        self.largest_history = max(self.largest_history, len(items))


def side_effect_free(node):
    """Return true when repeated evaluation cannot change the value."""
    if isinstance(node, (ast.Name, ast.Constant)):
        return True
    if isinstance(node, ast.Attribute):
        return side_effect_free(node.value)
    if isinstance(node, ast.Tuple):
        return all(side_effect_free(item) for item in node.elts)
    return False


def same_value(left, right):
    """Match equal source expressions that have no calls or indexes."""
    return side_effect_free(left) and side_effect_free(right) and ast.dump(left, include_attributes=False) == ast.dump(right, include_attributes=False)


def audit_assertions(path):
    """Find executable assertions that cannot fail."""
    tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    failures = []
    comparisons = (ast.Eq, ast.Is, ast.LtE, ast.GtE)
    methods = {"assertEqual", "assertIs", "assertLessEqual", "assertGreaterEqual"}
    for node in ast.walk(tree):
        reason = None
        if isinstance(node, ast.Assert):
            if isinstance(node.test, ast.Constant) and node.test.value is True:
                reason = "assert True"
            elif isinstance(node.test, ast.Compare) and len(node.test.ops) == 1 and type(node.test.ops[0]) in comparisons:
                if same_value(node.test.left, node.test.comparators[0]):
                    reason = "self comparison"
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute):
            if node.func.attr == "assertTrue" and node.args and isinstance(node.args[0], ast.Constant) and node.args[0].value is True:
                reason = "assertTrue(True)"
            elif node.func.attr == "assertFalse" and node.args and isinstance(node.args[0], ast.Constant) and node.args[0].value is False:
                reason = "assertFalse(False)"
            elif node.func.attr in methods and len(node.args) >= 2 and same_value(node.args[0], node.args[1]):
                reason = f"{node.func.attr} self assertion"
        if reason:
            failures.append((path, node.lineno, reason))
    return failures


def audit_test_tree(tests_root):
    """Audit every repository test file in a stable path order."""
    return [failure for path in sorted(tests_root.rglob("test_*.py")) for failure in audit_assertions(path)]


def run_sample(operations):
    """Run one complete history workload and return its elapsed time."""
    events = EventAudit()
    history = ClipboardHistory(events)
    started = time.perf_counter_ns()
    add = history.add
    accepted = sum(add(text) for text in operations)
    rejected = sum(add(value) for value in ("", " \t\n", "bad\0text", None))
    elapsed_ns = time.perf_counter_ns() - started
    if accepted != len(operations) or rejected != 0:
        raise RuntimeError("Clipboard history changed its input contract.")
    if len(history.items) > MAX_ITEMS or events.count != accepted or events.largest_history > MAX_ITEMS:
        raise RuntimeError("Clipboard history changed its event contract.")
    return elapsed_ns / 1_000_000


def summarize(samples):
    """Return stable summary values for JSON consumers."""
    ordered = sorted(samples)
    p95_index = max(0, min(len(ordered) - 1, (95 * len(ordered) + 99) // 100 - 1))
    midpoint = len(ordered) // 2
    median = ordered[midpoint] if len(ordered) % 2 else (ordered[midpoint - 1] + ordered[midpoint]) / 2
    return {
        "raw_samples_ms": samples,
        "median_ms": median,
        "p95_ms": ordered[p95_index],
        "minimum_ms": ordered[0],
        "maximum_ms": ordered[-1],
    }


def benchmark(samples, operations, unique_count, seed):
    """Measure the application path without test doubles."""
    workload = generated_operations(operations, unique_count, seed)
    run_sample(workload)
    values = [run_sample(workload) for _ in range(samples)]
    return {
        "schema": "opal-performance-v1",
        "workload": {
            "name": "clipboard-history-add",
            "operations_per_sample": operations,
            "unique_texts": unique_count,
            "seed": seed,
            "warmup_samples": 1,
        },
        "environment": {
            "python": platform.python_version(),
            "platform": platform.platform(),
        },
        "results": summarize(values),
    }


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--samples", type=int, default=21)
    parser.add_argument("--operations", type=int, default=6000)
    parser.add_argument("--unique-texts", type=int, default=256)
    parser.add_argument("--seed", default="opal-performance-v1")
    parser.add_argument("--output", type=pathlib.Path)
    parser.add_argument("--audit-tests", action="store_true")
    parser.add_argument("--tests-root", type=pathlib.Path, default=ROOT / "tests")
    args = parser.parse_args(argv)
    if args.audit_tests:
        failures = audit_test_tree(args.tests_root)
        for path, line, reason in failures:
            print(f"{path}:{line}: {reason}", file=sys.stderr)
        return 1 if failures else 0
    if args.samples < 3:
        parser.error("--samples must be at least 3.")
    result = benchmark(args.samples, args.operations, args.unique_texts, args.seed)
    encoded = json.dumps(result, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.write_text(encoded, encoding="utf-8")
    else:
        sys.stdout.write(encoded)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
