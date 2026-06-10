#!/usr/bin/env bash
# Digital picture frame slideshow (images + videos, no audio).
# Usage: slideshow.sh [compilation]   (see profiles/, or --list)
# Configure via .env in this script's directory — see .env.example.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=slideshow-lib.sh
source "$SCRIPT_DIR/slideshow-lib.sh"
slideshow_init "$SCRIPT_DIR" "$@"

: "${SLIDESHOW_BASE:?'SLIDESHOW_BASE is not set. Copy .env.example to .env and edit it.'}"
DELAY="${SLIDESHOW_DELAY:-10}"

# Build (and cache) this compilation's playlist on first use, or rebuild if the
# cache is empty/blank. The generator also performs TIFF→JPEG conversion, reusing
# the shared TIFF cache, so a compilation whose files were already cached by
# another incurs scan-only cost.
if ! grep -q '[^[:space:]]' "$SLIDESHOW_PLAYLIST" 2>/dev/null; then
  profile_arg=()
  [[ -n "$SLIDESHOW_PROFILE" ]] && profile_arg=("$SLIDESHOW_PROFILE")
  "$SCRIPT_DIR/generate-slideshow-playlist.sh" "${profile_arg[@]}" || exit 1
fi

# Refuse to launch on an empty/missing playlist; drop the empty cache so the
# next run regenerates instead of trusting a stale empty file.
if ! grep -q '[^[:space:]]' "$SLIDESHOW_PLAYLIST" 2>/dev/null; then
  echo "Error: no media found — playlist is empty: $SLIDESHOW_PLAYLIST" >&2
  rm -f "$SLIDESHOW_PLAYLIST"
  exit 1
fi

mpv \
  --fullscreen \
  --no-audio \
  --image-display-duration="$DELAY" \
  --loop-playlist=inf \
  --shuffle \
  --playlist="$SLIDESHOW_PLAYLIST"
