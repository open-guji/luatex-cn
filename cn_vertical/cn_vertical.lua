-- cn_vertical.lua
-- Chinese vertical typesetting module for LuaTeX
-- Uses native LuaTeX 'dir' primitives for RTT (Right-to-Left Top-to-Bottom) layout.

-- Create module namespace
cn_vertical = cn_vertical or {}

-- Function to typeset text in vertical mode with RTT direction
-- This supports line breaking and RTL column flow.
--
-- @param text The text content to typeset.
-- @param height (string) The vertical height (tex dimension), e.g. "300pt". Default "300pt".
-- @param col_spacing (string) The dimension for baselineskip (column spacing), e.g. "20pt". Default nil (use current).
-- @param char_spacing (number) The LetterSpace amount, e.g. 10. Default 0.
-- Use node.direct for performance and lower-level access
local D = node.direct
local GLYPH = node.id("glyph")
local KERN = node.id("kern")
local HLIST = node.id("hlist")
local VLIST = node.id("vlist")
local WHATSIT = node.id("whatsit")

-- Helper to convert TeX dimension string (e.g. "20pt") to number (scaled points)
local function to_dimen(dim_str)
    if not dim_str or dim_str == "" then return nil end
    return tex.sp(dim_str)
end

local GLUE = node.id("glue")

-- internal function to layout a list of nodes on a grid
-- grid_width: horizontal spacing (column width)
-- grid_height: vertical spacing (row height)
-- RTL layout: first character at top-right, columns flow left
local function grid_layout_nodes(head, grid_width, grid_height, line_limit, draw_debug)
    local d_head = D.todirect(head)
    local curr = d_head

    -- Safety: ensure line_limit is at least 1 to avoid divide by zero
    if line_limit < 1 then line_limit = 20 end

    -- First pass: count glyphs to determine total columns
    local glyph_count = 0
    local temp = d_head
    while temp do
        if D.getid(temp) == GLYPH then
            glyph_count = glyph_count + 1
        end
        temp = D.getnext(temp)
    end

    local total_cols = math.ceil(glyph_count / line_limit)

    -- Cache debug conversion
    local sp_to_bp = 0.0000152018
    local w_bp = grid_width * sp_to_bp
    local h_bp = -grid_height * sp_to_bp -- Draw down

    -- Second pass: position glyphs
    local count = 0
    while curr do
        local id = D.getid(curr)

        if id == GLUE then
            -- Zero out glue to prevent "Drift" / Slanting.
            D.setfield(curr, "width", 0)
            D.setfield(curr, "stretch", 0)
            D.setfield(curr, "shrink", 0)

        elseif id == KERN then
            local k_val = D.getfield(curr, "kern")
            -- Only zero out if it's not one of OUR special kerns?
            -- But we insert our kerns *after* the current processing point,
            -- and skip over them. So this should only hit existing kerns.
            if k_val ~= 0 then
               D.setfield(curr, "kern", 0)
            end

        elseif id == GLYPH then
            local row = count % line_limit
            local col = math.floor(count / line_limit)

            -- Get glyph metrics
            local d = D.getfield(curr, "depth")
            local w = D.getfield(curr, "width")

            -- 1. Vertical Positioning (Bottom Alignment)
            local final_y = -row * grid_height - grid_height + d

            -- 2. Horizontal Positioning (RTL: rightmost column first)
            -- col 0 should be at the right (x = total_cols-1 grid widths from left)
            -- col N should be at x = (total_cols-1-N) * grid_width
            local rtl_col = total_cols - 1 - col
            local final_x = rtl_col * grid_width + (grid_width - w) / 2

            D.setfield(curr, "xoffset", final_x)
            D.setfield(curr, "yoffset", final_y)


            -- Debug Grid line
            if draw_debug then
                local box_x = rtl_col * grid_width
                local box_y = -row * grid_height

                local tx_bp = box_x * sp_to_bp
                local ty_bp = box_y * sp_to_bp

                local literal = string.format("q 0.5 w 0 0 1 RG 1 0 0 1 %.4f %.4f cm 0 0 %.4f %.4f re S Q",
                    tx_bp, ty_bp, w_bp, h_bp
                )

                -- Use node.new (not direct) for pdf_literal, then convert
                local n_node = node.new("whatsit", "pdf_literal")
                n_node.data = literal
                n_node.mode = 0  -- 0 = origin mode
                local n = D.todirect(n_node)

                -- Insert BEFORE curr, update d_head if needed
                d_head = D.insert_before(d_head, curr, n)
            end

            -- 3. PDF Selection Fix (Negative Kern)
            -- Use manual linking to ensure we don't drop the rest of the list
            local k = D.new(KERN)
            D.setfield(k, "kern", -w)

            local next_node = D.getnext(curr)
            D.setlink(curr, k)
            if next_node then
               D.setlink(k, next_node)
            end

            count = count + 1

            -- SKIP the new kern 'k'
            -- The loop logic `curr = D.getnext(curr)` happens at end.
            -- If we set `curr = k`, `getnext` will return the node AFTER k.
            curr = k
        end

        curr = D.getnext(curr)
    end

    return D.tonode(d_head), glyph_count
end

-- Main entry point called from TeX
-- box_num: The box register containing the raw text (usually \hbox)
-- height: page/text height
-- grid_width: width of each grid cell (column spacing)
-- grid_height: height of each grid cell (row spacing)
-- col_limit: max chars per column (optional, calculated if nil)
-- debug_on: valid boolean or string "true"
function cn_vertical.make_grid_box(box_num, height, grid_width, grid_height, col_limit, debug_on)
    local box = tex.box[box_num]
    if not box then return end

    local list = box.list
    if not list then return end

    -- We assume the input box contains a flat list of chars (from strict wrapping or simple hbox)

    local g_width = to_dimen(grid_width) or 65536 * 20 -- default 20pt
    local g_height = to_dimen(grid_height) or g_width  -- default to grid_width if not set
    local h_dim = to_dimen(height) or (65536 * 300)    -- default 300pt

    -- Calculate line limit if not provided or if 0 (based on grid_height for vertical)
    local limit = tonumber(col_limit)
    if not limit or limit <= 0 then
        limit = math.floor(h_dim / g_height)
    end

    local is_debug = (debug_on == "true" or debug_on == true)

    -- Process the list
    local new_head, char_count = grid_layout_nodes(list, g_width, g_height, limit, is_debug)

    -- Update the box list
    box.list = new_head

    -- We need to resize the box to fit the new content
    -- Total cols = ceil(count / limit)
    local cols = math.ceil(char_count / limit)

    -- Calculate actual rows used (for the last column, may be partial)
    local actual_rows = math.min(limit, char_count)
    if cols > 1 then
        actual_rows = limit  -- Full columns use all rows
    end

    -- Set box dimensions
    -- Width: cols * grid_width
    -- Content is positioned with negative yoffset (below baseline)
    -- So we set height=0 and depth=actual content height
    box.width = cols * g_width
    box.height = 0
    box.depth = actual_rows * g_height
end

-- Old function deprecated, kept for reference or removal
function cn_vertical.vertical_rtt(text, height, col_spacing, char_spacing)
    -- ... deprecated ...
    tex.print("Error: vertical_rtt is deprecated. Use \\VerticalGrid instead.")
end

-- Return module
return cn_vertical
