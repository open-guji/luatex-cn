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
    local cur_column_indent = 0
    local layout_map = {}
    
    -- Occupancy map: occupancy[page][col][row] = true
    local occupancy = {}

    local function is_banxin_col(col)
        if interval <= 0 then return false end
        return (col % (interval + 1)) == interval
    end

    local function is_occupied(p, c, r)
        if not occupancy[p] then return false end
        if not occupancy[p][c] then return false end
        return occupancy[p][c][r] == true
    end

    local function mark_occupied(p, c, r)
        if not occupancy[p] then occupancy[p] = {} end
        if not occupancy[p][c] then occupancy[p][c] = {} end
        occupancy[p][c][r] = true
    end

    local function skip_banxin_and_occupied()
        local changed = true
        while changed do
            changed = false
            -- Skip Banxin
            while is_banxin_col(cur_col) do
                cur_col = cur_col + 1
                if cur_col >= p_cols then
                    cur_col = 0
                    cur_page = cur_page + 1
                end
                changed = true
            end
            -- Skip Occupied
            if is_occupied(cur_page, cur_col, cur_row) then
                cur_row = cur_row + 1
                if cur_row >= line_limit then
                    cur_row = 0
                    cur_col = cur_col + 1
                    changed = true
                else
                    -- Check again if new row is banxin or occupied
                    changed = true
                end
            end
        end
    end

    local t = d_head
    skip_banxin_and_occupied()

    while t do
        local id = D.getid(t)
        local indent = D.get_attribute(t, constants.ATTR_INDENT) or 0
        local r_indent = D.get_attribute(t, constants.ATTR_RIGHT_INDENT) or 0
        
        -- Textbox attributes; ONLY treat HLIST/VLIST as blocks
        local tb_w = 0
        local tb_h = 0
        if id == constants.HLIST or id == constants.VLIST then
            tb_w = D.get_attribute(t, constants.ATTR_TEXTBOX_WIDTH) or 0
            tb_h = D.get_attribute(t, constants.ATTR_TEXTBOX_HEIGHT) or 0
        end

        -- Hanging indent logic (only for regular glyphs/glue)
        if tb_w == 0 then
            if cur_row < indent then cur_row = indent end
            if indent > cur_column_indent then cur_column_indent = indent end
            if cur_row < cur_column_indent then cur_row = cur_column_indent end
        end

        local effective_limit = line_limit - r_indent
        if effective_limit < indent + 1 then effective_limit = indent + 1 end

        -- Check wrapping BEFORE placing
        if cur_row >= effective_limit then
            cur_col = cur_col + 1
            cur_row = 0
            if cur_col >= p_cols then
                cur_col = 0
                cur_page = cur_page + 1
            end
            cur_column_indent = indent
            if cur_row < indent then cur_row = indent end
            skip_banxin_and_occupied()
        end

        if tb_w > 0 and tb_h > 0 then
            -- Handle Textbox Block
            -- 1. Check if it fits in current column height
            if cur_row + tb_h > effective_limit then
                -- Wrap to next column
                cur_col = cur_col + 1
                cur_row = 0
                if cur_col >= p_cols then
                    cur_col = 0
                    cur_page = cur_page + 1
                end
                skip_banxin_and_occupied()
            end
            
            -- 2. Check if it overlaps with Banxin (if width > 1)
            local fits_width = true
            for c = cur_col, cur_col + tb_w - 1 do
                if is_banxin_col(c) or (c >= p_cols) then
                    fits_width = false
                    break
                end
            end
            
            if not fits_width then
                -- Move to next available column start
                cur_col = cur_col + 1
                cur_row = 0
                if cur_col >= p_cols then
                    cur_col = 0
                    cur_page = cur_page + 1
                end
                skip_banxin_and_occupied()
            end

            -- 3. Mark all cells as occupied
            for c = cur_col, cur_col + tb_w - 1 do
                for r = cur_row, cur_row + tb_h - 1 do
                    mark_occupied(cur_page, c, r)
                end
            end

            -- 4. Assign position
            layout_map[t] = {page=cur_page, col=cur_col, row=cur_row, is_block=true, width=tb_w, height=tb_h}
            
            -- 5. Move cursor
            skip_banxin_and_occupied()

        elseif id == constants.GLYPH then
            layout_map[t] = {page=cur_page, col=cur_col, row=cur_row}
            cur_row = cur_row + 1
            skip_banxin_and_occupied()
        elseif id == constants.GLUE then
             local subtype = D.getsubtype(t)
             local w = D.getfield(t, "width")
             if w > 0 and (subtype == 13 or subtype == 14) then
                 -- Assign position to glue so it's not discarded by render.lua
                 layout_map[t] = {page=cur_page, col=cur_col, row=cur_row}
                 cur_row = cur_row + 1
                 skip_banxin_and_occupied()
             end
        elseif id == constants.PENALTY and D.getfield(t, "penalty") <= -10000 then
             if cur_row > 0 then
                 cur_col = cur_col + 1
                 cur_row = 0
                 if cur_col >= p_cols then
                     cur_col = 0
                     cur_page = cur_page + 1
                 end
                 cur_column_indent = 0
                 skip_banxin_and_occupied()
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
