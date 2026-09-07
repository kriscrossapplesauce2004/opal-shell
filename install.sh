#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
    cat <<'EOF'
Usage: ./install.sh [--restart]

Install Opal into ~/.config/quickshell/opal and install the `opal` command
into ~/.local/bin. Existing shell files are moved to a timestamped backup;
preferences under ~/.local/state/opal are never touched.

Options:
  --restart  reload the running Opal shell after installation
  --help     show this help
EOF
}

restart=0
for arg in "$@"; do
    case "$arg" in
        --restart) restart=1 ;;
        --help|-h) usage; exit 0 ;;
        *) echo "Unknown option: $arg" >&2; usage >&2; exit 2 ;;
    esac
done

source_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
config_dir="${OPAL_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/opal}"
bin_dir="${OPAL_BIN_DIR:-${XDG_BIN_HOME:-$HOME/.local/bin}}"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/opal"
timestamp=$(date +%Y%m%d-%H%M%S)
backup_dir="$state_dir/pre-deploy-$timestamp-install"
config_parent=$(dirname -- "$config_dir")

if [[ ! -f "$source_dir/shell.qml" || ! -f "$source_dir/qmldir" || ! -f "$source_dir/backend.py" ]]; then
    echo "This does not look like an Opal source directory: $source_dir" >&2
    exit 1
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

wrapper_tmp=$(mktemp "$bin_dir/.opal.XXXXXX")
cat > "$wrapper_tmp" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

config="${OPAL_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/opal}"
marker="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/opal-active"

systemd_user() {
    command -v systemctl >/dev/null 2>&1 && systemctl --user "$@"
}

case "${1:-on}" in
    on)
        quickshell -d -n -p "$config"
        systemd_user mask --runtime --now dms.service || true
        touch "$marker"
        command -v hyprctl >/dev/null 2>&1 && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && hyprctl reload config-only || true
        echo 'Opal is on. Return to DMS with: opal off'
        ;;
    reload)
        quickshell kill -p "$config" || true
        exec "$0" on
        ;;
    off)
        rm -f -- "$marker"
        quickshell kill -p "$config" || true
        systemd_user unmask --runtime dms.service || true
        systemd_user start dms.service || true
        command -v hyprctl >/dev/null 2>&1 && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && hyprctl reload config-only || true
        ;;
    console|launcher|controls|notifications|clipboard|phone|desktop|appearance|close|inspect)
        exec quickshell ipc -p "$config" call opal "$1"
        ;;
    *)
        echo 'Usage: opal [on|reload|off|launcher|controls|notifications|clipboard|phone|console|desktop|appearance|close|inspect]' >&2
        exit 2
        ;;
esac
EOF
chmod 0755 "$wrapper_tmp"
mv -- "$wrapper_tmp" "$bin_dir/opal"

if [[ "$restart" -eq 1 ]]; then
    "$bin_dir/opal" reload
fi

echo "Installed Opal to $config_dir"
echo "Installed command to $bin_dir/opal"
[[ -n "$old_dir" ]] && echo "Previous shell backed up at $old_dir"
echo "Run '$bin_dir/opal on' to start it, or '$bin_dir/opal reload' to reload it."
