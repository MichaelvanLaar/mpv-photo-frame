# Learnings

Corrections and observations collected during configuration sessions.
Entries are tagged by skill and dated.

---

[cc-config:cc-config-init] A global prettier PostToolUse hook reformats Markdown on every Write/Edit; it column-aligns the Key Config Files table, which the pre-commit sync script then compacts — expect minor cosmetic churn between the two formats. — 2026-06-08
[cc-config:cc-config-optimize] `.githooks/pre-commit` (runs `scripts/sync-config-table.sh`) was never wired up — `core.hooksPath` had never been set for this clone, so it never ran. Fixed by running `git config core.hooksPath .githooks`; also documented in CLAUDE.md's Structure section since it's local git config, not tracked by git. — 2026-07-05
