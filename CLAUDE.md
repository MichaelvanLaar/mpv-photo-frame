# mpv-photo-frame

Linux digital picture frame: plays a photo/video library as a fullscreen mpv slideshow with fade transitions and an EXIF date/filename overlay. Bash orchestration scripts + Lua mpv scripts. Configured via a gitignored `.env` (see `.env.example`).

## Key Config Files

| File | Purpose |
|------|---------|
| `.claude/learnings.md` | Project corrections/observations, auto-recalled next run                                |
| `.claude/settings.json` | Permissions and environment variables                                                   |
| `.github/workflows/claude-code-review.yml` | Auto-reviews every pull request                                                         |
| `.github/workflows/claude.yml` | Runs Claude on `@claude` mentions in issues/PRs                                         |
| `.gitignore` | Git ignore patterns                                                                     |

## Commands

```bash
bash install.sh                       # copy Lua scripts to ~/.config/mpv/scripts/
./generate-slideshow-playlist.sh      # convert TIFFs + build shuffled playlist
./slideshow.sh                        # start the fullscreen slideshow
```

No test/build step. Verify loop (install with `apt install shellcheck` / `go install mvdan.cc/sh/v3/cmd/shfmt@latest` / `luarocks install luacheck`):

```bash
shellcheck *.sh                       # lint Bash scripts
shfmt -d .                            # check Bash formatting (2-space indent)
luacheck mpv-scripts/                 # lint Lua mpv scripts
```

## Structure

- `*.sh` — Bash entrypoints (install, playlist generation, slideshow launch)
- `mpv-scripts/` — Lua mpv scripts: `crossfade.lua` (fade transitions), `photo-info.lua` (overlay)
- `systemd/` — user service for playlist pre-generation on login
- `.env.example` — documented config template; real `.env` is gitignored

## Conventions

- All runtime config comes from `.env` — never hardcode paths; add new options to `.env.example` with a default and a doc-table row in `README.md`.
- Lua overlay options are exposed via mpv `script-opts` so users override without editing scripts.
- Keep scripts POSIX-friendly Bash with `set`-guarded variable expansion (`: "${VAR:?...}"`).

## Don't

- Don't commit secrets or credentials to git — `.env` stays untracked.
- Don't use `--force` flags — fix the underlying issue instead.
- Don't put private/absolute photo paths in committed files.

## Learnings

When the user corrects a mistake or points out a recurring issue, append a one-line summary to `.claude/learnings.md`. Don't modify CLAUDE.md directly.

## Compact Instructions

When compacting, preserve: list of modified files, current test/lint status, open TODOs, and key decisions made.
