# Luna window manager config

This is the compositor-neutral config for the Luna compositor (moonshot section 7.1 and section 10.8).
It holds keybinds, window rules, spaces, monitors, input, layout, animations, autostart and policy.
The schema is `opal/src/luna_wm_schema.json` (JSON Schema, draft 2020-12). It has no Hyprland names.
Hyprland dispatchers and options are mapped to it by `opal/src/hypr_import.py`.

## Top level

| Key | Meaning |
|---|---|
| `version` | Always `1`. |
| `source` | Where the config came from: `compositor`, `files` (for an import) or `preset`. |
| `policy` | Luna behaviour rules from section 7.1. These are defaults, not file settings. |
| `keybinds` | Typed binds: `mods`, `key`, `action`, optional `flags`, `mode`, `description`, `source`. |
| `window_rules` | `match` (class, title, initial_class, initial_title, floating, fullscreen, pinned, xwayland, focused) and `effects`. |
| `layer_rules` | `match.namespace` and effects `no_anim`, `blur`, `ignore_alpha`. |
| `spaces` | Named or numbered spaces: `id`, `kind` (number, named, special), `monitor`, `default`, `persistent`. |
| `monitors` | Per output: `match` (name, description or fallback), `mode`, `position`, `scale`, `rotation`, `flipped`, `vrr`. |
| `input` | Layout, variant, options, numlock, key repeat, touchpad, pointer sensitivity, focus-follows-mouse. |
| `cursor` | Theme, size, hide on touch. |
| `layout` | Algorithm (`dwindle`, `master`, `scrolling`), gaps, border, rounding, opacity, shadow, blur. |
| `animations` | `engine` is always `springs`. Hyprland curves and leaf speeds go in `recorded` for reference. |
| `gestures` | Finger swipes. Only `space_swipe` exists so far. |
| `environment` | Session variables. |
| `autostart` | Each entry has `when`: `login` (once per session) or `reload` (on each config reload). |

`policy` holds three fields, all set by section 7.1:

- `cursor_warps` (default `false`): the pointer does not move on focus or space change.
- `unexpected_float` (default `tile`): a window that floats without a rule is tiled at once.
- `mode_exit` (default `restore_windows`): leaving a mode restores every window.

## Keybind actions

Each action is an object with a `type`. Unknown fields are rejected.

| `type` | Fields | Hyprland source |
|---|---|---|
| `close_window` | `force` | `killactive`, `window.close`, `window.kill` |
| `focus` | `direction` | `movefocus`, `focus({direction})` |
| `focus_window_edge` | `edge` (`first`, `last`) | `focus({window="first"})` |
| `focus_monitor` | `direction` | `focusmonitor`, `focus({monitor})` |
| `move_focused` | `direction` | `movewindow <dir>`, `window.move({direction})` |
| `move_to_monitor` | `direction` | `movewindow mon:`, `window.move({monitor})` |
| `space` | `target`, `move_window`, `follow` | `workspace`, `movetoworkspace(silent)`, `focus/move({workspace})` |
| `resize` | `relative`, `dx`, `dy` or `width`, `height` | `resizeactive`, `window.resize` |
| `resize_mouse` / `move_mouse` | none | `window.resize()` / `window.drag()` with a mouse bind |
| `float` | `mode` (`toggle`, `enable`, `disable`) | `togglefloating`, `setfloating`, `window.float` |
| `fullscreen` | `mode` (`fullscreen`, `maximize`), `action` | `fullscreen`, `window.fullscreen` |
| `pin`, `center`, `raise` | none | `pin`, `centerwindow`, `alterzorder` |
| `snap` | `edge` | Luna only (used by presets) |
| `minimize` | none | Luna only (used by presets) |
| `group` | `op` (`toggle`, `next`, `prev`, `lock`) | `togglegroup`, `group.*` |
| `layout` | `op` (`toggle_split`, `preselect`, `pseudo`), `direction` | `togglesplit`, `layoutmsg`, `layout(...)` |
| `switch_window` | `direction` (`next`, `previous`) | Luna only (used by presets) |
| `exec` | `command` | `exec`, `exec_cmd` |
| `shell` | `intent` | Luna shell intents (launcher, overview, lock and so on) |
| `mode` | `op` (`enter`, `leave`), `name` | `submap`, `submap = reset`, `define_submap` |
| `display_power` | `action` | `dpms` |
| `session` | `op` (`exit`) | `exit` |
| `unbind` | none | `unbind` (the importer removes the bind and does not emit this) |

`space.target` has `kind` (`id`, `name`, `relative`, `empty`, `special`) and `value`.
`relative` values are `+1` and `-1`, from `e+1` and `e-1`.

## Key names and modifiers

- `mods` is a sorted list from: `super`, `shift`, `ctrl`, `alt`, `mod2`, `mod3`, `mod5`.
  Hyprland names map as `SUPER`/`MOD4` to `super`, `CONTROL` to `ctrl`, and `MOD1` to `alt`.
- `key` uses XKB keysym names (`Q`, `left`, `Page_Down`, `XF86AudioRaiseVolume`). Single letters are upper case.
  Pointer buttons keep `mouse:272`, and `code:20` keys stay as they are.
- `flags` has `repeat`, `locked`, `release`, `mouse`. They come from `binde`, `bindl`, `bindr`, `bindm`, or from the `repeating`, `locked`, `release`, `mouse`, `drag` options.

## Window rules and layer rules

Window rules use `match` and `effects` together. A rule with a match key Luna cannot evaluate is dropped and reported,
so it never applies to the wrong windows.

Effects: `float`, `tile`, `center`, `pin`, `fullscreen`, `no_focus`, `no_anim`, `opaque`, `rounding`, `border_width`,
`size` (`width`, `height`), `position` (`x`, `y`), `space` (`id`, `focus`), `opacity` (`active`, `inactive`).

## Input, layout and animations

- `input.layout` and `input.variant` come from `kb_layout` and `kb_variant`. `input.repeat` comes from `repeat_rate` and `repeat_delay`.
- `input.touchpad` comes from `natural_scroll`, `tap_to_click` and `disable_while_typing`.
- `input.pointer.sensitivity` takes values from -1 to 1.
- `layout.border.active_color` and `inactive_color` are `#RRGGBB` or `#RRGGBBAA`. Gradients are reported, not converted.
- Hyprland curves become `animations.recorded.curves` (four numbers each). Leaf speeds and curve names become `animations.recorded.rules`.
  Luna does not use them directly: the shell maps them to spring presets.

## Importer

```
python3 opal/src/hypr_import.py [--config PATH] [--out FILE] [--report]
python3 opal/src/hypr_import.py --preset luna|windows|macos|tiling [--out FILE]
python3 opal/src/hypr_import.py --diff-presets [--json]
python3 opal/src/hypr_import.py --with-opal-overlay ...
```

- It reads Lua (`hyprland.lua`) or legacy `hyprland.conf` (picked by file extension). It never runs Lua.
- It follows `require` and `dofile` relative to the config directory.
- `if` blocks whose condition depends on the runtime (for example, the Opal marker file) are skipped and reported.
  `--with-opal-overlay` runs that branch as if Opal were running. Loops over runtime data are not run.
- Every dropped item goes to `report.unmapped` (with its reason and source line), `report.ignored` (Hyprland-only
  settings), `report.errors` (syntax and missing files), or `report.notes` (overridden or unbound binds).
- Secrets are redacted in exec commands, autostart, environment values and report text (`TOKEN=`, `--token`, `user:pass@`, `Bearer`).
- The tool refuses to write under `~/.config/hypr`.

## Parity

`--diff-presets` compares the imported binds with each preset. For each preset it lists:

- `same`: the same key and the same action.
- `moved`: the same action on a different key.
- `changed`: the same key with a different action.
- `lost`: binds in your config that the preset does not have.
- `gained`: preset binds that your config does not use.

Actions compare with schema defaults filled in, so `follow: true` on a space action matches an omitted `follow`.

## Presets (section 10.8)

`luna`, `windows`, `macos` and `tiling` each emit a full config with keybinds and the default policy.
They use `shell` intents where the shell decides the behaviour. The shell must map these intents: `launcher`, `overview`, `terminal`, `lock`, and so on.

## Not yet in the schema

Hyprland window groups styling, per-space layout and gaps, HDR and colour-management monitor options, plugin options
(hyprbars), and `cursor` timeouts. The importer reports these rather than dropping them.
