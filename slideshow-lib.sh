#!/usr/bin/env bash
# shellcheck shell=bash
# Shared config/profile resolution for mpv-photo-frame.
# Sourced by slideshow.sh and generate-slideshow-playlist.sh — not run directly.

# Print available compilations (profiles/*.env, excluding the example template).
# Usage: slideshow_list_profiles <profiles_dir>
slideshow_list_profiles() {
  local dir="$1" f name found=false
  echo "Available compilations:"
  if [[ -d "$dir" ]]; then
    for f in "$dir"/*.env; do
      [[ -e "$f" ]] || continue
      name="$(basename "$f" .env)"
      [[ "$name" == "example" ]] && continue
      echo "  $name"
      found=true
    done
  fi
  "$found" || echo "  (none yet — create $dir/<name>.env; see example.env)"
  echo "Run with no argument for the default (shared .env)."
}

# Resolve configuration for an optional compilation argument.
# Usage: slideshow_init <script_dir> "$@"
# - sources <script_dir>/.env, then profiles/<name>.env (last wins)
# - handles --list / -l (prints and exits 0)
# - validates <name>; unknown or invalid name exits non-zero with the list
# - sets SLIDESHOW_PROFILE (empty for the default) and a per-compilation
#   SLIDESHOW_PLAYLIST default when one is not explicitly configured.
slideshow_init() {
  local script_dir="$1"; shift
  local profiles_dir="$script_dir/profiles"

  if [[ "${1:-}" == "--list" || "${1:-}" == "-l" ]]; then
    slideshow_list_profiles "$profiles_dir"
    exit 0
  fi

  # shellcheck disable=SC2034  # consumed by the sourcing script
  SLIDESHOW_PROFILE="${1:-}"

  # shellcheck source=/dev/null
  [[ -f "$script_dir/.env" ]] && source "$script_dir/.env"

  if [[ -n "$SLIDESHOW_PROFILE" ]]; then
    case "$SLIDESHOW_PROFILE" in
      */* | *..*)
        echo "Error: invalid compilation name '$SLIDESHOW_PROFILE'." >&2
        exit 2
        ;;
    esac
    local profile_file="$profiles_dir/$SLIDESHOW_PROFILE.env"
    if [[ ! -f "$profile_file" ]]; then
      echo "Error: no compilation named '$SLIDESHOW_PROFILE'." >&2
      slideshow_list_profiles "$profiles_dir" >&2
      exit 2
    fi
    # shellcheck source=/dev/null
    source "$profile_file"
  fi

  if [[ -z "${SLIDESHOW_PLAYLIST:-}" ]]; then
    if [[ -n "$SLIDESHOW_PROFILE" ]]; then
      SLIDESHOW_PLAYLIST="$HOME/.cache/slideshow-playlist-$SLIDESHOW_PROFILE.m3u"
    else
      SLIDESHOW_PLAYLIST="$HOME/.cache/slideshow-playlist.m3u"
    fi
  fi
}

# Build a find(1) -prune expression from SLIDESHOW_EXCLUDE into SLIDESHOW_PRUNE.
# Usage: slideshow_build_prune   (reads SLIDESHOW_EXCLUDE and SLIDESHOW_BASE)
slideshow_build_prune() {
  # shellcheck disable=SC2034  # consumed by the sourcing script
  SLIDESHOW_PRUNE=()
  [[ -n "${SLIDESHOW_EXCLUDE:-}" ]] || return 0
  SLIDESHOW_PRUNE+=('(')
  local first=true d
  while IFS= read -r d; do
    d="${d#"${d%%[![:space:]]*}"}"
    d="${d%"${d##*[![:space:]]}"}"
    [[ -z "$d" ]] && continue
    "$first" || SLIDESHOW_PRUNE+=('-o')
    SLIDESHOW_PRUNE+=('-path' "$SLIDESHOW_BASE/$d")
    first=false
  done < <(tr ',' '\n' <<< "$SLIDESHOW_EXCLUDE")
  SLIDESHOW_PRUNE+=(')' '-prune' '-o')
}
