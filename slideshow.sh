#!/usr/bin/env bash
# Digital picture frame slideshow (images + videos, no audio).
# Usage: slideshow.sh [name]   (no name: auto-pick / chooser; see --list)
# Configure via slideshow.conf in this script's directory — see slideshow.conf.example.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=slideshow-lib.sh
source "$SCRIPT_DIR/slideshow-lib.sh"

if [[ "${1:-}" == "--list" || "${1:-}" == "-l" ]]; then
  slideshow_list "$SCRIPT_DIR/slideshows"
  exit 0
fi

# Pick the slideshow: explicit name, else the three-layer chooser.
# slideshow_choose sets SLIDESHOW_NAME in this shell (not via $(...)) so the
# interactive menu's TTY checks work and `exit` propagates.
if [[ -n "${1:-}" ]]; then
  SLIDESHOW_NAME="$1"
else
  slideshow_choose "$SCRIPT_DIR"
fi
slideshow_load "$SCRIPT_DIR" "$SLIDESHOW_NAME"

: "${SLIDESHOW_SOURCES:?This slideshow has no SLIDESHOW_SOURCES; edit slideshows/<name>.conf.}"
DELAY="${SLIDESHOW_DELAY:-10}"

# Build (and cache) this slideshow's playlist on first use, or rebuild if the
# cache is empty/blank. The generator also performs TIFF→JPEG conversion, reusing
# the shared TIFF cache, so a slideshow whose files were already cached by another
# incurs scan-only cost.
if ! grep -q '[^[:space:]]' "$SLIDESHOW_PLAYLIST" 2>/dev/null; then
  "$SCRIPT_DIR/generate-slideshow-playlist.sh" "$SLIDESHOW_NAME" || exit 1
fi

# Refuse to launch on an empty/missing playlist; drop the empty cache so the
# next run regenerates instead of trusting a stale empty file.
if ! grep -q '[^[:space:]]' "$SLIDESHOW_PLAYLIST" 2>/dev/null; then
  echo "Error: no media found — playlist is empty: $SLIDESHOW_PLAYLIST" >&2
  rm -f "$SLIDESHOW_PLAYLIST"
  exit 1
fi

# Script options: forward only the ones set in slideshow.conf; unset ones use
# each Lua script's built-in defaults (see slideshow.conf.example).
script_opts=()
[[ -n "${SLIDESHOW_OVERLAY_FONT:-}" ]] && script_opts+=(--script-opts-append="photo-info-font=$SLIDESHOW_OVERLAY_FONT")
[[ -n "${SLIDESHOW_OVERLAY_SIZE:-}" ]] && script_opts+=(--script-opts-append="photo-info-size=$SLIDESHOW_OVERLAY_SIZE")
[[ -n "${SLIDESHOW_OVERLAY_COLOR:-}" ]] && script_opts+=(--script-opts-append="photo-info-color=$SLIDESHOW_OVERLAY_COLOR")
[[ -n "${SLIDESHOW_OVERLAY_OUTLINE:-}" ]] && script_opts+=(--script-opts-append="photo-info-outline=$SLIDESHOW_OVERLAY_OUTLINE")
[[ -n "${SLIDESHOW_OVERLAY_POSITION:-}" ]] && script_opts+=(--script-opts-append="photo-info-position=$SLIDESHOW_OVERLAY_POSITION")
[[ -n "${SLIDESHOW_OVERLAY_LANG:-}" ]] && script_opts+=(--script-opts-append="photo-info-lang=$SLIDESHOW_OVERLAY_LANG")
[[ -n "${SLIDESHOW_OVERLAY_CLOCK:-}" ]] && script_opts+=(--script-opts-append="photo-info-clock=$SLIDESHOW_OVERLAY_CLOCK")
[[ -n "${SLIDESHOW_BLURRED_BACKGROUND:-}" ]] && script_opts+=(--script-opts-append="blurred-background-mode=$SLIDESHOW_BLURRED_BACKGROUND")

mpv \
  --fullscreen \
  --no-audio \
  --image-display-duration="$DELAY" \
  --loop-playlist=inf \
  --shuffle \
  "${script_opts[@]}" \
  --playlist="$SLIDESHOW_PLAYLIST"
