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

# Parse SLIDESHOW_SOURCES into SLIDESHOW_ROOTS[] (find start dirs) and
# SLIDESHOW_PRUNE[] (a combined find -prune expression).
# Each non-blank, non-comment line:   PATH [ | exclude1,exclude2,... ]
# Excludes are relative to that line's PATH and pruned as "$PATH/$exclude".
# Missing PATHs are warned to stderr and skipped; an empty SLIDESHOW_SOURCES
# or zero usable roots is a fatal error (exit 2).
# Note: on those fatal errors it calls exit (not return) to abort the calling script.
slideshow_parse_sources() {
  # shellcheck disable=SC2034  # both arrays are consumed by the sourcing script
  SLIDESHOW_ROOTS=()
  # shellcheck disable=SC2034  # consumed by the sourcing script
  SLIDESHOW_PRUNE=()
  local -a prune_paths=()
  local line trimmed path excludes excl p first

  if [[ -z "${SLIDESHOW_SOURCES:-}" ]]; then
    echo "Error: SLIDESHOW_SOURCES is not set. Copy .env.example to .env and edit it." >&2
    exit 2
  fi

  while IFS= read -r line; do
    # Trim surrounding whitespace.
    trimmed="${line#"${line%%[![:space:]]*}"}"
    trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
    [[ -z "$trimmed" ]] && continue   # blank line
    [[ "$trimmed" == \#* ]] && continue   # comment line

    # Split "PATH | excludes" on the first '|'.
    if [[ "$trimmed" == *"|"* ]]; then
      path="${trimmed%%|*}"
      excludes="${trimmed#*|}"
    else
      path="$trimmed"
      excludes=""
    fi

    # Trim the path and drop a single trailing slash (but never reduce "/").
    path="${path#"${path%%[![:space:]]*}"}"
    path="${path%"${path##*[![:space:]]}"}"
    [[ "$path" != "/" ]] && path="${path%/}"
    [[ -z "$path" ]] && continue

    if [[ ! -d "$path" ]]; then
      echo "Warning: source folder not found, skipping: $path" >&2
      continue
    fi
    SLIDESHOW_ROOTS+=("$path")

    # Excludes: comma-separated, each relative to this path.
    if [[ -n "$excludes" ]]; then
      while IFS= read -r excl; do
        excl="${excl#"${excl%%[![:space:]]*}"}"
        excl="${excl%"${excl##*[![:space:]]}"}"
        [[ -z "$excl" ]] && continue
        prune_paths+=("$path/$excl")
      done < <(tr ',' '\n' <<<"$excludes")
    fi
  done <<<"$SLIDESHOW_SOURCES"

  if [[ "${#SLIDESHOW_ROOTS[@]}" -eq 0 ]]; then
    echo "Error: no usable source folders in SLIDESHOW_SOURCES." >&2
    exit 2
  fi

  # Build the prune expression from all collected exclude paths.
  if [[ "${#prune_paths[@]}" -gt 0 ]]; then
    SLIDESHOW_PRUNE+=('(')
    first=true
    for p in "${prune_paths[@]}"; do
      "$first" || SLIDESHOW_PRUNE+=('-o')
      SLIDESHOW_PRUNE+=('-path' "$p")
      first=false
    done
    SLIDESHOW_PRUNE+=(')' '-prune' '-o')
  fi
}
