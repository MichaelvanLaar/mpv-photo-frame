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

echo
if [[ $fails -eq 0 ]]; then
  echo "All tests passed."
else
  echo "$fails test(s) failed."
  exit 1
fi
