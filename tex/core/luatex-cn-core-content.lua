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
-- core_content.lua - 内容渲染模块
-- ============================================================================
-- 文件名: luatex-cn-core-content.lua
-- 层级: 第三阶段 - 渲染层 (Stage 3: Render Layer)
--
-- 【模块功能 / Module Purpose】
-- 本模块负责内容区域的渲染功能：
--   1. set_font_color: 设置后续所有文字的填充颜色
--   2. draw_column_borders: 绘制普通列的边框（跳过版心列）
--   3. draw_outer_border: 绘制整个内容区域的外围边框
--
-- ============================================================================

-- Load dependencies
local utils = package.loaded['util.luatex-cn-utils'] or
    require('util.luatex-cn-utils')
local constants = package.loaded['core.luatex-cn-constants'] or
    require('core.luatex-cn-constants')

-- Initialize global content table (similar to _G.page)
_G.content = _G.content or {}
_G.content.border_on = _G.content.border_on or false
_G.content.outer_border_on = _G.content.outer_border_on or false
_G.content.border_thickness = _G.content.border_thickness or 26214 -- 0.4pt
_G.content.outer_border_thickness = _G.content.outer_border_thickness or (65536 * 2)
_G.content.outer_border_sep = _G.content.outer_border_sep or (65536 * 2)
_G.content.border_padding_top = _G.content.border_padding_top or 0
_G.content.border_padding_bottom = _G.content.border_padding_bottom or 0
_G.content.n_column = _G.content.n_column or 8
_G.content.n_char_per_col = _G.content.n_char_per_col or 0
_G.content.page_columns = _G.content.page_columns or 0
_G.content.grid_width = _G.content.grid_width or 0
_G.content.grid_height = _G.content.grid_height or 0
_G.content.content_height = _G.content.content_height or 0
_G.content.available_width = _G.content.available_width or 0
_G.content.available_height = _G.content.available_height or 0
_G.content.border_overhead_height = _G.content.border_overhead_height or 0

-- Visual params (colors already converted to RGB strings by TeX)
_G.content.vertical_align = _G.content.vertical_align or "center"
_G.content.border_color = _G.content.border_color or "0 0 0"
_G.content.background_color = _G.content.background_color or nil
_G.content.font_color = _G.content.font_color or nil
_G.content.font_size = _G.content.font_size or 0

--- Setup global content parameters from TeX
-- @param params (table) Parameters from TeX keyvals
local function setup(params)
    params = params or {}
    if params.border_on ~= nil then _G.content.border_on = params.border_on end
    if params.outer_border_on ~= nil then _G.content.outer_border_on = params.outer_border_on end
    if params.border_thickness then _G.content.border_thickness = constants.to_dimen(params.border_thickness) end
    if params.outer_border_thickness then _G.content.outer_border_thickness = constants.to_dimen(params.outer_border_thickness) end
    if params.outer_border_sep then _G.content.outer_border_sep = constants.to_dimen(params.outer_border_sep) end
    if params.border_padding_top then _G.content.border_padding_top = constants.to_dimen(params.border_padding_top) end
    if params.border_padding_bottom then _G.content.border_padding_bottom = constants.to_dimen(params.border_padding_bottom) end
    if params.n_column then _G.content.n_column = tonumber(params.n_column) or 8 end
    if params.n_char_per_col then _G.content.n_char_per_col = tonumber(params.n_char_per_col) or 0 end
    if params.grid_width then _G.content.grid_width = constants.to_dimen(params.grid_width) end
    if params.grid_height then _G.content.grid_height = constants.to_dimen(params.grid_height) end

    -- Visual params (RGB strings already converted by TeX)
    if params.vertical_align and params.vertical_align ~= "" then
        _G.content.vertical_align = params.vertical_align
    end
    if params.border_color and params.border_color ~= "" and params.border_color ~= "nil" then
        _G.content.border_color = params.border_color
    end
    if params.background_color and params.background_color ~= "" and params.background_color ~= "nil" then
        _G.content.background_color = params.background_color
    else
        _G.content.background_color = nil
    end
    if params.font_color and params.font_color ~= "" and params.font_color ~= "nil" then
        _G.content.font_color = params.font_color
    else
        _G.content.font_color = nil
    end
    if params.font_size then
        _G.content.font_size = constants.to_dimen(params.font_size)
    end

    -- Phase 3: Push content base style to style stack
    local style_registry = package.loaded['util.luatex-cn-style-registry'] or
        require('util.luatex-cn-style-registry')

    local base_style = {
        -- Default indentation: 0 for content (Paragraph will override)
        indent = 0,
        first_indent = -1,  -- -1 means inherit from indent
    }
    if _G.content.font_color then
        base_style.font_color = _G.content.font_color
    end
    if _G.content.font_size then
        base_style.font_size = _G.content.font_size
    end

    -- Push content base style (bottom of stack)
    _G.content_style_id = style_registry.push(base_style)

    -- Store explicit page_columns if provided
    local explicit_page_cols = tonumber(params.page_columns) or 0

    -- Calculate available_width and auto page_columns
    local banxin_on = _G.banxin and _G.banxin.enabled
    local n_column = _G.content.n_column or 8
    local g_width = _G.content.grid_width or 0
    local b_thickness = _G.content.border_on and _G.content.border_thickness or 0
    local is_outer_border = _G.content.outer_border_on
    local ob_thickness = _G.content.outer_border_thickness or 0
    local ob_sep = _G.content.outer_border_sep or 0

    -- Get page dimensions from _G.page (set by page.setup)
    local p_width = _G.page and _G.page.paper_width or 0
    local m_left = _G.page and _G.page.margin_left or 0
    local m_right = _G.page and _G.page.margin_right or 0

    -- Calculate available width
    local available_width = p_width - m_left - m_right - b_thickness
    if is_outer_border then
        available_width = available_width - 2 * (ob_thickness + ob_sep)
    end
    _G.content.available_width = available_width

    -- Auto-calculate page_columns if not explicitly set
    if explicit_page_cols > 0 then
        _G.content.page_columns = explicit_page_cols
    elseif banxin_on then
        -- With banxin: 2 * n_column + 1 (center column)
        _G.content.page_columns = (2 * n_column + 1)
    elseif g_width > 0 and available_width > 0 then
        -- Without banxin: calculate from available width
        _G.content.page_columns = math.floor(available_width / g_width + 0.1)
        if _G.content.page_columns <= 0 then _G.content.page_columns = 1 end
    else
        _G.content.page_columns = math.max(1, n_column)
    end

    -- =========================================================================
    -- Auto-Layout: Calculate grid_width, grid_height, and content_height
    -- =========================================================================

    -- Get page height dimensions
    local p_height = _G.page and _G.page.paper_height or 0
    local m_top = _G.page and _G.page.margin_top or 0
    local m_bottom = _G.page and _G.page.margin_bottom or 0
    local b_padding_top = _G.content.border_padding_top or 0
    local b_padding_bottom = _G.content.border_padding_bottom or 0

    -- Calculate border overhead for height
    local border_overhead_height = 0
    if is_outer_border then
        border_overhead_height = border_overhead_height + 2 * (ob_thickness + ob_sep)
    end
    if _G.content.border_on then
        border_overhead_height = border_overhead_height + b_padding_top + b_padding_bottom + b_thickness
    end
    _G.content.border_overhead_height = border_overhead_height

    -- Calculate available height for text
    local available_height = p_height - m_top - m_bottom - border_overhead_height
    _G.content.available_height = available_height

    -- Auto-calculate grid_width if banxin is on AND no explicit grid_width was provided
    -- Note: We only calculate if grid_width is 0 or empty (not explicitly set)
    if banxin_on and _G.content.page_columns > 0 and (_G.content.grid_width or 0) == 0 then
        local border_overhead_width = b_thickness
        if is_outer_border then
            border_overhead_width = border_overhead_width + 2 * (ob_thickness + ob_sep)
        end
        local raw_width = p_width - m_left - m_right - border_overhead_width
        _G.content.grid_width = math.floor(raw_width / _G.content.page_columns)
    end

    -- Auto-calculate grid_height and content_height based on n_char_per_col
    local n_char = _G.content.n_char_per_col or 0
    local grid_h = _G.content.grid_height or 0

    if n_char > 0 and available_height > 0 then
        -- Mode A: n-char-per-col specified, calculate grid-height
        _G.content.grid_height = math.floor(available_height / n_char)
        _G.content.content_height = _G.content.grid_height * n_char
    elseif grid_h > 0 and available_height > 0 then
        -- Mode B: grid-height specified, calculate fitting rows
        local rows = math.floor(available_height / grid_h)
        _G.content.content_height = grid_h * rows
    end
end

--- 设置后续文字的字体颜色
-- @param p_head (node) 节点列表头部（直接引用）
-- @param font_rgb_str (string) 归一化的 RGB 颜色字符串
-- @return (node) 更新后的头部
local function set_font_color(p_head, font_rgb_str)
    if not font_rgb_str then
        return p_head
    end

    -- Set fill color for text
    local literal = utils.create_color_literal(font_rgb_str, false)
    p_head = utils.insert_pdf_literal(p_head, literal)

    return p_head
end

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

    local b_thickness_bp = border_thickness * sp_to_bp
    local half_thickness = math.floor(border_thickness / 2)

    for col = 0, total_cols - 1 do
        -- Skip banxin columns (they are drawn separately by banxin module)
        if not banxin_cols[col] then
            local rtl_col = total_cols - 1 - col
            local tx_bp = (rtl_col * grid_width + half_thickness + shift_x) * sp_to_bp
            local ty_bp = -(half_thickness + outer_shift) * sp_to_bp
            local tw_bp = grid_width * sp_to_bp
            local th_bp = -(line_limit * grid_height + b_padding_top + b_padding_bottom) * sp_to_bp

            -- Draw column border
            local literal = utils.create_border_literal(b_thickness_bp, border_rgb_str, tx_bp, ty_bp, tw_bp, th_bp)
            p_head = utils.insert_pdf_literal(p_head, literal)
        end
    end

    return p_head
end

--- 在整个内容区域外围绘制外边框
-- @param p_head (node) 节点列表头部（直接引用）
-- @param params (table) 参数表:
--   - inner_width: 内部内容宽度 (sp)
--   - inner_height: 内部内容高度 (sp)
--   - outer_border_thickness: 外边框厚度 (sp)
--   - outer_border_sep: 内外边框间距 (sp)
--   - border_rgb_str: 归一化的 RGB 颜色字符串
-- @return (node) 更新后的头部
local function draw_outer_border(p_head, params)
    local sp_to_bp = utils.sp_to_bp
    local inner_width = params.inner_width
    local inner_height = params.inner_height
    local ob_thickness_val = params.outer_border_thickness
    local ob_sep_val = params.outer_border_sep
    local border_rgb_str = params.border_rgb_str

    local ob_thickness_bp = ob_thickness_val * sp_to_bp

    local tx_bp = (ob_thickness_bp / 2)
    local ty_bp = -(ob_thickness_bp / 2)
    local tw_bp = (inner_width + ob_sep_val * 2 + ob_thickness_val) * sp_to_bp
    local th_bp = -(inner_height + ob_sep_val * 2 + ob_thickness_val) * sp_to_bp

    local literal = utils.create_border_literal(ob_thickness_bp, border_rgb_str, tx_bp, ty_bp, tw_bp, th_bp)
    p_head = utils.insert_pdf_literal(p_head, literal)

    return p_head
end

--- 绘制矩形边框
-- @param p_head (node) 节点列表头部
-- @param params (table) 参数表:
--   - x: 左上角 X 坐标 (sp)
--   - y: 左上角 Y 坐标 (sp，向下为负)
--   - width: 宽度 (sp)
--   - height: 高度 (sp)
--   - line_width: 线宽 (sp)
--   - color_str: RGB 颜色字符串
-- @return (node) 更新后的头部
local function draw_rect_frame(p_head, params)
    local sp_to_bp = utils.sp_to_bp
    local x_bp = params.x * sp_to_bp
    local y_bp = params.y * sp_to_bp
    local w_bp = params.width * sp_to_bp
    local h_bp = params.height * sp_to_bp
    local lw_bp = params.line_width * sp_to_bp
    local color_str = params.color_str or "0 0 0"

    -- Simple rectangular stroke
    local literal = string.format([[
q %s RG %.2f w
%.4f %.4f %.4f %.4f re S Q]],
        color_str, lw_bp,
        x_bp, y_bp - h_bp, w_bp, h_bp
    )

    return utils.insert_pdf_literal(p_head, literal)
end

--- 绘制填充八角形（背景）
-- @param p_head (node) 节点列表头部
-- @param params (table) 参数表:
--   - x: 左上角 X 坐标 (sp)
--   - y: 左上角 Y 坐标 (sp，向下为负)
--   - width: 宽度 (sp)
--   - height: 高度 (sp)
--   - color_str: RGB 填充颜色字符串
-- @return (node) 更新后的头部
local function draw_octagon_fill(p_head, params)
    local sp_to_bp = utils.sp_to_bp
    local x_bp = params.x * sp_to_bp
    local y_bp = params.y * sp_to_bp
    local w_bp = params.width * sp_to_bp
    local h_bp = params.height * sp_to_bp
    local color_str = params.color_str or "0.5 0.5 0.5"

    -- Calculate corner cut size (20% of smaller dimension)
    local corner = math.min(w_bp, h_bp) * 0.2

    local literal = string.format([[
q %s rg
%.4f %.4f m
%.4f %.4f l %.4f %.4f l %.4f %.4f l %.4f %.4f l
%.4f %.4f l %.4f %.4f l %.4f %.4f l h f Q]],
        color_str,
        x_bp + corner, y_bp,
        x_bp + w_bp - corner, y_bp,
        x_bp + w_bp, y_bp - corner,
        x_bp + w_bp, y_bp - h_bp + corner,
        x_bp + w_bp - corner, y_bp - h_bp,
        x_bp + corner, y_bp - h_bp,
        x_bp, y_bp - h_bp + corner,
        x_bp, y_bp - corner
    )

    return utils.insert_pdf_literal(p_head, literal)
end

--- 绘制填充圆形（背景）
-- @param p_head (node) 节点列表头部
-- @param params (table) 参数表:
--   - cx: 圆心 X 坐标 (sp)
--   - cy: 圆心 Y 坐标 (sp)
--   - radius: 半径 (sp)
--   - color_str: RGB 填充颜色字符串
-- @return (node) 更新后的头部
local function draw_circle_fill(p_head, params)
    local sp_to_bp = utils.sp_to_bp
    local cx_bp = params.cx * sp_to_bp
    local cy_bp = params.cy * sp_to_bp
    local r_bp = params.radius * sp_to_bp
    local color_str = params.color_str or "0.5 0.5 0.5"

    -- Bezier approximation constant: 4/3 * (sqrt(2) - 1)
    local k = 0.5523
    local kappa = r_bp * k

    local literal = string.format([[
q %s rg
%.4f %.4f m
%.4f %.4f %.4f %.4f %.4f %.4f c
%.4f %.4f %.4f %.4f %.4f %.4f c
%.4f %.4f %.4f %.4f %.4f %.4f c
%.4f %.4f %.4f %.4f %.4f %.4f c f Q]],
        color_str,
        cx_bp + r_bp, cy_bp,
        cx_bp + r_bp, cy_bp + kappa, cx_bp + kappa, cy_bp + r_bp, cx_bp, cy_bp + r_bp,
        cx_bp - kappa, cy_bp + r_bp, cx_bp - r_bp, cy_bp + kappa, cx_bp - r_bp, cy_bp,
        cx_bp - r_bp, cy_bp - kappa, cx_bp - kappa, cy_bp - r_bp, cx_bp, cy_bp - r_bp,
        cx_bp + kappa, cy_bp - r_bp, cx_bp + r_bp, cy_bp - kappa, cx_bp + r_bp, cy_bp
    )

    return utils.insert_pdf_literal(p_head, literal)
end

--- 绘制八角形边框
-- @param p_head (node) 节点列表头部
-- @param params (table) 参数表:
--   - x: 左上角 X 坐标 (sp)
--   - y: 左上角 Y 坐标 (sp，向下为负)
--   - width: 宽度 (sp)
--   - height: 高度 (sp)
--   - line_width: 线宽 (sp)
--   - color_str: RGB 颜色字符串
-- @return (node) 更新后的头部
local function draw_octagon_frame(p_head, params)
    local sp_to_bp = utils.sp_to_bp
    local x_bp = params.x * sp_to_bp
    local y_bp = params.y * sp_to_bp
    local w_bp = params.width * sp_to_bp
    local h_bp = params.height * sp_to_bp
    local lw_bp = params.line_width * sp_to_bp
    local color_str = params.color_str or "0 0 0"

    -- Calculate corner cut size (20% of smaller dimension)
    local corner = math.min(w_bp, h_bp) * 0.2

    local literal = string.format([[
q %s RG %.2f w
%.4f %.4f m
%.4f %.4f l %.4f %.4f l %.4f %.4f l %.4f %.4f l
%.4f %.4f l %.4f %.4f l %.4f %.4f l h S Q]],
        color_str, lw_bp,
        x_bp + corner, y_bp,
        x_bp + w_bp - corner, y_bp,
        x_bp + w_bp, y_bp - corner,
        x_bp + w_bp, y_bp - h_bp + corner,
        x_bp + w_bp - corner, y_bp - h_bp,
        x_bp + corner, y_bp - h_bp,
        x_bp, y_bp - h_bp + corner,
        x_bp, y_bp - corner
    )

    return utils.insert_pdf_literal(p_head, literal)
end

--- 绘制圆形边框（使用贝塞尔曲线近似）
-- @param p_head (node) 节点列表头部
-- @param params (table) 参数表:
--   - cx: 圆心 X 坐标 (sp)
--   - cy: 圆心 Y 坐标 (sp)
--   - radius: 半径 (sp)
--   - line_width: 线宽 (sp)
--   - color_str: RGB 颜色字符串
-- @return (node) 更新后的头部
local function draw_circle_frame(p_head, params)
    local sp_to_bp = utils.sp_to_bp
    local cx_bp = params.cx * sp_to_bp
    local cy_bp = params.cy * sp_to_bp
    local r_bp = params.radius * sp_to_bp
    local lw_bp = params.line_width * sp_to_bp
    local color_str = params.color_str or "0 0 0"

    -- Bezier approximation constant: 4/3 * (sqrt(2) - 1)
    local k = 0.5523
    local kappa = r_bp * k

    local literal = string.format([[
q %s RG %.2f w
%.4f %.4f m
%.4f %.4f %.4f %.4f %.4f %.4f c
%.4f %.4f %.4f %.4f %.4f %.4f c
%.4f %.4f %.4f %.4f %.4f %.4f c
%.4f %.4f %.4f %.4f %.4f %.4f c S Q]],
        color_str, lw_bp,
        cx_bp + r_bp, cy_bp,
        cx_bp + r_bp, cy_bp + kappa, cx_bp + kappa, cy_bp + r_bp, cx_bp, cy_bp + r_bp,
        cx_bp - kappa, cy_bp + r_bp, cx_bp - r_bp, cy_bp + kappa, cx_bp - r_bp, cy_bp,
        cx_bp - r_bp, cy_bp - kappa, cx_bp - kappa, cy_bp - r_bp, cx_bp, cy_bp - r_bp,
        cx_bp + kappa, cy_bp - r_bp, cx_bp + r_bp, cy_bp - kappa, cx_bp + r_bp, cy_bp
    )

    return utils.insert_pdf_literal(p_head, literal)
end

-- Create module table
local content = {
    setup = setup,
    set_font_color = set_font_color,
    draw_column_borders = draw_column_borders,
    draw_outer_border = draw_outer_border,
    draw_rect_frame = draw_rect_frame,
    draw_octagon_fill = draw_octagon_fill,
    draw_octagon_frame = draw_octagon_frame,
    draw_circle_fill = draw_circle_fill,
    draw_circle_frame = draw_circle_frame,
}

-- Register module in package.loaded
package.loaded['core.luatex-cn-core-content'] = content

return content
