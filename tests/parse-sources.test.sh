#!/usr/bin/env bash
# Framework-free unit tests for slideshow_parse_sources.
# Run: bash tests/parse-sources.test.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../slideshow-lib.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/slideshow-lib.sh"

fails=0
check() { # check <description> <expected> <actual>
  if [[ "$2" == "$3" ]]; then
    echo "ok   - $1"
  else
    echo "FAIL - $1"
    echo "       expected: [$2]"
    echo "       actual:   [$3]"
    fails=$((fails + 1))
  fi
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/a/private" "$tmp/a/keep" "$tmp/a/raw" "$tmp/b" "$tmp/c/raw"

# A: single folder, no excludes
SLIDESHOW_SOURCES="$tmp/a"
slideshow_parse_sources
check "single root" "$tmp/a" "${SLIDESHOW_ROOTS[*]}"
check "single root: no prune" "" "${SLIDESHOW_PRUNE[*]}"

# B: two folders, one exclude each
SLIDESHOW_SOURCES="
  $tmp/a | private
  $tmp/c | raw
"
slideshow_parse_sources
check "two roots" "$tmp/a $tmp/c" "${SLIDESHOW_ROOTS[*]}"
check "two roots: prune" "( -path $tmp/a/private -o -path $tmp/c/raw ) -prune -o" "${SLIDESHOW_PRUNE[*]}"

# C: blank lines and # comments skipped
SLIDESHOW_SOURCES="
# commented out
  $tmp/b

"
slideshow_parse_sources
check "comment/blank skipped" "$tmp/b" "${SLIDESHOW_ROOTS[*]}"

# D: multiple excludes on one line
SLIDESHOW_SOURCES="$tmp/a | private,keep"
slideshow_parse_sources
check "multi-exclude prune" "( -path $tmp/a/private -o -path $tmp/a/keep ) -prune -o" "${SLIDESHOW_PRUNE[*]}"

# E: trailing slash on path does not double the separator
SLIDESHOW_SOURCES="$tmp/a/ | raw"
slideshow_parse_sources
check "trailing slash trimmed" "$tmp/a" "${SLIDESHOW_ROOTS[*]}"
check "trailing slash prune" "( -path $tmp/a/raw ) -prune -o" "${SLIDESHOW_PRUNE[*]}"

# F: missing folder warned and skipped, valid one kept
# shellcheck disable=SC2034  # read by sourced slideshow_parse_sources
SLIDESHOW_SOURCES="
  $tmp/a
  $tmp/does-not-exist
"
slideshow_parse_sources 2>/dev/null
check "missing skipped" "$tmp/a" "${SLIDESHOW_ROOTS[*]}"

# G: empty SLIDESHOW_SOURCES -> exit 2
(SLIDESHOW_SOURCES="" slideshow_parse_sources) 2>/dev/null
check "empty -> exit 2" "2" "$?"

# H: all paths missing -> exit 2
(SLIDESHOW_SOURCES="/no/such/folder" slideshow_parse_sources) 2>/dev/null
check "all-missing -> exit 2" "2" "$?"

echo
if [[ $fails -eq 0 ]]; then
  echo "All tests passed."
else
  echo "$fails test(s) failed."
  exit 1
fi
