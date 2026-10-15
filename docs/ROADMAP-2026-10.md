# Opal overhaul — October 2026

Decided in the grilling session on 2026-10-07. Every workstream follows these rules.

## Ground rules

- Design: Pixel-level Material 3 Expressive polish is the base. New ideas must be useful in daily use. Do not add novelty or generic filler.
- Targets: OnePlus 7 (Determination guest), generic Linux phones (pmOS/Mobian), tablets, phone-as-dock input, and this desktop.
- Quickshell can wrap any compositor. Keep Hyprland optional (see `../../agents.md` invariants).
- Desktop control and assistant "computer use" go through AT-SPI (Jev), **never screenshots**.
- Telephony (calls/SMS/cellular) is out of scope for now.
- Verify with offscreen renders and unit tests on every change. Deploy to the live shell at milestones, with a backup.

## Workstreams

### A. Phone + tablet (one adaptive mode)
Tablet is part of phone mode. When the output is wide, phone mode becomes a tablet layout. It is not a separate mode.
- Gestures that follow the finger: edge back, home swipe, swipe-and-hold for recents, momentum, and cancellation.
- Make apps fit: phone outputs fullscreen or maximize apps per app, move fields above the keyboard (insets), and scale apps.
- Home and drawer reach Pixel level: grid, folders, widgets, drawer search and density.
- **Task-aware home:** above the grid, show what you were doing: recent files (recently-used.xbel), windows open on other Opal devices (Link), and paused media or games. Use local data only.
- Tablet: a persistent dock that shows running apps, a grid home, split view with a draggable divider, a slide-over floating window, and pen awareness.
- Services without telephony: torch, AOD/ambient lock, battery stats, and notifications on the lock screen.

### B. Game mode (Steam Deck class)
- Quick Access overlay over running games. Guide opens it; Guide+A or hold opens it from inside a game. It shows performance (FPS cap via MangoHud config, gamemode, power profile and TDP where supported), plus brightness, volume, notifications and the active game.
- Controller navigation everywhere: settings, quick settings, notifications, the system keyboard and polkit/lock.
- Keep the read-only joystick invariant. Never grab devices or inject input.

### C. Convergence
- Switch automatically on events: keyboard or mouse attach/detach, lid, the tablet-mode switch and rotation. Every switch offers an undo toast.
- Move apps with you: on dock or undock, move windows between the phone and the monitor, and restore their layout on return.
- Morph phone↔tablet↔desktop with an animation, not a hard swap. Respect reduced motion.

### D. Contextual pills
- A Dynamic Island-style activity system: stacked live activities (media, timer, focus, download/progress, recording, charging, connectivity) that expand in place.
- Apps can push activities: MPRIS, notification progress hints (`value`), and ongoing/resident notifications.
- The same pill appears on the phone status bar and the lock screen.
- Suggestion chips from local signals only, for example: monitor attached → "Use as desktop", Link device → "Resume on phone", a code in a notification → "Copy code".

### E. Claude assistant
- A dedicated panel with conversation, markdown, follow-ups and stop/retry. It is a real assistant, not only Start `!`.
- Hotkeys: Super+A and the Copilot/Assistant key; long-press Home on phone; hold Guide on console.
- Automatic context: the focused app and title, the selection or clipboard.
- Agentic actions through a larger Opal MCP (apps, windows, settings, files) and AT-SPI computer use through Jev. Risky actions need confirmation.

### F. Qt/GTK integration
- Full theme parity: a Kvantum theme generated from the palette, a GTK3/GTK4/libadwaita theme with shapes as well as colors, and a KDE color scheme for KDE apps.
- Live switching: the portal color-scheme (`org.freedesktop.appearance`), gsettings, KDE color reload, and Kitty reload.
- Sync fonts, icons, cursor and scale across Qt, GTK, Electron and XCursor.
- Flatpak: `flatpak override` filesystem access for themes, GTK_THEME and the icon theme. The portal settings must stay consistent.

## Integration

Each workstream works on its own branch. Shared files (`Hub.qml`, `shell.qml`, `backend.py`, `qmldir`, `Theme.qml`) get small additive edits only. Put new logic in new files.

### G. Rooms home (built, then removed 2026-10-07 at the user's request; MorphChip and the contextual pills stay)
The design comes from three rounds of rendered prototypes. `tests/prototypes3.qml` is the visual reference. Renders are in `~/.local/state/opal/artifacts/launcher-prototypes/round3/`. Phone mode gets a `phoneStyle` preference: `classic` (the current home) or `rooms`. Phone and tablet use the same parts.
- **Glance:** the date, a large clock and live chips (media, unread by app, focus timer, docked state) on a scrimmed wallpaper.
- **Earlier chips:** finished things (closed apps, ended games, older files) appear as small chips with an app icon.
- **Ladder:** 2–3 recent live or resumable items. Type size and opacity grow with recency, so the newest item is nearest the room.
- **Rooms:** Hyprland workspaces are rooms. The current room is a card that draws its real tiling, using window geometry from `hyprctl clients` and live screencopy where available. The other rooms are chips under the card, with a "+ Room" chip. Swipe or tap a chip to change room.
- **Pins and bar:** five traditional pinned icons, and the search bar (apps, files, rooms) with the app-drawer button.
- **Drawer:** a Shelf-style sheet with filter chips (All, Running, Games, Files, Dev), Running | Continue cards, then a plain A–Z grid.
- **Docked:** rooms live on the monitor, so on the phone they collapse into chips tagged with the monitor name, and the rest of the phone is the trackpad.
- **Tablet:** glance, Earlier and Ladder in a left column; the room carousel at the right; room chips, pins and a centred bar.
- **Morphs, highest priority first:**
  1. Chip → sheet: tapping any chip grows it in place into its full controls, and it shrinks back to the chip.
  2. Dock: room cards fly to the monitor and leave chips behind; on undock the chips grow back into cards.
  3. Room card ⇄ room chip during a swipe.
  4. A Ladder row → an Earlier chip as it ages.
  Use Material 3 components and shared `Theme` motion, and respect reduced motion.

### H. Quick Settings overhaul (phone and game)
The mobile shade and quick settings, and the game-mode Quick Access, need the same chips-and-morph treatment: tiles that morph into detail sheets, chips for active state, controller-first in game mode.

### I. Desktop with the Rooms paradigm (exploration)
Apply Rooms, chips and morphing to desktop mode: workspaces as rooms in the shelf, Earlier chips, and a glance. Render prototypes first and choose with the user before building.

### I. Home, pills, search, floating (2026-10-14)
Ground-up redesign; full spec in `docs/HOME-PILLS-2026-10.md`. Render round first.
