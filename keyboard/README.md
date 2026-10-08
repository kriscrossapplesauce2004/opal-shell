# Borealis system keyboard

Standalone Qt Quick frontend with Wayland input-method-v2 text commits and compositor virtual-keyboard events. Borealis is the keyboard identity; the installed binary remains `opal-keyboard` and the compatibility service remains `sm.puri.OSK0` so existing Aurora and Phosh integration does not break.

## Build and isolated validation

```sh
cmake -S . -B /tmp/opal-keyboard-improved-build
cmake --build /tmp/opal-keyboard-improved-build -j4
ctest --test-dir /tmp/opal-keyboard-improved-build --output-on-failure
/tmp/opal-keyboard-improved-build/opal-keyboard --preview --width 390
/tmp/opal-keyboard-improved-build/opal-keyboard --preview --width 1200 --height 800 --placement split
/tmp/opal-keyboard-improved-build/opal-keyboard --preview --width 900 --height 520 --purpose terminal
```

`--preview` uses its own editor and does not connect the system input method. Add `--handheld` to preview controller mode without a gamepad, `--layout` to pick an initial layout, `--purpose` to emulate application content hints, and `--placement` to inspect full, one-handed, and split convergence layouts. `--show` instead opens the real system keyboard for the focused application; use it deliberately. Starting without `--show` waits for input-method activation. No shell restart is required.

## Controls

- Handheld mode activates automatically when a gamepad is connected, or when the host sets `handheld`. The stick or d-pad moves a focus ring, **A** types the focused key, **B** erases, **X** types a space, **Y** toggles Shift, and the shoulder shortcuts switch layout or emoji. A Material controller icon and a short legend appear only in that mode. The adapter reads `/dev/input/js*` read-only and never grabs the device or injects input.
- The number row is permanent on the letter and symbol layouts. It is not a preference or a mode toggle.
- The deck keeps one height and one key size in every mode. The suggestion strip and the number row stay in place when the letter grid changes to symbols.
- Numeric, phone, and URL input purposes open a large numeric keypad automatically.
- **I↔** opens editing controls: Select stays active across arrow steps and spacebar drags; word arrows move or select a word at a time. Inserting text ends selection mode.
- Slide space to move the cursor; Shift extends selection and Ctrl moves by words. Navigation retains modifiers until the next non-navigation action.
- Double-tap Shift for caps lock. Hold letters for accents or top-row numbers; hold Backspace to repeat. Hold a skin-tone emoji for tone variants.
- Emoji has Faces, Hands, Life, and a Recent tab that fills as you type. Recent emoji are session-only.
- Auto-capitalisation starts a sentence after `.`, `!`, or `?` plus a space, and a double space inserts `. ` with the next letter capitalised.
- A key press highlights the whole key immediately, and accent previews draw on a topmost layer so other keys cannot cover them.
- **↔** cycles centred, left-hand, and right-hand placement on wide displays.
- Password/sensitive input suppresses character previews and accent popups. Typed text is not persisted by the frontend. Layout choices are session-only.
- Borealis watches Opal's preference file and follows the shell's live light/dark state, static Iris/Tide/Peach/Sky palettes, generated Material dynamic palette, and reduced-motion preference without restarting the keyboard.
- Suggestions are generated locally from surrounding text, a bounded lexicon, typo correction and small next-word rules. Accepted candidates get session-only ranking weight. Password and terminal contexts suppress suggestions.

## Validation boundary

Keymap, gamepad-mapping, and offscreen UI tests cover typing, replacement of selections, modifiers, layouts, repeat cancellation, accent holds, spacebar movement, simultaneous touches, number-row input, emoji categories, persistent selection, private holds, adaptive geometry at four window sizes, one-handed width, immediate whole-key highlight, topmost previews, purpose-driven keypads, skin-tone variants, controller navigation, auto-capitalisation, double-space punctuation, the recent-emoji tab, and wide-screen side panels. Narrow, small, landscape, wide, digit, emoji, handheld, dark, and light renders were inspected. These do not establish physical touchscreen or application/compositor compatibility; the improved build has not been live-qualified or deployed to Aurora.


## Round 2 overhaul

- **Tools menu.** The apps button at the left of the suggestion bar morphs (container transform, emphasized easing, instant with reduced motion) into a 4x3 grid: Clipboard (count badge), Emoji, Text editing, Trackpad, Terminal keys, One-handed, Floating, Resize, Languages, Symbols, Theme, Settings. Panels replace the keys and share a title bar with a keyboard button back and a settings button.
- **Clipboard.** `ClipboardBridge` runs `quickshell ipc call opal clipboardHistory` (read-only, text only, 3 s limit) against `~/.config/quickshell/opal` or `$OPAL_CONFIG_DIR`. Cards show pinned first, code in monospace, links, `#hex` swatches and image thumbnails. A tap commits the text through the input method and never as key events. The panel is off in sensitive fields and shows an empty state when the shell is not running.
- **Terminal mode** follows the `terminal` purpose or the Terminal keys tool: Esc, Tab, Ctrl, Alt and arrows replace the digit row, digits are hints and long-press types them, shell symbols fill the bottom row, Ctrl latches filled, the bar offers Paste, Ctrl C and Tab, and autocorrect, auto-capitals and double-space periods are off.
- **Floating keyboard** (hosts 720 px or wider). The card is drawn inside a transparent full-height layer surface. The input region is limited to the card, no space is reserved, drag handle moves it, the corner resizes it and a double tap on the handle docks it. Limit: the input-method and layer-shell protocols give no free window positioning, so this is an in-surface card. The input region is set with `QWindow::setMask` and was not tested on a live compositor.
- **Docked bar.** With a physical keyboard attached (`PhysicalKeyboard`, `/proc/bus/input/devices`) the deck shows a slim pill bar: suggestions, emoji, clipboard, show keyboard. The preference `keyboardDocked` is `auto` (default), `always` or `never`. `--docked` previews it.
- **Controller.** Keys are 25 percent larger, the focus ring grows, LB and RB pick the first and last suggestion, LT toggles symbols, RT held moves the text cursor with the stick or d-pad, Start hides. A hint bar lists the buttons.
- **Key style.** `keyboardKeyStyle` is `tonal` (default) or `borderless`. The Theme tool and the settings panel change it for the session only.
- Glide typing is not built.
