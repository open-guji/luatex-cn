-- Copyright 2026 Open-Guji (https://github.com/open-guji)
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- ============================================================================
-- core_sidenote.lua - 侧批（Side Annotation）处理模块
-- ============================================================================

local constants = package.loaded['core.luatex-cn-constants'] or
    require('core.luatex-cn-constants')
local utils = package.loaded['util.luatex-cn-utils'] or
    require('util.luatex-cn-utils')
local debug = package.loaded['debug.luatex-cn-debug'] or
    require('debug.luatex-cn-debug')
local style_registry = package.loaded['util.luatex-cn-style-registry'] or
    require('util.luatex-cn-style-registry')
local judou = package.loaded['guji.luatex-cn-guji-judou'] or
    require('guji.luatex-cn-guji-judou')
local punct_mod = package.loaded['core.luatex-cn-core-punct'] or
    require('core.luatex-cn-core-punct')
local setting_stack = package.loaded['util.luatex-cn-setting-stack'] or
    require('util.luatex-cn-setting-stack')
local text_position = package.loaded['core.luatex-cn-render-position'] or
    require('core.luatex-cn-render-position')
local helpers = package.loaded['core.luatex-cn-layout-grid-helpers'] or
    require('core.luatex-cn-layout-grid-helpers')
local D = node.direct

local dbg = debug.get_debugger('sidenote')

-- Safely resolve dimension value that may be a table (em unit) or number
-- Forward-declared here so render() can use it (defined before Internal Helpers section)
local function safe_resolve(val, font_size_sp)
    if type(val) == "table" and val.unit == "em" then
        return math.floor((val.value or 0) * (font_size_sp or 655360) + 0.5)
    end
    return tonumber(val) or 0
end

local sidenote = {}

-- Registry to hold sidenote content
sidenote.registry = {}
sidenote.registry_counter = 0

-- ============================================================================
-- Plugin Standard API
-- ============================================================================

--- Initialize Sidenote Plugin
-- @param params (table) Parameters from TeX
-- @param engine_ctx (table) Shared engine context
-- @return (table|nil) Plugin context or nil if disabled
function sidenote.initialize(params, engine_ctx)
    -- Sidenotes are currently always active if the module is loaded,
    -- but we could add a 'sidenote_on' parameter check here later.
    return {
        map = {} -- This will store the results of calculate_sidenote_positions
    }
end

--- Plugin integration for layout stage
function sidenote.layout(list, layout_map, engine_ctx, context)
    if not context then return end

    local sidenote_map = sidenote.calculate_sidenote_positions(layout_map, {
        list = list,
        page_columns = engine_ctx.page_columns,
        line_limit = engine_ctx.line_limit,
        n_column = engine_ctx.n_column,
        banxin_on = engine_ctx.banxin_on,
        grid_height = engine_ctx.g_height
    })

    context.map = sidenote_map
end

--- Plugin integration for render stage
function sidenote.render(head, layout_map, params, context, engine_ctx, page_idx, p_total_cols)
    if not (context and context.map) then return head end

    local sidenote_for_page = {}
    for sid, sn_list in pairs(context.map) do
        for _, node_info in ipairs(sn_list) do
            if node_info.page == page_idx then
                table.insert(sidenote_for_page, node_info)
            end
        end
    end

    if #sidenote_for_page == 0 then return head end

    dbg.log(string.format("Rendering %d nodes on page %d", #sidenote_for_page, page_idx))

    local d_head = D.todirect(head)

    local render_page = package.loaded['core.luatex-cn-core-render-page'] or
        require('core.luatex-cn-core-render-page')

    local sidenote_x_offset = engine_ctx.g_width * 0.9

    -- Build sidenote sublist first (using original reverse iteration to maintain correct order)
    local sn_head = nil
    local sidenote_color = nil  -- Track color from first sidenote node's attribute
    local linemark_entries = {}  -- Collect linemark entries for batch rendering

    for i = #sidenote_for_page, 1, -1 do
        local item = sidenote_for_page[i]
        local curr = item.node
        D.setnext(curr, nil)

        -- Extract font_color from node's ATTR_STYLE_REG_ID (Phase 2: Style registry)
        if not sidenote_color then
            local style_id = D.get_attribute(curr, constants.ATTR_STYLE_REG_ID)
            if style_id then
                sidenote_color = style_registry.get_font_color(style_id)
            end
        end

        if not sn_head then
            sn_head = curr
        else
            sn_head = D.insert_before(sn_head, sn_head, curr)
        end

        local meta_xshift = safe_resolve(item.metadata and item.metadata.xshift, engine_ctx.g_height)
        local pos = {
            col = item.col,
            y_sp = item.y_sp,
            sidenote_offset = sidenote_x_offset,
            xshift = meta_xshift,
        }

        local id = D.getid(curr)
        if id == constants.GLYPH then
            local d = D.getfield(curr, "depth") or 0
            local h = D.getfield(curr, "height") or 0
            local w = D.getfield(curr, "width") or 0

            local rtl_col = p_total_cols - 1 - pos.col
            local boundary_x = text_position.get_column_x(rtl_col + 1, engine_ctx.col_geom)
                + engine_ctx.half_thickness + engine_ctx.shift_x
            local final_x = boundary_x - (w / 2) + (pos.xshift or 0)

            local cell_h = item.cell_height or engine_ctx.g_height

            -- em 框居中（固定基线，见 render-position 的 get_em_span）；
            -- 标点保持墨迹居中，字体无参数时同样退回墨迹居中
            local asc, desc
            if D.get_attribute(curr, constants.ATTR_PUNCT_TYPE) == nil then
                asc, desc = text_position.get_em_span(D.getfield(curr, "font"))
            end
            if not asc then asc, desc = h, d end
            local final_y = -pos.y_sp - (cell_h + asc + desc) / 2 + desc -
                engine_ctx.shift_y

            D.setfield(curr, "xoffset", final_x)
            D.setfield(curr, "yoffset", final_y)

            -- Collect linemark entries (专名号/书名号)
            local lm_id = D.get_attribute(curr, constants.ATTR_LINE_MARK_ID)
            if lm_id and lm_id > 0 then
                linemark_entries[#linemark_entries + 1] =
                    helpers.create_linemark_entry({
                        group_id = lm_id,
                        col = item.col,
                        y_sp = pos.y_sp,
                        x_center_sp = boundary_x,
                        font_size = cell_h,
                    })
            end

            local k = D.new(constants.KERN)
            D.setfield(k, "kern", -w)
            D.insert_after(sn_head, curr, k)
        elseif id == constants.HLIST or id == constants.VLIST then
            sn_head = render_page._internal.handle_block_node(curr, sn_head, pos, engine_ctx)
        elseif id == constants.WHATSIT then
            -- Preserve whatsit nodes (including pdf_colorstack for color preservation)
            -- These nodes don't need position adjustment, just need to be kept in the list
            -- This is crucial for maintaining color across page boundaries
        else
            if id == constants.GLUE then
                D.setfield(curr, "width", 0)
                D.setfield(curr, "stretch", 0)
                D.setfield(curr, "shrink", 0)
            end
        end

        sn_head = render_page._internal.handle_debug_drawing(curr, sn_head, pos, engine_ctx)
    end

    -- Render linemark lines for sidenote characters (专名号/书名号)
    if #linemark_entries > 0 and sn_head then
        local linemark_mod = package.loaded['decorate.luatex-cn-linemark'] or
            require('decorate.luatex-cn-linemark')
        local lm_ctx = {
            grid_width = engine_ctx.g_width,
            grid_height = engine_ctx.g_height,
            p_total_cols = p_total_cols,
            shift_x = engine_ctx.shift_x,
            shift_y = engine_ctx.shift_y,
            half_thickness = engine_ctx.half_thickness,
            banxin_width = engine_ctx.banxin_width or 0,
            interval = engine_ctx.n_column or 0,
        }
        sn_head = linemark_mod.render_line_marks(sn_head, linemark_entries, lm_ctx)
    end

    -- Build background fill rectangles per cell (issue #93).
    -- When a sidenote has background_color set, fill the cell behind each glyph
    -- so the column borders (界行) under the sidenote are visually masked.
    -- Special value "page" / "inherit" / 继承 / 页面 inherits the page background
    -- color, which makes the sidenote blend into the page.
    if sn_head then
        local bg_literals = sidenote._build_bg_literals(sidenote_for_page,
            engine_ctx, p_total_cols)
        for i = #bg_literals, 1, -1 do
            sn_head = D.insert_before(sn_head, sn_head, bg_literals[i])
        end
    end

    -- Append sidenote sublist to end of main list (so sidenotes render on top of borders)
    if sn_head then
        -- ALWAYS wrap sidenote content with q/Q to prevent color leakage
        -- This is critical when sidenotes cross page boundaries, as embedded
        -- pdf_colorstack nodes (from TeX \color commands) may be split across pages
        local q_push = utils.create_pdf_literal("q")
        sn_head = D.insert_before(sn_head, sn_head, q_push)

        -- Set the sidenote color from style_registry. This is important for
        -- cross-page sidenotes where the second page's content may not have
        -- the colorstack push (which is on the first page).
        -- Also serves as a color reset to prevent leakage from unbalanced pops.
        local last_inserted = q_push
        if sidenote_color and sidenote_color ~= "" then
            local rgb_str = utils.normalize_rgb(sidenote_color)
            if rgb_str then
                local color_cmd = string.format("%s rg %s RG", rgb_str, rgb_str)
                local color_literal = utils.create_pdf_literal(color_cmd)
                D.insert_after(sn_head, q_push, color_literal)
                last_inserted = color_literal
            end
        else
            -- Fallback: reset to black if no color specified
            local color_reset = utils.create_pdf_literal("0 0 0 rg 0 0 0 RG")
            D.insert_after(sn_head, q_push, color_reset)
            last_inserted = color_reset
        end

        -- Find the tail and insert Q at the end
        local sn_tail = sn_head
        while D.getnext(sn_tail) do
            sn_tail = D.getnext(sn_tail)
        end
        local q_pop = utils.create_pdf_literal("Q")
        D.insert_after(sn_head, sn_tail, q_pop)

        if not d_head then
            d_head = sn_head
        else
            local d_tail = d_head
            while D.getnext(d_tail) do
                d_tail = D.getnext(d_tail)
            end
            D.setnext(d_tail, sn_head)
        end
    end

    return D.tonode(d_head)
end

-- ============================================================================
-- Internal Helpers
-- ============================================================================

local function serialize(t)
    if type(t) ~= "table" then return tostring(t) end
    local s = "{"
    for k, v in pairs(t) do
        s = s .. tostring(k) .. "=" .. tostring(v) .. ","
    end
    s = s .. "}"
    return s
end

local function create_gap_tracker()
    local gap_filled = {}
    return {
        get = function(p, c)
            if not gap_filled[p] then gap_filled[p] = {} end
            return gap_filled[p][c] or -1
        end,
        set = function(p, c, r)
            if not gap_filled[p] then gap_filled[p] = {} end
            gap_filled[p][c] = r
        end
    }
end

local function is_reserved_column(col, banxin_on, interval)
    if not banxin_on then return false end
    if interval <= 0 then return false end
    local hooks = package.loaded['core.luatex-cn-hooks'] or
        require('core.luatex-cn-hooks')
    return hooks.is_reserved_column(col, interval)
end

local function skip_to_valid_column(p, c, p_cols, banxin_on, interval)
    -- Only skip reserved columns (banxin), not the column right after banxin
    -- Sidenotes are offset to the right of the main text column, so they won't
    -- overlap with the banxin on the left
    while is_reserved_column(c, banxin_on, interval) or (c >= p_cols) do
        if c >= p_cols then
            c = 0
            p = p + 1
        else
            c = c + 1
        end
    end
    return p, c
end

local function extract_registry_content(registry_item)
    local content = nil
    local metadata = {}

    if type(registry_item) == "table" and registry_item.head then
        content = registry_item.head
        metadata = registry_item.metadata or {}
    else
        content = registry_item
    end
    return content, metadata
end

local function calculate_start_position(anchor_y_sp, metadata, main_grid_height)
    local yshift_grid = safe_resolve(metadata.yshift, main_grid_height) / main_grid_height
    local padding_top_grid = safe_resolve(metadata.padding_top, main_grid_height) / main_grid_height
    local anchor_row = anchor_y_sp / main_grid_height
    return math.max(anchor_row, padding_top_grid) + yshift_grid
end

-- Advance to the next valid (non-reserved) column on the current/next page,
-- aligning the row with the target column's body-text top boundary (taitou).
-- Only negative col_min_row values (taitou) affect alignment; positive
-- indent is ignored. Bumps past existing filled rows when present.
local function wrap_to_next_column(curr_p, curr_c, config)
    local next_p, next_c = curr_p, curr_c + 1
    next_p, next_c = skip_to_valid_column(next_p, next_c, config.p_cols, config.banxin_on, config.interval)

    local next_r = 0
    if config.col_min_row and config.col_min_row[next_p] then
        next_r = math.min(0, config.col_min_row[next_p][next_c] or 0)
    end

    local filled = config.tracker.get(next_p, next_c)
    if next_r <= filled and filled ~= -1 then
        next_r = filled + 0.1
    end

    return next_p, next_c, next_r
end

local function calculate_next_node_pos(curr_p, curr_c, curr_r, node_id, config)
    local next_p, next_c, next_r = curr_p, curr_c, curr_r

    -- Determine if this node consumes a row
    -- Note: GLUE nodes (spaces) should NOT consume rows in vertical typesetting
    if node_id == constants.GLYPH or node_id == constants.HLIST or
        node_id == constants.VLIST or node_id == constants.RULE then
        next_r = curr_r + config.step
    end

    if next_r + config.padding_bottom_grid >= config.line_limit then
        next_p, next_c, next_r = wrap_to_next_column(curr_p, curr_c, config)
    end

    return next_p, next_c, next_r
end

-- Scan layout_map to find the minimum row for each column on each page.
-- This captures taitou (negative row) information so wrapped sidenote content
-- can align with the body text's top boundary in the target column.
-- Returns: col_min_row[page][col] = min_row (can be negative)
local function build_col_min_row(layout_map, grid_height)
    local col_min_y = {}
    for _, pos in pairs(layout_map) do
        -- Only consider entries with valid page/col/y_sp, excluding placeholders
        if pos.page and pos.col and pos.y_sp and pos.mode ~= "placeholder" then
            local p, c = pos.page, pos.col
            if not col_min_y[p] then col_min_y[p] = {} end
            local cur = col_min_y[p][c]
            if not cur or pos.y_sp < cur then
                col_min_y[p][c] = pos.y_sp
            end
        end
    end
    -- Convert SP to row units
    local col_min_row = {}
    for p, cols in pairs(col_min_y) do
        col_min_row[p] = {}
        for c, y in pairs(cols) do
            col_min_row[p][c] = math.floor(y / grid_height)
        end
    end
    return col_min_row
end

local function place_individual_sidenote(sid, registry_item, last_node_pos, params, tracker)
    local content, metadata = extract_registry_content(registry_item)
    if not (content and sid and last_node_pos) then return nil end

    local p_cols = params.page_columns or 10
    local line_limit = params.line_limit or 20
    local main_grid_height = params.grid_height or (65536 * 20)
    local effective_gh = (metadata.grid_height and metadata.grid_height > 0)
        and metadata.grid_height or main_grid_height
    local step = 1
    if metadata.grid_height and metadata.grid_height > 0 then
        step = metadata.grid_height / main_grid_height
    end

    local config = {
        p_cols = p_cols,
        line_limit = line_limit,
        banxin_on = params.banxin_on,
        interval = params.n_column or 0,
        padding_top_grid = safe_resolve(metadata.padding_top, main_grid_height) / main_grid_height,
        padding_bottom_grid = safe_resolve(metadata.padding_bottom, main_grid_height) / main_grid_height,
        step = step,
        tracker = tracker,
        base_indent = last_node_pos.indent or 0,
        col_min_row = params.col_min_row,
    }

    local curr_p, curr_c = last_node_pos.page, last_node_pos.col
    local base_indent = last_node_pos.indent or 0
    local anchor_y_sp = last_node_pos.y_sp or 0
    dbg.log(string.format("Placing sid=%d at p=%d, c=%d, anchor_y_sp=%.0f, indent=%d",
        sid, curr_p, curr_c, anchor_y_sp, base_indent))

    curr_p, curr_c = skip_to_valid_column(curr_p, curr_c, p_cols, config.banxin_on, config.interval)

    local curr_r = calculate_start_position(anchor_y_sp, metadata, main_grid_height)
    local filled_r = tracker.get(curr_p, curr_c)
    -- Push down if the current row is at or below existing content. Skip when
    -- filled_r is the default (-1), so taitou (negative curr_r) is preserved.
    if curr_r <= filled_r and filled_r ~= -1 then
        curr_r = filled_r + 0.1
    end

    -- Reverse flow: a negative curr_r (from yshift) starts the sidenote in a
    -- prior column. Walk backwards skipping reserved (banxin) columns. At the
    -- page 0 / column 0 boundary, clamp to the first valid column at row 0.
    while curr_r < 0 do
        curr_c = curr_c - 1
        if curr_c < 0 then
            if curr_p > 0 then
                curr_p = curr_p - 1
                curr_c = p_cols - 1
            else
                curr_r = 0
                curr_p, curr_c = skip_to_valid_column(0, 0, p_cols, config.banxin_on, config.interval)
                break
            end
        end
        if not is_reserved_column(curr_c, config.banxin_on, config.interval) then
            curr_r = config.line_limit + curr_r
        end
    end

    -- Anchor sits at the bottom of the column (e.g. last character): push the
    -- first sidenote glyph into the next column so it doesn't ride the edge.
    if curr_r + config.padding_bottom_grid >= config.line_limit then
        curr_p, curr_c, curr_r = wrap_to_next_column(curr_p, curr_c, config)
    end

    local placed_nodes = {}
    local current_content_node = D.todirect(content)

    while current_content_node do
        table.insert(placed_nodes, {
            node = current_content_node,
            page = curr_p,
            col = curr_c,
            y_sp = curr_r * main_grid_height,
            cell_height = effective_gh,
            metadata = metadata
        })

        tracker.set(curr_p, curr_c, curr_r)

        local nid = D.getid(current_content_node)
        curr_p, curr_c, curr_r = calculate_next_node_pos(curr_p, curr_c, curr_r, nid, config)
        current_content_node = D.getnext(current_content_node)
    end

    return placed_nodes
end

local function find_sidenote_anchors(head, layout_map, on_sidenote_found)
    local t = head
    local last_node_pos = nil
    while t do
        local id = D.getid(t)
        if id == constants.WHATSIT then
            local uid = D.getfield(t, "user_id")
            -- dbg.log("Found whatsit, uid=" .. tostring(uid))
            if uid == constants.SIDENOTE_USER_ID then
                local sid = D.getfield(t, "value")
                local indent = D.get_attribute(t, constants.ATTR_INDENT) or 0
                local pos = layout_map[t]
                if pos then
                    local anchor_pos = {
                        page = pos.page,
                        col = pos.col,
                        y_sp = pos.y_sp or 0,
                        indent = indent
                    }
                    on_sidenote_found(sid, anchor_pos)
                else
                    -- Fallback to last node if whatsit not in layout map
                    on_sidenote_found(sid, last_node_pos)
                end
            end
        else
            if layout_map[t] then
                last_node_pos = layout_map[t]
            end
        end
        t = D.getnext(t)
    end
end

--- Resolve sidenote background color value to RGB string.
-- Returns nil for empty/none values. Special tokens "page", "inherit",
-- "继承", "页面", "頁面" inherit from the page background color (white when
-- no page background is configured, since that's what the page actually shows).
local function resolve_bg_color(bg_color)
    if not bg_color then return nil end
    local s = tostring(bg_color)
    if s == "" or s == "none" then return nil end
    local low_s = s:lower():gsub("^%s*(.-)%s*$", "%1")
    if low_s == "page" or low_s == "inherit"
        or low_s == "继承" or low_s == "页面" or low_s == "頁面" then
        local tex_bg = utils.get_tex_tl("l__luatexcn_page_background_color_tl")
        return utils.normalize_rgb(tex_bg) or "1.0000 1.0000 1.0000"
    end
    return utils.normalize_rgb(s)
end

--- Build PDF fill-rectangle literal nodes behind sidenote glyphs (issue #93).
-- Each placed sidenote node that consumes a row gets a small rectangle of
-- the same height as its cell, centered on the column boundary. The
-- rectangle masks any column borders (界行) underneath the sidenote text.
function sidenote._build_bg_literals(sidenote_for_page, engine_ctx, p_total_cols)
    local literals = {}
    if not sidenote_for_page or #sidenote_for_page == 0 then return literals end

    local sp_to_bp = utils.sp_to_bp
    for _, item in ipairs(sidenote_for_page) do
        local id = D.getid(item.node)
        local consumes_row = (id == constants.GLYPH or id == constants.HLIST
            or id == constants.VLIST or id == constants.RULE)
        if consumes_row then
            local bg_rgb = resolve_bg_color(
                item.metadata and item.metadata.background_color)
            if bg_rgb then
                local cell_h = item.cell_height or engine_ctx.g_height
                local font_size_sp = (item.metadata
                    and tonumber(item.metadata.font_size)) or cell_h
                local rtl_col = p_total_cols - 1 - item.col
                local boundary_x = text_position.get_column_x(rtl_col + 1,
                    engine_ctx.col_geom)
                    + (engine_ctx.half_thickness or 0)
                    + (engine_ctx.shift_x or 0)
                local meta_xshift = safe_resolve(
                    item.metadata and item.metadata.xshift,
                    engine_ctx.g_height)
                local center_x = boundary_x + meta_xshift
                local x_left = center_x - font_size_sp / 2
                local y_top = -item.y_sp - (engine_ctx.shift_y or 0)
                local literal_str = utils.create_fill_rect_literal(bg_rgb,
                    x_left * sp_to_bp,
                    y_top * sp_to_bp,
                    font_size_sp * sp_to_bp,
                    -cell_h * sp_to_bp)
                literals[#literals + 1] = utils.create_pdf_literal(literal_str)
            end
        end
    end
    return literals
end

-- Expose internal functions for unit testing
sidenote._internal = {
    serialize = serialize,
    create_gap_tracker = create_gap_tracker,
    is_reserved_column = is_reserved_column,
    skip_to_valid_column = skip_to_valid_column,
    extract_registry_content = extract_registry_content,
    calculate_start_position = calculate_start_position,
    calculate_next_node_pos = calculate_next_node_pos,
    wrap_to_next_column = wrap_to_next_column,
    build_col_min_row = build_col_min_row,
    place_individual_sidenote = place_individual_sidenote,
    find_sidenote_anchors = find_sidenote_anchors
}

-- ============================================================================
-- Public API
-- ============================================================================

--- Register a sidenote from a TeX box
function sidenote.register_sidenote(box_num, metadata)
    local box = tex.box[box_num]
    if not box then
        dbg.log("register_sidenote: box is nil!")
        return
    end

    sidenote.registry_counter = sidenote.registry_counter + 1
    local id = sidenote.registry_counter

    local content_head = node.copy_list(box.list)

    -- Build setting overrides from metadata (passed from TeX via \Sidenote[punct-mode=...])
    local setting_overrides = {}
    if metadata and metadata.punct_mode and metadata.punct_mode ~= "" then
        setting_overrides.punct_mode = metadata.punct_mode
    end
    if metadata and metadata.punct_style and metadata.punct_style ~= "" then
        setting_overrides.punct_style = metadata.punct_style
    end

    -- Push component-level settings (inherits global if no override)
    setting_stack.push(setting_overrides)
    local settings = setting_stack.current()

    -- Apply punctuation processing based on setting stack
    local effective_mode = settings.punct_mode or "normal"
    if effective_mode == "normal" then
        -- Normal mode: apply punct.flatten for vertical form replacement
        -- (e.g. 《》→︽︾, 「」→﹁﹂, ""→﹁﹂)
        local punct_ctx = {
            style   = (_G.punct and _G.punct.style) or "mainland",
            squeeze = not (_G.punct and _G.punct.squeeze == false),
            kinsoku = not (_G.punct and _G.punct.kinsoku == false),
        }
        content_head = punct_mod.flatten(content_head, {}, punct_ctx)
    else
        local judou_ctx = {
            mode = effective_mode,
            punct_mode = effective_mode,
            pos = (_G.judou and _G.judou.pos) or "right-bottom",
            size = (_G.judou and _G.judou.size) or "1em",
            color = (_G.judou and _G.judou.color) or "red",
        }
        content_head = judou.flatten(content_head, {}, judou_ctx)
    end

    -- Pop setting stack (restore previous settings)
    setting_stack.pop()

    -- Register style and set attribute on all nodes (Phase 2: Style registry)
    local font_color_str = metadata and metadata.font_color
    local font_size_str = metadata and metadata.font_size

    -- Build style table with all available attributes
    local style = {}
    if font_color_str and font_color_str ~= "" then
        style.font_color = font_color_str
    end
    if font_size_str and font_size_str ~= "" then
        style.font_size = constants.to_dimen(font_size_str)
    end

    -- Register style and set attribute if any style attributes are present
    if next(style) then  -- Check if style table is not empty
        local style_reg_id = style_registry.register(style)
        -- Traverse the node list and set ATTR_STYLE_REG_ID on all nodes
        for n in node.traverse(content_head) do
            node.set_attribute(n, constants.ATTR_STYLE_REG_ID, style_reg_id)
        end
    end

    sidenote.registry[id] = {
        head = content_head,
        metadata = metadata or {}
    }

    dbg.log(string.format("Registered sidenote ID=%d, metadata=%s", id, serialize(metadata or {})))

    local n = node.new("whatsit", "user_defined")
    n.user_id = constants.SIDENOTE_USER_ID
    n.type = 100
    n.value = id
    node.write(n)
end

--- Calculate positions for sidenotes based on main layout
function sidenote.calculate_sidenote_positions(layout_map, params)
    local sidenote_map = {}
    local list = params.list
    if not list then return {} end

    -- Build column-min-row map from the main text layout to support
    -- taitou-aware wrapping: wrapped sidenote content aligns with body text's
    -- top boundary in the target column.
    local grid_height = params.grid_height or (65536 * 20)
    params.col_min_row = build_col_min_row(layout_map, grid_height)

    local tracker = create_gap_tracker()
    local t = D.todirect(list)

    find_sidenote_anchors(t, layout_map, function(sid, last_node_pos)
        local registry_item = sidenote.registry[sid]
        local placed_nodes = place_individual_sidenote(sid, registry_item, last_node_pos, params, tracker)
        if placed_nodes then
            sidenote_map[sid] = placed_nodes
            dbg.log(string.format("Placed sidenote sid=%d with %d nodes", sid, #placed_nodes))
        end
    end)

    return sidenote_map
end

--- Clear the sidenote registry to free node memory
function sidenote.clear_registry()
    sidenote.registry = {}
    sidenote.registry_counter = 0
end

package.loaded['core.luatex-cn-core-sidenote'] = sidenote
return sidenote
