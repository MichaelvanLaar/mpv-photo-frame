#!/usr/bin/env bash
# shellcheck shell=bash
# Shared config/slideshow resolution for mpv-photo-frame.
# Sourced by slideshow.sh and generate-slideshow-playlist.sh — not run directly.

# Print the names of defined slideshows (slideshows/*.conf, excluding example).
# Usage: slideshow_names <slideshows_dir>   -> one name per line on stdout
slideshow_names() {
  local dir="$1" f name
  [[ -d "$dir" ]] || return 0
  for f in "$dir"/*.conf; do
    [[ -e "$f" ]] || continue
    name="$(basename "$f" .conf)"
    [[ "$name" == "example" ]] && continue
    printf '%s\n' "$name"
  done
}

# Print available slideshows for humans.
# Usage: slideshow_list <slideshows_dir>
slideshow_list() {
  local dir="$1" name found=false
  echo "Available slideshows:"
  while IFS= read -r name; do
    echo "  $name"
    found=true
  done < <(slideshow_names "$dir")
  "$found" || echo "  (none yet — create $dir/<name>.conf; see example.conf)"
}

# Validate a slideshow name: reject path separators and parent refs.
# Usage: slideshow_validate_name <name>   -> 0 ok, 1 invalid
slideshow_validate_name() {
  case "$1" in
  */* | *..*) return 1 ;;
  esac
  return 0
}

# Load app settings + a named slideshow's config (last wins), then set
# SLIDESHOW_NAME and a per-name SLIDESHOW_PLAYLIST default when unset.
# Usage: slideshow_load <script_dir> <name>   (exits 2 on invalid/unknown name)
slideshow_load() {
  local script_dir="$1" name="$2"
  local slideshows_dir="$script_dir/slideshows"

  # shellcheck source=/dev/null
  [[ -f "$script_dir/slideshow.conf" ]] && source "$script_dir/slideshow.conf"

  if ! slideshow_validate_name "$name"; then
    echo "Error: invalid slideshow name '$name'." >&2
    exit 2
  fi
  local conf="$slideshows_dir/$name.conf"
  if [[ ! -f "$conf" ]]; then
    echo "Error: no slideshow named '$name'." >&2
    slideshow_list "$slideshows_dir" >&2
    exit 2
  fi
  # shellcheck source=/dev/null
  source "$conf"

  # shellcheck disable=SC2034  # consumed by the sourcing script
  SLIDESHOW_NAME="$name"
  if [[ -z "${SLIDESHOW_PLAYLIST:-}" ]]; then
    SLIDESHOW_PLAYLIST="$HOME/.cache/slideshow-playlist-$name.m3u"
  fi
}

# Resolve which slideshow to play when no name was given (three-layer) and store
# the result in the global SLIDESHOW_NAME:
#   0 slideshows -> message + exit 1
#   1 slideshow  -> SLIDESHOW_NAME = its name
#   2+           -> interactive numbered chooser on a TTY; otherwise list + exit 1
# Sets a global (does NOT echo) so it can run in the main shell where the TTY is
# real — calling it via "$(...)" would make stdout a pipe and disable the menu.
# Usage: slideshow_choose <script_dir>   (sets SLIDESHOW_NAME, or exits non-zero)
slideshow_choose() {
  local script_dir="$1"
  local slideshows_dir="$script_dir/slideshows"
  local -a names=()
  mapfile -t names < <(slideshow_names "$slideshows_dir")

  if [[ "${#names[@]}" -eq 0 ]]; then
    echo "No slideshows yet. Create one: copy $slideshows_dir/example.conf to" >&2
    echo "$slideshows_dir/<name>.conf and set its SLIDESHOW_SOURCES (or use the GUI)." >&2
    exit 1
  fi
  if [[ "${#names[@]}" -eq 1 ]]; then
    # shellcheck disable=SC2034  # consumed by the sourcing script
    SLIDESHOW_NAME="${names[0]}"
    return 0
  fi
  if [[ ! -t 0 || ! -t 1 ]]; then
    echo "Multiple slideshows exist; pass one as the argument:" >&2
    slideshow_list "$slideshows_dir" >&2
    exit 1
  fi
  echo "Choose a slideshow:" >&2
  local i=1 n
  for n in "${names[@]}"; do
    printf '  %d) %s\n' "$i" "$n" >&2
    i=$((i + 1))
  done
  local choice
  read -rp "Number: " choice
  if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#names[@]})); then
    # shellcheck disable=SC2034  # consumed by the sourcing script
    SLIDESHOW_NAME="${names[choice - 1]}"
    return 0
  fi
  echo "Invalid selection." >&2
  exit 1
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
    echo "Error: SLIDESHOW_SOURCES is not set. Copy slideshow.conf.example to slideshow.conf and edit it." >&2
    exit 2
  fi

  while IFS= read -r line; do
    # Trim surrounding whitespace.
    trimmed="${line#"${line%%[![:space:]]*}"}"
    trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
    [[ -z "$trimmed" ]] && continue     # blank line
    [[ "$trimmed" == \#* ]] && continue # comment line

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
