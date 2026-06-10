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

# Overlay options: forward only the ones set in .env; unset ones use the
# photo-info.lua built-in defaults (see .env.example).
overlay_opts=()
[[ -n "${SLIDESHOW_OVERLAY_FONT:-}" ]]     && overlay_opts+=(--script-opts-append="photo-info-font=$SLIDESHOW_OVERLAY_FONT")
[[ -n "${SLIDESHOW_OVERLAY_SIZE:-}" ]]     && overlay_opts+=(--script-opts-append="photo-info-size=$SLIDESHOW_OVERLAY_SIZE")
[[ -n "${SLIDESHOW_OVERLAY_COLOR:-}" ]]    && overlay_opts+=(--script-opts-append="photo-info-color=$SLIDESHOW_OVERLAY_COLOR")
[[ -n "${SLIDESHOW_OVERLAY_OUTLINE:-}" ]]  && overlay_opts+=(--script-opts-append="photo-info-outline=$SLIDESHOW_OVERLAY_OUTLINE")
[[ -n "${SLIDESHOW_OVERLAY_POSITION:-}" ]] && overlay_opts+=(--script-opts-append="photo-info-position=$SLIDESHOW_OVERLAY_POSITION")
[[ -n "${SLIDESHOW_OVERLAY_LANG:-}" ]]     && overlay_opts+=(--script-opts-append="photo-info-lang=$SLIDESHOW_OVERLAY_LANG")
[[ -n "${SLIDESHOW_OVERLAY_CLOCK:-}" ]]    && overlay_opts+=(--script-opts-append="photo-info-clock=$SLIDESHOW_OVERLAY_CLOCK")

mpv \
  --fullscreen \
  --no-audio \
  --image-display-duration="$DELAY" \
  --loop-playlist=inf \
  --shuffle \
  "${overlay_opts[@]}" \
  --playlist="$SLIDESHOW_PLAYLIST"
