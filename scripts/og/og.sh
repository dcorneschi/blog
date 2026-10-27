#!/usr/bin/env bash
# Render every page bundle's cover.svg to og.png at the SVG's own size (2752x1536) for social
# previews. X, LinkedIn and Facebook ignore SVG in og:image;
# layouts/_partials/_funcs/get-page-images.html picks og.png when it exists.
#
# Usage: scripts/og/og.sh [content/posts/<slug> ...]   (default: every bundle with a cover.svg)
# Needs rsvg-convert (brew install librsvg). Roboto is dropped from the font list so the PNG uses
# Helvetica Neue, the font most visitors see: an SVG shown as <img> cannot load web fonts.
set -euo pipefail
cd "$(dirname "$0")/../.."

dirs=("$@")
if [ ${#dirs[@]} -eq 0 ]; then
  while IFS= read -r f; do dirs+=("$(dirname "$f")"); done < <(find content -name cover.svg | sort)
fi

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
for d in "${dirs[@]}"; do
  sed "s/font-family=\"Roboto, /font-family=\"/" "$d/cover.svg" > "$tmp"
  rsvg-convert -b '#f8f9fa' "$tmp" -o "$d/og.png"
  echo "$d/og.png"
done
