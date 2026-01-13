-- cn_vertical_render.lua
-- Chinese vertical typesetting module for LuaTeX - Coordinate Application and Rendering
--
-- This module is part of the cn_vertical package.
-- For documentation, see cn_vertical/README.md
--
-- Module: render
-- Purpose: Apply calculated positions to nodes, draw debug grid and borders
-- Dependencies: cn_vertical_constants
-- Exports: apply_positions function
-- Version: 0.3.0
-- Date: 2026-01-12

-- Load dependencies
-- Check if already loaded via dofile (package.loaded set manually)
local constants = package.loaded['constants'] or require('constants')
local D = constants.D

-- Conversion factor from scaled points to PDF big points
local sp_to_bp = 0.0000152018

--- Apply grid positions to nodes and render visual aids
-- Performs second-pass coordinate application, sets xoffset/yoffset for each glyph,
-- inserts negative kerns to fix PDF text selection, and draws debug grid/borders.
--
-- @param head (node) Head of node list
-- @param layout_map (table) Mapping from node pointer to {col, row}
-- @param grid_width (number) Grid column width in scaled points
-- @param grid_height (number) Grid row height in scaled points
-- @param total_cols (number) Total number of columns
-- @param vertical_align (string) Vertical alignment: "top", "center", or "bottom"
-- @param draw_debug (boolean) Whether to draw blue debug grid
-- @param draw_border (boolean) Whether to draw black column borders
-- @param b_padding_top (number) Extra padding at top of border in scaled points
-- @param b_padding_bottom (number) Extra padding at bottom of border in scaled points
-- @param line_limit (number) Maximum rows per column
-- @param n_column (number) Number of columns per page
-- @param page_columns (number) Total columns before a page break
-- @return (table) Array of page info {head, cols}
local function apply_positions(head, layout_map, grid_width, grid_height, total_pages, vertical_align, draw_debug, draw_border, b_padding_top, b_padding_bottom, line_limit, border_thickness, draw_outer_border, outer_border_thickness, outer_border_sep, n_column, page_columns)
    local d_head = D.todirect(head)

    -- Cached conversion factors for PDF literals
    local w_bp = grid_width * sp_to_bp
    local h_bp = -grid_height * sp_to_bp
    local b_thickness_bp = border_thickness * sp_to_bp
    local half_thickness = math.floor(border_thickness / 2)
    
    local ob_thickness = (outer_border_thickness or (65536 * 2))
    local ob_thickness_bp = ob_thickness * sp_to_bp
    local ob_sep = (outer_border_sep or (65536 * 2))
    
    -- Global shift for all inner content (characters and column borders)
    -- Horizontal Shift = Outer Border Thickness + Separation
    -- Vertical Shift = Outer Border Thickness + Separation + Top Padding
    local outer_shift = draw_outer_border and (ob_thickness + ob_sep) or 0
    local shift_x = outer_shift
    local shift_y = outer_shift + b_padding_top
    
    local interval = tonumber(n_column) or 0
    local p_cols = tonumber(page_columns) or (2 * interval + 1)
    
    local function is_banxin_col(col)
        if interval <= 0 then return false end
        return (col % (interval + 1)) == interval
    end

    -- Group nodes by page
    local page_nodes = {}
    for p = 0, total_pages - 1 do
        page_nodes[p] = { head = nil, tail = nil, max_col = 0 }
    end

    local t = d_head
    while t do
        local next_node = D.getnext(t)
        local id = D.getid(t)
        
        -- Detach node from stream
        D.setnext(t, nil)
        
        local pos = layout_map[t]
        if pos then
            local p = pos.page or 0
            local col = pos.col
            
            if page_nodes[p] then
                if not page_nodes[p].head then
                    page_nodes[p].head = t
                else
                    D.setnext(page_nodes[p].tail, t)
                end
                page_nodes[p].tail = t
                if col > page_nodes[p].max_col then page_nodes[p].max_col = col end
            end
        else
            -- If node has no position (e.g. glue that was zeroed), discard it
            -- or we could attach it to page 0. Let's discard to be safe.
            -- node.flush_node(D.tonode(t))
        end
        
        t = next_node
    end

    local result_pages = {}

    -- Process each page
    for p = 0, total_pages - 1 do
        local p_head = page_nodes[p].head
        if not p_head then
            -- Create empty head if needed?
        else
            local p_max_col = page_nodes[p].max_col
            local p_total_cols = p_max_col + 1
            -- Ensure we have at least the minimum number of columns for a page if border is on
            if draw_border and p_total_cols < p_cols then p_total_cols = p_cols end

            -- Draw outer border
            if draw_outer_border and p_total_cols > 0 then
                local inner_width = p_total_cols * grid_width + border_thickness
                local inner_height = line_limit * grid_height + b_padding_top + b_padding_bottom + border_thickness
                local tx_bp = (ob_thickness / 2) * sp_to_bp
                local ty_bp = -(ob_thickness / 2) * sp_to_bp
                local tw_bp = (inner_width + ob_sep * 2 + ob_thickness) * sp_to_bp
                local th_bp = -(inner_height + ob_sep * 2 + ob_thickness) * sp_to_bp
                local literal = string.format("q %.2f w 0 0 0 RG %.4f %.4f %.4f %.4f re S Q", ob_thickness_bp, tx_bp, ty_bp, tw_bp, th_bp)
                local n_node = node.new("whatsit", "pdf_literal")
                n_node.data = literal
                n_node.mode = 0
                p_head = D.insert_before(p_head, p_head, D.todirect(n_node))
            end

            -- Draw borders
            if draw_border and p_total_cols > 0 then
                for col = 0, p_total_cols - 1 do
                    local rtl_col = p_total_cols - 1 - col
                    local tx_bp = (rtl_col * grid_width + half_thickness + shift_x) * sp_to_bp
                    local ty_bp = -(half_thickness + outer_shift) * sp_to_bp
                    local tw_bp = grid_width * sp_to_bp
                    local th_bp = -(line_limit * grid_height + b_padding_top + b_padding_bottom) * sp_to_bp
                    local literal = string.format("q %.2f w 0 0 0 RG %.4f %.4f %.4f %.4f re S Q", b_thickness_bp, tx_bp, ty_bp, tw_bp, th_bp)
                    local n_node = node.new("whatsit", "pdf_literal")
                    n_node.data = literal
                    n_node.mode = 0
                    p_head = D.insert_before(p_head, p_head, D.todirect(n_node))
                end
            end

            -- Apply positions to glyphs on this page
            local curr = p_head
            while curr do
                local next_curr = D.getnext(curr)
                local id = D.getid(curr)
                if id == constants.GLYPH then
                    local pos = layout_map[curr]
                    if pos then
                        local col = pos.col
                        local row = pos.row
                        local d = D.getfield(curr, "depth")
                        local h = D.getfield(curr, "height")
                        local w = D.getfield(curr, "width")
                        local rtl_col = p_total_cols - 1 - col
                        local final_x = rtl_col * grid_width + (grid_width - w) / 2 + half_thickness + shift_x
                        local final_y
                        if vertical_align == "top" then
                            final_y = -row * grid_height - h - shift_y
                        elseif vertical_align == "center" then
                            local char_total_height = h + d
                            final_y = -row * grid_height - (grid_height + char_total_height) / 2 + d - shift_y
                        else
                            final_y = -row * grid_height - grid_height + d - shift_y
                        end
                        D.setfield(curr, "xoffset", final_x)
                        D.setfield(curr, "yoffset", final_y)
                        local k = D.new(constants.KERN)
                        D.setfield(k, "kern", -w)
                        D.setlink(curr, k)
                        if next_curr then D.setlink(k, next_curr) end
                        if draw_debug then
                            local tx_bp = (rtl_col * grid_width + half_thickness + shift_x) * sp_to_bp
                            local ty_bp = (-row * grid_height - shift_y) * sp_to_bp
                            local literal = string.format("q 0.5 w 0 0 1 RG 1 0 0 1 %.4f %.4f cm 0 0 %.4f %.4f re S Q", tx_bp, ty_bp, w_bp, h_bp)
                            local nn = node.new("whatsit", "pdf_literal")
                            nn.data = literal
                            nn.mode = 0
                            D.insert_before(p_head, curr, D.todirect(nn))
                        end
                    end
                elseif id == constants.GLUE then
                    D.setfield(curr, "width", 0)
                    D.setfield(curr, "stretch", 0)
                    D.setfield(curr, "shrink", 0)
                elseif id == constants.KERN then
                    local p_prev = layout_map[curr] -- Wait, we didn't store kerns in map
                    -- Actually we should just zero them out if they are not our injected negative kerns
                    -- But our injected negative kerns are not in the loop yet because we use next_curr
                    D.setfield(curr, "kern", 0)
                end
                curr = next_curr
            end
            
            result_pages[p+1] = { head = D.tonode(p_head), cols = p_total_cols }
        end
    end

    return result_pages
end

-- Create module table
local render = {
    apply_positions = apply_positions,
}

-- Register module in package.loaded for require() compatibility
package.loaded['render'] = render

-- Return module exports
return render
