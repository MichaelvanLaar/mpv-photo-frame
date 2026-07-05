#!/usr/bin/env bash
# shellcheck shell=bash
# Release helpers for mpv-photo-frame: version-bump detection, next-version
# arithmetic, and CHANGELOG.md section formatting. Sourced by the /release
# skill for unit-testable logic; run directly for its CLI (see bottom).
#   bash scripts/cut-release.sh bump | next-version <cur> <bump> | changelog <version> <date>

# Reads NUL-terminated full commit messages from stdin (git log --format=%B%x00).
# Prints major|minor|patch|none.
bump_type_for_commits() {
  local record subject type bang is_major=false has_feat=false has_relevant=false
  while IFS= read -r -d '' record; do
    [[ -z "$record" ]] && continue
    subject="${record%%$'\n'*}"
    if [[ "$subject" =~ ^([a-z]+)(\([^\)]*\))?(\!)?:[[:space:]] ]]; then
      type="${BASH_REMATCH[1]}"
      bang="${BASH_REMATCH[3]}"
      [[ -n "$bang" ]] && is_major=true
      case "$type" in
      feat)
        has_feat=true
        has_relevant=true
        ;;
      fix | refactor | perf | docs | style | build)
        has_relevant=true
        ;;
      *) ;; # chore/test/ci/unrecognized: doesn't count
      esac
    fi
    [[ "$record" == *"BREAKING CHANGE:"* ]] && is_major=true
  done
  if $is_major; then
    echo "major"
  elif $has_feat; then
    echo "minor"
  elif $has_relevant; then
    echo "patch"
  else
    echo "none"
  fi
}

# next_version <current_or_empty> <bump>  -> prints the next bare semver.
next_version() {
  local current="$1" bump="$2"
  if [[ -z "$current" ]]; then
    echo "1.0.0"
    return
  fi
  local major minor patch
  IFS='.' read -r major minor patch <<<"$current"
  case "$bump" in
  major)
    echo "$((major + 1)).0.0"
    ;;
  minor)
    echo "$major.$((minor + 1)).0"
    ;;
  patch)
    echo "$major.$minor.$((patch + 1))"
    ;;
  esac
}

# format_changelog_section <version> <date>  -> prints a Markdown section,
# reading NUL-terminated full commit messages from stdin (same format as
# bump_type_for_commits).
format_changelog_section() {
  local version="$1" date="$2"
  local -a added=() fixed=() changed=() docs=()
  local record subject type desc

  while IFS= read -r -d '' record; do
    [[ -z "$record" ]] && continue
    subject="${record%%$'\n'*}"
    if [[ "$subject" =~ ^([a-z]+)(\([^\)]*\))?\!?:[[:space:]](.*)$ ]]; then
      type="${BASH_REMATCH[1]}"
      desc="${BASH_REMATCH[3]}"
      case "$type" in
      feat) added+=("$desc") ;;
      fix) fixed+=("$desc") ;;
      refactor | perf | style | build) changed+=("$desc") ;;
      docs) docs+=("$desc") ;;
      *) ;; # chore/test/ci/unrecognized: excluded
      esac
    fi
  done

  printf '## [%s] - %s\n' "$version" "$date"
  local d
  if [[ "${#added[@]}" -gt 0 ]]; then
    printf '\n### Added\n'
    for d in "${added[@]}"; do printf -- '- %s\n' "$d"; done
  fi
  if [[ "${#fixed[@]}" -gt 0 ]]; then
    printf '\n### Fixed\n'
    for d in "${fixed[@]}"; do printf -- '- %s\n' "$d"; done
  fi
  if [[ "${#changed[@]}" -gt 0 ]]; then
    printf '\n### Changed\n'
    for d in "${changed[@]}"; do printf -- '- %s\n' "$d"; done
  fi
  if [[ "${#docs[@]}" -gt 0 ]]; then
    printf '\n### Docs\n'
    for d in "${docs[@]}"; do printf -- '- %s\n' "$d"; done
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  set -euo pipefail
  case "${1:-}" in
  bump)
    bump_type_for_commits
    ;;
  next-version)
    next_version "${2:-}" "${3:-}"
    ;;
  changelog)
    format_changelog_section "${2:-}" "${3:-}"
    ;;
  *)
    echo "Usage: cut-release.sh bump | next-version <current> <bump> | changelog <version> <date>" >&2
    echo "  bump and changelog read NUL-terminated commit messages from stdin." >&2
    exit 2
    ;;
  esac
fi
