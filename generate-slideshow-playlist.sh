#!/usr/bin/env bash
# Generate a shuffled playlist for mpv-photo-frame.
# Converts TIFF files to JPEG cache in parallel (skips already-cached).
# Configure via .env in this script's directory — see .env.example.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "$SCRIPT_DIR/.env" ]] && source "$SCRIPT_DIR/.env"

: "${SLIDESHOW_BASE:?'SLIDESHOW_BASE is not set. Copy .env.example to .env and edit it.'}"
TIFF_CACHE="${SLIDESHOW_TIFF_CACHE:-$HOME/.cache/slideshow-tiff-cache}"
PLAYLIST="${SLIDESHOW_PLAYLIST:-$HOME/.cache/slideshow-playlist.m3u}"

mkdir -p "$(dirname "$PLAYLIST")" "$TIFF_CACHE"

# Build find -prune args from SLIDESHOW_EXCLUDE (comma-separated folder names).
_prune=()
if [[ -n "${SLIDESHOW_EXCLUDE:-}" ]]; then
  _prune+=('(')
  _first=true
  while IFS= read -r _d; do
    _d="${_d#"${_d%%[![:space:]]*}"}"; _d="${_d%"${_d##*[![:space:]]}"}"
    [[ -z "$_d" ]] && continue
    "$_first" || _prune+=('-o')
    _prune+=('-path' "$SLIDESHOW_BASE/$_d")
    _first=false
  done < <(tr ',' '\n' <<< "$SLIDESHOW_EXCLUDE")
  _prune+=(')' '-prune' '-o')
fi

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
TIFF_COUNT=$(find "$SLIDESHOW_BASE" \
  "${_prune[@]}" \
  -type f \( -iname "*.tiff" -o -iname "*.tif" \) -print | wc -l)
echo "Converting $TIFF_COUNT TIFF files (skipping already-cached)…"

TIFF_JPGS=$(find "$SLIDESHOW_BASE" \
  "${_prune[@]}" \
  -type f \( -iname "*.tiff" -o -iname "*.tif" \) -print0 \
  | xargs -0 -P "$(nproc)" -I{} bash -c 'convert_tiff "$@"' _ {})

echo "Building playlist…"

find "$SLIDESHOW_BASE" \
  "${_prune[@]}" \
  -type f \( \
    -iname "*.jpg"   -o -iname "*.jpeg" \
    -o -iname "*.png"  -o -iname "*.webp" \
    -o -iname "*.gif"  -o -iname "*.bmp"  \
    -o -iname "*.avif" -o -iname "*.heic" \
    -o -iname "*.mp4"  -o -iname "*.mov"  \
    -o -iname "*.avi"  -o -iname "*.mkv"  \
    -o -iname "*.m4v"  -o -iname "*.3gp"  \
  \) -print > /tmp/slideshow-nontiff.txt

{ cat /tmp/slideshow-nontiff.txt; printf '%s\n' $TIFF_JPGS; } \
  | shuf > "$PLAYLIST"

rm -f /tmp/slideshow-nontiff.txt
echo "Playlist written: $(wc -l < "$PLAYLIST") entries → $PLAYLIST"
