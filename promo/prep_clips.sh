#!/usr/bin/env bash
# Edit proxies for Remotion: H.264 with a keyframe every half second, capped at 2560 px wide, plus the soundtrack.
set -euo pipefail
src=$HOME/.local/state/opal/artifacts/promo
out=$(dirname "$0")/video/public
mkdir -p "$out/clips"
cp "$src/soundtrack.wav" "$out/soundtrack.wav"
for f in "$src"/clips/[dptg][0-9][0-9]-*.mkv; do
    name=$(basename "${f%.mkv}")
    dst=$out/clips/$name.mp4
    [[ $dst -nt $f ]] && continue
    ffmpeg -v error -y -i "$f" -vf "scale='min(2560,iw)':-2:flags=lanczos,format=yuv420p" -c:v libx264 -preset medium -crf 15 -g 30 -an "$dst"
    echo "$name"
done
