# mpv-photo-frame

A Linux digital picture frame that plays your photo and video library as a fullscreen slideshow using [mpv](https://mpv.io/). Features smooth fade-to-black transitions and an on-screen date/filename overlay.

## Features

- Plays JPEG, PNG, HEIC, AVIF, GIF, BMP, WebP, MP4, MOV, AVI, MKV, M4V, 3GP
- Automatically converts TIFF files to JPEG (workaround for an FFmpeg YCbCr decoding bug with JPEG-in-TIFF)
- Parallel TIFF conversion with incremental caching — only re-converts changed files
- Fade-to-black transitions between items (crossfade.lua, OSD-based — works for both images and videos)
- On-screen overlay showing the photo date (from EXIF) and filename (photo-info.lua)
- Configurable via a simple `.env` file — no private paths in the repository

## Requirements

- mpv
- ffmpeg (provides `ffprobe`)
- ImageMagick (provides `convert`)

```bash
sudo apt install mpv ffmpeg imagemagick
```

## Quick Start

```bash
# 1. Clone
git clone https://github.com/michaelvanlaar/mpv-photo-frame.git
cd mpv-photo-frame

# 2. Install (copies Lua scripts to ~/.config/mpv/scripts/)
bash install.sh

# 3. Configure
cp .env.example .env
$EDITOR .env          # set SLIDESHOW_BASE to your photo folder

# 4. Build the playlist (converts TIFFs, ~few minutes on first run)
./generate-slideshow-playlist.sh

# 5. Start the slideshow
./slideshow.sh
```

## Configuration

Copy `.env.example` to `.env` and edit:

| Variable               | Default                           | Description                                |
| ---------------------- | --------------------------------- | ------------------------------------------ |
| `SLIDESHOW_BASE`       | _(required)_                      | Absolute path to your photo/video library  |
| `SLIDESHOW_DELAY`      | `10`                              | Seconds to display each image              |
| `SLIDESHOW_EXCLUDE`    | _(empty)_                         | Comma-separated subdirectory names to skip |
| `SLIDESHOW_TIFF_CACHE` | `~/.cache/slideshow-tiff-cache`   | Where to store converted TIFF→JPEG files   |
| `SLIDESHOW_PLAYLIST`   | `~/.cache/slideshow-playlist.m3u` | Where to store the generated playlist      |

Example `.env`:

```bash
SLIDESHOW_BASE="/mnt/nas/Photos"
SLIDESHOW_DELAY=12
SLIDESHOW_EXCLUDE="Unsorted,To edit"
```

## mpv Scripts

| Script           | Description                                                                          |
| ---------------- | ------------------------------------------------------------------------------------ |
| `crossfade.lua`  | Fades each item in from and out to black. Adjust `FADE` at the top for speed.        |
| `photo-info.lua` | Displays date and filename overlay (bottom-left). Adjust `MONTHS` for your language. |

Installed to `~/.config/mpv/scripts/` by `install.sh`.

## Regenerating the Playlist

The playlist is cached in `~/.cache/slideshow-playlist.m3u`. Delete it and re-run `generate-slideshow-playlist.sh` whenever you add new photos.

```bash
rm ~/.cache/slideshow-playlist.m3u
./generate-slideshow-playlist.sh
```

## Why TIFF conversion?

FFmpeg has a longstanding bug that decodes JPEG-in-TIFF files with incorrect YCbCr color space, producing green frames in mpv. `generate-slideshow-playlist.sh` pre-converts all TIFFs to standard JPEG using ImageMagick and substitutes the cached copies in the playlist. The originals are never modified.

## License

MIT
