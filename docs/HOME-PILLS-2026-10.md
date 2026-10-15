# Home, pills, search and floating mode — October 2026

Decided in the grilling session on 2026-10-14. This is a ground-up redesign. We do a rendered prototype round first, then build. After this work Opal becomes the live shell again instead of vibeshell.

## Homes

### Phone
- Fix pages. They are broken on the real device.
- Pixel-exact editing:
  - Long-press opens a menu with shortcuts, widgets and uninstall.
  - Icons lift and drag, and the grid reflows live.
  - Hold an item at the screen edge to change page.
  - Widgets come from a bottom-sheet picker with previews and sizes.
- **−1 screen** (swipe right of page 1): every live activity as a full card, the Claude assistant entry, and running agent tasks.
- Live pills dock onto the home as cards. One component morphs from pill to card to home widget.

### Tablet
- Pixel Tablet layout: a wide icon grid with real pages, widgets inline, and a persistent dock of running apps at the bottom.

### Desktop (one page only)
- Real `~/Desktop` folder contents as icons. `.desktop` files show as app icons.
- A free widget canvas: place and resize widgets anywhere, snapped to a grid.
- A task-aware glance appears on the wallpaper whenever the workspace has no windows, and fades out when a window opens.
- Shares a small amount of parts with the phone home. It is not a mirror.

### Widgets
- **Glance:** date, weather, next event and a live activity line. Weather comes from Open-Meteo for a city the user sets, with no geolocation.
- **Media:** the new player.
- **Photos:** a memories or album frame.
- **System/devices:** battery for the phone, headphones and controller, storage, and waiting updates.

## Contextual pills
- New kinds:
  - System ops: package updates and installs, builds, long shell commands, file copies.
  - Agents: Claude Code sessions (through hooks: working, waiting for permission, done; tap to focus the terminal), the Opal assistant (steps, stop, approve), and other agent CLIs through the CLI.
  - Devices: Bluetooth and controller battery, Link, and screen share, camera or mic in use.
- Each kind has a rich card. Media has a scrubber and art, the timer has a ring, and a transfer shows speed, ETA and cancel.
- Colour: a calm tonal tint per kind where it helps, and a neutral surface for plain progress such as downloads.
- Placement:
  - Phone status bar: tap opens the shade with that activity's card on top.
  - Desktop Shelf: the pill morphs upward into the card, and clicking away shrinks it.
  - The lock screen keeps its stack.
- Suggestion chips merge into pills as short-lived pills. They also appear in the search empty state.
- **Live Activity API:**
  - The `opal activity start|update|end` CLI and IPC, with fixed templates: progress, timer, status and media.
  - A `dev.opal.Activities` DBus interface for apps.
  - Opal MCP tools for agents.
  - Existing notification progress and resident hints keep working.

## Media player
- Pixel Quick Settings style:
  - Art fills the card at calm chroma.
  - Squiggly progress with seeking.
  - The app icon and source, with a tap to focus the app.
  - Switching between MPRIS players.
- It never shows the output device name. Output and volume live in their own section below the player.
- The same component is used in the pill card, the audio panel, home widgets and the Media app players in opal-apps.

## Search
- One component for desktop Start, the phone home pill and the tablet bar. It adapts its layout per posture.
- The empty state is minimal: the field, about five frequent apps, and suggestion pills.
- Inline answer cards: calculator, conversions, and Claude answers inline (replacing the `!` prefix) with "continue in panel".
- Results reach into:
  - Opal apps: Files, the Media library, Calendar, Photos and Text Editor recents.
  - Every setting, with inline toggles.
  - Games and Link-device windows.
- Fix the clipping at the left edge and the muddy icon plates.

## Floating window mode (optional)
- A desktop-wide opt-in toggle. Tiling stays the default, and turning the mode off returns every window to tiling.
- M3E Opal titlebars drawn by Opal for windows without CSD, with minimize, maximize and close.
- Snap: drag to edges and corners, and hover maximize for a layout picker.
- Real minimize to the Shelf, with window previews on hover.
- Each app's window geometry is remembered and restored at launch.
- All Hyprland calls go through `src/hypr_actions.py`.

## Fixes requested during the grilling
- Overlay panels play their reveal in reverse on close. The page is latched for the exit, visibility follows `panel.arrival`, and reopening mid-exit reverses smoothly. (Done 2026-10-14.)
- Tapping Super alone toggles Start: a release bind on `SUPER + Super_L` in `src/hyprland.lua`. (Done 2026-10-14.)
- Clicking a pill dismisses the page it opened.
- Long uptime: QML components disappear. Investigate output removal and re-adding (monitor sleep) for windows bound to a stale `Hub.targetScreen`.

## Round 4 renders (2026-10-15)
`tests/prototypes4.qml` → `~/.local/state/opal/artifacts/launcher-prototypes/round4/` (contact sheets `sheet-*.png`). The user's response was "waow".
- Keep the live Quick Settings tile style exactly: dense `ShadeTile`, with a glass body where only the icon square lights up, round icon-only tiles, and `ExpressiveSlider`. Do not draw flat filled tiles.
- Keep the Shelf's right side as separate pills: activity pill, then status icons, then a tinted clock pill. When the activity card is open, its pill gets a tertiary ring.
- Each kind's icon circle carries its accent (tertiary agent, error rec, primary focus, secondary device). Cards stay calm.
