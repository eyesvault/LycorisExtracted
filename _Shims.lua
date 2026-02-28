--[[
    _Shims.lua
    ──────────
    Lycoris-Rewrite uses the Luraph obfuscator and a custom Lua preprocessor.
    This file defines all preprocessor macros / obfuscator directives as plain
    Lua identity functions so the extracted modules run without modification.

    Call this file ONCE before loading any other module, e.g.:
        loadstring(readfile("LycorisExtracted/_Shims.lua"))()
    or simply paste its contents at the top of your loader.
]]

-- Luraph "no-virtualize" directive — just returns the function as-is.
LPH_NO_VIRTUALIZE = function(f) return f end

-- Preprocessor string scrambler — identity at runtime.
PP_SCRAMBLE_STR = function(s) return s end

-- Preprocessor number scrambler — identity at runtime.
PP_SCRAMBLE_NUM = function(n) return n end

-- Preprocessor "re-encrypt number" (used inside RPUE/module paths) — identity.
PP_SCRAMBLE_RE_NUM = function(n) return n end

-- LRM_UserNote is set by the preprocessor to identify release builds.
-- nil = developer / verbose mode (shows full action type names in logs).
LRM_UserNote = nil

-- shared.Lycoris is expected by Logger / Profiler.
-- silent = true suppresses all warn() output (useful in release builds).
if not shared.Lycoris then
    shared.Lycoris = { silent = false }
end
