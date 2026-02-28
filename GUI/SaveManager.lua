--[[
    GUI/SaveManager.lua  —  Config manager for bungie UI library
    ──────────────────────────────────────────────────────────────
    Linoria stored every UI element in global Toggles[] / Options[] tables and
    serialized them by index.  bungie's library is callback-based with no such
    globals.  Instead, every toggle/slider/selector callback writes its value
    into Configuration._store, so we save and restore Configuration._store
    directly.

    WHAT CHANGED vs the original SaveManager:
      • Save()  — serializes Configuration._store to JSON
      • Load()  — deserializes and calls Configuration.set() for each key
      • BuildConfigSection(tab) — uses bungie's NewTextbox / NewSelector /
        NewButton / NewLabel / NewSeperator instead of Linoria group methods
      • No Toggles[]/Options[] references anywhere
      • Frame-position keys (keybindFrame, watermark, infoLogger,
        animationVisualizer) are kept in the save file for forward compatibility
        but are silently ignored on load (bungie has no draggable frames)

    MIGRATION NOTE:
      Keys in SetIgnoreIndexes() are matched against Configuration._store keys,
      NOT against Linoria toggle IDs.  Update callers accordingly.
]]

return LPH_NO_VIRTUALIZE(function()
    local httpService = game:GetService("HttpService")

    -- ── Helpers ────────────────────────────────────────────────────────────

    local function isSerializable(v)
        local t = type(v)
        return t == "boolean" or t == "number" or t == "string"
    end

    ---Deep-serialize a value.  Only booleans, numbers, strings, and flat
    ---tables of those types are supported (covers Configuration._store).
    local function serializeValue(v)
        local t = type(v)
        if t == "boolean" or t == "number" or t == "string" then
            return v
        elseif t == "table" then
            local out = {}
            for k, val in pairs(v) do
                if type(k) == "string" and isSerializable(val) then
                    out[k] = val
                end
            end
            return out
        end
        return nil
    end

    -- ── SaveManager ────────────────────────────────────────────────────────

    local SaveManager = {}
    do
        SaveManager.Folder  = "EyeExe-Configs"
        SaveManager.Ignore  = {}
        SaveManager.Library = nil   -- set via SetLibrary(); used for Notify()

        -- ── Configuration access ───────────────────────────────────────────
        -- Require lazily so there's no circular-require issue at load time.
        local function getConfig()
            return require("Utility/Configuration")
        end

        -- ── Folder helpers ────────────────────────────────────────────────

        function SaveManager:SetFolder(folder)
            self.Folder = folder
            self:BuildFolderTree()
        end

        function SaveManager:SetIgnoreIndexes(list)
            for _, key in next, list do
                self.Ignore[key] = true
            end
        end

        function SaveManager:IgnoreThemeSettings()
            -- bungie has no theme system; nothing to ignore
        end

        function SaveManager:BuildFolderTree()
            pcall(function()
                if not isfolder(self.Folder) then
                    makefolder(self.Folder)
                end
            end)
        end

        function SaveManager:SetLibrary(library)
            self.Library = library
        end

        -- ── Notifications helper ──────────────────────────────────────────

        function SaveManager:_notify(msg, dur)
            if self.Library and self.Library.Notify then
                self.Library:Notify(msg, dur or 3)
            else
                print("[SaveManager]", msg)
            end
        end

        -- ── Save ──────────────────────────────────────────────────────────

        ---Save the current Configuration._store to a named config file.
        ---@param name string
        ---@return boolean, string?
        function SaveManager:Save(name)
            if not name or name == "" then
                return false, "no config name given"
            end

            local Configuration = getConfig()
            local store = Configuration._store

            local data = { objects = {} }

            for key, value in pairs(store) do
                if not self.Ignore[key] then
                    local serialized = serializeValue(value)
                    if serialized ~= nil then
                        table.insert(data.objects, { key = key, value = serialized })
                    end
                end
            end

            local ok, encoded = pcall(httpService.JSONEncode, httpService, data)
            if not ok then
                return false, "JSON encode failed: " .. tostring(encoded)
            end

            local path = self.Folder .. "/" .. name .. ".json"
            pcall(writefile, path, encoded)
            return true
        end

        -- ── Load ──────────────────────────────────────────────────────────

        ---Load a named config file into Configuration._store.
        ---@param name string
        ---@return boolean, string?
        function SaveManager:Load(name)
            if not name or name == "" then
                return false, "no config name given"
            end

            local file = self.Folder .. "/" .. name .. ".json"
            if not isfile(file) then
                return false, "file not found"
            end

            local ok, decoded = pcall(httpService.JSONDecode, httpService, readfile(file))
            if not ok then
                return false, "JSON decode failed"
            end

            local Configuration = getConfig()

            if decoded.objects then
                for _, entry in next, decoded.objects do
                    if entry.key and entry.value ~= nil then
                        task.spawn(function()
                            Configuration.set(entry.key, entry.value)
                        end)
                    end
                end
            end

            return true
        end

        -- ── Config list ───────────────────────────────────────────────────

        function SaveManager:RefreshConfigList()
            local ok, list = pcall(listfiles, self.Folder)
            if not ok then return {} end

            local out = {}
            for _, file in ipairs(list) do
                if file:sub(-5) == ".json" then
                    -- extract basename without extension
                    local pos = file:find(".json", 1, true)
                    local start = pos
                    local char = file:sub(pos, pos)
                    while char ~= "/" and char ~= "\\" and char ~= "" do
                        pos = pos - 1
                        char = file:sub(pos, pos)
                    end
                    if char == "/" or char == "\\" then
                        table.insert(out, file:sub(pos + 1, start - 1))
                    end
                end
            end
            return out
        end

        -- ── Autoload ──────────────────────────────────────────────────────

        function SaveManager:LoadAutoloadConfig()
            local autoloadFile = self.Folder .. "/autoload.txt"
            local ok, name = pcall(readfile, autoloadFile)
            if not ok or not name or name == "" then return end

            local success, err = self:Load(name)
            if not success then
                self:_notify("Failed to load autoload config: " .. tostring(err))
            else
                self:_notify(string.format('Auto loaded config "%s"', name))
            end
        end

        -- ── Config UI section (bungie API) ────────────────────────────────
        ---Build a config manager section inside a bungie tab.
        ---Call this from your Lycoris/Settings tab init.
        ---@param tab table  A bungie Components table (result of window:NewTab())
        function SaveManager:BuildConfigSection(tab)
            assert(self.Library, "SaveManager: must call SetLibrary() first")

            tab:NewSection("Config Manager")

            -- Config name input (medium textbox so the label fits)
            local nameInput = tab:NewTextbox(
                "Config name", "", "my_config", "all", "small", true, false,
                function(val)
                    -- stored in-place; we read nameInput below via a closure
                end
            )
            -- We track the current value ourselves since bungie textbox fires
            -- the callback on FocusLost, not on every keystroke.
            local configNameValue = ""
            nameInput:SetFunction(function(val) configNameValue = val end)

            -- Config list selector
            local configList = tab:NewSelector(
                "Config list", ". . .",
                self:RefreshConfigList(),
                function(val) end  -- just tracks selection
            )
            local selectedConfig = ". . ."
            configList:SetFunction(function(val) selectedConfig = val end)

            tab:NewSeperator()

            -- Buttons row: Create  |  Load
            tab:NewButton("Create config", function()
                local name = configNameValue
                if not name or name:gsub(" ", "") == "" then
                    return self:_notify("Invalid config name (empty)", 2)
                end
                local ok, err = self:Save(name)
                if not ok then
                    return self:_notify("Failed to save: " .. tostring(err))
                end
                self:_notify(string.format('Created config "%s"', name))
                -- refresh the selector options
                local newList = self:RefreshConfigList()
                for _, v in ipairs(newList) do
                    -- selectors in bungie don't have a SetValues method;
                    -- add any new options that aren't already there
                    pcall(function() configList:AddOption(v) end)
                end
            end)

            tab:NewButton("Load config", function()
                if selectedConfig == ". . ." or selectedConfig == "" then
                    return self:_notify("No config selected", 2)
                end
                local ok, err = self:Load(selectedConfig)
                if not ok then
                    return self:_notify("Failed to load: " .. tostring(err))
                end
                self:_notify(string.format('Loaded config "%s"', selectedConfig))
            end)

            tab:NewButton("Overwrite config", function()
                if selectedConfig == ". . ." or selectedConfig == "" then
                    return self:_notify("No config selected", 2)
                end
                local ok, err = self:Save(selectedConfig)
                if not ok then
                    return self:_notify("Failed to overwrite: " .. tostring(err))
                end
                self:_notify(string.format('Overwrote config "%s"', selectedConfig))
            end)

            tab:NewButton("Set as autoload", function()
                if selectedConfig == ". . ." or selectedConfig == "" then
                    return self:_notify("No config selected", 2)
                end
                pcall(writefile, self.Folder .. "/autoload.txt", selectedConfig)
                autoloadLabel:Text("Autoload: " .. selectedConfig)
                self:_notify(string.format('Set "%s" to auto load', selectedConfig))
            end)

            tab:NewSeperator()

            -- Autoload label
            local autoloadText = "Autoload: none"
            local ok, name = pcall(readfile, self.Folder .. "/autoload.txt")
            if ok and name and name ~= "" then
                autoloadText = "Autoload: " .. name
            end
            local autoloadLabel = tab:NewLabel(autoloadText, "left")
            SaveManager.AutoloadLabel = autoloadLabel
        end

        SaveManager:BuildFolderTree()
    end

    return SaveManager
end)()
