#!/usr/bin/env bash
# Framework-free unit tests for the settings+slideshows resolution and migration.
# Run: bash tests/refactor.test.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../slideshow-lib.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/slideshow-lib.sh"
# shellcheck source=../scripts/migrate-config.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/migrate-config.sh"

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

# --- slideshow_names / slideshow_validate_name -----------------------------
home="$(mktemp -d)"
trap 'rm -rf "$home"' EXIT
mkdir -p "$home/slideshows"
printf 'SLIDESHOW_SOURCES="/x"\n' >"$home/slideshows/beach.conf"
printf 'SLIDESHOW_SOURCES="/y"\n' >"$home/slideshows/family.conf"
cp "$SCRIPT_DIR/slideshows/example.conf" "$home/slideshows/example.conf"

names="$(slideshow_names "$home/slideshows" | sort | tr '\n' ' ')"
check "names lists non-example confs" "beach family " "$names"

slideshow_validate_name "ok-name"
check "valid name" "0" "$?"
slideshow_validate_name "a/b"
check "name with slash rejected" "1" "$?"
slideshow_validate_name ".."
check "parent ref rejected" "1" "$?"

# --- slideshow_choose: 1 slideshow sets SLIDESHOW_NAME ---------------------
one="$(mktemp -d)"
mkdir -p "$one/slideshows"
printf 'SLIDESHOW_SOURCES="/z"\n' >"$one/slideshows/only.conf"
SLIDESHOW_NAME=""
slideshow_choose "$one" </dev/null 2>/dev/null
check "choose: single -> SLIDESHOW_NAME" "only" "$SLIDESHOW_NAME"

# --- slideshow_choose: 0 -> exit 1 -----------------------------------------
zero="$(mktemp -d)"
mkdir -p "$zero/slideshows"
(slideshow_choose "$zero" </dev/null) >/dev/null 2>&1
check "choose: none -> exit 1" "1" "$?"

# --- slideshow_choose: 2+ non-tty -> exit 1 --------------------------------
(slideshow_choose "$home" </dev/null) >/dev/null 2>&1
check "choose: many non-tty -> exit 1" "1" "$?"

# --- slideshow_load: sets name + per-name playlist + sources ---------------
HOME_BAK="$HOME"
export HOME="$home"
printf 'SLIDESHOW_DELAY=7\n' >"$home/slideshow.conf"
slideshow_load "$home" "beach"
check "load: name set" "beach" "$SLIDESHOW_NAME"
check "load: sources from slideshow file" "/x" "$SLIDESHOW_SOURCES"
check "load: inherits settings" "7" "$SLIDESHOW_DELAY"
check "load: per-name playlist" "$home/.cache/slideshow-playlist-beach.m3u" "$SLIDESHOW_PLAYLIST"
export HOME="$HOME_BAK"

# --- migrate_strip_sources: single-line ------------------------------------
in_single="$(printf 'SLIDESHOW_DELAY=10\nSLIDESHOW_SOURCES="/a/b"\nSLIDESHOW_OVERLAY_SIZE=large\n')"
out_single="$(printf '%s\n' "$in_single" | migrate_strip_sources)"
check "strip single-line sources" "$(printf 'SLIDESHOW_DELAY=10\nSLIDESHOW_OVERLAY_SIZE=large')" "$out_single"

# --- migrate_strip_sources: multi-line -------------------------------------
in_multi="$(printf 'A=1\nSLIDESHOW_SOURCES="\n  /a | raw\n  /b\n"\nB=2\n')"
out_multi="$(printf '%s\n' "$in_multi" | migrate_strip_sources)"
check "strip multi-line sources" "$(printf 'A=1\nB=2')" "$out_multi"

# --- migrate_strip_sources: unquoted value only eats its own line ----------
in_unq="$(printf 'A=1\nSLIDESHOW_SOURCES=/a/b\nB=2\n')"
out_unq="$(printf '%s\n' "$in_unq" | migrate_strip_sources)"
check "strip unquoted sources (one line)" "$(printf 'A=1\nB=2')" "$out_unq"

echo
if [[ $fails -eq 0 ]]; then echo "All tests passed."; else
  echo "$fails test(s) failed."
  exit 1
fi
