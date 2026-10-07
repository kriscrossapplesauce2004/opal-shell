# Opal / Expressive

## October 2026 overhaul

- **Design**: tonal surfaces with little glass, restrained motion (no overshoot), Google Sans Flex type scale with variable axes (`Theme.type`, `MText.role`).
- **Bar**: four styles (`barStyle`: islands, dock, split, edge). Live activity pill for media and focus; volume and workspace changes show inside the bar; the app strip hugs its content and drops titles when crowded.
- **Notifications and controls**: compact tonal toasts; inbox grouped by app; controls and notifications are one sheet with reorderable, optional sections (calendar, monitor, clipboard, focus, batteries, your devices).
- **Start**: category rail, hero greeting and clock, `!` asks Claude through the Claude Code CLI with the Opal MCP server attached. Icons: original, backplate or themed (`iconStyle`).
- **Lock and login**: `LockScreen` (session lock + PAM, Super+L, logind Lock/Unlock) and a greetd greeter sharing `LockScene`. Install the greeter with `opal greeter` (sudo); revert with `opal greeter --revert`. `PolkitDialog` handles authentication with account selection, request details, password visibility, and progress/error feedback. `opal polkit` installs it as the default user service, independent of the shell, and disables hyprpolkitagent. The service starts at graphical login and reads Opal's theme preferences without running another desktop backend. On an older installation, update/reload the shell once to release its embedded agent. Check registration with `quickshell ipc -p ~/.local/share/opal/polkit/polkit.qml call polkit status`.
- **Phone**: editable home pages with widgets, folders and drag to reorder; auto-rotate through iio-sensor-proxy; swipe up on the lock screen.
- **Console**: library from Steam, Steam shortcuts, Prism Launcher, Heroic, Lutris and RetroArch (`game_library.py`), cover grid, rebuilt Play hub.
- **System**: theme export to GTK, Kitty, Qt and window borders; profiles; night light, dark mode and Do not disturb schedules (sun times from the time zone); updates and health; screen arrangement with keep-or-revert; first-start tour.
- **Opal Link** (`opal_link.py`): a KDE Connect protocol 8 device that can import your KDE Connect identity, so paired phones keep working. Opal devices also share what they are doing for "Open here" continuity.
- **Opal MCP server** (`opal_mcp.py`): registered with `claude mcp add` by the installer, so `claude` can read and change the shell.

A Material 3 Expressive-inspired Quickshell, with Pixel-style quick settings, a tablet-style app shelf, dynamic color palettes and genuinely translucent compositor-blurred surfaces. This is an independent shell, not Google software.

## Start / restore

`opal on` starts the shell and temporarily stops/masks DMS. `opal off` restores DMS and your prior Hyprland styling/bindings. DMS is not removed or permanently disabled. The runtime mask and Hyprland style marker disappear at reboot. The original shell was backed up under `~/.local/state/opal/v1-*`.

## Install

From a checkout, run `./install.sh`. It installs missing dependencies through
pacman, dnf, or apt where those packages exist, installs the shell into
`~/.config/quickshell/opal`, and puts `opal` in `~/.local/bin`. For a Lua-based
Hyprland config, it also adds an idempotent, reversible runtime-marker hook to
`~/.config/hypr/hyprland.lua`; the hook only loads Opal bindings while Opal is
on. Existing shell and Hyprland config files are backed up under
`~/.local/state/opal/pre-deploy-*-install`; preferences are preserved. Use
`./install.sh --restart` to install and reload in one step, `--no-deps` to skip
package installation, or `--no-hyprland` to leave Hyprland untouched.

## Material 3 Expressive glass refresh

- Shared tokens in `Theme.qml`: an M3 surface-container ramp, secondary/tertiary containers, glass island/raised/highlight roles, an error role, shape scale and expressive motion curves.
- Every `Surface` gets a soft top sheen. `MButton` uses M3 state layers (8% hover, 14% press), a shape-bounded press pulse and an offset focus ring. `Chip` is a themed assist/filter chip.
- The shelf is a set of translucent glass islands: a Start circle with a live dot that morphs while Start is open, a search pill with an inner field plus clipboard and screenshot shortcuts, circular app bubbles whose focused state morphs to a squircle, a notification island with an unread count, a status island (low-battery and volume-level icons) and a stronger clock island.
- The control panel has round header actions, network and active-app chips, pill-to-squircle tile morphs, thick sliders with in-track icons and M3 stop indicators, and it sizes itself to its content instead of leaving empty space.
- Desktop widgets: a recent-apps card, an analog clock in a four-lobe cookie shape (seconds hand hidden with reduced motion), a date blob with a scalloped month badge, a glass quick-action toolbar and now playing. Widget cards blur the wallpaper region behind them (`Frost.qml`), because compositor blur cannot reach inside the wallpaper surface.
- Media cards show album art inside the disc and as a blurred ambient tint, both masked to shape. Launcher and search filters use icon filter chips. The volume OSD uses glass and has a compositor blur rule.
- GPU-only effects (wallpaper frost, art masks) are not visible in software offscreen renders; there the cards fall back to their tint. `tests/headless.qml` includes `reference-desktop-*` composite scenes over a generated shoreline photo.

## Shortcuts and layouts

- Super+Space: launcher. Super+Comma: shade. Super+N: inbox.
- `opal phone` / Super+Ctrl+P: compact touch-sized app drawer, home clock, bottom Android-style navigation, and an adaptive shell-local keyboard for Opal search fields.
- `opal console` / Super+Ctrl+G: large game-first library, Steam Big Picture button, keyboard / joystick navigation.
- `opal quickaccess` / Super+Ctrl+Q / Guide button: Quick Access over the running game (see Game mode below).
- `opal desktop` / Super+Ctrl+D: restore desktop layout.
- `opal appearance`: personalize colors, light/dark, glass density, local wallpaper images, layout.
- `opal close`: dismiss overlay. `opal inspect`: read-only JSON diagnostics.
- All three layouts are shell layouts, not compositor display rotations or replacements for applications' own UI. Phone mode keeps a shell-local keyboard as a fallback, while Opal also starts Squeekboard as the real Wayland input method when it is installed.

## Game mode

Quick Access is a layer-shell overlay, so it works over any compositor and over fullscreen games. Guide opens it in every layout (turn that off in Quick Access if Steam should keep Guide). It shows the running game with session time, switch and quit, a Performance section, quick settings, notifications and controller batteries.

- **Performance** (`game_perf.py`): the frame limit and overlay level are written to an Opal-owned MangoHud file, `~/.local/state/opal/mangohud/MangoHud.conf`. Your own MangoHud config is never touched. Games that Opal starts get `MANGOHUD_CONFIGFILE`; Steam games need the launch option that Quick Access copies. GameMode status and power profiles come from `gamemoded` and `powerprofilesctl`. The power limit and GPU level rows appear only when the AMD sysfs files already exist and are writable by you; Opal never changes device permissions.
- **Controller navigation everywhere**: while any Opal overlay is open, the D-pad, A, B, X, LB and RB drive it (Quick Settings, notifications, Settings, polkit, lock screen, power menu, keyboard). `ControllerFocus.qml` finds clickable items, moves a visible focus ring between them and scrolls them into view; text fields open the on-screen keyboard. Nothing is handled while no overlay is open, and the joystick stays read-only.
- **Library**: a hero for the selected or last played game, Running and Unplayed lists, sort (RT), a detail sheet (LT) with local Steam playtime from `localconfig.vdf` and a Steam uninstall hand-off, and smooth scrolling.

## Docking and convergence

Open Convergence from the shelf or Quick Settings. Flow uses each output's logical dimensions independently; per-output Auto / Desktop workspace / Touch home overrides are remembered by connector name. A newly attached output gets a 20-second, non-keyboard-exclusive docking welcome. Startup establishes a baseline without opening overlays. Automatic convergence (on by default, per-trigger switches in Settings → Displays): an external keyboard or mouse, the lid, the tablet-mode switch, rotation and monitor hotplug switch each output's layout through `convergence_policy.py`, and every switch shows a non-focus-stealing undo toast. Layouts you set by hand per display always win. With Hyprland, windows follow you: on dock, phone-output windows move to the monitor and that monitor's remembered layout (workspace, floating geometry, fullscreen, keyed by make/model/serial) is restored; on undock they gather back on the phone output. Without Hyprland Opal says it cannot move windows. Phone, tablet and desktop layouts morph with a short animation (none with reduced motion). Input and switch state is read-only (`/proc/bus/input/devices`, EVIOCGSW); Opal never grabs input.

Convergence includes animated device previews, panel arrival motion, reduced-motion control, and working glass density. Touch home is wallpaper-first: clock, search, favorites, a compact now-playing row and recent-app shortcuts — no Quick Settings tiles or sliders. Wide displays put the clock beside the app area. The app switcher uses horizontally snapping cards with real window titles and close/return actions, not fabricated window screenshots. USB-C display-out, display arrangement, resolution, mirroring and application scaling depend on hardware and the compositor; Opal does not provide an Android docking service or phone-as-touchpad input injection. Physical hotplug still needs hardware verification.

## App switcher and phone display corners

Desktop Open, phone Recent and console App switcher share searchable window cards, workspace filtering, close/context actions and keyboard/controller navigation. Clicking a preview dismisses the keyboard-exclusive overlay before focusing the live window’s monitor and workspace. The checked adapter detects native Lua dispatchers (this installation) and retains a legacy CLI fallback; compositor errors are reported rather than silently ignored. App icons prefer an already-running window; Open new instance remains available in the context menu. Phone uses a height-bounded touch carousel; desktop and console use compact grids. Live Wayland screencopy previews are requested only for visible cards while the switcher is open, kept in GPU/session memory and never written to disk. Hyprland addresses resolve through a separately loaded optional adapter; unsupported or unavailable captures are labeled honestly. Physical capture behavior depends on the compositor and is not established by offscreen renders.

Choosing Phone targets the invoking display (remembered as phoneDisplay); other displays retain desktop layout. Flow still supports per-output overrides. The shell publishes resolved phone output names to `$XDG_RUNTIME_DIR/opal-phone-displays`; `hyprland.lua` applies `no_rounding` only to `m[output]` workspace selectors. Leaving phone layout or unplugging removes those selectors on config reload. Global desktop rounding is not set to zero.

## Shelf dragging

Desktop has no top bar. Separate bottom islands hold the launcher/search and circular app icons on the left, with tray, sound, connectivity, battery and clock on the right. There is no shared dock background. The control center, audio drawer, power picker and notifications open above the bottom controls. Phone retains its own status and navigation bars.

Drag taskbar icons horizontally to reorder them. The dragged item lifts, neighbors animate aside, and edges auto-scroll. Drop order is persisted separately from favorites and never moves application windows. A drag suppresses click-to-launch; releasing outside the strip cancels. Ctrl+Left/Right on a focused task also reorders it. New motion respects the reduced-motion preference; auto-hide stays inhibited while dragging or using a task context menu.

## Wallpaper studio

Appearance → Wallpaper studio opens a local thumbnail gallery with folder browsing and individual image selection. No procedural wallpaper artwork is bundled; without an image, the background is a solid theme color. The large preview includes a sample shell surface. Crop/fit and image dimming are draft-only until Apply; Reset restores the saved selection. Gallery discovery is bounded to 120 images / 3,000 entries / three directory levels, skips hidden files and symlink traversal, and never downloads assets. Default roots include Pictures, Pictures/Wallpapers, ~/wallpapers and system wallpaper directories. Image previews are decoded asynchronously at bounded thumbnail sizes. Wallpaper and preview settings are applied together in one preference write.

Phone-mode app drawers use a centered maximum-width area and at most seven columns on large displays, with separate category filters. The normal desktop launcher layout is unchanged.

## Launcher

App grid with fuzzy-ranked search, categories, recently launched apps, and pinned apps. Right-click or long-press to pin. Pins and recents are persisted; the shelf shows your pinned apps (a useful default set before you pin anything).

- Arrow keys: grid navigation. Enter: launch. Escape: close.
- `= (18 + 4) * 3`: safe arithmetic. Enter/click copies result using wl-copy. No eval or command execution.
- `> screenshot`, `> focus`, `> phone`: curated shell actions.
- `? search terms`: explicit Google search in your default browser.
- Apps / At a glance / Open / Style navigation rail (segmented toolbar in phone mode).
- Open lists and focuses live Hyprland windows; other compositors get an explicit unsupported message.

## Shell-local keyboard

Phone search, launcher search, clipboard filtering and console search share the same adaptive keyboard. It uses Material You dynamic colors, touch-width-aware key sizing, key previews, one-shot Shift and Caps Lock, numbers/symbols, cursor movement, held Backspace repeat and a context-specific action key. Editing is selection-aware and deletes common Unicode grapheme sequences such as emoji and combining characters as a unit instead of blindly removing one UTF-16 code unit. Controller search keeps D-pad navigation and selected-key highlighting. Reduced-motion settings apply to keyboard shape and press animations, and secure consumers can disable key previews.

The shell-local keyboard only edits eligible Opal QML text controls and remains the fallback when the system input method is unavailable. When Squeekboard is installed, Opal launches it through an isolated Material You theme wrapper and controls its real session D-Bus interface. Squeekboard then uses the compositor input-method/text-input protocols for ordinary application fields instead of key injection or clipboard replacement. Quick Settings and phone controls expose manual show/hide alongside normal focus-driven visibility.

## Useful things

Working volume/mute and hardware backlight controls, integrated Wi-Fi and Bluetooth detail pages with radio power, scanning, network/password entry, device pairing and connect/disconnect, notifications with actions, DND, actual Wayland idle inhibition, MPRIS media controls/art, 25-minute focus timer with pause/reset/+5, month-browsable calendar, live CPU/RAM, power profiles, screenshot capture, lock and confirmed power operations. Backlight controls only appear when the kernel exposes a backlight device. External monitor DDC brightness is not implemented.

DND suppresses toasts but retains notifications. Inbox is session-only and is not written to disk. Preferences, favorites, recent app IDs: `~/.local/state/opal/preferences.json`. Focus timer is in-memory. UI defaults to Inter + CaskaydiaCove Nerd Font.

## Phone bars

Phone has a dedicated 48-pixel status bar rather than desktop tray controls: clock opens the inbox, unread/quiet status, sound/now-playing, and a combined Wi-Fi/battery Quick Settings target. Hold the clock for quiet mode and personalization; hold connectivity for Wi-Fi and docking. A running focus timer gets a compact shortcut. Back / Home / Recents remain the three-button set, with larger touch targets and Home hold-actions. Gesture navigation has explicit Back and Apps shortcuts; tap the handle for Home, slide sideways or hold for Recents. Back navigates within Opal, never injects an application's Back key. Both bars remain available on full-screen launcher and utility overlays; the shade retains its own controls.

## Console controllers

The Python adapter reads the Linux joystick API at `/dev/input/js*`, without grabbing devices or injecting input. Kernel button and axis maps identify face buttons, shoulders, Start/Guide, Select and D-pad; fixed indices are a fallback when map queries are unavailable. Standard layout: A accept, B back, X pin, Y search, left stick / D-pad navigate, LB/RB change category, Select opens Play hub, Start toggles the library. Guide tap toggles Quick Access (or the library in console mode with no game), Guide held for 0.6 s opens the Claude assistant, and Guide+A always opens Quick Access even when the Guide setting is off. Choose Nintendo in Play hub → Setup to swap face-button actions and their hints. Stick navigation repeats after a short hold; triggers and the right stick are ignored. Keyboard arrows/Enter/Escape, Tab/Shift+Tab, F2 pin, F3 search and Menu also work.

Play hub has Library, Session, Sound and Setup sections. Left/right or LB/RB switches sections; up/down selects and accept activates. Volume, mute, music, session and layout toggles can be used without leaving the menu. Continue includes running games before recently launched games. A quiet play session suppresses popups and inhibits idle without changing saved DND settings; ending it restores the underlying behavior. Navigation is ignored outside console mode and, except Start and Guide, while the library/other overlays are closed. Game input is never intercepted, so a game may also receive controller buttons. Requires an accessible joystick device; no permissions are modified. Physical mappings still need hardware verification. The library, Play hub, search keyboard and app switcher support controllers; general settings dialogs remain touch/mouse/keyboard UI.

## Compatibility / dependencies

Quickshell + Qt Quick Controls + Wayland layer-shell + Python 3. No Hyprland QML imports: launcher, layouts, notifications, tray, preferences and widgets work on other layer-shell compositors. Workspaces/window focus use optional Hyprland CLI. Blur is compositor-provided, not a fake screenshot effect. This installation supplies rules for the installed Lua-config Hyprland; other compositors need their own blur rules. Not a GNOME or X11 panel.

Optional Linux tools: wpctl, playerctl, nmcli, bluetoothctl, brightnessctl, powerprofilesctl, grim, wl-copy, notify-send. Network and Bluetooth settings stay inside Quick Settings, using nmcli and bluetoothctl adapters. Wi-Fi supports visible personal/open networks and saved credentials; enterprise/hidden network configuration is not yet embedded. Bluetooth PIN/passkey confirmation still needs an existing system agent. Credentials are not saved by Opal (NetworkManager may retain its connection profile). Quick Settings includes microphone mute; advanced audio settings elsewhere still open pavucontrol. Screenshots go to Pictures/Screenshots. The media card may load the art URI supplied by your active player. Web search is only on explicit action. No weather or online recommendations are fabricated.

Not bundled: a screen recorder or a full controller mapper. Opal now ships its own lock screen, greetd greeter and polkit agent (see below). The installer now treats Squeekboard as an Opal runtime dependency where the supported package manager provides it; environments without Squeekboard keep the shell-local fallback and report the system keyboard as unavailable. Existing DMS-only shortcuts outside the remapped set remain unavailable while DMS is paused.

## Source

### Compact shell refresh

Start uses a bounded 560 × 590 panel, with category and A–Z app filters,
search across apps/windows/actions, compact recent-app cards and confirmed
session actions. The taskbar supports centered applications, optional titles,
window-count badges, a date clock, and direct notification/settings access.

The compact control panel uses mixed-width tiles, small header actions and
brightness/volume tracks. Edit lets you add, remove and reorder tiles; even an
empty selection is preserved. Unsupported keyboard and power controls stay
disabled. Settings brings connectivity, audio, style, taskbar, phone navigation,
notifications, accessibility, power and display convergence into one searchable
surface. Open it from Start, the control panel, the desktop context menu or
`quickshell ipc -c opal call opal settings`.

Phone home has a bottom favorites dock and search target, a filtered A–Z drawer,
adjustable app density, contextual Back, and a combined controls/notification
shade. All new surfaces use shared Theme roles, including the saved shell-wide
Matugen palette. Offscreen previews copy only theme preferences into temporary
state; they do not deploy or restart the desktop.

```text
src/                 Runtime QML module, Python adapters, assets and Hyprland hook
tests/               Python suites, isolated QML fixtures and render runner
tools/install.sh     Installer implementation
install.sh           Stable installer entry point
```

Runtime files stay together
in `src/` so QML singleton registration and relative backend/asset URLs work
without an import-path shim. Only `src/` is deployed, flat, to the live shell;
test fixtures and tooling are not installed.

From this directory, validate with:

```sh
python3 -m unittest discover -s tests -p 'test_*.py'
python3 tests/test_notifications.py
bash tests/render-offscreen.sh
```

The following filenames are relative to `src/`:

`Theme.qml`, `Surface.qml`, `MButton.qml`, `QuickTile.qml`, `ExpressiveSlider.qml`, `Flower.qml`: design system. `Launcher.qml`, `QuickSettings.qml`, `Dashboard.qml`, `Appearance.qml`: screens. `Hub.qml`: UI state and IPC bridge. `backend.py`: safe JSON-lines adapters and atomic preferences. `shell.qml`: panel/layer layout. `hyprland.lua`: reversible compositor overrides.
