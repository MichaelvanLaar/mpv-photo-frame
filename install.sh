#!/usr/bin/env bash
# mpv-photo-frame installer / deployer.
# Run this from the repo. It deploys a runnable copy to the runtime directory,
# installs the mpv Lua scripts, scaffolds runtime config, and installs the
# systemd user service that pre-generates the default playlist.
#
# Runtime directory (where the frame actually runs) is chosen as:
#   $SLIDESHOW_INSTALL_DIR  >  first argument  >  ~/Slideshow

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNTIME_DIR="${SLIDESHOW_INSTALL_DIR:-${1:-$HOME/Slideshow}}"
RUNTIME_DIR="$(realpath -m "$RUNTIME_DIR")"

# Refuse to deploy onto the repo itself (would cp files onto themselves and
# abort under set -e). Run from the repo and deploy to a separate runtime dir.
if [[ "$SCRIPT_DIR" == "$RUNTIME_DIR" ]]; then
  echo "Error: runtime dir equals the repo dir ($RUNTIME_DIR)." >&2
  echo "Run install.sh from the repo and deploy elsewhere, e.g.:" >&2
  echo "  SLIDESHOW_INSTALL_DIR=\"\$HOME/Slideshow\" ./install.sh" >&2
  exit 1
fi
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

# Deploy a runnable copy to the runtime directory (excluding the installer)
mkdir -p "$RUNTIME_DIR" "$RUNTIME_DIR/profiles"
for sh in "$SCRIPT_DIR"/*.sh; do
  base="$(basename "$sh")"
  [[ "$base" == "install.sh" ]] && continue
  cp "$sh" "$RUNTIME_DIR/$base"
done
cp -r "$SCRIPT_DIR/mpv-scripts" "$RUNTIME_DIR/"
chmod +x "$RUNTIME_DIR"/*.sh
echo "Deployed scripts to: $RUNTIME_DIR"

# Seed the example compilation (never overwrite existing files)
if [[ -f "$SCRIPT_DIR/profiles/example.env" && ! -f "$RUNTIME_DIR/profiles/example.env" ]]; then
  cp "$SCRIPT_DIR/profiles/example.env" "$RUNTIME_DIR/profiles/example.env"
  echo "Seeded: $RUNTIME_DIR/profiles/example.env"
fi

# Install mpv Lua scripts
mkdir -p "$MPV_SCRIPTS"
for lua in "$SCRIPT_DIR/mpv-scripts/"*.lua; do
  dest="$MPV_SCRIPTS/$(basename "$lua")"
  cp "$lua" "$dest"
  echo "Installed: $dest"
done

# Scaffold runtime .env (never overwrite)
if [[ ! -f "$RUNTIME_DIR/.env" ]]; then
  cp "$SCRIPT_DIR/.env.example" "$RUNTIME_DIR/.env"
  echo ""
  echo "Created $RUNTIME_DIR/.env from .env.example."
  echo ">>> Edit $RUNTIME_DIR/.env and set SLIDESHOW_BASE to your photo directory. <<<"
  echo ""
else
  echo "$RUNTIME_DIR/.env already exists — skipping."
fi

# Load runtime .env so SLIDESHOW_AFTER_SERVICE is available for the service unit
# shellcheck source=/dev/null
[[ -f "$RUNTIME_DIR/.env" ]] && source "$RUNTIME_DIR/.env"

# Install systemd user service (points at the deployed runtime copy)
mkdir -p "$SYSTEMD_USER_DIR"
SERVICE_FILE="$SYSTEMD_USER_DIR/slideshow-playlist.service"
{
  echo "[Unit]"
  echo "Description=Pre-generate slideshow playlist"
  [[ -n "${SLIDESHOW_AFTER_SERVICE:-}" ]] && echo "After=${SLIDESHOW_AFTER_SERVICE}"
  echo ""
  echo "[Service]"
  echo "Type=oneshot"
  echo "ExecStart=$RUNTIME_DIR/generate-slideshow-playlist.sh"
  echo ""
  echo "[Install]"
  echo "WantedBy=default.target"
} >"$SERVICE_FILE"
systemctl --user daemon-reload
echo "Installed: $SERVICE_FILE"

echo ""
echo "Done. Runtime: $RUNTIME_DIR"
echo "Next steps:"
echo "  1. Edit $RUNTIME_DIR/.env (SLIDESHOW_BASE, optionally SLIDESHOW_AFTER_SERVICE)"
echo "  2. Add compilations in $RUNTIME_DIR/profiles/<name>.env (see example.env)"
echo "  3. Re-run install.sh after editing .env to rebuild the service unit"
echo "  4. systemctl --user enable --now slideshow-playlist.service"
echo "  5. $RUNTIME_DIR/slideshow.sh        (or: $RUNTIME_DIR/slideshow.sh <name>)"
