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
local GLUE = node.id("glue")

-- Helper to convert TeX dimension string (e.g. "20pt") to number (scaled points)
local function to_dimen(dim_str)
    if not dim_str or dim_str == "" or dim_str == "0" or dim_str == "0pt" then return nil end
    local ok, res = pcall(tex.sp, dim_str)
    if ok then 
        if res == 0 then return nil end
        return res 
    else 
        return nil 
    end
end

local PENALTY = node.id("penalty")
local LOCAL_PAR = node.id("local_par")

-- Helper to flatten a vlist (from vbox) into a single list of nodes,
-- inserting penalties to mark paragraph breaks (hlist boundaries).
local function flatten_vbox(head)
    local d_head = D.todirect(head)
    local result_head_d = nil
    local result_tail_d = nil

    -- Helper to append a single node to the result list
    local function append_node(n)
        if not n then return end
        D.setnext(n, nil) -- Isolate the node
        if not result_head_d then
            result_head_d = n
            result_tail_d = n
        else
            D.setlink(result_tail_d, n)
            result_tail_d = n
        end
    end

    local curr = d_head
    while curr do
        local id = D.getid(curr)
        if id == HLIST or id == VLIST then
            local list_head = D.getfield(curr, "list") 
            if list_head then
                local line_nodes = {}
                local t = list_head
                while t do
                    local tid = D.getid(t)
                    local keep = false
                    if tid == GLYPH then
                        keep = true
                    elseif tid == KERN then
                        keep = true
                    elseif tid == GLUE then
                        -- Only keep user-defined skips (subtype 0)
                        -- Ignore rightskip (9), parfillskip (15), etc.
                        local subtype = D.getsubtype(t)
                        if subtype == 0 then
                            keep = true
                        end
                    end
                    
                    if keep then
                        table.insert(line_nodes, D.copy(t))
                    end
                    t = D.getnext(t)
                end
                
                -- Trim trailing "space-like" nodes from the end of the paragraph
                -- This removes trailing glues/kerns and space glyphs (char 32 or 12288)
                local last = #line_nodes
                while last > 0 do
                    local n = line_nodes[last]
                    local nid = D.getid(n)
                    local is_space = false
                    
                    if nid == GLUE or nid == KERN then
                        is_space = true
                    elseif nid == GLYPH then
                        local char = D.getfield(n, "char")
                        if char == 32 or char == 12288 then
                            is_space = true
                        end
                    end
                    
                    if is_space then
                        D.free(n)
                        table.remove(line_nodes, last)
                        last = last - 1
                    else
                        break
                    end
                end
                
                -- Append cleaned nodes to global list
                for _, n in ipairs(line_nodes) do
                    append_node(n)
                end
            end
            
            -- Add break penalty (-10001 = force column break)
            local p = D.new(PENALTY)
            D.setfield(p, "penalty", -10001)
            append_node(p)
        end
        
        curr = D.getnext(curr)
    end

    return D.tonode(result_head_d)
end

-- internal function to layout a list of nodes on a grid
-- grid_width: horizontal spacing (column width)
-- grid_height: vertical spacing (row height)
-- RTL layout: first character at top-right, columns flow left
local function grid_layout_nodes(head, grid_width, grid_height, line_limit, draw_debug, draw_border, border_padding)
    local d_head = D.todirect(head)
    
    -- Safety: ensure line_limit is at least 1
    if line_limit < 1 then line_limit = 20 end

    -- First pass: determine total columns by simulating the flow
    local sim_count = 0
    local temp = d_head
    while temp do
        local id = D.getid(temp)
        if id == GLYPH then
            sim_count = sim_count + 1
        elseif id == PENALTY and D.getfield(temp, "penalty") == -10001 then
             local rem = sim_count % line_limit
             if rem > 0 then
                 sim_count = sim_count + (line_limit - rem)
             end
        end
        temp = D.getnext(temp)
    end

    local total_cols = math.ceil(sim_count / line_limit)
    if total_cols == 0 then total_cols = 1 end

    -- Cache conversion factor for PDF literals
    local sp_to_bp = 0.0000152018
    local w_bp = grid_width * sp_to_bp
    local h_bp = -grid_height * sp_to_bp 
    local col_height_bp = -(line_limit * grid_height + border_padding) * sp_to_bp

    -- Draw border (乌丝栏)
    if draw_border and total_cols > 0 then
        for col = 0, total_cols - 1 do
            local rtl_col = total_cols - 1 - col
            local box_x = rtl_col * grid_width
            local tx_bp = box_x * sp_to_bp
            local literal = string.format("q 0.4 w 0 0 0 RG %.4f 0 %.4f %.4f re S Q",
                tx_bp, w_bp, col_height_bp
            )
            local n_node = node.new("whatsit", "pdf_literal")
            n_node.data = literal
            n_node.mode = 0
            local n = D.todirect(n_node)
            d_head = D.insert_before(d_head, d_head, n)
        end
    end

    -- Second pass: position glyphs
    local count = 0
    local curr = d_head
    while curr do
        local id = D.getid(curr)

        if id == GLUE then
            -- Zero out glue to prevent layout drift
            D.setfield(curr, "width", 0)
            D.setfield(curr, "stretch", 0)
            D.setfield(curr, "shrink", 0)

        elseif id == KERN then
            local k_val = D.getfield(curr, "kern")
            if k_val ~= 0 then D.setfield(curr, "kern", 0) end

        elseif id == PENALTY and D.getfield(curr, "penalty") == -10001 then
            -- Handle forced column break
            local rem = count % line_limit
            if rem > 0 then
                count = count + (line_limit - rem)
            end

        elseif id == GLYPH then
            local row = count % line_limit
            local col = math.floor(count / line_limit)

            local d = D.getfield(curr, "depth")
            local w = D.getfield(curr, "width")

            -- RTL Vertical Positioning
            local rtl_col = total_cols - 1 - col
            local final_x = rtl_col * grid_width + (grid_width - w) / 2
            local final_y = -row * grid_height - grid_height + d

            D.setfield(curr, "xoffset", final_x)
            D.setfield(curr, "yoffset", final_y)

            -- Debug Grid
            if draw_debug then
                local tx_bp = (rtl_col * grid_width) * sp_to_bp
                local ty_bp = (-row * grid_height) * sp_to_bp
                local literal = string.format("q 0.5 w 0 0 1 RG 1 0 0 1 %.4f %.4f cm 0 0 %.4f %.4f re S Q",
                    tx_bp, ty_bp, w_bp, h_bp
                )
                local n_node = node.new("whatsit", "pdf_literal")
                n_node.data = literal
                n_node.mode = 0
                d_head = D.insert_before(d_head, curr, D.todirect(n_node))
            end

            -- PDF Selection Fix
            local k = D.new(KERN)
            D.setfield(k, "kern", -w)
            local next_node = D.getnext(curr)
            D.setlink(curr, k)
            if next_node then D.setlink(k, next_node) end
            
            count = count + 1
            curr = k -- Skip the kern
        end

        curr = D.getnext(curr)
    end

    return D.tonode(d_head), count
end

-- Main entry point called from TeX
function cn_vertical.make_grid_box(box_num, height, grid_width, grid_height, col_limit, debug_on, border_on, border_padding)
    local box = tex.box[box_num]
    if not box then return end

    local list = box.list
    if not list then return end

    -- If captured as VBOX, flatten it first
    if box.id == 1 then
        list = flatten_vbox(list)
    end

    local g_width = to_dimen(grid_width) or (65536 * 20)
    local g_height = to_dimen(grid_height) or g_width
    local h_dim = to_dimen(height) or (65536 * 300)
    local b_padding = to_dimen(border_padding) or 0

    local limit = tonumber(col_limit)
    if not limit or limit <= 0 then
        limit = math.floor(h_dim / g_height)
    end

    local is_debug = (debug_on == "true" or debug_on == true)
    local is_border = (border_on == "true" or border_on == true)

    -- Process the list
    local new_head, final_count = grid_layout_nodes(list, g_width, g_height, limit, is_debug, is_border, b_padding)

    -- Create a NEW HLIST box for the result
    local cols = math.ceil(final_count / limit)
    if cols == 0 then cols = 1 end
    local actual_rows = math.min(limit, final_count)
    if cols > 1 then actual_rows = limit end

    local new_box = node.new("hlist")
    new_box.dir = "TLT"
    new_box.list = new_head
    new_box.width = cols * g_width
    new_box.height = 0
    new_box.depth = actual_rows * g_height
    
    tex.box[box_num] = new_box
end

-- Old function deprecated, kept for reference or removal
function cn_vertical.vertical_rtt(text, height, col_spacing, char_spacing)
    -- ... deprecated ...
    tex.print("Error: vertical_rtt is deprecated. Use \\VerticalGrid instead.")
end

-- Return module
return cn_vertical
