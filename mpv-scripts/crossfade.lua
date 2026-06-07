-- Fades each playlist item in from and out to black via an OSD overlay.
-- Uses a timer-driven animation instead of vf filters so it works for
-- both images (single decoded frame) and videos.

local mp = require 'mp'

if not mp.create_osd_overlay then
    mp.msg.warn("crossfade: mpv too old (no OSD overlay API), skipping")
    return
end

local FADE = 0.5   -- configurable: fade duration in seconds
local TICK = 0.04  -- configurable: animation step interval (~25 fps)

local overlay   = mp.create_osd_overlay("ass-events")
overlay.z       = 100
local anim_tmr  = nil
local sched_tmr = nil

local function render(opacity)
    -- opacity: 0.0 = transparent (visible), 1.0 = opaque black
    if opacity < 0.004 then
        overlay.data = ""
        overlay:update()
        return
    end
    local w = math.floor(mp.get_property_number("osd-width")  or 1920)
    local h = math.floor(mp.get_property_number("osd-height") or 1080)
    overlay.res_x = w
    overlay.res_y = h
    -- ASS alpha is inverted: 00=opaque, FF=transparent
    local a = string.format("%02X", math.floor((1 - opacity) * 255))
    overlay.data = string.format(
        "{\\an7\\pos(0,0)\\p1\\c&H000000&\\1a&H%s&}m 0 0 l %d 0 %d %d 0 %d",
        a, w, w, h, h
    )
    overlay:update()
end

local function stop_anim()
    if anim_tmr then anim_tmr:kill(); anim_tmr = nil end
end

local function cancel_all()
    stop_anim()
    if sched_tmr then sched_tmr:kill(); sched_tmr = nil end
end

local function animate(from_op, to_op)
    stop_anim()
    local op   = from_op
    local step = (to_op - from_op) / math.max(1, math.floor(FADE / TICK))
    render(op)
    anim_tmr = mp.add_periodic_timer(TICK, function()
        op = op + step
        if (step < 0 and op <= to_op) or (step > 0 and op >= to_op) then
            render(to_op)
            stop_anim()
        else
            render(op)
        end
    end)
end

local function schedule_fadeout()
    local duration = mp.get_property_number("duration")
    local elapsed  = mp.get_property_number("time-pos") or 0
    if not duration or duration < FADE * 2.5 then return end
    local delay = math.max(0, duration - FADE - elapsed)
    sched_tmr = mp.add_timeout(delay, function()
        sched_tmr = nil
        animate(0.0, 1.0)
    end)
end

mp.register_event("file-loaded", function()
    cancel_all()
    render(1.0)        -- ensure black before fade-in starts
    animate(1.0, 0.0)  -- fade in
    schedule_fadeout()
    if not sched_tmr then
        -- duration not populated yet; retry once after a short delay
        mp.add_timeout(0.15, schedule_fadeout)
    end
end)

mp.register_event("shutdown", cancel_all)
