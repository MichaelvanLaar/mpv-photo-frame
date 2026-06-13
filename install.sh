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

# Install mpv Lua scripts
mkdir -p "$MPV_SCRIPTS"
for lua in "$SCRIPT_DIR/mpv-scripts/"*.lua; do
  dest="$MPV_SCRIPTS/$(basename "$lua")"
  cp "$lua" "$dest"
  echo "Installed: $dest"
done

# Make shell scripts executable
chmod +x "$SCRIPT_DIR/slideshow.sh" "$SCRIPT_DIR/generate-slideshow-playlist.sh"

# Set up slideshow.conf
if [[ ! -f "$SCRIPT_DIR/slideshow.conf" ]]; then
  cp "$SCRIPT_DIR/slideshow.conf.example" "$SCRIPT_DIR/slideshow.conf"
  echo ""
  echo "Created slideshow.conf from slideshow.conf.example."
  echo ">>> Edit $SCRIPT_DIR/slideshow.conf and set SLIDESHOW_SOURCES to your photo folder(s). <<<"
  echo ""
else
  echo "slideshow.conf already exists — skipping."
fi

# Load slideshow.conf so SLIDESHOW_AFTER_SERVICE is available for the service unit
# shellcheck source=/dev/null
[[ -f "$SCRIPT_DIR/slideshow.conf" ]] && source "$SCRIPT_DIR/slideshow.conf"

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
  echo "ExecStart=$SCRIPT_DIR/generate-slideshow-playlist.sh"
  echo ""
  echo "[Install]"
  echo "WantedBy=default.target"
} > "$SERVICE_FILE"

systemctl --user daemon-reload
echo "Installed: $SERVICE_FILE"

echo ""
echo "Done. Next steps:"
echo "  1. Edit slideshow.conf (set SLIDESHOW_SOURCES and optionally SLIDESHOW_AFTER_SERVICE)"
echo "  2. Re-run install.sh after editing slideshow.conf to rebuild the service unit"
echo "  3. systemctl --user enable --now slideshow-playlist.service"
echo "  4. ./slideshow.sh        (or: ./slideshow.sh <name> for a compilation — see profiles/example.conf)"
