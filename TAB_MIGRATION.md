# Tab Migration Guide — Linoria → bungie UI library

Each tab file receives `window` (the `TabLibrary` from `lib:Init()`).
Below is a 1-to-1 mapping of every Linoria call to its bungie equivalent.

---

## Window & Tab creation

| Linoria | bungie |
|---------|--------|
| `window:AddTab("Combat")` | `window:NewTab("Combat")` |
| `tab:AddLeftGroupbox("Section")` | `tab:NewSection("Section")` |
| `tab:AddRightGroupbox("Section")` | `tab:NewSection("Section")` *(same page, no right column)* |

> bungie has a **single scrollable page per tab** — no left/right split.  
> Use `NewSection()` as visual dividers instead of groupboxes.

---

## Toggle

**Linoria:**
```lua
grp:AddToggle("EnableAutoDefense", {
    Text    = "Enable Auto Parry",
    Default = false,
    Callback = function(v) ... end,
})
```

**bungie:**
```lua
tab:NewToggle("Enable Auto Parry", false, function(v)
    Configuration.set("EnableAutoDefense", v)
end)
```

Reading the value later:
```lua
-- instead of:  Toggles["EnableAutoDefense"].Value
Configuration.expectToggleValue("EnableAutoDefense")
-- or directly: Configuration._store["EnableAutoDefense"]
```

---

## Slider

**Linoria:**
```lua
grp:AddSlider("DistanceLimit", {
    Text    = "Distance Limit",
    Min     = 0,
    Max     = 10000,
    Default = 3000,
    Suffix  = "s",
    Callback = function(v) ... end,
})
```

**bungie:**
```lua
tab:NewSlider("Distance Limit", "s", false, "",
    { min = 0, max = 10000, default = 3000 },
    function(v)
        Configuration.set("DistanceLimit", v)
    end
)
```

---

## Dropdown → Selector

**Linoria:**
```lua
grp:AddDropdown("PlayerSelectionType", {
    Text   = "Selection Type",
    Values = { "Closest In Distance", "Closest To Crosshair", "Least Health" },
    Default = 1,
    Callback = function(v) ... end,
})
```

**bungie:**
```lua
tab:NewSelector("Selection Type", "Closest In Distance",
    { "Closest In Distance", "Closest To Crosshair", "Least Health" },
    function(v)
        Configuration.set("PlayerSelectionType", v)
    end
)
```

---

## Input → Textbox

**Linoria:**
```lua
grp:AddInput("SaveManager_ConfigName", { Text = "Config name" })
```

**bungie:**
```lua
tab:NewTextbox("Config name", "", "my_config", "all", "small", true, false,
    function(v)
        -- v is the current text value
    end
)
```

Arguments: `(label, default, placeholder, format, size, autoexec, autoclear, callback)`
- `format`: `"all"` | `"numbers"` | `"lower"` | `"upper"`
- `size`:   `"small"` | `"medium"` | `"large"`

---

## Button

**Linoria:**
```lua
grp:AddButton("Save config", function() ... end)
```

**bungie:**
```lua
tab:NewButton("Save config", function() ... end)
```

Multi-buttons (up to 4 inline):
```lua
tab:NewButton("Create", function() ... end)
    :AddButton("Load", function() ... end)
    :AddButton("Delete", function() ... end)
```

---

## Label

**Linoria:**
```lua
grp:AddLabel("Some text", true)  -- true = wrap
```

**bungie:**
```lua
tab:NewLabel("Some text", "left")  -- "left" | "center" | "right"
```

---

## Divider

**Linoria:**
```lua
grp:AddDivider()
```

**bungie:**
```lua
tab:NewSeperator()
```

---

## Keybind

**Linoria:**
```lua
grp:AddKeyPicker("MyKey", { Default = "P", Text = "Toggle key" })
```

**bungie (standalone keybind):**
```lua
tab:NewKeybind("Toggle key", Enum.KeyCode.P, function(key)
    -- key = the chosen KeyCode name string
end)
```

**bungie (keybind attached to a toggle):**
```lua
tab:NewToggle("Enable something", false, callback)
    :AddKeybind(Enum.KeyCode.P)
```

---

## Color picker

bungie has no color picker — ThemeManager is a stub.  
Remove `grp:AddColorPicker()` calls entirely, or replace with a label.

---

## Reading values at runtime

bungie has **no** `Toggles[]` or `Options[]` globals.

| Old pattern | New pattern |
|-------------|-------------|
| `Toggles["EnableFly"].Value` | `Configuration._store["Fly"]` |
| `Options["DistanceLimit"].Value` | `Configuration._store["DistanceLimit"]` |
| *(anywhere)* | `Configuration.expectToggleValue("EnableFly")` |
| *(anywhere)* | `Configuration.expectOptionValue("DistanceLimit")` |

The key insight: **every callback writes into Configuration._store**, so
the rest of the codebase reads from there instead of polling the UI.

---

## Complete tab skeleton

```lua
local MyTab = {}

function MyTab.init(window)
    local Configuration = require("Utility/Configuration")

    local tab = window:NewTab("My Tab")

    -- ── Section 1 ────────────────────────────────────────────────────
    tab:NewSection("Core")

    tab:NewToggle("Enable feature", false, function(v)
        Configuration.set("MyFeatureEnabled", v)
    end)

    tab:NewSlider("Speed", "s", false, "", { min = 1, max = 100, default = 16 }, function(v)
        Configuration.set("MySpeed", v)
    end)

    -- ── Section 2 ────────────────────────────────────────────────────
    tab:NewSection("Advanced")

    tab:NewSelector("Mode", "Auto", { "Auto", "Manual", "Off" }, function(v)
        Configuration.set("MyMode", v)
    end)

    tab:NewButton("Do something", function()
        print("Button pressed!")
    end)
end

return MyTab
```
