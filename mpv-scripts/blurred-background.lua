-- Fills letterbox/pillarbox bars with a stretched, blurred copy of the
-- current photo/video instead of black (like portrait video on a 16:9 TV).

local mp = require 'mp'
local utils = require 'mp.utils'

local opts = { mode = "no" } -- no | yes | photos-only
require("mp.options").read_options(opts, "blurred-background")

local blur_photos = (opts.mode == "yes" or opts.mode == "photos-only")
local blur_videos = (opts.mode == "yes")

-- Video decode is the expensive, hardware-dependent case (see the hwdec=no
-- note below); photos are always cheap and correct regardless of hardware,
-- since they're a single frame with no hwdec involved. "photos-only" lets
-- videos keep normal hardware decode and plain letterboxing on machines
-- where the CPU cost of software-decoding video isn't worth it.
local VIDEO_EXTENSIONS = {
    mp4 = true, mov = true, avi = true, mkv = true, m4v = true, ["3gp"] = true,
}

local function is_video(path)
    local ext = path and path:match("%.([%w]+)$")
    return ext ~= nil and VIDEO_EXTENSIONS[ext:lower()] == true
end

local BLUR_SIGMA = 20 -- fixed; blurring at 1/4 resolution keeps this cheap

-- Builds the lavfi filter graph: a cover-scaled + blurred background behind
-- a scale-to-fit foreground, composited to exactly fill w x h. The leading
-- format=yuv420p guards against pixel formats our filters can't otherwise
-- negotiate (see the hwdec=no note below for why this matters).
local function build_vf(w, h)
    w = math.max(1, math.floor(w))
    h = math.max(1, math.floor(h))
    local qw = math.max(1, math.floor(w / 4))
    local qh = math.max(1, math.floor(h / 4))
    return string.format(
        "lavfi=[format=yuv420p,split=2[bg][fg];" ..
        "[bg]scale=%d:%d:force_original_aspect_ratio=increase,crop=%d:%d,scale=%d:%d,gblur=sigma=%d,scale=%d:%d[bg];" ..
        "[fg]scale=%d:%d:force_original_aspect_ratio=decrease[fg];" ..
        "[bg][fg]overlay=(W-w)/2:(H-h)/2]",
        w, h, w, h, qw, qh, BLUR_SIGMA, w, h, w, h
    )
end

-- osd-width/osd-height report 0 (not nil) before mpv has a real window size,
-- so a plain "or" fallback doesn't catch it (0 is truthy in Lua).
local function osd_dim(name, default)
    local v = mp.get_property_number(name)
    if v and v > 0 then
        return v
    end
    return default
end

-- mpv doesn't know a file's rotation until decode starts (video-params/rotate
-- reads nil right up to video-reconfig) -- by which point, for a still image,
-- the single frame may already be on screen. Reacting to that property (via
-- events or observe_property) is a race that reliably loses for the first
-- file of a session and for any rotation change, since those are exactly the
-- cases that need a fresh vf. exiftool reads the same rotation from the file
-- itself before mpv ever opens it, so the on_load hook below (which blocks
-- file-opening until it returns) can set vf correctly ahead of the first
-- frame, every time.
local function detect_rotate(path)
    local res = mp.command_native({
        name = "subprocess",
        args = { "exiftool", "-j", "-n", "-Orientation", "-Rotation", path },
        capture_stdout = true,
    })
    if not res or res.status ~= 0 or not res.stdout then
        return 0
    end
    local ok, parsed = pcall(utils.parse_json, res.stdout)
    if not ok or not parsed or not parsed[1] then
        return 0
    end
    local info = parsed[1]
    if info.Rotation then
        return info.Rotation % 360
    end
    local orientation_map = { [1] = 0, [3] = 180, [6] = 90, [8] = 270 }
    return orientation_map[info.Orientation] or 0
end

if blur_photos then
    if blur_videos then
        -- Hardware-decoded frames (e.g. vaapi nv12 surfaces) live in GPU memory
        -- and can't be consumed by gblur/scale/overlay without an hwdownload
        -- step whose target format we can't know in advance (and guessing
        -- wrong permanently disables the filter for that file, unlike the
        -- rotation race below, which is merely wrong-looking for a frame).
        -- This feature needs software-domain pixel access anyway, so decode
        -- in software rather than try to detect hwdec use in advance.
        mp.set_property("hwdec", "no")
    end

    mp.add_hook("on_load", 50, function()
        local path = mp.get_property("stream-open-filename")

        if is_video(path) and not blur_videos then
            mp.set_property("vf", "") -- don't inherit a previous file's blur vf
            return
        end

        local rotate = detect_rotate(path)

        local w = osd_dim("osd-width", 1920)
        local h = osd_dim("osd-height", 1080)
        -- mpv's own autorotate filter (for EXIF/rotation-tagged photos and
        -- videos, e.g. phone media) always runs *after* the user's vf chain,
        -- so this filter sees pre-rotation pixels while mpv rotates its
        -- output afterward. For a 90/270 rotation that swaps width and
        -- height, so build against swapped target dims here: once mpv
        -- rotates our output back, it lands on the real screen size.
        if rotate == 90 or rotate == 270 then
            w, h = h, w
        end

        mp.set_property("vf", build_vf(w, h))
    end)
end

return { build_vf = build_vf, is_video = is_video }
