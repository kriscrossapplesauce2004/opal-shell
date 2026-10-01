#!/usr/bin/env python3
"""Compare one or more Opal performance JSON files."""
import argparse
import json
import pathlib
import sys


def read_report(path):
    """Read and validate one benchmark result file."""
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
        results = payload["results"]
        workload = payload["workload"]
    except (OSError, ValueError, KeyError, TypeError) as error:
        raise ValueError(f"{path}: invalid benchmark report: {error}") from error
    samples = results.get("raw_samples_ms")
    if payload.get("schema") != "opal-performance-v1" or not isinstance(samples, list) or len(samples) < 3:
        raise ValueError(f"{path}: report has no usable raw samples.")
    if not all(isinstance(value, (int, float)) and value > 0 for value in samples):
        raise ValueError(f"{path}: report has invalid sample values.")
    return {"path": str(path), "operations": workload.get("operations_per_sample"), "workload": workload, **results}


def render(reports):
    """Render a compact table for terminals and CI logs."""
    baseline = reports[0]
    keys = ("name", "operations_per_sample", "unique_texts", "seed")
    baseline_workload = baseline.get("workload", {})
    lines = ["file\toperations\tsamples\tmedian_ms\tp95_ms\tops_per_second\tbaseline_delta_percent"]
    for report in reports:
        operations = report["operations"]
        median = report["median_ms"]
        rate = operations * 1000 / median if isinstance(operations, int) and median > 0 else 0
        same_workload = all(report.get("workload", {}).get(key) == baseline_workload.get(key) for key in keys)
        delta = (median / baseline["median_ms"] - 1) * 100 if same_workload else None
        delta_text = f"{delta:+.2f}" if delta is not None else "n/a"
        lines.append(f"{report['path']}\t{operations}\t{len(report['raw_samples_ms'])}\t{median:.3f}\t{report['p95_ms']:.3f}\t{rate:.1f}\t{delta_text}")
    return "\n".join(lines) + "\n"


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("reports", nargs="+", type=pathlib.Path)
    parser.add_argument("--json", action="store_true", dest="as_json")
    args = parser.parse_args(argv)
    try:
        reports = [read_report(path) for path in args.reports]
    except ValueError as error:
        parser.error(str(error))
    if args.as_json:
        sys.stdout.write(json.dumps(reports, indent=2) + "\n")
    else:
        sys.stdout.write(render(reports))


if __name__ == "__main__":
    main()
