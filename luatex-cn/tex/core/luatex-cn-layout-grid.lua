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
-- layout_grid.lua - 统一布局引擎（第二阶段）
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

-- clreq 共享内核：行内调整求解器与禁则决策（规则只在共享层，后端只组装与落盘）
local adjust = require('shared.luatex-cn-adjust')
local kinsoku = require('shared.luatex-cn-kinsoku')

-- Load helpers (parameter getters, style attributes, column validation, occupancy)
local h = package.loaded['core.luatex-cn-layout-grid-helpers'] or
    require('core.luatex-cn-layout-grid-helpers')

local get_banxin_on = h.get_banxin_on
local get_grid_width = h.get_grid_width
local get_margin_right = h.get_margin_right
local get_chapter_title = h.get_chapter_title
local get_node_font_color = h.get_node_font_color
local get_node_font_size = h.get_node_font_size
local apply_style_attrs = h.apply_style_attrs
local is_reserved_col = h.is_reserved_col
local is_center_gap_col = h.is_center_gap_col
local is_occupied = h.is_occupied
local mark_occupied = h.mark_occupied
local get_cell_height = h.get_cell_height
local resolve_cell_height = h.resolve_cell_height
local resolve_cell_width = h.resolve_cell_width

-- Gap between characters in natural mode = 10% of cell height (0.1em)
local GAP_RATIO = 0.1

-- 脚注标号组内数字的可读性下限（占自身字幅的比例）。低于此值时标号
-- 按需增高，而不是把数字压成无法辨认的横条（【二百五十四】五个数字
-- 挤进声明的两字幅时每个只有 0.35 字幅）。
local MARKER_MIN_SCALE = 0.6

-- 脚注标号在语义上依附于**前面**的内容（它标的是刚读过的那个词），
-- 所以前紧后松：前面几乎不留空，后面留出比正常字距更宽的一点空隙，
-- 让「…三嬗，︻一︼｜自生民以來」读起来是「，︻一︼」成一组。
-- 两侧都用标号自身的字号作基准（标号用脚注字号，比正文小）。
local MARKER_GAP_BEFORE_RATIO = 0.05
local MARKER_GAP_AFTER_RATIO = 0.30

--- 标号组两侧的固定间距（sp）
--- @param base number 标号自身的字幅（sp）
--- @param side string "before"（被标注内容 → 标号）或 "after"（标号 → 后文）
--- @return number
local function marker_gap_sp(base, side)
    local ratio = (side == "after") and MARKER_GAP_AFTER_RATIO
        or MARKER_GAP_BEFORE_RATIO
    return math.floor(base * ratio)
end

-- Export _internal for testing
local _internal = {}
_internal.get_banxin_on = get_banxin_on
_internal.get_grid_width = get_grid_width
_internal.get_margin_right = get_margin_right
_internal.get_chapter_title = get_chapter_title
_internal.is_reserved_col = is_reserved_col
_internal.is_center_gap_col = is_center_gap_col
_internal.marker_gap_sp = marker_gap_sp
_internal.GAP_RATIO = GAP_RATIO

local function create_grid_context(params, line_limit, p_cols)
    -- Use helper for chapter_title (from params only, no _G fallback)
    local initial_chapter = get_chapter_title(params)
    -- Unified layout: grid mode IS natural mode with fixed cell height and zero gap.
    -- Grid mode: default_cell_height = grid_height, default_cell_gap = 0
    -- Natural mode: default_cell_height = nil (font-size-based), default_cell_gap > 0
    local default_cell_height = params.default_cell_height  -- nil = natural mode
    local default_cell_gap = params.default_cell_gap       -- 0 set at layout_params definition
    local col_height_sp = params.col_height_sp             -- text area height (padding deducted)
    -- Full content height for band allocation (no padding deduction)
    local band_alloc_height = params.content_height_sp or col_height_sp
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
        -- Global column-padding (for per-column padding delta calculation)
        c_padding_top = params.c_padding_top or 0,
        c_padding_bottom = params.c_padding_bottom or 0,
        -- P2: page geometry offsets for computing absolute coordinates
        shift_x = params.shift_x or 0,
        shift_y = params.shift_y or 0,
        half_thickness = params.half_thickness or 0,
        -- Flag: whether padding has been applied for the current column
        col_padding_applied = true,
        chapter_title = initial_chapter,
        page_chapter_titles = {}, -- To store chapter title for each page
        page_resets = {}, -- page_resets[page] = true when a \chapter marker resets page number
        last_glyph_row = -1, -- Track last glyph row for detecting line changes
        -- Unified layout: grid = fixed cell_height + zero gap; natural = font-size + configurable gap
        default_cell_height = default_cell_height,
        default_cell_gap = default_cell_gap,
        cur_y_sp = 0,
        col_height_sp = col_height_sp,
        band_alloc_height = band_alloc_height,
        -- Explicit punct config (nil = no squeeze; set at layout_params definition)
        punct_config = params.punct_config,
        -- Free mode tracking
        is_free_mode = false,
        content_width = 0,
        accumulated_width_sp = 0,
        -- Phase 2.3: Column width tracking for Free Mode
        col_widths_sp = {}, -- col_widths_sp[page][col] = width_sp
        col_spacing_top_sp = {}, -- col_spacing_top_sp[page][col] = spacing_sp
        col_spacing_bottom_sp = {}, -- col_spacing_bottom_sp[page][col] = spacing_sp
        -- Auto column wrap: when true (default), columns auto-wrap on overflow.
        -- Set to false to disable auto-wrap (only explicit penalties cause column breaks).
        auto_column_wrap = true,
        -- Band (分栏) mode: divide page into horizontal bands
        n_bands = 1,
        cur_band = 0,
        band_heights_sp = {},     -- band_heights_sp[band_idx] = height_sp
        band_y_offsets_sp = {},   -- band_y_offsets_sp[band_idx] = y_offset_sp
        band_line_limits = {},    -- band_line_limits[band_idx] = max_rows
        band_cols_per_band = p_cols,
        band_mode = "auto",
        band_gap_sp = 0,
    }
    -- Initialize band parameters
    local n_bands = params.n_bands or 1
    if n_bands > 1 then
        local band_gap_sp = params.band_gap_sp or 0
        local total_gap = band_gap_sp * (n_bands - 1)
        -- Band allocation uses full content height (no padding deduction)
        local available_height = band_alloc_height - total_gap
        local band_heights = params.band_heights  -- user-specified per-band heights

        -- Pre-compute default height: unspecified bands share remaining space equally.
        -- The last unspecified band absorbs any sp rounding remainder.
        local specified_total = 0
        local unspecified_count = 0
        local last_unspecified = -1
        for i = 0, n_bands - 1 do
            if band_heights and band_heights[i + 1] then
                specified_total = specified_total + band_heights[i + 1]
            else
                unspecified_count = unspecified_count + 1
                last_unspecified = i
            end
        end
        local default_h = unspecified_count > 0
            and math.floor((available_height - specified_total) / unspecified_count)
            or 0

        local offset = 0
        for i = 0, n_bands - 1 do
            local h
            if band_heights and band_heights[i + 1] then
                h = band_heights[i + 1]
            elseif i == last_unspecified then
                -- Last unspecified band absorbs rounding remainder
                h = band_alloc_height - offset
                if h < 0 then h = 0 end
            else
                h = default_h
            end
            ctx.band_heights_sp[i] = h
            ctx.band_y_offsets_sp[i] = offset
            ctx.band_line_limits[i] = default_cell_height and math.floor(h / default_cell_height)
                or line_limit
            offset = offset + h + band_gap_sp
        end

        ctx.n_bands = n_bands
        ctx.band_cols_per_band = (params.band_columns and params.band_columns > 0)
            and params.band_columns or p_cols
        ctx.band_mode = params.band_mode or "auto"
        ctx.band_gap_sp = band_gap_sp
        -- Free mode (p_cols >= 10000): compute actual column count from content width
        if ctx.band_cols_per_band >= 10000 then
            local grid_w = params.grid_width or params.grid_height
            local cw = params.content_width or 0
            if cw > 0 and grid_w > 0 then
                ctx.band_cols_per_band = math.floor(cw / grid_w)
            end
        end
        -- Set initial line_limit to band 0's limit
        ctx.line_limit = ctx.band_line_limits[0]
        ctx.col_height_sp = ctx.band_heights_sp[0]
    else
        ctx.band_heights_sp[0] = band_alloc_height
        ctx.band_y_offsets_sp[0] = 0
        ctx.band_line_limits[0] = line_limit
    end

    ctx.page_chapter_titles[0] = ctx.chapter_title -- Initialize page 0 with the initial chapter title
    return ctx
end


local function apply_indentation(ctx, indent)
    if not indent or indent == 0 then return end
    local old_row = ctx.cur_row
    if indent < 0 then
        -- 负缩进（抬头）：列起始时设置 cur_row 为负值
        -- 用 cur_column_indent 追踪是否已应用，防止每个字符都重置
        -- （因为 -1+1=0，若用 cur_row<=0 判断会反复触发）
        if (ctx.cur_column_indent or 0) == 0 then
            ctx.cur_row = indent
            ctx.cur_column_indent = indent
        end
    else
        -- 正缩进：保持原有逻辑
        if ctx.cur_row < indent then ctx.cur_row = indent end
        if indent > (ctx.cur_column_indent or 0) then ctx.cur_column_indent = indent end
        if ctx.cur_row < (ctx.cur_column_indent or 0) then ctx.cur_row = ctx.cur_column_indent end
    end
    -- Sync sp accumulator when cur_row changed (unified layout)
    -- In natural mode, each cell occupies (grid_height + gap) where gap = 0.1em (GAP_RATIO).
    -- Grid mode (default_cell_height set): no gap between characters.
    if ctx.cur_row ~= old_row then
        local gh = (ctx.params and ctx.params.grid_height) or 655360
        local cell_gap = ctx.default_cell_height and 0 or math.floor(gh * GAP_RATIO)
        ctx.cur_y_sp = ctx.cur_row * (gh + cell_gap)
    end
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
            if ctx.auto_column_wrap ~= false and ctx.cur_col >= ctx.p_cols then
                ctx.cur_col = 0
                ctx.cur_page = ctx.cur_page + 1
            end
            changed = true
            -- When wrapping column/page, row reset must honor indent
            ctx.cur_row = 0
            ctx.cur_y_sp = 0
            ctx.cur_column_indent = 0
            if indent then apply_indentation(ctx, indent) end
        end
        -- Skip Center Gap
        while is_center_gap_col(ctx.cur_col, ctx.params, grid_height) do
            ctx.cur_col = ctx.cur_col + 1
            if ctx.auto_column_wrap ~= false and ctx.cur_col >= ctx.p_cols then
                ctx.cur_col = 0
                ctx.cur_page = ctx.cur_page + 1
            end
            changed = true
            -- When wrapping column/page, row reset must honor indent
            ctx.cur_row = 0
            ctx.cur_y_sp = 0
            ctx.cur_column_indent = 0
            if indent then apply_indentation(ctx, indent) end
        end
        -- Skip Occupied
        if is_occupied(ctx.occupancy, ctx.cur_page, ctx.cur_band, ctx.cur_col, ctx.cur_row) then
            ctx.cur_row = ctx.cur_row + 1
            ctx.cur_y_sp = ctx.cur_row * grid_height
            if ctx.cur_row >= ctx.line_limit then
                ctx.cur_row = 0
                ctx.cur_y_sp = 0
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

--- Reset per-column/cell transient state.
-- Must be called whenever the cursor moves to a new column, cell, or band
-- to prevent stale state from leaking across boundaries.
-- @param ctx (table) Grid context
local function reset_column_transient_state(ctx)
    ctx.cur_row = 0
    ctx.cur_y_sp = 0
    -- NOTE: cur_column_indent is NOT reset here because wrap_to_next_column
    -- has its own conditional logic (reset_indent / negative-indent check).
    -- Callers that need indent reset should do ctx.cur_column_indent = 0 explicitly.
    ctx.textflow_pending_sub_col = nil
    ctx.textflow_pending_row_used = nil
end

--- Wrap cursor to next column (and page if needed)
-- @param ctx (table) Grid context
--- Apply band format padding at column/band start.
-- Called eagerly when cur_y_sp is reset to 0, so all content types (glyphs,
-- textflow, textbox) benefit from per-band padding without lazy glyph check.
-- @param ctx (table) Grid context
local function apply_band_padding(ctx)
    ctx.col_padding_applied = false
    ctx.col_band_padding_applied = false
    ctx.col_band_padding_value = nil
    if ctx.table_band_formats then
        local bf = ctx.table_band_formats[ctx.cur_band]
        if bf and bf.padding_top then
            local pt = constants.to_dimen(bf.padding_top)
            if pt and pt ~= 0 then
                -- Band padding is an absolute offset from band top, not relative to column_padding
                ctx.cur_y_sp = ctx.cur_y_sp + pt
                ctx.col_band_padding_applied = true
                ctx.col_band_padding_value = pt
            end
        end
    end
end

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
    ctx.just_wrapped_column = true -- Flag for issue #54 fix
    reset_column_transient_state(ctx)
    apply_band_padding(ctx)

    local should_wrap_page = false

    -- In digital mode (auto_column_wrap==false), never auto-wrap pages.
    -- Only explicit \换页 (PENALTY_FORCE_PAGE) triggers page breaks.
    -- Content overflowing beyond p_cols will render outside the border,
    -- making errors visible without cascading to subsequent pages.
    if ctx.auto_column_wrap ~= false then
        if ctx.n_bands > 1 then
            local band_start = ctx.table_start_col or 0
            local cols_in_band = ctx.band_cols_per_band
            if ctx.cur_col >= band_start + cols_in_band then
                if ctx.band_mode == "parallel" then
                    -- Parallel mode (table default): column overflow wraps to
                    -- next page at the same band position, not to the next band.
                    ctx.cur_col = band_start
                    should_wrap_page = true
                else
                    -- Auto mode: columns fill current band, then next band,
                    -- then wrap to next page from band 0.
                    ctx.cur_col = band_start
                    ctx.cur_band = ctx.cur_band + 1
                    if ctx.cur_band >= ctx.n_bands then
                        ctx.cur_band = 0
                        should_wrap_page = true
                    end
                end
                -- Update line_limit and col_height for current band
                ctx.line_limit = ctx.band_line_limits[ctx.cur_band]
                ctx.col_height_sp = ctx.band_heights_sp[ctx.cur_band]
                ctx.cur_y_sp = 0
                apply_band_padding(ctx)
            end
        elseif ctx.is_free_mode and ctx.content_width > 0 then
            -- Free mode: check if accumulated width exceeds available width
            if ctx.accumulated_width_sp >= ctx.content_width then
                should_wrap_page = true
                ctx.accumulated_width_sp = 0 -- Reset for new page
            end
        else
            -- Grid mode: use fixed column count
            should_wrap_page = (ctx.cur_col >= p_cols)
        end
    end

    if should_wrap_page then
        -- In table mode, save cum offset BEFORE wrap so the subsequent
        -- target_col in PENALTY_CELL_BREAK is rebased to the new page.
        -- Counts cells already finished (cell_idx); the cell currently
        -- rendering will continue at col 0 of the new page.
        if ctx.table_render_cell_idx ~= nil and ctx.band_mode == "parallel" then
            local all_col_groups_w = (_G.content and _G.content.table_col_groups) or {}
            local col_groups_w = all_col_groups_w[ctx.cur_band] or {}
            local cum_so_far = 0
            for i = 1, ctx.table_render_cell_idx do
                cum_so_far = cum_so_far + (col_groups_w[i] or 0)
            end
            ctx.table_render_cum_offset = cum_so_far
        end
        ctx.cur_page = ctx.cur_page + 1
        -- Always reset page_has_content on page turn:
        -- new page has no content yet regardless of reset_content flag.
        -- (reset_content only controls same-page column wraps)
        ctx.page_has_content = false
        if ctx.n_bands > 1 and ctx.band_mode == "parallel" then
            -- Parallel mode: track the maximum page any band reached,
            -- so TABLE_END can resume after all bands.
            ctx.table_max_page = math.max(ctx.table_max_page or ctx.cur_page, ctx.cur_page)
            -- Track per-band max page for border rendering
            if ctx.table_band_max_page then
                local band = ctx.cur_band
                ctx.table_band_max_page[band] = math.max(
                    ctx.table_band_max_page[band] or (ctx.table_start_page or 0),
                    ctx.cur_page)
            end
            -- Parallel mode: new page starts at col 0, keep same band.
            -- Update table_start_col since on the new page the table
            -- occupies the full width (no preceding content).
            ctx.cur_col = 0
            ctx.table_start_col = 0
            ctx.band_cols_per_band = p_cols
        elseif ctx.n_bands > 1 then
            -- Auto mode: reset to column 0, band 0
            ctx.cur_col = 0
            ctx.cur_band = 0
            ctx.line_limit = ctx.band_line_limits[0]
            ctx.col_height_sp = ctx.band_heights_sp[0]
        else
            ctx.cur_col = 0
        end
    end
    -- Always reset negative cur_column_indent on column wrap:
    -- taitou (negative indent) only applies to its own column.
    if reset_indent or (ctx.cur_column_indent or 0) < 0 then
        ctx.cur_column_indent = 0
    end
    -- Negative indent (taitou) should only apply in the taitou column itself.
    -- After column change, check if we're outside the taitou column scope.
    local skip_indent = indent
    if indent and indent < 0 then
        if ctx.taitou_col == nil or ctx.cur_col ~= ctx.taitou_col or ctx.cur_page ~= ctx.taitou_page then
            skip_indent = 0
        end
    end
    move_to_next_valid_position(ctx, interval, grid_height, skip_indent)
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

--- Flush pending textflow state (advance cursor past textflow rows)
-- Called before processing regular glyphs or penalty breaks that follow textflow
local function flush_textflow_pending(ctx, grid_height)
    if ctx.textflow_pending_sub_col and ctx.textflow_pending_row_used then
        ctx.cur_row = ctx.cur_row + ctx.textflow_pending_row_used
        ctx.cur_y_sp = ctx.cur_row * grid_height
        ctx.textflow_pending_sub_col = nil
        ctx.textflow_pending_row_used = nil
    end
end

--- Apply cell vertical-align post-processing
-- After a cell's content has been laid out, shift all its glyph y_sp
-- positions to center the content within the band height.
-- @param ctx (table) Grid context (reads cell_valign_nodes, cell_cur_valign, col_height_sp)
-- @param layout_map (table) The layout map (node -> map_entry)
local function apply_cell_valign_impl(valign, nodes, band_height, layout_map)
    if not nodes or #nodes == 0 then return false end
    if not valign or (valign ~= "center" and valign ~= "bottom") then return false end

    -- Find content bottom: max(y_sp + effective_height) across all nodes.
    -- For textbox blocks, use ATTR_TEXTBOX_HEIGHT_SP (precise sp height) when available,
    -- because cell_height (= tb_rows * outer_grid_height) is rounded up and may exceed
    -- the band height, preventing centering.
    local max_y = 0
    for _, n in ipairs(nodes) do
        local entry = layout_map[n]
        if entry then
            local h = entry.cell_height or 0
            if entry.is_block then
                local precise_h = D.get_attribute(n, constants.ATTR_TEXTBOX_HEIGHT_SP)
                if precise_h and precise_h > 0 then
                    h = precise_h
                end
            end
            local bottom = entry.y_sp + h
            if bottom > max_y then max_y = bottom end
        end
    end

    if band_height <= 0 or max_y <= 0 then return false end

    -- Offset: center = half gap, bottom = full gap
    local gap = band_height - max_y
    local offset = 0
    if valign == "center" then
        offset = math.floor(gap / 2)
    elseif valign == "bottom" then
        offset = gap
    end
    if offset > 0 then
        for _, n in ipairs(nodes) do
            local entry = layout_map[n]
            if entry then
                entry.y_sp = entry.y_sp + offset
            end
        end
    end
    return true
end

-- Get the effective band height for valign, deducting all padding.
-- Global c_padding_top/bottom shift content start/end within the band;
-- band-format padding_top/bottom further reduce usable space.
-- Both must be deducted so centering/bottom-aligning uses only the usable area.
local function get_valign_band_height(ctx)
    local bh = ctx.col_height_sp or 0
    -- Deduct global column padding
    bh = bh - (ctx.c_padding_top or 0) - (ctx.c_padding_bottom or 0)
    -- Deduct band-level padding
    if ctx.table_band_formats then
        local bf = ctx.table_band_formats[ctx.cur_band]
        if bf then
            if bf.padding_top then
                local pt = constants.to_dimen(bf.padding_top)
                if pt and pt > 0 then bh = bh - pt end
            end
            if bf.padding_bottom then
                local pb = constants.to_dimen(bf.padding_bottom)
                if pb and pb > 0 then bh = bh - pb end
            end
        end
    end
    return bh
end

local function apply_cell_valign(ctx, layout_map)
    local nodes = ctx.cell_valign_nodes
    local valign = ctx.cell_cur_valign

    if not nodes or #nodes == 0 then
        -- Nodes not yet available (textbox may appear after BAND_BREAK in node stream).
        -- Save pending valign so flush_buffer can apply it when nodes arrive.
        if valign and (valign == "center" or valign == "bottom") and nodes then
            ctx.pending_cell_valign = valign
            ctx.pending_cell_valign_band_height = get_valign_band_height(ctx)
            ctx.pending_cell_valign_nodes = {}
        end
        ctx.cell_valign_nodes = nil
        ctx.cell_cur_valign = nil
        return
    end

    local bh = get_valign_band_height(ctx)
    apply_cell_valign_impl(valign, nodes, bh, layout_map)

    ctx.cell_valign_nodes = nil
    ctx.cell_cur_valign = nil
end

_internal.apply_cell_valign = apply_cell_valign

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
    if p_val == constants.PENALTY_DIGITAL_NEWLINE then
        -- DigitalContent newline: always force column break, even on empty column.
        -- Every ^^M in DigitalContent source = one column in PDF output,
        -- so consecutive newlines (empty lines) must produce empty columns.
        -- Also disable auto column wrap: only explicit newlines cause column breaks.
        ctx.auto_column_wrap = false

        -- Skip this newline if it immediately follows a page break (\换页).
        -- After PENALTY_FORCE_PAGE, the page resets to col=0, row=0, page_has_content=false.
        -- The ^^M after \换页 is just the TeX source line ending, not a meaningful column break.
        if ctx.cur_col == 0 and ctx.cur_row == 0 and not ctx.page_has_content then
            return true
        end

        flush_buffer_fn()
        if ctx.is_free_mode then
            local g_w = get_grid_width(ctx.params, grid_height)
            ctx.accumulated_width_sp = ctx.accumulated_width_sp + g_w
        end
        wrap_to_next_column(ctx, p_cols, interval, grid_height, indent, false, true)
        ctx.cur_column_indent = 0
        return true
    elseif p_val == constants.PENALTY_FORCE_COLUMN or p_val == constants.PENALTY_TAITOU then
        -- Forced column break (\换行 command) or taitou column break (\抬头 command)
        flush_buffer_fn()
        -- Use actual cur_column_indent (not clamped to 0) so that columns with
        -- taitou (negative indent) are correctly detected as non-empty.
        -- E.g., \抬头[2]壹贰\\ → cur_column_indent=-2, cur_row=0 → 0 > -2 → wrap.
        -- Without this, cur_row(0) > max(-2,0)=0 is false → wrap skipped (bug #78).
        if ctx.cur_row > ctx.cur_column_indent then
            -- Free mode: accumulate column width for page wrap
            if ctx.is_free_mode then
                local g_w = get_grid_width(ctx.params, grid_height)
                ctx.accumulated_width_sp = ctx.accumulated_width_sp + g_w
            end
            wrap_to_next_column(ctx, p_cols, interval, grid_height, indent, false, true)
        end
        ctx.cur_column_indent = 0
        -- Only taitou penalties record the target column for scope tracking.
        -- Regular PENALTY_FORCE_COLUMN (paragraph breaks, \换行) must NOT
        -- update taitou scope, otherwise stale forced negative indent from a
        -- previous \抬头 would leak into subsequent paragraphs.
        if p_val == constants.PENALTY_TAITOU then
            ctx.taitou_col = ctx.cur_col
            ctx.taitou_page = ctx.cur_page
        end
        return true
    elseif p_val == constants.PENALTY_HALF_PAGE then
        -- Half-page break (\换半页): skip to next half-page boundary.
        -- In butterfly-binding mode, each page = left half + banxin + right half.
        -- interval = n_column = columns per half-page.
        -- Left half: cols 0..interval-1, banxin: col interval, right half: cols interval+1..2*interval.
        if interval > 0 then
            flush_buffer_fn()
            -- When at the start of a half-page with no content in this half yet,
            -- just record the penalty node in place (don't jump).
            -- This handles \插图页 at page/half-page start: no-silk applies to current half.
            -- cur_row==0 at a half-page boundary means the current half is empty,
            -- regardless of whether the other half had content (page_has_content).
            local at_half_start = (ctx.cur_col == 0 or ctx.cur_col == interval + 1)
                                  and ctx.cur_row == 0
            if at_half_start then
                if penalty_node then
                    ctx.layout_map[penalty_node] = {
                        page = ctx.cur_page,
                        col = ctx.cur_col,
                        row = 0,
                        y_sp = 0,
                    }
                end
            else
                local target_col
                if ctx.cur_col <= interval then
                    -- Currently in left half (or at banxin): jump to right half start
                    target_col = interval + 1
                else
                    -- Currently in right half: jump to next page
                    target_col = 2 * interval + 1
                end
                -- Advance to target column
                ctx.cur_col = target_col
                ctx.cur_row = 0
                ctx.cur_y_sp = 0
                ctx.cur_column_indent = 0
                -- Check if we've passed page boundary
                if ctx.cur_col >= p_cols then
                    ctx.cur_col = 0
                    ctx.cur_page = ctx.cur_page + 1
                    ctx.page_has_content = false
                end
                -- Record penalty node in layout_map at final position
                -- so the no-silk scan covers the correct half-page.
                if penalty_node then
                    ctx.layout_map[penalty_node] = {
                        page = ctx.cur_page,
                        col = ctx.cur_col,
                        row = 0,
                        y_sp = 0,
                    }
                end
                move_to_next_valid_position(ctx, interval, grid_height, indent)
            end
        end
        return true
    elseif p_val == constants.PENALTY_FORCE_PAGE then
        -- Forced page break (\newpage, \clearpage)
        if not ctx.page_has_content and ctx.cur_col == 0 and ctx.cur_row == 0 then
            if ctx.n_bands > 1 then
                -- Inside a table: place a placeholder so render stage still
                -- produces the empty page (needed for parallel mode cross-page tables).
                if penalty_node then
                    ctx.layout_map[penalty_node] = {
                        page = ctx.cur_page,
                        col = 0,
                        row = 0,
                        y_sp = 0,
                        mode = "placeholder",
                    }
                end
            else
                -- Normal text: skip redundant page break to avoid empty pages
                -- (e.g., column overflow already wrapped to a new page).
                return true
            end
        end
        flush_buffer_fn()
        ctx.cur_page = ctx.cur_page + 1
        ctx.cur_col = 0
        ctx.cur_row = 0
        ctx.cur_y_sp = 0
        ctx.cur_column_indent = 0
        ctx.page_has_content = false
        -- Reset band to 0 on explicit page break
        if ctx.n_bands > 1 then
            ctx.cur_band = 0
            ctx.line_limit = ctx.band_line_limits[0]
            ctx.col_height_sp = ctx.band_heights_sp[0]
        end
        move_to_next_valid_position(ctx, interval, grid_height, indent)
        return true
    elseif p_val == constants.PENALTY_BAND_BREAK then
        -- Forced band break (\换栏 command)
        -- Skip to the next horizontal band (or next page if on last band)
        if ctx.n_bands > 1 then
            flush_buffer_fn()
            apply_cell_valign(ctx, ctx.layout_map)
            ctx.cur_col = ctx.table_start_col or 0
            reset_column_transient_state(ctx)
            ctx.cur_column_indent = 0
            -- Reset table cell index for new band (row)
            if ctx.table_start_col ~= nil then
                ctx.table_render_cell_idx = 0
                ctx.table_render_cum_offset = 0
            end
            ctx.cur_band = ctx.cur_band + 1
            if ctx.cur_band >= ctx.n_bands then
                -- Both auto and parallel: wrap to next page, band 0
                ctx.cur_band = 0
                ctx.cur_page = ctx.cur_page + 1
                ctx.page_has_content = false
                -- On new page, table starts at col 0 with full page width
                -- (unless column_fill=half-page, which keeps the original width)
                ctx.cur_col = 0
                ctx.table_start_col = 0
                ctx.band_cols_per_band = ctx.table_orig_band_cols or p_cols
            elseif ctx.band_mode == "parallel" and ctx.table_start_page ~= nil then
                -- Parallel mode: each band starts independently from the
                -- table's start page/col, so a long band that overflowed to
                -- later pages does not push subsequent bands forward.
                ctx.cur_page = ctx.table_start_page
                local orig_col = ctx.table_orig_start_col or 0
                ctx.cur_col = orig_col
                ctx.table_start_col = orig_col
                ctx.band_cols_per_band = ctx.table_orig_band_cols or (p_cols - orig_col)
                ctx.page_has_content = true
            end
            ctx.line_limit = ctx.band_line_limits[ctx.cur_band]
            ctx.col_height_sp = ctx.band_heights_sp[ctx.cur_band]
            apply_band_padding(ctx)

            -- Initialize valign tracking for the first cell of the new band
            local all_cell_valigns = _G.content and _G.content.table_cell_valigns or {}
            local cell_valigns = all_cell_valigns[ctx.cur_band] or {}
            if cell_valigns[1] then
                ctx.cell_valign_nodes = {}
                ctx.cell_cur_valign = cell_valigns[1]
            end

            move_to_next_valid_position(ctx, interval, grid_height, indent)
        end
        return true
    elseif p_val == constants.PENALTY_CELL_BREAK then
        -- Cell break in table mode: jump to next column group
        -- Use ctx.table_start_col to detect table mode (not _G.content.table_mode
        -- which is already cleared by cleanup() before layout runs)
        if ctx.table_start_col ~= nil then
            flush_buffer_fn()
            apply_cell_valign(ctx, ctx.layout_map)

            local all_col_groups = (_G.content and _G.content.table_col_groups) or {}
            local col_groups = all_col_groups[ctx.cur_band] or {}
            local cell_idx = ctx.table_render_cell_idx or 0
            local cell_width = col_groups[cell_idx + 1] or 0

            if cell_width > 0 then
                -- Fixed-width cell: jump to start of next group.
                -- cum_offset is set when a mid-band page-wrap occurred,
                -- to rebase target_col relative to the new page (otherwise
                -- target_col would still reflect pre-wrap position, leaving
                -- large gaps between cells across pages).
                local band_start = ctx.table_start_col
                local cum = 0
                for i = 1, cell_idx + 1 do
                    cum = cum + (col_groups[i] or 0)
                end
                local cum_offset = ctx.table_render_cum_offset or 0
                local target_col = band_start + (cum - cum_offset)
                -- If the previous cell's content overflowed past the target column
                -- (e.g. auto-width cells contributed 0 to cum but consumed real columns),
                -- use current position + cell_width, ensuring at least 1 column advance.
                if target_col <= ctx.cur_col then
                    local advance = math.max(cell_width, ctx.cur_row > 0 and 1 or 0)
                    target_col = ctx.cur_col + advance
                end
                ctx.cur_col = target_col
            else
                -- Auto-width cell (行宽=nil): advance past current content
                -- Always advance at least 1 column to avoid overlap with next cell
                ctx.cur_col = ctx.cur_col + 1
            end

            -- Parallel mode: if cell pushed cur_col past band boundary, wrap to next page
            if ctx.band_mode == "parallel" and ctx.n_bands > 1 then
                local band_start = ctx.table_start_col or 0
                local cols_in_band = ctx.band_cols_per_band
                if ctx.cur_col >= band_start + cols_in_band then
                    -- Save cum offset BEFORE wrap so subsequent target_col is
                    -- rebased to the new page.
                    local cum_so_far = 0
                    for i = 1, cell_idx + 1 do
                        cum_so_far = cum_so_far + (col_groups[i] or 0)
                    end
                    ctx.table_render_cum_offset = cum_so_far
                    ctx.cur_page = ctx.cur_page + 1
                    ctx.table_max_page = math.max(ctx.table_max_page or ctx.cur_page, ctx.cur_page)
                    if ctx.table_band_max_page then
                        local band = ctx.cur_band
                        ctx.table_band_max_page[band] = math.max(
                            ctx.table_band_max_page[band] or (ctx.table_start_page or 0),
                            ctx.cur_page)
                    end
                    ctx.page_has_content = false
                    ctx.cur_col = 0
                    ctx.table_start_col = 0
                    ctx.band_cols_per_band = p_cols
                end
            end

            reset_column_transient_state(ctx)
            ctx.cur_column_indent = 0
            apply_band_padding(ctx)
            ctx.table_render_cell_idx = cell_idx + 1

            -- Initialize valign tracking for the next cell
            local all_cell_valigns = _G.content and _G.content.table_cell_valigns or {}
            local cell_valigns = all_cell_valigns[ctx.cur_band] or {}
            local next_valign = cell_valigns[cell_idx + 2]
            if next_valign then
                ctx.cell_valign_nodes = {}
                ctx.cell_cur_valign = next_valign
            end

            move_to_next_valid_position(ctx, interval, grid_height, indent)
        end
        return true
    elseif p_val == constants.PENALTY_TABLE_START then
        -- Begin inline table section: switch to band mode dynamically
        flush_buffer_fn()
        -- Start table on a new column
        if ctx.cur_row > 0 or ctx.cur_col > 0 then
            ctx.cur_col = ctx.cur_col + (ctx.cur_row > 0 and 1 or 0)
            ctx.cur_row = 0
            ctx.cur_y_sp = 0
            ctx.cur_column_indent = 0
        end

        -- Save pre-table state
        ctx.saved_band_state = {
            n_bands = ctx.n_bands,
            band_heights_sp = ctx.band_heights_sp,
            band_y_offsets_sp = ctx.band_y_offsets_sp,
            band_line_limits = ctx.band_line_limits,
            band_cols_per_band = ctx.band_cols_per_band,
            band_mode = ctx.band_mode,
            band_gap_sp = ctx.band_gap_sp,
            line_limit = ctx.line_limit,
            col_height_sp = ctx.col_height_sp,
        }

        -- Dequeue table instance from the FIFO queue
        local table_mod = require('core.luatex-cn-core-table')
        local table_instance = table_mod.dequeue_instance()
        local tp = (table_instance and table_instance.params) or {}
        -- Install instance data so TABLE_END handler can read col_groups etc.
        if _G.content and table_instance then
            _G.content.table_params = table_instance.params
            _G.content.table_col_groups = table_instance.col_groups
            _G.content.table_band_formats = table_instance.band_formats
            _G.content.table_cell_valigns = table_instance.cell_valigns
            _G.content.table_cell_column_borders = table_instance.cell_column_borders
        end
        local n_bands = tp.n_bands or 2
        local band_gap_sp = tp.band_gap_sp or 0
        -- Use full content height for band allocation (no padding deduction)
        local alloc_height = ctx.band_alloc_height or ctx.saved_band_state.col_height_sp
        local default_cell_height = ctx.default_cell_height
        local orig_line_limit = ctx.saved_band_state.line_limit

        -- Calculate band layout
        local total_gap = band_gap_sp * (n_bands - 1)
        local available_height = alloc_height - total_gap
        local band_heights_sp = {}
        local band_y_offsets_sp = {}
        local band_line_limits = {}
        local band_heights = tp.band_heights

        -- Pre-compute default height: unspecified bands share remaining space equally.
        -- The last unspecified band absorbs any sp rounding remainder.
        local specified_total = 0
        local unspecified_count = 0
        local last_unspecified = -1
        for i = 0, n_bands - 1 do
            if band_heights and band_heights[i + 1] then
                specified_total = specified_total + band_heights[i + 1]
            else
                unspecified_count = unspecified_count + 1
                last_unspecified = i
            end
        end
        local default_h = unspecified_count > 0
            and math.floor((available_height - specified_total) / unspecified_count)
            or 0

        local offset = 0
        for i = 0, n_bands - 1 do
            local h
            if band_heights and band_heights[i + 1] then
                h = band_heights[i + 1]
            elseif i == last_unspecified then
                -- Last unspecified band absorbs rounding remainder
                h = alloc_height - offset
                if h < 0 then h = 0 end
            else
                h = default_h
            end
            band_heights_sp[i] = h
            band_y_offsets_sp[i] = offset
            band_line_limits[i] = default_cell_height
                and math.floor(h / default_cell_height) or orig_line_limit
            offset = offset + h + band_gap_sp
        end

        ctx.n_bands = n_bands
        ctx.band_heights_sp = band_heights_sp
        ctx.band_y_offsets_sp = band_y_offsets_sp
        ctx.band_line_limits = band_line_limits
        local cf = tp.column_fill
        if cf == "page" then
            ctx.band_cols_per_band = p_cols - ctx.cur_col
        elseif cf == "half-page" and interval > 0 then
            -- Fill current half-page only
            local half_end
            if ctx.cur_col <= interval then
                -- In left half (or at banxin): fill up to banxin boundary
                half_end = interval
            else
                -- In right half: fill up to page end
                half_end = p_cols
            end
            ctx.band_cols_per_band = half_end - ctx.cur_col
        elseif tp.n_columns and tp.n_columns > 0 then
            ctx.band_cols_per_band = tp.n_columns
        else
            ctx.band_cols_per_band = p_cols
        end
        ctx.band_mode = "parallel"
        ctx.band_gap_sp = band_gap_sp
        ctx.cur_band = 0
        ctx.line_limit = band_line_limits[0]
        ctx.col_height_sp = band_heights_sp[0]

        -- Record table start column and init cell tracking
        ctx.table_start_col = ctx.cur_col
        ctx.table_start_page = ctx.cur_page
        ctx.table_orig_start_col = ctx.cur_col  -- immutable copy for parallel reset
        ctx.table_orig_band_cols = ctx.band_cols_per_band  -- immutable copy for parallel reset
        -- Track max page each band reaches (for per-page border rendering)
        ctx.table_band_max_page = {}
        ctx.table_render_cell_idx = 0
        -- Cum offset for target_col rebase after page-wrap mid-band
        ctx.table_render_cum_offset = 0
        -- Save band formats for per-band padding lookup
        ctx.table_band_formats = _G.content and _G.content.table_band_formats or nil
        -- Apply band 0 padding
        apply_band_padding(ctx)

        -- Initialize valign tracking for the first cell (band 0)
        local all_cell_valigns = _G.content and _G.content.table_cell_valigns or {}
        local cell_valigns = all_cell_valigns[0] or {}
        if cell_valigns[1] then
            ctx.cell_valign_nodes = {}
            ctx.cell_cur_valign = cell_valigns[1]
        end

        move_to_next_valid_position(ctx, interval, grid_height, indent)
        return true
    elseif p_val == constants.PENALTY_TABLE_END then
        -- End inline table section: restore pre-table band state
        flush_buffer_fn()
        apply_cell_valign(ctx, ctx.layout_map)

        -- Parallel mode: restore cur_page to the maximum page any band reached,
        -- so the table end position accounts for all bands' overflow.
        if ctx.table_max_page and ctx.table_max_page > ctx.cur_page then
            ctx.cur_page = ctx.table_max_page
            ctx.cur_col = 0
            ctx.page_has_content = false
        end

        -- Record table end info for border rendering
        ctx.table_end_col = ctx.cur_col
        ctx.table_end_page = ctx.cur_page

        -- Read column_fill early (needed for both border width and page break)
        local tparams_cf = (_G.content and _G.content.table_params)
            and _G.content.table_params.column_fill or nil
        local is_fill_page = (tparams_cf == "page" or tparams_cf == "half-page")

        -- Calculate actual table width from col_groups (max across all bands).
        -- For column_fill=page, the start-page width differs from continuation
        -- pages (start spans from table_orig_start_col to page right edge;
        -- continuations start at col 0 and span the full page), so we record
        -- both and pick per-page below.
        local all_col_groups = (_G.content and _G.content.table_col_groups) or {}
        local actual_band_cols = 0
        local actual_band_cols_overflow = nil
        if is_fill_page then
            -- column_fill=page: start-page width is the original (saved before
            -- any mid-band page wrap reset ctx.band_cols_per_band to p_cols).
            actual_band_cols = ctx.table_orig_band_cols or ctx.band_cols_per_band
            actual_band_cols_overflow = p_cols
        else
            for _, band_groups in pairs(all_col_groups) do
                local band_cols = 0
                for i = 1, #band_groups do
                    local w = band_groups[i] or 0
                    band_cols = band_cols + (w > 0 and w or 1)
                end
                if band_cols > actual_band_cols then
                    actual_band_cols = band_cols
                end
            end
        end
        if actual_band_cols == 0 then
            actual_band_cols = ctx.band_cols_per_band
        end

        -- Save per-page inline table band info for border rendering
        ctx.page_table_bands = ctx.page_table_bands or {}
        local start_page = ctx.table_start_page or ctx.cur_page
        local end_page = ctx.cur_page
        local band_max_page = ctx.table_band_max_page or {}
        for pg = start_page, end_page do
            do
            local tparams = _G.content and _G.content.table_params or {}
            -- Build per-band column_border map from band_formats
            local band_formats = _G.content and _G.content.table_band_formats
            local band_column_borders = nil
            if band_formats and next(band_formats) then
                band_column_borders = {}
                for band_idx, fmt in pairs(band_formats) do
                    if fmt.column_border ~= nil then
                        band_column_borders[band_idx] = fmt.column_border
                    end
                end
                if not next(band_column_borders) then band_column_borders = nil end
            end

            -- Build per-cell column_border map
            local cell_column_borders = _G.content and _G.content.table_cell_column_borders or nil
            local cell_col_borders_map = nil
            if cell_column_borders and next(cell_column_borders) then
                cell_col_borders_map = cell_column_borders
            end

            -- Per-cell column borders are keyed by absolute cell_idx, which
            -- corresponds to specific cells on the start page only. On overflow
            -- pages, those cell positions are different (or empty) so applying
            -- the same map would draw spurious vertical lines at wrong places.
            local pg_cell_borders = (pg == start_page) and cell_col_borders_map or nil
            -- Multi-table per page: store as array, not single object,
            -- so multiple tables on the same page each retain their band info.
            local pg_band_cols = (pg == start_page) and actual_band_cols
                or (actual_band_cols_overflow or actual_band_cols)
            ctx.page_table_bands[pg] = ctx.page_table_bands[pg] or {}
            table.insert(ctx.page_table_bands[pg], {
                n_bands = ctx.n_bands,
                band_heights_sp = ctx.band_heights_sp,
                band_y_offsets_sp = ctx.band_y_offsets_sp,
                band_gap_sp = ctx.band_gap_sp or 0,
                table_start_col = (pg == start_page) and (ctx.table_orig_start_col or 0) or 0,
                actual_band_cols = pg_band_cols,
                column_border = tparams.column_border,
                band_border = tparams.band_border,
                band_column_borders = band_column_borders,
                cell_column_borders = pg_cell_borders,
                column_fill = tparams_cf,
                -- Debug: save cell column groups for cell coordinate debug
                col_groups = all_col_groups,
                n_columns = ctx.band_cols_per_band,
            })
            end
        end

        -- Move to next column after the table
        ctx.cur_col = ctx.cur_col + (ctx.cur_row > 0 and 1 or 0)
        reset_column_transient_state(ctx)
        ctx.cur_column_indent = 0

        -- column_fill=page/half-page: force break after table
        -- Skip if already at the start of a new page (e.g. parallel mode wrapped here)
        if is_fill_page and (ctx.cur_col > 0 or ctx.page_has_content) then
            if tparams_cf == "half-page" and interval > 0 then
                -- half-page: advance to next half-page boundary
                if ctx.cur_col <= interval then
                    -- In left half: jump to right half start
                    ctx.cur_col = interval + 1
                else
                    -- In right half: jump to next page
                    ctx.cur_col = 0
                    ctx.cur_page = ctx.cur_page + 1
                    ctx.page_has_content = false
                end
            else
                -- page: advance to next page
                ctx.cur_col = 0
                ctx.cur_page = ctx.cur_page + 1
                ctx.page_has_content = false
            end
        end

        -- Restore saved band state
        if ctx.saved_band_state then
            local s = ctx.saved_band_state
            ctx.n_bands = s.n_bands
            ctx.band_heights_sp = s.band_heights_sp
            ctx.band_y_offsets_sp = s.band_y_offsets_sp
            ctx.band_line_limits = s.band_line_limits
            ctx.band_cols_per_band = s.band_cols_per_band
            ctx.band_mode = s.band_mode
            ctx.band_gap_sp = s.band_gap_sp
            ctx.line_limit = s.line_limit
            ctx.col_height_sp = s.col_height_sp
            ctx.cur_band = 0
            ctx.saved_band_state = nil
        end

        -- Clean up table-specific ctx state
        ctx.table_start_col = nil
        ctx.table_start_page = nil
        ctx.table_orig_start_col = nil
        ctx.table_max_page = nil
        ctx.table_band_max_page = nil
        ctx.table_render_cell_idx = nil
        -- Clean up table data that were preserved for layout
        if _G.content then
            _G.content.table_col_groups = nil
            _G.content.table_params = nil
            _G.content.table_band_formats = nil
            _G.content.table_cur_band = nil
            _G.content.table_cell_valigns = nil
            _G.content.table_cell_column_borders = nil
        end

        move_to_next_valid_position(ctx, interval, grid_height, indent)
        return true
    end
    return false
end

_internal.handle_penalty_breaks = handle_penalty_breaks

--- Handle all penalty nodes: smart break, force column, force page
-- Combines smart break logic (previously inline in main loop) with
-- handle_penalty_breaks for a unified penalty dispatch.
local function handle_penalty_node(t, ctx, grid_height, indent, interval, p_cols, flush_fn)
    local p_val = D.getfield(t, "penalty")
    if p_val == constants.PENALTY_SMART_BREAK then
        -- Smart column break: only break if next node is NOT textflow
        local next_node = D.getnext(t)
        if next_node then
            local next_is_textflow = D.get_attribute(next_node, constants.ATTR_JIAZHU) == 1
            if not next_is_textflow then
                -- If column is empty (cur_row==0, e.g. after FORCE_COLUMN wrapped),
                -- clear stale textflow pending state without advancing cur_row.
                -- Otherwise a normal flush would re-add pending rows from the
                -- previous column and cause a double-wrap (empty column bug).
                if ctx.cur_row == 0 and ctx.textflow_pending_row_used
                    and ctx.just_wrapped_column then
                    -- Truly-empty column right after a wrap: stale pending
                    ctx.textflow_pending_sub_col = nil
                    ctx.textflow_pending_row_used = nil
                else
                    flush_textflow_pending(ctx, grid_height)
                end
                flush_fn()
                -- Use max(cur_column_indent, 0) to prevent negative indent (抬头)
                -- from causing false-positive wraps (same logic as FORCE_COLUMN).
                local sb_effective_indent = math.max(ctx.cur_column_indent, 0)
                if ctx.cur_row > sb_effective_indent then
                    wrap_to_next_column(ctx, p_cols, interval, grid_height, indent, false, true)
                end
                ctx.cur_column_indent = 0
            end
            -- If next is textflow, don't break - let textflow continue naturally
        end
    else
        handle_penalty_breaks(p_val, ctx, flush_fn, p_cols, interval, grid_height, indent, t)
    end
end
_internal.handle_penalty_node = handle_penalty_node

--- Get grid width for free mode column tracking
local function get_free_mode_grid_width(params)
    return params.grid_width or 0
end

--- Accumulate column width and record for free mode page-wrap detection
local function accumulate_free_mode_col_width(ctx, params)
    if not ctx.is_free_mode then return end
    local g_w = get_free_mode_grid_width(params)
    ctx.accumulated_width_sp = ctx.accumulated_width_sp + g_w
    ctx.col_widths_sp[ctx.cur_page] = ctx.col_widths_sp[ctx.cur_page] or {}
    if not ctx.col_widths_sp[ctx.cur_page][ctx.cur_col + 1] then
        ctx.col_widths_sp[ctx.cur_page][ctx.cur_col + 1] = g_w
    end
end

--- Determine indent for current cursor position (first-indent vs base-indent)
-- @param ctx (table) Grid context (reads cur_page, cur_col)
-- @param block_start_cols (table) Map of block_id -> {page, col} tracking first column
-- @param block_id (number|nil) Current block ID
-- @param base_indent (number) Base indent value
-- @param first_indent (number) First-column indent value (-1 means not set)
-- @return (number) The indent to use
local function get_indent_for_current_pos(ctx, block_start_cols, block_id, base_indent, first_indent)
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

--- Resolve indentation and layout constraints for a node
-- Three-tier priority: forced indent > explicit attribute > style stack inheritance
-- @param t (direct node) Current node
-- @param id (number) Node type ID
-- @param ctx (table) Grid context
-- @param block_start_cols (table) Block tracking map
-- @param grid_height (number) Grid height in sp
-- @param line_limit (number) Max rows per column
-- @return indent, r_indent, effective_limit, effective_col_height_sp, tb_w, tb_h
local function resolve_node_indent(t, id, ctx, block_start_cols, grid_height, line_limit)
    -- Penalty nodes don't occupy layout space — they should never carry indent.
    -- TeX's attribute inheritance causes penalty nodes inside \Column to inherit
    -- forced indent from \Indent, leading to empty columns in layout grid.
    if id == constants.PENALTY then
        local effective_limit = ctx.line_limit or line_limit
        local effective_col_height_sp = math.min(effective_limit * grid_height,
            ctx.col_height_sp or (effective_limit * grid_height))
        return 0, 0, effective_limit, effective_col_height_sp, 0, 0, 0, -1, nil
    end

    local block_id = D.get_attribute(t, constants.ATTR_BLOCK_ID)
    local node_indent = D.get_attribute(t, constants.ATTR_INDENT)
    local node_first_indent = D.get_attribute(t, constants.ATTR_FIRST_INDENT)

    -- Decode indent: two categories with different scope rules
    --   Taitou indent (\抬头/\平抬/\相对抬头): scoped to taitou column
    --   Suojin indent (\缩进[N]): not affected by taitou scope
    local indent_is_taitou, taitou_indent_value = constants.is_taitou_indent(node_indent)
    local indent_is_suojin, suojin_indent_value = constants.is_suojin_indent(node_indent)
    local first_indent_is_taitou, first_taitou_value = constants.is_taitou_indent(node_first_indent)
    local first_indent_is_suojin, first_suojin_value = constants.is_suojin_indent(node_first_indent)

    local indent_is_forced = indent_is_taitou or indent_is_suojin
    local first_indent_is_forced = first_indent_is_taitou or first_indent_is_suojin

    -- Taitou scope check: taitou indent only applies in the taitou column.
    -- When taitou_col is set (by PENALTY_TAITOU handler), nodes outside that
    -- column have their taitou values cleared and fall back to style stack.
    -- When taitou_col is nil (no active scope), taitou values pass through
    -- because wrap_to_next_column already cleared the scope — any remaining
    -- taitou-encoded nodes are in the correct (target) column.
    local outside_taitou = ctx.taitou_col ~= nil
        and (ctx.cur_col ~= ctx.taitou_col or ctx.cur_page ~= ctx.taitou_page)
    if indent_is_taitou and outside_taitou then
        indent_is_taitou = false
        indent_is_forced = false
        node_indent = nil
    end
    if first_indent_is_taitou and outside_taitou then
        first_indent_is_taitou = false
        first_indent_is_forced = false
        node_first_indent = nil
    end
    -- Note: suojin indent is NOT affected by taitou scope.

    -- Resolve base_indent: forced (taitou or suojin) > explicit > style stack
    local forced_indent_value = indent_is_taitou and taitou_indent_value
        or indent_is_suojin and suojin_indent_value or nil
    local base_indent = forced_indent_value or (node_indent or 0)

    local forced_first_value = first_indent_is_taitou and first_taitou_value
        or first_indent_is_suojin and first_suojin_value or nil
    local first_indent = forced_first_value or (node_first_indent or -1)

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

    local indent = get_indent_for_current_pos(ctx, block_start_cols, block_id, base_indent, first_indent)
    local r_indent = D.get_attribute(t, constants.ATTR_RIGHT_INDENT) or 0

    -- Textbox attributes; ONLY treat HLIST/VLIST as blocks
    local tb_w = 0
    local tb_h = 0
    if id == constants.HLIST or id == constants.VLIST then
        tb_w = D.get_attribute(t, constants.ATTR_TEXTBOX_WIDTH) or 0
        tb_h = D.get_attribute(t, constants.ATTR_TEXTBOX_HEIGHT) or 0
    end

    local effective_limit = (ctx.line_limit or line_limit) - r_indent
    if effective_limit < indent + 1 then effective_limit = indent + 1 end
    local effective_col_height_sp = math.min(effective_limit * grid_height,
        ctx.col_height_sp or (effective_limit * grid_height))

    return indent, r_indent, effective_limit, effective_col_height_sp, tb_w, tb_h, base_indent, first_indent, block_id
end

--- Export free mode layout data to _G.content
-- Fills missing column widths and exports accumulated data for render-position
local function export_free_mode_data(ctx, layout_map, params)
    if not ctx.is_free_mode then return end

    -- Fill in missing column widths from layout_map
    -- \行 columns record their own widths, but regular text columns
    -- only trigger overflow recording when full. This fills gaps with grid_width.
    local g_w = get_free_mode_grid_width(params)
    local max_col_per_page = {}
    for _, pos in pairs(layout_map) do
        local pg = pos.page
        local col = pos.col
        if pg and col then
            if not max_col_per_page[pg] or col > max_col_per_page[pg] then
                max_col_per_page[pg] = col
            end
        end
    end
    for pg, max_col in pairs(max_col_per_page) do
        ctx.col_widths_sp[pg] = ctx.col_widths_sp[pg] or {}
        for c = 0, max_col do
            if not ctx.col_widths_sp[pg][c + 1] then
                ctx.col_widths_sp[pg][c + 1] = g_w
            end
        end
    end

    _G.content = _G.content or {}
    _G.content.is_free_mode_layout = true
    _G.content.col_widths_sp = ctx.col_widths_sp
    _G.content.col_spacing_top_sp = ctx.col_spacing_top_sp
    _G.content.col_spacing_bottom_sp = ctx.col_spacing_bottom_sp

    -- Debug: log recorded widths
    local total_cols = 0
    for _, cols in pairs(ctx.col_widths_sp) do
        for _ in pairs(cols) do
            total_cols = total_cols + 1
        end
    end
    dbg.log(string.format("[Phase 2.3] Free Mode: recorded %d column widths", total_cols))
end

--- Handle spacing node (glue/kern): accumulate and quantize to grid
-- @param t (direct node) Current spacing node
-- @param ctx (table) Grid context
-- @param grid_height (number) Grid height in sp
-- @param effective_col_height_sp (number) Effective column height in sp
-- @param indent (number) Current indent
-- @param interval (number) Banxin interval
-- @param p_cols (number) Columns per page
-- @param flush_fn (function) Buffer flush callback
-- @return (direct node|nil) Next node to process (nil = end of list)
local function handle_spacing_node(t, ctx, grid_height, effective_col_height_sp,
                                    indent, interval, p_cols, flush_fn)
    local net_width, lookahead = accumulate_spacing(t)

    -- In table mode, don't auto-wrap on spacing overflow
    local in_table = ctx.table_start_col ~= nil

    -- Unified guard: skip spacing at column start (before any content)
    if net_width > 0 and ctx.cur_y_sp > 0 then
        if ctx.default_cell_height then
            -- Grid mode: quantize spacing to discrete grid cells
            local cell_h = ctx.default_cell_height
            local threshold = cell_h * 0.25
            if net_width > threshold then
                local num_cells = math.floor(net_width / cell_h + 0.5)
                if num_cells < 1 then num_cells = 1 end

                dbg.log(string.format("  SPACING: val=%.2fpt, grid_h=%.2fpt, num_cells=%d",
                    net_width / 65536, grid_height / 65536, num_cells))

                for i = 1, num_cells do
                    ctx.cur_y_sp = ctx.cur_y_sp + cell_h
                    ctx.cur_row = math.floor(ctx.cur_y_sp / grid_height + 0.5)
                    if not in_table and ctx.cur_y_sp >= effective_col_height_sp then
                        flush_fn("wrap")
                        wrap_to_next_column(ctx, p_cols, interval, grid_height, indent, false, false)
                    else
                        move_to_next_valid_position(ctx, interval, grid_height, indent)
                    end
                end
            end
        else
            -- Natural mode: accumulate sp directly, no quantization
            ctx.cur_y_sp = ctx.cur_y_sp + net_width
            ctx.cur_row = math.floor(ctx.cur_y_sp / grid_height + 0.5)
            if not in_table and ctx.cur_y_sp > effective_col_height_sp then
                flush_fn("wrap")
                wrap_to_next_column(ctx, p_cols, interval, grid_height, indent, false, false)
            end
        end
    end

    return lookahead
end

--- Helper: Calculate actual accumulated height in column buffer
-- Returns total height of all characters + gaps between them
-- @param col_buffer (table) Buffer of character entries
-- @return (number) Total accumulated height in sp

--- 估算用的相邻字距（sp），与 inter_gap_desc 的 width 同口径：两字幅
-- 标点单元内部 0、中西边界 1/4em、其余 0.1em。估算与求解器不一致会让
-- 列尾早换（或晚换）一列——#119 的教训。
local function est_inter_gap_sp(prev_node, prev_ch, next_node)
    if D.get_attribute(next_node, constants.ATTR_RIGID_PREV) == 2 then
        return 0
    end
    -- 横置西文串内部：字母连排成词，无字距
    if D.get_attribute(prev_node, constants.ATTR_SIDEWAYS) == 1
        and D.get_attribute(next_node, constants.ATTR_SIDEWAYS) == 1 then
        return 0
    end
    -- 中横排组内部：整组共占一格，组内无字距
    local tcy = D.get_attribute(prev_node, constants.ATTR_TCY)
    if tcy and tcy > 0
        and D.get_attribute(next_node, constants.ATTR_TCY) == tcy then
        return 0
    end
    if D.get_attribute(next_node, constants.ATTR_CJK_WESTERN_PREV) == 1 then
        local em = get_node_font_size(prev_node) or prev_ch
        return math.floor(em * 0.25)
    end
    return math.floor(prev_ch * GAP_RATIO)
end

local function calculate_buffer_height(col_buffer)
    if #col_buffer == 0 then return 0 end
    local total_height = 0
    for i, entry in ipairs(col_buffer) do
        local ch = entry.cell_height or 0
        total_height = total_height + ch
        if i < #col_buffer then
            total_height = total_height
                + est_inter_gap_sp(entry.node, ch, col_buffer[i + 1].node)
        end
    end
    return total_height
end

_internal.calculate_buffer_height = calculate_buffer_height

-- ============================================================================
-- Natural Mode Kinsoku (Line-breaking Rules)
-- ============================================================================
-- Punctuation type codes (from ATTR_PUNCT_TYPE):
-- 1=open, 2=close, 3=fullstop, 4=comma, 5=middle, 6=nobreak

local function is_line_start_forbidden_code(code)
    return code == 2 or code == 3 or code == 4 or code == 5
end

local function is_line_end_forbidden_code(code)
    return code == 1
end

-- ============================================================================
-- clreq 行内调整：把一列拆成「刚性字幅 + 可调 gap」
-- 设计见 docs/CLREQ-VERTICAL-ADJUST-DESIGN.md §2
-- ============================================================================

--- 字幅基准（sp）：与 get_cell_height 同一口径——样式字号 → 字体字号 →
-- 正文网格。标点的收回量都是相对它的比例，取错基准会让字面居中错位
-- （用已扣掉收回量的 cell_height 当基准就是这个错误）。
local function node_em(nd, grid_height)
    local fs = get_node_font_size(nd)
    if fs and fs > 0 then return fs end
    local fid = D.getfield(nd, "font")
    if fid then
        local f = font.getfont(fid)
        if f and f.size then return f.size end
    end
    return grid_height
end

--- 读「1 + 千分比」型属性，未设置时为 0
local function attr_permille(nd, attr)
    local v = D.get_attribute(nd, attr)
    if not v or v <= 1 then return 0 end
    return (v - 1) / 1000
end

--- 第 i 与第 i+1 个条目之间的字距 gap。
-- 标号组内部、标号两侧、块（墨围等）两侧都是固定间距，不参与调整；
-- 只有正文字距可调，且它在 clreq 挤压顺序里排在所有标点空白之后
-- （"inter_char"，见 shared/adjust.lua 的注释），拉伸时作为兜底均分对象。
-- @param locked (boolean) 该边界属于刚性单元内部
-- @param two_em (boolean) 该边界在两字幅标点单元（—— …… ？！）内部：
--   clreq 规定整个单元占两个汉字宽度，中间不能再夹字距，故归零
local function inter_gap_desc(entries, i, grid_height, locked, two_em)
    local e = entries[i]
    local nxt = entries[i + 1]
    local ch = e.cell_height or grid_height
    local cur_marker = D.get_attribute(e.node, constants.ATTR_FOOTNOTE_MARKER)
    local nxt_marker = D.get_attribute(nxt.node, constants.ATTR_FOOTNOTE_MARKER)
    local cur_in_group = cur_marker and cur_marker > 0
    local nxt_in_group = nxt_marker and nxt_marker > 0

    local w
    if cur_in_group and nxt_in_group then
        w = 0                                   -- 标号组内部：无间隙
    elseif cur_in_group then
        -- 标号 → 后文：后松。但后面若紧跟标点，标号与该标点同属依附前文的
        -- 收尾单元，仍按普通字距。
        local nxt_punct = D.get_attribute(nxt.node, constants.ATTR_PUNCT_TYPE)
        local base = get_node_font_size(e.node) or grid_height
        if nxt_punct and nxt_punct > 0 then
            w = math.floor(base * GAP_RATIO)
        else
            w = marker_gap_sp(base, "after")
        end
    elseif nxt_in_group then
        w = marker_gap_sp(get_node_font_size(nxt.node) or grid_height, "before")
    elseif e.is_block then
        w = math.floor(ch * GAP_RATIO)
    else
        local base = math.floor(ch * GAP_RATIO)
        if two_em then
            return { width = 0, min = 0, max = 0 }
        end
        -- 横置西文串内部：无字距且刚性（字母连排成词，不可拉开）
        if D.get_attribute(e.node, constants.ATTR_SIDEWAYS) == 1
            and D.get_attribute(nxt.node, constants.ATTR_SIDEWAYS) == 1 then
            return { width = 0, min = 0, max = 0 }
        end
        -- 中横排组内部：整组共占一格，无字距且刚性（组内横向排布由
        -- render 负责，列方向上组只有组首那一个字幅）
        local tcy = D.get_attribute(e.node, constants.ATTR_TCY)
        if tcy and tcy > 0
            and D.get_attribute(nxt.node, constants.ATTR_TCY) == tcy then
            return { width = 0, min = 0, max = 0 }
        end
        if locked then
            return { width = base, min = base, max = base }
        end
        -- 中西边界（clreq）：0.1em 基准字距整段升格为 1/4em 中西间距，
        -- 可挤至 1/8、拉至 1/2（不参与兜底均分——1/2 是硬上限）。
        -- em 取边界前字字号（混排字号通常一致）；flatten 只在 context
        -- 挡位打这个标记（shared/luatex-cn-cjk-western.lua 判定）。
        if D.get_attribute(nxt.node, constants.ATTR_CJK_WESTERN_PREV) == 1 then
            local em = get_node_font_size(e.node) or grid_height
            return { width = math.floor(em * 0.25),
                     min = math.floor(em * 0.125),
                     max = math.floor(em * 0.5),
                     shrink_class = "cjk_western",
                     stretch_class = "cjk_western" }
        end
        return { width = base, min = 0, max = base,
                 shrink_class = "inter_char", fallback = true }
    end
    return { width = w, min = w, max = w }
end

--- 把一列拆成求解器要的 gap 序列。
--
-- 模型（设计 §2.1）：标点字幅里的空白升格为 gap，cell 只留刚性墨迹部分。
-- 空白分两截——相邻标点规则**强制**收回的那截已经由 punct.flatten 扣进
-- cell_height（clreq 的连续标点缩减是硬性规定，不是弹性），剩下的那截才是
-- 弹性余量，列排不下时按 clreq 挤压优先顺序先收它、再动字距。
--
-- gap 顺序（N 个字）：
--   head_1, [tail_1, inter_1, head_2], …, [tail_{N-1}, inter_{N-1}, head_N], tail_N
-- 不合并同一边界上的三个 gap：它们的挤压类别不同（标点空白在 clreq 顺序的
-- 前列，字距是最后手段），合并会丢掉优先级。
--
-- @param entries (table) 列内条目（需已定好 cell_height）
-- @param grid_height (number) 正文网格字幅（sp），用作缺省字号
-- @return (table) {
--   gaps, rigid[i], rigid_total,
--   head_idx[i], tail_idx[i], inter_idx[i],
--   blank_head_sp[i], blank_total_sp[i]  -- 潜在空白（供还原字面位置）
-- }
local function build_column_gaps(entries, grid_height)
    local N = #entries
    local el_head, el_tail, rigid = {}, {}, {}
    local cls, rigid_prev, two_em_prev = {}, {}, {}
    local blank_head_sp, blank_total_sp = {}, {}
    local rigid_total = 0

    for i = 1, N do
        local e = entries[i]
        local nd = e.node
        local ch = e.cell_height or grid_height
        local em = node_em(nd, grid_height)
        local b_total = attr_permille(nd, constants.ATTR_PUNCT_BLANK)
        local b_head = attr_permille(nd, constants.ATTR_PUNCT_BLANK_HEAD)
        local m_total = attr_permille(nd, constants.ATTR_PUNCT_SQUEEZE)
        local m_head = attr_permille(nd, constants.ATTR_PUNCT_SQUEEZE_HEAD)
        local eh = math.max(0, b_head - m_head) * em
        local et = math.max(0, (b_total - b_head) - (m_total - m_head)) * em
        if eh + et > ch then
            -- 字幅被样式覆盖（style grid_height）等异常情形：不升格空白
            eh, et = 0, 0
        end
        -- 刚性墨迹尺寸必须在扣除硬性收回**之前**定下：收回的是空白，
        -- 不是墨迹，扣多少都不该让刚性部分变大（否则字面会被整体推走）
        rigid[i] = ch - eh - et
        -- clreq 行尾点号悬挂：列末点号整幅出列——墨迹与空白都不进列高
        -- 预算，字形挂在版口之外。与 TRIM_END（只收空白）的区别就在这个
        -- rigid 归零；两者叠加也无妨，都是把该字幅从预算里拿走。
        if i == N and D.get_attribute(nd, constants.ATTR_PUNCT_HANG) then
            rigid[i], eh, et = 0, 0, 0
        end
        rigid_total = rigid_total + rigid[i]
        -- 列首的开始夹注符号、列末的点号：clreq 规定的收回是硬性的，不是
        -- 弹性余量，落在这两个位置就直接从空白里扣掉（设计 §2.3）
        if i == 1 then
            eh = math.max(0, eh
                - attr_permille(nd, constants.ATTR_PUNCT_TRIM_START) * em)
        end
        if i == N then
            et = math.max(0, et
                - attr_permille(nd, constants.ATTR_PUNCT_TRIM_END) * em)
        end
        el_head[i], el_tail[i] = eh, et
        blank_head_sp[i] = b_head * em
        blank_total_sp[i] = b_total * em

        local ci = D.get_attribute(nd, constants.ATTR_PUNCT_SHRINK_CLASS)
        cls[i] = (ci and ci > 1) and adjust.SHRINK_ORDER[ci - 1] or nil
        local rp = D.get_attribute(nd, constants.ATTR_RIGID_PREV)
        rigid_prev[i] = (rp or 0) >= 1
        two_em_prev[i] = (rp == 2)
    end

    local gaps = {}
    local head_idx, tail_idx, inter_idx = {}, {}, {}
    local function push(g)
        gaps[#gaps + 1] = g
        return #gaps
    end
    -- 刚性单元内部：宽度锁死（横排的教训——只清 stretch 不清 shrink，
    -- 两字幅单元会被压扁）
    local function blank_gap(w, class, locked)
        return { width = w, min = locked and w or 0, max = w,
                 shrink_class = (not locked) and class or nil }
    end

    for i = 1, N do
        if i > 1 then
            local locked = rigid_prev[i]
            tail_idx[i - 1] = push(blank_gap(el_tail[i - 1], cls[i - 1], locked))
            inter_idx[i - 1] = push(inter_gap_desc(entries, i - 1, grid_height,
                locked, two_em_prev[i]))
        end
        head_idx[i] = push(blank_gap(el_head[i], cls[i],
            i > 1 and rigid_prev[i] or false))
    end
    -- 列末标点余下的空白是 clreq 挤压顺序的第 1 级（位于行末的标点），
    -- 优先于其余所有类别
    tail_idx[N] = push(blank_gap(el_tail[N],
        cls[N] and "line_end_punct" or nil, false))

    return {
        gaps = gaps, rigid = rigid, rigid_total = rigid_total,
        head_idx = head_idx, tail_idx = tail_idx, inter_idx = inter_idx,
        blank_head_sp = blank_head_sp, blank_total_sp = blank_total_sp,
    }
end

--- Calculate whether to squeeze or stretch for kinsoku resolution.
--
-- 只负责组装两个候选排布（挤进 = 多收一个字，推出 = 少一个字），代价比较
-- 交给共享层 kinsoku.resolve_overflow——它对两个候选各解一次 adjust.solve，
-- 因此看得见 clreq 的挤压优先顺序：收一个逗号的字面空白远比拉开字距便宜。
-- 后端自己按 gap 大小比价是看不到这一层的，会把求解器本来吃得下的列推出去。
--
-- @param col_buffer (table) Current column buffer (N chars)
-- @param t_node (direct node) The character about to be placed
-- @param ctx (table) Grid context
-- @param grid_height (number) Grid height in sp
-- @return (string) "squeeze" or "stretch"
local function calculate_kinsoku_action(col_buffer, t_node, ctx, grid_height)
    local N = #col_buffer
    if N < 2 then return "stretch" end

    local col_start_y = col_buffer[1].y_sp or 0
    local available = ctx.col_height_sp - col_start_y

    local squeeze_entries = {}
    for i = 1, N do squeeze_entries[i] = col_buffer[i] end
    squeeze_entries[N + 1] = {
        node = t_node,
        cell_height = resolve_cell_height(t_node, grid_height, nil,
            ctx.punct_config),
    }
    local sq = build_column_gaps(squeeze_entries, grid_height)

    local stretch_entries = {}
    for i = 1, N - 1 do stretch_entries[i] = col_buffer[i] end
    local st = build_column_gaps(stretch_entries, grid_height)

    local action, detail = kinsoku.resolve_overflow({
        squeeze = { target = available - sq.rigid_total, gaps = sq.gaps },
        stretch = { target = available - st.rigid_total, gaps = st.gaps },
    }, {
        -- 本后端的量纲是 sp，容差按字幅千分之一（≈0.014pt）显式给出：
        -- 差这么点的两个方案视觉完全一致，该落到 clreq 的「全等 → 先挤进」，
        -- 而不是由浮点舍入决定。共享层不知道量纲，只能自适应推导。
        tolerance = grid_height * 0.001,
    })

    dbg.log(string.format(
        "kinsoku cost: 字距形变 squeeze=%.1f stretch=%.1f sp，判于 %s (N=%d) → %s [p:%d c:%d]",
        detail.squeeze_gap, detail.stretch_gap, detail.decided_by or "全等/先挤进",
        N, action, ctx.cur_page, ctx.cur_col))

    return action
end

--- Check if a kinsoku violation would occur at column wrap point.
-- Called when should_wrap=true in natural mode.
-- @param t (direct node) Character about to be placed (would go to next column)
-- @param ctx (table) Grid context
-- @param col_buffer (table) Current column buffer
-- @param grid_height (number) Grid height in sp
-- @return (string|nil) "squeeze", "stretch", or nil (no violation)
local function check_natural_kinsoku(t, ctx, col_buffer, grid_height)
    if #col_buffer < 1 then return nil end
    if not ctx.punct_config or not ctx.punct_config.kinsoku then return nil end

    -- Case 1: t is line-start-forbidden (would start new column)
    local t_code = D.get_attribute(t, constants.ATTR_PUNCT_TYPE)
    if t_code and t_code > 0 and is_line_start_forbidden_code(t_code) then
        return calculate_kinsoku_action(col_buffer, t, ctx, grid_height)
    end

    -- Case 2: last buffer char is line-end-forbidden (would end current column)
    local last = col_buffer[#col_buffer]
    local last_code = D.get_attribute(last.node, constants.ATTR_PUNCT_TYPE)
    if last_code and last_code > 0 and is_line_end_forbidden_code(last_code) then
        return calculate_kinsoku_action(col_buffer, t, ctx, grid_height)
    end

    -- Case 3: t 与列尾字同属两字幅标点单元（—— …… ？！），断在中间就把
    -- 一个占两字幅的符号劈成两半（clreq 符号分离禁则）。挤进还是推出交给
    -- 同一套比价——推出时只推一个字，正好是本单元的前一半。
    if D.get_attribute(t, constants.ATTR_RIGID_PREV) == 2 then
        return calculate_kinsoku_action(col_buffer, t, ctx, grid_height)
    end

    return nil
end

_internal.is_line_start_forbidden_code = is_line_start_forbidden_code
_internal.is_line_end_forbidden_code = is_line_end_forbidden_code
_internal.build_column_gaps = build_column_gaps
_internal.calculate_kinsoku_action = calculate_kinsoku_action
_internal.check_natural_kinsoku = check_natural_kinsoku

--- Handle glyph node: decoration markers and regular characters
-- @param t (direct node) Current glyph node
-- @param ctx (table) Grid context
-- @param col_buffer (table) Column buffer
-- @param layout_map (table) Output layout map
-- @param grid_height (number) Grid height in sp
-- @param indent (number) Current indent
-- @param effective_limit (number) Effective line limit
-- @param distribute (boolean) Distribution mode flag
-- @param interval (number) Banxin interval
-- @param p_cols (number) Columns per page
-- @param params (table) Layout parameters (for hooks, free mode)
-- @param flush_fn (function) Buffer flush callback
local function handle_glyph_node(t, ctx, col_buffer, layout_map, grid_height,
                                  indent, effective_limit, distribute,
                                  interval, p_cols, params, flush_fn, base_indent)
    flush_textflow_pending(ctx, grid_height)
    local dec_id = D.get_attribute(t, constants.ATTR_DECORATE_ID)
    if dec_id and dec_id > 0 then
        -- Decorate Marker: position for the PREVIOUS character
        -- ISSUE #54 FIX: When column just wrapped (just_wrapped_column flag),
        -- use the previous character's position (last column's last row)
        local dec_page = ctx.cur_page
        local dec_col = ctx.cur_col
        local dec_y_sp = ctx.cur_y_sp
        local dec_band = ctx.cur_band

        if ctx.just_wrapped_column and ctx.last_char_row then
            -- Column just wrapped - use previous character's position
            dec_page = ctx.last_char_page or ctx.cur_page
            dec_col = ctx.last_char_col or ctx.cur_col
            dec_y_sp = (ctx.last_char_y_sp or 0) + (ctx.last_char_cell_height or grid_height)
            dec_band = ctx.last_char_band or ctx.cur_band
        end

        local dec_band_y_off = ctx.band_y_offsets_sp[dec_band] or 0
        local map_entry = {
            page = dec_page,
            col = dec_col,
            band = dec_band,
            y_sp = dec_y_sp,
            band_y_offset_sp = dec_band_y_off,
            cell_height = ctx.last_char_cell_height or grid_height,
            -- P2: absolute coordinates
            x = h.compute_x(dec_col, dec_page, ctx),
            y = h.compute_y(dec_y_sp, dec_band_y_off, ctx),
        }

        apply_style_attrs(map_entry, t)

        layout_map[t] = map_entry
        -- DO NOT increment cur_row - marker is zero-width overlay
    else
        -- Detect line change and clear temporary indents
        if ctx.cur_row ~= ctx.last_glyph_row then
            style_registry.pop_temporary()
            ctx.last_glyph_row = ctx.cur_row
        end

        -- Unified layout: resolve cell height and gap
        local cell_h = resolve_cell_height(t, grid_height, ctx.default_cell_height, ctx.punct_config)
        local cell_w = resolve_cell_width(t, ctx.default_cell_width)
        -- Natural mode: 0.1em gap (proportional to font size); grid mode: 0
        local gap = ctx.default_cell_height and 0 or math.floor(cell_h * GAP_RATIO)

        -- 中横排（\中横排）：整组共占一个字幅——组首按普通字幅入格，组内
        -- 其余字形字幅与字距归零（列方向不再前进，横向排布由 render 负责）。
        -- 组员因此永远不会触发换列，整组天然不可拆。组号递增，靠「与上一个
        -- 字形同号」识别组内续字（相邻两组不会误并）。
        local tcy = D.get_attribute(t, constants.ATTR_TCY)
        tcy = (tcy and tcy > 0) and tcy or nil
        if tcy and ctx.prev_tcy_group == tcy then
            cell_h = 0
            gap = 0
        end
        ctx.prev_tcy_group = tcy

        -- Column overflow check (sp-based)
        -- Natural mode: use actual accumulated height from buffer instead of cur_y_sp
        -- Grid mode: use cur_y_sp (which is synchronized with cur_row * grid_height)
        -- In table mode, column transitions are controlled by CELL_BREAK/BAND_BREAK only
        local should_wrap = false
        if not distribute and ctx.auto_column_wrap and ctx.cur_y_sp > 0
                and ctx.table_start_col == nil then
            if ctx.default_cell_height then
                -- Grid mode: use cur_y_sp (synchronized with grid)
                should_wrap = (ctx.cur_y_sp + cell_h > ctx.col_height_sp)
            else
                -- Natural mode: calculate actual height from buffer
                local col_start_y = #col_buffer > 0 and col_buffer[1].y_sp or 0
                local buffer_height = calculate_buffer_height(col_buffer)
                local next_y = col_start_y + buffer_height + cell_h
                -- Add the boundary gap for the character we're about to add
                -- （两字幅单元 0 / 中西边界 1/4em / 其余 0.1em，
                --   同 calculate_buffer_height）
                if #col_buffer > 0 then
                    local prev = col_buffer[#col_buffer]
                    next_y = next_y
                        + est_inter_gap_sp(prev.node, prev.cell_height or 0, t)
                end
                should_wrap = (next_y > ctx.col_height_sp)
            end
        end

        -- Natural mode kinsoku check (before flush)
        if should_wrap and not ctx.default_cell_height then
            local kinsoku_action = check_natural_kinsoku(t, ctx, col_buffer, grid_height)
            if kinsoku_action == "squeeze" then
                should_wrap = false
                dbg.log(string.format(
                    "natural kinsoku: SQUEEZE (char 0x%04X) [p:%d c:%d]",
                    D.getfield(t, "char") or 0, ctx.cur_page, ctx.cur_col))
            elseif kinsoku_action == "stretch" then
                local pulled_list = { table.remove(col_buffer) }
                -- 中横排组是一个整体：被拉走的若是组尾，整组一并同行
                local pv = D.get_attribute(pulled_list[1].node,
                    constants.ATTR_TCY)
                if pv and pv > 0 then
                    while #col_buffer > 0
                        and D.get_attribute(col_buffer[#col_buffer].node,
                            constants.ATTR_TCY) == pv do
                        table.insert(pulled_list, 1, table.remove(col_buffer))
                    end
                end
                flush_fn("wrap")
                accumulate_free_mode_col_width(ctx, params)
                wrap_to_next_column(ctx, p_cols, interval, grid_height, base_indent or indent, false, false)
                apply_indentation(ctx, base_indent or indent)
                for _, pulled in ipairs(pulled_list) do
                    table.insert(col_buffer, {
                        node = pulled.node,
                        page = ctx.cur_page,
                        col = ctx.cur_col,
                        band = ctx.cur_band,
                        y_sp = ctx.cur_y_sp,
                        height = pulled.height,
                        cell_height = pulled.cell_height,
                        cell_width = pulled.cell_width,
                    })
                    local ph = pulled.cell_height or grid_height
                    ctx.cur_y_sp = ctx.cur_y_sp + ph + math.floor(ph * GAP_RATIO)
                end
                ctx.cur_row = math.floor(ctx.cur_y_sp / grid_height + 0.5)
                ctx.page_has_content = true
                should_wrap = false
                dbg.log(string.format(
                    "natural kinsoku: STRETCH (char 0x%04X) [p:%d c:%d]",
                    D.getfield(t, "char") or 0, ctx.cur_page, ctx.cur_col))
            end
        end

        if should_wrap then
            flush_fn("wrap")
            accumulate_free_mode_col_width(ctx, params)
            wrap_to_next_column(ctx, p_cols, interval, grid_height, base_indent or indent, false, false)
            apply_indentation(ctx, base_indent or indent)
        end

        -- Apply per-column style padding override on first glyph of a new column.
        -- Band format padding is applied eagerly at column/band start (see apply_band_padding).
        -- Style-level padding overrides band padding when set on the first glyph.
        -- Both band padding and style padding are absolute offsets from column/band top.
        if not ctx.col_padding_applied then
            ctx.col_padding_applied = true
            local style_id = D.get_attribute(t, constants.ATTR_STYLE_REG_ID)
            local style_pt = style_id and style_registry.get_padding_top(style_id)
            if style_pt then
                if ctx.col_band_padding_applied then
                    -- Band padding was already applied; replace with style padding
                    local band_val = ctx.col_band_padding_value or 0
                    local adjust = style_pt - band_val
                    if adjust ~= 0 then
                        ctx.cur_y_sp = ctx.cur_y_sp + adjust
                    end
                else
                    -- No band padding; apply style padding directly
                    if style_pt ~= 0 then
                        ctx.cur_y_sp = ctx.cur_y_sp + style_pt
                    end
                end
            end
        end

        table.insert(col_buffer, {
            node = t,
            page = ctx.cur_page,
            col = ctx.cur_col,
            band = ctx.cur_band,
            y_sp = ctx.cur_y_sp,
            height = (D.getfield(t, "height") or 0) + (D.getfield(t, "depth") or 0),
            cell_height = cell_h,
            cell_width = cell_w,
        })

        -- Track last character position for decoration markers.
        -- MUST be done AFTER column wrap decision so last_char_* reflects
        -- the character's actual position (which may be in a new column).
        ctx.last_char_page = ctx.cur_page
        ctx.last_char_col = ctx.cur_col
        ctx.last_char_band = ctx.cur_band
        ctx.last_char_row = ctx.cur_row
        ctx.last_char_y_sp = ctx.cur_y_sp
        ctx.last_char_cell_height = cell_h
        -- Clear wrapped flag: character has been placed in its final column.
        ctx.just_wrapped_column = false

        ctx.cur_y_sp = ctx.cur_y_sp + cell_h + gap
        ctx.cur_row = math.floor(ctx.cur_y_sp / grid_height + 0.5)
        ctx.page_has_content = true

        -- Kinsoku (line-breaking rules) hook:
        -- gap==0 implies grid mode (natural mode has gap>0), so no mode guard needed
        if gap == 0 and not distribute and params and params.hooks
            and params.hooks.check_kinsoku then
            params.hooks.check_kinsoku(
                t, ctx, effective_limit, col_buffer,
                flush_fn, wrap_to_next_column,
                p_cols, interval, grid_height, indent)
        end

        -- Skip banxin columns, center gap, and occupied cells
        -- In natural mode (n_column=0): all checks are no-op
        move_to_next_valid_position(ctx, interval, grid_height, indent)
    end
end

--- Flush column buffer: finalize positions and write to layout_map
-- @param col_buffer (table) Buffer of entries for current column
-- @param ctx (table) Grid context
-- @param grid_height (number) Grid height in sp
-- @param distribute (boolean) Whether to distribute nodes evenly
-- @param layout_map (table) Output layout map (node → position)
-- @param reason (string|nil) 这次落盘的成因："wrap" = 写满换列（该列均排到
--   列底），其余（段落结束、强制换列/换页、缓冲收尾）一律按自然长度排——
--   clreq：正文末行不均排。缺省视作 "end"。
local function flush_buffer(col_buffer, ctx, grid_height, distribute, layout_map, reason)
    if #col_buffer == 0 then return end

    local N = #col_buffer
    local H = ctx.line_limit -- Default to integer grid cells

    -- Column start offset: first entry's y_sp may include indent from
    -- apply_indentation (e.g., footnote indent=1). All recalculation
    -- paths must preserve this offset instead of starting from 0.
    local col_start_y = col_buffer[1].y_sp or 0

    -- If absolute height is provided and we are in distribution mode,
    -- use the actual dimension to calculate distribution.
    -- Deduct padding_top/bottom (box-level inset, not inherited).
    local fill_pad_top = 0
    local fill_pad_bottom = 0
    if distribute and ctx.params.absolute_height and ctx.params.absolute_height > 0 then
        local constants_mod = package.loaded['core.luatex-cn-constants'] or
            require('core.luatex-cn-constants')
        if ctx.params.padding_top then
            fill_pad_top = constants_mod.to_dimen(ctx.params.padding_top) or 0
        end
        if ctx.params.padding_bottom then
            fill_pad_bottom = constants_mod.to_dimen(ctx.params.padding_bottom) or 0
        end
        local dist_height = ctx.params.absolute_height - fill_pad_top - fill_pad_bottom
        H = dist_height / grid_height
    end

    local v_scale_all = 1.0
    local distribute_y_sp = {}

    if distribute and N > 1 then
        local total_char_height = 0
        for _, entry in ipairs(col_buffer) do
            local ch = entry.cell_height or entry.height or grid_height
            if ch <= 0 then ch = grid_height end
            total_char_height = total_char_height + ch
        end

        local H_sp = H * grid_height
        -- Start distributing from col_start_y (not fill_pad_top).
        -- shift_y already includes c_padding_top, so adding fill_pad_top here
        -- would double-apply the top padding.
        local dist_start_y = col_start_y
        local available_sp = H_sp - dist_start_y
        if total_char_height > available_sp then
            -- Squeeze mode
            v_scale_all = available_sp / total_char_height
            local current_y = dist_start_y
            for i = 1, N do
                local entry = col_buffer[i]
                local ch = entry.cell_height or entry.height or grid_height
                if ch <= 0 then ch = grid_height end
                ch = ch * v_scale_all
                local y_center = current_y + ch / 2
                distribute_y_sp[i] = y_center - grid_height * 0.5
                current_y = current_y + ch
            end
        else
            -- Distribute mode (No enlargement)
            v_scale_all = 1.0
            local gap = (available_sp - total_char_height) / (N - 1)
            local current_y = dist_start_y
            for i = 1, N do
                local entry = col_buffer[i]
                local ch = entry.cell_height or entry.height or grid_height
                if ch <= 0 then ch = grid_height end
                local y_center = current_y + ch / 2
                distribute_y_sp[i] = y_center - grid_height * 0.5
                current_y = current_y + ch + gap
            end
        end
    end

    -- Natural mode (no default_cell_height): recalculate positions.
    -- Natural mode gap strategy (0.1em proportional gap):
    --   1. Base gap = 0.1 * cell_height per character (proportional to font size)
    --   2. If column is nearly full (remaining < 1 char), stretch stretchable gaps
    --      so total height = col_height_sp (bottom-aligned with full columns)
    --   Stretchable gaps: only between regular text glyphs (not marker groups, not blocks)
    if not ctx.default_cell_height and N > 0 and not distribute then
        -- Pre-pass: set marker group cell_heights so gap calculation uses correct sizes.
        -- Without this, each marker char counts as grid_height in total_cells,
        -- but the actual marker group height is much smaller (marker_height * fn_size).
        do
            local i = 1
            while i <= N do
                local mv = D.get_attribute(col_buffer[i].node, constants.ATTR_FOOTNOTE_MARKER)
                if mv and mv > 0 then
                    local gs, ge = i, i
                    while ge + 1 <= N do
                        local nv = D.get_attribute(col_buffer[ge + 1].node, constants.ATTR_FOOTNOTE_MARKER)
                        if nv == mv then ge = ge + 1 else break end
                    end
                    local glen = ge - gs + 1
                    if glen >= 3 then
                        local total_h = mv
                        local bracket_h = math.floor(total_h * 0.125)
                        local middle_total = total_h - 2 * bracket_h
                        local n_middle = glen - 2
                        local middle_h = math.floor(middle_total / n_middle)
                        -- 可读性下限：位数多时（【二百五十四】共 5 个数字）
                        -- 按声明高度均分会把每个数字压到三分之一字幅以下，
                        -- 成为无法辨认的横条。低于下限时让标号按需增高——
                        -- 一两位数的常见情形仍是声明的高度，脚注缩进按
                        -- marker-height 对齐的约定不受影响。
                        local own_h = get_node_font_size(col_buffer[gs + 1].node)
                            or grid_height
                        local min_middle_h = math.floor(own_h * MARKER_MIN_SCALE)
                        if middle_h < min_middle_h then
                            middle_h = min_middle_h
                        end
                        col_buffer[gs].cell_height = bracket_h
                        for j = gs + 1, ge - 1 do
                            col_buffer[j].cell_height = middle_h
                        end
                        col_buffer[ge].cell_height = bracket_h
                    end
                    i = ge + 1
                else
                    i = i + 1
                end
            end
        end

        -- clreq 行内调整：组装 gap 序列后交给共享层求解（设计 §2–§4）。
        -- 旧的三分支经验策略（平均压缩 / 平均拉伸 / 一律 0.1em）没有优先级，
        -- 把逗号空白、夹注符号空白、中西间距、字距一视同仁；求解器按 clreq
        -- 的七级挤压 / 二级拉伸 + 兜底均分处理。
        local col = build_column_gaps(col_buffer, grid_height)
        local available = ctx.col_height_sp - col_start_y
        local target = available - col.rigid_total
        local natural = 0
        for _, g in ipairs(col.gaps) do natural = natural + g.width end

        -- 均排的两个条件缺一不可：
        --   ① 这一列是写满后换列的——段末列、强制换列/换页收尾的列不均排
        --      （clreq：正文末行不均排）；
        --   ② 剩余量不足一个字幅——列尾被夹注、标号组这类整块元素挡住而空出
        --      一大截时硬拉到列底会把字距拉散，宁可参差。
        -- 超长的列不论成因都要压缩，否则溢出版口。
        local justify = (reason == "wrap")
            and (target - natural) < grid_height + math.floor(grid_height * GAP_RATIO)
        local widths
        if N > 1 and (natural > target or justify) then
            local r = adjust.solve(target, col.gaps)
            widths = r.widths
            if r.deficit > 0 then
                dbg.log(string.format(
                    "column adjust: 全部触底仍超长 %d sp (N=%d) [p:%d c:%d]",
                    math.floor(r.deficit), N, ctx.cur_page, ctx.cur_col))
            end
        end
        local function gw(idx)
            return widths and widths[idx] or col.gaps[idx].width
        end

        local y = col_start_y
        for i, e in ipairs(col_buffer) do
            local hw = gw(col.head_idx[i])
            local tw = gw(col.tail_idx[i])
            e.y_sp = y
            e.cell_height = hw + col.rigid[i] + tw
            -- 字面还原量随 entry 下发：收回量现在由求解器决定，不再是每字一个
            -- 常量，render 只读不算（设计 §4）
            if col.blank_total_sp[i] > 0 then
                e.punct_squeeze_sp = col.blank_total_sp[i] - hw - tw
                e.punct_head_sp = col.blank_head_sp[i] - hw
            end
            y = y + e.cell_height
            if i < N then y = y + gw(col.inter_idx[i]) end
        end
    end

    -- Redistribute footnote marker y_sp and v_scale.
    -- cell_height was already set in the pre-pass above; here we only fix y_sp
    -- (which was computed using the correct cell_heights) and set v_scale for
    -- multi-char middle glyphs that need to be squeezed.
    do
        local i = 1
        while i <= N do
            local mv = D.get_attribute(col_buffer[i].node, constants.ATTR_FOOTNOTE_MARKER)
            if mv and mv > 0 then
                local gs, ge = i, i
                while ge + 1 <= N do
                    local nv = D.get_attribute(col_buffer[ge + 1].node, constants.ATTR_FOOTNOTE_MARKER)
                    if nv == mv then ge = ge + 1 else break end
                end
                local glen = ge - gs + 1
                if glen >= 3 then
                    -- 每个字形按**真实墨迹**缩到分给它的格子里。以前只缩
                    -- 中间字、且拿正文网格 grid_height 当参照系：括号从不
                    -- 缩放，格子只有 12.5% 字幅而字形按原大绘制，墨迹侵入
                    -- 相邻数字的格子——【一百】的「百」压进「︼」正是这么
                    -- 来的；中间字的参照系也错（应为该字自身尺寸）。
                    -- 墨迹本就装得下的（如单字标号）保持原大，只缩装不下的。
                    --
                    -- 墨迹必须取 boundingbox：height/depth 会把基线到墨迹
                    -- 之间的空白算进去（︼ 的 depth 为 0、height 却是 0.668，
                    -- 而墨迹只有 0.368），照它缩会让 ︻ ︼ 一大一小。
                    local ink_shift = {}
                    for j = gs, ge do
                        local e = col_buffer[j]
                        local fid = D.getfont(e.node)
                        local fdata = fid and font.getfont(fid)
                        local fs = get_node_font_size(e.node)
                            or (fdata and fdata.size) or grid_height
                        local top, bot = h.glyph_ink_span(e.node)
                        local ink = (top - bot) * fs
                        local cell = e.cell_height
                        if ink > 0 and cell and cell > 0 and cell < ink then
                            e.v_scale = cell / ink
                        end
                        -- 括号是标点，渲染按 height/depth 盒居中而不是按墨迹；
                        -- 两个中心差多少就补多少，否则 ︻ ︼ 一高一低。
                        local ptype = D.get_attribute(e.node, constants.ATTR_PUNCT_TYPE)
                        if ptype and ptype > 0 then
                            local box_center = ((D.getfield(e.node, "height") or 0)
                                - (D.getfield(e.node, "depth") or 0)) / 2
                            local ink_center = (top + bot) / 2 * fs
                            ink_shift[j] = (ink_center - box_center) * (e.v_scale or 1)
                        end
                    end
                    -- Fix y_sp: redistribute within group using pre-set cell_heights，
                    -- 再叠加各自的墨迹居中补偿
                    local sy = col_buffer[gs].y_sp
                    local y = sy
                    for j = gs, ge do
                        col_buffer[j].y_sp = y + (ink_shift[j] or 0)
                        y = y + col_buffer[j].cell_height
                    end
                end
                i = ge + 1
            else
                i = i + 1
            end
        end
    end

    for i, entry in ipairs(col_buffer) do
        local y_sp = distribute_y_sp[i] or entry.y_sp
        local v_scale = entry.v_scale or ((distribute and N > 1) and v_scale_all or 1.0)

        local fl_band = entry.band or 0
        local fl_band_y_off = ctx.band_y_offsets_sp[fl_band] or 0
        local map_entry = {
            page = entry.page,
            col = entry.col,
            band = fl_band,
            y_sp = y_sp,
            band_y_offset_sp = fl_band_y_off,
            is_block = entry.is_block,
            width = entry.width,
            height = entry.height,
            v_scale = v_scale,
            cell_height = entry.cell_height,
            cell_width = entry.cell_width,
            -- 标点字面还原量（sp）：自然模式下由行内调整求解器决定，
            -- render 按它把字面放回原位（设计 §4）
            punct_squeeze_sp = entry.punct_squeeze_sp,
            punct_head_sp = entry.punct_head_sp,
            -- P2: absolute coordinates
            x = h.compute_x(entry.col, entry.page, ctx),
            y = h.compute_y(y_sp, fl_band_y_off, ctx),
        }
        apply_style_attrs(map_entry, entry.node)

        -- Check for line mark attribute (专名号/书名号)
        local lm_id = D.get_attribute(entry.node, constants.ATTR_LINE_MARK_ID)
        if lm_id and lm_id > 0 then
            map_entry.line_mark_id = lm_id
        end

        layout_map[entry.node] = map_entry

        -- Track nodes for cell vertical-align post-processing
        if ctx.cell_valign_nodes then
            ctx.cell_valign_nodes[#ctx.cell_valign_nodes + 1] = entry.node
        end
        -- Track nodes for deferred (pending) cell valign
        if ctx.pending_cell_valign_nodes then
            ctx.pending_cell_valign_nodes[#ctx.pending_cell_valign_nodes + 1] = entry.node
        end
    end

    -- Apply deferred cell valign if pending nodes were collected
    if ctx.pending_cell_valign and ctx.pending_cell_valign_nodes and #ctx.pending_cell_valign_nodes > 0 then
        apply_cell_valign_impl(
            ctx.pending_cell_valign,
            ctx.pending_cell_valign_nodes,
            ctx.pending_cell_valign_band_height,
            layout_map)
        ctx.pending_cell_valign = nil
        ctx.pending_cell_valign_nodes = nil
        ctx.pending_cell_valign_band_height = nil
    end

    -- Clear buffer in-place to preserve reference for external hooks (kinsoku)
    for i = #col_buffer, 1, -1 do
        col_buffer[i] = nil
    end
end

-- @param page_columns (number) Total columns before a page break
-- @param params (table) Optional parameters:
--   - distribute (boolean) If true, distribute nodes evenly in columns
-- @return (table, number, table, table) layout_map, total_pages, page_chapter_titles, banxin_registry
local function calculate_grid_positions(head, grid_height, line_limit, n_column, page_columns, params)
    local d_head = D.todirect(head)
    params = params or {}
    params.grid_height = params.grid_height or grid_height -- Store for ctx.params access
    local distribute = params.distribute

    if line_limit < 1 then line_limit = 20 end

    local interval = tonumber(n_column) or 0
    local p_cols
    local is_free_mode = (interval == 0 and not page_columns)

    if page_columns and tonumber(page_columns) then
        -- Explicit page-columns specified
        p_cols = tonumber(page_columns)
    elseif interval > 0 then
        -- Grid mode: use interval-based calculation
        p_cols = 2 * interval + 1
    else
        -- Free mode (n-column = 0, no page-columns):
        -- Don't pre-calculate columns, use large value and check space dynamically
        p_cols = 10000 -- Large value, actual wrap decided by available width
    end

    if p_cols <= 0 then p_cols = 10000 end -- Safety

    -- Debug: Log floating textbox parameters
    if params.floating then
        dbg.log(string.format("Floating textbox detected: floating_x=%.1fpt, paper_width=%.1fpt",
            (params.floating_x or 0) / 65536, (params.paper_width or 0) / 65536))
    end

    -- Stateful cursor layout
    local ctx = create_grid_context(params, line_limit, p_cols)
    ctx.banxin_registry = {} -- Track Banxin columns per page
    ctx.is_free_mode = is_free_mode
    -- P2: Store column geometry in ctx for compute_x (RTL coordinate calculation)
    ctx.col_interval = interval
    ctx.col_banxin_width = _G.content and _G.content.banxin_width or (params.grid_width or 0)

    -- In free mode, use content_width from three-layer architecture for page wrap
    if is_free_mode then
        ctx.content_width = params.content_width  -- 0 set at layout_params definition
        dbg.log(string.format("[Free Mode] Enabled, p_cols=%d (virtual), content_width=%.1fpt", p_cols, ctx.content_width / 65536))
    else
        ctx.content_width = 0
    end

    local layout_map = {}
    ctx.layout_map = layout_map

    -- Buffer for distribution mode
    local col_buffer = {}

    -- Initial skip
    move_to_next_valid_position(ctx, interval, grid_height, 0)

    -- Block tracking for First Indent
    local block_start_cols = {} -- map[block_id] -> {page=p, col=c}

    -- reason 见 flush_buffer：只有写满换列的列才均排到列底，其余按自然长度
    local function do_flush(reason)
        flush_buffer(col_buffer, ctx, grid_height, distribute, layout_map, reason)
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
                ctx.page_resets[ctx.cur_page] = true
            end
        end

        ::start_of_loop::
        local id = D.getid(t)


        if id == constants.WHATSIT then
            -- Position transparently at current cursor
            local wh_band_y_off = ctx.band_y_offsets_sp[ctx.cur_band] or 0
            local map_entry = {
                page = ctx.cur_page,
                col = ctx.cur_col,
                band = ctx.cur_band,
                y_sp = ctx.cur_y_sp,
                band_y_offset_sp = wh_band_y_off,
                -- P2: absolute coordinates
                x = h.compute_x(ctx.cur_col, ctx.cur_page, ctx),
                y = h.compute_y(ctx.cur_y_sp, wh_band_y_off, ctx),
            }
            apply_style_attrs(map_entry, t)

            -- Floating textbox anchors carry visible content for the page;
            -- mark page_has_content so a following \newpage isn't dropped as redundant.
            if D.getfield(t, "user_id") == constants.FLOATING_TEXTBOX_USER_ID then
                ctx.page_has_content = true
            end

            layout_map[t] = map_entry
            t = D.getnext(t)
            if not t then break end
            goto start_of_loop
        end

        if node_count < 200 then
            dbg.log(string.format("  Node=%s ID=%d [p:%d, c:%d, r:%.1f]", tostring(t), id, ctx.cur_page,
                ctx.cur_col, ctx.cur_row))
        end
        node_count = node_count + 1

        -- Resolve indent, textbox dimensions, and effective column height
        local indent, r_indent, effective_limit, effective_col_height_sp, tb_w, tb_h,
              base_indent, first_indent, block_id =
            resolve_node_indent(t, id, ctx, block_start_cols, grid_height, line_limit)


        -- Check wrapping BEFORE placing (unified: sp-based)
        -- In distribution mode, we allow overflow so we can squeeze characters later
        -- When auto_column_wrap is false, only explicit penalties cause column breaks
        -- Skip auto-wrap for jiazhu (textflow) nodes: they manage column transitions
        -- via their own callbacks.wrap(). Without this check, body text filling
        -- exactly one column would trigger a premature wrap here, creating an
        -- empty column before jiazhu content.
        -- Also skip when the current non-content node (GLUE/KERN/PENALTY) is immediately
        -- followed by a textflow node — the intermediate spacing should not cause a wrap.
        local is_textflow_node = D.get_attribute(t, constants.ATTR_JIAZHU) == 1
            and not (tb_w > 0 and tb_h > 0)
        local next_is_textflow = false
        if not is_textflow_node and id ~= constants.GLYPH then
            -- Lookahead: skip non-content nodes to find the next content node
            local lookahead = D.getnext(t)
            while lookahead do
                local la_id = D.getid(lookahead)
                if la_id == constants.GLYPH or la_id == constants.HLIST or la_id == constants.VLIST then
                    -- Found a content node — check if it's textflow
                    if D.get_attribute(lookahead, constants.ATTR_JIAZHU) == 1 then
                        next_is_textflow = true
                    end
                    break
                elseif la_id == constants.GLUE or la_id == constants.KERN
                        or la_id == constants.PENALTY or la_id == constants.WHATSIT then
                    lookahead = D.getnext(lookahead)
                else
                    break
                end
            end
        end
        -- Pre-node column wrap check: use actual buffer height in natural mode
        -- In table mode, column transitions are controlled by CELL_BREAK/BAND_BREAK only
        local in_table = ctx.table_start_col ~= nil
        local should_wrap_before_node = false
        if ctx.auto_column_wrap and not distribute and not is_textflow_node and not next_is_textflow and not in_table then
            if ctx.default_cell_height then
                -- Grid mode: use cur_y_sp
                should_wrap_before_node = (ctx.cur_y_sp >= effective_col_height_sp)
            else
                -- Natural mode: use actual buffer height
                if #col_buffer > 0 then
                    local col_start_y = col_buffer[1].y_sp or 0
                    local buffer_height = calculate_buffer_height(col_buffer)
                    local total_height = col_start_y + buffer_height
                    should_wrap_before_node = (total_height >= effective_col_height_sp)
                end
            end
        end

        -- Natural mode kinsoku at pre-node wrap: if the upcoming glyph would
        -- cause a kinsoku violation when placed at the start of a new column,
        -- suppress the pre-node wrap and let handle_glyph_node's kinsoku logic
        -- resolve it (squeeze the current column or stretch by pulling a char).
        if should_wrap_before_node and not ctx.default_cell_height
                and id == constants.GLYPH then
            local kinsoku_action = check_natural_kinsoku(t, ctx, col_buffer, grid_height)
            if kinsoku_action then
                should_wrap_before_node = false
            end
        end

        if should_wrap_before_node then
            do_flush("wrap")
            accumulate_free_mode_col_width(ctx, params)
            wrap_to_next_column(ctx, p_cols, interval, grid_height, base_indent, true, false)
            -- After column wrap, fully re-resolve indent: the column change may
            -- invalidate taitou scope (\平抬/\抬头 only affects one column),
            -- and first_indent only applies to the block's starting column.
            indent, r_indent, effective_limit, effective_col_height_sp, tb_w, tb_h,
                base_indent, first_indent, block_id =
                resolve_node_indent(t, id, ctx, block_start_cols, grid_height, line_limit)
            indent = get_indent_for_current_pos(ctx, block_start_cols, block_id, base_indent, first_indent)
        end

        -- Skip apply_indentation for textflow nodes with forced indent:
        -- textflow handles forced indent (from \缩进[N]) internally via
        -- base_y_sp = ni_indent_val * gh. Applying it here would advance
        -- ctx.cur_row, causing the left sub-column to inherit the right's indent.
        -- Normal indent (from style stack, e.g., \段落[indent=2]) must still
        -- be applied so ctx.cur_row is set correctly for textflow layout.
        --
        -- However, when \缩进[N] is at the line level (before regular text + textflow),
        -- the suojin forced indent attribute leaks to textflow nodes. If cur_column_indent
        -- already equals the forced indent value, it means apply_indentation was
        -- already called for preceding regular text — clear the forced indent so
        -- textflow continues from ctx.cur_row instead of jumping back.
        -- IMPORTANT: Only clear suojin-encoded indents (\缩进[N]).
        -- Taitou-encoded indents (\平抬/\单抬/\相对抬头) must be passed through
        -- to textflow intact, as they represent intentional forced positioning.
        if is_textflow_node then
            local tf_indent_attr = D.get_attribute(t, constants.ATTR_INDENT)
            local tf_is_suojin, tf_indent_val = constants.is_suojin_indent(tf_indent_attr)
            if tf_is_suojin then
                if (ctx.cur_column_indent or 0) == tf_indent_val then
                    -- Suojin forced indent already consumed by preceding regular text;
                    -- clear it so textflow uses ctx.cur_row as base position.
                    D.set_attribute(t, constants.ATTR_INDENT, 0)
                end
            else
                apply_indentation(ctx, indent)
            end
        else
            apply_indentation(ctx, indent)
        end

        -- Check for Column (单列排版) first
        local is_column = D.get_attribute(t, constants.ATTR_COLUMN) == 1
        if is_column then
            local column_mod = package.loaded['core.luatex-cn-core-column'] or
                require('core.luatex-cn-core-column')

            -- Get align mode to check for LastColumn (align >= 4)
            local align_mode = D.get_attribute(t, constants.ATTR_COLUMN_ALIGN) or 0
            local is_last_column = align_mode >= 4

            -- Column always starts on a new column
            do_flush()
            -- In grid mode or if current column has content, wrap to next column
            -- In free mode with space available, allow columns side-by-side
            -- Use cur_column_indent as threshold: if cur_row only advanced due to
            -- apply_indentation (not actual content), don't wrap.
            local should_wrap_before_column = false
            local col_indent_threshold = math.max(ctx.cur_column_indent or 0, 0)
            if ctx.cur_row > col_indent_threshold then
                if not ctx.is_free_mode then
                    -- Grid mode: always wrap
                    should_wrap_before_column = true
                else
                    -- Free mode: accumulate current column width, then use
                    -- wrap_to_next_column for proper page wrap checking
                    local g_w = get_grid_width(params, grid_height)
                    ctx.accumulated_width_sp = ctx.accumulated_width_sp + g_w
                    should_wrap_before_column = true
                end
            end
            if should_wrap_before_column then
                wrap_to_next_column(ctx, p_cols, interval, grid_height, 0, true, false)
            end

            -- For LastColumn, jump to the last column of current half-page
            if is_last_column then
                if ctx.is_free_mode then
                    texio.write_nl("luatex-cn warning: \\末行 (LastColumn) is not supported in Free Mode (n-column=0). Ignored.")
                else
                    -- Calculate last column before banxin (or page end)
                    local last_col = column_mod.find_last_column_in_half_page(
                        ctx.cur_col, p_cols, interval, get_banxin_on(params))
                    if last_col > ctx.cur_col then
                        ctx.cur_col = last_col
                        ctx.cur_row = 0
                        ctx.cur_y_sp = 0
                    end
                end
            end

            local column_params = {
                line_limit = line_limit,
                grid_height = grid_height,
                p_cols = p_cols,
                interval = interval,
                indent = indent,
            }
            local column_callbacks = {
                flush = do_flush,
                wrap = function()
                    if ctx.is_free_mode then
                        -- Free mode: don't wrap, just move to next column position
                        ctx.cur_col = ctx.cur_col + 1
                        ctx.cur_row = 0
                        ctx.cur_y_sp = 0
                    else
                        -- Grid mode: normal wrap (may trigger page break)
                        wrap_to_next_column(ctx, p_cols, interval, grid_height, 0, true, false)
                    end
                end,
                debug = function(msg) dbg.log(msg) end
            }

            -- In free mode, track column width for page wrap decision
            local col_start_col = ctx.cur_col
            local col_start_page = ctx.cur_page
            local col_start_node = t  -- Save Column's first node for style lookup

            t = column_mod.place_nodes(ctx, t, layout_map, column_params, column_callbacks)

            if not t then break end

            -- Record column width in col_widths_sp for compute_x.
            -- Free Mode: always record (explicit width or estimated from grid).
            -- Non-Free Mode: only record when explicit column_width is set (\行[width=...]).
            do
                local style_reg = require('util.luatex-cn-style-registry')
                local style_id = D.get_attribute(col_start_node, constants.ATTR_STYLE_REG_ID)
                local col_width_val = style_id and style_reg.get_attr(style_id, "column_width")
                local col_width_sp = (type(col_width_val) == "number" and col_width_val > 0) and col_width_val or nil

                -- cols_used may be negative when place_nodes triggers page wrap
                -- (last column fills the page, advancing cur_col to 0 on next page).
                -- For explicit column_width, always record regardless of cols_used.
                local cols_used = ctx.cur_col - col_start_col
                if cols_used <= 0 and ctx.cur_page > col_start_page then
                    -- Column placed on col_start_page, but cursor wrapped to next page.
                    -- The column was valid (1 column used on start page).
                    cols_used = 1
                end

                if cols_used > 0 and (ctx.is_free_mode or col_width_sp) then
                    local g_width = get_grid_width(params, 0)
                    local actual_width_sp = col_width_sp or (cols_used * g_width)

                    local sp_top = style_id and style_reg.get_spacing_top(style_id) or 0
                    local sp_bot = style_id and style_reg.get_spacing_bottom(style_id) or 0
                    local total_width_sp = actual_width_sp + (sp_top or 0) + (sp_bot or 0)

                    ctx.col_widths_sp[col_start_page] = ctx.col_widths_sp[col_start_page] or {}
                    ctx.col_widths_sp[col_start_page][col_start_col + 1] = total_width_sp

                    ctx.col_spacing_top_sp[col_start_page] = ctx.col_spacing_top_sp[col_start_page] or {}
                    ctx.col_spacing_top_sp[col_start_page][col_start_col + 1] = sp_top or 0
                    ctx.col_spacing_bottom_sp[col_start_page] = ctx.col_spacing_bottom_sp[col_start_page] or {}
                    ctx.col_spacing_bottom_sp[col_start_page][col_start_col + 1] = sp_bot or 0

                    if ctx.is_free_mode then
                        ctx.accumulated_width_sp = ctx.accumulated_width_sp + total_width_sp
                    end
                end
            end
            goto start_of_loop
        end

        local is_textflow = D.get_attribute(t, constants.ATTR_JIAZHU) == 1
        -- Textboxes inside jiazhu enter textflow as inline blocks so they
        -- get sub-column placement (#96). collect_nodes recognises HLIST/
        -- VLIST with TEXTBOX_WIDTH > 0 as inline-block content.
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
                textflow_mode = textflow_mode,
                grid_height = grid_height, -- For cur_y_sp sync
            }
            local callbacks = {
                flush = do_flush,
                wrap = function()
                    wrap_to_next_column(ctx, p_cols, interval, grid_height, indent, false, false)
                end,
                get_indent = function(bid, bi, fi)
                    return get_indent_for_current_pos(ctx, block_start_cols, bid, bi, fi)
                end,
                debug = function(msg) dbg.log(msg) end
            }

            t = textflow.place_nodes(ctx, t, layout_map, place_params, callbacks)
            ctx.page_has_content = true

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
                indent = 0, -- Textbox should not inherit paragraph indent
                grid_height = grid_height, -- For cur_y_sp sync
            }
            local tb_callbacks = {
                flush = do_flush,
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
            handle_glyph_node(t, ctx, col_buffer, layout_map, grid_height,
                indent, effective_limit, distribute, interval, p_cols, params, do_flush, base_indent)
        elseif id == constants.GLUE or id == constants.KERN then
            t = handle_spacing_node(t, ctx, grid_height, effective_col_height_sp,
                indent, interval, p_cols, do_flush)
            if not t then break end
            goto start_of_loop
        elseif id == constants.PENALTY then
            handle_penalty_node(t, ctx, grid_height, indent, interval, p_cols, do_flush)
        end

        t = D.getnext(t)
    end

    do_flush()

    local map_count = 0
    for _ in pairs(layout_map) do map_count = map_count + 1 end
    dbg.log(string.format("Layout map built. Total entries: %d, Total pages: %d", map_count,
        ctx.cur_page + 1))

    export_free_mode_data(ctx, layout_map, params)

    -- Re-compute pos.x for all layout_map entries now that col_widths_sp is complete.
    -- During layout, compute_x() may see incomplete col_widths_sp (missing entries for columns
    -- that were broken via penalty rather than natural overflow).
    -- Also applies to non-Free Mode pages with \行[width=...] (e.g. TitlePage).
    do
        local has_widths = ctx.is_free_mode
        if not has_widths then
            for _ in pairs(ctx.col_widths_sp) do has_widths = true; break end
        end
        if has_widths then
            -- Pre-compute per-page content_width (sum of col_widths_sp)
            -- and count how many columns each page has in col_widths_sp
            local page_cw_sum = {}
            local page_cw_count = {}
            for pg, cols in pairs(ctx.col_widths_sp) do
                local sum_w = 0
                local count = 0
                for _, w in pairs(cols) do sum_w = sum_w + w; count = count + 1 end
                page_cw_sum[pg] = sum_w
                page_cw_count[pg] = count
            end
            -- Count actual columns per page from layout_map (max col + 1)
            local page_max_col = {}
            for _, pos in pairs(layout_map) do
                if pos.page ~= nil and pos.col ~= nil then
                    local prev = page_max_col[pos.page]
                    if not prev or pos.col > prev then
                        page_max_col[pos.page] = pos.col
                    end
                end
            end
            -- Determine which pages have ALL columns covered by col_widths_sp
            -- (e.g. TitlePage). Pages with only partial coverage use uniform grid_width.
            local page_all_covered = {}
            if not ctx.is_free_mode then
                for pg, count in pairs(page_cw_count) do
                    local max_col = page_max_col[pg] or 0
                    if count >= max_col + 1 then
                        page_all_covered[pg] = true
                    end
                end
            end
            for _, pos in pairs(layout_map) do
                if pos.page ~= nil and pos.col ~= nil then
                    -- Re-compute pos.x / col_width / content_width only for:
                    -- 1) Free Mode pages (all cols computed from content width)
                    -- 2) Pages where ALL columns have col_widths_sp entries (TitlePage)
                    -- Skip pages with only partial col_widths_sp (e.g. \行[column-width=50pt])
                    -- — those use uniform grid_width and don't need pos.x re-computation.
                    if ctx.is_free_mode or page_all_covered[pos.page] then
                        pos.x = h.compute_x(pos.col, pos.page, ctx)
                        local cws = ctx.col_widths_sp[pos.page]
                        local cw = cws and cws[pos.col + 1]
                        if cw and cw > 0 then
                            pos.col_width = cw
                        end
                        -- Store page content_width for non-Free Mode (TitlePage)
                        if not ctx.is_free_mode and page_cw_sum[pos.page] then
                            pos.content_width = page_cw_sum[pos.page]
                        end
                    end
                end
            end
        end
    end

    -- Export band layout info for render layer (border drawing)
    if ctx.n_bands > 1 and _G.content then
        _G.content.band_heights_sp = ctx.band_heights_sp
        _G.content.band_y_offsets_sp = ctx.band_y_offsets_sp
        _G.content.band_cols_per_band = ctx.band_cols_per_band
    end

    -- Export per-page inline table band info for render layer
    if ctx.page_table_bands and _G.content then
        _G.content.page_table_bands = ctx.page_table_bands
    end

    return layout_map, ctx.cur_page + 1, ctx.page_chapter_titles, ctx.banxin_registry, ctx.page_resets
end

-- Create module table
local layout = {
    calculate_grid_positions = calculate_grid_positions,
    _internal = _internal,
}

-- Register module in package.loaded for require() compatibility
-- 注册模块到 package.loaded
package.loaded['core.luatex-cn-layout-grid'] = layout

-- Return module exports
return layout
