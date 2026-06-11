# Learnings

Corrections and observations collected during configuration sessions.
Entries are tagged by skill and dated.

---

[cc-config:cc-config-init] A global prettier PostToolUse hook reformats Markdown on every Write/Edit; it column-aligns the Key Config Files table, which the pre-commit sync script then compacts — expect minor cosmetic churn between the two formats. — 2026-06-08
[cc-config:cc-config-optimize] The `Read(./.env.*)` and `Read(./profiles/*.env)` deny globs also match the public templates `.env.example` / `profiles/example.env`, so editing those templates is blocked and needs a Bash heredoc write (approve the command). Kept intentionally to protect real `.env.*` / private profiles — don't propose narrowing them again. — 2026-06-11
