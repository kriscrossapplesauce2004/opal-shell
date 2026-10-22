# Switcher, Settings and the Material look (2026-10-23)

Grilling decisions. Render round 1 comes before any build; the user picks per mode.

## 1. App switcher

What is wrong today (all confirmed): no Alt+Tab; the switcher is an 1100 px sheet docked to the
right with an "App switcher" title; every card carries icon row, close, split, preview, title,
workspace and "Return"; windows are not in recent order; staggered entrance and many live
previews make it slow.

Decided:
- **Alt+Tab** = hold-to-cycle strip. Every window, most recent first. A quick tap goes to the
  last window. Tab / Shift+Tab / arrows cycle, release Alt commits, Escape cancels.
  Hyprland: `ALT + Tab` enters submap `opal-switch`; release of Alt is a compositor bind, so a
  fast tap never leaves the strip open.
- **Super+Tab** = overview.
- Recent order is tracked in the shell (works with Hyprland and generic Wayland).
- Shape is **mode dependent**. Render round 1 shows options for: desktop tiling, desktop
  floating mode, tablet, phone, console.

## 2. Settings

Problems: search only matches section names; looks heavy (tall rows with subtitles, morphing
corners, many tinted badges); every page uses different rows and spacing.

Decided:
- "More how Android does it": Android 16 Settings. Search pill on top, top level as connected
  card groups, subpages with a large title that collapses on scroll, segmented list items,
  switches with a check / cross in the handle.
- Reorganise freely (Wallpaper & style is a junk drawer today).
- Deep search: every setting is indexed. A hit on one setting opens its page, scrolls to the
  row and highlights it.
- One set of row components for every page.

Proposed tree (render round 1):
Network & internet · Connected devices (Bluetooth, Opal Link, controllers) · Apps & windows
(tiling/floating, app switcher, file dialogs) · Notifications · Battery & power (profiles, keep
awake, session, power key) · Sound · Displays (arrangement, what each screen becomes, night
light) · Wallpaper & style (wallpaper, themes, colours, dark theme, icons, Look) · Home & shelf
(layout mode, shelf, pins, desktop widgets, weather) · Phone & gestures · Games & controller ·
Modes & routines (schedules, profiles) · Accessibility · System (updates & health, app themes) ·
About.

## 3. The Material look

Configurable:
- Presets: **Glass**, **Mixed** (solid sheets, menus, Settings and shade; glass shelf, dock and
  home widgets), **Material** (everything solid).
- Per-surface overrides: panels & sheets, menus, shelf & dock, home widgets, shade & Quick
  Settings, lock screen. Any override that differs from the preset shows "Custom".
- Separate switches: compositor blur, glass edges & sheen, elevation shadows, app
  transparency (theme export, e.g. Kitty background opacity).

## 4. Components

New M3 Expressive components: loading indicator (morphing shapes), floating toolbar, split
button. Refresh existing ones to current M3E (switch handle icons, slider, buttons, menus with
Standard / Vibrant styles, search bar, flexible top app bar, segmented list items).

Shape rule: things may squish while pressed; selection still changes colour only.
