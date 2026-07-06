# Changelog

## [1.0.0] - 2026-07-06

### Added
- ✨ publish GitHub Releases from pushed version tags
- ✨ add /release skill
- ✨ add CLI dispatcher to cut-release.sh
- ✨ add changelog section formatting for the release workflow
- ✨ add next-version arithmetic for the release workflow
- ✨ add bump-type detection for the release workflow
- ✨ add photos-only mode for blurred-background on weak hardware
- ✨ login service pre-warms all slideshows (--all)
- ✨ idempotent auto-migration to settings+slideshows layout
- ✨ --all mode pre-warms every slideshow's playlist
- ✨ three-layer slideshow selection in slideshow.sh
- ✨ guard slideshow.sh on SLIDESHOW_SOURCES
- ✨ scan all SLIDESHOW_SOURCES roots when building the playlist
- ✨ parse SLIDESHOW_SOURCES into multi-root find inputs
- ✨ forward overlay options from .env to mpv
- ✨ make overlay color, position and language configurable
- ✨ deploy a runnable copy to a runtime directory
- ✨ add example compilation template and ignore real profiles
- ✨ select a compilation and build its playlist lazily
- ✨ select a compilation in playlist generation
- ✨ add shared profile/config resolution lib
- ✨ make overlay text size configurable via size presets
- ✨ make overlay font configurable via script-opts
- ✨ add systemd playlist service with cloud-mount dependency
- ✨ initial public release of mpv-photo-frame

### Fixed
- 🐛 strip git-log's leading separator newline in commit parsing
- 🐛 blurred-background: eliminate rotation race, fix hwdec format error
- 🐛 correct self-deploy guidance and document the deploy install model

### Changed
- 🔧 settings+slideshows resolution (names/list/load/choose)
- 🔧 slideshow.conf.example is settings-only (no sources)
- 🔧 rename profiles/ → slideshows/ with equal-slideshow wording
- 🔧 rename .env → slideshow.conf throughout
- ♻️ make install.sh a one-time in-place installer again

### Docs
- 📝 document how to check for and apply updates
- 📝 fill in CLAUDE.md description for release.yml
- 📝 fill in CLAUDE.md description for the /release skill
- 📝 fix stale exiftool requirement wording for photos-only mode
- 📝 address review notes (correct generator error msg, restore SLIDESHOW_PLAYLIST warning)
- 📝 document settings + flat slideshows model
- 📄 document sub-sub-folder and glob excludes in SLIDESHOW_SOURCES
- 📄 document SLIDESHOW_SOURCES, drop SLIDESHOW_BASE/EXCLUDE
- 📄 document overlay variables in .env.example
- 📄 clarify overlay LANG auto + hex colour format
- 📄 document overlay configuration via .env
- 📄 document compilations in .env.example
- 📄 document slideshow compilations
- 📄 link license section to LICENSE file
- 📄 add MIT license file
