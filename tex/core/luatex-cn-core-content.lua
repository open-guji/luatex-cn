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
local drawing = package.loaded['util.luatex-cn-drawing'] or
    require('util.luatex-cn-drawing')

-- ============================================================================
-- Shared Layout Calculation Helpers
-- ============================================================================

--- Calculate border overhead for width
-- @param border_on (bool) Inner border enabled
-- @param outer_border_on (bool) Outer border enabled
-- @param b_thickness (number) Inner border thickness (sp)
-- @param ob_thickness (number) Outer border thickness (sp)
-- @param ob_sep (number) Outer border separation (sp)
-- @return (number) Total width overhead from borders (sp)
local function calc_border_overhead_width(border_on, outer_border_on, b_thickness, ob_thickness, ob_sep)
    local overhead = 0
    if outer_border_on then
        overhead = overhead + 2 * (ob_thickness + ob_sep)
    end
    if border_on then
        overhead = overhead + b_thickness
    end
    return overhead
end

--- Calculate border overhead for height
-- @param border_on (bool) Inner border enabled
-- @param outer_border_on (bool) Outer border enabled
-- @param b_thickness (number) Inner border thickness (sp)
-- @param ob_thickness (number) Outer border thickness (sp)
-- @param ob_sep (number) Outer border separation (sp)
-- @param b_padding_top (number) Border top padding (sp)
-- @param b_padding_bottom (number) Border bottom padding (sp)
-- @return (number) Total height overhead from borders (sp)
local function calc_border_overhead_height(border_on, outer_border_on, b_thickness, ob_thickness, ob_sep, b_padding_top, b_padding_bottom)
    local overhead = 0
    if outer_border_on then
        overhead = overhead + 2 * (ob_thickness + ob_sep)
    end
    if border_on then
        overhead = overhead + b_padding_top + b_padding_bottom + b_thickness
    end
    return overhead
end

--- Calculate grid_height and content_height from available height
-- @param available_height (number) Available height for content (sp)
-- @param n_char_per_col (number) Characters per column (0 = not specified)
-- @param existing_grid_height (number) Existing grid height (sp, 0 = not specified)
-- @return grid_height (sp), content_height (sp)
local function calc_grid_dimensions(available_height, n_char_per_col, existing_grid_height)
    local grid_height, content_height
    if n_char_per_col > 0 and available_height > 0 then
        -- Mode A: n-char-per-col specified, calculate grid-height
        grid_height = math.floor(available_height / n_char_per_col)
        content_height = grid_height * n_char_per_col
    elseif existing_grid_height > 0 and available_height > 0 then
        -- Mode B: grid-height specified, calculate fitting rows
        grid_height = existing_grid_height
        local rows = math.floor(available_height / grid_height)
        content_height = grid_height * rows
    else
        -- Fallback: use available height
        grid_height = existing_grid_height
        content_height = available_height
    end
    return grid_height, content_height
end

-- ============================================================================
-- Global Content State
-- ============================================================================

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

-- ============================================================================
-- Setup Helper Functions
-- ============================================================================

--- Parse border and layout parameters from TeX
-- @param params (table) Parameters from TeX keyvals
local function parse_border_params(params)
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
end

--- Parse visual parameters from TeX (colors, font_size, etc.)
-- @param params (table) Parameters from TeX keyvals
local function parse_visual_params(params)
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
end

--- Push content base style to style stack
local function push_content_base_style()
    local style_registry = package.loaded['util.luatex-cn-style-registry'] or
        require('util.luatex-cn-style-registry')

    -- Helper to convert sp to pt string for style registry
    local function sp_to_pt_str(sp)
        if not sp or sp == 0 then return nil end
        return string.format("%.5fpt", sp / 65536)
    end

    local base_style = {
        indent = 0,
        first_indent = -1,  -- -1 means inherit from indent
        -- Border parameters (boolean flags and style values)
        border = _G.content.border_on or false,
        border_width = sp_to_pt_str(_G.content.border_thickness),
        border_color = _G.content.border_color or "0 0 0",
        outer_border = _G.content.outer_border_on or false,
    }
    if _G.content.font_color then
        base_style.font_color = _G.content.font_color
    end
    if _G.content.font_size then
        base_style.font_size = _G.content.font_size
    end

    _G.content_style_id = style_registry.push(base_style)
end

--- Calculate available width from page dimensions and borders
local function calc_available_width()
    local b_thickness = _G.content.border_on and _G.content.border_thickness or 0
    local is_outer_border = _G.content.outer_border_on
    local ob_thickness = _G.content.outer_border_thickness or 0
    local ob_sep = _G.content.outer_border_sep or 0

    local p_width = _G.page and _G.page.paper_width or 0
    local m_left = _G.page and _G.page.margin_left or 0
    local m_right = _G.page and _G.page.margin_right or 0

    local available_width = p_width - m_left - m_right - b_thickness
    if is_outer_border then
        available_width = available_width - 2 * (ob_thickness + ob_sep)
    end
    _G.content.available_width = available_width
end

--- Calculate page_columns based on available width and settings
-- @param explicit_page_cols (number) Explicitly set page columns (0 if not set)
local function calc_page_columns(explicit_page_cols)
    local banxin_on = _G.banxin and _G.banxin.enabled
    local n_column = _G.content.n_column or 8
    local g_width = _G.content.grid_width or 0
    local available_width = _G.content.available_width or 0

    if explicit_page_cols > 0 then
        _G.content.page_columns = explicit_page_cols
    elseif banxin_on then
        _G.content.page_columns = (2 * n_column + 1)
    elseif g_width > 0 and available_width > 0 then
        _G.content.page_columns = math.floor(available_width / g_width + 0.1)
        if _G.content.page_columns <= 0 then _G.content.page_columns = 1 end
    else
        _G.content.page_columns = math.max(1, n_column)
    end
end

--- Calculate auto-layout dimensions (grid_width, grid_height, content_height)
local function calc_auto_layout()
    local b_thickness = _G.content.border_on and _G.content.border_thickness or 0
    local is_outer_border = _G.content.outer_border_on
    local ob_thickness = _G.content.outer_border_thickness or 0
    local ob_sep = _G.content.outer_border_sep or 0
    local b_padding_top = _G.content.border_padding_top or 0
    local b_padding_bottom = _G.content.border_padding_bottom or 0
    local banxin_on = _G.banxin and _G.banxin.enabled

    local p_width = _G.page and _G.page.paper_width or 0
    local p_height = _G.page and _G.page.paper_height or 0
    local m_left = _G.page and _G.page.margin_left or 0
    local m_right = _G.page and _G.page.margin_right or 0
    local m_top = _G.page and _G.page.margin_top or 0
    local m_bottom = _G.page and _G.page.margin_bottom or 0

    -- Calculate border overhead for height
    local border_overhead_height = calc_border_overhead_height(
        _G.content.border_on, is_outer_border, b_thickness, ob_thickness, ob_sep, b_padding_top, b_padding_bottom)
    _G.content.border_overhead_height = border_overhead_height

    -- Calculate available height for text
    local available_height = p_height - m_top - m_bottom - border_overhead_height
    _G.content.available_height = available_height

    -- Auto-calculate grid_width if banxin is on AND no explicit grid_width was provided
    if banxin_on and _G.content.page_columns > 0 and (_G.content.grid_width or 0) == 0 then
        local border_overhead_width = calc_border_overhead_width(
            _G.content.border_on, is_outer_border, b_thickness, ob_thickness, ob_sep)
        local raw_width = p_width - m_left - m_right - border_overhead_width
        _G.content.grid_width = math.floor(raw_width / _G.content.page_columns)
    end

    -- Auto-calculate grid_height and content_height
    local n_char = _G.content.n_char_per_col or 0
    local grid_h = _G.content.grid_height or 0
    local new_grid_h, new_content_h = calc_grid_dimensions(available_height, n_char, grid_h)
    if n_char > 0 or grid_h > 0 then
        _G.content.grid_height = new_grid_h
        _G.content.content_height = new_content_h
    end
end

--- Sync content parameters from TeX to Lua (idempotent, can be called multiple times)
-- @param params (table) Parameters from TeX keyvals
local function sync_params(params)
    params = params or {}

    -- 1. Parse parameters
    parse_border_params(params)
    parse_visual_params(params)

    -- 2. Calculate layout dimensions
    local explicit_page_cols = tonumber(params.page_columns) or 0
    calc_available_width()
    calc_page_columns(explicit_page_cols)
    calc_auto_layout()
end

--- Initialize content style (call once per content block, before processing)
local function init_style()
    push_content_base_style()
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

-- ============================================================================
-- Guji Auto-Layout: Calculate grid dimensions and set TeX token lists
-- ============================================================================

--- Calculate guji layout and set TeX token lists directly
-- @param params Table with layout parameters (passed from TeX)
local function guji_auto_layout(params)
    params = params or {}

    -- Get page dimensions from _G.page (already synced)
    local p_width = _G.page and _G.page.paper_width or 0
    local p_height = _G.page and _G.page.paper_height or 0
    local m_left = _G.page and _G.page.margin_left or 0
    local m_right = _G.page and _G.page.margin_right or 0
    local m_top = _G.page and _G.page.margin_top or 0
    local m_bottom = _G.page and _G.page.margin_bottom or 0

    -- Get content parameters from params (passed from TeX)
    local n_column = tonumber(params.n_column) or 8
    local n_char_per_col = tonumber(params.n_char_per_col) or 0
    local border_on = params.border_on
    local outer_border_on = params.outer_border_on
    local b_thickness = border_on and constants.to_dimen(params.border_thickness or "0pt") or 0
    local ob_thickness = constants.to_dimen(params.outer_border_thickness or "0pt")
    local ob_sep = constants.to_dimen(params.outer_border_sep or "0pt")
    local b_padding_top = constants.to_dimen(params.border_padding_top or "0pt")
    local b_padding_bottom = constants.to_dimen(params.border_padding_bottom or "0pt")
    local existing_grid_height = constants.to_dimen(params.grid_height or "0pt")

    -- I. Width Logic: Calculate grid-width from n-column
    local border_overhead_width = calc_border_overhead_width(border_on, outer_border_on, b_thickness, ob_thickness, ob_sep)
    local available_width = p_width - m_left - m_right - border_overhead_width
    local total_cols = 2 * n_column + 1  -- guji with banxin
    local grid_width = math.floor(available_width / total_cols)

    -- II. Height Logic: Calculate available height
    local border_overhead_height = calc_border_overhead_height(border_on, outer_border_on, b_thickness, ob_thickness, ob_sep, b_padding_top, b_padding_bottom)
    local available_height = p_height - m_top - m_bottom - border_overhead_height
    local grid_height, content_height = calc_grid_dimensions(available_height, n_char_per_col, existing_grid_height)

    -- Calculate adjusted margin-top (bottom-aligned content)
    local total_box_height = content_height + border_overhead_height + 2 * 65536 -- +2pt
    local margin_top = p_height - m_bottom - total_box_height

    -- Convert sp to pt string and set TeX token lists
    local function to_pt(sp) return string.format("%.5fpt", sp / 65536) end
    token.set_macro("l__luatexcn_content_grid_width_tl", to_pt(grid_width))
    token.set_macro("l__luatexcn_content_grid_height_tl", to_pt(grid_height))
    token.set_macro("l__luatexcn_content_height_tl", to_pt(content_height))
    token.set_macro("l__luatexcn_page_margin_top_tl", to_pt(margin_top))
end

-- Create module table
local content = {
    sync_params = sync_params,
    init_style = init_style,
    set_font_color = set_font_color,
    draw_column_borders = draw_column_borders,
    draw_outer_border = draw_outer_border,
    guji_auto_layout = guji_auto_layout,
    -- Re-export drawing functions for backward compatibility
    draw_rect_frame = drawing.draw_rect_frame,
    draw_octagon_fill = drawing.draw_octagon_fill,
    draw_octagon_frame = drawing.draw_octagon_frame,
    draw_circle_fill = drawing.draw_circle_fill,
    draw_circle_frame = drawing.draw_circle_frame,
}

-- Register module in package.loaded
package.loaded['core.luatex-cn-core-content'] = content

return content
