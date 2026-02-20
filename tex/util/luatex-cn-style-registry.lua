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

--- Get outer border thickness from style
-- @param id (number) Style ID
-- @return (number|nil) Outer border thickness in sp, or nil if not found
function style_registry.get_outer_border_thickness(id)
    return style_registry.get_attr(id, "outer_border_thickness")
end

--- Get outer border separation from style
-- @param id (number) Style ID
-- @return (number|nil) Outer border separation in sp, or nil if not found
function style_registry.get_outer_border_sep(id)
    return style_registry.get_attr(id, "outer_border_sep")
end

--- Get background color from style
-- @param id (number) Style ID
-- @return (string|nil) Background color RGB string, or nil if not found
function style_registry.get_background_color(id)
    return style_registry.get_attr(id, "background_color")
end

--- Get border shape from style
-- @param id (number) Style ID
-- @return (string|nil) Border shape ("none", "rect", "octagon", "circle"), or nil if not found
function style_registry.get_border_shape(id)
    return style_registry.get_attr(id, "border_shape")
end

--- Get border margin from style
-- @param id (number) Style ID
-- @return (string|nil) Border margin value (e.g., "1pt"), or nil if not found
function style_registry.get_border_margin(id)
    return style_registry.get_attr(id, "border_margin")
end

--- Get grid height override from style
-- @param id (number) Style ID
-- @return (number|nil) Grid height in sp (nil = use default/font-based)
function style_registry.get_grid_height(id)
    return style_registry.get_attr(id, "grid_height")
end

--- Get cell width from style
-- @param id (number) Style ID
-- @return (number|nil) Cell width in sp (nil = use grid_width)
function style_registry.get_cell_width(id)
    return style_registry.get_attr(id, "cell_width")
end

--- Get cell gap from style
-- @param id (number) Style ID
-- @return (number|nil) Cell gap in sp, or nil
function style_registry.get_cell_gap(id)
    return style_registry.get_attr(id, "cell_gap")
end

--- Get spacing-top (column right spacing) from style
-- @param id (number) Style ID
-- @return (number|nil) Spacing-top in sp, or nil if not found
function style_registry.get_spacing_top(id)
    return style_registry.get_attr(id, "spacing_top")
end

--- Get spacing-bottom (column left spacing) from style
-- @param id (number) Style ID
-- @return (number|nil) Spacing-bottom in sp, or nil if not found
function style_registry.get_spacing_bottom(id)
    return style_registry.get_attr(id, "spacing_bottom")
end

--- Get column width from style
-- @param id (number) Style ID
-- @return (number|nil) Column width in sp, or nil if not found
function style_registry.get_column_width(id)
    return style_registry.get_attr(id, "column_width")
end

--- Get xshift from style
-- @param id (number) Style ID
-- @return (number|table|nil) xshift value (sp number or {value,unit} table), or nil
function style_registry.get_xshift(id)
    return style_registry.get_attr(id, "xshift")
end

--- Get yshift from style
-- @param id (number) Style ID
-- @return (number|table|nil) yshift value (sp number or {value,unit} table), or nil
function style_registry.get_yshift(id)
    return style_registry.get_attr(id, "yshift")
end

--- Get auto-width setting from style
-- @param id (number) Style ID
-- @return (boolean|nil) Auto-width setting, or nil if not found
function style_registry.get_auto_width(id)
    return style_registry.get_attr(id, "auto_width")
end

--- Get width-scale from style
-- @param id (number) Style ID
-- @return (number|nil) Width scale factor, or nil if not found
function style_registry.get_width_scale(id)
    return style_registry.get_attr(id, "width_scale")
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

--- Push indent style (convenience function for Paragraph environment)
-- @param indent (number) Base indent value (grid units)
-- @param first_indent (number) First line indent, -1 means use indent value
-- @param temporary (boolean) Whether this is a temporary indent (auto-pop on column change)
-- @return (number) New style ID
function style_registry.push_indent(indent, first_indent, temporary)
    indent = tonumber(indent) or 0
    first_indent = tonumber(first_indent) or -1
    if first_indent == -1 then
        first_indent = indent
    end
    local style = {
        indent = indent,
        first_indent = first_indent
    }
    if temporary then
        style.temporary = true
    end
    return style_registry.push(style)
end

--- Pop current style from stack
-- @return (number|nil) Popped style ID, or nil if stack was empty
function style_registry.pop()
    return table.remove(_G.style_registry.stack)
end

--- Pop all temporary styles from stack (called on column change)
-- @return (number) Number of temporary styles popped
function style_registry.pop_temporary()
    local count = 0
    while true do
        local id = style_registry.current_id()
        if not id then break end

        local style = style_registry.get(id)
        if not style or not style.temporary then
            break
        end

        style_registry.pop()
        count = count + 1
    end
    return count
end

--- Push a content style with common font parameters
-- Handles font_color, font_size (string → sp conversion), font name.
-- @param font_color (string|nil)
-- @param font_size (string|nil) e.g., "14pt"
-- @param font (string|nil)
-- @param extra (table|nil) Additional style fields (textflow_align, auto_balance, grid_height, etc.)
-- @return (number) Style ID (always a valid number)
function style_registry.push_content_style(font_color, font_size, font, extra)
    local constants_mod = package.loaded['core.luatex-cn-constants'] or
        require('core.luatex-cn-constants')
    local style = {}
    if font_color and font_color ~= "" then
        style.font_color = font_color
    end
    if font_size and font_size ~= "" then
        style.font_size = constants_mod.to_dimen(font_size)
    end
    if font and font ~= "" then
        style.font = font
    end
    if extra then
        for k, v in pairs(extra) do
            style[k] = v
        end
    end
    return style_registry.push(style) or 0
end

--- Build an extra table from optional grid_height, spacing_top, spacing_bottom, xshift, yshift strings
--- Convenience helper for TeX→Lua calls where table construction in expl3 is awkward.
-- @param grid_height (string|nil) e.g., "1.5em"
-- @param spacing_top (string|nil) e.g., "5pt"
-- @param spacing_bottom (string|nil) e.g., "5pt"
-- @param xshift (string|nil) e.g., "-0.3em"
-- @param yshift (string|nil) e.g., "0.5em"
-- @return (table|nil) Extra table for push_content_style, or nil if all params are nil
function style_registry.make_extra(grid_height, spacing_top, spacing_bottom, xshift, yshift)
    local constants_mod = package.loaded['core.luatex-cn-constants'] or
        require('core.luatex-cn-constants')
    local extra = {}
    local has_any = false
    if grid_height and grid_height ~= "" then
        extra.grid_height = constants_mod.to_dimen(grid_height)
        has_any = true
    end
    if spacing_top and spacing_top ~= "" then
        extra.spacing_top = constants_mod.to_dimen(spacing_top)
        has_any = true
    end
    if spacing_bottom and spacing_bottom ~= "" then
        extra.spacing_bottom = constants_mod.to_dimen(spacing_bottom)
        has_any = true
    end
    if xshift and xshift ~= "" then
        extra.xshift = constants_mod.to_dimen(xshift)
        has_any = true
    end
    if yshift and yshift ~= "" then
        extra.yshift = constants_mod.to_dimen(yshift)
        has_any = true
    end
    return has_any and extra or nil
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
