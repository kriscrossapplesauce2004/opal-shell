#!/bin/sh
# Install Opal on any Linux desktop:
#   curl -fsSL https://raw.githubusercontent.com/kriscrossapplesauce2004/opal-shell/main/get.sh | sh
#   curl -fsSL …/get.sh | sh -s -- --gui      the same steps in a window
#   curl -fsSL …/get.sh | sh -s -- --check    only show what would happen
# It fetches the Opal source, then the switch assistant checks this computer, asks a few questions, installs what is missing
# (your password is asked once) and adds Opal to the login screen. Your current desktop stays. Undo: opal switch --undo
# OPAL_REF picks a branch or tag; OPAL_SOURCE_DIR picks where the source goes.
set -eu
repo="${OPAL_REPO:-https://github.com/kriscrossapplesauce2004/opal-shell}"
ref="${OPAL_REF:-main}"
dir="${OPAL_SOURCE_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/opal/source}"
say() { printf '  %s\n' "$*"; }
fail() { printf '  %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -ne 0 ] || fail "Run this as your own user, not root. It asks for your password when it needs it."
command -v python3 >/dev/null 2>&1 || fail "Opal's installer needs Python 3. Install python3 with your package manager, then run this again."
command -v bash >/dev/null 2>&1 || fail "Opal's installer needs bash. Install bash, then run this again."

printf '\n  \033[1;35m◆ Opal\033[0m\n\n'
if [ -d "$dir/.git" ] && command -v git >/dev/null 2>&1; then
    say "Updating the Opal source in $dir"
    git -C "$dir" fetch -q --depth 1 origin "$ref" && git -C "$dir" checkout -q FETCH_HEAD
elif command -v git >/dev/null 2>&1; then
    say "Downloading Opal into $dir"
    rm -rf "$dir.tmp"
    git clone -q --depth 1 --branch "$ref" "$repo" "$dir.tmp"
    rm -rf "$dir"; mkdir -p "$(dirname "$dir")"; mv "$dir.tmp" "$dir"
else
    # No git yet: the branch tarball works the same.
    command -v curl >/dev/null 2>&1 || fail "Install git or curl, then run this again."
    say "Downloading Opal into $dir"
    tmp=$(mktemp -d)
    curl -fsSL "$repo/archive/$ref.tar.gz" | tar -xz -C "$tmp"
    rm -rf "$dir"; mkdir -p "$(dirname "$dir")"; mv "$tmp"/* "$dir"; rmdir "$tmp"
fi
# A piped script has no terminal on stdin; the assistant opens /dev/tty for its questions.
exec bash "$dir/tools/switch/opal-switch" "$@"
