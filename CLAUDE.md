# mpv-photo-frame

Linux digital picture frame: plays a photo/video library as a fullscreen mpv slideshow with fade transitions and an EXIF date/filename overlay. Bash orchestration scripts + Lua mpv scripts. Configured via a gitignored `slideshow.conf` (see `slideshow.conf.example`).

## Key Config Files

| File | Purpose |
|------|---------|
| `.claude/settings.json` | Permissions and environment variables                                       |
| `.claude/skills/release/SKILL.md` | Cuts a new release: bumps version, updates changelog, tags, and pushes      |
| `.github/workflows/claude-code-review.yml` | Auto-reviews every pull request                                             |
| `.github/workflows/claude.yml` | Runs Claude on `@claude` mentions in issues/PRs                             |
| `.github/workflows/release.yml` | Publishes GitHub Releases from pushed version tags                          |
| `.gitignore` | Git ignore patterns                                                         |

## Commands

```bash
bash install.sh                       # copy Lua scripts to ~/.config/mpv/scripts/
./generate-slideshow-playlist.sh      # convert TIFFs + build shuffled playlist
./slideshow.sh                        # start the fullscreen slideshow
```

No build step. Verify loop (install with `apt install shellcheck` / `go install mvdan.cc/sh/v3/cmd/shfmt@latest` / `luarocks install luacheck`):

```bash
shellcheck *.sh tests/*.sh            # lint Bash scripts (incl. tests/)
shfmt -i 2 -d .                       # check Bash formatting (2-space indent)
luacheck mpv-scripts/                 # lint Lua mpv scripts
for f in tests/*.test.sh; do bash "$f"; done   # run all unit tests
```

## Structure

- `*.sh` — Bash entrypoints (install, playlist generation, slideshow launch)
- `mpv-scripts/` — Lua mpv scripts: `crossfade.lua` (fade transitions), `photo-info.lua` (overlay), `blurred-background.lua` (letterbox/pillarbox fill)
- `slideshows/<name>.conf` — one file per slideshow (sources + per-slideshow overrides); every slideshow is equal, there's no default
- `systemd/` — user service for playlist pre-generation on login
- `slideshow.conf.example` — documented config template (app-wide settings); real `slideshow.conf` is gitignored

Local git config (not tracked, set once per clone): `git config core.hooksPath .githooks` — wires up `scripts/sync-config-table.sh`, which keeps the Key Config Files table above in sync on commit.

## Conventions

- All runtime config comes from `slideshow.conf` — never hardcode paths; add new options to `slideshow.conf.example` with a default and a doc-table row in `README.md`.
- Lua overlay options are exposed via mpv `script-opts` so users override without editing scripts.
- Keep scripts POSIX-friendly Bash with `set`-guarded variable expansion (`: "${VAR:?...}"`).

## Don't

- Don't commit secrets or credentials to git — `slideshow.conf` stays untracked.
- Don't use `--force` flags — fix the underlying issue instead.
- Don't put private/absolute photo paths in committed files.

## Learnings

When the user corrects a mistake or points out a recurring issue, append a one-line summary to `.claude/learnings.md`. Don't modify CLAUDE.md directly.

## Compact Instructions

When compacting, preserve: list of modified files, current test/lint status, open TODOs, and key decisions made.
