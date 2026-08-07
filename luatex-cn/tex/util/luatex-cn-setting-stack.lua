-- Copyright 2026 Open-Guji (https://github.com/open-guji)
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- ============================================================================
-- luatex-cn-setting-stack.lua - Setting Stack for Component-Level Configuration
-- ============================================================================
-- Manages semantic settings (punct_mode, punct_style) that affect how text
-- content is processed, as opposed to the style stack which only affects
-- visual appearance.
--
-- Settings propagate via a stack: global defaults → component overrides.
-- Each component (sidenote, textbox, pizhu, etc.) can push overrides
-- before processing content, then pop afterward.
-- ============================================================================

local setting_stack = {}

-- Initialize global setting stack
if not _G.setting_stack then
    _G.setting_stack = {
        stack = {},   -- [{punct_mode="judou", ...}, ...]
    }
end

-- All known setting keys with their default values.
-- Components only need to push keys they want to override.
local DEFAULTS = {
    punct_mode  = "normal",   -- "normal" / "judou" / "none"
    punct_style = "mainland", -- "mainland" / "taiwan"
    debug       = false,      -- true / false
}

--- Push overrides onto the stack.
-- Missing keys inherit from parent (stack top) or global defaults.
-- @param overrides (table|nil) Keys to override, e.g. {punct_mode="normal"}
-- @return (table) The effective settings after push
function setting_stack.push(overrides)
    overrides = overrides or {}
    local parent = setting_stack.current()

    local new_entry = {}
    for k, default_v in pairs(DEFAULTS) do
        if overrides[k] ~= nil and overrides[k] ~= "" then
            new_entry[k] = overrides[k]
        else
            -- Use explicit nil check (not `or`) to handle false values correctly
            local pv = parent[k]
            new_entry[k] = (pv ~= nil) and pv or default_v
        end
    end

    table.insert(_G.setting_stack.stack, new_entry)
    return new_entry
end

--- Pop the top entry from the stack.
-- @return (table|nil) The popped entry, or nil if stack was empty
function setting_stack.pop()
    return table.remove(_G.setting_stack.stack)
end

--- Get the current effective settings (stack top or defaults).
-- @return (table) Current settings table (never nil)
function setting_stack.current()
    local stack = _G.setting_stack.stack
    if #stack > 0 then
        return stack[#stack]
    end
    -- Return a copy of defaults
    local result = {}
    for k, v in pairs(DEFAULTS) do
        result[k] = v
    end
    -- Also check _G.judou for global overrides set by \judouSetup
    if _G.judou and _G.judou.punct_mode and _G.judou.punct_mode ~= "" then
        result.punct_mode = _G.judou.punct_mode
    end
    if _G.punct and _G.punct.style and _G.punct.style ~= "" then
        result.punct_style = _G.punct.style
    end
    -- Check global debug state
    if _G.luatex_cn_debug and _G.luatex_cn_debug.global_enabled then
        result.debug = true
    end
    return result
end

--- Get the current value of a specific setting.
-- @param key (string) Setting key name
-- @return (any) Current value
function setting_stack.get(key)
    return setting_stack.current()[key]
end

--- Clear the stack (for testing or document reset).
function setting_stack.clear()
    _G.setting_stack = {
        stack = {},
    }
end

-- Register module
package.loaded['util.luatex-cn-setting-stack'] = setting_stack

return setting_stack
