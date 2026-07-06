#!/usr/bin/env bash
# Framework-free unit tests for scripts/cut-release.sh.
# Run: bash tests/cut-release.test.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../scripts/cut-release.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/cut-release.sh"

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

# commits <msg1> [msg2...] -> writes NUL-terminated messages to stdout
commits() {
  local m
  for m in "$@"; do
    printf '%s\0' "$m"
  done
}

# git_log_commits <msg1> [msg2...] -> writes NUL-terminated messages to
# stdout, replicating `git log --format=%B%x00`'s real behavior: git's
# tformat separator prepends a "\n" before every record except the first.
git_log_commits() {
  local m first=true
  for m in "$@"; do
    if $first; then
      first=false
    else
      printf '\n'
    fi
    printf '%s\n\0' "$m"
  done
}

check "no commits -> none" "none" "$(commits | bump_type_for_commits)"
check "only chore -> none" "none" "$(commits 'chore: 🔧 tidy up' | bump_type_for_commits)"
check "only chore+test+ci -> none" "none" "$(commits 'chore: 🔧 x' 'test: ✅ y' 'ci: 💚 z' | bump_type_for_commits)"
check "only fix -> patch" "patch" "$(commits 'fix: 🐛 crash on empty list' | bump_type_for_commits)"
check "fix+docs -> patch" "patch" "$(commits 'fix: 🐛 x' 'docs: 📝 y' | bump_type_for_commits)"
check "fix+chore -> patch (chore ignored)" "patch" "$(commits 'fix: 🐛 x' 'chore: 🔧 y' | bump_type_for_commits)"
check "feat -> minor" "minor" "$(commits 'feat: ✨ add blur toggle' | bump_type_for_commits)"
check "feat+fix -> minor" "minor" "$(commits 'feat: ✨ x' 'fix: 🐛 y' | bump_type_for_commits)"
check "bang in type -> major" "major" "$(commits 'feat!: 💥 drop old config format' | bump_type_for_commits)"
check "bang with scope -> major" "major" "$(commits 'fix(config)!: 💥 x' | bump_type_for_commits)"
check "footer BREAKING CHANGE -> major" "major" "$(commits $'feat: add x\n\nBREAKING CHANGE: config format changed' | bump_type_for_commits)"
check "major wins over feat+fix" "major" "$(commits 'feat: ✨ x' 'fix!: 💥 y' | bump_type_for_commits)"
check "unrecognized type alone -> none" "none" "$(commits 'wip: not a real type' | bump_type_for_commits)"

# Regression: real `git log --format=%B%x00` output prepends "\n" before
# every record but the first (git's tformat separator). commits() above
# doesn't reproduce this, so it can't catch a subject-extraction bug that
# only trips on records 2+.
check "real git-log separator: feat as 2nd record -> minor" "minor" "$(git_log_commits 'fix: 🐛 x' 'feat: ✨ y' | bump_type_for_commits)"
check "real git-log separator: feat as 3rd record -> minor" "minor" "$(git_log_commits 'chore: 🔧 a' 'docs: 📝 b' 'feat: ✨ c' | bump_type_for_commits)"

check "no current version -> 1.0.0 (patch)" "1.0.0" "$(next_version "" "patch")"
check "no current version -> 1.0.0 (major)" "1.0.0" "$(next_version "" "major")"
check "patch bump" "1.4.3" "$(next_version "1.4.2" "patch")"
check "minor bump resets patch" "1.5.0" "$(next_version "1.4.2" "minor")"
check "major bump resets minor+patch" "2.0.0" "$(next_version "1.4.2" "major")"
check "patch bump from x.y.0" "0.1.1" "$(next_version "0.1.0" "patch")"

section="$(commits 'feat: ✨ add blur toggle' 'fix: 🐛 crash on empty list' | format_changelog_section "1.4.0" "2026-07-05")"
check "section: header" "## [1.4.0] - 2026-07-05" "$(head -n1 <<<"$section")"
check "section: has Added" "true" "$([[ "$section" == *"### Added"* ]] && echo true || echo false)"
check "section: Added bullet" "true" "$([[ "$section" == *"- ✨ add blur toggle"* ]] && echo true || echo false)"
check "section: has Fixed" "true" "$([[ "$section" == *"### Fixed"* ]] && echo true || echo false)"
check "section: Fixed bullet" "true" "$([[ "$section" == *"- 🐛 crash on empty list"* ]] && echo true || echo false)"

docs_only="$(commits 'docs: 📝 fix typo' | format_changelog_section "1.4.1" "2026-07-06")"
check "docs-only: no Added section" "false" "$([[ "$docs_only" == *"### Added"* ]] && echo true || echo false)"
check "docs-only: no Fixed section" "false" "$([[ "$docs_only" == *"### Fixed"* ]] && echo true || echo false)"
check "docs-only: has Docs" "true" "$([[ "$docs_only" == *"### Docs"* ]] && echo true || echo false)"

chore_excluded="$(commits 'fix: 🐛 x' 'chore: 🔧 internal cleanup' | format_changelog_section "1.4.2" "2026-07-07")"
check "chore excluded from output" "false" "$([[ "$chore_excluded" == *"internal cleanup"* ]] && echo true || echo false)"

real_git_log_section="$(git_log_commits 'chore: 🔧 a' 'feat: ✨ add blur toggle' | format_changelog_section "1.4.3" "2026-07-08")"
check "real git-log separator: 2nd-record feat reaches changelog" "true" "$([[ "$real_git_log_section" == *"- ✨ add blur toggle"* ]] && echo true || echo false)"

echo
if [[ $fails -eq 0 ]]; then
  echo "All tests passed."
else
  echo "$fails test(s) failed."
  exit 1
fi
