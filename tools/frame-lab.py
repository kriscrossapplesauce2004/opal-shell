#!/usr/bin/env python3
"""Run the Frame Lab fixture offscreen and report frame gaps per scenario.

Schema opal-framelab-v1 (JSON object):
  schema        "opal-framelab-v1"
  created       UTC time of the run, ISO 8601
  budget_ms     frame budget used for over_budget counts
  caveat        text: offscreen software timings are a regression signal only
  environment   python, platform, machine, cpus, cpu, quickshell, backend,
                qpa_platform, cycles, clock
  scenarios     list of {name, surface, cycles, flickable, frames, median_ms,
                p95_ms, p99_ms, max_ms, over_budget, over_budget_pct} and,
                with --raw, intervals_ms (every frame gap, in ms)
Percentiles use nearest rank, as tests/benchmark_performance.py does.
Compare exit codes: 0 ok, 1 p99 regression over --tolerance, 2 run failed.
"""
import argparse
import datetime
import json
import math
import os
import pathlib
import platform
import shutil
import statistics
import subprocess
import sys
import tempfile


ROOT = pathlib.Path(__file__).resolve().parents[1]
ENTRY = "framelab.qml"
PREFIX = "FRAMELAB "
COMPLETE = "OFFSCREEN_TESTS_COMPLETE"
ERROR_PATTERN = ("TypeError", "ReferenceError", "ERROR", "Unable to assign", "Binding loop", "ASSERTION_FAILED")
CAVEAT = ("Offscreen software timings from one machine. They show regressions between runs, "
          "not real GPU or compositor frame times.")


def percentile(values, pct):
    """Return the nearest-rank percentile of values."""
    if not values:
        raise ValueError("percentile needs at least one value.")
    ordered = sorted(values)
    index = math.ceil(pct * len(ordered) / 100) - 1
    return ordered[max(0, min(len(ordered) - 1, index))]


def summarize(intervals, budget_ms):
    """Return frame statistics for one scenario."""
    count = len(intervals)
    if not count:
        return {"frames": 0, "median_ms": None, "p95_ms": None, "p99_ms": None, "max_ms": None,
                "over_budget": 0, "over_budget_pct": 0.0}
    over = sum(1 for value in intervals if value > budget_ms)
    return {
        "frames": count,
        "median_ms": round(statistics.median(intervals), 3),
        "p95_ms": round(percentile(intervals, 95), 3),
        "p99_ms": round(percentile(intervals, 99), 3),
        "max_ms": round(max(intervals), 3),
        "over_budget": over,
        "over_budget_pct": round(100 * over / count, 2),
    }


def parse_lines(text):
    """Return the JSON objects printed with the Frame Lab prefix."""
    found = []
    for line in text.splitlines():
        index = line.find(PREFIX)
        if index >= 0:
            found.append(json.loads(line[index + len(PREFIX):]))
    return found


def build_report(lines, budget_ms, environment, raw=False, caveat=CAVEAT):
    """Combine parsed scenario lines into an opal-framelab-v1 report."""
    scenarios = []
    for line in lines:
        row = {"name": line["scenario"], "surface": line["surface"], "cycles": line["cycles"], "flickable": line.get("flickable", False)}
        row.update(summarize(line["intervals_ms"], budget_ms))
        if raw:
            row["intervals_ms"] = line["intervals_ms"]
        scenarios.append(row)
    return {
        "schema": "opal-framelab-v1",
        "created": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "budget_ms": budget_ms,
        "caveat": caveat,
        "environment": environment,
        "scenarios": scenarios,
    }


def compare(current, baseline, tolerance_pct):
    """Return one row per scenario name and whether any p99 regressed."""
    base_by_name = {row["name"]: row for row in baseline["scenarios"]}
    cur_by_name = {row["name"]: row for row in current["scenarios"]}
    rows = []
    regressed = False
    for name in sorted(set(base_by_name) | set(cur_by_name)):
        base = base_by_name.get(name)
        cur = cur_by_name.get(name)
        row = {"name": name, "base_p99_ms": base and base["p99_ms"], "cur_p99_ms": cur and cur["p99_ms"],
               "delta_ms": None, "delta_pct": None, "status": "ok"}
        if base is None:
            row["status"] = "new"
        elif cur is None:
            row["status"] = "missing"
        elif base["p99_ms"] is None or cur["p99_ms"] is None:
            row["status"] = "no frames"
        else:
            row["delta_ms"] = round(cur["p99_ms"] - base["p99_ms"], 3)
            if base["p99_ms"] > 0:
                row["delta_pct"] = round(100 * row["delta_ms"] / base["p99_ms"], 2)
            if row["delta_pct"] is not None and row["delta_pct"] > tolerance_pct:
                row["status"] = "regressed"
                regressed = True
        rows.append(row)
    return rows, regressed


def format_scenarios(report):
    """Return a compact table of scenario statistics."""
    head = f"{'scenario':<16}{'frames':>7}{'median':>9}{'p95':>9}{'p99':>9}{'max':>9}{'>budget':>9}"
    lines = [head, "-" * len(head)]
    for row in report["scenarios"]:
        cells = [row[key] for key in ("median_ms", "p95_ms", "p99_ms", "max_ms")]
        values = "".join(f"{'-' if cell is None else f'{cell:.2f}':>9}" for cell in cells)
        lines.append(f"{row['name']:<16}{row['frames']:>7}{values}{row['over_budget_pct']:>8.1f}%")
    return "\n".join(lines)


def format_compare(rows):
    """Return a compact table of p99 deltas against a baseline."""
    head = f"{'scenario':<16}{'base p99':>10}{'now p99':>10}{'delta ms':>10}{'delta %':>9}  status"
    lines = [head, "-" * len(head)]
    for row in rows:
        def cell(value, fmt):
            return "-" if value is None else format(value, fmt)
        lines.append(f"{row['name']:<16}{cell(row['base_p99_ms'], '.2f'):>10}{cell(row['cur_p99_ms'], '.2f'):>10}"
                     f"{cell(row['delta_ms'], '+.2f'):>10}{cell(row['delta_pct'], '+.1f'):>9}  {row['status']}")
    return "\n".join(lines)


def cpu_model():
    """Return the first CPU model name, or an empty string."""
    try:
        for line in pathlib.Path("/proc/cpuinfo").read_text(encoding="utf-8").splitlines():
            if line.startswith("model name"):
                return line.split(":", 1)[1].strip()
    except OSError:
        pass
    return ""


def quickshell_version():
    """Return the first line of quickshell --version."""
    try:
        result = subprocess.run(["quickshell", "--version"], capture_output=True, text=True, timeout=10)
        return (result.stdout or result.stderr).strip().splitlines()[0]
    except (OSError, subprocess.SubprocessError, IndexError):
        return "unknown"


def run_fixture(cycles, backend, timeout_s):
    """Run the fixture in an isolated home and return (log text, timed out)."""
    root = pathlib.Path(tempfile.mkdtemp(prefix="opal-framelab-"))
    (root / "home" / ".local" / "share").mkdir(parents=True)
    (root / "home" / ".config").mkdir(parents=True)
    (root / "runtime").mkdir(mode=0o700)
    (root / "config").mkdir()
    shutil.copytree(ROOT / "src", root / "config" / "src", ignore=shutil.ignore_patterns("__pycache__"))
    shutil.copy(ROOT / "tests" / ENTRY, root / "config" / ENTRY)
    env = {key: value for key, value in os.environ.items() if key not in ("DISPLAY", "WAYLAND_DISPLAY", "HYPRLAND_INSTANCE_SIGNATURE")}
    env.update({
        "HOME": str(root / "home"), "XDG_RUNTIME_DIR": str(root / "runtime"),
        "XDG_CONFIG_HOME": str(root / "home" / ".config"), "XDG_DATA_HOME": str(root / "home" / ".local" / "share"),
        "QT_QPA_PLATFORM": "offscreen", "QT_QPA_PLATFORMTHEME": "basic", "QT_QUICK_BACKEND": backend,
        "OPAL_TEST_OUTPUT": str(root), "DBUS_SESSION_BUS_ADDRESS": f"unix:path={root / 'no-bus'}",
        "OPAL_FRAMELAB_CYCLES": str(cycles),
    })
    try:
        result = subprocess.run(["quickshell", "-p", str(root / "config" / ENTRY)], env=env, capture_output=True,
                                text=True, timeout=timeout_s)
        text, timed_out = (result.stdout or "") + (result.stderr or ""), False
    except subprocess.TimeoutExpired as error:
        raw = error.stdout or b""
        text, timed_out = (raw.decode("utf-8", "replace") if isinstance(raw, bytes) else raw), True
    (root / "render.log").write_text(text, encoding="utf-8")
    return text, timed_out, root


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--out", type=pathlib.Path, default=pathlib.Path("/tmp/opal-framelab/framelab.json"))
    parser.add_argument("--budget-ms", type=float, default=16.7)
    parser.add_argument("--compare", type=pathlib.Path, metavar="BASELINE")
    parser.add_argument("--tolerance", type=float, default=25.0, help="allowed p99 growth in percent")
    parser.add_argument("--cycles", type=int, default=5)
    parser.add_argument("--backend", default="software")
    parser.add_argument("--timeout", type=int, default=240)
    parser.add_argument("--raw", action="store_true", help="keep every frame gap in the report")
    args = parser.parse_args(argv)
    if args.budget_ms <= 0 or args.cycles < 1 or args.tolerance < 0:
        parser.error("--budget-ms and --cycles must be positive; --tolerance must not be negative.")

    text, timed_out, root = run_fixture(args.cycles, args.backend, args.timeout)
    lines = parse_lines(text)
    errors = [line for line in text.splitlines()
              if any(word in line for word in ERROR_PATTERN) and "Failed to connect pipewire context" not in line]
    if timed_out or COMPLETE not in text or not lines:
        print(f"Frame Lab did not finish. Log: {root / 'render.log'}", file=sys.stderr)
        for line in errors[:20]:
            print(line, file=sys.stderr)
        return 2
    environment = {
        "python": platform.python_version(), "platform": platform.platform(), "machine": platform.machine(),
        "cpus": os.cpu_count(), "cpu": cpu_model(), "quickshell": quickshell_version(), "backend": args.backend,
        "qpa_platform": "offscreen", "cycles": args.cycles, "clock": lines[0]["clock"],
    }
    report = build_report(lines, args.budget_ms, environment, raw=args.raw)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(format_scenarios(report))
    print(f"Report: {args.out}")
    if errors:
        print(f"{len(errors)} log lines look like errors. Log: {root / 'render.log'}", file=sys.stderr)
    if args.compare:
        baseline = json.loads(args.compare.read_text(encoding="utf-8"))
        rows, regressed = compare(report, baseline, args.tolerance)
        print()
        print(format_compare(rows))
        if regressed:
            print(f"p99 regression above {args.tolerance:g}%.", file=sys.stderr)
            return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
