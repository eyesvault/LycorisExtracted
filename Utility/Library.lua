--[[
    Utility/Library.lua  —  Bridge adapter for bungie's UI library (v2.0.2)
    ─────────────────────────────────────────────────────────────────────────
    Lycoris calls:
        Library:Notify(str, duration)               — toast notification
        Library:ManuallyManagedNotify(str)          — persistent notification
        Library:AddMissEntry(type, key, name, dist, parent)  — miss-log row
        Library:GetOverrideData(timingName)         — per-timing override table

    bungie's library notification API:
        local Notif = library:InitNotifications()
        Notif:Notify(text, duration, type, callback)
            type = "notification" | "alert" | "error" | "success" | "information"

    ── HOW TO WIRE ─────────────────────────────────────────────────────────────
    After you call  library:Init()  and  library:InitNotifications(),
    pass the returned Notif object into this bridge:

        local Library = require("Utility/Library")
        Library._notif = Notif      -- ← that's all you need

    Then Library:Notify() will automatically call Notif:Notify() underneath.
    ────────────────────────────────────────────────────────────────────────────
]]

local Library = {}

-- Holds the bungie Notification object once set.
-- Set this with:  Library._notif = library:InitNotifications()
Library._notif = nil

-- ── Notifications ─────────────────────────────────────────────────────────────

--- Show a brief toast notification.
--- @param str string
--- @param duration number  seconds (bungie lib uses this as the bar fill time)
function Library:Notify(str, duration)
    if self._notif then
        -- bungie types: "notification" = purple bar (default)
        --               "alert"        = yellow bar
        --               "error"        = red bar
        --               "success"      = green bar
        --               "information"  = indigo bar
        self._notif:Notify(str, duration or 3, "notification")
    else
        -- Fallback if InitNotifications() hasn't been called yet
        print(string.format("[Lycoris | %.1fs] %s", duration or 3, str))
    end
end

--- Show a persistent notification. Returns a cancel function.
--- bungie's library doesn't have a built-in "persistent" type,
--- so we fire a long-lived notification and return a no-op cancel.
--- @param str string
--- @return function  call to dismiss (no-op for this library)
function Library:ManuallyManagedNotify(str)
    if self._notif then
        self._notif:Notify(str, 30, "information")  -- 30-second bar = "persistent-ish"
    else
        print(string.format("[Lycoris Persistent] %s", str))
    end
    return function() end  -- bungie lib auto-dismisses; no manual cancel needed
end

-- ── Miss log (optional) ──────────────────────────────────────────────────────
-- Called when a game event was detected but had no timing configured.
-- Useful for building new timings. Hook up to a label/section if you want
-- to display misses in your UI.

--- @param defenderType string  "Animation" | "Effect" | "Part" | "Sound"
--- @param key string
--- @param name string?
--- @param distance number
--- @param parent string?
function Library:AddMissEntry(defenderType, key, name, distance, parent)
    -- Optional: surface misses in your UI or print for debugging:
    -- self:Notify(string.format("[Miss][%s] %s (%.0fs)", defenderType, tostring(key), distance), 2)
    -- print(string.format("[Lycoris Miss][%s] key=%s dist=%.1f", defenderType, tostring(key), distance))
end

-- ── Per-timing override data (optional) ─────────────────────────────────────
-- Return a table to override per-timing settings:
--   .fr    = failure rate (0–100)
--   .iaer  = ignore-animation-end rate (0–100)
--   .dipr  = dash-instead-of-parry rate (0–100)
-- Return nil to use global Configuration values.

--- @param timingName string
--- @return table?
function Library:GetOverrideData(timingName)
    return nil  -- stub — implement if you want per-timing overrides
end

return Library
