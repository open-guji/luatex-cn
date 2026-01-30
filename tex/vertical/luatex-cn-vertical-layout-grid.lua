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
local constants = package.loaded['vertical.luatex-cn-vertical-base-constants'] or
    require('vertical.luatex-cn-vertical-base-constants')
local D = constants.D
local utils = package.loaded['vertical.luatex-cn-vertical-base-utils'] or
    require('vertical.luatex-cn-vertical-base-utils')
local hooks = package.loaded['vertical.luatex-cn-vertical-base-hooks'] or
    require('vertical.luatex-cn-vertical-base-hooks')

local _internal = {}

local function is_reserved_col(col, interval, banxin_on)
    if not banxin_on then return false end
    if interval <= 0 then return false end
    return _G.vertical.hooks.is_reserved_column(col, interval)
end

local function is_center_gap_col(col, params, grid_height)
    if not params.banxin_on then return false end
    -- Use provided params if available
    local g_width = params.grid_width or grid_height or (65536 * 20)

    local paper_w = params.floating_paper_width or params.paper_width or 0
    if paper_w <= 0 and _G.vertical and _G.vertical.main_paper_width then
        paper_w = _G.vertical.main_paper_width
    end
    if paper_w <= 0 then return false end

    local center = paper_w / 2
    local gap_half_width = 15 * 65536 -- 15pt in sp

    local floating_x = params.floating_x or 0
    if not params.floating then
        -- actually, main text col 0 is anchored to margin_right.
        -- So floating_x for main text's right origin is margin_right.
        if type(params.margin_right) == "number" then
            floating_x = params.margin_right
        else
            floating_x = constants.to_dimen(params.margin_right) or 0
        end
    end

    local col_right_x = floating_x + col * g_width
    local col_left_x = col_right_x + g_width

    local gap_left = center - gap_half_width
    local gap_right = center + gap_half_width

    local overlaps = (col_right_x < gap_right) and (col_left_x > gap_left)

    if overlaps then
        utils.debug_log(string.format("[layout] Skipping center gap column %d", col))
    end


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
        chapter_title = params.chapter_title or "",
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
    while changed do
        changed = false
        -- Skip Banxin and register it
        while is_reserved_col(ctx.cur_col, interval, ctx.params.banxin_on) do
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
        utils.debug_log(string.format("[layout] Floating textbox detected: floating_x=%.1fpt, paper_width=%.1fpt",
            (params.floating_x or 0) / 65536, (params.paper_width or 0) / 65536))
    end

    -- Stateful cursor layout
    local ctx = create_grid_context(params, line_limit, p_cols)
    ctx.banxin_registry = {} -- Track Banxin columns per page
    local layout_map = {}

    -- Buffer for distribution mode
    local col_buffer = {}

    -- Initial skip
    move_to_next_valid_position(ctx, interval, grid_height, indent)

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
    move_to_next_valid_position(ctx, interval, grid_height, indent)

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

        if node_count < 200 and utils and utils.debug_log then
            utils.debug_log(string.format("  [layout] Node=%s ID=%d [p:%d, c:%d, r:%d]", tostring(t), id, ctx.cur_page,
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
            ctx.cur_col = ctx.cur_col + 1
            ctx.cur_row = 0
            if ctx.cur_col >= p_cols then
                ctx.cur_col = 0
                ctx.cur_page = ctx.cur_page + 1
            end

            -- CRITICAL: Reset column indent when wrapping to new column
            ctx.cur_column_indent = 0
            move_to_next_valid_position(ctx, interval, grid_height, indent)
        end

        apply_indentation(ctx, indent)

        local is_jiazhu = D.get_attribute(t, constants.ATTR_JIAZHU) == 1
        if is_jiazhu then
            if utils and utils.debug_log then
                utils.debug_log(string.format("  [layout] JIAZHU DETECTED: node=%s", tostring(t)))
            end
            flush_buffer()
            -- Collect Jiazhu sequence
            local j_nodes = {}
            local temp_t = t
            while temp_t and D.get_attribute(temp_t, constants.ATTR_JIAZHU) == 1 do
                local tid = D.getid(temp_t)
                if tid == constants.GLYPH then
                    table.insert(j_nodes, temp_t)
                end
                temp_t = D.getnext(temp_t)
            end
            if utils and utils.debug_log then
                utils.debug_log(string.format("  [layout] Collected %d jiazhu glyphs", #j_nodes))
            end

            -- Ensure we have at least 2 rows available before starting a Jiazhu sequence
            -- This prevents "orphan" Jiazhu rows starting at the very bottom of a column.
            if effective_limit - ctx.cur_row < 2 then
                flush_buffer()
                ctx.cur_col = ctx.cur_col + 1
                ctx.cur_row = 0
                if ctx.cur_col >= p_cols then
                    ctx.cur_col = 0
                    ctx.cur_page = ctx.cur_page + 1
                end
                move_to_next_valid_position(ctx, interval, grid_height, indent)
            end

            -- Process via core_textflow
            -- Note: subsequent chunks must also account for indentation in their columns
            local textflow = package.loaded['vertical.luatex-cn-vertical-core-textflow'] or
                require('vertical.luatex-cn-vertical-core-textflow')
            local available_in_first = effective_limit - ctx.cur_row
            local capacity_per_subsequent = line_limit - base_indent - r_indent -- Use base_indent for subsequent columns

            local jiazhu_mode = D.get_attribute(t, constants.ATTR_JIAZHU_MODE) or 0

            local chunks = textflow.process_jiazhu_sequence(j_nodes, available_in_first, capacity_per_subsequent,
                jiazhu_mode)

            for i, chunk in ipairs(chunks) do
                -- If not the first chunk, move to next column
                if i > 1 then
                    ctx.cur_col = ctx.cur_col + 1
                    ctx.cur_row = 0
                    if ctx.cur_col >= p_cols then
                        ctx.cur_col = 0
                        ctx.cur_page = ctx.cur_page + 1
                    end
                    move_to_next_valid_position(ctx, interval, grid_height, indent)

                    -- Recalculate indentation and row start for new column
                    local chunk_indent = get_indent_for_current_pos(block_id, base_indent, first_indent)
                    if ctx.cur_row < chunk_indent then ctx.cur_row = chunk_indent end
                end

                -- Record positions
                for _, node_info in ipairs(chunk.nodes) do
                    layout_map[node_info.node] = {
                        page = ctx.cur_page,
                        col = ctx.cur_col,
                        row = ctx.cur_row + node_info.relative_row,
                        sub_col = node_info.sub_col
                    }
                end

                ctx.cur_row = ctx.cur_row + chunk.rows_used
            end

            t = temp_t
            if not t then break end
            goto start_of_loop
        end

        if tb_w > 0 and tb_h > 0 then
            -- Handle Textbox Block
            if ctx.cur_row + tb_h > effective_limit then
                flush_buffer()
                ctx.cur_col = ctx.cur_col + 1
                ctx.cur_row = indent
                if ctx.cur_col >= p_cols then
                    ctx.cur_col = 0
                    ctx.cur_page = ctx.cur_page + 1
                end
                move_to_next_valid_position(ctx, interval, grid_height, indent)
            end

            local fits_width = true
            for c = ctx.cur_col, ctx.cur_col + tb_w - 1 do
                if is_reserved_col(c, interval, ctx.params.banxin_on) or (c >= p_cols) then
                    fits_width = false
                    break
                end
            end

            if not fits_width then
                flush_buffer()
                ctx.cur_col = ctx.cur_col + 1
                ctx.cur_row = 0
                if ctx.cur_col >= p_cols then
                    ctx.cur_col = 0
                    ctx.cur_page = ctx.cur_page + 1
                end
                move_to_next_valid_position(ctx, interval, grid_height, indent)
            end

            for c = ctx.cur_col, ctx.cur_col + tb_w - 1 do
                for r = ctx.cur_row, ctx.cur_row + tb_h - 1 do
                    mark_occupied(ctx.occupancy, ctx.cur_page, c, r)
                end
            end

            table.insert(col_buffer,
                {
                    node = t,
                    page = ctx.cur_page,
                    col = ctx.cur_col,
                    relative_row = ctx.cur_row,
                    is_block = true,
                    width = tb_w,
                    height =
                        tb_h
                })
            ctx.cur_row = ctx.cur_row + tb_h
            move_to_next_valid_position(ctx, interval, grid_height, indent)
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
            local net_width = 0
            local lookahead = t

            while lookahead do
                local lid = D.getid(lookahead)
                if lid == constants.GLUE then
                    net_width = net_width + (D.getfield(lookahead, "width") or 0)
                elseif lid == constants.KERN then
                    net_width = net_width + (D.getfield(lookahead, "kern") or 0)
                elseif lid == constants.PENALTY then
                    if D.getfield(lookahead, "penalty") <= -10000 then break end
                elseif lid == constants.WHATSIT or lid == constants.MARK then
                    -- Skip
                else
                    break
                end
                lookahead = D.getnext(lookahead)
            end

            local threshold = (grid_height or 655360) * 0.25
            if net_width > threshold then
                local num_cells = math.floor(net_width / (grid_height or 655360) + 0.5)
                if num_cells < 1 then num_cells = 1 end

                if ctx.cur_row > ctx.cur_column_indent then
                    utils.debug_log(string.format("  [layout] SPACING: val=%.2fpt, grid_h=%.2fpt, num_cells=%d",
                        net_width / 65536, (grid_height or 0) / 65536, num_cells))

                    for i = 1, num_cells do
                        ctx.cur_row = ctx.cur_row + 1
                        if ctx.cur_row >= effective_limit then
                            flush_buffer()
                            ctx.cur_col = ctx.cur_col + 1
                            ctx.cur_row = 0
                            if ctx.cur_col >= p_cols then
                                ctx.cur_col = 0
                                ctx.cur_page = ctx.cur_page + 1
                            end
                        end
                        move_to_next_valid_position(ctx, interval, grid_height, indent)
                    end
                else
                    if utils and utils.debug_log then
                        utils.debug_log(string.format("  [layout] SPACING: val=%.2fpt IGNORED (at top or within indent)",
                            net_width / 65536))
                    end
                end
            end

            t = lookahead
            if not t then break end
            goto start_of_loop
        elseif id == constants.PENALTY then
            local p_val = D.getfield(t, "penalty")
            -- Internal Flatten logic uses -10002 for forced column break (paragraph end)
            if p_val == -10002 then
                flush_buffer()
                -- Column break only happens if there's content in current column
                if ctx.cur_row > ctx.cur_column_indent then
                    ctx.cur_col = ctx.cur_col + 1
                    ctx.cur_row = 0
                    if ctx.cur_col >= p_cols then
                        ctx.cur_col = 0
                        ctx.cur_page = ctx.cur_page + 1
                        ctx.page_has_content = false
                    end
                    move_to_next_valid_position(ctx, interval, grid_height, indent)
                end
                -- Always reset indent when paragraph ends, regardless of column break
                ctx.cur_column_indent = 0
            elseif p_val == -10003 then
                -- Our internal forced page break (set by redefined \newpage and \clearpage)
                if ctx.page_has_content then
                    flush_buffer()
                    -- Force Page Break
                    ctx.cur_page = ctx.cur_page + 1
                    ctx.cur_col = 0
                    ctx.cur_row = 0
                    ctx.cur_column_indent = 0
                    ctx.page_has_content = false
                    move_to_next_valid_position(ctx, interval, grid_height, indent)
                end
            end
        end

        t = D.getnext(t)
        ::continue::
    end

    flush_buffer()

    local total_pages = ctx.cur_page + 1

    if utils and utils.debug_log then
        local map_count = 0
        for _ in pairs(layout_map) do map_count = map_count + 1 end
        utils.debug_log(string.format("[layout] Layout map built. Total entries: %d, Total pages: %d", map_count,
            ctx.cur_page + 1))
    end

    return layout_map, ctx.cur_page + 1, ctx.page_chapter_titles, ctx.banxin_registry
end

-- Create module table
local layout = {
    calculate_grid_positions = calculate_grid_positions,
}

-- Register module in package.loaded for require() compatibility
-- 注册模块到 package.loaded
package.loaded['vertical.luatex-cn-vertical-layout-grid'] = layout

-- Return module exports
return layout
