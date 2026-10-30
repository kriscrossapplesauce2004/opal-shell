# Luna compositor spike: QtWaylandCompositor arm, then the waylib fork

Status: the QtWaylandCompositor arm below is now the test harness `luna-compositor-qt`. The product base is the waylib
fork (decision in moonshot.md §32); see "waylib fork" at the end. `luna-compositor` is now the waylib build.
Scope: the M0 exit (§27) asks for the Opal shell inside the Luna compositor on this PC. This spike proves the
one-scene model with a stand-in shell, not Opal itself.

## What is here

| Path | Purpose |
|---|---|
| `CMakeLists.txt`, `src/` | `luna-compositor-qt` (C++20, Qt 6.12); before 2026-10-29 this target was `luna-compositor` |
| `qml/Main.qml` | Compositor, output, protocol objects, tiling state, focus |
| `qml/ClientWindow.qml` | One xdg toplevel as an Item: spring geometry, open and close animation |
| `qml/Bar.qml` | Minimal shell: task list (click focuses and raises, cross closes), clock |
| `qml/Layout.js` | Master-stack tiling |
| `clients/test-client.qml` | Qt test client (one window, moving dot) |
| `run-nested.sh` | Builds, runs the compositor, starts three clients, closes one, exits, prints frame summary |
| `src/frame_log.cpp` | Frame timing from `QQuickWindow::frameSwapped`, written as JSON (`luna-frames-v1`) on exit |

Usage: `./run-nested.sh [--offscreen] [--seconds N] [--out DIR]`, or run the binary directly with
`--socket NAME --frame-log PATH --exit-after MS --budget-ms MS`. The socket name is printed on start.

## What works (verified)

- Build with CMake and Ninja, zero warnings.
- Nested run in the live Hyprland session: socket `luna-0`, three Qt clients (`QT_QPA_PLATFORM=wayland`)
  connect, one client is closed mid-run, the compositor exits 0, and no processes remain.
- Offscreen run (`-platform offscreen`), same flow.
- The Qt client connects with no protocol error in the compositor log.
- Frame log written on exit.

## What is verified only by reading the code (not observed)

- Window content is on screen in the nested run. Only the run's `backend=wayland` result and clean exit were seen;
  no screenshot was taken.
- Focus and keyboard input, pointer input through `WaylandMouseTracker`, the close snapshot (`ShaderEffectSource`
  refreshed every 500 ms), and popups (`autoCreatePopupItems`).
- Server-side decoration: the server prefers it, but the Qt client's behaviour was not checked.
- Spring geometry and open and close motion: the code is there, the look was not checked by eye.

## What does not work

- **foot cannot connect.** The compositor advertises `wl_seat` v4 and `wl_data_device_manager` v1. foot needs
  v5 and v3, prints "need interface version 5, but compositor only implements 4", and exits with status 230.
  A daily-driver terminal is blocked. This is the QtWaylandCompositor default, not our code.
- **kitty fails** in the offscreen run with an EGL error (`Failed to initialize EGL`). Not investigated further.
- **presentation-time is not advertised.** The `PresentationTime` element loads, but no `wp_presentation`
  global appears. Cause not found.
- **Layer-shell is absent** (`zwlr_layer_shell_v1` is not in QtWaylandCompositor).
  Implication for today's Quickshell-based shell: its bar, panels, notifications, lock and launcher are
  layer surfaces. They cannot run as-is in this compositor. The spike replaces them with in-scene items, which
  means porting each Quickshell surface to a QML item in the compositor scene. The separate Quickshell
  dependency inventory decides the size of that port.
- **xdg-output** QML element: adding `XdgOutputManagerV1 {}` breaks Qt clients ("compositor didn't create a
  QWaylandXdgOutputV1"). Removed. The default global is still advertised.
- Popups are created as children of the surface item, so they can extend past a toplevel. The tiling wrapper
  does not clip, so a window mid-spring can show surface content outside its tile for a few frames.

## Protocol coverage against the §7.1 day-one list

Source: `wayland-info` against the running spike, plus `strings` on the Qt libraries for the names listed as "lib".

| §7.1 protocol | Status | Note |
|---|---|---|
| xdg-shell | Yes (v1) | Toplevels and popups; Qt client works |
| layer-shell | No | Not in QtWaylandCompositor; blocks Quickshell |
| linux-dmabuf | No | Needs the hardware-integration plugin; clients fall back to shm, a GPU-performance risk |
| explicit sync | No | |
| presentation-time | No | Element loads, global not advertised (see above) |
| fifo | No | |
| commit-timing | No | |
| fractional scale | No | |
| viewporter | Yes (v1) | `wp_viewporter` advertised by default |
| tearing control | No | |
| colour management / HDR | No | |
| text-input v3 | Yes (v3) | Plus v2 |
| input-method v2 | Partial | Qt's own `qt_text_input_method` only; no `zwp_input_method_v2` |
| pointer constraints | No | |
| relative pointer | No | |
| idle inhibit | Yes (v1) | |
| xdg-activation | Lib only | String in the Qt library, not advertised in the probe |
| xdg-foreign | No | |
| xdg-session-management | No | |
| cursor shape | No | |
| security-context | No | |
| Xwayland | Not tested | |
| xdg-decoration | Yes (v1) | Server-side preferred |
| xdg-dialog | Yes (v1) | `xdg_wm_dialog_v1` |
| xdg-output | Yes (v3) | Default global |

## Frame numbers (this machine)

Frame log: `opal/compositor/build/run/frames.json` (nested) and the scratchpad copy below. Busy frames are
intervals of 100 ms or less, because the scene idles between clock ticks and spring motion.

| Run | Backend | Frames | Busy median | p95 | p99 | max | Over 16.7 ms | Idle gaps >100 ms |
|---|---|---|---|---|---|---|---|---|
| Nested, 15 s | wayland (Hyprland) | 866 | 16.66 ms | 16.88 ms | 17.17 ms | 50.16 ms | 33.8% | 1 |
| Offscreen, 8 s | offscreen | 685 | 10.27 ms | 16.65 ms | 17.61 ms | 19.64 ms | 4.4% | 1 |

Notes:
- The nested median sits on the 60 Hz display cadence (16.67 ms), so the 16.7 ms budget is at the edge
  of vsync. A third of intervals land just over it. This says little about headroom, and the budget should be
  re-set against the real refresh rate before the next run.
- Offscreen numbers are software rendering with no vsync, so they are not comparable to nested.
- Raw files: `/tmp/claude-1000/-home-melissa-lunaos/bf175b8d-83bc-423f-9376-edef8981f95e/scratchpad/offscreen-run2/frames.json`
  (offscreen) and `/tmp/claude-1000/-home-melissa-lunaos/bf175b8d-83bc-423f-9376-edef8981f95e/scratchpad/nested-run/frames.json` (nested).
- Input latency, GPU load and the pop score are not measured.

## Plan for the other two arms

Nothing here is installed. Commands marked "check" first confirm the package exists.

1. **Treeland fork.** `pacman -Si treeland` (check), then `sudo pacman -S treeland`, which the moonshot
   names as Treeland 0.8.7 in extra. Treeland is a full compositor, so the comparison is its own nested
   build (`treeland` binary, nested under Hyprland) running the same stand-in shell. Use the same protocol probe
   (`wayland-info`) and the same three Qt clients. For frame times, patch the Treeland build to write the same
   `luna-frames-v1` JSON from `frameSwapped`. Build the fork from source only if the packaged version cannot
   show Opal.
2. **Clean waylib build.** `pacman -Ss waylib` (check). If it is packaged, install it; if not, clone waylib
   and qwlroots from their upstream repositories, build against the system `wlroots0.20`, and build the same
   luna-compositor scene against waylib's `WaylandCompositor` types. Record the exact commit hashes.
3. **Comparison.** Same scene, same three clients, same 15 s script, same JSON schema, nested and then
   offscreen. Add the same probe output (`wayland-info`) per arm, a foot connection test, a layer-shell
   test, and a presentation-time test. Pick on the busy-frame p99 and the number of §7.1 protocols that
   work with real clients. Once a DRM build exists, repeat on DRM on the rig.

## Recommendation (provisional)

- Keep QtWaylandCompositor for the M0 nested proof and for shell prototyping. It needs no extra packages
  and runs the one-scene model in-process.
- Do not pick it as the product compositor yet. Its gaps block daily use: no layer-shell, no
  linux-dmabuf, no presentation-time, and clients stuck at old `wl_seat` and `wl_data_device_manager`
  versions (foot does not start). Those gaps touch the §7.1 list directly.
- Decide after the waylib and Treeland arms run the same comparison. Treat waylib as the leading candidate
  for the product if its build is clean, because it is the wlroots path that the §7.1 list assumes.

Risks:
- Waylib or Treeland may need patches that push the schedule past M0.
- Protocol gaps in QtWaylandCompositor may be fixable by subclassing its C++ extensions, but that work is not
  scoped.
- Nested numbers do not show DRM scanout behaviour, the thing §6.1 depends on.
- The stand-in shell hides the real cost of porting Quickshell surfaces to in-scene items.
- The 16.7 ms budget was set for a 60 Hz nested run and may mislead on other displays.

## Full shell (2026-10-29)

The unmodified Opal shell (`quickshell -p opal/src`) runs as a client inside luna-compositor.

- Protocols added: `zwlr_layer_shell_v1` (layers, anchors, margins, exclusive zones, keyboard modes, popups),
  `zwlr_foreign_toplevel_management_v1` (the shell's window list sees every client), `ext_session_lock_v1`
  (the lock screen). Protocol XML is vendored in `protocols/`. Screencopy is not done: no live window thumbnails.
- Isolation: `run-shell.sh` gives the shell a temp HOME and state folders, a private D-Bus, and no Hyprland
  signature, so it never touches the live session or its preferences.
- Seen in screenshots: taskbar with the three test clients tiled above it (exclusive zone kept), Start menu with
  search focus, Quick Settings, a notification pill and the notification centre over the private bus, the lock screen.
- Offscreen run, 30 s, 3 clients: 2511 frames, busy median 7.17 ms, p95 11.48, p99 16.40, max 44.00, 0.7 % over 16.7 ms.
  Clean exit, no processes left.
- Try it: `opal/compositor/run-shell.sh --offscreen --seconds 30 --snapshot --out /tmp/luna-shell` (screenshots and
  frames.json in the out folder). Without `--offscreen` it opens one window on the current session.

Gaps toward the M0 exit (on this PC, nested then DRM):
- No DRM backend yet; nested and offscreen only.
- No screencopy, so recents and the task hover card have no live previews.
- Hyprland-only shell features (workspaces, snap, window rules, convergence moves) have no compositor side yet.
- Test clients are Qt clients; foot still needs newer wl_seat and wl_data_device_manager versions.
- Two processes, two clocks: this is the compatibility path. Moving shell surfaces into the compositor scene (§6.1)
  is the next step, surface by surface; see `opal/docs/quickshell-port-map.md`.

## waylib fork (2026-10-29)

`luna-compositor` is rebuilt on our fork of waylib (Treeland 0.11.0, wlroots 0.20.2 underneath). The
QtWaylandCompositor build stays as `luna-compositor-qt` and still builds and runs the same scenario.
Fork details, licences and patch policy: `vendor/FORK.md`.

### What builds

| Part | Where | Note |
|---|---|---|
| waylib 0.6.13 + vendored wlroots 0.20.2 | `vendor/treeland` (branch `luna`), built by `vendor/build-waylib.sh` into `vendor-prefix/` | All wlroots features on (DRM, libinput, Wayland, X11, GLES2, Vulkan, Xwayland, lcms2, libliftoff). qwlroots no longer exists upstream: waylib calls wlroots directly. |
| `luna-compositor` | `luna/src` (server, output capture), `luna/qml` (scene) | C++20, Qt 6.12, links `Waylib::WaylibServer` |
| `luna-compositor-qt` | `src/`, `qml/` | Unchanged code, renamed target |

`luna/` replaces waylib's tinywl example with a smaller design: C++ (`luna/src/server.cpp`) owns the protocols, the
outputs and input; one QML scene (`luna/qml/Scene.qml`) owns placement and motion. Ported from the Qt arm:
the stand-in bar and task list (`Bar.qml`), master-stack tiling (`qml/Layout.js`, shared by both targets), spring
geometry and open and close motion (`ClientWindow.qml`), layer-shell arrangement with exclusive zones
(`Layers.js`), focus rules (lock, then exclusive layer, then active window), `--frame-log`, `--screenshot`,
`--shot-dir` (SIGUSR1), `--exit-after`, `--socket`. New: `--backend headless|wayland|drm|auto`, `--size WxH`
(headless output), `--no-xwayland`. The frame log counts output commits that carry a buffer; screenshots read back
the committed buffer of the first output, so they show exactly what the output shows.

### Protocol coverage against §7.1

Source: `wayland-info` against the running compositor (`build/waylib-smoke/wayland-info.txt`, 53 globals), plus
`WAYLAND_DEBUG` on real clients for the rows marked "seen".

| Protocol | State | Note |
|---|---|---|
| xdg-shell | Offered (v5) | Qt clients, foot, mpv; popups placed from the positioner |
| layer-shell | Offered (v5) | The full Opal shell runs on it; exclusive zones, layers, keyboard modes |
| Xwayland | Offered, seen | Lazy start; glxgears maps and tiles; work area sent when the X WM is up |
| linux-dmabuf | Offered (v4) | From the wlroots renderer |
| presentation-time | Offered (v2), seen, **our patch** | Without patch 2, waylib never sends `presented`; with it mpv gets `presented` events. Headless gives refresh 0 and no vsync flag. |
| viewporter | Offered (v1) | |
| fractional-scale | Offered (v1), seen | Qt client got `preferred_scale(120)` (1.0) |
| cursor-shape | Offered (v2) | |
| pointer-constraints | Offered (v1) | Activated when the surface has keyboard focus; the cursor is not yet held or confined by the compositor |
| relative-pointer | Offered (v1) | Seat motion forwarded |
| text-input v3, input-method v2 | Offered | Also text-input v1 and v2, virtual keyboard; input popups placed at the parent's origin only |
| idle-inhibit, ext-idle-notify | Offered | Inhibitors stop idle notification |
| xdg-activation | Offered (v1) | Any token raises and focuses; no token policy yet |
| xdg-decoration | Offered (v1) | Client-side preferred: Opal draws frames |
| foreign-toplevel | Offered | wlr v3 (Opal's task list uses it) and ext-foreign-toplevel-list v1 |
| ext-session-lock | Offered (v1), seen | Opal lock screen; `locked` is sent at once, not after a blank frame (to fix) |
| screencopy | Offered | wlr-screencopy v3, ext-image-copy-capture v1 with output sources. No toplevel capture source yet, so no live window thumbnails. |
| output-management | Offered (v4) | Test and apply of mode, scale, transform, VRR, enable |
| tearing-control | Offered (v1) | Hint only; the compositor never tears yet |
| xdg-foreign | Offered (v1, v2) | |
| security-context | Offered (v1) | No per-context filtering yet |
| xdg-dialog, toplevel tag, toplevel icon, system bell, content type, single-pixel buffer, alpha modifier | Offered | |
| fifo, commit-timing | Missing, **needs our patch** | Not in wlroots 0.20; backport from wlroots main, then pace in waylib |
| explicit sync (linux-drm-syncobj) | Not offered, **needs our patch** | wlroots has it, but waylib's Qt Quick render path neither waits on acquire points nor signals release points; offering it now would hang clients |
| colour management, HDR | Not offered, **needs our patch** | wlroots 0.20 has the manager; waylib renders through Qt RHI in 8-bit sRGB |
| VRR | Partial | Through output management on DRM only |
| xdg-session-management | Missing, **needs our patch** | Not in wlroots 0.20 |
| DRM leasing | Not offered | DRM only, later |

### What runs (verified, all headless unless marked)

- **Full Opal shell** (`quickshell -p opal/src`, unmodified, isolated exactly as the Qt arm: temp HOME and state,
  private D-Bus, no Hyprland signature): `./run-shell.sh --offscreen --seconds 40 --snapshot`. Screenshots seen:
  `build/shell-run-waylib/01-desktop.png` to `08-lock.png`: taskbar with exclusive zone, three Qt test clients tiled
  above it, Start with search focus, Quick Settings, notification pill, notification centre, lock screen. Exit 0,
  no processes left. The shell needs no change for waylib.
- **Same scenario on the Qt harness**: `./run-shell.sh --impl qt --offscreen ...`, screenshots in
  `build/shell-run-qt/`.
- **foot** starts and tiles (needed `wl_seat` v5 and `wl_data_device_manager` v3; waylib offers v9 and v3).
- **Xwayland**: glxgears (the only X11 client installed; no xeyes, xterm, xclock or xlogo) maps through Xwayland,
  runs at 60 FPS, and tiles. Screenshot with the shell, foot and glxgears: `build/shell-run-waylib-extra/09-extra.png`
  (`./run-shell.sh --offscreen --extra`); without the shell: `build/waylib-smoke/xwayland-foot.png`.
- **Nested Wayland** (visible, 15 s): `./run-nested.sh --seconds 15` with three clients, one closed, exit 0.
- **DRM**: code path written, **not run** (Hyprland owns the seat). See below.

### Frame numbers (same machine, RX 6600)

Busy frames are intervals of 100 ms or less. "Over 25 ms" counts frames that missed a 60 Hz vblank.

| Run | Compositor | Backend | Frames | Median | p95 | p99 | Max | Over 16.7 ms | Over 25 ms |
|---|---|---|---|---|---|---|---|---|---|
| Full shell, 40 s | waylib | headless, 60 Hz paced | 1152 | 16.41 | 16.66 | 18.05 | 99.77 | 4.0 % | 0.3 % |
| Full shell, 40 s | qt | offscreen, not paced | 2313 | 15.47 | 16.88 | 17.68 | 36.23 | 7.6 % | 0.2 % |
| Full shell + foot + glxgears, 46 s | waylib | headless | 1415 | 16.40 | 16.68 | 45.90 | 86.07 | 4.5 % | 1.2 % |
| Stand-in bar, 3 clients, 15 s | waylib | nested on Hyprland | 861 | 16.66 | 16.82 | 17.47 | 50.04 | 18.9 % | 0.1 % |
| Stand-in bar, 3 clients, 15 s | qt | nested on Hyprland (earlier run, above) | 866 | 16.66 | 16.88 | 17.17 | 50.16 | 33.8 % | n/a |
| Stand-in bar, 3 clients, 12 s | waylib | headless | 662 | 16.37 | 16.59 | 17.33 | 20.05 | 3.5 % | 0.0 % |
| Stand-in bar, 3 clients, 12 s | qt | offscreen | 1222 | 8.88 | 16.13 | 17.08 | 19.17 | 2.9 % | 0.0 % |

Reading:
- Nested, both run at the host's 60 Hz with the same median and almost the same tail; waylib has fewer intervals
  just over 16.7 ms. The nested Qt row is from the earlier run, not re-run today (limit on visible windows).
- Headless waylib is paced by the headless output's 60 Hz timer; Qt offscreen is not paced at all (median 8.9 ms).
  So the headless and offscreen rows do not compare one to one. Use them to watch each arm over time.
- The p99 of the extra run comes from Xwayland and foot starting mid-run.
- The 16.7 ms budget sits on the vblank edge; "over 25 ms" is the better miss count.

Frame logs: `build/<run>/frames.json`.

### Gaps and known issues

- One nested run hung at exit: the compositor ignored SIGTERM after `--exit-after` and was stopped by its PID; a
  stale `luna-0` socket was removed. A second nested run (without `DISPLAY` and the Hyprland signature in the
  compositor's environment) exited cleanly. Cause not found. Mitigation: `main()` now forces exit 5 s after the
  event loop ends, and `run-nested.sh` clears `DISPLAY` and `HYPRLAND_INSTANCE_SIGNATURE` for the compositor.
- One output only: every surface enters every output; the scene covers the first output.
- Close motion relies on waylib keeping the last buffer of a destroyed surface; it ran without errors, not checked by eye.
- Pointer constraints are activated but not enforced; xdg-activation has no token policy; `locked` is sent before a
  blank frame is on screen.
- No toplevel capture source, so recents and the task hover card still have no live previews.
- Hyprland-only shell features (workspaces, snap, window rules, convergence moves) still have no compositor side.
- The vendored wlroots differs from Arch's `wlroots0.20`, so it is built from the fork, not taken from the system.

### DRM bring-up from a free VT (not run here)

From a text VT where no compositor holds the seat (log in on Ctrl+Alt+F3; logind or seatd gives the seat):

```
cd ~/lunaos/opal/compositor
./build/luna-compositor --backend drm --frame-log /tmp/luna-drm.json --exit-after 30000
```

`--backend drm` sets `WLR_BACKENDS=drm,libinput` and refuses to start if `WAYLAND_DISPLAY`, `DISPLAY` or
`HYPRLAND_INSTANCE_SIGNATURE` is set. `--exit-after` gives a way back without a keybinding. Start a client from
another VT with `WAYLAND_DISPLAY=luna-0 XDG_RUNTIME_DIR=/run/user/$(id -u) foot`.

### Commands

```
vendor/build-waylib.sh                       # fork: waylib + wlroots + protocol packages into vendor-prefix/
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release && cmake --build build
./run-shell.sh --offscreen --seconds 40 --snapshot --out build/shell-run-waylib          # waylib (default)
./run-shell.sh --impl qt --offscreen --seconds 40 --snapshot --out build/shell-run-qt    # Qt harness
./run-shell.sh --offscreen --seconds 46 --snapshot --extra                               # + foot + X11 client
./run-nested.sh [--impl waylib|qt] [--offscreen] --seconds 15                            # stand-in bar, 3 clients
```

### Next steps

1. **Scene-graph shell surfaces.** Move Opal surfaces from Quickshell layer surfaces into the compositor scene, one
   by one (`opal/docs/quickshell-port-map.md`), so the shell and the windows share one frame clock (§6.1). Start
   with the bar and the task list, which already exist as stand-ins.
2. **DRM from a VT**, then planes: direct scanout for full-screen clients through waylib's output layers.
3. **Fork patches, in order:** explicit sync in the waylib render path; fifo and commit-timing (backport from
   wlroots main); toplevel capture source for live thumbnails; colour management after that.
4. **Integrity's hwcomposer bridge**, later: a wlroots backend (or waylib output) that hands frames to Android
   hwcomposer through Integrity, for phones without mainline DRM.
