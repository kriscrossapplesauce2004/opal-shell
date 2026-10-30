import json
import pathlib
import sys
import tempfile
import textwrap
import unittest

SOURCE = pathlib.Path(__file__).resolve().parents[1] / 'src'
sys.path.insert(0, str(SOURCE))
import hypr_import as hi  # noqa: E402


def write(root, rel, text):
    path = pathlib.Path(root) / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(textwrap.dedent(text), encoding='utf-8')
    return path


def run_lua(text, extra=None):
    """Write a hyprland.lua fixture and import it."""
    with tempfile.TemporaryDirectory(prefix='hypr-import-') as root:
        write(root, 'hyprland.lua', text)
        for rel, body in (extra or {}).items():
            write(root, rel, body)
        cfg, rep = hi.import_config(pathlib.Path(root) / 'hyprland.lua')
    return cfg, rep


def run_conf(text, extra=None):
    with tempfile.TemporaryDirectory(prefix='hypr-import-') as root:
        write(root, 'hyprland.conf', text)
        for rel, body in (extra or {}).items():
            write(root, rel, body)
        cfg, rep = hi.import_config(pathlib.Path(root) / 'hyprland.conf')
    return cfg, rep


class LuaBindTests(unittest.TestCase):
    def test_binds_with_variables_and_dispatchers(self):
        cfg, rep = run_lua('''
            local mod = "SUPER"
            hl.bind(mod .. " + Q", hl.dsp.window.close())
            hl.bind(mod .. " + SHIFT + left", hl.dsp.window.move({ direction = "l" }))
            hl.bind("SUPER + 3", hl.dsp.focus({ workspace = "3" }))
            hl.bind("SUPER + SHIFT + 3", hl.dsp.window.move({ workspace = "3" }))
            hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
            hl.bind("SUPER + R", hl.dsp.layout("togglesplit"))
            hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Move" })
            hl.bind("SUPER + code:20", hl.dsp.window.resize({ x = -100, y = 0, relative = true }))
            hl.bind("Print", hl.dsp.exec_cmd("rishot"))
        ''')
        by_key = {(tuple(b['mods']), b['key']): b for b in cfg['keybinds']}
        self.assertEqual(by_key[(('super',), 'Q')]['action'], {'type': 'close_window'})
        self.assertEqual(by_key[(('shift', 'super'), 'left')]['action'], {'type': 'move_focused', 'direction': 'left'})
        self.assertEqual(by_key[(('super',), '3')]['action']['target'], {'kind': 'id', 'value': '3'})
        self.assertTrue(by_key[(('shift', 'super'), '3')]['action']['move_window'])
        self.assertEqual(by_key[(('super',), 'F')]['action'], {'type': 'fullscreen', 'mode': 'maximize', 'action': 'toggle'})
        self.assertEqual(by_key[(('super',), 'R')]['action'], {'type': 'layout', 'op': 'toggle_split'})
        self.assertEqual(by_key[(('super',), 'mouse:272')]['flags'], {'mouse': True})
        self.assertEqual(by_key[(('super',), 'mouse:272')]['description'], 'Move')
        self.assertEqual(by_key[(('super',), 'code:20')]['action'], {'type': 'resize', 'relative': True, 'dx': -100, 'dy': 0})
        self.assertEqual(by_key[((), 'Print')]['action'], {'type': 'exec', 'command': 'rishot'})
        self.assertEqual(rep['counts']['unmapped'], 0)

    def test_unbind_and_override_are_recorded(self):
        cfg, rep = run_lua('''
            hl.bind("SUPER + Q", hl.dsp.window.close())
            hl.bind("SUPER + Q", hl.dsp.exec_cmd("kitty"))
            hl.bind("Print", hl.dsp.exec_cmd("grim"))
            hl.unbind("Print")
        ''')
        self.assertEqual(len(cfg['keybinds']), 1)
        self.assertEqual(cfg['keybinds'][0]['action'], {'type': 'exec', 'command': 'kitty'})
        self.assertTrue(any('replaces' in n for n in rep['notes']))
        self.assertTrue(any('unbind removes' in n for n in rep['notes']))

    def test_submap_binds_get_mode(self):
        cfg, _ = run_lua('''
            hl.define_submap("resize", function()
                hl.bind("right", hl.dsp.window.resize({ x = 20, y = 0, relative = true }))
                hl.bind("Escape", hl.dsp.submap("reset"))
            end)
            hl.bind("SUPER + R", hl.dsp.submap("resize"))
        ''')
        modes = [b.get('mode') for b in cfg['keybinds']]
        self.assertEqual(modes.count('resize'), 2)
        leave = [b for b in cfg['keybinds'] if b['key'] == 'Escape'][0]
        self.assertEqual(leave['action'], {'type': 'mode', 'op': 'leave'})
        enter = [b for b in cfg['keybinds'] if b['key'] == 'R'][0]
        self.assertEqual(enter['action'], {'type': 'mode', 'op': 'enter', 'name': 'resize'})

    def test_lua_function_bind_is_reported(self):
        cfg, rep = run_lua('hl.bind("SUPER + X", function() print("x") end)')
        self.assertEqual(cfg['keybinds'], [])
        self.assertIn('Lua function', rep['unmapped'][0]['reason'])

    def test_unknown_dispatcher_is_reported(self):
        cfg, rep = run_lua('hl.bind("SUPER + Y", hl.dsp.pass({}))')
        self.assertEqual(cfg['keybinds'], [])
        self.assertTrue(rep['unmapped'])


class LuaRuleTests(unittest.TestCase):
    def test_window_rules_match_and_effects(self):
        cfg, rep = run_lua('''
            hl.window_rule({ match = { class = "^(pavucontrol)$" }, tile = true })
            hl.window_rule({ match = { class = "^(steam)$", title = "^(notif)" }, no_initial_focus = true, pin = true })
            hl.window_rule({ name = "pip", match = { class = "^(firefox)$", title = "^(Picture)$" }, float = true,
                             size = { x = 640, y = 360 }, opacity = 0.9, workspace = "3 silent" })
            hl.window_rule({ match = { tag = "x" }, float = true })
            hl.window_rule({ match = { class = "^(game)$" }, ["hyprbars:no_bar"] = true, float = true })
        ''')
        rules = cfg['window_rules']
        self.assertEqual(rules[0]['effects'], {'tile': True})
        self.assertEqual(rules[1]['effects'], {'no_focus': True, 'pin': True})
        self.assertEqual(rules[1]['match'], {'class': '^(steam)$', 'title': '^(notif)'})
        pip = rules[2]
        self.assertEqual(pip['name'], 'pip')
        self.assertEqual(pip['effects']['size'], {'width': 640, 'height': 360})
        self.assertEqual(pip['effects']['space'], {'id': '3', 'focus': False})
        self.assertEqual(pip['effects']['opacity'], {'active': 0.9, 'inactive': 0.9})
        self.assertEqual(len(rules), 4)
        self.assertTrue(any('tag' in u['item'] or 'match tag' in u['item'] for u in rep['unmapped']))
        self.assertTrue(any('hyprbars' in i['item'] for i in rep['ignored']))

    def test_monitors_fallback_and_transform(self):
        cfg, _ = run_lua('''
            hl.monitor({ output = "eDP-2", mode = "2560x1600@239.999", position = "2697x0", scale = 1, vrr = 1 })
            hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
            hl.monitor({ output = "DP-3", mode = "1920x1080", position = "auto", transform = 5, vrr = 2, bitdepth = 10 })
        ''')
        mons = cfg['monitors']
        self.assertEqual(mons[0]['match'], {'name': 'eDP-2'})
        self.assertEqual(mons[0]['mode'], {'width': 2560, 'height': 1600, 'refresh': 239.999})
        self.assertEqual(mons[0]['vrr'], 'on')
        self.assertEqual(mons[0]['position'], {'x': 2697, 'y': 0})
        self.assertEqual(mons[1]['match'], {'fallback': True})
        self.assertEqual(mons[1]['position'], 'auto')
        self.assertEqual(mons[2]['rotation'], 90)
        self.assertTrue(mons[2]['flipped'])
        self.assertEqual(mons[2]['vrr'], 'fullscreen_only')

    def test_workspace_rules_and_loops(self):
        cfg, _ = run_lua('''
            for i = 1, 3 do
                hl.workspace_rule({ workspace = tostring(i), monitor = "DP-1" })
            end
            hl.workspace_rule({ workspace = "name:Play", monitor = "HDMI-A-1", default = true })
        ''')
        ids = [(s['id'], s['kind'], s.get('monitor')) for s in cfg['spaces']]
        self.assertEqual(ids, [('1', 'number', 'DP-1'), ('2', 'number', 'DP-1'), ('3', 'number', 'DP-1'),
                               ('Play', 'named', 'HDMI-A-1')])
        self.assertTrue(cfg['spaces'][3]['default'])


class LuaFileTests(unittest.TestCase):
    def test_require_and_comments_and_sourced_files(self):
        with tempfile.TemporaryDirectory(prefix='hypr-import-') as root:
            write(root, 'hyprland.lua', '''
                -- top comment
                --[[ block
                comment ]]
                require("dms.binds")
                hl.config({ general = { gaps_in = 7 } })  -- inline
            ''')
            write(root, 'dms/binds.lua', 'hl.bind("SUPER + T", hl.dsp.exec_cmd("kitty"))\n')
            write(root, 'dms/input.lua', 'hl.config({ input = { kb_layout = "us" } })\n')
            cfg, rep = hi.import_config(pathlib.Path(root) / 'hyprland.lua')
        self.assertEqual(cfg['layout']['gaps'], {'inner': 7})
        self.assertEqual(cfg['keybinds'][0]['action'], {'type': 'exec', 'command': 'kitty'})
        self.assertTrue(any(p.endswith('dms/binds.lua') for p in rep['files']['loaded']))
        self.assertTrue(any(p.endswith('dms/input.lua') for p in rep['files']['not_loaded']))

    def test_missing_module_is_an_error(self):
        _, rep = run_lua('require("nope.absent")')
        self.assertTrue(any('not found' in e['message'] for e in rep['errors']))

    def test_runtime_conditional_is_reported_not_run(self):
        cfg, rep = run_lua('''
            local marker = io.open("/run/user/1000/opal-active", "r")
            if marker then
                hl.bind("SUPER + space", hl.dsp.exec_cmd("opal"))
            end
        ''')
        self.assertEqual(cfg['keybinds'], [])
        self.assertTrue(any('runtime state' in u['reason'] for u in rep['unmapped']))

    def test_assume_opal_runs_overlay_branch(self):
        with tempfile.TemporaryDirectory(prefix='hypr-import-') as root:
            write(root, 'hyprland.lua', '''
                local marker = io.open("/run/user/1000/opal-active", "r")
                if marker then
                    marker:close()
                    hl.bind("SUPER + space", hl.dsp.exec_cmd("opal launcher"))
                end
            ''')
            cfg, _ = hi.import_config(pathlib.Path(root) / 'hyprland.lua', assume_opal=True)
        self.assertEqual(cfg['keybinds'][0]['action'], {'type': 'exec', 'command': 'opal launcher'})

    def test_malformed_lines_go_to_errors(self):
        cfg, rep = run_lua('''
            hl.bind("SUPER + A", hl.dsp.window.close())
            hl.bind("SUPER + B" hl.dsp.window.close())
            hl.bind("SUPER + C", hl.dsp.window.close())
        ''')
        keys = [b['key'] for b in cfg['keybinds']]
        self.assertIn('A', keys)
        self.assertIn('C', keys)
        self.assertTrue(rep['errors'])

    def test_options_and_policy_defaults(self):
        cfg, _ = run_lua('''
            hl.config({
                general = { gaps_in = 5, gaps_out = 8, border_size = 2, layout = "dwindle",
                            col = { active_border = "rgba(cbb5edee)" } },
                decoration = { rounding = 12, shadow = { enabled = true, offset = "0 5", color = "rgba(00000070)" } },
                input = { kb_layout = "gb", touchpad = { natural_scroll = true }, repeat_rate = 30 },
                cursor = { no_warps = true },
                misc = { disable_hyprland_logo = true },
                general_unknown = { foo = 1 },
            })
        ''')
        self.assertEqual(cfg['layout']['border'], {'width': 2, 'active_color': '#CBB5EDEE'})
        self.assertEqual(cfg['layout']['shadow'], {'enabled': True, 'offset': [0, 5], 'color': '#00000070'})
        self.assertEqual(cfg['input']['layout'], 'gb')
        self.assertEqual(cfg['input']['repeat'], {'rate': 30})
        self.assertIs(cfg['policy']['cursor_warps'], False)
        self.assertEqual(cfg['policy']['unexpected_float'], 'tile')

    def test_animations_recorded_and_springs(self):
        cfg, _ = run_lua('''
            hl.curve("easeOut", { type = "bezier", points = { { 0.1, 0.2 }, { 0.3, 1.0 } } })
            hl.animation({ leaf = "windowsIn", enabled = true, speed = 3, bezier = "easeOut" })
        ''')
        self.assertEqual(cfg['animations']['engine'], 'springs')
        self.assertEqual(cfg['animations']['recorded']['curves'][0]['points'], [0.1, 0.2, 0.3, 1.0])
        self.assertEqual(cfg['animations']['recorded']['rules'][0]['leaf'], 'windowsIn')

    def test_hyprland_start_autostart_and_redaction(self):
        cfg, rep = run_lua('''
            hl.on("hyprland.start", function()
                hl.exec_cmd("sync-tool --token=abc123secret")
                hl.exec_cmd("systemctl --user start hyprland-session.target")
            end)
            hl.env("XCURSOR_THEME", "Bibata")
            hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
        ''')
        self.assertEqual(cfg['autostart'][1]['when'], 'login')
        self.assertNotIn('abc123secret', json.dumps(cfg))
        self.assertIn('[REDACTED]', cfg['autostart'][0]['command'])
        self.assertGreaterEqual(rep['redacted'], 1)
        self.assertEqual(cfg['cursor']['theme'], 'Bibata')
        self.assertEqual(cfg['gestures'][0]['action'], 'space_swipe')


class ConfTests(unittest.TestCase):
    def test_legacy_conf_binds_variables_and_flags(self):
        cfg, rep = run_conf('''
            $mod = SUPER
            bind = $mod, Q, killactive,
            bind = $mod SHIFT, left, movewindow, l
            bindm = $mod, mouse:272, movewindow
            binde = $mod, minus, resizeactive, -100 0
            bindd = $mod, Return, Terminal, exec, kitty --title "a, b"
            bind = , Print, exec, grim -g "$(slurp)"
            bind = $mod, Y, pass, ^(foo)$
        ''')
        by_key = {(tuple(b['mods']), b['key']): b for b in cfg['keybinds']}
        self.assertEqual(by_key[(('super',), 'Q')]['action'], {'type': 'close_window'})
        self.assertEqual(by_key[(('shift', 'super'), 'left')]['action'], {'type': 'move_focused', 'direction': 'left'})
        self.assertEqual(by_key[(('super',), 'mouse:272')]['flags'], {'mouse': True})
        self.assertEqual(by_key[(('super',), 'minus')]['flags'], {'repeat': True})
        self.assertEqual(by_key[(('super',), 'minus')]['action'], {'type': 'resize', 'relative': True, 'dx': -100, 'dy': 0})
        self.assertEqual(by_key[(('super',), 'Return')]['description'], 'Terminal')
        self.assertEqual(by_key[(('super',), 'Return')]['action'], {'type': 'exec', 'command': 'kitty --title "a, b"'})
        self.assertEqual(by_key[((), 'Print')]['action']['command'], 'grim -g "$(slurp)"')
        self.assertTrue(any("'pass'" in u['reason'] for u in rep['unmapped']))

    def test_legacy_rules_monitors_workspaces_autostart(self):
        cfg, rep = run_conf('''
            monitor = DP-1, 2560x1440@144, 0x0, 1
            monitor = HDMI-A-1, disable
            workspace = 1, monitor:DP-1, default:true
            windowrulev2 = float, class:^(pavucontrol)$, title:^(Volume)$
            windowrule = tile, ^(kitty)$
            windowrulev2 = pin, tag:foo
            layerrule = noanim, ^(quickshell)$
            exec-once = waybar
            exec = notify-send reloaded
            env = XCURSOR_SIZE,24
            gesture = 3, horizontal, workspace
            animation = windows, 1, 3, default
            bezier = easeOut, 0.1, 0.2, 0.3, 1.0
        ''')
        self.assertEqual(cfg['monitors'][0]['match'], {'name': 'DP-1'})
        self.assertEqual(cfg['monitors'][0]['mode'], {'width': 2560, 'height': 1440, 'refresh': 144.0})
        self.assertEqual(cfg['monitors'][1]['enabled'], False)
        self.assertEqual(cfg['spaces'][0]['monitor'], 'DP-1')
        self.assertTrue(cfg['spaces'][0]['default'])
        self.assertEqual(cfg['window_rules'][0]['match'], {'class': '^(pavucontrol)$', 'title': '^(Volume)$'})
        self.assertEqual(cfg['window_rules'][0]['effects'], {'float': True})
        self.assertEqual(cfg['window_rules'][1]['match'], {'class': '^(kitty)$'})
        self.assertEqual(cfg['layer_rules'][0]['effects'], {'no_anim': True})
        self.assertEqual([a['when'] for a in cfg['autostart']], ['login', 'reload'])
        self.assertEqual(cfg['cursor']['size'], 24)
        self.assertEqual(cfg['gestures'][0]['fingers'], 3)
        self.assertEqual(cfg['animations']['recorded']['curves'][0]['name'], 'easeOut')
        self.assertTrue(any('tag' in u['item'] for u in rep['unmapped']))

    def test_conf_sections_source_and_submap(self):
        cfg, _ = run_conf('''
            source = ./extra.conf
            input {
                kb_layout = gb
                touchpad {
                    natural_scroll = true
                }
            }
            submap = resize
            bind = , right, resizeactive, 20 0
            submap = reset
        ''', extra={'extra.conf': 'general {\n    gaps_in = 3\n}\n'})
        self.assertEqual(cfg['input']['layout'], 'gb')
        self.assertEqual(cfg['input']['touchpad'], {'natural_scroll': True})
        self.assertEqual(cfg['layout']['gaps'], {'inner': 3})
        self.assertEqual(cfg['keybinds'][0]['mode'], 'resize')


class PresetAndParityTests(unittest.TestCase):
    def test_presets_are_well_formed(self):
        for name in hi.PRESET_NAMES:
            cfg = hi.preset_config(name)
            self.assertEqual(cfg['version'], 1)
            self.assertTrue(cfg['keybinds'], name)
            for b in cfg['keybinds']:
                self.assertIn(b['action']['type'], KNOWN_ACTIONS, name)
                for m in b['mods']:
                    self.assertIn(m, MODS, name)

    def test_schema_top_level_keys_cover_output(self):
        schema = json.loads((SOURCE / 'luna_wm_schema.json').read_text(encoding='utf-8'))
        cfg, _ = run_lua('hl.bind("SUPER + Q", hl.dsp.window.close())')
        self.assertLessEqual(set(cfg), set(schema['properties']))
        self.assertLessEqual(set(hi.preset_config('luna')), set(schema['properties']))

    def test_diff_reports_lost_and_gained(self):
        user = [{'mods': ['super'], 'key': 'Q', 'action': {'type': 'close_window'}},
                {'mods': ['super'], 'key': 'Y', 'action': {'type': 'exec', 'command': 'x'}}]
        diff = hi.diff_presets(user, presets=('tiling',))
        d = diff['tiling']
        self.assertEqual(len(d['same']), 1)
        self.assertEqual([b['key'] for b in d['lost']], ['Y'])
        self.assertTrue(any(b['key'] == 'Return' for b in d['gained']))
        text = hi.format_diff(diff)
        self.assertIn('lost    SUPER+Y', text)

    def test_space_defaults_compare_equal(self):
        user = [{'mods': ['super'], 'key': '1', 'action': {'type': 'space', 'target': {'kind': 'id', 'value': '1'}}}]
        d = hi.diff_presets(user, presets=('luna',))['luna']
        self.assertTrue(any(b['key'] == '1' for b in d['same']))


class OutputSafetyTests(unittest.TestCase):
    def test_refuses_to_write_under_hypr_config(self):
        with self.assertRaises(SystemExit):
            hi._check_out(str(hi.HYPR_HOME / 'luna.json'))

    def test_missing_config_returns_error_code(self):
        self.assertEqual(hi.main(['--config', '/nonexistent/hyprland.lua']), 2)


KNOWN_ACTIONS = {'close_window', 'focus', 'focus_window_edge', 'focus_monitor', 'move_focused', 'move_to_monitor',
                 'space', 'resize', 'move_mouse', 'resize_mouse', 'float', 'fullscreen', 'pin', 'center', 'raise',
                 'snap', 'minimize', 'group', 'layout', 'switch_window', 'exec', 'shell', 'mode', 'display_power',
                 'session', 'unbind'}
MODS = {'super', 'shift', 'ctrl', 'alt', 'mod2', 'mod3', 'mod5'}


class RealConfigTests(unittest.TestCase):
    """Smoke test on the user's config. Skipped when it is absent."""

    def test_real_config_imports(self):
        path = hi.DEFAULT_CONFIG
        if not path.is_file():
            self.skipTest('no Hyprland config here')
        cfg, rep = hi.import_config(path)
        self.assertTrue(cfg['keybinds'])
        self.assertEqual(rep['counts']['keybinds'], len(cfg['keybinds']))
        json.dumps(cfg)


if __name__ == '__main__':
    unittest.main()
