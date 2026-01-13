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
local banxin = package.loaded['banxin'] or require('banxin')

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
-- @param border_rgb (string) RGB color for borders (e.g., "0 0 0")
-- @param bg_rgb (string) RGB color for background (e.g., "1 1 1")
-- @return (table) Array of page info {head, cols}
local function apply_positions(head, layout_map, params)
    local d_head = D.todirect(head)

    local grid_width = params.grid_width
    local grid_height = params.grid_height
    local total_pages = params.total_pages
    local vertical_align = params.vertical_align
    local draw_debug = params.draw_debug
    local draw_border = params.draw_border
    local b_padding_top = params.b_padding_top
    local b_padding_bottom = params.b_padding_bottom
    local line_limit = params.line_limit
    local border_thickness = params.border_thickness
    local draw_outer_border = params.draw_outer_border
    local outer_border_thickness = params.outer_border_thickness
    local outer_border_sep = params.outer_border_sep
    local n_column = params.n_column
    local page_columns = params.page_columns
    local border_rgb = params.border_rgb
    local bg_rgb = params.bg_rgb
    local font_rgb = params.font_rgb

    -- Cached conversion factors for PDF literals
    local w_bp = grid_width * sp_to_bp
    local h_bp = -grid_height * sp_to_bp
    local b_thickness_bp = border_thickness * sp_to_bp
    local half_thickness = math.floor(border_thickness / 2)
    
    local ob_thickness_val = (outer_border_thickness or (65536 * 2))
    local ob_thickness_bp = ob_thickness_val * sp_to_bp
    local ob_sep_val = (outer_border_sep or (65536 * 2))
    
    -- Global shift for all inner content
    local outer_shift = draw_outer_border and (ob_thickness_val + ob_sep_val) or 0
    local shift_x = outer_shift
    local shift_y = outer_shift + b_padding_top
    
    local interval = tonumber(n_column) or 0
    local p_cols = tonumber(page_columns) or (2 * interval + 1)
    
    local function normalize_rgb(s)
        if s == nil then return nil end
        s = tostring(s)
        if s == "nil" or s == "" then return nil end
        s = s:gsub(",", " ")
        local r, g, b = s:match("([%d%.]+)%s+([%d%.]+)%s+([%d%.]+)")
        if not r then return s end 
        r, g, b = tonumber(r), tonumber(g), tonumber(b)
        if not r or not g or not b then return s end
        if r > 1 or g > 1 or b > 1 then
            return string.format("%.4f %.4f %.4f", r/255, g/255, b/255)
        end
        return string.format("%.4f %.4f %.4f", r, g, b)
    end

    local b_rgb_str = normalize_rgb(border_rgb) or "0.0000 0.0000 0.0000"
    local background_rgb_str = normalize_rgb(bg_rgb)
    local text_rgb_str = normalize_rgb(font_rgb)
    
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

            local inner_width = p_total_cols * grid_width + border_thickness
            local inner_height = line_limit * grid_height + b_padding_top + b_padding_bottom + border_thickness

            -- Draw borders
            if draw_border and p_total_cols > 0 then
                for col = 0, p_total_cols - 1 do
                    local rtl_col = p_total_cols - 1 - col
                    local tx_bp = (rtl_col * grid_width + half_thickness + shift_x) * sp_to_bp
                    local ty_bp = -(half_thickness + outer_shift) * sp_to_bp
                    local tw_bp = grid_width * sp_to_bp
                    local th_bp = -(line_limit * grid_height + b_padding_top + b_padding_bottom) * sp_to_bp
                    local literal = string.format("q %.2f w %s RG %.4f %.4f %.4f %.4f re S Q", b_thickness_bp, b_rgb_str, tx_bp, ty_bp, tw_bp, th_bp)
                    local n_node = node.new("whatsit", "pdf_literal")
                    n_node.data = literal
                    n_node.mode = 0
                    p_head = D.insert_before(p_head, p_head, D.todirect(n_node))
                    
                    -- Draw banxin dividers for banxin columns
                    if is_banxin_col(col) then
                        local banxin_x = rtl_col * grid_width + half_thickness + shift_x
                        local banxin_y = -(half_thickness + outer_shift)
                        local banxin_height = line_limit * grid_height + b_padding_top + b_padding_bottom
                        local banxin_params = {
                            x = banxin_x,
                            y = banxin_y,
                            width = grid_width,
                            total_height = banxin_height,
                            section1_ratio = params.banxin_s1_ratio or 0.28,
                            section2_ratio = params.banxin_s2_ratio or 0.56,
                            section3_ratio = params.banxin_s3_ratio or 0.16,
                            color_str = b_rgb_str,
                            border_thickness = border_thickness,
                            banxin_text = params.banxin_text or "",
                            font_size = grid_height -- Use grid height as base font size
                        }
                        local banxin_result = banxin.draw_banxin(banxin_params)

                        -- Insert line drawing literals
                        for _, lit in ipairs(banxin_result.literals) do
                            local bn = node.new("whatsit", "pdf_literal")
                            bn.data = lit
                            bn.mode = 0
                            p_head = D.insert_before(p_head, p_head, D.todirect(bn))
                        end

                        -- Insert text nodes for banxin text
                        -- We create individual glyph nodes for each character
                        if banxin_result.text_nodes then
                            for _, text_data in ipairs(banxin_result.text_nodes) do
                                -- Create glyph node
                                local glyph = node.new(node.id("glyph"))
                                glyph.char = utf8.codepoint(text_data.char)
                                glyph.font = font.current()
                                glyph.lang = 0

                                -- Set font size via font table if needed
                                -- For now, we'll use the current font

                                -- Create hlist to hold the glyph
                                local hlist = node.new(node.id("hlist"))
                                hlist.head = glyph
                                hlist.width = 0
                                hlist.height = text_data.font_size
                                hlist.depth = 0

                                -- Create PDF literal for positioning
                                -- Use PDF's text matrix to position the character
                                local x_bp = text_data.x * sp_to_bp
                                local y_bp = text_data.y * sp_to_bp
                                local fs_bp = text_data.font_size * sp_to_bp

                                -- We'll use whatsit nodes to position via PDF
                                -- This is a simpler approach: create the character as a node
                                -- and let LuaTeX handle the rendering

                                -- For now, insert the glyph directly
                                -- The positioning will need refinement
                                p_head = D.insert_before(p_head, p_head, D.todirect(hlist))
                            end
                        end
                    end
                end
            end

            -- Draw outer border
            if draw_outer_border and p_total_cols > 0 then
                local tx_bp = (ob_thickness_bp / 2)
                local ty_bp = -(ob_thickness_bp / 2)
                local tw_bp = (inner_width + ob_sep_val * 2 + ob_thickness_val) * sp_to_bp
                local th_bp = -(inner_height + ob_sep_val * 2 + ob_thickness_val) * sp_to_bp
                local literal = string.format("q %.2f w %s RG %.4f %.4f %.4f %.4f re S Q", ob_thickness_bp, b_rgb_str, tx_bp, ty_bp, tw_bp, th_bp)
                local n_node = node.new("whatsit", "pdf_literal")
                n_node.data = literal
                n_node.mode = 0
                p_head = D.insert_before(p_head, p_head, D.todirect(n_node))
            end

            -- --- BOTTOM LAYER (Drawn first) ---
            -- Insert these last so they become the first in the stream
            
            -- Set Font Color (Bottom Layer)
            if text_rgb_str then
                local literal = string.format("%s rg", text_rgb_str)
                local n_node = node.new("whatsit", "pdf_literal")
                n_node.data = literal
                n_node.mode = 0
                p_head = D.insert_before(p_head, p_head, D.todirect(n_node))
            end

            -- Draw background color (Bottom Layer)
            if background_rgb_str then
                -- Background needs to cover the entire page
                -- The origin (0,0) in our box is at (margin_left, paper_height - margin_top)
                local p_width = params.paper_width or 0
                local p_height = params.paper_height or 0
                local m_left = params.margin_left or 0
                local m_top = params.margin_top or 0
                
                local tx_bp, ty_bp, tw_bp, th_bp
                if p_width > 0 and p_height > 0 then
                    -- Relative to our box origin (0,0)
                    tx_bp = -m_left * sp_to_bp
                    ty_bp = m_top * sp_to_bp
                    tw_bp = p_width * sp_to_bp
                    th_bp = -p_height * sp_to_bp
                else
                    -- Fallback to box-sized background if paper size is not provided
                    tx_bp = 0
                    ty_bp = 0
                    tw_bp = (inner_width + outer_shift * 2) * sp_to_bp
                    th_bp = -(inner_height + outer_shift * 2) * sp_to_bp
                end

                local literal = string.format("q 0 w %s rg %.4f %.4f %.4f %.4f re f Q", background_rgb_str, tx_bp, ty_bp, tw_bp, th_bp)
                local n_node = node.new("whatsit", "pdf_literal")
                n_node.data = literal
                n_node.mode = 0
                p_head = D.insert_before(p_head, p_head, D.todirect(n_node))
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
