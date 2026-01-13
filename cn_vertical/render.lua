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
-- @param border_padding (number) Extra padding at bottom of border in scaled points
-- @param line_limit (number) Maximum rows per column
-- @return (node) Modified node list head
local function apply_positions(head, layout_map, grid_width, grid_height, total_cols, vertical_align, draw_debug, draw_border, border_padding, line_limit, border_thickness, draw_outer_border, outer_border_thickness, outer_border_sep)
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
    -- Shift = Outer Border Thickness + Separation
    local shift = draw_outer_border and (ob_thickness + ob_sep) or 0
    local shift_bp = shift * sp_to_bp

    -- Draw outer border (if enabled)
    if draw_outer_border and total_cols > 0 then
        local inner_width = total_cols * grid_width + border_thickness
        local inner_height = line_limit * grid_height + border_padding + border_thickness
        
        -- Rect starts at half the outer thickness to have its OUTER edge at 0
        local tx_bp = (ob_thickness / 2) * sp_to_bp
        local ty_bp = -(ob_thickness / 2) * sp_to_bp
        local tw_bp = (inner_width + ob_sep * 2 + ob_thickness) * sp_to_bp
        local th_bp = -(inner_height + ob_sep * 2 + ob_thickness) * sp_to_bp
        
        local literal = string.format("q %.2f w 0 0 0 RG %.4f %.4f %.4f %.4f re S Q",
            ob_thickness_bp, tx_bp, ty_bp, tw_bp, th_bp
        )
        local n_node = node.new("whatsit", "pdf_literal")
        n_node.data = literal
        n_node.mode = 0
        d_head = D.insert_before(d_head, d_head, D.todirect(n_node))
    end

    -- Draw column borders (if enabled)
    if draw_border and total_cols > 0 then
        for col = 0, total_cols - 1 do
            local rtl_col = total_cols - 1 - col
            local box_x = rtl_col * grid_width
            
            local tx_bp = (box_x + half_thickness + shift) * sp_to_bp
            local ty_bp = -(half_thickness + shift) * sp_to_bp
            local tw_bp = grid_width * sp_to_bp
            local th_bp = -(line_limit * grid_height + border_padding) * sp_to_bp
            
            local literal = string.format("q %.2f w 0 0 0 RG %.4f %.4f %.4f %.4f re S Q",
                b_thickness_bp, tx_bp, ty_bp, tw_bp, th_bp
            )
            local n_node = node.new("whatsit", "pdf_literal")
            n_node.data = literal
            n_node.mode = 0
            d_head = D.insert_before(d_head, d_head, D.todirect(n_node))
        end
    end

    -- Second Pass: Apply positions linearly
    local t = d_head
    while t do
        local id = D.getid(t)
        local next_node = D.getnext(t) -- Save next before modifying links (injection)

        if id == constants.GLYPH then
            local pos = layout_map[t]
            if pos then
                local col = pos.col
                local row = pos.row

                local d = D.getfield(t, "depth")
                local h = D.getfield(t, "height")
                local w = D.getfield(t, "width")

                local rtl_col = total_cols - 1 - col
                local final_x = rtl_col * grid_width + (grid_width - w) / 2 + half_thickness + shift

                -- Calculate vertical position based on alignment
                local final_y
                if vertical_align == "top" then
                    -- Align to top of grid cell (baseline at top)
                    final_y = -row * grid_height - h - shift
                elseif vertical_align == "center" then
                    -- Center vertically in grid cell
                    local char_total_height = h + d
                    final_y = -row * grid_height - (grid_height + char_total_height) / 2 + d - shift
                else -- "bottom" (default/original behavior)
                    -- Align to bottom of grid cell (using depth)
                    final_y = -row * grid_height - grid_height + d - shift
                end

                D.setfield(t, "xoffset", final_x)
                D.setfield(t, "yoffset", final_y)

                -- Fix PDF selection (Inject negative kern to cancel advance)
                local k = D.new(constants.KERN)
                D.setfield(k, "kern", -w)
                D.setlink(t, k)
                if next_node then D.setlink(k, next_node) end

                -- Draw debug grid
                if draw_debug then
                     local tx_bp = (rtl_col * grid_width + half_thickness + shift) * sp_to_bp
                     local ty_bp = (-row * grid_height - shift) * sp_to_bp
                     local literal = string.format("q 0.5 w 0 0 1 RG 1 0 0 1 %.4f %.4f cm 0 0 %.4f %.4f re S Q",
                         tx_bp, ty_bp, w_bp, h_bp
                     )
                     local nn = node.new("whatsit", "pdf_literal")
                     nn.data = literal
                     nn.mode = 0
                     D.insert_before(d_head, t, D.todirect(nn))
                end
            end
        elseif id == constants.GLUE then
             -- Zero out glue width
             D.setfield(t, "width", 0)
             D.setfield(t, "stretch", 0)
             D.setfield(t, "shrink", 0)
        elseif id == constants.KERN then
             -- Zero out kerns
             D.setfield(t, "kern", 0)
        end

        t = next_node
    end

    return D.tonode(d_head)
end

-- Create module table
local render = {
    apply_positions = apply_positions,
}

-- Register module in package.loaded for require() compatibility
package.loaded['render'] = render

-- Return module exports
return render
