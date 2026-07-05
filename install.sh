#!/usr/bin/env bash
# mpv-photo-frame installer
# Copies mpv Lua scripts, installs the systemd user service, and scaffolds slideshow.conf.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MPV_SCRIPTS="${HOME}/.config/mpv/scripts"
SYSTEMD_USER_DIR="${HOME}/.config/systemd/user"

# Dependency check
missing=()
for cmd in mpv ffprobe convert shuf xargs md5sum; do
  command -v "$cmd" &>/dev/null || missing+=("$cmd")
done
if [[ ${#missing[@]} -gt 0 ]]; then
  echo "Missing dependencies: ${missing[*]}"
  echo "Install with:  sudo apt install mpv ffmpeg imagemagick"
  exit 1
fi
echo "Dependencies OK."

# Migrate an old-layout install (default slideshow in slideshow.conf + profiles/).
# shellcheck source=scripts/migrate-config.sh
source "$SCRIPT_DIR/scripts/migrate-config.sh"
migrate_config "$SCRIPT_DIR"

# Install mpv Lua scripts
mkdir -p "$MPV_SCRIPTS"
for lua in "$SCRIPT_DIR/mpv-scripts/"*.lua; do
  dest="$MPV_SCRIPTS/$(basename "$lua")"
  cp "$lua" "$dest"
  echo "Installed: $dest"
done

# Make shell scripts executable
chmod +x "$SCRIPT_DIR/slideshow.sh" "$SCRIPT_DIR/generate-slideshow-playlist.sh"

# Set up slideshow.conf (app-wide settings; sources live in slideshows/<name>.conf)
if [[ ! -f "$SCRIPT_DIR/slideshow.conf" ]]; then
  cp "$SCRIPT_DIR/slideshow.conf.example" "$SCRIPT_DIR/slideshow.conf"
  echo ""
  echo "Created slideshow.conf (settings) from slideshow.conf.example."
  echo ">>> Create a slideshow: copy slideshows/example.conf to slideshows/<name>.conf"
  echo "    and set its SLIDESHOW_SOURCES. <<<"
  echo ""
else
  echo "slideshow.conf already exists — skipping."
fi

# Load slideshow.conf so SLIDESHOW_AFTER_SERVICE is available for the service unit
# shellcheck source=/dev/null
[[ -f "$SCRIPT_DIR/slideshow.conf" ]] && source "$SCRIPT_DIR/slideshow.conf"

if [[ "${SLIDESHOW_BLURRED_BACKGROUND:-}" =~ ^(yes|photos-only)$ ]] && ! command -v exiftool &>/dev/null; then
  echo "Warning: SLIDESHOW_BLURRED_BACKGROUND=yes requires exiftool, which is not installed."
  echo "  Install with:  sudo apt install libimage-exiftool-perl"
fi

# Install systemd user service
mkdir -p "$SYSTEMD_USER_DIR"
SERVICE_FILE="$SYSTEMD_USER_DIR/slideshow-playlist.service"

{
  echo "[Unit]"
  echo "Description=Pre-generate slideshow playlist"
  [[ -n "${SLIDESHOW_AFTER_SERVICE:-}" ]] && echo "After=${SLIDESHOW_AFTER_SERVICE}"
  echo ""
  echo "[Service]"
  echo "Type=oneshot"
  echo "ExecStart=$SCRIPT_DIR/generate-slideshow-playlist.sh --all"
  echo ""
  echo "[Install]"
  echo "WantedBy=default.target"
} >"$SERVICE_FILE"

systemctl --user daemon-reload
echo "Installed: $SERVICE_FILE"

echo ""
echo "Done. Next steps:"
echo "  1. Create a slideshow: cp slideshows/example.conf slideshows/<name>.conf, set SLIDESHOW_SOURCES"
echo "  2. (Optional) edit slideshow.conf for app-wide settings / SLIDESHOW_AFTER_SERVICE, then re-run install.sh"
echo "  3. systemctl --user enable --now slideshow-playlist.service"
echo "  4. ./slideshow.sh            (no name = auto-pick / chooser; or ./slideshow.sh <name>)"
