# Compat Lab (skeleton)

Compat Lab checks that top Android apps still install, launch and survive a short smoke run on
the Luna Android layer. It is the skeleton for moonshot section 13.1 and the M0-M3 item
"a Compat Lab skeleton" in section 27. It uses only the Python 3 standard library (3.11 or
newer, for `tomllib`).

```
tools/compat-lab/
  lab.py          fetch, run, report, compare
  apps.toml       the app list (30 seeded F-Droid apps)
  fixtures/       simulated outcomes for --device fake
  README.md
opal/tests/test_compat_lab.py   unit and end-to-end tests
```

## How it maps to moonshot 13.1

| 13.1 requirement | Status in this skeleton |
|---|---|
| Top 1,000 apps installed, launched and smoke-tested | Format and pipeline work. Only 30 apps are seeded. |
| x86_64-capable apps run nightly in parallel headless containers on the rig desktops | `--containers N` is in the CLI and shards the list. Shards run one after another for now. |
| ARM-only apps rotate on the rig phones | Not built. `arm-only` apps are listed and reported as `skipped`. |
| Logins with test accounts | Not built. `test_account` holds a placeholder name only. No credential is read or stored. |
| A regression blocks the release | `compare` exits 1 on a regression. The release gate must call it (not built). |
| Installed, launched, smoke-tested | Done: install, launch, PID check, fixed-seed monkey, logcat scan, screenshot, uninstall. |

## Commands

```
python3 tools/compat-lab/lab.py fetch [--only PKG ...] [--refresh-index]
python3 tools/compat-lab/lab.py run --device fake --settle-scale 0 --out DIR     # no device needed
python3 tools/compat-lab/lab.py run --device waydroid [--serial S] [--installer waydroid|adb]
python3 tools/compat-lab/lab.py report DIR/results.json        # report.json and report.html
python3 tools/compat-lab/lab.py compare BASE/results.json NEW/results.json   # exit 1 on regression
```

- `fetch` downloads each APK into `$XDG_CACHE_HOME/compat-lab/apk/` (default `~/.cache`) and
  checks its SHA-256. F-Droid entries take the hash from `index-v1.jar`, using
  `android_store.build_catalog` from `opal/src`, which is imported and not copied. `apk-url`
  entries use the hash pinned in `apps.toml`. A mismatch removes the file and fails. The
  result goes to `manifest.json` in the cache.
- `run` installs with `waydroid app install` (or `adb install -r`), launches with
  `adb shell monkey -p PKG -c android.intent.category.LAUNCHER 1`, waits, checks `pidof`, runs
  any `monkey:N` steps with a fixed seed, reads `adb logcat -d`, takes a screenshot with
  `adb exec-out screencap -p` and removes the app. Every subprocess uses an argument array and
  a timeout. The run never removes an app that was already installed. It writes
  `results.json`, `shots/PKG.png` and, for failing apps, `logs/PKG.log`.
- `report` writes `report.json` and a standalone `report.html` with a verdict badge and the
  screenshot for each app.
- `compare` reads two result files. It reports a regression when an app gets worse, goes
  missing (or `skipped`) after it passed, or a new app fails.

## Verdicts

Checked in this order. The first one that applies wins.

| Verdict | Meaning |
|---|---|
| `fail` | The install was refused, a smoke step failed, or the APK was not in the cache or failed its checksum. |
| `crash` | `FATAL EXCEPTION` for the app, a native `Fatal signal` for the app, or a monkey `// CRASH:` line. |
| `anr` | `ANR in PKG` for the app, or a monkey `// NOT RESPONDING:` line. |
| `no-launch` | The launch command failed, or `pidof` found no process after the settle wait. |
| `pass` | None of the above. |
| `skipped` | Play placeholder, `arm-only`, already installed on the device, or not fetched. |

Sub-processes count (`PKG:name`). Logcat text that has no `Process:` line is not attributed.

## apps.toml

One `[[app]]` table per app. The file header describes every field. Summary:

- `source`: `fdroid`, `apk-url` (needs `url` and a 64-character `sha256`), or
  `play-placeholder` (listed, not run).
- `abi`: `x86_64-capable` (x86_64 native code or pure Java) or `arm-only`.
- `category`: browser, maps, messaging, media, notes, keyboard, files, game, system, other.
- `test_account`: a placeholder name such as `lab-messaging-01`, or `none`.
- `smoke`: `launch`, `settle:SECONDS`, `monkey:EVENTS`. `launch` is added first when missing.

The seed list covers browser, maps, messaging, media, notes, keyboard, files and game, plus
three system apps. Each entry was checked against the F-Droid index with the lab's own
resolver. All 30 resolve to an x86_64-capable or pure Java build.

## Tests

```
cd opal && python3 -m unittest tests.test_compat_lab
```

The tests cover verdict order, logcat and monkey parsing (with realistic FATAL EXCEPTION, ANR
and native crash lines), `apps.toml` validation, F-Droid resolution from a synthetic index,
download and checksum checks against `file://` URLs, argument-array commands and timeouts, a
full fake run, report output and regression exit codes. No test touches a device or the
network.

## Nightly on the rig (planned)

1. On each rig desktop, a systemd timer runs `fetch --refresh-index` and then
   `run --containers N --out ~/compat/runs/DATE`, once per night.
2. `report` writes the HTML page. The page is served to the team.
3. `compare` runs against the last green baseline. Exit 1 blocks the release train.
4. Each container needs its own Waydroid data directory and its own adb port. Setting that up
   is the part that is not built.

## Not done

- Play apps (`play-placeholder`) are not fetched or run. Play needs an account and the
  sandboxed Play layer from section 13.1.
- Logins with test accounts. Test accounts are named only; there is no credential store.
- ARM-only rotation on the phones. There is no phone lane.
- Parallel containers. `--containers` shards the list, but the shards run one after another.
- Real app flows. The monkey run is random input, not a scripted UI test.
- Screenshot comparison. Screenshots are saved for people to read; nothing diffs them.
- F-Droid index signature. `index-v1.jar` is downloaded over HTTPS and its JAR signature is
  not checked. Each APK is checked against the index hash.
- The release gate that calls `compare`.
- Booting or configuring Waydroid. `run --device waydroid` uses a session that already runs.
