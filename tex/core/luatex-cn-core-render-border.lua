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
-- luatex-cn-core-render-border.lua - 边框渲染模块
-- ============================================================================
-- 文件名: luatex-cn-core-render-border.lua
-- 层级: 第三阶段 - 渲染层 (Stage 3: Render Layer)
--
-- 【模块功能 / Module Purpose】
-- 本模块负责边框和装饰边框的渲染：
--   1. draw_column_borders: 绘制普通列的边框（跳过版心列）
--   2. draw_outer_border: 绘制整个内容区域的外围边框
--   3. render_borders: 高层协调函数，处理所有边框渲染
--   4. 装饰边框形状（rect/octagon/circle）的渲染
--
-- ============================================================================

-- Load dependencies
local utils = package.loaded['util.luatex-cn-utils'] or
    require('util.luatex-cn-utils')
local constants = package.loaded['core.luatex-cn-constants'] or
    require('core.luatex-cn-constants')
local drawing = package.loaded['util.luatex-cn-drawing'] or
    require('util.luatex-cn-drawing')
local page_mod = package.loaded['core.luatex-cn-core-page'] or
    require('core.luatex-cn-core-page')
local text_position = package.loaded['core.luatex-cn-render-position'] or
    require('core.luatex-cn-render-position')

-- ============================================================================
-- Column Border Drawing
-- ============================================================================

--- 绘制列边框（仅限普通列，不含版心列）
-- 版心列应由 banxin.draw_banxin_column 单独绘制
-- @param p_head (node) 节点列表头部（直接引用）
-- @param params (table) 参数表:
--   - total_cols: 要绘制的总列数
--   - grid_width: 每列的宽度 (sp)
--   - grid_height: 每行的高度 (sp)
--   - line_limit: 每列的行数限制
--   - border_thickness: 边框厚度 (sp)
--   - b_padding_top: 顶部内边距 (sp)
--   - b_padding_bottom: 底部内边距 (sp)
--   - shift_x: 水平偏移 (sp)
--   - outer_shift: 外边框偏移 (sp)
--   - border_rgb_str: 归一化的 RGB 颜色字符串
--   - banxin_cols: 可选，要跳过的列索引集合（版心列）
-- @return (node) 更新后的头部
local function draw_column_borders(p_head, params)
    local sp_to_bp = utils.sp_to_bp
    local total_cols = params.total_cols
    local grid_width = params.grid_width
    local grid_height = params.grid_height
    local line_limit = params.line_limit
    local border_thickness = params.border_thickness
    local b_padding_top = params.b_padding_top
    local b_padding_bottom = params.b_padding_bottom
    local shift_x = params.shift_x
    local outer_shift = params.outer_shift
    local border_rgb_str = params.border_rgb_str
    local banxin_cols = params.banxin_cols or {} -- Set of column indices to skip
    local col_min_rows = params.col_min_rows or {} -- Per-column min row for taitou raised border
    local banxin_width = params.banxin_width or 0
    local interval = params.interval or 0

    local b_thickness_bp = border_thickness * sp_to_bp
    local half_thickness = math.floor(border_thickness / 2)

    -- Variable-width column borders: when col_widths is set,
    -- each column has its own width in sp.
    local col_widths = _G.content and _G.content.col_widths
    if col_widths and #col_widths > 0 then
        for i = 1, #col_widths do
            local logical_col = i - 1
            local rtl_col = total_cols - 1 - logical_col
            local tx_bp = (text_position.get_column_x_var(rtl_col, col_widths, total_cols) + half_thickness + shift_x) * sp_to_bp
            local ty_bp = -(half_thickness + outer_shift) * sp_to_bp
            local tw_bp = col_widths[i] * sp_to_bp
            local th_bp = -(line_limit * grid_height + b_padding_top + b_padding_bottom) * sp_to_bp

            local literal = utils.create_border_literal(b_thickness_bp, border_rgb_str, tx_bp, ty_bp, tw_bp, th_bp)
            p_head = utils.insert_pdf_literal(p_head, literal)
        end
        return p_head
    end

    for col = 0, total_cols - 1 do
        -- Skip banxin columns (they are drawn separately by banxin module)
        if not banxin_cols[col] then
            local rtl_col = total_cols - 1 - col
            local tx_bp = (text_position.get_column_x(rtl_col, grid_width, banxin_width, interval) + half_thickness + shift_x) * sp_to_bp
            local ty_bp = -(half_thickness + outer_shift) * sp_to_bp
            local tw_bp = text_position.get_column_width(col, grid_width, banxin_width, interval) * sp_to_bp
            local th_bp = -(line_limit * grid_height + b_padding_top + b_padding_bottom) * sp_to_bp

            -- Taitou raised border: extend column upward for negative row columns
            local min_row = col_min_rows[col]
            if min_row and min_row < 0 then
                local raised_sp = (-min_row) * grid_height
                ty_bp = ty_bp + raised_sp * sp_to_bp
                th_bp = th_bp - raised_sp * sp_to_bp
            end

            -- Draw column border
            local literal = utils.create_border_literal(b_thickness_bp, border_rgb_str, tx_bp, ty_bp, tw_bp, th_bp)
            p_head = utils.insert_pdf_literal(p_head, literal)
        end
    end

    return p_head
end

-- ============================================================================
-- Outer Border Drawing
-- ============================================================================

--- 在整个内容区域外围绘制外边框
-- 当有抬头列（负行号）时，绘制阶梯状外边框以包裹突出文字
-- @param p_head (node) 节点列表头部（直接引用）
-- @param params (table) 参数表:
--   - inner_width: 内部内容宽度 (sp)
--   - inner_height: 内部内容高度 (sp)
--   - outer_border_thickness: 外边框厚度 (sp)
--   - outer_border_sep: 内外边框间距 (sp)
--   - border_rgb_str: 归一化的 RGB 颜色字符串
--   - col_min_rows: (optional) 每列最小行号表
--   - total_cols: (optional) 总列数
--   - grid_width: (optional) 格子宽度 (sp)
--   - grid_height: (optional) 格子高度 (sp)
--   - half_thickness: (optional) 列边框半厚度 (sp)
--   - shift_x: (optional) 水平偏移 (sp)
-- @return (node) 更新后的头部
local function draw_outer_border(p_head, params)
    local sp_to_bp = utils.sp_to_bp
    local inner_width = params.inner_width
    local inner_height = params.inner_height
    local ob_thickness_val = params.outer_border_thickness
    local ob_sep_val = params.outer_border_sep
    local border_rgb_str = params.border_rgb_str
    local col_min_rows = params.col_min_rows or {}

    local ob_thickness_bp = ob_thickness_val * sp_to_bp

    local tx_bp = (ob_thickness_bp / 2)
    local ty_bp = -(ob_thickness_bp / 2)
    local tw_bp = (inner_width + ob_sep_val * 2 + ob_thickness_val) * sp_to_bp
    local th_bp = -(inner_height + ob_sep_val * 2 + ob_thickness_val) * sp_to_bp

    -- Check if any taitou columns exist
    local has_taitou = false
    for _, v in pairs(col_min_rows) do
        if v and v < 0 then has_taitou = true; break end
    end

    if not has_taitou then
        -- Simple rectangle (no taitou)
        local literal = utils.create_border_literal(ob_thickness_bp, border_rgb_str, tx_bp, ty_bp, tw_bp, th_bp)
        p_head = utils.insert_pdf_literal(p_head, literal)
        return p_head
    end

    -- Stepped outer border path for taitou columns
    local total_cols = params.total_cols
    local grid_width = params.grid_width
    local grid_height = params.grid_height
    local half_thickness = params.half_thickness or 0
    local shift_x = params.shift_x or 0
    local gh_bp = grid_height * sp_to_bp

    -- Bottom and right edges of outer border
    local by_bp = ty_bp + th_bp  -- bottom Y
    local rx_bp = tx_bp + tw_bp  -- right X
    local ob_sep_bp = ob_sep_val * sp_to_bp

    -- Per-column top Y (visual left to right = rtl_col 0 to n-1)
    local col_tops = {}
    for rtl_col = 0, total_cols - 1 do
        local col = total_cols - 1 - rtl_col
        local min_row = col_min_rows[col]
        if min_row and min_row < 0 then
            col_tops[rtl_col] = ty_bp + (-min_row) * gh_bp
        else
            col_tops[rtl_col] = ty_bp
        end
    end

    -- Column boundary X positions (supports mixed column widths)
    local banxin_width = params.banxin_width or 0
    local interval = params.interval or 0
    local function cb(b)
        return (text_position.get_column_x(b, grid_width, banxin_width, interval) + half_thickness + shift_x) * sp_to_bp
    end

    -- Construct path: counter-clockwise from bottom-left
    local parts = {}
    -- Start at bottom-left
    parts[#parts + 1] = string.format("%.4f %.4f m", tx_bp, by_bp)
    -- Left edge up to leftmost column's top
    parts[#parts + 1] = string.format("%.4f %.4f l", tx_bp, col_tops[0])

    -- Step offset: ob_sep measured from inner edges of both borders (compensate stroke centering)
    local half_inner_bp = half_thickness * sp_to_bp
    local step_offset = ob_sep_bp + ob_thickness_bp / 2 + half_inner_bp

    -- Top edge with steps (left to right)
    for b = 1, total_cols do
        local rtl_col = b - 1  -- column to the left of boundary b
        local cur_top = col_tops[rtl_col]

        if b < total_cols then
            local next_top = col_tops[b]
            local has_step = math.abs(next_top - cur_top) > 0.001

            if has_step then
                -- Shift step vertical to maintain ob_sep gap from inner column border edge
                local step_x
                if cur_top > next_top then
                    -- Step DOWN (left taller): shift RIGHT past inner boundary
                    step_x = cb(b) + step_offset
                else
                    -- Step UP (right taller): shift LEFT before inner boundary
                    step_x = cb(b) - step_offset
                end
                -- Horizontal to step position, then vertical step
                parts[#parts + 1] = string.format("%.4f %.4f l", step_x, cur_top)
                parts[#parts + 1] = string.format("%.4f %.4f l", step_x, next_top)
            else
                -- No step: horizontal to column boundary
                parts[#parts + 1] = string.format("%.4f %.4f l", cb(b), cur_top)
            end
        else
            -- Last column: horizontal to right edge
            parts[#parts + 1] = string.format("%.4f %.4f l", rx_bp, cur_top)
        end
    end

    -- Right edge down to bottom-right
    parts[#parts + 1] = string.format("%.4f %.4f l", rx_bp, by_bp)
    -- Close and stroke
    parts[#parts + 1] = "h S"

    local path_str = table.concat(parts, " ")
    local literal = string.format("q %.2f w %s RG %s Q", ob_thickness_bp, border_rgb_str, path_str)
    p_head = utils.insert_pdf_literal(p_head, literal)

    return p_head
end

-- ============================================================================
-- High-level Border Rendering
-- ============================================================================

--- 渲染所有边框（列边框、外边框、装饰边框、背景）
-- @param p_head (node) 节点列表头部
-- @param params (table) 参数表:
--   -- Grid and dimensions
--   - p_total_cols: 页面总列数
--   - actual_cols: 实际内容列数
--   - actual_rows: 实际内容行数
--   - grid_width: 每列宽度 (sp)
--   - grid_height: 每行高度 (sp)
--   - line_limit: 每列行数限制
--   -- Border params
--   - border_thickness: 边框厚度 (sp)
--   - b_padding_top: 顶部内边距 (sp)
--   - b_padding_bottom: 底部内边距 (sp)
--   - shift_x: 水平偏移 (sp)
--   - outer_shift: 外边框偏移 (sp)
--   - b_rgb_str: 边框颜色字符串
--   - ob_thickness_val: 外边框厚度 (sp)
--   - ob_sep_val: 外边框间距 (sp)
--   -- Flags
--   - draw_border: 是否绘制列边框
--   - draw_outer_border: 是否绘制外边框
--   - is_textbox: 是否为文本框模式
--   - reserved_cols: 要跳过的列索引集合
--   -- Visual params
--   - border_shape: 装饰边框形状 ("none", "rect", "octagon", "circle")
--   - border_color_str: 装饰边框颜色
--   - border_width: 装饰边框宽度 (sp)
--   - border_margin: 装饰边框外边距 (sp)
--   - background_rgb_str: 背景颜色字符串
--   - text_rgb_str: 文字颜色字符串
-- @return (node) 更新后的头部
local function render_borders(p_head, params)
    local p_total_cols = params.p_total_cols
    local actual_cols = params.actual_cols
    local actual_rows = params.actual_rows
    local grid_width = params.grid_width
    local grid_height = params.grid_height
    local line_limit = params.line_limit
    local border_thickness = params.border_thickness
    local b_padding_top = params.b_padding_top
    local b_padding_bottom = params.b_padding_bottom
    local is_textbox = params.is_textbox

    local banxin_width = params.banxin_width or 0
    local interval = params.interval or 0

    -- Calculate content dimensions (shared logic in content module)
    local content_mod = package.loaded['core.luatex-cn-core-content'] or
        require('core.luatex-cn-core-content')
    local _, _, inner_width, inner_height = content_mod.calculate_content_dimensions({
        is_textbox = is_textbox,
        actual_cols = actual_cols,
        actual_rows = actual_rows,
        grid_width = grid_width,
        grid_height = grid_height,
        line_limit = line_limit,
        b_padding_top = b_padding_top,
        b_padding_bottom = b_padding_bottom,
        p_total_cols = p_total_cols,
        border_thickness = border_thickness,
        banxin_width = banxin_width,
        interval = interval,
    })

    -- 1. Draw column borders
    if params.draw_border and p_total_cols > 0 then
        p_head = draw_column_borders(p_head, {
            total_cols = p_total_cols,
            grid_width = grid_width,
            grid_height = grid_height,
            banxin_width = banxin_width,
            interval = interval,
            line_limit = line_limit,
            border_thickness = border_thickness,
            b_padding_top = b_padding_top,
            b_padding_bottom = b_padding_bottom,
            shift_x = params.shift_x,
            outer_shift = params.outer_shift,
            border_rgb_str = params.b_rgb_str,
            banxin_cols = params.reserved_cols,
            col_min_rows = params.col_min_rows,
        })
    end

    -- 2. Draw outer border
    if params.draw_outer_border_flag and p_total_cols > 0 then
        p_head = draw_outer_border(p_head, {
            inner_width = inner_width,
            inner_height = inner_height,
            outer_border_thickness = params.ob_thickness_val,
            outer_border_sep = params.ob_sep_val,
            border_rgb_str = params.b_rgb_str,
            -- Taitou stepped border params
            col_min_rows = params.col_min_rows,
            total_cols = p_total_cols,
            grid_width = grid_width,
            grid_height = grid_height,
            banxin_width = banxin_width,
            interval = interval,
            half_thickness = math.floor(border_thickness / 2),
            shift_x = params.shift_x,
        })
    end

    -- 3. Draw background (shaped or rectangular)
    local border_shape = params.border_shape
    local shape_width = actual_cols * grid_width
    local shape_height = actual_rows * grid_height

    if border_shape == "octagon" and params.background_rgb_str then
        -- Octagon-shaped background
        local border_m = params.border_margin or 0
        p_head = drawing.draw_octagon_fill(p_head, {
            x = -border_m,
            y = border_m,
            width = shape_width + 2 * border_m,
            height = shape_height + 2 * border_m,
            color_str = params.background_rgb_str,
        })
    elseif border_shape == "circle" and params.background_rgb_str then
        -- Circle-shaped background
        local border_m = params.border_margin or 0
        p_head = drawing.draw_circle_fill(p_head, {
            cx = shape_width / 2,
            cy = -shape_height / 2,
            radius = math.max(shape_width, shape_height) / 2 + border_m,
            color_str = params.background_rgb_str,
        })
    else
        -- Rectangular background (default)
        p_head = page_mod.draw_background(p_head, {
            bg_rgb_str = params.background_rgb_str,
            inner_width = inner_width,
            inner_height = inner_height,
            outer_shift = params.outer_shift,
            is_textbox = is_textbox,
        })
    end

    -- 4. Draw border frame decoration
    if border_shape and border_shape ~= "none" then
        local border_color = params.border_color_str or params.b_rgb_str or "0 0 0"
        local border_w = params.border_width or (65536 * 0.4)
        local border_m = params.border_margin or 0

        if border_shape == "rect" then
            p_head = drawing.draw_rect_frame(p_head, {
                x = -border_m,
                y = border_m,
                width = shape_width + 2 * border_m,
                height = shape_height + 2 * border_m,
                line_width = border_w,
                color_str = border_color,
            })
        elseif border_shape == "octagon" then
            p_head = drawing.draw_octagon_frame(p_head, {
                x = -border_m,
                y = border_m,
                width = shape_width + 2 * border_m,
                height = shape_height + 2 * border_m,
                line_width = border_w,
                color_str = border_color,
            })
        elseif border_shape == "circle" then
            p_head = drawing.draw_circle_frame(p_head, {
                cx = shape_width / 2,
                cy = -shape_height / 2,
                radius = math.max(shape_width, shape_height) / 2 + border_m,
                line_width = border_w,
                color_str = border_color,
            })
        end
    end

    return p_head
end

-- ============================================================================
-- Module Exports
-- ============================================================================

local render_border = {
    draw_column_borders = draw_column_borders,
    draw_outer_border = draw_outer_border,
    render_borders = render_borders,
}

-- Register module
package.loaded['core.luatex-cn-core-render-border'] = render_border

return render_border
