-- text_position.lua
-- Chinese vertical typesetting module for LuaTeX - Unified Text Positioning
--
-- This module is part of the cn_vertical package.
-- For documentation, see cn_vertical/README.md
--
-- Module: text_position
-- Purpose: Unified functions for positioning text characters in vertical layout
-- Dependencies: constants
-- Version: 0.1.0
-- Date: 2026-01-13

-- Load dependencies
local constants = package.loaded['constants'] or require('constants')
local D = constants.D

--- Position a single glyph node at the specified coordinates
-- This is the core function for placing a character at an exact position.
-- It sets xoffset/yoffset and creates a negative kern to stack characters.
--
-- @param glyph_direct (node) Direct glyph node to position
-- @param x (number) X position in scaled points (left edge of cell)
-- @param y (number) Y position in scaled points (top edge of cell, negative downward)
-- @param params (table) Parameters:
--   - cell_width (number) Width of the cell for horizontal centering
--   - cell_height (number) Height of the cell for vertical centering
--   - h_align (string) Horizontal alignment: "left", "center", "right" (default: "center")
--   - v_align (string) Vertical alignment: "top", "center", "bottom" (default: "center")
-- @return (node, node) The glyph node and the negative kern node (both direct nodes)
local function position_glyph(glyph_direct, x, y, params)
    params = params or {}
    local cell_width = params.cell_width or 0
    local cell_height = params.cell_height or 0
    local h_align = params.h_align or "center"
    local v_align = params.v_align or "center"

    -- Get glyph dimensions
    local g_width = D.getfield(glyph_direct, "width") or 0
    local g_height = D.getfield(glyph_direct, "height") or 0
    local g_depth = D.getfield(glyph_direct, "depth") or 0

    -- Calculate horizontal offset based on alignment
    local x_offset
    if h_align == "left" then
        x_offset = x
    elseif h_align == "right" then
        x_offset = x + cell_width - g_width
    else -- center
        x_offset = x + (cell_width - g_width) / 2
    end

    -- Calculate vertical offset based on alignment
    local char_total_height = g_height + g_depth
    local y_offset
    if v_align == "top" then
        y_offset = y - g_height
    elseif v_align == "bottom" then
        y_offset = y - cell_height + g_depth
    else -- center
        y_offset = y - (cell_height + char_total_height) / 2 + g_depth
    end

    -- Apply offsets
    D.setfield(glyph_direct, "xoffset", x_offset)
    D.setfield(glyph_direct, "yoffset", y_offset)

    -- Create protected negative kern (subtype 1 = explicit kern, won't be zeroed)
    local kern = D.new(constants.KERN)
    D.setfield(kern, "subtype", 1)
    D.setfield(kern, "kern", -g_width)

    -- Link glyph to kern
    D.setlink(glyph_direct, kern)

    return glyph_direct, kern
end

--- Create a vertical column of text characters
-- Arranges characters from top to bottom in a single column.
-- This is used for banxin text and can be used for any vertical text block.
--
-- @param text (string) UTF-8 text to render
-- @param params (table) Parameters:
--   - x (number) X position of the column left edge (sp)
--   - y_top (number) Y position of the column top edge (sp, negative downward)
--   - width (number) Column width for horizontal centering (sp)
--   - height (number) Total height of the text area (sp)
--   - num_cells (number) Optional: number of cells (default: number of characters)
--   - v_align (string) Vertical alignment within each cell: "top", "center", "bottom"
--   - h_align (string) Horizontal alignment within column: "left", "center", "right"
--   - font_id (number) Optional: font ID (default: current font)
--   - shift_y (number) Optional: additional Y shift (sp)
-- @return (node) Head of the linked node chain (direct node), or nil if no text
local function create_vertical_text(text, params)
    if not text or text == "" then
        return nil
    end

    -- Parse UTF-8 characters
    local chars = {}
    for char in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        table.insert(chars, char)
    end

    local num_chars = #chars
    if num_chars == 0 then
        return nil
    end

    local x = params.x or 0
    local y_top = params.y_top or 0
    local width = params.width or 0
    local height = params.height or 0
    local num_cells = params.num_cells or num_chars
    local v_align = params.v_align or "center"
    local h_align = params.h_align or "center"
    local font_id = params.font_id or font.current()
    local shift_y = params.shift_y or 0

    -- Calculate cell height
    local cell_height = height / num_cells

    local head = nil
    local tail = nil

    for i, char in ipairs(chars) do
        -- Create glyph node
        local glyph = node.new(node.id("glyph"))
        glyph.char = utf8.codepoint(char)
        glyph.font = font_id
        glyph.lang = 0

        local glyph_direct = D.todirect(glyph)

        -- Calculate cell position (0-indexed row)
        local row = i - 1
        local cell_y = y_top - row * cell_height - shift_y

        -- Position the glyph
        local _, kern = position_glyph(glyph_direct, x, cell_y, {
            cell_width = width,
            cell_height = cell_height,
            h_align = h_align,
            v_align = v_align,
        })

        -- Build the chain
        if head == nil then
            head = glyph_direct
            tail = kern
        else
            D.setlink(tail, glyph_direct)
            tail = kern
        end
    end

    return head
end

--- Position a glyph in a grid cell (used by main text rendering)
-- This is a convenience wrapper for positioning glyphs in a column/row grid.
--
-- @param glyph_direct (node) Direct glyph node to position
-- @param col (number) Column index (0-indexed, RTL will be handled by caller)
-- @param row (number) Row index (0-indexed)
-- @param params (table) Parameters:
--   - grid_width (number) Width of each grid cell (sp)
--   - grid_height (number) Height of each grid cell (sp)
--   - total_cols (number) Total number of columns (for RTL calculation)
--   - shift_x (number) X shift for margins/borders (sp)
--   - shift_y (number) Y shift for margins/borders (sp)
--   - v_align (string) Vertical alignment: "top", "center", "bottom"
--   - half_thickness (number) Half of border thickness (sp)
-- @return (node, node) The glyph node and the negative kern node
local function position_glyph_in_grid(glyph_direct, col, row, params)
    local grid_width = params.grid_width or 0
    local grid_height = params.grid_height or 0
    local total_cols = params.total_cols or 1
    local shift_x = params.shift_x or 0
    local shift_y = params.shift_y or 0
    local v_align = params.v_align or "center"
    local half_thickness = params.half_thickness or 0

    -- Calculate RTL column position
    local rtl_col = total_cols - 1 - col

    -- Calculate cell position
    local cell_x = rtl_col * grid_width + half_thickness + shift_x
    local cell_y = -row * grid_height - shift_y

    return position_glyph(glyph_direct, cell_x, cell_y, {
        cell_width = grid_width,
        cell_height = grid_height,
        h_align = "center",
        v_align = v_align,
    })
end

--- Calculate grid position coordinates (pure calculation, no node manipulation)
-- This is used by render.lua for main text positioning where nodes are modified in-place.
--
-- @param col (number) Column index (0-indexed)
-- @param row (number) Row index (0-indexed)
-- @param glyph_dims (table) Glyph dimensions: width, height, depth
-- @param params (table) Parameters:
--   - grid_width (number) Width of each grid cell (sp)
--   - grid_height (number) Height of each grid cell (sp)
--   - total_cols (number) Total number of columns (for RTL calculation)
--   - shift_x (number) X shift for margins/borders (sp)
--   - shift_y (number) Y shift for margins/borders (sp)
--   - v_align (string) Vertical alignment: "top", "center", "bottom"
--   - half_thickness (number) Half of border thickness (sp)
-- @return (number, number) x_offset, y_offset for the glyph
local function calc_grid_position(col, row, glyph_dims, params)
    local grid_width = params.grid_width or 0
    local grid_height = params.grid_height or 0
    local total_cols = params.total_cols or 1
    local shift_x = params.shift_x or 0
    local shift_y = params.shift_y or 0
    local v_align = params.v_align or "center"
    local half_thickness = params.half_thickness or 0

    local w = glyph_dims.width or 0
    local h = glyph_dims.height or 0
    local d = glyph_dims.depth or 0

    -- Calculate RTL column position
    local rtl_col = total_cols - 1 - col

    -- Calculate X offset (horizontally centered in cell)
    local x_offset = rtl_col * grid_width + (grid_width - w) / 2 + half_thickness + shift_x

    -- Calculate Y offset based on vertical alignment
    local y_offset
    if v_align == "top" then
        y_offset = -row * grid_height - h - shift_y
    elseif v_align == "center" then
        local char_total_height = h + d
        y_offset = -row * grid_height - (grid_height + char_total_height) / 2 + d - shift_y
    else -- bottom
        y_offset = -row * grid_height - grid_height + d - shift_y
    end

    return x_offset, y_offset
end

-- Create module table
local text_position = {
    position_glyph = position_glyph,
    create_vertical_text = create_vertical_text,
    position_glyph_in_grid = position_glyph_in_grid,
    calc_grid_position = calc_grid_position,
}

-- Register module in package.loaded for require() compatibility
package.loaded['text_position'] = text_position

-- Return module exports
return text_position

