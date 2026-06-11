#!/usr/bin/env bash
# Generate a shuffled playlist for mpv-photo-frame.
# Usage: generate-slideshow-playlist.sh [compilation]   (see profiles/, or --list)
# Converts TIFF files to JPEG cache in parallel (skips already-cached).
# Configure via .env in this script's directory — see .env.example.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=slideshow-lib.sh
source "$SCRIPT_DIR/slideshow-lib.sh"
slideshow_init "$SCRIPT_DIR" "$@"

TIFF_CACHE="${SLIDESHOW_TIFF_CACHE:-$HOME/.cache/slideshow-tiff-cache}"
PLAYLIST="$SLIDESHOW_PLAYLIST"

mkdir -p "$(dirname "$PLAYLIST")" "$TIFF_CACHE"

slideshow_parse_sources

# Convert one TIFF to a cached JPEG if not already done or source is newer.
convert_tiff() {
  local src="$1"
  local name
  name=$(basename "${src%.*}")
  local hash
  hash=$(printf '%s' "$src" | md5sum | cut -d' ' -f1)
  local dst="$TIFF_CACHE/$hash.jpg"
  if [[ ! -f "$dst" || "$src" -nt "$dst" ]]; then
    convert "$src" -colorspace sRGB -quality 90 \
      -set comment "$name" \
      "$dst" 2>/dev/null && {
      echo "$name" > "$dst.name"
      echo "$dst"
    }
  else
    echo "$name" > "$dst.name"
    echo "$dst"
  fi
}
export -f convert_tiff
export TIFF_CACHE

echo "Scanning for TIFF files…"
TIFF_COUNT=$(find "${SLIDESHOW_ROOTS[@]}" \
  "${SLIDESHOW_PRUNE[@]}" \
  -type f \( -iname "*.tiff" -o -iname "*.tif" \) -print | wc -l)
echo "Converting $TIFF_COUNT TIFF files (skipping already-cached)…"

TIFF_JPGS=$(find "${SLIDESHOW_ROOTS[@]}" \
  "${SLIDESHOW_PRUNE[@]}" \
  -type f \( -iname "*.tiff" -o -iname "*.tif" \) -print0 \
  | xargs -0 -P "$(nproc)" -I{} bash -c 'convert_tiff "$@"' _ {})

echo "Building playlist…"

NONTIFF_LIST=$(mktemp) || exit 1
trap 'rm -f "$NONTIFF_LIST"' EXIT

find "${SLIDESHOW_ROOTS[@]}" \
  "${SLIDESHOW_PRUNE[@]}" \
  -type f \( \
    -iname "*.jpg"   -o -iname "*.jpeg" \
    -o -iname "*.png"  -o -iname "*.webp" \
    -o -iname "*.gif"  -o -iname "*.bmp"  \
    -o -iname "*.avif" -o -iname "*.heic" \
    -o -iname "*.mp4"  -o -iname "*.mov"  \
    -o -iname "*.avi"  -o -iname "*.mkv"  \
    -o -iname "*.m4v"  -o -iname "*.3gp"  \
  \) -print > "$NONTIFF_LIST"

# shellcheck disable=SC2086  # intentional word-split of the newline-separated TIFF list
{ cat "$NONTIFF_LIST"; printf '%s\n' $TIFF_JPGS; } \
  | shuf > "$PLAYLIST"

echo "Playlist written: $(wc -l < "$PLAYLIST") entries → $PLAYLIST"
