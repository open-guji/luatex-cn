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

-- Export _internal for testing
local _internal = {}
_internal.get_banxin_on = get_banxin_on
_internal.get_grid_width = get_grid_width
_internal.get_margin_right = get_margin_right
_internal.get_chapter_title = get_chapter_title
_internal.is_reserved_col = is_reserved_col
_internal.is_center_gap_col = is_center_gap_col

local function create_grid_context(params, line_limit, p_cols)
    -- Use helper for chapter_title (from params only, no _G fallback)
    local initial_chapter = get_chapter_title(params)
    -- Unified layout: grid mode IS natural mode with fixed cell height and zero gap.
    -- Grid mode: default_cell_height = grid_height, default_cell_gap = 0
    -- Natural mode: default_cell_height = nil (font-size-based), default_cell_gap > 0
    local default_cell_height = params.default_cell_height  -- nil = natural mode
    local default_cell_gap = params.default_cell_gap       -- 0 set at layout_params definition
    local col_height_sp = params.col_height_sp             -- 0 set at layout_params definition
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
        page_resets = {}, -- page_resets[page] = true when a \chapter marker resets page number
        last_glyph_row = -1, -- Track last glyph row for detecting line changes
        -- Unified layout: grid = fixed cell_height + zero gap; natural = font-size + configurable gap
        default_cell_height = default_cell_height,
        default_cell_gap = default_cell_gap,
        cur_y_sp = 0,
        col_height_sp = col_height_sp,
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
        local available_height = col_height_sp - total_gap
        local band_heights = params.band_heights  -- user-specified per-band heights

        local offset = 0
        for i = 0, n_bands - 1 do
            local h
            if band_heights and band_heights[i + 1] then
                h = band_heights[i + 1]
            else
                h = math.floor(available_height / n_bands)
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
        ctx.band_heights_sp[0] = col_height_sp
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
    -- Always reset Y accumulator on column wrap (unified layout)
    ctx.cur_y_sp = 0
    -- Clear textflow pending state: when a column break occurs, any pending
    -- "right sub-column waiting for left" state is no longer valid. Without
    -- this, flush_textflow_pending() would incorrectly advance cur_row in the
    -- new column (e.g., empty \左小列{} followed by ^^M newline in digital mode).
    ctx.textflow_pending_sub_col = nil
    ctx.textflow_pending_row_used = nil

    local should_wrap_page = false

    -- In digital mode (auto_column_wrap==false), never auto-wrap pages.
    -- Only explicit \换页 (PENALTY_FORCE_PAGE) triggers page breaks.
    -- Content overflowing beyond p_cols will render outside the border,
    -- making errors visible without cascading to subsequent pages.
    if ctx.auto_column_wrap ~= false then
        if ctx.n_bands > 1 then
            -- Band mode: columns wrap within each band, then to next band
            local band_start = ctx.table_start_col or 0
            local cols_in_band = ctx.band_cols_per_band
            if ctx.cur_col >= band_start + cols_in_band then
                ctx.cur_col = band_start
                ctx.cur_band = ctx.cur_band + 1
                if ctx.cur_band >= ctx.n_bands then
                    if ctx.band_mode == "auto" then
                        ctx.cur_band = 0
                        should_wrap_page = true
                    else
                        -- per-page mode: stay on last band (overflow visible)
                        ctx.cur_band = ctx.n_bands - 1
                    end
                end
                -- Update line_limit and col_height for current band
                ctx.line_limit = ctx.band_line_limits[ctx.cur_band]
                ctx.col_height_sp = ctx.band_heights_sp[ctx.cur_band]
                ctx.cur_y_sp = 0
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
        ctx.cur_col = 0
        ctx.cur_page = ctx.cur_page + 1
        -- Always reset page_has_content on page turn:
        -- new page has no content yet regardless of reset_content flag.
        -- (reset_content only controls same-page column wraps)
        ctx.page_has_content = false
        -- Reset band to 0 on page turn
        if ctx.n_bands > 1 then
            ctx.cur_band = 0
            ctx.line_limit = ctx.band_line_limits[0]
            ctx.col_height_sp = ctx.band_heights_sp[0]
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
        local effective_indent = math.max(ctx.cur_column_indent, 0)
        if ctx.cur_row > effective_indent then
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
    elseif p_val == constants.PENALTY_FORCE_PAGE then
        -- Forced page break (\newpage, \clearpage)
        -- If the current page already has no content (e.g., we just wrapped to a new page
        -- due to column overflow), skip the redundant page break to avoid creating empty pages
        -- in 对开 (split-page) mode.
        if not ctx.page_has_content and ctx.cur_col == 0 and ctx.cur_row == 0 then
            return true
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
            ctx.cur_col = ctx.table_start_col or 0
            ctx.cur_row = 0
            ctx.cur_y_sp = 0
            ctx.cur_column_indent = 0
            -- Reset table cell index for new band (row)
            if ctx.table_start_col ~= nil then
                ctx.table_render_cell_idx = 0
            end
            ctx.cur_band = ctx.cur_band + 1
            if ctx.cur_band >= ctx.n_bands then
                if ctx.band_mode == "auto" then
                    ctx.cur_band = 0
                    ctx.cur_page = ctx.cur_page + 1
                    ctx.page_has_content = false
                else
                    ctx.cur_band = ctx.n_bands - 1
                end
            end
            ctx.line_limit = ctx.band_line_limits[ctx.cur_band]
            ctx.col_height_sp = ctx.band_heights_sp[ctx.cur_band]
            move_to_next_valid_position(ctx, interval, grid_height, indent)
        end
        return true
    elseif p_val == constants.PENALTY_CELL_BREAK then
        -- Cell break in table mode: jump to next column group
        -- Use ctx.table_start_col to detect table mode (not _G.content.table_mode
        -- which is already cleared by cleanup() before layout runs)
        if ctx.table_start_col ~= nil then
            flush_buffer_fn()
            local col_groups = (_G.content and _G.content.table_col_groups) or {}
            local cell_idx = ctx.table_render_cell_idx or 0
            local cell_width = col_groups[cell_idx + 1] or 0

            if cell_width > 0 then
                -- Fixed-width cell: jump to start of next group
                local band_start = ctx.table_start_col
                local cum = 0
                for i = 1, cell_idx + 1 do
                    cum = cum + (col_groups[i] or 0)
                end
                ctx.cur_col = band_start + cum
            end

            ctx.cur_row = 0
            ctx.cur_y_sp = 0
            ctx.cur_column_indent = 0
            ctx.table_render_cell_idx = cell_idx + 1
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

        -- Read table params from _G.content.table_params
        local tp = (_G.content and _G.content.table_params) or {}
        local n_bands = tp.n_bands or 2
        local band_gap_sp = tp.band_gap_sp or 0
        local col_height_sp = ctx.saved_band_state.col_height_sp
        local default_cell_height = ctx.default_cell_height
        local orig_line_limit = ctx.saved_band_state.line_limit

        -- Calculate band layout
        local total_gap = band_gap_sp * (n_bands - 1)
        local available_height = col_height_sp - total_gap
        local band_heights_sp = {}
        local band_y_offsets_sp = {}
        local band_line_limits = {}
        local band_heights = tp.band_heights

        local offset = 0
        for i = 0, n_bands - 1 do
            local h
            if band_heights and band_heights[i + 1] then
                h = band_heights[i + 1]
            else
                h = math.floor(available_height / n_bands)
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
        ctx.band_cols_per_band = p_cols
        ctx.band_mode = "auto"
        ctx.band_gap_sp = band_gap_sp
        ctx.cur_band = 0
        ctx.line_limit = band_line_limits[0]
        ctx.col_height_sp = band_heights_sp[0]

        -- Record table start column and init cell tracking
        ctx.table_start_col = ctx.cur_col
        ctx.table_start_page = ctx.cur_page
        ctx.table_render_cell_idx = 0

        move_to_next_valid_position(ctx, interval, grid_height, indent)
        return true
    elseif p_val == constants.PENALTY_TABLE_END then
        -- End inline table section: restore pre-table band state
        flush_buffer_fn()

        -- Record table end info for border rendering
        ctx.table_end_col = ctx.cur_col
        ctx.table_end_page = ctx.cur_page

        -- Move to next column after the table
        ctx.cur_col = ctx.cur_col + (ctx.cur_row > 0 and 1 or 0)
        ctx.cur_row = 0
        ctx.cur_y_sp = 0
        ctx.cur_column_indent = 0

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
        ctx.table_render_cell_idx = nil
        -- Clean up table data that were preserved for layout
        if _G.content then
            _G.content.table_col_groups = nil
            _G.content.table_params = nil
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
                if ctx.cur_row == 0 and ctx.textflow_pending_row_used then
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
                    if ctx.cur_y_sp >= effective_col_height_sp then
                        flush_fn()
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
            if ctx.cur_y_sp > effective_col_height_sp then
                flush_fn()
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

local function calculate_buffer_height(col_buffer)
    if #col_buffer == 0 then return 0 end
    local total_height = 0
    for i, entry in ipairs(col_buffer) do
        local ch = entry.cell_height or 0
        total_height = total_height + ch
        if i < #col_buffer then
            total_height = total_height + math.floor(ch * GAP_RATIO)
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

--- Calculate whether to squeeze or stretch for kinsoku resolution.
-- Compares per-gap cost of each option and returns the cheaper one.
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
    local base_gap = math.floor(grid_height * GAP_RATIO)

    local total_cells = 0
    for _, e in ipairs(col_buffer) do
        total_cells = total_cells + (e.cell_height or grid_height)
    end

    -- Squeeze: fit N+1 chars in column (N gaps)
    local t_cell_h = resolve_cell_height(t_node, grid_height, nil, ctx.punct_config)
    local total_squeeze = total_cells + t_cell_h
    local n_gaps_squeeze = N
    local squeeze_cost = math.huge
    if total_squeeze < available and n_gaps_squeeze > 0 then
        local new_gap = (available - total_squeeze) / n_gaps_squeeze
        squeeze_cost = math.abs(new_gap - base_gap)
    end

    -- Stretch: keep N-1 chars in column (N-2 gaps)
    local last_cell_h = col_buffer[N].cell_height or grid_height
    local total_stretch = total_cells - last_cell_h
    local n_gaps_stretch = N - 2
    local stretch_cost = math.huge
    if n_gaps_stretch > 0 then
        local new_gap = (available - total_stretch) / n_gaps_stretch
        stretch_cost = math.abs(new_gap - base_gap)
    elseif N == 2 then
        stretch_cost = 0
    end

    dbg.log(string.format(
        "kinsoku cost: squeeze=%.2f stretch=%.2f (base_gap=%d, N=%d) [p:%d c:%d]",
        squeeze_cost, stretch_cost, base_gap, N, ctx.cur_page, ctx.cur_col))

    return squeeze_cost <= stretch_cost and "squeeze" or "stretch"
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

    return nil
end

_internal.is_line_start_forbidden_code = is_line_start_forbidden_code
_internal.is_line_end_forbidden_code = is_line_end_forbidden_code
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

        local map_entry = {
            page = dec_page,
            col = dec_col,
            band = dec_band,
            y_sp = dec_y_sp,
            band_y_offset_sp = ctx.band_y_offsets_sp[dec_band] or 0,
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

        -- Clear wrapped flag - we've processed a regular character
        ctx.just_wrapped_column = false

        -- Unified layout: resolve cell height and gap
        local cell_h = resolve_cell_height(t, grid_height, ctx.default_cell_height, ctx.punct_config)
        local cell_w = resolve_cell_width(t, ctx.default_cell_width)
        -- Natural mode: 0.1em gap (proportional to font size); grid mode: 0
        local gap = ctx.default_cell_height and 0 or math.floor(cell_h * GAP_RATIO)

        -- Track last character position for decoration markers
        ctx.last_char_page = ctx.cur_page
        ctx.last_char_col = ctx.cur_col
        ctx.last_char_band = ctx.cur_band
        ctx.last_char_row = ctx.cur_row
        ctx.last_char_y_sp = ctx.cur_y_sp
        ctx.last_char_cell_height = cell_h

        -- Column overflow check (sp-based)
        -- Natural mode: use actual accumulated height from buffer instead of cur_y_sp
        -- Grid mode: use cur_y_sp (which is synchronized with cur_row * grid_height)
        local should_wrap = false
        if not distribute and ctx.auto_column_wrap and ctx.cur_y_sp > 0 then
            if ctx.default_cell_height then
                -- Grid mode: use cur_y_sp (synchronized with grid)
                should_wrap = (ctx.cur_y_sp + cell_h > ctx.col_height_sp)
            else
                -- Natural mode: calculate actual height from buffer
                local col_start_y = #col_buffer > 0 and col_buffer[1].y_sp or 0
                local buffer_height = calculate_buffer_height(col_buffer)
                local next_y = col_start_y + buffer_height + cell_h
                -- Add 0.1em gap for the character we're about to add
                if #col_buffer > 0 then
                    local prev_ch = col_buffer[#col_buffer].cell_height or 0
                    next_y = next_y + math.floor(prev_ch * GAP_RATIO)
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
                local pulled = table.remove(col_buffer)
                flush_fn()
                accumulate_free_mode_col_width(ctx, params)
                wrap_to_next_column(ctx, p_cols, interval, grid_height, base_indent or indent, false, false)
                apply_indentation(ctx, base_indent or indent)
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
                ctx.cur_row = math.floor(ctx.cur_y_sp / grid_height + 0.5)
                ctx.page_has_content = true
                should_wrap = false
                dbg.log(string.format(
                    "natural kinsoku: STRETCH (char 0x%04X) [p:%d c:%d]",
                    D.getfield(t, "char") or 0, ctx.cur_page, ctx.cur_col))
            end
        end

        if should_wrap then
            flush_fn()
            accumulate_free_mode_col_width(ctx, params)
            wrap_to_next_column(ctx, p_cols, interval, grid_height, base_indent or indent, false, false)
            apply_indentation(ctx, base_indent or indent)
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
local function flush_buffer(col_buffer, ctx, grid_height, distribute, layout_map)
    if #col_buffer == 0 then return end

    local N = #col_buffer
    local H = ctx.line_limit -- Default to integer grid cells

    -- Column start offset: first entry's y_sp may include indent from
    -- apply_indentation (e.g., footnote indent=1). All recalculation
    -- paths must preserve this offset instead of starting from 0.
    local col_start_y = col_buffer[1].y_sp or 0

    -- If absolute height is provided and we are in distribution mode,
    -- use the actual dimension to calculate distribution.
    if distribute and ctx.params.absolute_height and ctx.params.absolute_height > 0 then
        H = ctx.params.absolute_height / grid_height
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
        local available_sp = H_sp - col_start_y
        if total_char_height > available_sp then
            -- Squeeze mode
            v_scale_all = available_sp / total_char_height
            local current_y = col_start_y
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
            local current_y = col_start_y
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
        -- Classify each gap: stretchable, fixed, or none
        -- gap_fixed[i] = fixed gap size in sp (0 for markers, 0.1em for blocks)
        -- is_stretchable[i] = true only for text-text gaps
        local is_stretchable = {}
        local gap_fixed = {}
        local total_cells = 0
        local total_fixed_gaps = 0
        local total_base_gaps = 0
        local n_stretchable = 0
        for i, e in ipairs(col_buffer) do
            local ch = e.cell_height or grid_height
            total_cells = total_cells + ch
            if i < N then
                local cur_is_marker = D.get_attribute(e.node, constants.ATTR_FOOTNOTE_MARKER)
                local nxt = col_buffer[i + 1]
                local nxt_is_marker = D.get_attribute(nxt.node, constants.ATTR_FOOTNOTE_MARKER)
                local cur_is_block = e.is_block
                if (cur_is_marker and cur_is_marker > 0)
                    and (nxt_is_marker and nxt_is_marker > 0) then
                    -- Inside marker group: no gap
                    is_stretchable[i] = false
                    gap_fixed[i] = 0
                elseif (cur_is_marker and cur_is_marker > 0)
                    and not (nxt_is_marker and nxt_is_marker > 0) then
                    -- Marker end → next element: fixed 0.2em gap (based on grid_height)
                    local fg = math.floor(grid_height * 0.2)
                    is_stretchable[i] = false
                    gap_fixed[i] = fg
                    total_fixed_gaps = total_fixed_gaps + fg
                elseif (nxt_is_marker and nxt_is_marker > 0) then
                    -- Before marker group start: no gap
                    is_stretchable[i] = false
                    gap_fixed[i] = 0
                elseif cur_is_block then
                    -- Block (墨围 etc.): fixed 0.1em gap, not stretchable
                    local fg = math.floor(ch * GAP_RATIO)
                    is_stretchable[i] = false
                    gap_fixed[i] = fg
                    total_fixed_gaps = total_fixed_gaps + fg
                else
                    -- Regular text: stretchable 0.1em gap
                    local bg = math.floor(ch * GAP_RATIO)
                    is_stretchable[i] = true
                    gap_fixed[i] = bg
                    n_stretchable = n_stretchable + 1
                    total_base_gaps = total_base_gaps + bg
                end
            end
        end
        local occupied = total_cells + total_base_gaps + total_fixed_gaps + col_start_y
        local remaining = ctx.col_height_sp - occupied

        if N == 1 then
            -- Keep original y_sp (preserves indent offset)
        elseif remaining < 0 and N > 1 and n_stretchable > 0 then
            -- Overfull (kinsoku squeeze): compress stretchable gaps to fit
            local total_available = ctx.col_height_sp - total_cells - col_start_y - total_fixed_gaps
            if total_available > 0 then
                local squeeze_gap = total_available / n_stretchable
                local y = col_start_y
                for i, e in ipairs(col_buffer) do
                    e.y_sp = y
                    local ch = e.cell_height or grid_height
                    if i < N then
                        y = y + ch + (is_stretchable[i] and squeeze_gap or gap_fixed[i])
                    else
                        y = y + ch
                    end
                end
            else
                -- Even with zero gaps, chars don't fit. Stack tight.
                local y = col_start_y
                for i, e in ipairs(col_buffer) do
                    e.y_sp = y
                    local ch = e.cell_height or grid_height
                    if i < N then
                        y = y + ch + (is_stretchable[i] and 0 or (gap_fixed[i] or 0))
                    end
                end
            end
        elseif remaining >= 0 and remaining < grid_height + math.floor(grid_height * GAP_RATIO) and N > 1 and n_stretchable > 0 then
            -- Nearly full: stretch only stretchable gaps; fixed gaps keep their size
            local total_available = ctx.col_height_sp - total_cells - col_start_y - total_fixed_gaps
            local stretch_gap = total_available / n_stretchable
            local y = col_start_y
            for i, e in ipairs(col_buffer) do
                e.y_sp = y
                local ch = e.cell_height or grid_height
                if i < N then
                    y = y + ch + (is_stretchable[i] and stretch_gap or gap_fixed[i])
                else
                    y = y + ch
                end
            end
        else
            -- Not full: use 0.1em for stretchable and block gaps; 0 for markers
            local y = col_start_y
            for i, e in ipairs(col_buffer) do
                local ch = e.cell_height or grid_height
                e.y_sp = y
                if i < N then
                    y = y + ch + gap_fixed[i]
                else
                    y = y + ch
                end
            end
        end
    end

    -- Redistribute footnote marker groups (︻一︼ etc.) to fixed height.
    -- Attribute value = total target height in sp (e.g., 2 * 12pt = 24pt).
    -- Layout: open bracket 0.25*fn_size at top, middle chars 1.5*fn_size centered,
    --         close bracket 0.25*fn_size at bottom.
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
                    local total_h = mv  -- already in sp
                    local bracket_h = math.floor(total_h / 8)  -- ~0.25 * fn_size per bracket
                    local mid_total = total_h - 2 * bracket_h
                    local mid_count = glen - 2
                    local mid_slot = mid_total / mid_count
                    local sy = col_buffer[gs].y_sp
                    -- Open bracket
                    col_buffer[gs].y_sp = sy
                    col_buffer[gs].cell_height = bracket_h
                    -- Middle characters
                    local mid_start = sy + bracket_h
                    for j = gs + 1, ge - 1 do
                        col_buffer[j].y_sp = mid_start + (j - gs - 1) * mid_slot
                        col_buffer[j].cell_height = math.floor(mid_slot)
                    end
                    -- Close bracket
                    col_buffer[ge].y_sp = sy + total_h - bracket_h
                    col_buffer[ge].cell_height = bracket_h
                end
                i = ge + 1
            else
                i = i + 1
            end
        end
    end

    for i, entry in ipairs(col_buffer) do
        local y_sp = distribute_y_sp[i] or entry.y_sp
        local v_scale = (distribute and N > 1) and v_scale_all or 1.0

        local map_entry = {
            page = entry.page,
            col = entry.col,
            band = entry.band or 0,
            y_sp = y_sp,
            band_y_offset_sp = ctx.band_y_offsets_sp[entry.band or 0] or 0,
            is_block = entry.is_block,
            width = entry.width,
            height = entry.height,
            v_scale = v_scale,
            cell_height = entry.cell_height,
            cell_width = entry.cell_width,
        }
        apply_style_attrs(map_entry, entry.node)

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

    -- In free mode, use content_width from three-layer architecture for page wrap
    if is_free_mode then
        ctx.content_width = params.content_width  -- 0 set at layout_params definition
        dbg.log(string.format("[Free Mode] Enabled, p_cols=%d (virtual), content_width=%.1fpt", p_cols, ctx.content_width / 65536))
    else
        ctx.content_width = 0
    end

    local layout_map = {}

    -- Buffer for distribution mode
    local col_buffer = {}

    -- Initial skip
    move_to_next_valid_position(ctx, interval, grid_height, 0)

    -- Block tracking for First Indent
    local block_start_cols = {} -- map[block_id] -> {page=p, col=c}

    local function do_flush()
        flush_buffer(col_buffer, ctx, grid_height, distribute, layout_map)
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
            local map_entry = {
                page = ctx.cur_page,
                col = ctx.cur_col,
                band = ctx.cur_band,
                y_sp = ctx.cur_y_sp,
                band_y_offset_sp = ctx.band_y_offsets_sp[ctx.cur_band] or 0,
            }
            apply_style_attrs(map_entry, t)

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
        local should_wrap_before_node = false
        if ctx.auto_column_wrap and not distribute and not is_textflow_node and not next_is_textflow then
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
            do_flush()
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
                -- Calculate last column before banxin (or page end)
                local last_col = column_mod.find_last_column_in_half_page(
                    ctx.cur_col, p_cols, interval, get_banxin_on(params))
                if last_col > ctx.cur_col then
                    ctx.cur_col = last_col
                    ctx.cur_row = 0
                    ctx.cur_y_sp = 0
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

            -- Phase 2.3: Record column width in Free Mode
            if ctx.is_free_mode then
                local cols_used = ctx.cur_col - col_start_col
                if cols_used > 0 then
                    -- Get style attributes from Column's first node
                    local style_reg = require('util.luatex-cn-style-registry')
                    local style_id = D.get_attribute(col_start_node, constants.ATTR_STYLE_REG_ID)
                    local col_width_str = style_id and style_reg.get_attr(style_id, "column_width")
                    local col_width_sp = col_width_str and tex.sp(col_width_str) or nil

                    -- Record column width (use explicit width if set, else estimate from grid)
                    local g_width = get_grid_width(params, 0)
                    local actual_width_sp = col_width_sp or (cols_used * g_width)

                    -- Add spacing to column width (spacing-top = right margin, spacing-bottom = left margin)
                    local sp_top = style_id and style_reg.get_spacing_top(style_id) or 0
                    local sp_bot = style_id and style_reg.get_spacing_bottom(style_id) or 0
                    local total_width_sp = actual_width_sp + (sp_top or 0) + (sp_bot or 0)

                    -- Initialize page array if needed
                    ctx.col_widths_sp[col_start_page] = ctx.col_widths_sp[col_start_page] or {}
                    ctx.col_widths_sp[col_start_page][col_start_col + 1] = total_width_sp  -- 1-indexed for render-position

                    -- Record spacing separately for render-position offset calculation
                    ctx.col_spacing_top_sp[col_start_page] = ctx.col_spacing_top_sp[col_start_page] or {}
                    ctx.col_spacing_top_sp[col_start_page][col_start_col + 1] = sp_top or 0
                    ctx.col_spacing_bottom_sp[col_start_page] = ctx.col_spacing_bottom_sp[col_start_page] or {}
                    ctx.col_spacing_bottom_sp[col_start_page][col_start_col + 1] = sp_bot or 0

                    -- Accumulate for page wrap decision
                    ctx.accumulated_width_sp = ctx.accumulated_width_sp + total_width_sp
                end
            end
            goto start_of_loop
        end

        local is_textflow = D.get_attribute(t, constants.ATTR_JIAZHU) == 1
        -- Textbox nodes with jiazhu attribute should NOT enter textflow path;
        -- they will be handled as independent textbox blocks below.
        if is_textflow and not (tb_w > 0 and tb_h > 0) then
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

    -- Export band layout info for render layer (border drawing)
    if ctx.n_bands > 1 and _G.content then
        _G.content.band_heights_sp = ctx.band_heights_sp
        _G.content.band_y_offsets_sp = ctx.band_y_offsets_sp
        _G.content.band_cols_per_band = ctx.band_cols_per_band
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
