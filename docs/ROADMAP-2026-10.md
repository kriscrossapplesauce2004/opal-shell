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
