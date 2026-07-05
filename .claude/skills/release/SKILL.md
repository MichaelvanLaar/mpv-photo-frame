---
name: release
description: Cut a new mpv-photo-frame release — bumps VERSION, updates CHANGELOG.md, tags, and (after confirmation) pushes. Use when the user asks to cut/create/publish a release or new version, or runs /release.
---

# Cutting a release

This drives the whole release process for this repo: version bump, CHANGELOG.md entry, commit, tag, and — only after explicit confirmation — push. Publishing the actual GitHub Release happens in CI (`.github/workflows/release.yml`), triggered by the pushed tag; this skill's job ends at the push.

## Preconditions

Run these checks with the Bash tool. Abort with a clear message to the user if any fails — do not attempt to fix the repo state yourself.

1. Clean working tree: `git status --porcelain` must print nothing.
2. On `main`: `git rev-parse --abbrev-ref HEAD` must print `main`.
3. Up to date with `origin/main`: run `git fetch origin main --quiet`, then compare `git rev-parse HEAD` with `git rev-parse origin/main` — they must match.

## Determine the release

1. Find the last tag: `git describe --tags --abbrev=0 2>/dev/null || true` (empty output means no release has ever been cut).
2. Collect commits since that tag as NUL-terminated full messages:
   - If there was a last tag: `git log --format=%B%x00 "$last_tag"..HEAD`
   - If there was no last tag (first release): `git log --format=%B%x00`
3. Pipe that same commit stream into `bash scripts/cut-release.sh bump` to get the bump type (`major`/`minor`/`patch`/`none`).
4. If the bump type is `none`, tell the user there's nothing user-visible to release since `$last_tag` (or, if there was no tag, that the whole history has no `feat`/`fix`/`refactor`/`perf`/`docs` commit) and stop here.
5. Compute the new version: `bash scripts/cut-release.sh next-version "${last_tag#v}" "$bump_type"` (pass an empty string for `${last_tag#v}` when there was no last tag).
6. Compute today's date as `YYYY-MM-DD` (e.g. `date +%Y-%m-%d`).
7. Pipe the same commit stream again into `bash scripts/cut-release.sh changelog "$new_version" "$today"` to get the new CHANGELOG section.

## Write the changes

1. Write the new version (bare semver, single line, no trailing newline beyond the one line) to `VERSION` at the repo root, creating the file if it doesn't exist.
2. Prepend the new section to `CHANGELOG.md`:
   - If `CHANGELOG.md` doesn't exist yet, create it starting with a `# Changelog\n\n` header before the new section.
   - If it exists, insert the new section directly after the `# Changelog` header line, above all existing sections (newest first).
3. Show the user the diff (`git diff -- VERSION CHANGELOG.md`) before committing.

## Commit and tag

1. `git add VERSION CHANGELOG.md`
2. Commit: `git commit -m "chore: 🔖 release v$new_version"`
3. Create an annotated tag whose message is exactly the changelog section text: `git tag -a "v$new_version" -F -` (feed the section text on stdin), or equivalently write the section to a temp file and use `-F <file>`.

## Push — confirm first

Pushing publishes the release and triggers CI. **Stop and explicitly ask the user to confirm** ("Push v$new_version to origin now?") before running anything below. Do not push without an explicit yes.

Once confirmed:

```bash
git push origin main
git push origin "v$new_version"
```

Report the pushed tag and that `.github/workflows/release.yml` will publish the GitHub Release shortly.
