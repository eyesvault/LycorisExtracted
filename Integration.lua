--[[
    Integration.lua  —  Lycoris Combat System × bungie UI library (v2.0.2)
    ────────────────────────────────────────────────────────────────────────
    Drop this file alongside LycorisExtracted/ and wire it up in your loader.

    bungie's library API recap:
        local lib  = library:Init(Enum.KeyCode.RightAlt)
        local tab  = lib:NewTab("Combat")
        tab:NewSection("Header")
        tab:NewToggle("Label", default, callback)
        tab:NewSlider("Label", "suffix", compare, compareSign, {min,max,default}, callback)
        tab:NewSelector("Label", defaultStr, {"A","B"}, callback)
        local Notif = library:InitNotifications()
        Notif:Notify(text, duration, "notification"|"alert"|"error"|"success"|"information")

    KEY DIFFERENCE from Linoria:
        bungie's library is CALLBACK-BASED — no central Toggles[] table to poll.
        Every :NewToggle() fires a callback(bool) when changed.
        Configuration._store is the single source of truth:
            every callback writes into it,
            Configuration.expectToggleValue() reads from it.
]]

-- ═══════════════════════════════════════════════════════════════════════════
--  STEP 1 — Run _Shims first (defines preprocessor macros as no-ops)
-- ═══════════════════════════════════════════════════════════════════════════
-- loadstring(readfile("LycorisExtracted/_Shims.lua"))()

-- ═══════════════════════════════════════════════════════════════════════════
--  STEP 2 — Set up your require() resolver
-- ═══════════════════════════════════════════════════════════════════════════
--[[
local _cache = {}
local function req(path)
    if _cache[path] then return _cache[path] end
    local src = readfile("LycorisExtracted/" .. path .. ".lua")
    local fn, err = loadstring(src)
    assert(fn, "LycorisExtracted: failed to load " .. path .. "\n" .. tostring(err))
    local result = fn()
    _cache[path] = result
    return result
end
getgenv().require = req
]]

-- ═══════════════════════════════════════════════════════════════════════════
--  STEP 3 — Wire bungie notifications → Library bridge
-- ═══════════════════════════════════════════════════════════════════════════
--[[
    local Library = require("Utility/Library")
    local Notif   = library:InitNotifications()
    Library._notif = Notif      -- all Lycoris toasts now go through bungie's system
]]

-- ═══════════════════════════════════════════════════════════════════════════
--  STEP 4 — Create UI and wire each element into Configuration._store
-- ═══════════════════════════════════════════════════════════════════════════
--[[
    local Configuration = require("Utility/Configuration")
    local Defense       = require("Features/Combat/Defense")

    local lib = library:Init(Enum.KeyCode.RightAlt)

    -- ── Combat tab ───────────────────────────────────────────────────────
    local combatTab = lib:NewTab("Combat")

    combatTab:NewSection("Core")

    combatTab:NewToggle("Enable Auto Parry", false, function(v)
        Configuration.set("EnableAutoDefense", v)
    end)

    combatTab:NewToggle("Notifications", false, function(v)
        Configuration.set("EnableNotifications", v)
    end)

    combatTab:NewToggle("Hitbox Visualizations", false, function(v)
        Configuration.set("EnableVisualizations", v)
        Defense.visualizations()    -- updates existing parts immediately
    end)

    -- ── Defence behaviour ─────────────────────────────────────────────────
    combatTab:NewSection("Behaviour")

    combatTab:NewToggle("Roll On Parry Cooldown", false, function(v)
        Configuration.set("RollOnParryCooldown", v)
    end)

    combatTab:NewToggle("Vent Fallback", false, function(v)
        Configuration.set("VentFallback", v)
    end)

    combatTab:NewToggle("Block Fallback", false, function(v)
        Configuration.set("DeflectBlockFallback", v)
    end)

    combatTab:NewToggle("Use I-Frames", false, function(v)
        Configuration.set("UseIFrames", v)
    end)

    combatTab:NewToggle("Parry Dodgeables", false, function(v)
        Configuration.set("ParryOnly", v)
    end)

    combatTab:NewToggle("Auto Feint", false, function(v)
        Configuration.set("AutoFeint", v)
    end)

    combatTab:NewToggle("Roll Cancel", false, function(v)
        Configuration.set("RollCancel", v)
    end)

    combatTab:NewToggle("Validate Animations", true, function(v)
        Configuration.set("ValidateIncomingAnimations", v)
    end)

    -- ── Targeting ─────────────────────────────────────────────────────────
    combatTab:NewSection("Targeting")

    combatTab:NewSelector("Selection Type", "Closest In Distance",
        { "Closest In Distance", "Closest To Crosshair", "Least Health" },
        function(v) Configuration.set("PlayerSelectionType", v) end
    )

    combatTab:NewSlider("Distance Limit", "s", false, "",
        { min = 0, max = 10000, default = 3000 },
        function(v) Configuration.set("DistanceLimit", v) end
    )

    combatTab:NewSlider("FOV Limit", "°", false, "",
        { min = 0, max = 180, default = 180 },
        function(v) Configuration.set("FOVLimit", v) end
    )

    combatTab:NewSlider("Max Targets", "", false, "",
        { min = 1, max = 64, default = 4 },
        function(v) Configuration.set("MaxTargets", v) end
    )

    combatTab:NewToggle("Ignore Mobs", false, function(v)
        Configuration.set("IgnoreMobs", v)
    end)

    combatTab:NewToggle("Ignore Players", false, function(v)
        Configuration.set("IgnorePlayers", v)
    end)

    combatTab:NewToggle("Ignore Allies", false, function(v)
        Configuration.set("IgnoreAllies", v)
    end)

    -- ── Filters ───────────────────────────────────────────────────────────
    combatTab:NewSection("Filters")

    local filters = Configuration._store.AutoDefenseFilters

    combatTab:NewToggle("Disable While Holding Block", false, function(v)
        filters["Disable While Holding Block"] = v
    end)

    combatTab:NewToggle("Disable When Typing", false, function(v)
        filters["Disable When Textbox Focused"] = v
    end)

    combatTab:NewToggle("Disable Sightless Beam", false, function(v)
        filters["Disable While Using Sightless Beam"] = v
    end)

    combatTab:NewToggle("Disable Window Inactive", false, function(v)
        filters["Disable When Window Not Active"] = v
    end)

    combatTab:NewToggle("Filter M1s", false, function(v)
        filters["Filter Out M1s"] = v
    end)

    combatTab:NewToggle("Filter Mantras", false, function(v)
        filters["Filter Out Mantras"] = v
    end)

    combatTab:NewToggle("Filter Criticals", false, function(v)
        filters["Filter Out Criticals"] = v
    end)
]]

-- ═══════════════════════════════════════════════════════════════════════════
--  STEP 5 — Init combat systems (always after UI setup)
-- ═══════════════════════════════════════════════════════════════════════════
--[[
    local StateListener = require("Features/Combat/StateListener")
    local Defense       = require("Features/Combat/Defense")

    StateListener.init()   -- hooks local Animator.AnimationPlayed
    Defense.init()         -- hooks game descendants, effects, input

    -- Clean shutdown on respawn / script reload:
    -- Defense.detach()
    -- StateListener.detach()
]]

-- ═══════════════════════════════════════════════════════════════════════════
--  BOOT HELPER  (optional — wraps everything into one call)
-- ═══════════════════════════════════════════════════════════════════════════
local Integration = {}

---Boot the Lycoris combat system with bungie's UI library.
---@param bungieLib    table   The object returned by library:Init()
---@param bungieNotif  table   The object returned by library:InitNotifications()
function Integration.init(bungieLib, bungieNotif)
    -- Shims (safe to call multiple times)
    if not rawget(_G, "LPH_NO_VIRTUALIZE") then
        LPH_NO_VIRTUALIZE  = function(f) return f end
        PP_SCRAMBLE_STR    = function(s) return s end
        PP_SCRAMBLE_NUM    = function(n) return n end
        PP_SCRAMBLE_RE_NUM = function(n) return n end
        LRM_UserNote       = nil
        if not shared.Lycoris then shared.Lycoris = { silent = false } end
    end

    -- Wire bungie notifications
    local Library = require("Utility/Library")
    if bungieNotif then
        Library._notif = bungieNotif
    end

    -- Boot
    local StateListener = require("Features/Combat/StateListener")
    local Defense       = require("Features/Combat/Defense")

    StateListener.init()
    Defense.init()

    print("[LycorisExtracted] Combat system initialized.")

    return {
        Defense       = Defense,
        StateListener = StateListener,
        detach = function()
            Defense.detach()
            StateListener.detach()
        end,
    }
end

return Integration
