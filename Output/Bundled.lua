-- ══════════════════════════════════════════════════════════════════
--  EYE V2  +  Lycoris Auto-Parry Integration
--  Place this file in your executor workspace.
--  Place the LycorisExtracted/ folder in the same directory.
-- ══════════════════════════════════════════════════════════════════

-- ── 1. LYCORIS SHIMS ─────────────────────────────────────────────
-- Must run before any Lycoris module is loaded.
LPH_NO_VIRTUALIZE  = function(f) return f end
PP_SCRAMBLE_STR    = function(s) return s end
PP_SCRAMBLE_NUM    = function(n) return n end
PP_SCRAMBLE_RE_NUM = function(n) return n end
LRM_UserNote       = nil
if not shared.Lycoris then shared.Lycoris = { silent = false } end

-- ── 2. MODULE LOADER ─────────────────────────────────────────────
-- Reads files from  LycorisExtracted/<path>.lua  relative to your
-- executor's workspace folder.
local _moduleCache = {}
local function req(path)
    if _moduleCache[path] then return _moduleCache[path] end
    local fullPath = "LycorisExtracted/" .. path .. ".lua"
    local src = readfile(fullPath)
    assert(src, "[Lycoris] Cannot find: " .. fullPath)
    local fn, err = loadstring(src)
    assert(fn, "[Lycoris] Parse error in " .. path .. ": " .. tostring(err))
    local ok, result = pcall(fn)
    assert(ok, "[Lycoris] Runtime error in " .. path .. ": " .. tostring(result))
    _moduleCache[path] = result
    return result
end
getgenv().require = req   -- expose globally so Lycoris modules can call require()

-- ── 3. VALUE STORES ──────────────────────────────────────────────
-- These tables are populated as the UI elements are created below.
-- Configuration.lua reads from them via the bridge functions.
local Toggles = {}   -- [key] = { Value = bool }
local Options  = {}  -- [key] = { Value = number/string/table }

local function makeToggle(key, default)
    Toggles[key] = { Value = default }
    return function(v) Toggles[key].Value = v end
end

local function makeSlider(key, default)
    Options[key] = { Value = default }
    return function(v) Options[key].Value = v end
end

local function makeDropdown(key, default)
    Options[key] = { Value = default }
    return function(v) Options[key].Value = v end
end

-- ── 4. WIRE CONFIGURATION ────────────────────────────────────────
local Configuration = req("Utility/Configuration")

function Configuration.expectToggleValue(key)
    if Toggles[key] then return Toggles[key].Value end
    return Configuration._store[key] or false
end

function Configuration.expectOptionValue(key)
    if Options[key] then return Options[key].Value end
    return Configuration._store[key]
end

-- ── 5. WIRE LIBRARY NOTIFICATIONS ────────────────────────────────
-- This UI lib doesn't expose a :Notify() — we fall back to a
-- small on-screen hint via game's CoreGui or just print.
local LycorisLib = req("Utility/Library")
function LycorisLib:Notify(str, duration)
    -- swap this for your preferred notification method if you have one
    print(string.format("[AutoParry | %.1fs] %s", duration or 3, str))
end

-- ── 6. CREATE THE WINDOW ─────────────────────────────────────────
local Library = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/bloodball/-back-ups-for-libs/main/cat"
))()

local Window = Library:CreateWindow("EYE V2", Vector2.new(492, 598), Enum.KeyCode.RightControl)

-- ════════════════════════════════════════════════════════════════
--  COMBAT TAB
-- ════════════════════════════════════════════════════════════════
local CombatTab = Window:CreateTab("Combat")

-- ── Core on/off ──────────────────────────────────────────────────
local coreSection = CombatTab:CreateSector("Auto Defense", "left")

coreSection:AddToggle("Enable Auto Parry", false, makeToggle("EnableAutoDefense", false))
coreSection:AddToggle("Enable Notifications", false, makeToggle("EnableNotifications", false))
coreSection:AddToggle("Enable Visualizations", false, function(v)
    makeToggle("EnableVisualizations", false)(v)
    -- refresh existing hitbox part transparencies
    local ok, Defense = pcall(req, "Features/Combat/Defense")
    if ok and Defense then Defense.visualizations() end
end)

-- ── Parry behaviour ──────────────────────────────────────────────
local parrySection = CombatTab:CreateSector("Parry Settings", "left")

parrySection:AddToggle("Roll On Parry Cooldown", false,  makeToggle("RollOnParryCooldown", false))
parrySection:AddToggle("Vent Fallback",          false,  makeToggle("VentFallback", false))
parrySection:AddToggle("Block Fallback",         false,  makeToggle("DeflectBlockFallback", false))
parrySection:AddToggle("Use IFrames",            false,  makeToggle("UseIFrames", false))
parrySection:AddToggle("Parry Dodgeables",       false,  makeToggle("ParryOnly", false))
parrySection:AddToggle("Blatant Roll",           false,  makeToggle("BlatantRoll", false))
parrySection:AddToggle("Roll Cancel",            false,  makeToggle("RollCancel", false))

-- ── Advanced ─────────────────────────────────────────────────────
local advSection = CombatTab:CreateSector("Advanced", "right")

advSection:AddToggle("Auto Feint",                  false, makeToggle("AutoFeint", false))
advSection:AddDropdown("Auto Feint Type", { "Normal", "Aggressive" }, "Normal", false,
    makeDropdown("AutoFeintType", "Normal"))

advSection:AddToggle("Use Prediction Mantra",       false, makeToggle("UsePrediction", false))
advSection:AddToggle("Use Punishment Mantra",       false, makeToggle("UsePunishment", false))
advSection:AddToggle("Validate Animations",         true,  makeToggle("ValidateIncomingAnimations", true))
advSection:AddToggle("Check Mob Target",            false, makeToggle("CheckTargetingValue", false))

-- ── Filters ──────────────────────────────────────────────────────
local filterSection = CombatTab:CreateSector("Filters", "right")

-- We store these into the AutoDefenseFilters sub-table
local function filterToggle(filterKey, default)
    Configuration._store["AutoDefenseFilters"] = Configuration._store["AutoDefenseFilters"] or {}
    Configuration._store["AutoDefenseFilters"][filterKey] = default
    return function(v)
        Configuration._store["AutoDefenseFilters"][filterKey] = v
    end
end

filterSection:AddToggle("Disable On Block Hold",     false, filterToggle("Disable While Holding Block", false))
filterSection:AddToggle("Disable When Typing",       false, filterToggle("Disable When Textbox Focused", false))
filterSection:AddToggle("Disable During Countdown",  false, filterToggle("Disable During Chime Countdown", false))
filterSection:AddToggle("Filter M1s",                false, filterToggle("Filter Out M1s", false))
filterSection:AddToggle("Filter Mantras",            false, filterToggle("Filter Out Mantras", false))
filterSection:AddToggle("Filter Criticals",          false, filterToggle("Filter Out Criticals", false))

-- ── Targeting ────────────────────────────────────────────────────
local targetSection = CombatTab:CreateSector("Targeting", "left")

targetSection:AddDropdown("Selection Type",
    { "Closest In Distance", "Closest To Crosshair", "Least Health" },
    "Closest In Distance", false,
    makeDropdown("PlayerSelectionType", "Closest In Distance"))

--                       label        min  max   default  step  callback
targetSection:AddSlider("FOV Limit",   0,  180,  180,     1,    makeSlider("FOVLimit", 180))
targetSection:AddSlider("Distance",    0, 3000, 3000,     10,   makeSlider("DistanceLimit", 3000))
targetSection:AddSlider("Max Targets", 1,   16,    4,      1,   makeSlider("MaxTargets", 4))

targetSection:AddToggle("Ignore Players", false, makeToggle("IgnorePlayers", false))
targetSection:AddToggle("Ignore Mobs",    false, makeToggle("IgnoreMobs", false))
targetSection:AddToggle("Ignore Allies",  false, makeToggle("IgnoreAllies", false))

-- ── Timing windows ───────────────────────────────────────────────
local windowSection = CombatTab:CreateSector("Windows", "right")

windowSection:AddSlider("Punishable Window (s)", 0, 2,   0.7, 0.05, makeSlider("DefaultPunishableWindow", 0.7))
windowSection:AddSlider("After Window (s)",      0, 1,   0.1, 0.01, makeSlider("DefaultAfterWindow", 0.1))
windowSection:AddSlider("Roll Cancel Delay (s)", 0, 0.5, 0.0, 0.01, makeSlider("RollCancelDelay", 0.0))

-- ── Failure / randomisation ──────────────────────────────────────
local failSection = CombatTab:CreateSector("Human Error", "right")

failSection:AddToggle("Allow Failure", false, makeToggle("AllowFailure", false))
failSection:AddSlider("Failure Rate %",           0, 100, 0, 1, makeSlider("FailureRate", 0))
failSection:AddSlider("Ignore Anim End Rate %",   0, 100, 0, 1, makeSlider("IgnoreAnimationEndRate", 0))
failSection:AddSlider("Dash Instead Parry Rate %",0, 100, 0, 1, makeSlider("DashInsteadOfParryRate", 0))

-- ── Status ───────────────────────────────────────────────────────
local statusSection = CombatTab:CreateSector("State Overrides", "right")

statusSection:AddToggle("Block Parry State",   false, makeToggle("BlockParryState", false))
statusSection:AddToggle("Block Vent State",    false, makeToggle("BlockVentState", false))
statusSection:AddToggle("Block Dodge State",   false, makeToggle("BlockDodgeState", false))
statusSection:AddToggle("No Blocking State",   false, makeToggle("NoBlockingState", false))

-- ── Misc features ────────────────────────────────────────────────
local miscSection = CombatTab:CreateSector("Misc", "left")

miscSection:AddToggle("Auto Ragdoll Recover",  false, makeToggle("AutoRagdollRecover", false))
miscSection:AddToggle("Auto Mantra Followup",  false, makeToggle("AutoMantraFollowup", false))
miscSection:AddToggle("Check Move Hit",        false, makeToggle("CheckIfMoveHit", false))
miscSection:AddToggle("Auto Golden Tongue",    false, makeToggle("AutoGoldenTongue", false))
miscSection:AddToggle("Auto Ardour",           false, makeToggle("AutoArdour", false))
miscSection:AddToggle("Feint Flourish",        false, makeToggle("FeintFlourish", false))
miscSection:AddToggle("M1 Hold",               false, makeToggle("M1Hold", false))
miscSection:AddToggle("Effect Logging",        false, makeToggle("EffectLogging", false))

CombatTab:CreateConfigSystem("right")

-- ════════════════════════════════════════════════════════════════
--  TELEPORT TAB  (unchanged from your original script)
-- ════════════════════════════════════════════════════════════════
local TeleportTab = Window:CreateTab("Teleport")
local tpsection   = TeleportTab:CreateSector("NPCs", "left")

local tween_s    = game:GetService("TweenService")
local tweeninfo  = TweenInfo.new(22, Enum.EasingStyle.Linear)

local function bypass_teleport(v)
    local lp = game.Players.LocalPlayer
    if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
        tween_s:Create(lp.Character.HumanoidRootPart, tweeninfo, { CFrame = CFrame.new(v) }):Play()
    end
end

tpsection:AddButton("Kai", function()
    bypass_teleport(Vector3.new(763.267578125, 125.71009826660156, -4659.4404296875))
end)

local tpsection2 = TeleportTab:CreateSector("WAYSTONEs", "right")

local waystones = {
    { "Deepforest 1",  Vector3.new(2181.88818359375,  155.66354370117188,  -1849.626953125)      },
    { "Deepforest 2",  Vector3.new(1133.764404296875, 144.66915893554688,  -2502.49072265625)    },
    { "Deepforest 3",  Vector3.new(2615.952392578125, 121.6691665649414,   -2587.40283203125)    },
    { "Desert 1",      Vector3.new(-1219.086669921875, 324.591552734375,    684.24267578125)     },
    { "Desert 2",      Vector3.new(-1275.702392578125, 314.7851867675781,  -272.0736389160156)   },
    { "Desert 3",      Vector3.new(-2094.791748046875, 297.59478759765625,  184.36509704589844)  },
    { "Desert 4",      Vector3.new(-2167.153076171875, 609.6549682617188,  -722.68896484375)     },
    { "Forest 1",      Vector3.new(1773.548828125,     118.4777603149414,  -617.2544555664062)   },
    { "Forest 2",      Vector3.new(-113.61598205566406,172.92913818359375,  203.93280029296875)  },
    { "Forest 3",      Vector3.new(2743.5048828125,    287.0509948730469,   115.0159683227539)   },
    { "Forest 4",      Vector3.new(1163.505615234375,  191.88560485839844, -734.6102294921875)   },
    { "Tundra 1",      Vector3.new(3836.20654296875,   620.9088745117188,  -146.89779663085938)  },
    { "Tundra 2",      Vector3.new(4833.82421875,      690.4481811523438,  1399.513427734375)    },
    { "Tundra 3",      Vector3.new(5555.21630859375,   1345.4522705078125,   47.87493896484375)  },
    { "Tundra 4",      Vector3.new(5428.88525390625,   1113.45458984375,    832.739501953125)    },
}

for _, wp in ipairs(waystones) do
    local name, pos = wp[1], wp[2]
    tpsection2:AddButton(name .. " Waystone", function()
        bypass_teleport(pos)
    end)
end

-- ════════════════════════════════════════════════════════════════
--  INIT LYCORIS
-- ════════════════════════════════════════════════════════════════
task.spawn(function()
    -- small delay so the UI finishes drawing before we hook game signals
    task.wait(1)

    local ok1, StateListener = pcall(req, "Features/Combat/StateListener")
    local ok2, Defense       = pcall(req, "Features/Combat/Defense")

    if not ok1 then
        warn("[Lycoris] StateListener failed to load: " .. tostring(StateListener))
        return
    end
    if not ok2 then
        warn("[Lycoris] Defense failed to load: " .. tostring(Defense))
        return
    end

    StateListener.init()
    Defense.init()

    print("[Lycoris] Auto-parry system active.")

    -- Expose for console debugging
    getgenv().LycorisDefense       = Defense
    getgenv().LycorisStateListener = StateListener
    getgenv().LycorisReq           = req
end)
