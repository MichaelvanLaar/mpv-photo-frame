# mpv-photo-frame

A Linux digital picture frame that plays your photo and video library as a fullscreen slideshow using [mpv](https://mpv.io/). Features smooth fade-to-black transitions and an on-screen date/filename overlay.

## Features

- Plays JPEG, PNG, HEIC, AVIF, GIF, BMP, WebP, MP4, MOV, AVI, MKV, M4V, 3GP
- Automatically converts TIFF files to JPEG (workaround for an FFmpeg YCbCr decoding bug with JPEG-in-TIFF)
- Parallel TIFF conversion with incremental caching — only re-converts changed files
- Fade-to-black transitions between items (crossfade.lua, OSD-based — works for both images and videos)
- On-screen overlay showing the photo date (from EXIF) and filename (photo-info.lua)
- Configurable via a simple `.env` file — no private paths in the repository
- systemd user service for playlist pre-generation on login, with optional dependency on a cloud-mount service

## Requirements

- mpv
- ffmpeg (provides `ffprobe`)
- ImageMagick (provides `convert`)

```bash
sudo apt install mpv ffmpeg imagemagick
```

## Quick Start

```bash
# 1. Clone (this folder becomes your installation — keep it where you like)
git clone https://github.com/michaelvanlaar/mpv-photo-frame.git
cd mpv-photo-frame

# 2. Install: copies the mpv Lua scripts, installs the systemd pre-gen
#    service, and creates .env from the template on first run.
bash install.sh

# 3. Configure (install.sh created .env from the template)
$EDITOR .env          # set SLIDESHOW_BASE to your photo folder
bash install.sh       # re-run if you changed SLIDESHOW_AFTER_SERVICE

# 4. Build the playlist (converts TIFFs, ~few minutes on first run)
./generate-slideshow-playlist.sh

# 5. Start the slideshow
./slideshow.sh
```

## Configuration

Edit `.env` (install.sh creates it from `.env.example` on first run):

| Variable                  | Default                           | Description                                                |
| ------------------------- | --------------------------------- | ---------------------------------------------------------- |
| `SLIDESHOW_BASE`          | _(required)_                      | Absolute path to your photo/video library                  |
| `SLIDESHOW_DELAY`         | `10`                              | Seconds to display each image                              |
| `SLIDESHOW_EXCLUDE`       | _(empty)_                         | Comma-separated subdirectory names to skip                 |
| `SLIDESHOW_TIFF_CACHE`    | `~/.cache/slideshow-tiff-cache`   | Where to store converted TIFF→JPEG files                   |
| `SLIDESHOW_PLAYLIST`      | `~/.cache/slideshow-playlist.m3u` | Where to store the generated playlist                      |
| `SLIDESHOW_AFTER_SERVICE` | _(empty)_                         | systemd service to wait for before generating the playlist |

Example `.env`:

```bash
SLIDESHOW_BASE="/mnt/nas/Photos"
SLIDESHOW_DELAY=12
SLIDESHOW_EXCLUDE="Unsorted,To edit"
```

## mpv Scripts

| Script           | Description                                                                                                         |
| ---------------- | ------------------------------------------------------------------------------------------------------------------- |
| `crossfade.lua`  | Fades each item in from and out to black. Adjust `FADE` at the top for speed.                                       |
| `photo-info.lua` | Displays a date/filename overlay. Font, size, colour, position and language are configurable in `.env` (see below). |

Installed to `~/.config/mpv/scripts/` by `install.sh`.

### Customising the overlay (photo-info.lua)

Overlay options are set in `.env` (alongside the other settings) and applied at
launch — no need to edit the Lua script or a separate file. Each option is
optional; anything you omit uses a sensible built-in default.

| `.env` variable              | Default                | Values                                                    |
| ---------------------------- | ---------------------- | --------------------------------------------------------- |
| `SLIDESHOW_OVERLAY_FONT`     | `DejaVu Sans`          | any installed font name                                   |
| `SLIDESHOW_OVERLAY_SIZE`     | `medium`               | `small` / `medium` / `large` / `xlarge`                   |
| `SLIDESHOW_OVERLAY_COLOR`    | `FFFFFF`               | hex `RRGGBB` (text fill)                                  |
| `SLIDESHOW_OVERLAY_OUTLINE`  | `000000`               | hex `RRGGBB` (text outline)                               |
| `SLIDESHOW_OVERLAY_POSITION` | `bottom-left`          | `bottom-left` / `bottom-right` / `top-left` / `top-right` |
| `SLIDESHOW_OVERLAY_LANG`     | system language → `en` | `en` / `de` / `fr` / `es`                                 |
| `SLIDESHOW_OVERLAY_CLOCK`    | language default       | `12` / `24`                                               |

The language sets month names and the date/time format (e.g. `de`:
“14. März 2024 / 14:30 Uhr”, `en`: “March 14, 2024 / 2:30 PM”). With nothing set,
the overlay uses your system language, falling back to English.

`SLIDESHOW_OVERLAY_SIZE` scales the overlay text relative to the screen height
(no pixel values needed):

| Value    | Scale | Notes                          |
| -------- | ----- | ------------------------------ |
| `small`  | 0.75× |                                |
| `medium` | 1.0×  | Default — unchanged appearance |
| `large`  | 1.4×  |                                |
| `xlarge` | 1.8×  |                                |

The date and time lines scale together, keeping their relative proportions. An unknown value falls back to `medium`.

## Compilations (multiple slideshows)

A _compilation_ is a named slideshow: a base folder plus optional excluded
subfolders, plus any other settings you want to override. Define one by creating
`profiles/<name>.env` (next to `install.sh`) and setting at least its
`SLIDESHOW_BASE`:

```bash
# profiles/urlaub.env
SLIDESHOW_BASE="/home/you/Pictures/Holidays"
SLIDESHOW_EXCLUDE="private,raw"
SLIDESHOW_DELAY=6
```

Then play it, or list what's defined:

```bash
./slideshow.sh urlaub      # play the "urlaub" compilation
./slideshow.sh --list      # list available compilations
./slideshow.sh             # default: the shared .env (unchanged behaviour)
```

Resolution is layered, last wins: built-in default → `.env` (shared) →
`profiles/<name>.env`. Any setting a compilation omits falls back to `.env`,
then to the built-in default, so nothing is ever unset.

Each compilation gets its **own** playlist cache
(`~/.cache/slideshow-playlist-<name>.m3u`); the no-argument default keeps
`~/.cache/slideshow-playlist.m3u`. (Setting a global `SLIDESHOW_PLAYLIST` in the shared `.env` overrides this and forces all compilations onto one cache — set it only inside a single `profiles/<name>.env` if you need a custom path.) The TIFF→JPEG cache is shared across all
compilations, so files converted for one are reused by others at no extra cost.
The login service pre-builds only the default; other compilations build their
cache on first launch and reuse it thereafter.

Want a desktop icon per compilation? Create a `.desktop` launcher with
`Exec=…/slideshow.sh <name>` — desktop icons are intentionally not part of this
project.

## Regenerating the Playlist

The playlist is cached in `~/.cache/slideshow-playlist.m3u`. Delete it and re-run `generate-slideshow-playlist.sh` whenever you add new photos.

```bash
rm ~/.cache/slideshow-playlist.m3u
./generate-slideshow-playlist.sh
```

## Cloud Storage (rclone, sshfs, SMB, …)

If your photos live on a cloud service or NAS, mount the storage as a local directory first and point `SLIDESHOW_BASE` at the mount point. The key requirement is that the mount must be ready before `generate-slideshow-playlist.sh` runs — a systemd `After=` dependency handles this automatically.

**Example with rclone and OneDrive:**

1. Create a rclone remote (run once interactively):

   ```bash
   rclone config
   ```

2. Create a systemd user service that mounts the remote:

   ```bash
   # ~/.config/systemd/user/rclone-onedrive.service
   [Unit]
   Description=rclone mount OneDrive
   After=network-online.target
   Wants=network-online.target

   [Service]
   Type=notify
   ExecStart=rclone mount "MyRemote:" %h/Photos \
       --vfs-cache-mode=full \
       --vfs-cache-max-size=50G \
       --allow-other
   ExecStop=/bin/fusermount -u %h/Photos
   Restart=on-failure

   [Install]
   WantedBy=default.target
   ```

3. Configure mpv-photo-frame to wait for it:

   ```bash
   # .env
   SLIDESHOW_BASE="${HOME}/Photos"
   SLIDESHOW_AFTER_SERVICE="rclone-onedrive.service"
   ```

4. Re-run `install.sh` — it writes the `After=` line into the installed service unit.

5. Enable both services:
   ```bash
   systemctl --user enable --now rclone-onedrive.service
   systemctl --user enable --now slideshow-playlist.service
   ```

The same pattern works for any mount tool: replace `rclone-onedrive.service` with whatever service manages your mount.

## Why TIFF conversion?

FFmpeg has a longstanding bug that decodes JPEG-in-TIFF files with incorrect YCbCr color space, producing green frames in mpv. `generate-slideshow-playlist.sh` pre-converts all TIFFs to standard JPEG using ImageMagick and substitutes the cached copies in the playlist. The originals are never modified.

## License

[MIT](LICENSE)
