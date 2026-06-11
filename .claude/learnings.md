# Learnings

Corrections and observations collected during configuration sessions.
Entries are tagged by skill and dated.

---

[cc-config:cc-config-init] A global prettier PostToolUse hook reformats Markdown on every Write/Edit; it column-aligns the Key Config Files table, which the pre-commit sync script then compacts — expect minor cosmetic churn between the two formats. — 2026-06-08
[cc-config:cc-config-optimize] The `.env.*` and `profiles/*.env` deny globs were removed because their only matches were the public `.env.example` / `profiles/example.env` templates (which must stay editable); the real secret `.env` stays protected via `Read(./.env)`. Don't re-add the broad globs. — 2026-06-11
