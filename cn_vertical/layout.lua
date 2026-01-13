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

-- @param page_columns (number) Total columns before a page break
-- @param params (table) Optional parameters:
--   - distribute (boolean) If true, distribute nodes evenly in columns
-- @return (table, number) layout_map (node_ptr -> {page, col, row}), total_pages
local function calculate_grid_positions(head, grid_height, line_limit, n_column, page_columns, params)
    local d_head = D.todirect(head)
    params = params or {}
    local distribute = params.distribute

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
    
    -- Buffer for distribution mode
    local col_buffer = {}

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

    local function flush_buffer()
        if #col_buffer == 0 then return end
        
        local N = #col_buffer
        local H = line_limit -- For inner layout, line_limit is total rows
        
        for i, entry in ipairs(col_buffer) do
            local row
            if distribute and N > 1 and N < H then
                -- Evenly distribute with sub-grid precision: Row = (i-1) * (H-1)/(N-1)
                row = (i-1) * (H-1) / (N-1)
            else
                row = entry.relative_row
            end
            
            layout_map[entry.node] = {
                page = entry.page, 
                col = entry.col, 
                row = row,
                is_block = entry.is_block,
                width = entry.width,
                height = entry.height
            }
        end
        col_buffer = {}
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
            flush_buffer()
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
            if cur_row + tb_h > effective_limit then
                flush_buffer()
                cur_col = cur_col + 1
                cur_row = 0
                if cur_col >= p_cols then
                    cur_col = 0
                    cur_page = cur_page + 1
                end
                skip_banxin_and_occupied()
            end
            
            local fits_width = true
            for c = cur_col, cur_col + tb_w - 1 do
                if is_banxin_col(c) or (c >= p_cols) then
                    fits_width = false
                    break
                end
            end
            
            if not fits_width then
                flush_buffer()
                cur_col = cur_col + 1
                cur_row = 0
                if cur_col >= p_cols then
                    cur_col = 0
                    cur_page = cur_page + 1
                end
                skip_banxin_and_occupied()
            end

            for c = cur_col, cur_col + tb_w - 1 do
                for r = cur_row, cur_row + tb_h - 1 do
                    mark_occupied(cur_page, c, r)
                end
            end

            table.insert(col_buffer, {node=t, page=cur_page, col=cur_col, relative_row=cur_row, is_block=true, width=tb_w, height=tb_h})
            cur_row = cur_row + tb_h
            skip_banxin_and_occupied()

        elseif id == constants.GLYPH then
            table.insert(col_buffer, {node=t, page=cur_page, col=cur_col, relative_row=cur_row})
            cur_row = cur_row + 1
            skip_banxin_and_occupied()
        elseif id == constants.GLUE then
             local subtype = D.getsubtype(t)
             local w = D.getfield(t, "width")
             if w > 0 and (subtype == 13 or subtype == 14) then
                 table.insert(col_buffer, {node=t, page=cur_page, col=cur_col, relative_row=cur_row})
                 cur_row = cur_row + 1
                 skip_banxin_and_occupied()
             end
        elseif id == constants.PENALTY and D.getfield(t, "penalty") <= -10000 then
             flush_buffer()
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
    
    flush_buffer()

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
