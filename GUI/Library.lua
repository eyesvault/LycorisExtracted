--[[
    GUI/Library.lua  —  bungie UI library (v2.0.2) wrapper
    ───────────────────────────────────────────────────────
    Loads bungie's library and wraps it so that Menu.lua, SaveManager, and
    the rest of Lycoris can call it the same way they called Linoria.

    WHAT CHANGED vs Linoria:
    ┌─────────────────────────────────┬──────────────────────────────────┐
    │ Linoria call                    │ bungie equivalent                │
    ├─────────────────────────────────┼──────────────────────────────────┤
    │ Library:CreateWindow({...})     │ lib:Init(keybind)                │
    │ window:AddTab("name")           │ window:NewTab("name")            │
    │ tab:AddLeftGroupbox("name")     │ tab  (groupboxes → sections)     │
    │ tab:AddRightGroupbox("name")    │ tab  (same page, no right pane)  │
    │ grp:AddToggle("id", {Text, …})  │ tab:NewToggle(text, def, cb)     │
    │ grp:AddSlider("id", {…})        │ tab:NewSlider(…)                 │
    │ grp:AddDropdown("id", {…})      │ tab:NewSelector(text, def, list, cb) │
    │ grp:AddInput("id", {Text})      │ tab:NewTextbox(text, …)          │
    │ grp:AddButton(text, fn)         │ tab:NewButton(text, fn)          │
    │ grp:AddLabel(text, wrap)        │ tab:NewLabel(text, "left")       │
    │ grp:AddDivider()                │ tab:NewSeperator()               │
    │ Library:SetWatermark(str)       │ Wm:Text(str)                     │
    │ Library:Notify(msg, dur)        │ Notif:Notify(msg, dur, type)     │
    │ Library:Unload()                │ Init:Remove() + Wm:Remove()      │
    │ Toggles[id].Value               │ Configuration._store[id]         │
    │ Options[id].Value               │ Configuration._store[id]         │
    └─────────────────────────────────┴──────────────────────────────────┘

    NOTE: bungie's library has no colour-picker or theme system, so
    ThemeManager is a no-op stub.  There are also no Toggles[] / Options[]
    globals — all UI state flows through callbacks into Configuration._store.

    USAGE (Menu.lua pattern):
        local Library = require("GUI/Library")
        local window  = Library:CreateWindow({ Title = "Eye.Exe", AutoShow = true })
        local tab     = window:NewTab("Combat")       -- bungie API
        tab:NewToggle("Enable parry", false, function(v)
            Configuration.set("EnableAutoDefense", v)
        end)
        Library:SetWatermark("Eye.Exe | 0ms")
        Library:Notify("Loaded!", 3)
        -- on detach:
        Library:Unload()
]]

-- ── Load bungie's library ──────────────────────────────────────────────────
-- Replace the URL with your own host if desired.
local _lib = loadstring(game:HttpGet("https://raw.githubusercontent.com/Consistt/Ui/main/UnLeaked"))()

-- ── Public wrapper ──────────────────────────────────────────────────────────
local Library = {}

Library._lib      = _lib   -- raw bungie library (in case a tab needs it)
Library._init     = nil    -- TabLibrary returned by lib:Init()
Library._wm       = nil    -- WatermarkFunctions returned by lib:Watermark()
Library._notif    = nil    -- Notification object from lib:InitNotifications()

-- Exposed so Utility/Library.lua can share the same Notif instance
-- (set automatically inside CreateWindow)
Library.Notif = nil

-- ── Window creation ─────────────────────────────────────────────────────────

---Create the main window.  Call once from Menu.init().
---@param opts table  { Title, AutoShow, ... }  — mirrors Linoria's opts table
---@return table      TabLibrary  (bungie's window — pass to tab init functions)
function Library:CreateWindow(opts)
    opts = opts or {}
    local title    = opts.Title or "Eye.Exe"
    local autoShow = opts.AutoShow ~= false   -- default true

    -- Set title on bungie library
    _lib.title = title

    -- Boot notifications
    local Notif = _lib:InitNotifications()
    self._notif = Notif
    self.Notif  = Notif

    -- Wire Utility/Library (combat toasts) to the same Notif object
    local ok, UtilLib = pcall(require, "Utility/Library")
    if ok and UtilLib and type(UtilLib) == "table" then
        UtilLib._notif = Notif
    end

    -- Intro animation (skip when silent)
    if autoShow and not (shared and shared.Lycoris and shared.Lycoris.silent) then
        _lib:Introduction()
        task.wait(1)
    end

    -- Create the window
    local init = _lib:Init(Enum.KeyCode.RightAlt)
    self._init = init

    -- Watermark (starts with just the title; Menu updates it via SetWatermark)
    self._wm = _lib:Watermark(title)

    return init  -- callers receive the TabLibrary (window:NewTab() etc.)
end

-- ── Watermark ────────────────────────────────────────────────────────────────

---Update the watermark text.  Called by Menu.lua every 0.5s.
---@param str string
function Library:SetWatermark(str)
    if self._wm then
        self._wm:Text(str)
    end
end

-- ── Notifications ─────────────────────────────────────────────────────────

---Show a brief toast.
---@param msg  string
---@param dur  number   seconds (default 3)
---@param type string   "notification"|"alert"|"error"|"success"|"information"
function Library:Notify(msg, dur, notifType)
    if self._notif then
        self._notif:Notify(tostring(msg), dur or 3, notifType or "notification")
    else
        print(string.format("[Library:Notify] %s", tostring(msg)))
    end
end

-- ── Unload ────────────────────────────────────────────────────────────────

---Destroy the window and watermark.  Called by Menu.detach().
function Library:Unload()
    if self._init then
        pcall(function() self._init:Remove() end)
        self._init = nil
    end
    if self._wm then
        pcall(function() self._wm:Remove() end)
        self._wm = nil
    end
    self._notif = nil
    self.Notif  = nil
end

-- ── Stubs kept for source-compatibility ──────────────────────────────────
-- Menu.lua assigns Library.ToggleKeybind; bungie handles the keybind
-- internally via Init:UpdateKeybind(), so this is a harmless no-op field.
Library.ToggleKeybind = nil

-- InfoLoggerFrame / AnimationVisualizerFrame / Watermark / KeybindFrame
-- These are Linoria-specific fields that SaveManager references when saving
-- frame positions.  bungie has no equivalent, so we stub them to avoid errors.
Library.InfoLoggerFrame             = { Position = UDim2.new() }
Library.AnimationVisualizerFrame    = { Position = UDim2.new() }
Library.Watermark                   = { Position = UDim2.new() }
Library.KeybindFrame                = { Position = UDim2.new() }
Library.InfoLoggerData              = {
    KeyBlacklistHistory = {},
    KeyBlacklistList    = {},
    InfoLoggerCycle     = false,
}

function Library:RefreshInfoLogger() end
function Library:KeyBlacklists() return {} end

return Library
