#!/usr/bin/env bash
# Digital picture frame slideshow (images + videos, no audio).
# Configure via .env in this script's directory — see .env.example.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "$SCRIPT_DIR/.env" ]] && source "$SCRIPT_DIR/.env"

: "${SLIDESHOW_BASE:?'SLIDESHOW_BASE is not set. Copy .env.example to .env and edit it.'}"
DELAY="${SLIDESHOW_DELAY:-10}"
CACHED_PLAYLIST="${SLIDESHOW_PLAYLIST:-$HOME/.cache/slideshow-playlist.m3u}"

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

if [[ -f "$CACHED_PLAYLIST" ]]; then
  PLAYLIST="$CACHED_PLAYLIST"
else
  PLAYLIST=$(mktemp)
  trap 'rm -f "$PLAYLIST"' EXIT
  find "$SLIDESHOW_BASE" \
    "${_prune[@]}" \
    -type f \( \
      -iname "*.jpg"   -o -iname "*.jpeg" \
      -o -iname "*.png"  -o -iname "*.webp" \
      -o -iname "*.gif"  -o -iname "*.bmp"  \
      -o -iname "*.tiff" -o -iname "*.tif"  \
      -o -iname "*.avif" -o -iname "*.heic" \
      -o -iname "*.mp4"  -o -iname "*.mov"  \
      -o -iname "*.avi"  -o -iname "*.mkv"  \
      -o -iname "*.m4v"  -o -iname "*.3gp"  \
    \) -print0 \
    | shuf -z \
    | tr '\0' '\n' > "$PLAYLIST"
fi

mpv \
  --fullscreen \
  --no-audio \
  --image-display-duration="$DELAY" \
  --loop-playlist=inf \
  --shuffle \
  --playlist="$PLAYLIST"
