#!/usr/bin/env bash
# Generate a shuffled playlist for mpv-photo-frame.
# Usage: generate-slideshow-playlist.sh [name|--all]   (no arg = --all; see --list)
# Converts TIFF files to JPEG cache in parallel (skips already-cached).
# Configure via slideshow.conf in this script's directory — see slideshow.conf.example.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=slideshow-lib.sh
source "$SCRIPT_DIR/slideshow-lib.sh"

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
      echo "$name" >"$dst.name"
      echo "$dst"
    }
  else
    echo "$name" >"$dst.name"
    echo "$dst"
  fi
}
export -f convert_tiff

# Generate one slideshow's playlist. Assumes slideshow_load has populated
# SLIDESHOW_SOURCES / SLIDESHOW_PLAYLIST / SLIDESHOW_TIFF_CACHE for this run.
generate_one() {
  TIFF_CACHE="${SLIDESHOW_TIFF_CACHE:-$HOME/.cache/slideshow-tiff-cache}"
  PLAYLIST="$SLIDESHOW_PLAYLIST"
  mkdir -p "$(dirname "$PLAYLIST")" "$TIFF_CACHE"
  export TIFF_CACHE
  slideshow_parse_sources

  echo "Scanning for TIFF files…"
  TIFF_COUNT=$(find "${SLIDESHOW_ROOTS[@]}" \
    "${SLIDESHOW_PRUNE[@]}" \
    -type f \( -iname "*.tiff" -o -iname "*.tif" \) -print | wc -l)
  echo "Converting $TIFF_COUNT TIFF files (skipping already-cached)…"

  TIFF_JPGS=$(find "${SLIDESHOW_ROOTS[@]}" \
    "${SLIDESHOW_PRUNE[@]}" \
    -type f \( -iname "*.tiff" -o -iname "*.tif" \) -print0 |
    xargs -0 -P "$(nproc)" -I{} bash -c 'convert_tiff "$@"' _ {})

  echo "Building playlist…"
  local nontiff_list
  nontiff_list=$(mktemp) || return 1
  find "${SLIDESHOW_ROOTS[@]}" \
    "${SLIDESHOW_PRUNE[@]}" \
    -type f \( \
    -iname "*.jpg" -o -iname "*.jpeg" \
    -o -iname "*.png" -o -iname "*.webp" \
    -o -iname "*.gif" -o -iname "*.bmp" \
    -o -iname "*.avif" -o -iname "*.heic" \
    -o -iname "*.mp4" -o -iname "*.mov" \
    -o -iname "*.avi" -o -iname "*.mkv" \
    -o -iname "*.m4v" -o -iname "*.3gp" \
    \) -print >"$nontiff_list"

  # shellcheck disable=SC2086  # intentional word-split of the newline-separated TIFF list
  {
    cat "$nontiff_list"
    printf '%s\n' $TIFF_JPGS
  } | shuf >"$PLAYLIST"
  rm -f "$nontiff_list"
  echo "Playlist written: $(wc -l <"$PLAYLIST") entries → $PLAYLIST"
}

mode="${1:-}"
case "$mode" in
--list | -l)
  slideshow_list "$SCRIPT_DIR/slideshows"
  exit 0
  ;;
"" | --all)
  mapfile -t _names < <(slideshow_names "$SCRIPT_DIR/slideshows")
  if [[ "${#_names[@]}" -eq 0 ]]; then
    echo "No slideshows to generate. Create slideshows/<name>.conf first." >&2
    exit 1
  fi
  for _n in "${_names[@]}"; do
    echo "=== $_n ==="
    (slideshow_load "$SCRIPT_DIR" "$_n" && generate_one) || exit 1
  done
  ;;
*)
  slideshow_load "$SCRIPT_DIR" "$mode"
  generate_one
  ;;
esac
