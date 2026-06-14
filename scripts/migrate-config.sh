#!/usr/bin/env bash
# shellcheck shell=bash
# One-time migration from the old "default slideshow" layout to settings+slideshows.
# Idempotent and safe to re-run. Sourced by install.sh (calls migrate_config), or
# run directly:  bash scripts/migrate-config.sh

# Strip a top-level SLIDESHOW_SOURCES assignment (single- or multi-line, quoted)
# from stdin, leaving every other line intact. Reads stdin, writes stdout.
migrate_strip_sources() {
  awk '
    skip == 1 { if ($0 ~ /"/) skip = 0; next }
    /^[[:space:]]*SLIDESHOW_SOURCES=/ {
      rest = $0; sub(/^[^=]*=/, "", rest)   # value after the first =
      if (rest !~ /"/) next                 # unquoted single-line value
      sub(/^[^"]*"/, "", rest)              # drop up to the opening quote
      if (rest ~ /"/) next                  # closing quote on the same line
      skip = 1; next                        # multi-line: skip until closing quote
    }
    { print }
  '
}

# Migrate the installation rooted at <script_dir>. Idempotent.
migrate_config() {
  local script_dir="$1"
  local conf="$script_dir/slideshow.conf"
  local slideshows_dir="$script_dir/slideshows"
  local profiles_dir="$script_dir/profiles"
  local did=false

  mkdir -p "$slideshows_dir"

  # 1. Move any leftover user profiles/*.conf into slideshows/.
  if [[ -d "$profiles_dir" ]]; then
    local f base dest
    for f in "$profiles_dir"/*.conf; do
      [[ -e "$f" ]] || continue
      base="$(basename "$f")"
      [[ "$base" == "example.conf" ]] && continue
      dest="$slideshows_dir/$base"
      if [[ -e "$dest" ]]; then
        echo "migrate: skip $base (already in slideshows/)"
      else
        mv "$f" "$dest"
        echo "migrate: moved profiles/$base -> slideshows/$base"
        did=true
      fi
    done
    rmdir "$profiles_dir" 2>/dev/null && echo "migrate: removed empty profiles/"
  fi

  # 2. Extract SLIDESHOW_SOURCES from slideshow.conf into slideshows/all-photos.conf.
  if [[ -f "$conf" ]]; then
    local sources
    # shellcheck source=/dev/null
    sources="$(
      source "$conf"
      printf '%s' "${SLIDESHOW_SOURCES:-}"
    )"
    if [[ -n "$sources" ]]; then
      local target="$slideshows_dir/all-photos.conf"
      if [[ -e "$target" ]]; then
        echo "migrate: $target exists; left slideshow.conf sources untouched"
      else
        [[ -f "$conf.bak" ]] || {
          cp "$conf" "$conf.bak"
          echo "migrate: backed up slideshow.conf -> slideshow.conf.bak"
        }
        {
          echo "# Migrated from slideshow.conf — rename this file to retitle the slideshow."
          printf 'SLIDESHOW_SOURCES="%s"\n' "$sources"
        } >"$target"
        echo "migrate: wrote sources -> slideshows/all-photos.conf"
        local stripped
        stripped="$(migrate_strip_sources <"$conf")"
        printf '%s\n' "$stripped" >"$conf"
        echo "migrate: removed SLIDESHOW_SOURCES from slideshow.conf (settings kept)"
        did=true
      fi
    fi
  fi

  "$did" || echo "migrate: nothing to migrate"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  set -euo pipefail
  _root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  migrate_config "$_root"
fi
