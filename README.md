# Lycoris-Rewrite — Extracted Combat System

Standalone extraction of the auto-parry, timing engine, animation logger, and
animation visualizer from [Lycoris-Rewrite](https://github.com/Blastbrean/Lycoris-Rewrite),
ready to drop into any Roblox executor script / UI library.

---

## File Layout

```
LycorisExtracted/
│
├── _Shims.lua                   ← LOAD THIS FIRST — defines preprocessor macros
├── Integration.lua              ← Quick-start wiring guide + boot helper
│
├── Utility/
│   ├── Configuration.lua        ← ★ EDIT THIS — bridge to your UI library
│   ├── Library.lua              ← ★ EDIT THIS — bridge for notifications & miss-log
│   ├── Maid.lua                 — Cleanup / lifecycle manager
│   ├── Signal.lua               — Safe RBXScriptSignal wrapper
│   ├── Profiler.lua             — Microprofiler wrapper
│   ├── TaskSpawner.lua          — Coroutine spawner with error handling
│   ├── Logger.lua               — warn() + notify() helpers
│   ├── Table.lua                — Table utilities (slice, etc.)
│   ├── Finder.lua               — Game-world finder helpers
│   ├── OriginalStore.lua        — Temporarily swap instance properties
│   └── OriginalStoreManager.lua — OriginalStore registry
│
├── Game/
│   ├── Latency.lua              — RTT / send-delay / receive-delay helpers
│   ├── KeyHandling.lua          — SHA-256 remote-name finder (obfuscation bypass)
│   ├── QueuedBlocking.lua       — Frame-perfect block queue (Deflect / Normal)
│   ├── InputClient.lua          — All player input simulation (parry/dodge/feint…)
│   ├── PlayerScanning.lua       — Moderator & ally detection
│   │
│   ├── Objects/
│   │   └── DodgeOptions.lua     — Roll/dodge configuration object
│   │
│   └── Timings/
│       ├── Action.lua           — Single timed action (type, when, hitbox)
│       ├── ActionContainer.lua  — Keyed collection of Actions
│       ├── Timing.lua           — Base timing (name, tag, distances, windows…)
│       ├── AnimationTiming.lua  — Animation-specific timing (ID, hyperarmor…)
│       ├── EffectTiming.lua     — Effect-specific timing (effect name)
│       ├── PartTiming.lua       — Part-specific timing (part name)
│       ├── SoundTiming.lua      — Sound-specific timing (sound ID)
│       ├── TimingContainer.lua  — Keyed collection of Timings
│       ├── TimingContainerPair.lua — Internal + config pair (config overrides)
│       ├── TimingSave.lua       — Save-file structure (4 containers)
│       ├── SaveManager.lua      — Filesystem load/save + auto-save
│       ├── ModuleManager.lua    — User-written Lua module executor
│       └── PlaybackData.lua     — Animation speed history (for Visualizer)
│
└── Features/
    ├── Combat/
    │   ├── Defense.lua          — ★ TOP-LEVEL COORDINATOR — call .init() here
    │   ├── StateListener.lua    — Combat state tracker (parry/vent/dodge avail.)
    │   ├── EntityHistory.lua    — CFrame history per entity (for prediction)
    │   ├── Targeting.lua        — Viable target selection + sorting
    │   │
    │   └── Objects/
    │       ├── Defender.lua         — Base defender class (hitbox, action, tasks…)
    │       ├── AnimatorDefender.lua — Watches Animator.AnimationPlayed
    │       ├── EffectDefender.lua   — Watches ClientEffect remote events
    │       ├── PartDefender.lua     — Watches workspace parts (BasePart added)
    │       ├── SoundDefender.lua    — Watches Sound.Played
    │       ├── Target.lua           — Typed target object (character, root, dist…)
    │       ├── Task.lua             — Delayed coroutine with blocking check
    │       ├── HitboxOptions.lua    — Hitbox check configuration object
    │       ├── RepeatInfo.lua       — State for repeat-until-parry-end timings
    │       └── ValidationOptions.lua — Validation configuration for an action
    │
    └── Game/
        └── AnimationVisualizer.lua  — 3-D viewport + timeline UI
```

---

## Architecture — How Auto-Parry Works

```
Game event
    │
    ├─ Animator.AnimationPlayed  ──→  AnimatorDefender.process(track)
    ├─ ClientEffect.OnClientEvent ─→  EffectDefender.new(name, data)
    ├─ workspace DescendantAdded  ──→  PartDefender.new(part)
    └─ Sound.Played               ──→  SoundDefender.process()
                │
                ▼
    Timing lookup  (SaveManager.as / .es / .ps / .ss)
    TimingContainerPair → config overrides internal
                │
          ┌─────┴──────────────────────────────┐
          │  RPUE mode?  →  srpue() loop        │
          │  Module mode? →  ModuleManager.lf() │
          │  Normal?     →  actions() loop      │
          └─────────────────────────────────────┘
                │  For each Action:
                ▼
    Task.new(delay = action:when() - rdelay - sdelay)
                │
                ▼  (on deadline)
    Defender.handle(timing, action)
        ├─ Defender.valid()   ← StateListener, filters, stun checks
        ├─ AutoFeint          ← if AutoFeint enabled
        └─ Defender.parry()   ← QueuedBlocking.invoke(BLOCK_TYPE_DEFLECT)
              │  fallbacks:
              ├─ canDodge → InputClient.dodge()
              ├─ canVent  → InputClient.vent()
              └─ canBlock → QueuedBlocking.invoke(BLOCK_TYPE_NORMAL)
```

---

## Timing Config System

Timings are stored in `%localappdata%/Roblox` (Windows) under
`Lycoris-Rewrite-Timings/` as **MessagePack** files.

Each timing file has 4 containers:

| Container | Timing type | Key |
|-----------|------------|-----|
| `as` | AnimationTiming | Animation ID (rbxassetid://…) |
| `es` | EffectTiming | Effect class name |
| `ps` | PartTiming | Part name |
| `ss` | SoundTiming | Sound ID |

**Key fields on a Timing:**

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Human-readable name |
| `tag` | string | "M1" / "Mantra" / "Critical" / "Undefined" |
| `imdd` | number | Min activation distance (studs) |
| `imxd` | number | Max activation distance |
| `punishable` | number | Window before action: block inputs (sec) |
| `after` | number | Window after action: still accept (sec) |
| `duih` | bool | Delay until player is inside hitbox |
| `rpue` | bool | Repeat parry until animation end |
| `umoa` | bool | Use custom Lua module instead of actions |
| `hitbox` | Vector3 | Size for hitbox check |
| `fhb` | bool | Offset hitbox in facing direction |
| `hso` | number | Additional forward/back shift (studs) |

---

## Quick Integration (bungie UI library v2.0.2)

```lua
-- 1. Boot shims
loadstring(readfile("LycorisExtracted/_Shims.lua"))()

-- 2. Custom require
local _cache = {}
local function req(path)
    if _cache[path] then return _cache[path] end
    local fn = assert(loadstring(readfile("LycorisExtracted/" .. path .. ".lua")))
    local result = fn()
    _cache[path] = result
    return result
end
getgenv().require = req

-- 3. Wire bungie notifications → Library bridge
--    (bungie's library is callback-based — no central Toggles[] table)
local Library = req("Utility/Library")
local Notif   = library:InitNotifications()
Library._notif = Notif       -- all Lycoris toasts now go through bungie's system

-- 4. Build UI — every callback writes into Configuration._store
local Configuration = req("Utility/Configuration")
local Defense       = req("Features/Combat/Defense")
local lib = library:Init(Enum.KeyCode.RightAlt)

local combatTab = lib:NewTab("Combat")
combatTab:NewSection("Core")

combatTab:NewToggle("Enable Auto Parry", false, function(v)
    Configuration.set("EnableAutoDefense", v)
end)
combatTab:NewToggle("Roll On Parry Cooldown", false, function(v)
    Configuration.set("RollOnParryCooldown", v)
end)
combatTab:NewToggle("Notifications", false, function(v)
    Configuration.set("EnableNotifications", v)
end)
combatTab:NewToggle("Hitbox Visualizations", false, function(v)
    Configuration.set("EnableVisualizations", v)
    Defense.visualizations()
end)

combatTab:NewSection("Targeting")
combatTab:NewSelector("Selection Type", "Closest In Distance",
    { "Closest In Distance", "Closest To Crosshair", "Least Health" },
    function(v) Configuration.set("PlayerSelectionType", v) end
)
combatTab:NewSlider("Distance Limit", "s", false, "",
    { min = 0, max = 10000, default = 3000 },
    function(v) Configuration.set("DistanceLimit", v) end
)
-- See Integration.lua for the full list of every toggle / slider / selector

-- 5. Init (always after UI is built)
req("Features/Combat/StateListener").init()
req("Features/Combat/Defense").init()
```

---

## Preprocessor Macros

The source uses the Luraph + custom preprocessor. `_Shims.lua` defines all
of them as identity functions so they become no-ops at runtime:

| Macro | Purpose | Runtime behaviour |
|-------|---------|-------------------|
| `LPH_NO_VIRTUALIZE(f)` | Tells Luraph not to virtualize this fn | Returns `f` unchanged |
| `PP_SCRAMBLE_STR(s)` | Encrypts string literals at compile time | Returns `s` unchanged |
| `PP_SCRAMBLE_NUM(n)` | Encrypts number literals at compile time | Returns `n` unchanged |
| `PP_SCRAMBLE_RE_NUM(n)` | Re-encrypts a number (used in RPUE paths) | Returns `n` unchanged |
| `LRM_UserNote` | Set to a string in release builds | `nil` (dev/verbose mode) |

---

## Notes

- **InputClient.lua** is highly game-specific (Deepwoken). Its `dodge()`,
  `feint()`, `vent()` functions contain full reimplementations of the game's
  movement client. These should work as-is.

- **KeyHandling.lua** uses `getgc()` (executor-only) to find obfuscated
  RemoteEvent names by hash. It is required for `ServerSlide` / `ServerSlideStop`.

- **ModuleManager.lua** loads Lua files from `Lycoris-Rewrite-Modules/` on disk.
  If you don't use custom modules, this can be left inert.

- The **AnimationVisualizer** depends on a draggable ScreenGui window (originally
  built for Linoria). To use it with bungie's library you would need to host the
  ViewportFrame inside one of bungie's tab pages, or create a standalone ScreenGui.
  `Defense.agpd(animId)` retrieves PlaybackData for any recorded animation ID.
