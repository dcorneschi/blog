#!/usr/bin/env bash
# Typeset a blog post as an A4 PDF: Markdown -> HTML (pandoc) -> PDF (WeasyPrint).
#
# Usage:  scripts/pdf/pdf.sh <post folder> [output.pdf]
#   e.g.  scripts/pdf/pdf.sh content/posts/terraform-lock-file-checksums
#         scripts/pdf/pdf.sh content/cheatsheet/tmux ~/Desktop/tmux.pdf
#
# Default output: ~/Downloads/Claude/<slug>.pdf (override with PDF_DIR=/some/dir).
# Needs pandoc and weasyprint (brew install pandoc weasyprint) and internet for the Google Fonts.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../.." && pwd)"

if [ $# -lt 1 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  sed -n '4,8s/^# \{0,1\}//p' "$0"
  exit 1
fi
post="$(cd "$1" && pwd)"
[ -f "$post/index.md" ] || { echo "No index.md in $post (expected a page bundle)" >&2; exit 1; }

slug="$(basename "$post")"
section="$(basename "$(dirname "$post")")"
out="${2:-${PDF_DIR:-$HOME/Downloads/Claude}/$slug.pdf}"
mkdir -p "$(dirname "$out")"

# Site settings from hugo.toml
base_url="$(sed -n 's/^baseURL = "\(.*\)"/\1/p' "$repo/hugo.toml")"
author="$(sed -n '/\[params.author\]/,/^$/s/^ *name = "\(.*\)"/\1/p' "$repo/hugo.toml" | head -n 1)"
url="${base_url%/}/$section/$slug/"

# Cover: same choice as the theme (*feature* first, then *cover* / *thumbnail*)
cover="$(find "$post" -maxdepth 1 -type f \( -iname '*feature*' \) | sort | head -n 1)"
[ -n "$cover" ] || cover="$(find "$post" -maxdepth 1 -type f \( -iname '*cover*' -o -iname '*thumbnail*' \) | sort | head -n 1)"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# lists_without_preceding_blankline: Hugo (goldmark) allows a list right after a paragraph, pandoc doesn't by default
pandoc "$post/index.md" \
  -f markdown+lists_without_preceding_blankline -t html5 -s \
  --template="$here/template.html" \
  --toc --toc-depth=2 --syntax-highlighting=tango \
  --resource-path="$post" \
  -M author="$author" -M url="$url" -M css="$here/print.css" \
  ${cover:+-M cover="$cover"} \
  -o "$work/article.html"

# Fontconfig prints harmless warnings about the web fonts
weasyprint -q -u "$post/" "$work/article.html" "$out" 2> >(grep -v -i fontconfig >&2)

echo "$out"
