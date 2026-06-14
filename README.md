# mpv-photo-frame

A Linux digital picture frame that plays your photo and video library as a fullscreen slideshow using [mpv](https://mpv.io/). Features smooth fade-to-black transitions and an on-screen date/filename overlay.

## Features

- Plays JPEG, PNG, HEIC, AVIF, GIF, BMP, WebP, MP4, MOV, AVI, MKV, M4V, 3GP
- Automatically converts TIFF files to JPEG (workaround for an FFmpeg YCbCr decoding bug with JPEG-in-TIFF)
- Parallel TIFF conversion with incremental caching — only re-converts changed files
- Fade-to-black transitions between items (crossfade.lua, OSD-based — works for both images and videos)
- On-screen overlay showing the photo date (from EXIF) and filename (photo-info.lua)
- Configurable via `slideshow.conf` (app-wide settings) and per-slideshow `slideshows/<name>.conf` files — no private paths in the repository
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
#    service, and creates slideshow.conf from the template on first run.
bash install.sh

# 3. Create a slideshow (sources live here, one per source folder)
cp slideshows/example.conf slideshows/home.conf
$EDITOR slideshows/home.conf      # set SLIDESHOW_SOURCES to your photo folder(s)
# (Optional) edit slideshow.conf for app-wide settings, then: bash install.sh

# 4. Build the playlist(s) (converts TIFFs, ~few minutes on first run)
./generate-slideshow-playlist.sh        # builds every slideshow (--all)

# 5. Start the slideshow
./slideshow.sh                          # one slideshow plays; several → chooser
```

## Configuration

`slideshow.conf` holds **app-wide settings** (install.sh creates it from `slideshow.conf.example` on first run). `SLIDESHOW_SOURCES` lives in each slideshow's own file — see [Slideshows](#slideshows) below.

| Variable                  | Default                         | Description                                                |
| ------------------------- | ------------------------------- | ---------------------------------------------------------- |
| `SLIDESHOW_DELAY`         | `10`                            | Seconds to display each image                              |
| `SLIDESHOW_TIFF_CACHE`    | `~/.cache/slideshow-tiff-cache` | Where to store converted TIFF→JPEG files                   |
| `SLIDESHOW_AFTER_SERVICE` | _(empty)_                       | systemd service to wait for before generating the playlist |

Example `slideshow.conf` (settings only):

```bash
# slideshow.conf  (app-wide settings; inherited by every slideshow)
SLIDESHOW_DELAY=12
SLIDESHOW_OVERLAY_SIZE=large
```

Example `slideshows/home.conf` (one slideshow; this is where sources live):

```bash
# slideshows/home.conf  (one slideshow; this is where sources live)
SLIDESHOW_SOURCES="
  /mnt/nas/Photos   | Unsorted,To edit
  /mnt/nas/Family   | 2019/Unedited
  /mnt/nas/Archive  | */RAW,*/Thumbnails
  /mnt/nas/PhoneBackup
"
```

## mpv Scripts

| Script           | Description                                                                                                                   |
| ---------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| `crossfade.lua`  | Fades each item in from and out to black. Adjust `FADE` at the top for speed.                                                 |
| `photo-info.lua` | Displays a date/filename overlay. Font, size, colour, position and language are configurable in `slideshow.conf` (see below). |

Installed to `~/.config/mpv/scripts/` by `install.sh`.

### Customising the overlay (photo-info.lua)

Overlay options are set in `slideshow.conf` (alongside the other settings) and applied at
launch — no need to edit the Lua script or a separate file. Each option is
optional; anything you omit uses a sensible built-in default.

| `slideshow.conf` variable    | Default                | Values                                                    |
| ---------------------------- | ---------------------- | --------------------------------------------------------- |
| `SLIDESHOW_OVERLAY_FONT`     | `DejaVu Sans`          | any installed font name                                   |
| `SLIDESHOW_OVERLAY_SIZE`     | `medium`               | `small` / `medium` / `large` / `xlarge`                   |
| `SLIDESHOW_OVERLAY_COLOR`    | `FFFFFF`               | hex `RRGGBB`, no leading `#` (text fill)                  |
| `SLIDESHOW_OVERLAY_OUTLINE`  | `000000`               | hex `RRGGBB`, no leading `#` (text outline)               |
| `SLIDESHOW_OVERLAY_POSITION` | `bottom-left`          | `bottom-left` / `bottom-right` / `top-left` / `top-right` |
| `SLIDESHOW_OVERLAY_LANG`     | system language → `en` | `en` / `de` / `fr` / `es` (or `auto` / unset = system)    |
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

## Slideshows

Each slideshow is a file in `slideshows/<name>.conf`. All slideshows are equal —
there is no default. Define one by creating a file there and setting at least its
`SLIDESHOW_SOURCES`:

```bash
# slideshows/urlaub.conf
SLIDESHOW_SOURCES="
  /home/you/Pictures/Holidays | private,raw
"
SLIDESHOW_DELAY=6
```

Then play it, or list what's defined:

```bash
./slideshow.sh urlaub      # play the "urlaub" slideshow
./slideshow.sh --list      # list available slideshows
./slideshow.sh             # 0 slideshows → prompt to create one
                           # 1 slideshow  → plays it automatically
                           # 2+ slideshows → interactive numbered chooser (TTY)
                           #               or list + exit (non-interactive)
```

Resolution is layered, last wins: built-in default → `slideshow.conf` (app-wide
settings) → `slideshows/<name>.conf`. Any setting a slideshow omits falls back to
`slideshow.conf`, then to the built-in default, so nothing is ever unset.

Each slideshow has its **own** playlist cache
(`~/.cache/slideshow-playlist-<name>.m3u`). The TIFF→JPEG cache is shared across
all slideshows, so files converted for one are reused by others at no extra cost.
The login service pre-warms **all** slideshows (`--all`) so every playlist is
ready before first launch.

Want a desktop icon per slideshow? Create a `.desktop` launcher with
`Exec=…/slideshow.sh <name>` — desktop icons are intentionally not part of this
project.

## Regenerating the Playlist

Each slideshow's playlist is cached as `~/.cache/slideshow-playlist-<name>.m3u`. Delete the cache(s) and re-run `generate-slideshow-playlist.sh` whenever you add new photos.

```bash
rm -f ~/.cache/slideshow-playlist-*.m3u
./generate-slideshow-playlist.sh          # rebuild all
./generate-slideshow-playlist.sh home     # or just one
```

## Cloud Storage (rclone, sshfs, SMB, …)

If your photos live on a cloud service or NAS, mount the storage as a local directory first and point `SLIDESHOW_SOURCES` at the mount point. The key requirement is that the mount must be ready before `generate-slideshow-playlist.sh` runs — a systemd `After=` dependency handles this automatically.

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
   # slideshow.conf  (app-wide settings)
   SLIDESHOW_AFTER_SERVICE="rclone-onedrive.service"
   ```

   ```bash
   # slideshows/onedrive.conf  (the slideshow pointing at the mount)
   SLIDESHOW_SOURCES="${HOME}/Photos"
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
