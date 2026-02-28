--[[
    GUI/ThemeManager.lua  —  Stub for bungie UI library
    ─────────────────────────────────────────────────────
    bungie's library has a fixed dark theme with purple accents.
    There is no colour-picker or theme system, so ThemeManager
    becomes a no-op stub that keeps Menu.lua and LycorisTab from
    erroring when they call the standard interface.

    All public methods are present and return self for chaining,
    but they do nothing.
]]

return LPH_NO_VIRTUALIZE(function()
    local ThemeManager = {}
    do
        ThemeManager.Library = nil
        ThemeManager.Folder  = "EyeExe-Themes"

        -- Called by Menu.lua / LycorisTab after window creation.
        function ThemeManager:SetLibrary(lib) self.Library = lib end
        function ThemeManager:SetFolder(folder) self.Folder = folder end

        -- Called by LycorisTab to add a section.
        -- Returns a no-op groupbox so callers don't error.
        function ThemeManager:CreateGroupBox(tab)
            -- Create a harmless section as a placeholder
            if tab and tab.NewSection then
                tab:NewSection("Theme")
                tab:NewLabel("bungie UI has a fixed dark theme. No customisation available.", "left")
            end
            return { AddColorPicker = function() return {} end,
                     AddDropdown    = function() return {} end,
                     AddDivider     = function() return {} end,
                     AddButton      = function() return {} end,
                     AddInput       = function() return {} end,
                     AddLabel       = function() return {} end }
        end

        function ThemeManager:ApplyToTab(tab)    self:CreateGroupBox(tab) end
        function ThemeManager:ApplyToGroupbox(g) end

        function ThemeManager:ApplyTheme(theme)  end
        function ThemeManager:ThemeUpdate()       end
        function ThemeManager:LoadDefault()       end
        function ThemeManager:SaveDefault(theme)  end
        function ThemeManager:GetCustomTheme(f)   return nil end
        function ThemeManager:SaveCustomTheme(f)  end
        function ThemeManager:ReloadCustomThemes() return {} end

        function ThemeManager:BuildFolderTree()
            pcall(function()
                if not isfolder(self.Folder) then
                    makefolder(self.Folder)
                end
            end)
        end

        ThemeManager:BuildFolderTree()
    end
    return ThemeManager
end)()
