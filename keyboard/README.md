# Borealis System Keyboard

Borealis (`opal-keyboard`) is Opal's standalone Qt Quick on-screen keyboard for Wayland, using `input-method-v2` text commits and compositor `virtual-keyboard` events. It also exposes the `sm.puri.OSK0` D-Bus interface for compatibility with Phosh and mobile shell toggles.

## Build & Preview

```sh
cmake -S . -B build
cmake --build build -j4
ctest --test-dir build --output-on-failure

# Preview layouts in an isolated window without attaching to the system input method:
./build/opal-keyboard --preview --width 390
./build/opal-keyboard --preview --width 1200 --height 800 --placement split
./build/opal-keyboard --preview --width 900 --height 520 --purpose terminal
./build/opal-keyboard --preview --handheld
```

Pass `--show` to open the live system keyboard for the focused Wayland application, or run without flags to wait for `input-method-v2` activation.

## Features

- **Adaptive layouts** — Full width on phones, and centered, left-handed, right-handed, split (`↔`), or floating draggable card on tablets and desktops (720 px and wider). Automatically collapses to a slim suggestion/clipboard pill bar when a physical keyboard is attached (`--docked`).
- **Permanent number row & stable deck height** — The top number row and suggestion strip stay fixed in place when switching between letter, symbol, and emoji grids. Numeric, phone, and URL fields open a dedicated keypad automatically.
- **Word suggestions & typing aids** — Local prefix/typo suggestions from surrounding text, auto-capitalization after sentence punctuation, double-space period insertion, long-press accents and skin-tone variants, and held Backspace repeat. Suggestions and key popups are automatically suppressed in password and terminal fields.
- **Tools drawer** — The apps button on the suggestion bar opens a 4×3 tool grid:
  - **Clipboard** — Queries Opal's clipboard history (`quickshell ipc call opal clipboardHistory`) with pinned items, code formatting, `#hex` color swatches, and image thumbnails.
  - **Emoji** — Categorized Faces, Hands, Life, and session Recent tabs.
  - **Text editing (`I↔`)** — Selection toggle, word-step arrows, and spacebar cursor dragging (`Shift` extends selection, `Ctrl` jumps by word).
  - **Terminal mode** — Replaces the top row with `Esc`, `Tab`, `Ctrl`, `Alt`, and arrow keys, adds shell symbols to the bottom row, and offers quick `Paste`, `Ctrl+C`, and `Tab` actions.
  - **Trackpad, One-handed, Floating, Resize, Languages, Theme (`tonal` / `borderless`), and Settings**.
- **Controller mode** — Activates automatically when a gamepad is connected (`--handheld`). Scales keys by 1.25×, moves a focus ring with the stick or D-pad, and binds **A** (type), **B** (backspace), **X** (space), **Y** (Shift), **LB/RB** (suggestions), **LT** (symbols), **RT + stick** (cursor move), and **Start** (hide).
- **Live Opal theming** — Watches `~/.local/state/opal/preferences.json` and updates light/dark mode, Material You dynamic palettes, and reduced-motion settings on the fly.
