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
    if not (params and params.floating) then
        -- actually, main text col 0 is anchored to margin_right.
        -- So floating_x for main text's right origin is margin_right.
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

local function create_grid_context(params, line_limit, p_cols)
    -- Use helper for chapter_title with fallback to _G.metadata
    local initial_chapter = get_chapter_title(params)
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
        -- Can add other state if needed
    }
    ctx.page_chapter_titles[0] = ctx.chapter_title -- Initialize page 0 with the initial chapter title
    return ctx
end


local function apply_indentation(ctx, indent)
    if not indent or indent <= 0 then return end
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
    ctx.cur_col = ctx.cur_col + 1
    ctx.cur_row = 0
    if ctx.cur_col >= p_cols then
        ctx.cur_col = 0
        ctx.cur_page = ctx.cur_page + 1
        if reset_content then
            ctx.page_has_content = false
        end
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
local function handle_penalty_breaks(p_val, ctx, flush_buffer_fn, p_cols, interval, grid_height, indent)
    if p_val == -10002 then
        -- Forced column break (paragraph end)
        flush_buffer_fn()
        if ctx.cur_row > ctx.cur_column_indent then
            wrap_to_next_column(ctx, p_cols, interval, grid_height, indent, false, true)
        end
        ctx.cur_column_indent = 0
        return true
    elseif p_val == -10003 then
        -- Forced page break
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

        for i, entry in ipairs(col_buffer) do
            local row = distribute_rows[i] or entry.relative_row
            local v_scale = (distribute and N > 1) and v_scale_all or 1.0

            layout_map[entry.node] = {
                page = entry.page,
                col = entry.col,
                row = row,
                is_block = entry.is_block,
                width = entry.width,
                height = entry.height,
                v_scale = v_scale
            }
        end
        col_buffer = {}
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

        -- Logging for diagnostic
        -- print(string.format("[D-layout-trace] Node=%s ID=%d [WHATSIT_REF=%d]", tostring(t), id, constants.WHATSIT or -1))
        if id == constants.WHATSIT then
            -- Position transparently at current cursor
            layout_map[t] = {
                page = ctx.cur_page,
                col = ctx.cur_col,
                row = ctx.cur_row
            }
            -- print(string.format("[D-layout] WHATSIT Node=%s [p:%d, c:%d, r:%d]", tostring(t), ctx.cur_page, ctx.cur_col, ctx.cur_row))
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
        local block_id = D.get_attribute(t, constants.ATTR_BLOCK_ID)
        local base_indent = D.get_attribute(t, constants.ATTR_INDENT) or 0
        local first_indent = D.get_attribute(t, constants.ATTR_FIRST_INDENT) or -1

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

        local is_jiazhu = D.get_attribute(t, constants.ATTR_JIAZHU) == 1
        if is_jiazhu then
            local textflow = package.loaded['core.luatex-cn-core-textflow'] or
                require('core.luatex-cn-core-textflow')

            local jiazhu_mode = D.get_attribute(t, constants.ATTR_JIAZHU_MODE) or 0
            local place_params = {
                effective_limit = effective_limit,
                line_limit = line_limit,
                base_indent = base_indent,
                r_indent = r_indent,
                block_id = block_id,
                first_indent = first_indent,
                jiazhu_mode = jiazhu_mode
            }
            local callbacks = {
                flush = flush_buffer,
                wrap = function()
                    wrap_to_next_column(ctx, p_cols, interval, grid_height, indent, false, false)
                end,
                get_indent = get_indent_for_current_pos,
                debug = function(msg) dbg.log(msg) end
            }

            t = textflow.place_jiazhu_nodes(ctx, t, layout_map, place_params, callbacks)

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
                indent = indent
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
            local dec_id = D.get_attribute(t, constants.ATTR_DECORATE_ID)
            if dec_id and dec_id > 0 then
                -- Decorate Marker: position directly at current row WITHOUT entering col_buffer
                -- This ensures the marker doesn't affect normal character layout
                layout_map[t] = {
                    page = ctx.cur_page,
                    col = ctx.cur_col,
                    row = ctx.cur_row
                }
                -- DO NOT increment cur_row - marker is zero-width overlay
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
                move_to_next_valid_position(ctx, interval, grid_height, indent)
            end
        elseif id == constants.GLUE or id == constants.KERN then
            -- Accumulate consecutive spacing nodes
            local net_width, lookahead = accumulate_spacing(t)

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
                else
                    -- if debug.is_enabled("layout") then
                    --     debug.log("layout", string.format("  SPACING: val=%.2fpt IGNORED (at top or within indent)",
                    --         net_width / 65536))
                    -- end
                end
            end

            t = lookahead
            if not t then break end
            goto start_of_loop
        elseif id == constants.PENALTY then
            local p_val = D.getfield(t, "penalty")
            handle_penalty_breaks(p_val, ctx, flush_buffer, p_cols, interval, grid_height, indent)
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
