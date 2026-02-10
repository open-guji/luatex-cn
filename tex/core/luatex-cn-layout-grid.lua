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
-- layout_grid.lua - 虚拟网格布局计算（第二阶段）
-- ============================================================================
-- 文件名: layout_grid.lua (原 layout.lua)
-- 层级: 第二阶段 - 布局层 (Stage 2: Layout Layer)
--
-- 【模块功能 / Module Purpose】
-- 本模块负责排版流水线的第二阶段，在不修改节点的情况下进行"虚拟布局模拟"：
--   1. 遍历节点流，计算每个节点应该出现在哪一页、哪一列、第几行
--   2. 处理自动换列、分页逻辑（当行数超过 line_limit 时）
--   3. 避让版心（banxin）列位置，确保不在版心列放置正文内容
--   4. 支持"分布模式"（distribute），在列内均匀分布字符（用于 textbox）
--   5. 维护占用地图（occupancy map），防止 textbox 块与其他内容重叠
--
-- 【术语对照 / Terminology】
--   layout_map        - 布局映射（节点指针 → 坐标位置）
--   cur_page/col/row  - 当前光标位置（页/列/行）
--   banxin            - 版心（古籍中间的分隔列）
--   occupancy         - 占用地图（记录已被使用的网格位置）
--   line_limit        - 每列最大行数
--   page_columns      - 每页最大列数
--   effective_limit   - 有效行数限制（考虑右缩进后）
--   col_buffer        - 列缓冲区（用于分布模式）
--   distribute        - 分布模式（均匀分布字符）
--
-- 【注意事项】
--   • 本模块只计算位置（layout_map），不修改节点本身
--   • 版心列由 n_column 参数控制：每 (n_column + 1) 列就是一个版心列
--   • 右缩进（r_indent）会缩短列的有效高度（effective_limit）
--   • Textbox 块（由 core_textbox.lua 处理生成）占用多个网格单元（width × height）
--   • Textbox 在外部布局中始终表现为一个 width=1 的块，高度由其内容决定
--   • Penalty≤-10000 会触发强制换列（由 flatten_nodes.lua 插入）
--
-- 【整体架构 / Architecture】
--   输入: 一维节点流 + grid_height + line_limit + n_column + page_columns
--      ↓
--   calculate_grid_positions()
--      ├─ 维护光标状态 (cur_page, cur_col, cur_row)
--      ├─ 遍历每个节点
--      │   ├─ 应用缩进逻辑（hanging indent）
--      │   ├─ 检查是否需要换列/分页
--      │   ├─ 跳过版心列和已占用位置
--      │   └─ 记录位置到 layout_map[node] = {page, col, row}
--      └─ Textbox 块额外标记 occupancy 地图
--      ↓
--   输出: layout_map (节点指针 → 坐标) + total_pages
--
-- ============================================================================

-- Load dependencies
-- Check if already loaded via dofile (package.loaded set manually)
local constants = package.loaded['core.luatex-cn-constants'] or
    require('core.luatex-cn-constants')
local D = constants.D
local utils = package.loaded['util.luatex-cn-utils'] or
    require('util.luatex-cn-utils')
local hooks = package.loaded['core.luatex-cn-hooks'] or
    require('core.luatex-cn-hooks')
local debug = package.loaded['debug.luatex-cn-debug'] or
    require('debug.luatex-cn-debug')
local style_registry = package.loaded['util.luatex-cn-style-registry'] or
    require('util.luatex-cn-style-registry')

local dbg = debug.get_debugger('layout')

local _internal = {}

-- =============================================================================
-- Helper functions to get params with fallback to globals
-- =============================================================================

-- Helper to get banxin_on with fallback to _G.banxin.enabled
local function get_banxin_on(params)
    if params and params.banxin_on ~= nil then
        return params.banxin_on
    end
    return _G.banxin and _G.banxin.enabled or false
end

-- Helper to get grid_width with fallback to _G.content.grid_width
local function get_grid_width(params, fallback)
    if params and params.grid_width and params.grid_width > 0 then
        return params.grid_width
    end
    if _G.content and _G.content.grid_width and _G.content.grid_width > 0 then
        return _G.content.grid_width
    end
    return fallback or (65536 * 20)
end

-- Helper to get margin_right with fallback to _G.page.margin_right
local function get_margin_right(params)
    if params and params.margin_right then
        if type(params.margin_right) == "number" then
            return params.margin_right
        else
            return constants.to_dimen(params.margin_right) or 0
        end
    end
    return _G.page and _G.page.margin_right or 0
end

-- Helper to get chapter_title with fallback to _G.metadata.chapter_title
local function get_chapter_title(params)
    if params and params.chapter_title and params.chapter_title ~= "" then
        return params.chapter_title
    end
    return _G.metadata and _G.metadata.chapter_title or ""
end

_internal.get_banxin_on = get_banxin_on
_internal.get_grid_width = get_grid_width
_internal.get_margin_right = get_margin_right
_internal.get_chapter_title = get_chapter_title

-- =============================================================================
-- Helpers to get style attributes from node's style registry attribute
-- =============================================================================

-- Extract font_color from node's ATTR_STYLE_REG_ID attribute
-- Returns font_color string (e.g., "1 0 0" for red) or nil
local function get_node_font_color(node)
    local style_id = D.get_attribute(node, constants.ATTR_STYLE_REG_ID)
    if style_id and style_id > 0 then
        return style_registry.get_font_color(style_id)
    end
    return nil
end

-- Extract font_size from node's ATTR_STYLE_REG_ID attribute
-- Returns font_size in sp (scaled points) or nil
local function get_node_font_size(node)
    local style_id = D.get_attribute(node, constants.ATTR_STYLE_REG_ID)
    if style_id and style_id > 0 then
        return style_registry.get_font_size(style_id)
    end
    return nil
end

-- Extract font name/family from node's ATTR_STYLE_REG_ID attribute
-- Returns font name string or nil
local function get_node_font(node)
    local style_id = D.get_attribute(node, constants.ATTR_STYLE_REG_ID)
    if style_id and style_id > 0 then
        return style_registry.get_font(style_id)
    end
    return nil
end

-- =============================================================================
-- Column validation functions
-- =============================================================================

local function is_reserved_col(col, interval, banxin_on)
    if not banxin_on then return false end
    if interval <= 0 then return false end
    return _G.core.hooks.is_reserved_column(col, interval)
end

local function is_center_gap_col(col, params, grid_height)
    local banxin_on = get_banxin_on(params)
    if not banxin_on then return false end

    -- Use provided params if available, fall back to globals
    local g_width = get_grid_width(params, grid_height)

    -- Use global page width (set by page.setup via \pageSetup)
    local paper_w = _G.page and _G.page.paper_width or 0
    if paper_w <= 0 then return false end

    local center = paper_w / 2
    local gap_half_width = 15 * 65536 -- 15pt in sp

    local floating_x = params and params.floating_x or 0
    if floating_x <= 0 then
        -- No explicit floating_x provided, use margin_right as the right origin
        -- (main text col 0 is anchored to margin_right)
        floating_x = get_margin_right(params)
    end

    local col_right_x = floating_x + col * g_width
    local col_left_x = col_right_x + g_width

    local gap_left = center - gap_half_width
    local gap_right = center + gap_half_width

    local overlaps = (col_right_x < gap_right) and (col_left_x > gap_left)

    return overlaps
end

_internal.is_reserved_col = is_reserved_col
_internal.is_center_gap_col = is_center_gap_col

local function is_occupied(occupancy, p, c, r)
    if not occupancy[p] then return false end
    if not occupancy[p][c] then return false end
    return occupancy[p][c][r] == true
end

local function mark_occupied(occupancy, p, c, r)
    if not occupancy[p] then occupancy[p] = {} end
    if not occupancy[p][c] then occupancy[p][c] = {} end
    occupancy[p][c][r] = true
end

--- Get cell height for a node in natural layout mode
-- Returns font_size from style registry, or actual font size,
-- or grid_height as fallback.
-- Punctuation nodes (ATTR_PUNCT_TYPE > 0) get half height
local function get_cell_height(node, grid_height)
    local base
    local fs = get_node_font_size(node)
    if fs and fs > 0 then
        base = fs
    else
        local fid = D.getfield(node, "font")
        if fid then
            local f = font.getfont(fid)
            if f and f.size then base = f.size end
        end
    end
    base = base or grid_height
    -- Punctuation occupies half cell
    local punct_type = D.get_attribute(node, constants.ATTR_PUNCT_TYPE)
    if punct_type and punct_type > 0 then
        return math.floor(base * 0.5)
    end
    return base
end

local function create_grid_context(params, line_limit, p_cols)
    -- Use helper for chapter_title with fallback to _G.metadata
    local initial_chapter = get_chapter_title(params)
    local layout_mode = (params and params.layout_mode) or "grid"
    local col_height_sp = (params and params.col_height_sp) or 0
    local inter_cell_gap = (params and params.inter_cell_gap) or 0
    local ctx = {
        cur_page = 0,
        cur_col = 0,
        cur_row = 0,
        occupancy = {},
        params = params,
        line_limit = line_limit,
        p_cols = p_cols,
        cur_column_indent = 0,
        page_has_content = false,
        chapter_title = initial_chapter,
        page_chapter_titles = {}, -- To store chapter title for each page
        last_glyph_row = -1, -- Track last glyph row for detecting line changes
        -- Natural layout mode fields
        layout_mode = layout_mode,
        cur_y_sp = 0,
        col_height_sp = col_height_sp,
        inter_cell_gap = inter_cell_gap,
    }
    ctx.page_chapter_titles[0] = ctx.chapter_title -- Initialize page 0 with the initial chapter title
    return ctx
end


local function apply_indentation(ctx, indent)
    if not indent or indent == 0 then return end
    if indent < 0 then
        -- 负缩进（抬头）：列起始时设置 cur_row 为负值
        -- 用 cur_column_indent 追踪是否已应用，防止每个字符都重置
        -- （因为 -1+1=0，若用 cur_row<=0 判断会反复触发）
        if (ctx.cur_column_indent or 0) == 0 then
            ctx.cur_row = indent
            ctx.cur_column_indent = indent
        end
        return
    end
    -- 正缩进：保持原有逻辑
    if ctx.cur_row < indent then ctx.cur_row = indent end
    if indent > (ctx.cur_column_indent or 0) then ctx.cur_column_indent = indent end
    if ctx.cur_row < (ctx.cur_column_indent or 0) then ctx.cur_row = ctx.cur_column_indent end
end


local function move_to_next_valid_position(ctx, interval, grid_height, indent)
    local changed = true
    local banxin_on = get_banxin_on(ctx.params)
    while changed do
        changed = false
        -- Skip Banxin and register it
        while is_reserved_col(ctx.cur_col, interval, banxin_on) do
            -- Register this Banxin column for the current page
            if not ctx.banxin_registry[ctx.cur_page] then
                ctx.banxin_registry[ctx.cur_page] = {}
            end
            ctx.banxin_registry[ctx.cur_page][ctx.cur_col] = true

            ctx.cur_col = ctx.cur_col + 1
            if ctx.cur_col >= ctx.p_cols then
                ctx.cur_col = 0
                ctx.cur_page = ctx.cur_page + 1
            end
            changed = true
            -- When wrapping column/page, row reset must honor indent
            ctx.cur_row = 0
            ctx.cur_column_indent = 0
            if indent then apply_indentation(ctx, indent) end
        end
        -- Skip Center Gap
        while is_center_gap_col(ctx.cur_col, ctx.params, grid_height) do
            ctx.cur_col = ctx.cur_col + 1
            if ctx.cur_col >= ctx.p_cols then
                ctx.cur_col = 0
                ctx.cur_page = ctx.cur_page + 1
            end
            changed = true
            -- When wrapping column/page, row reset must honor indent
            ctx.cur_row = 0
            ctx.cur_column_indent = 0
            if indent then apply_indentation(ctx, indent) end
        end
        -- Skip Occupied
        if is_occupied(ctx.occupancy, ctx.cur_page, ctx.cur_col, ctx.cur_row) then
            ctx.cur_row = ctx.cur_row + 1
            if ctx.cur_row >= ctx.line_limit then
                ctx.cur_row = 0
                ctx.cur_col = ctx.cur_col + 1
                changed = true
                -- Reset column-specific indent tracker
                ctx.cur_column_indent = 0
                if indent then apply_indentation(ctx, indent) end
            else
                changed = true
                -- Row increment might need to re-check indent if we passed it then hit something?
                -- Actually skip indent is handled before placement usually.
            end
        end
    end
end

_internal.move_to_next_valid_position = move_to_next_valid_position

--- Wrap cursor to next column (and page if needed)
-- @param ctx (table) Grid context
-- @param p_cols (number) Total columns per page
-- @param interval (number) Banxin interval
-- @param grid_height (number) Grid height in sp
-- @param indent (number|nil) Current indent
-- @param reset_indent (boolean) Whether to reset column indent
-- @param reset_content (boolean) Whether to reset page_has_content flag
local function wrap_to_next_column(ctx, p_cols, interval, grid_height, indent, reset_indent, reset_content)
    -- Pop temporary indents when changing column
    style_registry.pop_temporary()

    ctx.cur_col = ctx.cur_col + 1
    ctx.cur_row = 0
    ctx.just_wrapped_column = true -- Flag for issue #54 fix
    -- Natural mode: reset Y accumulator
    if ctx.layout_mode == "natural" then
        ctx.cur_y_sp = 0
    end
    if ctx.cur_col >= p_cols then
        ctx.cur_col = 0
        ctx.cur_page = ctx.cur_page + 1
        -- Always reset page_has_content on page turn:
        -- new page has no content yet regardless of reset_content flag.
        -- (reset_content only controls same-page column wraps)
        ctx.page_has_content = false
    end
    if reset_indent then
        ctx.cur_column_indent = 0
    end
    move_to_next_valid_position(ctx, interval, grid_height, indent)
end

_internal.wrap_to_next_column = wrap_to_next_column

--- Accumulate consecutive glue/kern nodes and return total width
-- @param start_node (direct node) Starting node
-- @return (number, direct node) net_width in sp, and next non-spacing node
local function accumulate_spacing(start_node)
    local net_width = 0
    local lookahead = start_node

    while lookahead do
        local lid = D.getid(lookahead)
        if lid == constants.GLUE then
            net_width = net_width + (D.getfield(lookahead, "width") or 0)
        elseif lid == constants.KERN then
            net_width = net_width + (D.getfield(lookahead, "kern") or 0)
        elseif lid == constants.PENALTY then
            if D.getfield(lookahead, "penalty") <= -10000 then break end
        elseif lid == constants.WHATSIT then
            -- Skip whatsit nodes
        else
            break
        end
        lookahead = D.getnext(lookahead)
    end

    return net_width, lookahead
end

_internal.accumulate_spacing = accumulate_spacing

--- Handle penalty node for column/page breaks
-- @param p_val (number) Penalty value
-- @param ctx (table) Grid context
-- @param flush_buffer (function) Buffer flush function
-- @param p_cols (number) Columns per page
-- @param interval (number) Banxin interval
-- @param grid_height (number) Grid height
-- @param indent (number) Current indent
-- @return (boolean) true if handled, false otherwise
local function handle_penalty_breaks(p_val, ctx, flush_buffer_fn, p_cols, interval, grid_height, indent, penalty_node)
    if p_val == constants.PENALTY_FORCE_COLUMN then
        -- Forced column break (explicit \换行 command)
        flush_buffer_fn()
        -- Check for post-break indent (e.g., footnote indentation)
        local post_indent = penalty_node and D.get_attribute(penalty_node, constants.ATTR_COLUMN_BREAK_INDENT)
        if post_indent and post_indent > 0 then
            -- Footnote column break: wrap to new column only if current column
            -- has actual content (not just indentation space)
            if ctx.cur_row > ctx.cur_column_indent then
                wrap_to_next_column(ctx, p_cols, interval, grid_height, indent, false, true)
            end
            ctx.cur_row = post_indent
            ctx.cur_column_indent = 0
        else
            if ctx.cur_row > ctx.cur_column_indent then
                wrap_to_next_column(ctx, p_cols, interval, grid_height, indent, false, true)
            end
            ctx.cur_column_indent = 0
        end
        return true
    elseif p_val == constants.PENALTY_FORCE_PAGE then
        -- Forced page break (\newpage, \clearpage)
        if ctx.page_has_content then
            flush_buffer_fn()
            ctx.cur_page = ctx.cur_page + 1
            ctx.cur_col = 0
            ctx.cur_row = 0
            ctx.cur_column_indent = 0
            ctx.page_has_content = false
            move_to_next_valid_position(ctx, interval, grid_height, indent)
        end
        return true
    end
    return false
end

_internal.handle_penalty_breaks = handle_penalty_breaks

-- @param page_columns (number) Total columns before a page break
-- @param params (table) Optional parameters:
--   - distribute (boolean) If true, distribute nodes evenly in columns
-- @return (table, number, table, table) layout_map, total_pages, page_chapter_titles, banxin_registry
local function calculate_grid_positions(head, grid_height, line_limit, n_column, page_columns, params)
    local d_head = D.todirect(head)
    params = params or {}
    local distribute = params.distribute

    if line_limit < 1 then line_limit = 20 end

    local interval = tonumber(n_column) or 0
    local p_cols = tonumber(page_columns) or (2 * interval + 1)
    if p_cols <= 0 then p_cols = 10000 end -- Safety

    -- Debug: Log floating textbox parameters
    if params.floating then
        dbg.log(string.format("Floating textbox detected: floating_x=%.1fpt, paper_width=%.1fpt",
            (params.floating_x or 0) / 65536, (params.paper_width or 0) / 65536))
    end

    -- Stateful cursor layout
    local ctx = create_grid_context(params, line_limit, p_cols)
    ctx.banxin_registry = {} -- Track Banxin columns per page
    local layout_map = {}

    -- Buffer for distribution mode
    local col_buffer = {}

    -- Initial skip
    move_to_next_valid_position(ctx, interval, grid_height, 0)

    -- Block tracking for First Indent
    local block_start_cols = {} -- map[block_id] -> {page=p, col=c}

    local function get_indent_for_current_pos(block_id, base_indent, first_indent)
        if block_id and block_id > 0 and first_indent >= 0 then
            if not block_start_cols[block_id] then
                block_start_cols[block_id] = { page = ctx.cur_page, col = ctx.cur_col }
            end
            local start_info = block_start_cols[block_id]
            if ctx.cur_page == start_info.page and ctx.cur_col == start_info.col then
                return first_indent
            end
        end
        return base_indent
    end

    local function flush_buffer()
        if #col_buffer == 0 then return end

        local N = #col_buffer
        local H = line_limit -- Default to integer grid cells

        -- If absolute height is provided and we are in distribution mode,
        -- use the actual dimension to calculate distribution.
        if distribute and ctx.params.absolute_height and ctx.params.absolute_height > 0 then
            H = ctx.params.absolute_height / grid_height
        end

        local v_scale_all = 1.0
        local distribute_rows = {}

        if distribute and N > 1 then
            local total_char_height = 0
            for _, entry in ipairs(col_buffer) do
                local ch = entry.height or grid_height
                if ch <= 0 then ch = grid_height end
                total_char_height = total_char_height + ch
            end

            local H_sp = H * grid_height
            if total_char_height > H_sp then
                -- Squeeze mode
                v_scale_all = H_sp / total_char_height
                local current_y = 0
                for i = 1, N do
                    local entry = col_buffer[i]
                    local ch = (entry.height or grid_height)
                    if ch <= 0 then ch = grid_height end
                    ch = ch * v_scale_all
                    local y_center = current_y + ch / 2
                    distribute_rows[i] = y_center / grid_height - 0.5
                    current_y = current_y + ch
                end
            else
                -- Distribute mode (No enlargement)
                v_scale_all = 1.0
                local gap = (H_sp - total_char_height) / (N - 1)
                local current_y = 0
                for i = 1, N do
                    local entry = col_buffer[i]
                    local ch = (entry.height or grid_height)
                    if ch <= 0 then ch = grid_height end
                    local y_center = current_y + ch / 2
                    distribute_rows[i] = y_center / grid_height - 0.5
                    current_y = current_y + ch + gap
                end
            end
        end

        -- Natural mode: recalculate positions with tight packing
        -- Only stretch when remaining space < min_cell_height (nearly full column)
        if ctx.layout_mode == "natural" and N > 0 and not distribute then
            local total_cells = 0
            local min_cell = math.huge
            for _, e in ipairs(col_buffer) do
                local ch = e.cell_height or grid_height
                total_cells = total_cells + ch
                if ch < min_cell then min_cell = ch end
            end
            local remaining = ctx.col_height_sp - total_cells

            if N == 1 then
                col_buffer[1].relative_row = 0
            elseif remaining > 0 and remaining < min_cell and N > 1 then
                -- Nearly full: distribute remaining space for bottom alignment
                local gap = remaining / (N - 1)
                local y = 0
                for _, e in ipairs(col_buffer) do
                    e.relative_row = y / grid_height
                    y = y + (e.cell_height or grid_height) + gap
                end
            else
                -- Normal: tight packing, no stretching
                local y = 0
                for _, e in ipairs(col_buffer) do
                    e.relative_row = y / grid_height
                    y = y + (e.cell_height or grid_height)
                end
            end
        end

        for i, entry in ipairs(col_buffer) do
            local row = distribute_rows[i] or entry.relative_row
            local v_scale = (distribute and N > 1) and v_scale_all or 1.0

            -- Get style attributes from node's style registry attribute (Phase 2: Style Registry)
            local font_color = get_node_font_color(entry.node)
            local font_size = get_node_font_size(entry.node)
            local font = get_node_font(entry.node)

            local map_entry = {
                page = entry.page,
                col = entry.col,
                row = row,
                is_block = entry.is_block,
                width = entry.width,
                height = entry.height,
                v_scale = v_scale,
                cell_height = entry.cell_height,
            }
            -- Only add optional style fields if they are set
            if font_color then
                map_entry.font_color = font_color
            end
            if font_size then
                map_entry.font_size = font_size
            end
            if font then
                map_entry.font = font
            end

            -- Check for line mark attribute (专名号/书名号)
            local lm_id = D.get_attribute(entry.node, constants.ATTR_LINE_MARK_ID)
            if lm_id and lm_id > 0 then
                map_entry.line_mark_id = lm_id
            end

            layout_map[entry.node] = map_entry
        end
        -- Clear buffer in-place to preserve reference for external hooks (kinsoku)
        for i = #col_buffer, 1, -1 do
            col_buffer[i] = nil
        end
    end

    local t = d_head
    move_to_next_valid_position(ctx, interval, grid_height, 0)

    local node_count = 0
    while t do
        -- Check for dynamic chapter title marker via attribute
        local reg_id = D.get_attribute(t, constants.ATTR_CHAPTER_REG_ID)
        if reg_id and reg_id > 0 then
            local new_title = _G.chapter_registry and _G.chapter_registry[reg_id]
            if new_title then
                ctx.chapter_title = new_title
                ctx.page_chapter_titles[ctx.cur_page] = new_title
            end
        end

        ::start_of_loop::
        local id = D.getid(t)

        if id == constants.WHATSIT then
            -- Position transparently at current cursor
            local map_entry = {
                page = ctx.cur_page,
                col = ctx.cur_col,
                row = ctx.cur_row
            }

            local font_color = get_node_font_color(t)
            local font_size = get_node_font_size(t)
            local font = get_node_font(t)
            if font_color then
                map_entry.font_color = font_color
            end
            if font_size then
                map_entry.font_size = font_size
            end
            if font then
                map_entry.font = font
            end

            layout_map[t] = map_entry
            t = D.getnext(t)
            if not t then break end
            goto start_of_loop
        end

        if node_count < 200 then
            dbg.log(string.format("  Node=%s ID=%d [p:%d, c:%d, r:%d]", tostring(t), id, ctx.cur_page,
                ctx.cur_col, ctx.cur_row))
        end
        node_count = node_count + 1

        -- Advanced Indentation Logic
        --[[
        ===================================================================
        Indent Resolution Logic (Refactored 2026-02-06)
        ===================================================================

        Three-tier priority system for determining indent:

        1. FORCED INDENT (highest priority)
           - Encoded as negative values < INDENT_FORCE_BASE (-1000)
           - Special case: INDENT_FORCE_ZERO (-2) forces indent to 0
           - General case: (INDENT_FORCE_BASE - value) forces indent to value
           - Used by: \SetIndent, \平抬, TextBox (to prevent inheriting)
           - Bypasses all other mechanisms including style stack

        2. EXPLICIT INDENT (medium priority)
           - Positive attribute values (> 0)
           - Set directly by Paragraph environment or user code
           - Does NOT bypass style stack (0 means "check stack")

        3. STYLE STACK INHERITANCE (lowest priority)
           - When attribute is 0 or nil and not forced
           - Inherits from parent style (Paragraph, TextFlow, etc.)
           - Allows nested contexts to share indent settings

        Examples:
        - \begin{段落}[indent=2] → sets base to 2 (explicit)
        - \SetIndent{1} → forces to 1 (forced, bypasses stack)
        - \SetIndent{0} → forces to 0 (forced, not inherited!)
        - \夹注{...} → inherits from outer Paragraph (stack)
        ===================================================================
        ]]--

        local block_id = D.get_attribute(t, constants.ATTR_BLOCK_ID)
        local node_indent = D.get_attribute(t, constants.ATTR_INDENT)
        local node_first_indent = D.get_attribute(t, constants.ATTR_FIRST_INDENT)

        -- Decode forced indent values (handles both -2 and < -1000)
        local indent_is_forced, forced_indent_value = constants.is_forced_indent(node_indent)
        local first_indent_is_forced, forced_first_indent_value = constants.is_forced_indent(node_first_indent)

        -- Start with forced value (if forced) or explicit attribute (if set) or 0
        local base_indent = indent_is_forced and forced_indent_value or (node_indent or 0)
        local first_indent = first_indent_is_forced and forced_first_indent_value or (node_first_indent or -1)

        -- If not forced and no explicit value, inherit from style stack
        if not indent_is_forced and (node_indent == nil or node_indent == 0) then
            local style_id = D.get_attribute(t, constants.ATTR_STYLE_REG_ID)
            if style_id then
                local stack_indent = style_registry.get_indent(style_id)
                if stack_indent and stack_indent > 0 then
                    base_indent = stack_indent
                end
            end
        end

        -- Same logic for first_indent
        if not first_indent_is_forced and (node_first_indent == nil or node_first_indent == -1) then
            local style_id = D.get_attribute(t, constants.ATTR_STYLE_REG_ID)
            if style_id then
                local stack_first_indent = style_registry.get_first_indent(style_id)
                if stack_first_indent and stack_first_indent ~= -1 then
                    first_indent = stack_first_indent
                end
            end
        end

        local current_indent = get_indent_for_current_pos(block_id, base_indent, first_indent)

        local indent = current_indent
        local r_indent = D.get_attribute(t, constants.ATTR_RIGHT_INDENT) or 0

        -- Textbox attributes; ONLY treat HLIST/VLIST as blocks
        -- 这些属性由 textbox.lua 在 verticalize_inner_box 阶段设置
        local tb_w = 0
        local tb_h = 0
        if id == constants.HLIST or id == constants.VLIST then
            tb_w = D.get_attribute(t, constants.ATTR_TEXTBOX_WIDTH) or 0
            tb_h = D.get_attribute(t, constants.ATTR_TEXTBOX_HEIGHT) or 0
        end

        -- Indent logic applying to current position
        -- Only apply column-level indent tracking when this node has indent > 0
        -- This prevents indent from "leaking" to non-indented content in the same column

        local effective_limit = line_limit - r_indent
        if effective_limit < indent + 1 then effective_limit = indent + 1 end

        -- Check wrapping BEFORE placing
        -- In distribution mode, we allow overflow so we can squeeze characters later
        if ctx.cur_row >= effective_limit and not distribute then
            flush_buffer()
            wrap_to_next_column(ctx, p_cols, interval, grid_height, indent, true, false)
        end

        apply_indentation(ctx, indent)

        -- Check for Column (单列排版) first
        local is_column = D.get_attribute(t, constants.ATTR_COLUMN) == 1
        if is_column then
            local column_mod = package.loaded['core.luatex-cn-core-column'] or
                require('core.luatex-cn-core-column')

            -- Get align mode to check for LastColumn (align >= 4)
            local align_mode = D.get_attribute(t, constants.ATTR_COLUMN_ALIGN) or 0
            local is_last_column = align_mode >= 4

            -- Column always starts on a new column
            flush_buffer()
            if ctx.cur_row > 0 then
                wrap_to_next_column(ctx, p_cols, interval, grid_height, 0, true, false)
            end

            -- For LastColumn, jump to the last column of current half-page
            if is_last_column then
                -- Calculate last column before banxin (or page end)
                local last_col = column_mod.find_last_column_in_half_page(
                    ctx.cur_col, p_cols, interval, get_banxin_on(params))
                if last_col > ctx.cur_col then
                    ctx.cur_col = last_col
                    ctx.cur_row = 0
                end
            end

            local column_params = {
                line_limit = line_limit,
                grid_height = grid_height,
                p_cols = p_cols,
                interval = interval
            }
            local column_callbacks = {
                flush = flush_buffer,
                wrap = function()
                    wrap_to_next_column(ctx, p_cols, interval, grid_height, 0, true, false)
                end,
                debug = function(msg) dbg.log(msg) end
            }

            t = column_mod.place_nodes(ctx, t, layout_map, column_params, column_callbacks)

            if not t then break end
            goto start_of_loop
        end

        local is_textflow = D.get_attribute(t, constants.ATTR_JIAZHU) == 1
        if is_textflow then
            local textflow = package.loaded['core.luatex-cn-core-textflow'] or
                require('core.luatex-cn-core-textflow')

            local textflow_mode = D.get_attribute(t, constants.ATTR_JIAZHU_MODE) or 0
            local place_params = {
                effective_limit = effective_limit,
                line_limit = line_limit,
                base_indent = base_indent,
                r_indent = r_indent,
                block_id = block_id,
                first_indent = first_indent,
                textflow_mode = textflow_mode
            }
            local callbacks = {
                flush = flush_buffer,
                wrap = function()
                    wrap_to_next_column(ctx, p_cols, interval, grid_height, indent, false, false)
                end,
                get_indent = get_indent_for_current_pos,
                debug = function(msg) dbg.log(msg) end
            }

            t = textflow.place_nodes(ctx, t, layout_map, place_params, callbacks)

            if not t then break end
            goto start_of_loop
        end

        if tb_w > 0 and tb_h > 0 then
            -- Handle Textbox Block
            local textbox = package.loaded['core.luatex-cn-core-textbox'] or
                require('core.luatex-cn-core-textbox')

            local tb_params = {
                effective_limit = effective_limit,
                p_cols = p_cols,
                indent = 0 -- Textbox should not inherit paragraph indent
            }
            local tb_callbacks = {
                flush = flush_buffer,
                wrap = function(ri, rc)
                    wrap_to_next_column(ctx, p_cols, interval, grid_height, indent, ri, rc)
                end,
                is_reserved = function(c)
                    return is_reserved_col(c, interval, ctx.params.banxin_on)
                end,
                mark_occupied = mark_occupied,
                push_buffer = function(e) table.insert(col_buffer, e) end,
                move_next = function()
                    move_to_next_valid_position(ctx, interval, grid_height, indent)
                end
            }

            textbox.place_textbox_node(ctx, t, tb_w, tb_h, tb_params, tb_callbacks)
        elseif id == constants.GLYPH then
            -- Flush pending textflow state before processing regular glyph
            -- This ensures "后续文字" continues after textflow, not from start
            if ctx.textflow_pending_sub_col and ctx.textflow_pending_row_used then
                ctx.cur_row = ctx.cur_row + ctx.textflow_pending_row_used
                ctx.textflow_pending_sub_col = nil
                ctx.textflow_pending_row_used = nil
            end
            local dec_id = D.get_attribute(t, constants.ATTR_DECORATE_ID)
            if dec_id and dec_id > 0 then
                -- Decorate Marker: position for the PREVIOUS character
                -- ISSUE #54 FIX: When column just wrapped (just_wrapped_column flag),
                -- use the previous character's position (last column's last row)
                local dec_page = ctx.cur_page
                local dec_col = ctx.cur_col
                local dec_row = ctx.cur_row

                if ctx.just_wrapped_column and ctx.last_char_row then
                    -- Column just wrapped - use previous character's position
                    dec_page = ctx.last_char_page or ctx.cur_page
                    dec_col = ctx.last_char_col or ctx.cur_col
                    dec_row = ctx.last_char_row + 1 -- +1 because render subtracts 1
                end

                local map_entry = {
                    page = dec_page,
                    col = dec_col,
                    row = dec_row
                }

                local font_color = get_node_font_color(t)
                local font_size = get_node_font_size(t)
                local font = get_node_font(t)
                if font_color then
                    map_entry.font_color = font_color
                end
                if font_size then
                    map_entry.font_size = font_size
                end
                if font then
                    map_entry.font = font
                end

                layout_map[t] = map_entry
                -- DO NOT increment cur_row - marker is zero-width overlay
            else
                -- Detect line change and clear temporary indents
                if ctx.cur_row ~= ctx.last_glyph_row then
                    style_registry.pop_temporary()
                    ctx.last_glyph_row = ctx.cur_row
                end

                -- Track last character position for decoration markers
                ctx.last_char_page = ctx.cur_page
                ctx.last_char_col = ctx.cur_col
                ctx.last_char_row = ctx.cur_row
                -- Clear wrapped flag - we've processed a regular character
                ctx.just_wrapped_column = false

                if ctx.layout_mode == "natural" then
                    local cell_h = get_cell_height(t, grid_height)
                    -- Column overflow check
                    if ctx.cur_y_sp + cell_h > ctx.col_height_sp and ctx.cur_y_sp > 0 then
                        flush_buffer()
                        wrap_to_next_column(ctx, p_cols, interval, grid_height, indent, false, false)
                    end
                    table.insert(col_buffer, {
                        node = t,
                        page = ctx.cur_page,
                        col = ctx.cur_col,
                        relative_row = ctx.cur_y_sp / grid_height,
                        height = (D.getfield(t, "height") or 0) + (D.getfield(t, "depth") or 0),
                        cell_height = cell_h,
                    })
                    ctx.cur_y_sp = ctx.cur_y_sp + cell_h + ctx.inter_cell_gap
                    ctx.cur_row = math.floor(ctx.cur_y_sp / grid_height + 0.5)
                    ctx.page_has_content = true
                else
                    table.insert(col_buffer, {
                        node = t,
                        page = ctx.cur_page,
                        col = ctx.cur_col,
                        relative_row = ctx.cur_row,
                        height = (D.getfield(t, "height") or 0) + (D.getfield(t, "depth") or 0)
                    })
                    ctx.cur_row = ctx.cur_row + 1
                    ctx.page_has_content = true

                    -- Kinsoku (line-breaking rules) hook:
                    -- When column is about to wrap, check if we need to adjust
                    -- to prevent forbidden characters at column start/end
                    if not distribute and params and params.hooks
                        and params.hooks.check_kinsoku then
                        params.hooks.check_kinsoku(
                            t, ctx, effective_limit, col_buffer,
                            flush_buffer, wrap_to_next_column,
                            p_cols, interval, grid_height, indent)
                    end

                    move_to_next_valid_position(ctx, interval, grid_height, indent)
                end
            end
        elseif id == constants.GLUE or id == constants.KERN then
            -- Accumulate consecutive spacing nodes
            local net_width, lookahead = accumulate_spacing(t)

            if ctx.layout_mode == "natural" then
                -- Natural mode: accumulate sp directly, no quantization
                if net_width > 0 and ctx.cur_y_sp > 0 then
                    ctx.cur_y_sp = ctx.cur_y_sp + net_width
                    if ctx.cur_y_sp > ctx.col_height_sp then
                        flush_buffer()
                        wrap_to_next_column(ctx, p_cols, interval, grid_height, indent, false, false)
                    end
                end
            else
                local threshold = (grid_height or 655360) * 0.25
                if net_width > threshold then
                    local num_cells = math.floor(net_width / (grid_height or 655360) + 0.5)
                    if num_cells < 1 then num_cells = 1 end

                    if ctx.cur_row > ctx.cur_column_indent then
                        dbg.log(string.format("  SPACING: val=%.2fpt, grid_h=%.2fpt, num_cells=%d",
                            net_width / 65536, (grid_height or 0) / 65536, num_cells))

                        for i = 1, num_cells do
                            ctx.cur_row = ctx.cur_row + 1
                            if ctx.cur_row >= effective_limit then
                                flush_buffer()
                                wrap_to_next_column(ctx, p_cols, interval, grid_height, indent, false, false)
                            else
                                move_to_next_valid_position(ctx, interval, grid_height, indent)
                            end
                        end
                    end
                end
            end

            t = lookahead
            if not t then break end
            goto start_of_loop
        elseif id == constants.PENALTY then
            local p_val = D.getfield(t, "penalty")
            -- Smart column break: Check next node type before deciding
            if p_val == constants.PENALTY_SMART_BREAK then
                local next_node = D.getnext(t)
                if next_node then
                    local next_is_textflow = D.get_attribute(next_node, constants.ATTR_JIAZHU) == 1
                    if not next_is_textflow then
                        -- Flush pending textflow state before checking cur_row
                        -- (auto-balance=false textflow may have rows_used=0, leaving cur_row un-advanced)
                        if ctx.textflow_pending_sub_col and ctx.textflow_pending_row_used then
                            ctx.cur_row = ctx.cur_row + ctx.textflow_pending_row_used
                            ctx.textflow_pending_sub_col = nil
                            ctx.textflow_pending_row_used = nil
                        end
                        -- Next node is regular text, break to new column
                        flush_buffer()
                        if ctx.cur_row > ctx.cur_column_indent then
                            wrap_to_next_column(ctx, p_cols, interval, grid_height, indent, false, true)
                        end
                        ctx.cur_column_indent = 0
                    end
                    -- If next is textflow, don't break - let textflow continue naturally
                end
            else
                handle_penalty_breaks(p_val, ctx, flush_buffer, p_cols, interval, grid_height, indent, t)
            end
        end

        t = D.getnext(t)
        ::continue::
    end

    flush_buffer()

    local total_pages = ctx.cur_page + 1

    local map_count = 0
    for _ in pairs(layout_map) do map_count = map_count + 1 end
    dbg.log(string.format("Layout map built. Total entries: %d, Total pages: %d", map_count,
        ctx.cur_page + 1))

    return layout_map, ctx.cur_page + 1, ctx.page_chapter_titles, ctx.banxin_registry
end

-- Create module table
local layout = {
    calculate_grid_positions = calculate_grid_positions,
}

-- Register module in package.loaded for require() compatibility
-- 注册模块到 package.loaded
package.loaded['core.luatex-cn-layout-grid'] = layout

-- Return module exports
return layout
