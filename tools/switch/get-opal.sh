#!/bin/sh
# Get Opal on any desktop: fetches the Opal source, then opens the switch assistant.
#   curl -fsSL https://raw.githubusercontent.com/kriscrossapplesauce2004/opal-shell/main/tools/switch/get-opal.sh | sh
#   … | sh -s -- --gui      the window assistant
#   … | sh -s -- --check    only show what would happen
# OPAL_REF picks a branch or tag; OPAL_SOURCE_DIR picks where the source goes.
set -eu
repo="${OPAL_REPO:-https://github.com/kriscrossapplesauce2004/opal-shell}"
ref="${OPAL_REF:-main}"
dir="${OPAL_SOURCE_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/opal/source}"
say() { printf '  %s\n' "$*"; }
need_python() {
    command -v python3 >/dev/null 2>&1 && return 0
    say "Opal's assistant needs Python 3. Install python3 with your package manager, then run this again."
    exit 1
}
need_python
if [ -d "$dir/.git" ] && command -v git >/dev/null 2>&1; then
    say "Updating the Opal source in $dir"
    git -C "$dir" fetch --depth 1 origin "$ref" >/dev/null 2>&1 && git -C "$dir" checkout -q FETCH_HEAD
elif command -v git >/dev/null 2>&1; then
    say "Getting the Opal source into $dir"
    rm -rf "$dir.tmp"
    git clone -q --depth 1 --branch "$ref" "$repo" "$dir.tmp"
    rm -rf "$dir"; mv "$dir.tmp" "$dir"
else
    # No git yet: the release tarball works the same.
    say "Getting the Opal source into $dir"
    tmp=$(mktemp -d)
    curl -fsSL "$repo/archive/$ref.tar.gz" | tar -xz -C "$tmp"
    rm -rf "$dir"; mkdir -p "$(dirname "$dir")"; mv "$tmp"/* "$dir"; rmdir "$tmp"
fi
# A piped script has no terminal on stdin; the assistant reads answers from /dev/tty.
exec bash "$dir/tools/switch/opal-switch" "$@"
