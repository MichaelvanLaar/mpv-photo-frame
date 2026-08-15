local mp    = require 'mp'
local utils = require 'mp.utils'

if not mp.create_osd_overlay then
    mp.msg.warn("photo-info: mpv too old (no OSD overlay API), skipping")
    return
end

local DATE_TAGS = { "DateTimeOriginal", "DateTime", "creation_time", "date" }

local opts = {
    font = "DejaVu Sans",
    size = "medium",
    color = "FFFFFF",
    outline = "000000",
    position = "bottom-left",
    lang = "",     -- empty = auto-detect from $LANG, falling back to en
    clock = "",    -- empty = chosen language's default
}
require("mp.options").read_options(opts, "photo-info")

-- Overlay size presets: multipliers on the height-proportional font sizes.
local SIZE_SCALE = {
    small  = 0.75,
    medium = 1.0,  -- current look (unchanged default)
    large  = 1.4,
    xlarge = 1.8,
}
local scale = SIZE_SCALE[opts.size:lower()]
if not scale then
    mp.msg.warn("photo-info: unknown size '" .. opts.size .. "', using medium")
    scale = 1.0
end

-- Hex RRGGBB -> ASS &HBBGGRR& (ASS colour bytes are reversed); fall back on bad input.
local function to_ass_color(hex, fallback)
    if type(hex) == "string" and hex:match("^%x%x%x%x%x%x$") then
        return "&H" .. hex:sub(5, 6) .. hex:sub(3, 4) .. hex:sub(1, 2) .. "&"
    end
    mp.msg.warn("photo-info: invalid color '" .. tostring(hex) .. "', using default")
    return fallback
end
local fill_c    = to_ass_color(opts.color, "&HFFFFFF&")
local outline_c = to_ass_color(opts.outline, "&H000000&")

-- Corner position -> ASS alignment (\an) + anchor fractions of width/height.
local POS = {
    ["bottom-left"]  = { an = 1, xf = 0.013, yf = 0.977 },
    ["bottom-right"] = { an = 3, xf = 0.987, yf = 0.977 },
    ["top-left"]     = { an = 7, xf = 0.013, yf = 0.023 },
    ["top-right"]    = { an = 9, xf = 0.987, yf = 0.023 },
}
local pos = POS[opts.position:lower()]
if not pos then
    mp.msg.warn("photo-info: unknown position '" .. opts.position .. "', using bottom-left")
    pos = POS["bottom-left"]
end

-- 12-hour clock helper with language-specific markers.
local function ampm(h, mi, am, pm)
    local hn = tonumber(h)
    local suffix = (hn < 12) and am or pm
    local h12 = hn % 12
    if h12 == 0 then h12 = 12 end
    return h12 .. ":" .. mi .. " " .. suffix
end

-- Language presets: month names + date/time builders + default clock.
local PRESETS = {
    en = {
        months = { "January", "February", "March", "April", "May", "June",
                   "July", "August", "September", "October", "November", "December" },
        date   = function(d, m, y) return m .. " " .. d .. ", " .. y end,    -- March 14, 2024
        clock_default = "24",
        time24 = function(h, mi) return h .. ":" .. mi end,                  -- 14:30
        time12 = function(h, mi) return ampm(h, mi, "AM", "PM") end,         -- 2:30 PM
    },
    de = {
        months = { "Januar", "Februar", "März", "April", "Mai", "Juni",
                   "Juli", "August", "September", "Oktober", "November", "Dezember" },
        date   = function(d, m, y) return d .. ". " .. m .. " " .. y end,    -- 14. März 2024
        clock_default = "24",
        time24 = function(h, mi) return h .. ":" .. mi .. " Uhr" end,        -- 14:30 Uhr
        time12 = function(h, mi) return ampm(h, mi, "AM", "PM") end,
    },
    fr = {
        months = { "janvier", "février", "mars", "avril", "mai", "juin",
                   "juillet", "août", "septembre", "octobre", "novembre", "décembre" },
        date   = function(d, m, y) return d .. " " .. m .. " " .. y end,     -- 14 mars 2024
        clock_default = "24",
        time24 = function(h, mi) return tonumber(h) .. " h " .. mi end,      -- 14 h 30
        time12 = function(h, mi) return ampm(h, mi, "AM", "PM") end,
    },
    es = {
        months = { "enero", "febrero", "marzo", "abril", "mayo", "junio",
                   "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre" },
        date   = function(d, m, y) return d .. " de " .. m .. " de " .. y end, -- 14 de marzo de 2024
        clock_default = "24",
        time24 = function(h, mi) return h .. ":" .. mi end,                  -- 14:30
        time12 = function(h, mi) return ampm(h, mi, "a. m.", "p. m.") end,   -- 2:30 p. m.
    },
}

local function detect_lang()
    local env = os.getenv("LC_ALL") or os.getenv("LC_TIME") or os.getenv("LANG") or ""
    local code = env:sub(1, 2):lower()
    return PRESETS[code] and code or "en"
end

local lang = opts.lang:lower()
if lang == "" or lang == "auto" then
    lang = detect_lang()
elseif not PRESETS[lang] then
    mp.msg.warn("photo-info: unknown language '" .. opts.lang .. "', using en")
    lang = "en"
end
local L = PRESETS[lang]

local clock = opts.clock
if clock ~= "12" and clock ~= "24" then
    if clock ~= "" then
        mp.msg.warn("photo-info: invalid clock '" .. clock .. "', using language default")
    end
    clock = L.clock_default
end

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

-- Returns { day=<number>, month=<1..12>, year=<string>, hour=<string>, min=<string> } or nil.
local function parse_date(s)
    local y, mo, d, h, mi =
        s:match("(%d%d%d%d)[:%-%/](%d%d)[:%-%/](%d%d)[T ](%d%d):(%d%d)")
    if not y or y == "0000" then return nil end
    local m = tonumber(mo)
    if not m or m < 1 or m > 12 then return nil end
    return { day = tonumber(d), month = m, year = y, hour = h, min = mi }
end

-- Date with no time component, e.g. IPTC/XMP DateCreated on scans that never
-- recorded a capture time. Returns { day=<number>, month=<1..12>, year=<string> } or nil.
local function parse_date_only(s)
    local y, mo, d = s:match("^(%d%d%d%d)[:%-%/](%d%d)[:%-%/](%d%d)$")
    if not y or y == "0000" then return nil end
    local m = tonumber(mo)
    if not m or m < 1 or m > 12 then return nil end
    return { day = tonumber(d), month = m, year = y }
end

-- IPTC/XMP DateCreated via exiftool: the one metadata field that can carry a
-- date with no attached time (unlike every ffprobe/EXIF tag in DATE_TAGS).
local function get_exiftool_date_created(path)
    local r = utils.subprocess({
        args = { "exiftool", "-j", "-DateCreated", path },
        capture_stdout = true,
        capture_stderr = false,
    })
    if not r or r.status ~= 0 or not r.stdout then return nil end
    local data = utils.parse_json(r.stdout)
    if not data or not data[1] then return nil end
    return data[1].DateCreated
end

local function get_label(path, tags)
    -- 1. Date from EXIF/stream tags
    for _, key in ipairs(DATE_TAGS) do
        local v = tags[key]
        if v and not v:match("^0000") then
            local p = parse_date(v)
            if p then
                local line2 = (clock == "12") and L.time12(p.hour, p.min)
                                               or  L.time24(p.hour, p.min)
                return {
                    line1 = L.date(p.day, L.months[p.month], p.year),
                    line2 = line2,
                }
            end
        end
    end
    -- 2. Date-only fallback: IPTC/XMP DateCreated (via exiftool) when no
    --    ffprobe/EXIF tag carried a date+time. Shown as date only, no time line.
    local dc = get_exiftool_date_created(path)
    if dc then
        local p = parse_date(dc)
        if p then
            local line2 = (clock == "12") and L.time12(p.hour, p.min)
                                           or  L.time24(p.hour, p.min)
            return {
                line1 = L.date(p.day, L.months[p.month], p.year),
                line2 = line2,
            }
        end
        local pd = parse_date_only(dc)
        if pd then
            return { line1 = L.date(pd.day, L.months[pd.month], pd.year), line2 = nil }
        end
    end

    -- 3. Sidecar .name file (TIFF cache — ffprobe cannot read JPEG COM segments)
    local fh = io.open(path .. ".name", "r")
    if fh then
        local name = fh:read("*l")
        fh:close()
        if name and name ~= "" then
            return { line1 = name, line2 = nil }
        end
    end
    -- 4. Filename — skip 32-char hex hashes (TIFF cache artefacts)
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

    local fs_date = math.floor(h * 0.022 * scale)
    local fs_time = math.floor(h * 0.0165 * scale)
    local x       = math.floor(w * pos.xf)
    local y       = math.floor(h * pos.yf)

    local base = string.format(
        "{\\an%d\\pos(%d,%d)\\fs%d\\fn%s"
        .. "\\c%s\\3c%s\\3a&H80&\\bord2\\shad2}",
        pos.an, x, y, fs_date, opts.font, fill_c, outline_c
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
