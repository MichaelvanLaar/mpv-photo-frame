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
