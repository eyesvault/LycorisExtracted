--[[
    Configuration.lua  (Bridge adapter)
    ────────────────────────────────────
    Lycoris internally calls:
        Configuration.expectToggleValue("SomeName")  → boolean
        Configuration.expectOptionValue("SomeName")  → number / string / table

    This bridge translates those calls into your UI library's stored values.

    ── HOW TO WIRE UP ──────────────────────────────────────────────────────────
    Replace the two functions at the bottom of this file with calls into your
    own UI library.  Examples for common libraries are shown below.

    Linoria (already what Lycoris uses):
        expectToggleValue  → Toggles["SomeName"].Value
        expectOptionValue  → Options["SomeName"].Value

    Rayfield:
        expectToggleValue  → RayfieldLib.Flags["SomeName"]
        expectOptionValue  → RayfieldLib.Flags["SomeName"]

    Custom table approach (simplest for testing):
        Just populate Configuration._store at startup.
    ────────────────────────────────────────────────────────────────────────────
]]

local Configuration = {}

-- ── Default value store ─────────────────────────────────────────────────────
-- These are the defaults used by Lycoris Combat.  Override them via your UI
-- library or by editing _store directly before calling Defense.init().
-- ────────────────────────────────────────────────────────────────────────────
Configuration._store = {
    -- Core toggles
    EnableAutoDefense             = false,
    EnableNotifications           = false,
    EnableVisualizations          = false,

    -- Defense behavior
    RollOnParryCooldown           = false,
    VentFallback                  = false,
    DeflectBlockFallback          = false,
    UseIFrames                    = false,
    ParryOnly                     = false,
    BlatantRoll                   = false,
    RollCancel                    = false,
    UsePrediction                 = false,
    UsePunishment                 = false,
    AutoFeint                     = false,
    ValidateIncomingAnimations    = true,
    CheckTargetingValue           = false,

    -- State filters (multi-select dropdown in Lycoris)
    -- expectOptionValue("AutoDefenseFilters") returns a table<string, bool>
    AutoDefenseFilters = {
        ["Disable While Holding Block"]      = false,
        ["Disable When Textbox Focused"]     = false,
        ["Disable While Using Sightless Beam"] = false,
        ["Disable When Window Not Active"]   = false,
        ["Disable During Chime Countdown"]   = false,
        ["Filter Out M1s"]                   = false,
        ["Filter Out Mantras"]               = false,
        ["Filter Out Criticals"]             = false,
        ["Filter Out Undefined"]             = false,
    },

    -- Targeting options
    PlayerSelectionType   = "Closest In Distance",  -- or "Closest To Crosshair" / "Least Health"
    FOVLimit              = 180,
    DistanceLimit         = 3000,
    MaxTargets            = 4,
    IgnorePlayers         = false,
    IgnoreMobs            = false,
    IgnoreAllies          = false,

    -- Blocking / state
    BlockVentState        = false,
    BlockParryState       = false,
    BlockDodgeState       = false,
    NoBlockingState       = false,

    -- Failure / randomization
    AllowFailure          = false,
    FailureRate           = 0,
    IgnoreAnimationEndRate= 0,
    DashInsteadOfParryRate= 0,

    -- Windows
    DefaultPunishableWindow = 0.7,
    DefaultAfterWindow      = 0.1,
    RollCancelDelay         = 0.0,

    -- Auto-feint
    AutoFeintType = "Normal",  -- or "Aggressive"

    -- Animation speed changer
    AnimationSpeedChanger   = false,
    AnimationSpeedMinimum   = 1.0,
    AnimationSpeedMaximum   = 1.3,
    SwitchBetweenSpeeds     = false,
    LimitToAPAnimations     = false,

    -- Visualizer
    ShowAnimationVisualizer = false,

    -- Misc features
    AutoRagdollRecover      = false,
    AutoMantraFollowup      = false,
    CheckIfMoveHit          = false,
    AutoGoldenTongue        = false,
    AutoArdour              = false,
    CheckIfInCombat         = false,
    AutoWisp                = false,
    AutoWispDelay           = 0,
    M1Hold                  = false,
    FeintFlourish           = false,
    EffectLogging           = false,

    -- Logger
    ShowLoggerWindow            = false,
    MinimumLoggerDistance       = 0,
    MaximumLoggerDistance       = 9999,
    QuickNotificationSpeed      = 0.5,
}

-- ── External UI library hooks ────────────────────────────────────────────────
-- Replace these two functions with your library's getter calls.
-- ────────────────────────────────────────────────────────────────────────────

--- Get a toggle (boolean) value by key.
--- @param key string
--- @return boolean
function Configuration.expectToggleValue(key)
    -- ── Linoria example: ──────────────────────────────────────────────────
    -- if Toggles and Toggles[key] then return Toggles[key].Value end
    -- ─────────────────────────────────────────────────────────────────────
    local v = Configuration._store[key]
    if type(v) == "boolean" then return v end
    return false
end

--- Get an option (number / string / table) value by key.
--- @param key string
--- @return any
function Configuration.expectOptionValue(key)
    -- ── Linoria example: ──────────────────────────────────────────────────
    -- if Options and Options[key] then return Options[key].Value end
    -- ─────────────────────────────────────────────────────────────────────
    return Configuration._store[key]
end

--- Convenience: set a value directly (useful for scripted overrides / testing).
--- @param key string
--- @param value any
function Configuration.set(key, value)
    Configuration._store[key] = value
end

return Configuration
