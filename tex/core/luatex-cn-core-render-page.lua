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
-- render_page.lua - 坐标应用与视觉渲染（第三阶段主模块）
-- ============================================================================
-- 文件名: render_page.lua (原 render.lua)
-- 层级: 第三阶段 - 渲染层 (Stage 3: Render Layer)
--
-- 【模块功能 / Module Purpose】
-- 本模块负责排版流水线的第三阶段，将虚拟坐标应用到实际节点并绘制视觉元素：
--   1. 根据 layout_map 为每个节点设置 xoffset/yoffset（文字）或 kern/shift（块）
--   2. 插入负 kern 以抵消 TLT 方向盒子的水平推进
--   3. 调用子模块绘制边框、版心、背景
--   4. 文本框（Textbox）块由其内部逻辑渲染好后，在此模块仅作为整体块进行定位
--   5. 按页拆分节点流，生成多个独立的页面盒子
--   6. 可选绘制调试网格（蓝色框显示字符位置，红色框显示 textbox 块）
--
-- 【术语对照 / Terminology】
--   apply_positions   - 应用坐标位置（将虚拟坐标转为实际节点属性）
--   xoffset/yoffset   - 字形偏移（glyph 专用定位属性）
--   kern              - 字距调整（用于水平定位块级节点）
--   shift             - 盒子垂直偏移（box.shift 属性）
--   RTL               - 从右到左（Right-To-Left，竖排时列序）
--   page_nodes        - 页面节点分组（按页分组的节点列表）
--   p_head            - 页面头节点（当前页的节点链头部）
--   outer_shift       - 外边框偏移（外边框厚度+间距）
--
-- 【注意事项】
--   • Glyph 节点使用 xoffset/yoffset 定位，块级节点（HLIST/VLIST）使用 Kern+Shift
--   • RTL 列序转换：物理列号 = total_cols - 1 - 逻辑列号
--   • 绘制顺序严格控制：背景最底层 → 边框 → 版心 → 文字（通过 insert_before 实现）
--   • 所有 PDF 绘图指令使用 pdf_literal 节点（mode=0，用户坐标系）
--   • Kern 的 subtype=1 表示"显式 kern"，不会被后续清零（用于保护版心等特殊位置）
--   • 【重要】如果 xoffset/yoffset 计算错误（如 0 或 超出页面范围），文字将不可见
--   • 【重要】PDF literal 语法错误（如缺少 q/Q 对，或非法颜色值）会破坏整页渲染
--
-- 【整体架构 / Architecture】
--   输入: 节点流 + layout_map + 渲染参数（颜色、边框、页边距等）
--      ↓
--   apply_positions()
--      ├─ 按页分组节点（遍历 layout_map，根据 page 分组）
--      ├─ 对每一页：
--      │   ├─ 绘制背景色（render_background.draw_background）
--      │   ├─ 设置字体颜色（render_background.set_font_color）
--      │   ├─ 绘制外边框（render_border.draw_outer_border）
--      │   ├─ 绘制列边框（render_border.draw_column_borders，跳过版心列）
--      │   ├─ 绘制版心列（render_banxin.draw_banxin_column，含分隔线和文字）
--      │   ├─ 应用节点坐标
--      │   │   ├─ Glyph: 调用 render_position.calc_grid_position()
--      │   │   └─ Block: 使用 Kern 包裹 + Shift
--      │   └─ 可选：绘制调试网格
--      └─ 返回 result_pages[{head, cols}]
--      ↓
--   输出: 多个渲染好的页面（每页是一个 HLIST，dir=TLT）
--
-- ============================================================================

-- Load dependencies
local constants = package.loaded['core.luatex-cn-constants'] or
    require('core.luatex-cn-constants')
local D = constants.D
local utils = package.loaded['util.luatex-cn-utils'] or
    require('util.luatex-cn-utils')
local content = package.loaded['core.luatex-cn-core-content'] or
    require('core.luatex-cn-core-content')
local debug = package.loaded['debug.luatex-cn-debug'] or
    require('debug.luatex-cn-debug')

local dbg = debug.get_debugger('render')
local page_mod = package.loaded['core.luatex-cn-core-page'] or
    require('core.luatex-cn-core-page')
local textbox_mod = package.loaded['core.luatex-cn-core-textbox'] or
    require('core.luatex-cn-core-textbox')
local render_border = package.loaded['core.luatex-cn-core-render-border'] or
    require('core.luatex-cn-core-render-border')
local linemark_mod = package.loaded['decorate.luatex-cn-linemark'] or
    require('decorate.luatex-cn-linemark')
local page_process = package.loaded['core.luatex-cn-core-render-page-process'] or
    require('core.luatex-cn-core-render-page-process')


-- Internal functions for unit testing (delegated to page_process module)
local _internal = {
    handle_glyph_node = page_process.handle_glyph_node,
    handle_block_node = page_process.handle_block_node,
    handle_debug_drawing = page_process.handle_debug_drawing,
    handle_decorate_node = page_process.handle_decorate_node,
    process_page_nodes = page_process.process_page_nodes,
}


-- 辅助函数：计算渲染上下文（尺寸、偏移、列数等）
-- All values come from ctx (populated by main.lua)
local function calculate_render_context(ctx)
    -- Unpack nested contexts
    local engine = ctx.engine
    local grid = ctx.grid
    local page = ctx.page
    local visual = ctx.visual

    -- All values from ctx (main.lua populates these from style stack)
    local border_thickness = engine.border_thickness
    local half_thickness = engine.half_thickness
    local ob_thickness_val = page.ob_thickness
    local ob_sep_val = page.ob_sep
    local b_padding_top = engine.b_padding_top
    local b_padding_bottom = engine.b_padding_bottom
    local grid_width = grid.width
    local grid_height = grid.height
    local banxin_width = grid.banxin_width or 0
    local body_font_size = grid.body_font_size or grid_width

    -- Dynamic values from ctx (calculated per-invocation in main.lua)
    local outer_shift = engine.outer_shift
    local shift_x = engine.shift_x
    local shift_y = engine.shift_y

    local interval = grid.n_column
    local p_cols = grid.cols
    local line_limit = grid.line_limit

    -- Visual params from ctx.visual (populated by main.lua)
    local vertical_align = visual.vertical_align or "center"
    local background_rgb_str = utils.normalize_rgb(visual.bg_rgb)
    local text_rgb_str = utils.normalize_rgb(visual.font_rgb)
    -- Border shape decoration parameters
    local border_shape = visual.border_shape or "none"
    local border_color_str = utils.normalize_rgb(visual.border_color) or "0 0 0"
    local border_width = constants.to_dimen(visual.border_width) or (65536 * 0.4)
    local border_margin = constants.to_dimen(visual.border_margin) or (65536 * 1)

    -- Colors: border from engine (already normalized in main.lua)
    local b_rgb_str = engine.border_rgb_str

    return {
        border_thickness = border_thickness,
        half_thickness = half_thickness,
        ob_thickness_val = ob_thickness_val,
        ob_sep_val = ob_sep_val,
        outer_shift = outer_shift,
        shift_x = shift_x,
        shift_y = shift_y,
        interval = interval,
        p_cols = p_cols,
        line_limit = line_limit,
        b_padding_top = b_padding_top,
        b_padding_bottom = b_padding_bottom,
        b_rgb_str = b_rgb_str,
        background_rgb_str = background_rgb_str,
        text_rgb_str = text_rgb_str,
        grid_width = grid_width,
        grid_height = grid_height,
        banxin_width = banxin_width,
        body_font_size = body_font_size,
        vertical_align = vertical_align,
        -- TextFlow align default (per-node align from style stack takes precedence)
        textflow_align = (_G.jiazhu and _G.jiazhu.align) or "outward",
        -- Judou parameters from _G.judou global (set by judou.setup)
        judou_pos = (_G.judou and _G.judou.pos) or "right-bottom",
        judou_size = (_G.judou and _G.judou.size) or "1em",
        judou_color = (_G.judou and _G.judou.color) or "red",
        -- Border shape decoration parameters (textbox only)
        border_shape = border_shape,
        border_color_str = border_color_str,
        border_width = border_width,
        border_margin = border_margin,
    }
end

_internal.calculate_render_context = calculate_render_context

-- 辅助函数：将节点按页分组
local function group_nodes_by_page(d_head, layout_map, total_pages)
    local page_nodes = {}
    for p = 0, total_pages - 1 do
        page_nodes[p] = { head = nil, tail = nil, max_col = 0, max_row = 0 }
    end

    local t = d_head
    while t do
        local next_node = D.getnext(t)
        local pos = layout_map[t]
        D.setnext(t, nil)

        if pos then
            local p = pos.page or 0
            if page_nodes[p] then
                if not page_nodes[p].head then
                    page_nodes[p].head = t
                else
                    D.setnext(page_nodes[p].tail, t)
                end
                page_nodes[p].tail = t
                if pos.col > page_nodes[p].max_col then page_nodes[p].max_col = pos.col end
                -- Track max row for actual content height calculation
                -- Note: pos.row can be fractional (from distribute_rows), use math.ceil
                -- Note: pos.height is in sp (physical), NOT grid row count
                local row = pos.row or 0
                local row_ceil = math.ceil(row)
                if row_ceil > page_nodes[p].max_row then page_nodes[p].max_row = row_ceil end
            else
                node.flush_node(D.tonode(t))
            end
        else
            node.flush_node(D.tonode(t))
        end
        t = next_node
    end
    return page_nodes
end

_internal.group_nodes_by_page = group_nodes_by_page

-- 辅助函数：定位浮动文本框
_internal.position_floating_box = textbox_mod.render_floating_box

-- Local reference to process_page_nodes from the process module
local process_page_nodes = page_process.process_page_nodes

-- 辅助函数：渲染单个页面
local function render_single_page(p_head, p_max_col, p_max_row, p, layout_map, params, ctx)
    if not p_head then return nil, 0 end

    local p_total_cols = p_max_col + 1
    local p_cols = ctx.p_cols
    -- Always enforce full page width to ensure correct RTL/SplitPage absolute positioning
    if p_cols > 0 and p_total_cols < p_cols then
        p_total_cols = p_cols
    end

    -- Actual content dimensions (for special border shapes)
    local actual_cols = p_max_col + 1
    local actual_rows = p_max_row + 1

    local grid_width = ctx.grid_width
    local grid_height = ctx.grid_height
    local border_thickness = ctx.border_thickness
    local line_limit = ctx.line_limit
    local b_padding_top = ctx.b_padding_top
    local b_padding_bottom = ctx.b_padding_bottom
    local grid = params.grid
    local engine = params.engine
    local page = params.page
    local plugins = params.plugins

    local draw_border = engine.draw_border
    local draw_outer_border = page.is_outer_border
    local shift_x = ctx.shift_x
    local outer_shift = ctx.outer_shift
    local b_rgb_str = ctx.b_rgb_str

    -- Reserved columns (computed via engine_ctx helper function)
    local reserved_cols = grid.get_reserved_cols and grid.get_reserved_cols(p, p_total_cols) or {}

    -- Scan layout_map for taitou columns (negative row = raised border)
    local col_min_rows = {}
    local scan_t = p_head
    while scan_t do
        local pos = layout_map[scan_t]
        if pos then
            local col = pos.col
            local row = math.floor(pos.row or 0)
            if row < 0 and (not col_min_rows[col] or row < col_min_rows[col]) then
                col_min_rows[col] = row
            end
        end
        scan_t = D.getnext(scan_t)
    end

    -- Borders, background, and decorative frames (handled by render_border module)
    p_head = render_border.render_borders(p_head, {
        -- Grid and dimensions
        p_total_cols = p_total_cols,
        actual_cols = actual_cols,
        actual_rows = actual_rows,
        grid_width = grid_width,
        grid_height = grid_height,
        banxin_width = ctx.banxin_width,
        interval = ctx.interval,
        line_limit = line_limit,
        -- Border params
        border_thickness = border_thickness,
        b_padding_top = b_padding_top,
        b_padding_bottom = b_padding_bottom,
        shift_x = shift_x,
        outer_shift = outer_shift,
        b_rgb_str = b_rgb_str,
        ob_thickness_val = ctx.ob_thickness_val,
        ob_sep_val = ctx.ob_sep_val,
        -- Flags
        draw_border = draw_border,
        draw_outer_border_flag = draw_outer_border,
        is_textbox = page.is_textbox,
        reserved_cols = reserved_cols,
        -- Visual params
        border_shape = ctx.border_shape,
        border_color_str = ctx.border_color_str,
        border_width = ctx.border_width,
        border_margin = ctx.border_margin,
        background_rgb_str = ctx.background_rgb_str,
        -- Taitou raised border
        col_min_rows = col_min_rows,
    })

    -- Font color
    p_head = content.set_font_color(p_head, ctx.text_rgb_str)

    -- Node positions
    -- Update context with page-specific total_cols
    local ctx_node = {}
    for k, v in pairs(ctx) do ctx_node[k] = v end
    ctx_node.p_total_cols = p_total_cols

    p_head = process_page_nodes(p_head, layout_map, params, ctx_node)

    -- Render Line Marks (专名号/书名号) - batch PDF drawing after all glyphs are positioned
    if ctx_node.line_mark_entries and #ctx_node.line_mark_entries > 0 then
        p_head = linemark_mod.render_line_marks(p_head, ctx_node.line_mark_entries, ctx_node)
    end

    -- Render Floating TextBoxes
    if plugins.floating_map then
        for _, item in ipairs(plugins.floating_map) do
            if item.page == p then
                p_head = textbox_mod.render_floating_box(p_head, item, params)
            end
        end
    end

    -- For TextBox: return actual content dimensions, not expanded page dimensions
    -- This ensures TextBox output box has correct dimensions in main document flow
    local return_cols = page.is_textbox and actual_cols or p_total_cols
    local return_rows = page.is_textbox and actual_rows or line_limit
    return D.tonode(p_head), return_cols, return_rows
end

_internal.render_single_page = render_single_page

-- @param head (node) 节点列表头部
-- @param layout_map (table) 从节点指针到 {col, row} 的映射
-- @param params (table) 渲染参数
-- @return (table) 页面信息数组 {head, cols}
local function apply_positions(head, layout_map, params)
    local d_head = D.todirect(head)

    local ctx = calculate_render_context(params)

    dbg.log(string.format("[render] apply_positions: border=%s, font=%s",
        tostring(params.border_rgb), tostring(params.font_rgb)))

    -- Group nodes by page
    local page_nodes = group_nodes_by_page(d_head, layout_map, params.total_pages)

    local result_pages = {}

    -- Process each page
    for p = 0, params.total_pages - 1 do
        local p_head = page_nodes[p].head
        local p_max_col = page_nodes[p].max_col
        local p_max_row = page_nodes[p].max_row
        local rendered_head, cols, rows = render_single_page(p_head, p_max_col, p_max_row, p, layout_map, params, ctx)
        if rendered_head then
            result_pages[p + 1] = { head = rendered_head, cols = cols, rows = rows }
        end
    end

    return result_pages
end

-- Create module table
local render = {
    apply_positions = apply_positions,
    _internal = _internal
}

-- Register module
package.loaded['core.luatex-cn-core-render-page'] = render
return render
