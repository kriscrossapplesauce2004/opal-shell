# Pills, Quick Settings, spaces and the lock screen (2026-10-28)

Decided in the 2026-10-28 grilling. Render round 1: `tests/qspl-proto.qml`
(`OPAL_ENTRY=qspl-proto.qml tests/render-offscreen.sh`), review page
https://claude.ai/artifact/VrjbZ1CJKV2Kzx8LJZW133. Numbers below refer to its renders.

## Contextual pills (all surfaces)

- One pill component everywhere: desktop Shelf, phone status bar, tablet bar, lock screen,
  console Quick Access (11).
- Several activities share one **segmented pill**: one pill split into segments with small gaps.
  The most urgent activity leads, is widest and shows its label; the others show an icon and a
  short value; past four, the last segment is a count (09). Hover shows every label.
- Clicking a segment grows it into its card with that kind's own controls; the other activities
  wait as segments on top of the card (10).
- New sources: downloads, file copies, builds, screen recording, game sessions, Android, screen
  share, system updates (09), on top of media, timers, devices and pushed activities.
- **Collapse (ChromeOS style):** one small button folds every contextual pill into a single small
  chip; one click expands them again. The state persists.
- **Level setting:** Full / Calm / Off (Settings, Shelf).
  - Full: as above.
  - Calm: icons only, at most two activity segments, the notification pill never grows (icons +
    count), the clock event segment appears only when the event starts.
  - Off: no contextual pills; workspace, status and clock stay.

## Desktop notification pill

- Desktop only (the phone shade stays merged). Hidden when there are no notifications.
- A new notification grows the pill to "App icon · sender/title · text" for 4 s with a dwell bar,
  then it settles to up to three app icons and a count (01).
- Click pops the notification card up: grouped per app, inline reply and actions, Do not disturb
  and Clear all in the header, a Silent section, Notification settings (02).

## Clock pill and the clock + calendar card

- The clock pill gains an event segment only when the next event needs attention: from 10 min
  before ("Standup in 8 min"), then "Standup now · Join" (01).
- Click opens one combined card: big clock with seconds, date, world clocks, the next alarm and
  running timers, the month with event dots, today's agenda with Join (12).

## Quick Settings

- Desktop: the compact card (A, 03). No notifications and no clock on the desktop.
  Header: battery estimate; edit, lock, power, settings.
- Tiles come in three sizes: round 1×1, wide 2×1, big 2×2 with a live control (media, timer,
  devices). Any tile can take any size it supports.
- Edit mode: remove badges, a resize handle, drag to reorder, a size chooser, a spare-tiles tray
  (05).
- Long-press (right-click on desktop) grows a tile into its detail sheet; back shrinks it into
  the tile (06 Wi-Fi with hidden and enterprise networks, 07 Displays with DDC/CI brightness per
  monitor).
- Phone shade: keeps notifications, gets the new tiles (08).

## Named spaces

- A space can have a name, a Material symbol (searchable picker) and a colour (14).
- Unnamed spaces are auto-named from their main app and marked "auto-named" (13).
- The Shelf pill shows the space's symbol in its colour; a switch flashes the name and apps (01).
- Space menu: Rename, Icon and colour, Save space, Move windows to…, Close space (13).
- **Save space** is explicit: it keeps the apps, layout, symbol and colour. Saved spaces sit in a
  Saved row of the spaces card and in search, and reopen with their apps.

## Lock screen

Priority: customisation, then controls while locked, then expressive motion.

- Clock faces: **Stacked** (hours over minutes) and **Thin**. Colour choice.
- At a glance line under the clock: date, weather, next event, alarms.
- Live activities (the segmented pill) under the glance line.
- Notifications: one chip ("4 notifications" + app icons) that grows into the list (17);
  privacy setting as today; actions and inline reply, which send after unlock.
- Widget stack near the bottom: swipeable, with dots (Now playing, Timers, Calendar, Devices).
- Two corner shortcuts, each any QS tile or app, fired by holding.
- Quick Settings while locked (18): toggles work, private tiles show a lock badge and ask to
  unlock before their sheet opens.
- The editor lives in **Settings → Lock screen** with a live preview (20).

## Bugs to fix on the way

- Settings: rows you click stay highlighted ("elements you click on do not unbrighten").
