#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
    cat <<'EOF'
Usage: ./install.sh [--restart] [--no-deps] [--no-hyprland] [--no-keyboard]

Install Opal into ~/.config/quickshell/opal and install the `opal` command
into ~/.local/bin. Existing shell files are moved to a timestamped backup
(the newest three are kept); preferences under ~/.local/state/opal are never
touched.

Options:
  --restart      reload the running Opal shell after installation
  --no-deps      do not install missing runtime dependencies
  --no-keyboard  do not build and install the Borealis system keyboard
  --no-hyprland  do not add the reversible Lua hook to Hyprland
  --help         show this help
EOF
}

restart=0
install_deps=1
install_hyprland=1
install_keyboard=1
for arg in "$@"; do
    case "$arg" in
        --restart) restart=1 ;;
        --no-deps) install_deps=0 ;;
        --no-hyprland) install_hyprland=0 ;;
        --no-keyboard) install_keyboard=0 ;;
        --help|-h) usage; exit 0 ;;
        *) echo "Unknown option: $arg" >&2; usage >&2; exit 2 ;;
    esac
done

source_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../src" && pwd)
config_dir="${OPAL_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/opal}"
bin_dir="${OPAL_BIN_DIR:-${XDG_BIN_HOME:-$HOME/.local/bin}}"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/opal"
timestamp=$(date +%Y%m%d-%H%M%S)
backup_root="$state_dir/backups"
backup_dir="$backup_root/install-$timestamp"
config_parent=$(dirname -- "$config_dir")
hypr_config="${OPAL_HYPRLAND_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.lua}"

if [[ ! -f "$source_dir/shell.qml" || ! -f "$source_dir/qmldir" || ! -f "$source_dir/backend.py" ]]; then
    echo "This does not look like an Opal source directory: $source_dir" >&2
    exit 1
fi

install_dependencies() {
    local manager package tool missing_quickshell=0
    local -a missing=() packages=()
    local -A package_for=(
        [quickshell]=quickshell [python3]=python [hyprctl]=hyprland
        [wpctl]=wireplumber [playerctl]=playerctl [nmcli]=networkmanager
        [bluetoothctl]=bluez [brightnessctl]=brightnessctl
        [powerprofilesctl]=power-profiles-daemon [grim]=grim
        [wl-copy]=wl-clipboard [notify-send]=libnotify [cmake]=cmake
    )

    for tool in "${!package_for[@]}"; do
        command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
    done
    ((${#missing[@]})) || return 0

    if command -v pacman >/dev/null 2>&1; then
        manager=pacman
        for tool in "${missing[@]}"; do packages+=("${package_for[$tool]}"); done
    elif command -v dnf >/dev/null 2>&1; then
        manager=dnf
        for tool in "${missing[@]}"; do packages+=("${package_for[$tool]}"); done
    elif command -v apt-get >/dev/null 2>&1; then
        manager=apt
        for tool in "${missing[@]}"; do
            case "$tool" in
                quickshell) missing_quickshell=1 ;;
                python3) packages+=(python3) ;;
                hyprctl) packages+=(hyprland) ;;
                wpctl) packages+=(wireplumber) ;;
                nmcli) packages+=(network-manager) ;;
                notify-send) packages+=(libnotify-bin) ;;
                *) packages+=("${package_for[$tool]}") ;;
            esac
        done
    else
        echo "Missing dependencies: ${missing[*]}" >&2
        echo "No supported package manager found (pacman, dnf, apt-get)." >&2
        return 1
    fi

    if ((${#packages[@]} == 0)); then
        if [[ "$missing_quickshell" -eq 1 ]]; then
            echo "Quickshell is not available from standard apt repositories. Install it from its official package source, then rerun this script." >&2
            return 1
        fi
        return 0
    fi
    echo "Installing missing Opal dependencies: ${packages[*]}"
    case "$manager" in
        pacman) sudo pacman -S --needed --noconfirm "${packages[@]}" ;;
        dnf) sudo dnf install -y "${packages[@]}" ;;
        apt) sudo apt-get update && sudo apt-get install -y "${packages[@]}" ;;
    esac
    if [[ "$missing_quickshell" -eq 1 ]]; then
        echo "Quickshell is not available from standard apt repositories. Install it from its official package source, then rerun this script." >&2
        return 1
    fi
}

install_hyprland_hook() {
    local hook_path temp hook_escaped
    if [[ ! -f "$hypr_config" ]]; then
        echo "Hyprland Lua config not found at $hypr_config; skipped automatic hook." >&2
        echo "Set OPAL_HYPRLAND_CONFIG to your hyprland.lua path and rerun if needed." >&2
        return 0
    fi
    if grep -Fq "$config_dir/hyprland.lua" "$hypr_config"; then
        echo "Hyprland hook is already installed in $hypr_config"
        return 0
    fi

    # Outside the pruned install backups: this is the only pre-Opal copy.
    mkdir -p "$backup_root"
    cp -a -- "$hypr_config" "$backup_root/$(basename -- "$hypr_config").before-opal"
    hook_path="$config_dir/hyprland.lua"
    hook_escaped=${hook_path//\\/\\\\}
    hook_escaped=${hook_escaped//\"/\\\"}
    temp=$(mktemp "${hypr_config}.opal.XXXXXX")
    cp -- "$hypr_config" "$temp"
    {
        printf '\n-- OPAL_INSTALL_HOOK_BEGIN\n'
        printf 'do\n'
        printf '    local marker = io.open((os.getenv("XDG_RUNTIME_DIR") or "/run/user/1000") .. "/opal-active", "r")\n'
        printf '    if marker then\n'
        printf '        marker:close()\n'
        printf '        dofile("%s")\n' "$hook_escaped"
        printf '    end\n'
        printf 'end\n'
        printf '%s\n' '-- OPAL_INSTALL_HOOK_END'
    } >> "$temp"
    mv -- "$temp" "$hypr_config"
    echo "Added reversible Opal hook to $hypr_config"
}

# Adds a Hyprland start hook that runs "opal login"; it starts Opal only when "opal autostart on" was set.
install_autostart_hook() {
    [[ -f "$hypr_config" ]] || return 0
    grep -Fq 'OPAL_AUTOSTART_BEGIN' "$hypr_config" && return 0
    temp=$(mktemp "${hypr_config}.opal.XXXXXX")
    cp -- "$hypr_config" "$temp"
    {
        printf '\n-- OPAL_AUTOSTART_BEGIN\n'
        printf 'hl.on("hyprland.start", function()\n'
        printf '    hl.exec_cmd("%s/opal login")\n' "$bin_dir"
        printf 'end)\n'
        printf '%s\n' '-- OPAL_AUTOSTART_END'
    } >> "$temp"
    mv -- "$temp" "$hypr_config"
    echo "Added Opal autostart hook to $hypr_config (enable with: opal autostart on)"
}

if [[ "$install_deps" -eq 1 ]]; then
    install_dependencies
fi

mkdir -p "$config_parent" "$bin_dir" "$state_dir"
tmp_dir=$(mktemp -d "$config_parent/.opal-install.XXXXXX")
old_dir=""
cleanup() {
    rm -rf -- "$tmp_dir"
}
trap cleanup EXIT

# Copy only the source package. Git metadata, tests, bytecode, and local
# recovery directories never become part of the live shell installation.
while IFS= read -r -d '' file; do
    install -m 0644 "$file" "$tmp_dir/$(basename -- "$file")"
done < <(find "$source_dir" -maxdepth 1 -type f ! -name '*.pyc' -print0)

if [[ -e "$config_dir" ]]; then
    mkdir -p "$backup_dir"
    mv -- "$config_dir" "$backup_dir/opal"
    old_dir="$backup_dir/opal"
fi

if ! mv -- "$tmp_dir" "$config_dir"; then
    if [[ -n "$old_dir" && ! -e "$config_dir" ]]; then
        mv -- "$old_dir" "$config_dir"
    fi
    echo "Could not activate the new Opal installation; the previous copy was restored." >&2
    exit 1
fi

# Keep the three newest install backups; older shells are in git history.
if [[ -d "$backup_root" ]]; then
    find "$backup_root" -mindepth 1 -maxdepth 1 -type d -name 'install-*' |
        sort -r | tail -n +4 | xargs -r rm -rf --
fi

wrapper_tmp=$(mktemp "$bin_dir/.opal.XXXXXX")
cat > "$wrapper_tmp" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

config="${OPAL_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/opal}"
marker="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/opal-active"
# Persistent flag: when it exists, "opal login" starts Opal at Hyprland start.
autostart_flag="${XDG_STATE_HOME:-$HOME/.local/state}/opal/autostart"

systemd_user() {
    command -v systemctl >/dev/null 2>&1 && systemctl --user "$@"
}
# Reload the Hyprland config, except in safe mode: there a reload replaces the user's config with the recovery config.
hypr_reload() {
    command -v hyprctl >/dev/null 2>&1 && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] || return 0
    if [[ -e "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr/$HYPRLAND_INSTANCE_SIGNATURE/recoverycfg.lua" ]]; then
        echo 'Hyprland is in safe mode: the Hyprland config was not reloaded. Log out and in to load it.'
        return 0
    fi
    hyprctl reload config-only || true
}
# Quickshell logs live in /run and are lost at reboot. Keep the last ten shell logs before each stop, for bugs that only show after long uptime.
save_log() {
    local dir="${XDG_STATE_HOME:-$HOME/.local/state}/opal/logs"
    mkdir -p "$dir"
    quickshell log -p "$config" > "$dir/opal-$(date +%Y%m%d-%H%M%S).log" 2>/dev/null || true
    ls -1t "$dir"/opal-*.log 2>/dev/null | tail -n +11 | xargs -r rm -f --
}

case "${1:-on}" in
    on)
        # Opal brings its own polkit agent; only one agent can register per session.
        if systemd_user is-enabled --quiet opal-polkit.service; then
            systemd_user start opal-polkit.service
        else
            systemd_user stop hyprpolkitagent.service || true
        fi
        # Stop DMS before Opal starts so two shells never show at the same time.
        systemd_user mask --runtime --now dms.service || true
        # Use the desktop icon theme, so folders and file types get real icons and not only app icons.
        if [[ -z "${QS_ICON_THEME:-}" ]]; then
            QS_ICON_THEME=$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'") || true
            [[ -n "$QS_ICON_THEME" ]] || QS_ICON_THEME=$(sed -n 's/^icon_theme=//p' "${XDG_CONFIG_HOME:-$HOME/.config}/qt6ct/qt6ct.conf" 2>/dev/null | head -1)
            [[ -n "$QS_ICON_THEME" ]] && export QS_ICON_THEME
        fi
        quickshell -d -n -p "$config"
        touch "$marker"
        hypr_reload
        echo 'Opal is on. Return to DMS with: opal off'
        ;;
    reload)
        save_log
        quickshell kill -p "$config" || true
        # Quickshell releases a detached instance asynchronously. Starting in
        # the same instant can be rejected as an already-running config.
        sleep 1
        exec "$0" on
        ;;
    off)
        rm -f -- "$marker"
        save_log
        quickshell kill -p "$config" || true
        systemd_user unmask --runtime dms.service || true
        systemd_user start dms.service || true
        if ! systemd_user is-enabled --quiet opal-polkit.service; then
            systemd_user start hyprpolkitagent.service || true
        fi
        hypr_reload
        ;;
    login)
        # Called by the Hyprland start hook; does nothing unless autostart is on.
        [[ -e "$autostart_flag" ]] && exec "$0" on
        exit 0
        ;;
    autostart)
        case "${2:-status}" in
            on) mkdir -p "$(dirname -- "$autostart_flag")"; touch "$autostart_flag"; echo 'Opal starts at login.' ;;
            off) rm -f -- "$autostart_flag"; echo 'Opal no longer starts at login; DMS starts instead.' ;;
            *) [[ -e "$autostart_flag" ]] && echo on || echo off ;;
        esac
        ;;
    console|gaming)
        exec quickshell ipc -p "$config" call opal gaming
        ;;
    greeter)
        exec sudo "@OPAL_TOOLS@/install-greeter.sh" "${@:2}"
        ;;
    polkit)
        exec bash "@OPAL_TOOLS@/install-polkit.sh"
        ;;
    quickaccess|qa)
        exec quickshell ipc -p "$config" call opal quickaccess
        ;;
    activity)
        shift
        exec python3 "$config/opal_activity.py" "$@"
        ;;
    launcher|controls|notifications|clipboard|phone|desktop|appearance|close|inspect|lock)
        exec quickshell ipc -p "$config" call opal "$1"
        ;;
    *)
        echo 'Usage: opal [on|reload|off|autostart [on|off]|activity …|lock|greeter [--revert]|polkit|launcher|controls|notifications|clipboard|phone|console|gaming|quickaccess|desktop|appearance|close|inspect]' >&2
        exit 2
        ;;
esac
EOF
# Register the Opal MCP server with Claude Code, so "claude" can drive the shell.
if command -v claude >/dev/null 2>&1 && ! claude mcp get opal >/dev/null 2>&1; then
    claude mcp add --scope user opal -- python3 "$config_dir/opal_mcp.py" >/dev/null 2>&1 &&
        echo "Registered the Opal MCP server with Claude Code (remove with: claude mcp remove opal)" || true
fi

# The greeter command runs the installer from this checkout.
tools_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
sed -i "s|@OPAL_TOOLS@|$tools_dir|" "$wrapper_tmp"
chmod 0755 "$wrapper_tmp"
mv -- "$wrapper_tmp" "$bin_dir/opal"

# Opal's drag-snap plugin. Rebuilt here so it always matches the installed Hyprland.
install_windowing_plugin() {
    local plugin_source plugin_dir
    plugin_source=$(CDPATH= cd -- "$source_dir/../plugins/opal-windowing" 2>/dev/null && pwd) || { echo "Windowing plugin source not found; drag snapping stays off." >&2; return 0; }
    plugin_dir="${OPAL_PLUGIN_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/opal/plugins}"
    mkdir -p "$plugin_dir"
    if make -s -C "$plugin_source" >"$state_dir/plugin-build.log" 2>&1 && [[ -f "$plugin_source/opal-windowing.so" ]]; then
        install -m 0644 "$plugin_source/opal-windowing.so" "$plugin_dir/opal-windowing.so.tmp"
        mv -- "$plugin_dir/opal-windowing.so.tmp" "$plugin_dir/opal-windowing.so"
        echo "Installed windowing plugin to $plugin_dir/opal-windowing.so"
    else
        echo "Windowing plugin build failed; see $state_dir/plugin-build.log. Drag snapping stays off." >&2
    fi
}

# Borealis is Opal's system keyboard. Build it from the checkout and install it next to the opal command.
install_borealis() {
    local keyboard_source build_dir
    keyboard_source=$(CDPATH= cd -- "$source_dir/../keyboard" 2>/dev/null && pwd) || { echo "Borealis source not found; the system keyboard is not installed." >&2; return 0; }
    if ! command -v cmake >/dev/null 2>&1; then
        echo "cmake is missing; Borealis is not built. Opal falls back to Squeekboard or its shell keyboard." >&2
        return 0
    fi
    build_dir="$state_dir/keyboard-build"
    echo "Building the Borealis keyboard..."
    if cmake -S "$keyboard_source" -B "$build_dir" -DCMAKE_BUILD_TYPE=Release >"$build_dir.log" 2>&1 &&
       cmake --build "$build_dir" -j"$(nproc 2>/dev/null || echo 4)" --target opal-keyboard opal-pointer >>"$build_dir.log" 2>&1; then
        install -m 0755 "$build_dir/opal-keyboard" "$bin_dir/opal-keyboard.tmp"
        mv -- "$bin_dir/opal-keyboard.tmp" "$bin_dir/opal-keyboard"
        # Trackpad helper for docked phones.
        install -m 0755 "$build_dir/opal-pointer" "$bin_dir/opal-pointer.tmp"
        mv -- "$bin_dir/opal-pointer.tmp" "$bin_dir/opal-pointer"
        echo "Installed Borealis keyboard to $bin_dir/opal-keyboard"
    else
        echo "Borealis build failed; see $build_dir.log. The previous keyboard, if any, is kept." >&2
    fi
}

if [[ "$install_keyboard" -eq 1 ]]; then
    install_borealis
fi

if [[ "$install_hyprland" -eq 1 ]]; then
    install_windowing_plugin
    install_hyprland_hook
    install_autostart_hook
fi

if [[ "$restart" -eq 1 ]]; then
    "$bin_dir/opal" reload
fi

echo "Installed Opal to $config_dir"
echo "Installed command to $bin_dir/opal"
[[ -n "$old_dir" ]] && echo "Previous shell backed up at $old_dir"
echo "Run '$bin_dir/opal on' to start it, or '$bin_dir/opal reload' to reload it."
