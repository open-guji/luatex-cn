-- cn_vertical_layout.lua
-- Chinese vertical typesetting module for LuaTeX - Grid Layout Calculation
--
-- This module is part of the cn_vertical package.
-- For documentation, see cn_vertical/README.md
--
-- Module: layout
-- Purpose: Calculate grid positions for each node (first pass simulation)
-- Dependencies: cn_vertical_constants
-- Exports: calculate_grid_positions function
-- Version: 0.3.0
-- Date: 2026-01-12

-- Load dependencies
-- Check if already loaded via dofile (package.loaded set manually)
local constants = package.loaded['constants'] or require('constants')
local D = constants.D

--- Calculate grid positions for nodes
-- Performs first-pass layout simulation to determine (col, row) coordinates for each node.
-- Handles column wrapping, hanging indents, and left/right indentation.
--
-- @param head (node) Head of flattened node list
-- @param grid_height (number) Grid row height in scaled points
-- @param line_limit (number) Maximum rows per column
-- @param n_column (number) Number of columns per page/section (defines Banxin gap)
-- @param page_columns (number) Total columns before a page break
-- @return (table, number) layout_map (node_ptr -> {page, col, row}), total_pages
local function calculate_grid_positions(head, grid_height, line_limit, n_column, page_columns)
    local d_head = D.todirect(head)

    if line_limit < 1 then line_limit = 20 end

    local interval = tonumber(n_column) or 0
    local p_cols = tonumber(page_columns) or (2 * interval + 1)
    if p_cols <= 0 then p_cols = 10000 end -- Safety

    -- Stateful cursor layout
    local cur_page = 0
    local cur_col = 0
    local cur_row = 0
    local simulated_max_col = 0
    local cur_column_indent = 0
    local layout_map = {}

    local function is_banxin_col(col)
        if interval <= 0 then return false end
        -- Banxin is the (interval+1)-th column (0-indexed: index == interval)
        return (col % (interval + 1)) == interval
    end

    local function skip_banxin()
        while is_banxin_col(cur_col) do
            cur_col = cur_col + 1
            if cur_col >= p_cols then
                cur_col = 0
                cur_page = cur_page + 1
            end
        end
    end

    local t = d_head

    -- Initial check for first column (index 0)
    skip_banxin()

    while t do
        local id = D.getid(t)
        local indent = D.get_attribute(t, constants.ATTR_INDENT) or 0
        local r_indent = D.get_attribute(t, constants.ATTR_RIGHT_INDENT) or 0

        -- Hanging indent logic (Top indent)
        -- Apply indent if it's higher than current position
        if cur_row < indent then
            cur_row = indent
        end
        -- Track the column's base indent for hanging
        if indent > cur_column_indent then
            cur_column_indent = indent
        end
        -- Ensure we maintain at least the column_indent
        if cur_row < cur_column_indent then
            cur_row = cur_column_indent
        end

        -- Calculate effective row limit for this node
        local effective_limit = line_limit - r_indent
        if effective_limit < indent + 1 then effective_limit = indent + 1 end -- Safety

        -- Check wrapping BEFORE placing
        -- If current row is already beyond limit (e.g. slight overflow), we should wrap.
        if cur_row >= effective_limit then
            cur_col = cur_col + 1
            cur_row = 0
            
            -- Check page break
            if cur_col >= p_cols then
                cur_col = 0
                cur_page = cur_page + 1
            end

            -- Reset column indent for new column
            cur_column_indent = indent
            -- Re-apply top indent for new column
            if cur_row < indent then cur_row = indent end

            -- Skip Banxin column
            skip_banxin()
        end

        if id == constants.GLYPH then
            layout_map[t] = {page=cur_page, col=cur_col, row=cur_row}
            cur_row = cur_row + 1
        elseif id == constants.GLUE then
             -- In vertical layout, glue represents horizontal space in the original layout
             -- We convert it to vertical offset, but it should not increment row like a glyph
             -- Only spaceskip and xspaceskip should advance position
             local subtype = D.getsubtype(t)
             local w = D.getfield(t, "width")
             -- Only advance for actual inter-word spaces (spaceskip=13, xspaceskip=14)
             -- NOT for userskip (0) which might be structural spacing
             if w > 0 and (subtype == 13 or subtype == 14) then
                 cur_row = cur_row + 1
             end
        elseif id == constants.PENALTY and D.getfield(t, "penalty") <= -10000 then
             -- Forced break
             if cur_row > 0 then
                 cur_col = cur_col + 1
                 cur_row = 0
                 
                 -- Check page break
                 if cur_col >= p_cols then
                     cur_col = 0
                     cur_page = cur_page + 1
                 end

                 cur_column_indent = 0 -- Reset column indent for next column
                 skip_banxin()
             end
        end

        t = D.getnext(t)
    end

    local total_pages = cur_page + 1

    return layout_map, total_pages
end

-- Create module table
local layout = {
    calculate_grid_positions = calculate_grid_positions,
}

-- Register module in package.loaded for require() compatibility
package.loaded['layout'] = layout

-- Return module exports
return layout
