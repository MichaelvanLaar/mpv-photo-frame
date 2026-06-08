# Learnings

Corrections and observations collected during configuration sessions.
Entries are tagged by skill and dated.

---

[cc-config:cc-config-init] No verify-loop tooling is installed — shellcheck/shfmt/luacheck all absent; CLAUDE.md names the commands but the loop is inactive until `apt install`/`go install`/`luarocks install`. — 2026-06-08
[cc-config:cc-config-init] A global prettier PostToolUse hook reformats Markdown on every Write/Edit; it column-aligns the Key Config Files table, which the pre-commit sync script then compacts — expect minor cosmetic churn between the two formats. — 2026-06-08
