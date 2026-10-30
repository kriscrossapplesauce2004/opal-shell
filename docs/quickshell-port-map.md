# Quickshell port map (Opal to the Luna compositor)

Snapshot: **2026-10-29**, `opal/src/*.qml` (240 top-level QML files, 98 import Quickshell).
`opal/src` is still changing, so these numbers are a dated snapshot. Regenerate with:

    python3 -I opal/tools/quickshell-inventory.py          # text
    python3 -I opal/tools/quickshell-inventory.py --json   # JSON

The type catalog comes from the installed Quickshell 0.3.2 qmltypes (`/usr/lib/qt6/qml/Quickshell`).

Scope: M0 exit from moonshot §27 ("today's shell QML running inside the Luna compositor") and
the Appendix A mapping. Shim status comes from `opal/compat` (see the last section).

## 1. Totals

| Measure | Count |
|---|---|
| QML files in `opal/src` (top level) | 240 |
| Files that import Quickshell | 98 |
| Quickshell import lines | 153 |
| Distinct Quickshell types and attached/singleton names used | 41 |
| Type occurrences | 640 |
| Files that use a Quickshell type | 80 |

Of the 640 occurrences, 161 are enum values (`WlrLayer`, `WlrKeyboardFocus`, `ExclusionMode`,
`Intersection`). The other 479 are objects, members or singletons.

| Group | Occurrences | Types | Files | Effort (estimate, engineer-weeks) |
|---|---|---|---|---|
| windows/surfaces | 392 (231 objects + 161 enum values) | 10 | 34 | 2-3 |
| core runtime | 172 | 8 | 68 | 2-3 |
| services | 45 | 14 | 11 | 8-12 (backends in Rust services) |
| I/O (Process, FileView) | 20 | 4 | 7 | 3-4 (plus the Python backends they drive) |
| IPC (IpcHandler) | 4 | 1 | 4 | 1 |
| compositor (Wayland) | 6 | 3 | 3 | 3-4 (needs the compositor window model) |
| compositor (Hyprland) | 1 | 1 | 1 | 1 (retired at M6; see section 4) |

Effort figures are rough planning numbers. They assume the compositor exposes a window model,
output list and shell-layer API, and that the Rust services from M1 exist. Services dominate the
total, and most of that is backend work outside QML.

## 2. Per-type inventory

Columns: what the type does for Opal today, and what replaces it in the Luna compositor.
"Shim" means the stand-in in `opal/compat/Luna/Shell` (plain Item or value). "Not shimmed" means
the test harness cannot load it.

### 2.1 Windows and surfaces

| Type (module) | Kind | Uses (files) | What it does for Opal | Luna replacement | Shim |
|---|---|---|---|---|---|
| PanelWindow (Quickshell) | component | 49 (31) | Layer-shell panels: bars, shell surfaces, shade, dock, pickers | Compositor-owned shell-layer Item in the compositor scene | Yes (Item with screen, exclusiveZone, mask, margins) |
| FloatingWindow (Quickshell) | component | 3 (2) | Floating popups in `switch.qml` and `game-session.qml` | Floating shell-layer Item, or a Luna desktop floating window | Yes (Item) |
| WlrLayershell (Quickshell.Wayland) | attached | 139 (30) | Attached props `namespace`, `layer`, `keyboardFocus` on every PanelWindow | Shell-layer properties on the Item (the compositor owns layers and focus) | **No** (blocker 1) |
| WlrLayer (Quickshell.Wayland) | enum | 47 (30) | Layer values `Overlay`, `Top`, `Background` | Compositor layer enum | Yes (enum stand-in) |
| WlrKeyboardFocus (Quickshell.Wayland) | enum | 60 (28) | Focus values `None`, `Exclusive`, `OnDemand` | Compositor focus enum | Yes (enum stand-in) |
| ExclusionMode (Quickshell) | enum | 45 (28) | Exclusive-zone mode, nearly always `Ignore` | Compositor exclusive-zone enum | Yes (enum stand-in) |
| Intersection (Quickshell) | enum | 9 (5) | Region combine or subtract | Compositor input region | Yes (enum stand-in) |
| Region (Quickshell) | component | 38 (17) | Input mask (click-through areas) | Input region on the shell-layer Item | Yes (value only, no effect) |
| WlSessionLock (Quickshell.Wayland) | component | 1 (LockScreen) | Session lock | Compositor session lock (see blocker 5) | No |
| WlSessionLockSurface (Quickshell.Wayland) | component | 1 (LockScreen) | Lock surface per screen | Compositor lock surface | No |

### 2.2 Compositor integration

| Type (module) | Kind | Uses (files) | What it does for Opal | Luna replacement | Shim |
|---|---|---|---|---|---|
| Hyprland (Quickshell.Hyprland) | singleton | 1 (HyprWindowPreview) | Hyprland toplevel list for previews | Compositor window model (blocker 4). Hyprland paths go away at M6 | No |
| ToplevelManager (Quickshell.Wayland) | singleton | 4 (Hub, Taskbar) | Wayland toplevel list, `activeToplevel`, feeds `Hub.windows` | Compositor window model (blocker 4) | No |
| ScreencopyView (Quickshell.Wayland) | component | 1 (WindowPreview) | Live window thumbnail | Compositor texture in the scene (moonshot §7.2, "live thumbnails are textures") | No |
| IdleInhibitor (Quickshell.Wayland) | component | 1 (shell.qml) | Keep the screen awake while media plays | Compositor idle-inhibit protocol (listed in §7.1), or the power service | No |

### 2.3 Core runtime

| Type (module) | Kind | Uses (files) | What it does for Opal | Luna replacement | Shim |
|---|---|---|---|---|---|
| Quickshell (Quickshell) | singleton | 121 (60) | Members: `screens` 65, `iconPath` 26, `env` 23, `watchFiles` 4, `execDetached` 2 | `screens` becomes the compositor output model. `iconPath` becomes an icon service. `env` becomes session env from the compositor. `watchFiles` and `execDetached` become a Luna service call or a C++ helper | Yes for `screens` (from `Qt.application.screens`), `iconPath` and `env` (return empty). `watchFiles` and `execDetached` are inert |
| Scope (Quickshell) | component | 27 (25) | Non-visual grouping | Plain Qt `Item` | Yes |
| ShellRoot (Quickshell) | component | 6 (6) | Root of an entry file | Plain Qt `Item` | Yes |
| Variants (Quickshell) | component | 8 (7) | One surface per screen | Plain Qt `Instantiator` over the compositor's output model | Yes (Instantiator) |
| Singleton (Quickshell) | component | 3 (3) | Root type of singleton files | Plain Qt `QtObject` | Yes |
| LazyLoader (Quickshell) | component | 2 (2) | Load a surface on demand | Plain Qt `Loader` (note the lint rule in §6.3: no synchronous Loader for a surface) | No (not needed by the leaves) |
| DesktopEntries (Quickshell) | singleton | 3 (2) | App index for search and switch | Luna index service (`luna-indexd`, Appendix A) | No |
| SystemClock (Quickshell) | component | 2 (1, Hub) | Clock with seconds | Plain Qt `Timer` and `Date` | No |

### 2.4 I/O

| Type (module) | Kind | Uses (files) | What it does for Opal | Luna replacement | Shim |
|---|---|---|---|---|---|
| Process (Quickshell.Io) | component | 12 (6) | Runs the Python backends (`backend.py`, `status.py`, `switch` engine, greeter info) | Typed clients to Luna services over binary IPC (§6.3). No JSON in the shell | No (blocker 3) |
| FileView (Quickshell.Io) | component | 2 (2) | Reads files (`Hub.qml`, `PolkitDialog`) | Luna service or a C++ model with a file watch | No |
| SplitParser (Quickshell.Io) | component | 4 (4) | Parses `Process` stdout line by line | Disappears with `Process` | No |
| StdioCollector (Quickshell.Io) | component | 2 (1) | Collects `Process` stdout (`GreeterController`) | Disappears with `Process` | No |

### 2.5 IPC

| Type (module) | Kind | Uses (files) | What it does for Opal | Luna replacement | Shim |
|---|---|---|---|---|---|
| IpcHandler (Quickshell.Io) | component | 4 (4) | Shell command endpoint for the `opal` MCP tools and the CLI | A Luna IPC endpoint behind `luna-actions` (Appendix A) with the same command contract | No |

### 2.6 Services

| Type (module) | Kind | Uses (files) | What it does for Opal | Luna replacement | Shim |
|---|---|---|---|---|---|
| Pipewire (Services.Pipewire) | singleton | 10 (2) | Audio sinks, sources and nodes (`nodes` 6) | Luna audio service (M1 service list, "audio") | No |
| PwObjectTracker (Services.Pipewire) | component | 2 (2) | Keeps PipeWire objects bound | Luna audio service client | No |
| PwNodeType (Services.Pipewire) | singleton | 3 (2) | Node type enum | Luna audio service enum | No |
| UPower (Services.UPower) | singleton | 2 (2) | Battery devices | `luna-powerd` | No |
| UPowerDeviceType (Services.UPower) | singleton | 4 (2) | Device type enum | `luna-powerd` enum | No |
| Mpris (Services.Mpris) | singleton | 2 (2) | Media players (`players`) | Luna media service (not yet named in moonshot) | No |
| NotificationServer (Services.Notifications) | component | 1 (Notifier) | Owns the notification daemon | `luna-notifyd` | No |
| NotificationUrgency (Services.Notifications) | singleton | 3 (2) | Urgency enum | `luna-notifyd` enum | No |
| SystemTray (Services.SystemTray) | singleton | 1 (DesktopShelf) | StatusNotifier tray items | `luna-statusd`, or a compositor-owned tray | No |
| Greetd (Services.Greetd) | singleton | 12 (1) | Greeter login sessions (`GreeterController`) | Lunaos greeter in the compositor (Appendix A) | No |
| GreetdState (Services.Greetd) | singleton | 2 (1) | Greetd state enum | Same as Greetd | No |
| PamContext (Services.Pam) | component | 1 (LockController) | PAM check for the lock screen | Compositor-owned auth (§7.3) | No |
| PamResult (Services.Pam) | singleton | 1 (LockController) | PAM result enum | Same as PamContext | No |
| PolkitAgent (Services.Polkit) | component | 1 (PolkitDialog) | Polkit agent dialog | Compositor-owned polkit (Appendix A) | No |

## 3. Effort by group (estimate)

- **windows/surfaces, 2-3 weeks.** The shim `PanelWindow` is already an Item, so the QML side is mechanical. The work is the compositor shell-layer contract (layer, focus, exclusive zone, input region) and rewriting about 139 `WlrLayershell.*` uses across 30 files.
- **core runtime, 2-3 weeks.** Most types are plain Qt already. The real work is the output model (`screens`), the icon service (`iconPath`, 26 uses) and the desktop entry index.
- **services, 8-12 weeks.** Mostly Rust services that M1 already lists (status, audio, network, Bluetooth, power, notifications, displays). The QML rewiring is about 2 weeks. Greetd, PAM and polkit belong in the compositor, and that is a design decision, not a port.
- **I/O, 3-4 weeks.** Removing `Process` and `FileView` is quick once the typed clients exist. The Python backends they drive (`backend.py` is 1,749 lines) are the real cost.
- **IPC, 1 week.** Define the Luna endpoint and keep the `opal` MCP command contract.
- **compositor (Wayland and Hyprland), 3-4 weeks in QML.** Depends on the compositor exposing a window model, thumbnails and idle inhibit. Hyprland paths are retired at M6.

## 4. The five hardest blockers

1. **Layer-shell attached properties (`WlrLayershell.*`, 139 uses in 30 files).** Plain QML cannot
   declare attached properties. The smoke probe `TopBar.qml` fails with "Non-existent attached
   object" (TopBar.qml:13). The compositor needs a native shell-layer contract (layer, focus,
   exclusive zone, input region). Moonshot §7.1 lists layer-shell only as a compatibility protocol,
   so the native contract is undefined.
2. **`Hub.qml` is the choke point.** It holds 28 Quickshell references (`Process`, `FileView`,
   `SplitParser`, `Quickshell.screens`, `ToplevelManager`) and everything reads `Hub.prefs`.
   `Theme.qml` reads `Hub.prefs`, so every themed leaf depends on Hub. Appendix A says to split Hub
   by domain into C++ models. This must happen before the port, not during it.
3. **The Process and FileView backend bridge (20 I/O uses in 7 files).** The shell gets its data by
   running Python backends and parsing stdout. Replacing that means typed Luna clients over binary
   IPC (§6.3), and those services are M1 work. Until they exist, the surfaces show no live data.
4. **The window model.** `Hub.windows` is built from `ToplevelManager` and `Hyprland.toplevels`.
   Thumbnails use `ScreencopyView`. The compositor must expose a toplevel list, activation,
   monitor and workspace per window, and thumbnails as scene textures (§7.2). That API is not
   defined yet. Hyprland-only paths (`HyprWindowPreview`, `Hub.status.hypr` gating) need a decision.
5. **Session and auth (`WlSessionLock`, `PamContext`, `Greetd`, `PolkitAgent`).** These are
   security surfaces. Moonshot §7.3 says security lives in the compositor, but the §7.1 protocol list
   has no session-lock protocol (`ext-session-lock-v1`) and no greeter or PAM plan. This must be
   decided before the lock and greeter can leave Hyprland.

Near-blocker: `IpcHandler` (4 uses) is the endpoint behind the `opal` MCP tools. Its contract has
to survive the move, or the agent tools break.

## 5. Shim status and harness (`opal/compat`)

Layout:

- `opal/compat/Luna/Shell/`: shim types as Items and enum singletons (`qmldir`, `PanelWindow.qml`,
  `FloatingWindow.qml`, `PopupWindow.qml`, `ShellRoot.qml`, `Scope.qml`, `Variants.qml`,
  `Region.qml`, `Singleton.qml`, `QuickshellGlobal.qml`, enum singletons).
- `opal/compat/fake/Quickshell/`: a `Quickshell` module that maps names to the shim files by
  relative `qmldir` paths. Submodules without a shim are stubs with one placeholder type each.
- `opal/compat/stubs/Hub.qml`: test stand-in for Hub, with only the fields Theme and leaves read.
- `opal/compat/run-smoke.sh`: builds `opal/compat/gen/` (symlinks to `opal/src/*.qml`, Hub replaced
  by the stub, `qmldir` with only `Theme` and `Hub`) and runs `smoke.qml` offscreen with
  `qml6 -platform offscreen -I opal/compat/fake`.
- `opal/compat/smoke.qml`: the test.

Result (2026-10-29, `qml6` 6.12.0, offscreen):

| Component | Result |
|---|---|
| MText | Loads and instantiates |
| Glyph | Loads and instantiates |
| Surface | Loads and instantiates |
| ProgressRing | Loads and instantiates |
| SettingsGroup | Loads and instantiates (pulls SettingsLabel and MText) |
| Composition: shim PanelWindow per screen hosting Glyph | Pass (1 offscreen screen) |
| NotificationCard (probe) | Instantiates with runtime warnings. `NotificationUrgency` (Services.Notifications) is not shimmed, so the `critical` binding is undefined |
| TopBar (probe) | Fails: "Non-existent attached object" (`WlrLayershell`), blocker 1 |

Leaves pass 5 of 5. The run exits 0, and probes do not count toward failures.

Harness findings to keep in mind:

- A module-only `qmldir` stub falls back to the system Quickshell plugin ("plugin not found"). A
  placeholder type in each stub stops that.
- Copying all of `opal/src/qmldir` makes Qt load every singleton, including `Activities`, which
  fails on Quickshell.Io. The generated `qmldir` registers only `Theme` and `Hub`.
- Attached properties cannot be shimmed in pure QML (confirmed).
- `Qt.application.screens` gives a working `screens` list offscreen.
- `QT_FORCE_STDERR_LOGGING=1` is needed to see QML console output in this environment.

## 6. Notes

- `opal/tools/quickshell-inventory.py` is stdlib only. It reads the Quickshell qmltypes, strips
  comments and strings, and counts uses per file.
- `opal/compat/gen/` is generated. It is safe to delete and regenerate with `run-smoke.sh`.
