#!/usr/bin/env bash
# mpv-photo-frame installer
# Copies mpv Lua scripts, scaffolds .env, and checks dependencies.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MPV_SCRIPTS="${HOME}/.config/mpv/scripts"

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

# Set up .env
if [[ ! -f "$SCRIPT_DIR/.env" ]]; then
  cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
  echo ""
  echo "Created .env from .env.example."
  echo ">>> Edit $SCRIPT_DIR/.env and set SLIDESHOW_BASE to your photo directory. <<<"
else
  echo ".env already exists — skipping."
fi

echo ""
echo "Done. Next steps:"
echo "  1. Edit .env (set SLIDESHOW_BASE)"
echo "  2. ./generate-slideshow-playlist.sh   # first run: converts TIFFs and builds playlist"
echo "  3. ./slideshow.sh                     # start the slideshow"
