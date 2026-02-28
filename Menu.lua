--[[
    Menu.lua  —  adapted for bungie UI library (v2.0.2)
    ─────────────────────────────────────────────────────
    CHANGES vs the original Linoria Menu.lua:
      • Library:CreateWindow()  →  lib:Init()  (via GUI/Library wrapper)
      • ThemeManager stripped — bungie has a fixed theme, the module is a stub
      • Watermark updates through Wm:Text() instead of Library:SetWatermark()
      • Library.ToggleKeybind assignment replaced with Init:UpdateKeybind()
        — add a keybind element in LycorisTab to let the user change it
      • No Options[] / Toggles[] globals — tabs use Configuration._store
      • SaveManager:BuildConfigSection() uses bungie's NewTextbox/NewButton API

    TAB MIGRATION NOTE:
      Each tab file (CombatTab, BuilderTab, etc.) receives `window` which is
      now the bungie TabLibrary.  Inside each tab, replace:

        window:AddTab("name")             →  window:NewTab("name")
        tab:AddLeftGroupbox("name")       →  tab  (use NewSection for headers)
        tab:AddRightGroupbox("name")      →  same tab  (no right pane)
        grp:AddToggle("id", {Text, Default, Callback})
            →  tab:NewToggle(text, default, function(v) Configuration.set("id", v) end)
        grp:AddSlider("id", {Min, Max, Default, Suffix})
            →  tab:NewSlider(text, suffix, false, "", {min, max, default}, cb)
        grp:AddDropdown("id", {Values, Default})
            →  tab:NewSelector(text, default, values, cb)
        grp:AddButton(text, fn)           →  tab:NewButton(text, fn)
        grp:AddLabel(text)                →  tab:NewLabel(text, "left")
        grp:AddDivider()                  →  tab:NewSeperator()

      Toggles[id].Value / Options[id].Value  →  Configuration._store[id]
                                           or  Configuration.expectToggleValue(id)
]]

local Menu = {}

-- ── GUI modules ────────────────────────────────────────────────────────────
local ThemeManager = require("GUI/ThemeManager")  -- no-op stub for bungie
local SaveManager  = require("GUI/SaveManager")
local Library      = require("GUI/Library")        -- bungie wrapper

-- ── Tab modules ────────────────────────────────────────────────────────────
local CombatTab    = require("Menu/CombatTab")
local GameTab      = require("Menu/GameTab")
local BuilderTab   = require("Menu/BuilderTab")
local VisualsTab   = require("Menu/VisualsTab")
local LycorisTab   = require("Menu/LycorisTab")
local AutomationTab = require("Menu/AutomationTab")
local ExploitTab   = require("Menu/ExploitTab")

-- ── Utilities ──────────────────────────────────────────────────────────────
local Logger       = require("Utility/Logger")
local Maid         = require("Utility/Maid")
local Signal       = require("Utility/Signal")
local Configuration = require("Utility/Configuration")

-- ── Services ───────────────────────────────────────────────────────────────
local runService   = game:GetService("RunService")
local stats        = game:GetService("Stats")
local players      = game:GetService("Players")

-- ── Signals / maids ────────────────────────────────────────────────────────
local renderStepped = Signal.new(runService.RenderStepped)
local menuMaid      = Maid.new()

-- ── Constants ──────────────────────────────────────────────────────────────
local MENU_TITLE = "Eye.Exe | Beta"

-- ────────────────────────────────────────────────────────────────────────────

---Initialize the menu.
function Menu.init()
    -- Create window via the bungie wrapper.
    -- CreateWindow() internally calls lib:Introduction(), lib:Init(), and
    -- lib:Watermark(), then returns the TabLibrary (= Init).
    local window = Library:CreateWindow({
        Title   = MENU_TITLE,
        AutoShow = not shared.Lycoris.silent,
    })

    -- Configure ThemeManager (stub — bungie has a fixed theme).
    ThemeManager:SetLibrary(Library)
    ThemeManager:SetFolder("Lycoris-RogueClone-Themes")

    -- Configure SaveManager.
    SaveManager:SetLibrary(Library)
    SaveManager:SetFolder("Lycoris-Configs")
    SaveManager:SetIgnoreIndexes({
        -- These are runtime-only states that should not persist across sessions.
        "Fly", "NoClip", "Speedhack", "InfiniteJump",
        "AttachToBack", "Invisibility",
    })

    -- Initialize all tabs.
    -- Each tab receives `window` and calls window:NewTab() internally.
    CombatTab.init(window)
    BuilderTab.init(window)
    GameTab.init(window)
    VisualsTab.init(window)
    ExploitTab.init(window)
    AutomationTab.init(window)
    LycorisTab.init(window)

    -- ── Watermark loop ───────────────────────────────────────────────────
    local lastUpdate = os.clock()

    menuMaid:add(renderStepped:connect(
        "Menu_WatermarkUpdate",
        LPH_NO_VIRTUALIZE(function()
            if os.clock() - lastUpdate <= 0.5 then return end
            lastUpdate = os.clock()

            -- Pull stats.
            local networkStats      = stats:FindFirstChild("Network")
            local workspaceStats    = stats:FindFirstChild("Workspace")
            local performanceStats  = stats:FindFirstChild("PerformanceStats")
            local serverStats       = networkStats and networkStats:FindFirstChild("ServerStatsItem")

            local pingData      = serverStats and serverStats:FindFirstChild("Data Ping")
            local heartbeatData = workspaceStats and workspaceStats:FindFirstChild("Heartbeat")
            local cpuData       = performanceStats and performanceStats:FindFirstChild("CPU")
            local gpuData       = performanceStats and performanceStats:FindFirstChild("GPU")

            local ping = pingData      and pingData:GetValue()      or 0.0
            local fps  = heartbeatData and heartbeatData:GetValue() or 0.0
            local cpu  = cpuData       and cpuData:GetValue()       or 0.0
            local gpu  = gpuData       and gpuData:GetValue()       or 0.0

            local mouse    = players.LocalPlayer and players.LocalPlayer:GetMouse()
            local position = workspace.CurrentCamera and workspace.CurrentCamera.CFrame.Position
            local posFmt   = position
                and string.format("(%.2f, %.2f, %.2f)", position.X, position.Y, position.Z)
                or  "N/A"

            local str = string.format(
                "%s | %.2fms | %.1f/s | %.1fms | %.1fms",
                MENU_TITLE, ping, fps, cpu, gpu
            )

            if Configuration.expectToggleValue("ShowDebugInformation") then
                str = str .. string.format(" | %s", posFmt)
                str = str .. string.format(" | %s",
                    mouse and mouse.Target and mouse.Target:GetFullName() or "N/A")
            end

            -- Update watermark via the bungie wrapper.
            Library:SetWatermark(str)
        end)
    ))

    -- ── Menu keybind ─────────────────────────────────────────────────────
    -- bungie's library handles its own toggle keybind (set in lib:Init).
    -- If LycorisTab exposes a keybind picker, wire it here via:
    --   window:UpdateKeybind(Enum.KeyCode[chosenKey])
    -- The line below is the original pattern; adapt as needed.
    -- Library.ToggleKeybind = Options.MenuKeybind  ← Linoria-only, removed

    -- Load autoload config.
    SaveManager:LoadAutoloadConfig()

    Logger.warn("Menu initialized.")
end

---Detach the menu cleanly.
function Menu.detach()
    menuMaid:clean()
    Library:Unload()
    Logger.warn("Menu detached.")
end

return Menu
