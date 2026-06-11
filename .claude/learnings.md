# Learnings

Corrections and observations collected during configuration sessions.
Entries are tagged by skill and dated.

---

[cc-config:cc-config-init] A global prettier PostToolUse hook reformats Markdown on every Write/Edit; it column-aligns the Key Config Files table, which the pre-commit sync script then compacts — expect minor cosmetic churn between the two formats. — 2026-06-08
[cc-config:cc-config-optimize] Env protection uses a template-aware PreToolUse hook, NOT `permissions.deny` globs (deny can't exclude templates, so `Read(./.env.*)` wrongly blocks `.env.example`). The project `settings.json` has its own PreToolUse hook (allows `*.example`/`*.sample`/`*.template`/`*.dist`/`example.env`/`sample.env`; blocks `.env`/`.env.*`/`*.env`, covering `profiles/*.env`) so the repo is self-contained; the user-level hook mirrors it globally. Only blunt deny is exact `Read(./.env)`. Don't add `.env.*`/`profiles/*.env` deny globs — they'd re-block templates. — 2026-06-11
