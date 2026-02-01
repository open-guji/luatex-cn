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
-- luatex-cn-style-registry.lua - Style Registry for Multi-Attribute Preservation
-- ============================================================================
-- This module provides a global registry to map style IDs to style objects
-- containing multiple attributes (color, font_size, grid_height, etc.).
-- Used in conjunction with ATTR_STYLE_REG_ID to preserve styles across
-- page boundaries.
--
-- Phase 2 of the Context System Design (doc/context-system-design.md)
-- ============================================================================

local style_registry = {}

-- Initialize global registry
if not _G.style_registry then
    _G.style_registry = {
        next_id = 1,
        styles = {},         -- id -> {color, font_size, grid_height, ...}
        style_to_id = {},    -- reverse lookup for deduplication (serialized style -> id)
        stack = {},          -- [id1, id2, ...] stack of active style IDs (Phase 3)
    }
end

--- Serialize a style table to a string for deduplication
-- @param style (table) Style table
-- @return (string) Serialized representation
local function serialize_style(style)
    if not style then return "" end

    local parts = {}
    -- Sort keys for consistent serialization
    local keys = {}
    for k in pairs(style) do
        table.insert(keys, k)
    end
    table.sort(keys)

    for _, k in ipairs(keys) do
        local v = style[k]
        if v ~= nil then
            table.insert(parts, string.format("%s=%s", k, tostring(v)))
        end
    end

    return table.concat(parts, ";")
end

--- Register a style and return its ID
-- @param style (table) Style table with any of: color, font_size, grid_height, etc.
-- @return (number|nil) Style ID, or nil if style is empty/nil
function style_registry.register(style)
    if not style or next(style) == nil then
        return nil
    end

    -- Serialize style for deduplication
    local serialized = serialize_style(style)

    -- Check if style already registered (deduplication)
    if _G.style_registry.style_to_id[serialized] then
        return _G.style_registry.style_to_id[serialized]
    end

    -- Register new style (make a copy to avoid mutation)
    local id = _G.style_registry.next_id
    local style_copy = {}
    for k, v in pairs(style) do
        style_copy[k] = v
    end

    _G.style_registry.styles[id] = style_copy
    _G.style_registry.style_to_id[serialized] = id
    _G.style_registry.next_id = id + 1

    return id
end

--- Get style object by ID
-- @param id (number) Style ID
-- @return (table|nil) Style table, or nil if ID not found
function style_registry.get(id)
    if not id then return nil end
    return _G.style_registry.styles[id]
end

--- Get a specific attribute from style by ID
-- @param id (number) Style ID
-- @param attr (string) Attribute name (e.g., "font_color", "font_size")
-- @return (any|nil) Attribute value, or nil if not found
function style_registry.get_attr(id, attr)
    local style = style_registry.get(id)
    if not style then return nil end
    return style[attr]
end

--- Get font color from style
-- @param id (number) Style ID
-- @return (string|nil) Font color string, or nil if not found
function style_registry.get_font_color(id)
    return style_registry.get_attr(id, "font_color")
end

--- Get font size from style
-- @param id (number) Style ID
-- @return (number|nil) Font size in sp (scaled points), or nil if not found
function style_registry.get_font_size(id)
    return style_registry.get_attr(id, "font_size")
end

--- Get font name/family from style
-- @param id (number) Style ID
-- @return (string|nil) Font name/family, or nil if not found
function style_registry.get_font(id)
    return style_registry.get_attr(id, "font")
end

--- Get indent from style
-- @param id (number) Style ID
-- @return (number|nil) Indent value (grid units), or nil if not found
function style_registry.get_indent(id)
    return style_registry.get_attr(id, "indent")
end

--- Get first indent from style
-- @param id (number) Style ID
-- @return (number|nil) First indent value (grid units), or nil if not found
function style_registry.get_first_indent(id)
    return style_registry.get_attr(id, "first_indent")
end

--- Get border setting from style
-- @param id (number) Style ID
-- @return (boolean|nil) Border setting, or nil if not found
function style_registry.get_border(id)
    return style_registry.get_attr(id, "border")
end

--- Get border width from style
-- @param id (number) Style ID
-- @return (string|nil) Border width (e.g., "0.4pt"), or nil if not found
function style_registry.get_border_width(id)
    return style_registry.get_attr(id, "border_width")
end

--- Get border color from style
-- @param id (number) Style ID
-- @return (string|nil) Border color RGB string, or nil if not found
function style_registry.get_border_color(id)
    return style_registry.get_attr(id, "border_color")
end

--- Get outer border setting from style
-- @param id (number) Style ID
-- @return (boolean|nil) Outer border setting, or nil if not found
function style_registry.get_outer_border(id)
    return style_registry.get_attr(id, "outer_border")
end

-- ============================================================================
-- Style Stack Functions (Phase 3: Style Inheritance)
-- ============================================================================

--- Get current style ID from stack top
-- @return (number|nil) Current style ID, or nil if stack is empty
function style_registry.current_id()
    local stack = _G.style_registry.stack
    return stack[#stack]
end

--- Get current style from stack top
-- @return (table|nil) Current style table, or nil if stack is empty
function style_registry.current()
    local id = style_registry.current_id()
    return style_registry.get(id)
end

--- Push a new style with inheritance from current style
-- @param overrides (table) Style attributes to set/override
-- @return (number) New style ID
function style_registry.push(overrides)
    overrides = overrides or {}

    -- Get parent style (from stack top)
    local parent = style_registry.current() or {}

    -- Merge: inherit from parent + override with new values
    local new_style = {}
    for k, v in pairs(parent) do
        new_style[k] = v
    end
    for k, v in pairs(overrides) do
        new_style[k] = v
    end

    -- Register merged style (with deduplication)
    local id = style_registry.register(new_style)

    -- Push ID to stack
    table.insert(_G.style_registry.stack, id)

    return id
end

--- Pop current style from stack
-- @return (number|nil) Popped style ID, or nil if stack was empty
function style_registry.pop()
    return table.remove(_G.style_registry.stack)
end

--- Clear the registry (useful for testing or document end)
function style_registry.clear()
    _G.style_registry = {
        next_id = 1,
        styles = {},
        style_to_id = {},
        stack = {},
    }
end

--- Get registry statistics (for debugging)
-- @return (table) { total_styles, next_id }
function style_registry.stats()
    local count = 0
    for _ in pairs(_G.style_registry.styles) do
        count = count + 1
    end
    return {
        total_styles = count,
        next_id = _G.style_registry.next_id,
    }
end

-- Register module
package.loaded['util.luatex-cn-style-registry'] = style_registry

return style_registry
