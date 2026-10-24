-- Loaded only while the runtime Opal marker exists. No DMS files are edited.
-- A nested test session points these at its own state folder, shell and plugin builds.
local OPAL_STATE = os.getenv("OPAL_STATE_DIR") or (os.getenv("HOME") .. "/.local/state/opal")
-- Compositor styling follows the shell layout mode, tuned per mode instead of
-- one generic desktop profile. Re-read on every Hyprland config reload; the
-- shell triggers one whenever the mode changes (see Hub.mode).
local function opal_mode()
    local f = io.open(OPAL_STATE .. "/preferences.json", "r")
    if not f then return "desktop" end
    local body = f:read("*a"); f:close()
    return body:match('"mode"%s*:%s*"([a-z]+)"') or "desktop"
end
-- The Look switch "Compositor blur" turns blur off for Opal's own layers. Window blur stays as the user set it.
local function opal_blur()
    local f = io.open(OPAL_STATE .. "/preferences.json", "r")
    if not f then return true end
    local body = f:read("*a"); f:close()
    return body:match('"lookBlur"%s*:%s*false') == nil
end
local OPAL_BLUR = opal_blur()
local profiles = {
    desktop = { gaps_in = 5, gaps_out = 8, border = 1, rounding = 16 },
    console = { gaps_in = 2, gaps_out = 4, border = 1, rounding = 6 },
    -- Phone geometry is output-scoped below. Never square every monitor.
    phone = { gaps_in = 5, gaps_out = 8, border = 1, rounding = 16 },
}
local p = profiles[opal_mode()] or profiles.desktop
-- Console mode gives the compositor the game-session roles: apps open fullscreen on the Play workspace,
-- and the empty Home workspace shows the console home under them. Leaving console mode brings the apps back (hypr_actions.console_release).
if opal_mode() == "console" then
    pcall(hl.window_rule, { name = "opal-console-play", match = { class = ".*" }, workspace = "name:Play", fullscreen = true })
end
hl.config({
    general = { gaps_in = p.gaps_in, gaps_out = p.gaps_out, border_size = p.border,
        col = { active_border = "rgba(cbb5edee)", inactive_border = "rgba(55536655)" } },
    decoration = { rounding = p.rounding, blur = { enabled = true, size = 6, passes = 2 },
        shadow = { enabled = true, range = 35, render_power = 3, color = "rgba(080b1880)" } }
})
-- The pointer stays where the user left it: focus and workspace changes never move it.
pcall(hl.config, { cursor = { no_warps = true } })
-- Touchscreens swipe workspaces natively. Phone mode uses the shell gesture layer instead. The 3-finger touchpad swipe lives in the user config.
if opal_mode() ~= "phone" then
    pcall(hl.config, { gestures = { workspace_swipe_touch = true } })
end
-- Written atomically by Opal after resolving each output's actual layout.
-- Workspace monitor selectors follow workspaces moved between outputs.
local runtime = os.getenv("XDG_RUNTIME_DIR")
local phone_displays = runtime and io.open(runtime .. "/opal-phone-displays", "r")
if phone_displays then
    for name in phone_displays:lines() do
        if not name:match("^mode=") and name:match("^[%w_.:%-]+$") then
            hl.workspace_rule({ workspace = "m[" .. name .. "]", no_rounding = true })
        end
    end
    phone_displays:close()
end
hl.layer_rule({ match = { namespace = "^opal-(bar|shelf|overlay|toast|volume-osd)$" }, blur = OPAL_BLUR, ignore_alpha = 0.1, no_anim = true })
-- New shade/audio cards blur only their own small surfaces; click-away layers
-- are transparent input surfaces, never fullscreen blur regions.
hl.layer_rule({ match = { namespace = "^opal-(audio|shade)$" }, blur = OPAL_BLUR, ignore_alpha = 0.1, no_anim = true })
-- The taskbar menu is a full-screen input host with one painted card.
-- ignore_alpha keeps blur confined to that translucent card.
hl.layer_rule({ match = { namespace = "^opal-taskbar-menu$" }, blur = OPAL_BLUR, ignore_alpha = 0.1, no_anim = true })
hl.layer_rule({ match = { namespace = "^opal-assistant$" }, blur = OPAL_BLUR, ignore_alpha = 0.1, no_anim = true })
hl.layer_rule({ match = { namespace = "^opal-power-profile$" }, blur = OPAL_BLUR, ignore_alpha = 0.1, no_anim = true })
hl.layer_rule({ match = { namespace = "^opal-power-menu$" }, no_anim = true })
-- Newer card surfaces animate themselves and blur only their painted cards.
hl.layer_rule({ match = { namespace = "^opal-(convergence-toast|quick-access|tablet-dock|phone-dock|polkit|assistant|activity|snap|snap-assist)$" }, blur = OPAL_BLUR, ignore_alpha = 0.1, no_anim = true })
-- Gesture, edge and split layers are input surfaces: no blur and no compositor animation.
hl.layer_rule({ match = { namespace = "^opal-(gesture|edge|split)$" }, blur = false, no_anim = true })
-- The snap preview stays unblurred: the dragged window under it must stay readable.
hl.layer_rule({ match = { namespace = "^opal-snap-preview$" }, blur = false, no_anim = true })
hl.layer_rule({ match = { namespace = "^opal-(audio|shade|activity)-dismiss$" }, blur = false, no_anim = true })
local function bind(key, command)
    hl.unbind(key)
    hl.bind(key, hl.dsp.exec_cmd(command))
end
local qs = "quickshell ipc -p " .. (os.getenv("OPAL_SHELL_PATH") or (os.getenv("HOME") .. "/.config/quickshell/opal")) .. " call opal "
bind("SUPER + space", qs .. "launcher")
-- A lone Super tap toggles Start. Release binds are skipped when another key was pressed with Super.
hl.unbind("SUPER + Super_L")
hl.bind("SUPER + Super_L", hl.dsp.exec_cmd(qs .. "launcher"), { release = true })
bind("ALT + space", qs .. "launcher")
-- App switcher. Hold Alt and tap Tab to walk windows in recent order; releasing Alt switches.
-- Every call names the hold and the step, so a late IPC call can never reopen a switch that already ended.
local switch_hold, switch_step = 0, 0
local function switch_send(verb) hl.exec_cmd(qs .. verb .. " " .. switch_hold .. " " .. switch_step) end
local function switch_begin(step)
    switch_hold = switch_hold + 1; switch_step = step
    hl.dispatch(hl.dsp.submap("opal-switch"))
    switch_send("switcherStep")
end
local function switch_finish(verb)
    hl.dispatch(hl.dsp.submap("reset"))
    switch_send(verb)
end
hl.unbind("ALT + Tab")
hl.bind("ALT + Tab", function() switch_begin(1) end)
hl.unbind("ALT + SHIFT + Tab")
hl.bind("ALT + SHIFT + Tab", function() switch_begin(-1) end)
pcall(hl.define_submap, "opal-switch", function()
    hl.bind("ALT + Tab", function() switch_step = switch_step + 1; switch_send("switcherStep") end)
    hl.bind("ALT + SHIFT + Tab", function() switch_step = switch_step - 1; switch_send("switcherStep") end)
    hl.bind("ALT + right", function() switch_step = switch_step + 1; switch_send("switcherStep") end)
    hl.bind("ALT + left", function() switch_step = switch_step - 1; switch_send("switcherStep") end)
    hl.bind("ALT + Q", function() switch_send("switcherCloseWindow") end)
    hl.bind("ALT + Alt_L", function() switch_finish("switcherCommit") end, { release = true })
    hl.bind("ALT + Alt_R", function() switch_finish("switcherCommit") end, { release = true })
    hl.bind("ALT + Return", function() switch_finish("switcherCommit") end)
    hl.bind("ALT + Escape", function() switch_finish("switcherCancel") end)
    hl.bind("Escape", function() switch_finish("switcherCancel") end)
end)
-- Super+Tab opens the same switcher and keeps it open without holding a key.
bind("SUPER + Tab", qs .. "switcherOpen")
bind("SUPER + comma", qs .. "controls")
bind("SUPER + N", qs .. "notifications")
bind("SUPER + CTRL + P", qs .. "phone")
bind("SUPER + CTRL + G", qs .. "gaming")
bind("SUPER + CTRL + Q", qs .. "quickaccess")
bind("SUPER + CTRL + D", qs .. "desktop")
-- Rishot owns Print; Opal Capture Studio remains on Super+Shift+S.
bind("Print", "/home/melissa/.local/bin/rishot")
bind("SUPER + SHIFT + S", qs .. "capture")
bind("SHIFT + Print", qs .. "screenshot")
bind("SUPER + SHIFT + R", qs .. "record")
bind("SUPER + X", qs .. "controls")
bind("SUPER + V", qs .. "clipboard")
bind("SUPER + A", qs .. "assistant")
-- Copilot keys send XF86Assistant or Super+Shift+F23.
bind("XF86Assistant", qs .. "assistant")
bind("SUPER + SHIFT + F23", qs .. "assistant")
bind("SUPER + M", "kitty -e btop")
bind("SUPER + ALT + L", qs .. "lock")
bind("SUPER + L", qs .. "lock")
bind("XF86AudioRaiseVolume", "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 3%+")
-- Power key menu. Press and release both reach Opal, so it tells taps, double presses and holds apart; they work on the lock screen too.
-- The backend decides per device whether Opal owns the key. Where it does not, logind keeps it and Opal ignores these edges.
local power_held = false
hl.unbind("XF86PowerOff")
hl.bind("XF86PowerOff", function() power_held = true; hl.exec_cmd(qs .. "powerKey down") end, { locked = true })
hl.bind("XF86PowerOff", function() power_held = false; hl.exec_cmd(qs .. "powerKey up") end, { locked = true, release = true })
-- Power plus volume down is a chord while power is held.
hl.unbind("XF86AudioLowerVolume")
hl.bind("XF86AudioLowerVolume", function()
    if power_held then hl.exec_cmd(qs .. "powerChord") else hl.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 3%-") end
end)
-- Desktops keep their power key; Super+Escape opens the same menu.
bind("SUPER + Escape", qs .. "powerMenu")
-- While the menu is open this empty submap is active, so the volume and power keys reach the menu surface. Super+Escape always gets out.
pcall(hl.define_submap, "opal-power", function()
    hl.bind("SUPER + Escape", function() hl.dispatch(hl.dsp.submap("reset")); hl.exec_cmd(qs .. "powerMenuClose") end, { locked = true })
end)
bind("XF86AudioMute", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
bind("XF86AudioMicMute", "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle")
bind("XF86AudioPlay", "playerctl play-pause")
bind("XF86AudioPause", "playerctl play-pause")
bind("XF86AudioNext", "playerctl next")
bind("XF86AudioPrev", "playerctl previous")
bind("XF86MonBrightnessUp", "brightnessctl set +5%")
bind("XF86MonBrightnessDown", "brightnessctl set 5%-")
-- Display settings saved from Opal.
pcall(dofile, os.getenv("HOME") .. "/.config/hypr/opal-monitors.lua")

-- Floating window mode (opt-in). It reads the preference like opal_mode(); turning it off removes the rule, and the shell tiles the windows again.
local function opal_floating()
    local f = io.open(OPAL_STATE .. "/preferences.json", "r")
    if not f then return false end
    local body = f:read("*a"); f:close()
    return body:match('"floatingMode"%s*:%s*true') ~= nil
end
local function file_exists(path)
    local f = io.open(path, "r")
    if f then f:close(); return true end
    return false
end
local state_dir = OPAL_STATE
local function first_existing(paths)
    for _, path in ipairs(paths) do
        if file_exists(path) then return path end
    end
    return nil
end
local plugin_dir = os.getenv("OPAL_PLUGIN_DIR") or (os.getenv("HOME") .. "/.local/share/opal/plugins/")
local titlebar_plugin = first_existing({ plugin_dir .. "hyprbars.so", os.getenv("HOME") .. "/.local/share/vibeshell/plugins/hyprbars.so" })
-- opal-windowing reports window drags for snap zones and gives a snapped window its size back when it is dragged away.
local windowing_plugin = first_existing({ plugin_dir .. "opal-windowing.so" })
-- Hyprland loads the plugins that the config declares on each pass and unloads the ones it no longer declares, then reloads.
-- Declare both plugins on every pass in both modes: a skipped declaration unloads the plugin (reload loop, then a crash), and unloading hyprbars while bars are shown aborts Hyprland.
if titlebar_plugin then pcall(hl.plugin.load, titlebar_plugin) end
if windowing_plugin then pcall(hl.plugin.load, windowing_plugin) end
local bars = hl.plugin and hl.plugin.hyprbars
local windowing = hl.plugin and hl.plugin.opal_windowing
if opal_floating() then
    hl.window_rule({ name = "opal-float-all", match = { class = ".*" }, float = true })
    -- Windows snap to each other and to the screen edges; any border resizes the window.
    pcall(hl.config, { general = { snap = { enabled = true, window_gap = 12, monitor_gap = 12, respect_gaps = true },
        resize_on_border = true, extend_border_grab_area = 12, hover_icon_on_border = true } })
    if windowing then pcall(hl.config, { plugin = { opal_windowing = { snap_zones = true } } }) end
    bind("SUPER + H", qs .. "minimize")
    bind("SUPER + D", qs .. "showDesktop")
    -- Super+Alt+arrows: left and right cycle the side's widths, up and down split into quarters, maximize, restore and minimize.
    bind("SUPER + ALT + left", qs .. "keySnap left")
    bind("SUPER + ALT + right", qs .. "keySnap right")
    bind("SUPER + ALT + up", qs .. "keySnap up")
    bind("SUPER + ALT + down", qs .. "keySnap down")
    -- Titlebars: hyprbars in Opal colours. The bar options reapply on every pass.
    -- The vendored hyprbars keeps its buttons across reloads, so seed them once per session.
    if bars then
        local ok, c = pcall(dofile, state_dir .. "/hypr-titlebars.lua")
        if not ok or type(c) ~= "table" then c = { bar = "rgba(271d1df2)", text = "rgb(f0dedd)", close = "rgb(ffb4ab)", button = "rgb(4a3f3e)", ink = "rgb(1b1112)", font = "Google Sans Flex" } end
        pcall(hl.config, { plugin = { hyprbars = {
            enabled = true, bar_height = 36, bar_color = c.bar, ["col.text"] = c.text, bar_title_enabled = true,
            bar_text_font = c.font, bar_text_size = 11, bar_text_weight = "semibold", bar_text_align = "left", bar_padding = 14,
            bar_button_padding = 10, bar_part_of_window = true, bar_precedence_over_border = true, bar_blur = false,
            icon_on_hover = true, inactive_button_color = c.button,
            on_double_click = qs .. "maximize",
        } } })
        -- Buttons are laid out right to left: close, maximize, minimize, snap layouts.
        if not _G.opal_hyprbars_seeded then
            pcall(bars.add_button, { bg_color = c.close, fg_color = c.ink, size = 15, icon = "×", action = [[hyprctl eval 'hl.dispatch(hl.dsp.window.close())']] })
            pcall(bars.add_button, { bg_color = c.button, fg_color = c.text, size = 15, icon = "□", action = qs .. "maximize" })
            pcall(bars.add_button, { bg_color = c.button, fg_color = c.text, size = 15, icon = "–", action = qs .. "minimize" })
            pcall(bars.add_button, { bg_color = c.button, fg_color = c.text, size = 15, icon = "⊞", action = qs .. "snaplayouts" })
            _G.opal_hyprbars_seeded = true
        end
    end
else
    -- Tiling mode keeps both plugins loaded with their parts switched off.
    if bars then pcall(hl.config, { plugin = { hyprbars = { enabled = false } } }) end
    if windowing then pcall(hl.config, { plugin = { opal_windowing = { snap_zones = false } } }) end
end
bind("SUPER + Z", qs .. "snaplayouts")
