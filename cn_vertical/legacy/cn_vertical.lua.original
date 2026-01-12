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

-- Register a custom attribute for indentation
local ATTR_INDENT = luatexbase.attributes.cnverticalindent or luatexbase.new_attribute("cnverticalindent")
local ATTR_RIGHT_INDENT = luatexbase.attributes.cnverticalrightindent or luatexbase.new_attribute("cnverticalrightindent")

-- Helper to flatten a vlist (from vbox) into a single list of nodes,
-- extracting indentation from line starts and applying it as attributes.
-- Also cleans up nodes (keeps valid glues/glyphs).
-- Added Indent support
-- char_width: The width of a single character (for calculating indent in character units)
local function flatten_vbox(head, grid_width, char_width)
    local d_head = D.todirect(head)
    local result_head_d = nil
    local result_tail_d = nil

    local function append_node(n)
        if not n then return end
        D.setnext(n, nil)
        if not result_head_d then
            result_head_d = n
            result_tail_d = n
        else
            D.setlink(result_tail_d, n)
            result_tail_d = n
        end
    end

    -- Recursive node collector
    local function collect_nodes(n_head, indent_level, right_indent_level)
        local t = n_head
        while t do
            local tid = D.getid(t)
            
            if tid == HLIST or tid == VLIST then
                -- Recurse into boxes
                local inner = D.getfield(t, "list")
                collect_nodes(inner, indent_level, right_indent_level)
            else
                local keep = false
                if tid == GLYPH or tid == KERN then
                    keep = true
                elseif tid == GLUE then
                    local subtype = D.getsubtype(t)
                    -- Keep userskip (0), spaceskip (13), xspaceskip (14)
                    if subtype == 0 or subtype == 13 or subtype == 14 then
                       keep = true
                    end
                elseif tid == PENALTY then
                    keep = true
                end
                
                if keep then
                    local copy = D.copy(t)
                    if indent_level > 0 then
                        D.set_attribute(copy, ATTR_INDENT, indent_level)
                    end
                    if right_indent_level > 0 then
                        D.set_attribute(copy, ATTR_RIGHT_INDENT, right_indent_level)
                    end
                    append_node(copy)
                end
            end
            t = D.getnext(t)
        end
    end

    local curr = d_head
    while curr do
        local id = D.getid(curr)
        if id == HLIST then
            -- This looks like a line. Check for leftskip (indent)
            -- leftskip is usually glue subtype 8 at start of list
            local line_head = D.getfield(curr, "list")
            local indent = 0
            local right_indent = 0

            -- Check HLIST itself for indent (shift field)
            -- This is where LaTeX stores indentation for list items
            local shift = D.getfield(curr, "shift") or 0
            if shift > 0 then
                -- Use char_width instead of grid_width for indent calculation
                -- This correctly handles nested lists where indent is in em units
                indent = math.floor(shift / char_width + 0.5)
            end

            -- Also check for leftskip glue (fallback for other indent methods)
            local t_scan = line_head
            while t_scan do
                local tid = D.getid(t_scan)
                if tid == GLYPH then
                    -- Content started (glyph), stop looking
                    break
                elseif tid == GLUE and D.getsubtype(t_scan) == 8 then -- leftskip
                    local w = D.getfield(t_scan, "width")
                    if w > 0 and indent == 0 then
                        -- Only use leftskip if we haven't already found shift-based indent
                        indent = math.floor(w / char_width + 0.5)
                    end
                    break
                end
                t_scan = D.getnext(t_scan)
            end

            -- Detect Right Indent (Rightskip) - scan entire list
            -- Note: LaTeX itemize doesn't always generate rightskip glue
            -- Instead, it may adjust line width. So rightmargin might not be detectable here.
            t_scan = line_head
            while t_scan do
                if D.getid(t_scan) == GLUE and D.getsubtype(t_scan) == 9 then -- rightskip
                     local w = D.getfield(t_scan, "width")
                     if w > 0 then
                         right_indent = math.floor((w / char_width) + 0.5)
                     end
                end
                t_scan = D.getnext(t_scan)
            end
            
            -- Collect content of this line, applying indent
            collect_nodes(line_head, indent, right_indent)
            
            -- Add break penalty (-10001 = column break)
            -- Note: In standard list, item lines are paragraphs? 
            -- Actually itemize creates paragraphs. So HLISTS are lines.
            -- We should preserve line structure? 
            -- cn_vertical reflows text. So we merge lines of a paragraph.
            -- We only add penalty if "curr" was a paragraph end?
            -- flatten_vbox assumes input is a list of lines.
            -- If we input a VBOX from LaTeX, it contains HLISTs (lines) and GLUES (baselineskip).
            -- We don't want to break column at every line!
            -- Use penalty only if original had break? 
            -- Or just rely on natural flow?
            -- CURRENT BEHAVIOR: We append penalty -10001 at every HLIST/VLIST iteration.
            -- This forces EVERY LINE to start a new column. This is WRONG for wrapped text in general,
            -- BUT for `guji` (ancient book), we usually have manual breaks or specific structure.
            -- HOWEVER, `itemize` wraps text. If we break column at every line, it looks scattered.
            -- Implementation choice:
            -- If we want reflow, we should NOT break at every line.
            -- We should only break if explicitly requested or at paragraph end.
            -- But detecting paragraph end in VBox is hard (it's flattened).
            -- Valid compromise for now: Continue existing behavior (Break at every HLIST = New Column).
            -- This means `itemize` lines become columns.
            -- This is actually STANDARD for ancient books (lines are columns).
            -- So `indent` on every line (HLIST) is correct.
            local p = D.new(PENALTY)
            D.setfield(p, "penalty", -10001)
            append_node(p)
            
        elseif id == VLIST then
             -- Recurse or treat as line? 
             -- Treat as container.
             local inner = D.getfield(curr, "list")
             -- Flatten recursively? 
             -- For now, just collect nodes (no indent logic for VLIST container itself?)
             collect_nodes(inner, 0, 0)
        end
        curr = D.getnext(curr)
    end
    
    return D.tonode(result_head_d)
end

-- internal function to layout a list of nodes on a grid
-- grid_width: horizontal spacing (column width)
-- grid_height: vertical spacing (row height)
-- RTL layout: first character at top-right, columns flow left
-- vertical_align: "top", "center", or "bottom"
local function grid_layout_nodes(head, grid_width, grid_height, line_limit, draw_debug, draw_border, border_padding, vertical_align)
    local d_head = D.todirect(head)
    
    if line_limit < 1 then line_limit = 20 end

    -- Stateful cursor layout
    -- We track max column used to determine width
    local simulated_max_col = 0
    
    local cur_col = 0
    local cur_row = 0

    -- Track current column's indent (for hanging indent within same column)
    local cur_column_indent = 0

    -- Cache conversion factor for PDF literals
    local sp_to_bp = 0.0000152018
    local w_bp = grid_width * sp_to_bp
    local h_bp = -grid_height * sp_to_bp
    local col_height_bp = -(line_limit * grid_height + border_padding) * sp_to_bp

    -- RE-IMPLEMENTATION OF LOGIC
    -- We perform layout calculation.
    -- Store (node_ptr -> {col, row}) mapping.
    local layout_map = {}

    local t = d_head
    while t do
        local id = D.getid(t)
        local indent = D.get_attribute(t, ATTR_INDENT) or 0
        local r_indent = D.get_attribute(t, ATTR_RIGHT_INDENT) or 0

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
        
        -- Check wrapping BEFORE placing?
        -- If current row is already beyond limit (e.g. slight overflow), we should wrap.
        if cur_row >= effective_limit then
            cur_col = cur_col + 1
            cur_row = 0
            -- Reset column indent for new column
            cur_column_indent = indent
            -- Re-apply top indent for new column
            if cur_row < indent then cur_row = indent end
        end

        if id == GLYPH then
            layout_map[t] = {col=cur_col, row=cur_row}
            if cur_col > simulated_max_col then simulated_max_col = cur_col end
            cur_row = cur_row + 1
        elseif id == GLUE then
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
        elseif id == PENALTY and D.getfield(t, "penalty") <= -10000 then
             -- Forced break
             if cur_row > 0 then
                 cur_col = cur_col + 1
                 cur_row = 0
                 cur_column_indent = 0 -- Reset column indent for next column
             end
        end
        
        -- Wrap again if advance pushed it over?
        if cur_row >= effective_limit then
             -- Wait, if we just placed a glyph at (limit-1), cur_row becomes limit.
             -- Does it wrap now or next start?
             -- Next start checks `>=`. So it wraps then. Correct.
        end
        
        t = D.getnext(t)
    end
    
    local total_cols = simulated_max_col + 1
    
    -- Draw border (same as before)
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
            d_head = D.insert_before(d_head, d_head, D.todirect(n_node))
        end
    end

    -- Second Pass: Apply positions linearly
    local t = d_head
    while t do
        local id = D.getid(t)
        local next_node = D.getnext(t) -- Save next before modifying links (injection)
        
        if id == GLYPH then
            local pos = layout_map[t]
            if pos then
                local col = pos.col
                local row = pos.row
                
                local d = D.getfield(t, "depth")
                local h = D.getfield(t, "height")
                local w = D.getfield(t, "width")

                local rtl_col = total_cols - 1 - col
                local final_x = rtl_col * grid_width + (grid_width - w) / 2

                -- Calculate vertical position based on alignment
                local final_y
                if vertical_align == "top" then
                    -- Align to top of grid cell (baseline at top)
                    final_y = -row * grid_height - h
                elseif vertical_align == "center" then
                    -- Center vertically in grid cell
                    local char_total_height = h + d
                    final_y = -row * grid_height - (grid_height + char_total_height) / 2 + d
                else -- "bottom" (default/original behavior)
                    -- Align to bottom of grid cell (using depth)
                    final_y = -row * grid_height - grid_height + d
                end

                D.setfield(t, "xoffset", final_x)
                D.setfield(t, "yoffset", final_y)
                
                -- Fix PDF selection (Inject negative kern to cancel advance)
                local k = D.new(KERN)
                D.setfield(k, "kern", -w)
                D.setlink(t, k)
                if next_node then D.setlink(k, next_node) end
                
                -- Draw debug grid
                if draw_debug then
                     local tx_bp = (rtl_col * grid_width) * sp_to_bp
                     local ty_bp = (-row * grid_height) * sp_to_bp
                     local literal = string.format("q 0.5 w 0 0 1 RG 1 0 0 1 %.4f %.4f cm 0 0 %.4f %.4f re S Q",
                         tx_bp, ty_bp, w_bp, h_bp
                     )
                     local nn = node.new("whatsit", "pdf_literal")
                     nn.data = literal
                     nn.mode = 0
                     D.insert_before(d_head, t, D.todirect(nn))
                end
            end
        elseif id == GLUE then
             -- Zero out glue width
             D.setfield(t, "width", 0)
             D.setfield(t, "stretch", 0)
             D.setfield(t, "shrink", 0)
        elseif id == KERN then
             -- Zero out kerns
             D.setfield(t, "kern", 0)
        end
        
        t = next_node
    end
    
    return D.tonode(d_head), (total_cols * line_limit)
end

-- Main entry point called from TeX
function cn_vertical.make_grid_box(box_num, height, grid_width, grid_height, col_limit, debug_on, border_on, border_padding, vertical_align)
    local box = tex.box[box_num]
    if not box then return end

    local g_width = to_dimen(grid_width) or (65536 * 20)

    local list = box.list
    if not list then return end

    local g_height = to_dimen(grid_height) or g_width

    -- Use grid_height (char height) as approximate char width for indent calculation
    -- For square Chinese characters, char_width ≈ char_height
    local char_width = g_height

    -- If captured as VBOX, flatten it first
    if box.id == 1 then
        list = flatten_vbox(list, g_width, char_width)
    end
    local h_dim = to_dimen(height) or (65536 * 300)
    local b_padding = to_dimen(border_padding) or 0

    local limit = tonumber(col_limit)
    if not limit or limit <= 0 then
        limit = math.floor(h_dim / g_height)
    end

    local is_debug = (debug_on == "true" or debug_on == true)
    local is_border = (border_on == "true" or border_on == true)

    -- Parse vertical alignment (default: center)
    local valign = vertical_align or "center"
    if valign ~= "top" and valign ~= "center" and valign ~= "bottom" then
        valign = "center"
    end

    -- Process the list
    local new_head, final_count = grid_layout_nodes(list, g_width, g_height, limit, is_debug, is_border, b_padding, valign)

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
