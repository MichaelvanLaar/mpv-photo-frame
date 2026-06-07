local mp    = require 'mp'
local utils = require 'mp.utils'

if not mp.create_osd_overlay then
    mp.msg.warn("photo-info: mpv too old (no OSD overlay API), skipping")
    return
end

-- Configurable: month names in your language.
local MONTHS = {
    "Januar", "Februar", "März", "April", "Mai", "Juni",
    "Juli", "August", "September", "Oktober", "November", "Dezember"
}

local DATE_TAGS = { "DateTimeOriginal", "DateTime", "creation_time", "date" }

local overlay = mp.create_osd_overlay("ass-events")
overlay.z     = 50  -- below crossfade.lua (z = 100)

local function get_tags(path)
    local r = utils.subprocess({
        args = {
            "ffprobe", "-v", "quiet",
            "-print_format", "json",
            "-read_intervals", "%+#1",
            "-show_entries", "format_tags:stream_tags:frame_tags",
            path,
        },
        capture_stdout = true,
        capture_stderr = false,
    })
    if not r or r.status ~= 0 then return {} end
    local data = utils.parse_json(r.stdout)
    if not data then return {} end
    local tags = {}
    if data.format and data.format.tags then
        for k, v in pairs(data.format.tags) do tags[k] = v end
    end
    if data.streams then
        for _, s in ipairs(data.streams) do
            if s.tags then
                for k, v in pairs(s.tags) do
                    if not tags[k] then tags[k] = v end
                end
            end
        end
    end
    if data.frames then
        for _, f in ipairs(data.frames) do
            if f.tags then
                for k, v in pairs(f.tags) do
                    if not tags[k] then tags[k] = v end
                end
            end
        end
    end
    return tags
end

local function parse_date(s)
    local y, mo, d, h, mi =
        s:match("(%d%d%d%d)[:%-%/](%d%d)[:%-%/](%d%d)[T ](%d%d):(%d%d)")
    if not y or y == "0000" then return nil end
    local m = tonumber(mo)
    if not m or m < 1 or m > 12 then return nil end
    return {
        line1 = string.format("%d. %s %s", tonumber(d), MONTHS[m], y),
        line2 = string.format("%s:%s Uhr", h, mi),
    }
end

local function get_label(path, tags)
    -- 1. Date from EXIF/stream tags
    for _, key in ipairs(DATE_TAGS) do
        local v = tags[key]
        if v and not v:match("^0000") then
            local parsed = parse_date(v)
            if parsed then return parsed end
        end
    end
    -- 2. Sidecar .name file (TIFF cache — ffprobe cannot read JPEG COM segments)
    local fh = io.open(path .. ".name", "r")
    if fh then
        local name = fh:read("*l")
        fh:close()
        if name and name ~= "" then
            return { line1 = name, line2 = nil }
        end
    end
    -- 3. Filename — skip 32-char hex hashes (TIFF cache artefacts)
    local fname = mp.get_property("filename/no-ext") or ""
    if fname ~= ""
        and not fname:match(
            "^%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x"
            .. "%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x$"
        )
    then
        return { line1 = fname:gsub("[_%-]", " "), line2 = nil }
    end
    return nil
end

local function update()
    local path = mp.get_property("path")
    if not path then return end

    local w = math.floor(mp.get_property_number("osd-width")  or 0)
    local h = math.floor(mp.get_property_number("osd-height") or 0)
    if w < 16 then w = 3840 end
    if h < 16 then h = 2160 end
    overlay.res_x = w
    overlay.res_y = h

    local tags  = get_tags(path)
    local label = get_label(path, tags)

    if not label then
        overlay.data = ""
        overlay:update()
        return
    end

    local fs_date = math.floor(h * 0.022)
    local fs_time = math.floor(h * 0.0165)
    local x       = math.floor(w * 0.013)
    local y       = math.floor(h * 0.977)

    -- Configurable: font name (must be installed on your system).
    local base = string.format(
        "{\\an1\\pos(%d,%d)\\fs%d\\fnDejaVu Sans"
        .. "\\c&HFFFFFF&\\3c&H000000&\\3a&H80&\\bord2\\shad2}",
        x, y, fs_date
    )

    if label.line2 then
        overlay.data = base .. label.line1
            .. string.format("\\N{\\fs%d\\alpha&H40&}", fs_time)
            .. label.line2
    else
        overlay.data = base .. label.line1
    end

    overlay:update()
end

mp.register_event("file-loaded", function()
    mp.add_timeout(0.05, update)
end)

mp.register_event("shutdown", function()
    overlay:remove()
end)
