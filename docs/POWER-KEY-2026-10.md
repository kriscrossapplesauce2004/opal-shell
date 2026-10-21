# Power key menu (2026-10-21)

Grilling and render round 1 decided this. Renders: `artifacts/powermenu-prototypes/round1/` (prototype `tests/powermenu-proto.qml`, motion video `list-motion.mp4`). Chosen look: render `p5-01-drum-edge`, `p5-08`/`p5-09` for submenus, `p5-10` locked, `p5-12`/`p5-13` for Settings.

## Behaviour
- **Tap power (screen on)** opens the menu. It opens on **Sleep** with a countdown ring (default 2 s; Off/1/2/3 s in Settings). With no input it sleeps; any volume press, touch or key cancels the countdown. Tap power again picks the selected row (so tap-tap still sleeps at once).
- **Tap power (screen off)** wakes the screen as today. It does not open the menu.
- **Volume up/down** move the selection while the menu is open; they change volume again once it closes.
- **Motion: drum picker.** The highlight stays in the centre and the list rolls past it, rows fading with distance. It stops at the ends (no wrap).
- **Placement: edge sheet** beside the power key, sliding in from that edge. Round arrow hints sit at the volume rocker and light up on press. The device profile sets the key edge and positions (OnePlus 7: volume on the left, power on the right).
- **Submenus** (`>` rows) open in place. Their first row is **Back**.
- **Touch too:** tap a row to pick it, flick the drum, tap outside to close.
- **Haptics:** a short tick per step, a firmer one on pick (feedbackd; no-op without it).
- **Live state in rows:** Flashlight On, track now playing, current mode, and similar.
- **Locked:** the menu works. Sleep, Power and Media work directly. Displays, Contacts and Switch user show a lock and ask to unlock first (like notification actions).
- **Other presses** (double-press, hold, power+volume-down) do **nothing by default**. Each can be set in Settings to any catalogue action. The kernel/PMIC force-off on a long hold is untouched.

## Devices
- **Phone and tablet:** the hardware power key.
- **Desktop:** the power key is **not** taken (logind keeps it). A Super chord opens the same menu, driven by arrows/Enter/Escape and the mouse.
- **Game mode:** hold Guide opens it, driven by the D-pad, A to pick and B to go back.

## Default menu
Displays › · Contacts › · **Sleep** · Power › · Media › · Switch user

- **Displays ›** is one flat list with group labels. *Mode:* Phone, Tablet, Desktop, Game (current one ticked). *Outputs* (only while a second display or dock is attached): Mirror, Extend, This screen only, Cast….
- **Contacts ›** lists starred contacts from the Contacts app (CardDAV), then a per-contact submenu: Call, Text, Share to them (current screenshot/file/link), plus more where a handler exists. On a phone, Call and Text go through the system dialer and messaging apps (ModemManager: GNOME Calls / Chatty). On desktop they go through a linked phone (KDE Connect).
- **Power ›** Restart, Shut down, Log out, Lock.
- **Media ›** Play/Pause (now playing as its subtitle), Next, Previous.
- **Switch user** is **fast user switching**: the current session keeps running, and another user logs in through the Opal greeter on a new VT. Switching back returns to the locked session.

## Customising (Settings › Power key)
- Reorder rows (drag handle), remove them, choose the row the menu starts on, add submenus ("folders") and reset to the defaults.
- **Add action** is a chip sheet grouped as Device (Flashlight, Rotation lock, Airplane, Do not disturb, Hotspot, Keep awake, Ring/vibrate), Capture (Screenshot, Record screen, Camera, Voice memo), Shell (Ask Claude, Search, Notifications, Quick settings, Clipboard, Game mode, Lock), Media & people (Media, Contacts, Output, Cast) and Yours (Open app…, Run command…, Open link…, Submenu…). It has a search field.
- Countdown: Off / 1 s / 2 s / 3 s. Other presses: double-press, hold, power+volume-down, each with an action picker.
- Stored in preferences as `powerMenu` (tree of `{action, args?, label?, items?}`), `powerMenuStart`, `powerMenuCountdown`, `powerPress` (`{double, hold, chord}`).

## Plumbing
- The backend holds a logind `handle-power-key` inhibitor while Opal runs on a phone or tablet, so logind stops suspending on the key. If Opal dies, the inhibitor goes with it and the key falls back to plain logind sleep.
- Hyprland binds `XF86PowerOff` to `opal powerkey` (press/release, for double and hold timing). While the menu is open, a submap takes over `XF86AudioRaiseVolume`/`XF86AudioLowerVolume` and Escape. Binds go through `src/hypr_actions.py`.
