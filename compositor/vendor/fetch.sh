#!/usr/bin/env bash
# Fetch the waylib fork and its protocol packages at the pinned commits, then apply our patches on a `luna` branch.
# The checkouts stay out of the monorepo; the pins are here and in FORK.md, our patches are in patches/.
# Usage: vendor/fetch.sh   (skips a checkout that already exists)
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

fetch() {
    local dir="$1" url="$2" commit="$3"
    if [[ -d "$HERE/$dir/.git" ]]; then echo "$dir: present, skipped"; return; fi
    git clone --quiet "$url" "$HERE/$dir"
    git -C "$HERE/$dir" checkout --quiet "$commit"
    echo "$dir: $commit"
}

fetch treeland https://github.com/linuxdeepin/treeland f342a5b6debd028ed9bc4bc3e806118efbcae8f2
fetch treeland-protocols https://github.com/linuxdeepin/treeland-protocols f6203a9db4cce16226a8bad46f645db0539c9a7d
fetch wlr-protocols https://gitlab.freedesktop.org/wlroots/wlr-protocols.git a741f0ac5d655338a5100fc34bc8cec87d237346

# Our patches go on a `luna` branch at the upstream tag, one commit each.
if ! git -C "$HERE/treeland" rev-parse --verify --quiet luna >/dev/null; then
    git -C "$HERE/treeland" checkout --quiet -b luna f342a5b6debd028ed9bc4bc3e806118efbcae8f2
    git -C "$HERE/treeland" am --quiet "$HERE"/patches/treeland/*.patch
    echo "treeland: branch luna at $(git -C "$HERE/treeland" rev-parse --short HEAD)"
fi
