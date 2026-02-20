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
-- core_content.lua - 内容配置与布局模块
-- ============================================================================
-- 文件名: luatex-cn-core-content.lua
-- 层级: 配置层 (Configuration Layer)
--
-- 【模块功能 / Module Purpose】
-- 本模块负责内容区域的配置和布局计算：
--   1. sync_params: 从 TeX 同步内容参数到 Lua (_G.content)
--   2. init_style: 初始化 style stack 基础样式
--   3. set_font_color: 设置后续所有文字的填充颜色
--   4. guji_auto_layout: 古籍自动布局计算（网格尺寸等）
--
-- 注意：边框绘制已移至 luatex-cn-core-render-border.lua
--
-- ============================================================================

-- Load dependencies
local utils = package.loaded['util.luatex-cn-utils'] or
    require('util.luatex-cn-utils')
local constants = package.loaded['core.luatex-cn-constants'] or
    require('core.luatex-cn-constants')

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
-- Organized according to CONTENT_REDESIGN.md three-layer architecture
_G.content = _G.content or {}

-- ========== Total Box (Page - Margins) ==========
_G.content.total_width = _G.content.total_width or 0
_G.content.total_height = _G.content.total_height or 0

-- ========== Border Parameters ==========
-- Outer border
_G.content.outer_border_on = _G.content.outer_border_on or false
_G.content.outer_border_thickness = _G.content.outer_border_thickness or (65536 * 2)
_G.content.outer_border_sep = _G.content.outer_border_sep or (65536 * 2)
_G.content.outer_border_color = _G.content.outer_border_color or "0 0 0"  -- New: for future use

-- Inner border
_G.content.border_on = _G.content.border_on or false
_G.content.border_thickness = _G.content.border_thickness or 26214 -- 0.4pt
_G.content.border_color = _G.content.border_color or "0 0 0"
_G.content.border_padding_top = _G.content.border_padding_top or 0
_G.content.border_padding_bottom = _G.content.border_padding_bottom or 0

-- ========== Content Area (Text Layout Area, excluding borders) ==========
_G.content.content_width = _G.content.content_width or 0
_G.content.content_height = _G.content.content_height or 0

-- ========== Grid Layout Parameters ==========
_G.content.n_column = _G.content.n_column or 8
_G.content.n_char_per_col = _G.content.n_char_per_col or 0
_G.content.page_columns = _G.content.page_columns or 0
_G.content.grid_width = _G.content.grid_width or 0
_G.content.grid_height = _G.content.grid_height or 0
_G.content.banxin_width = _G.content.banxin_width or 0
_G.content.banxin_ratio = _G.content.banxin_ratio or 0.7

-- ========== Internal (border overhead tracking) ==========
_G.content.border_overhead_height = _G.content.border_overhead_height or 0

-- ========== Visual Parameters ==========
_G.content.vertical_align = _G.content.vertical_align or "center"
_G.content.background_color = _G.content.background_color or nil
_G.content.font_color = _G.content.font_color or nil
_G.content.font_size = _G.content.font_size or 0

-- ========== Unified Layout Engine Parameters ==========
_G.content.layout_mode = _G.content.layout_mode or "grid"
_G.content.inter_cell_gap = _G.content.inter_cell_gap or 0
_G.content.cell_height = _G.content.cell_height or nil
_G.content.cell_width = _G.content.cell_width or nil
_G.content.cell_gap = _G.content.cell_gap or nil

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
    if params.layout_mode and params.layout_mode ~= "" then
        _G.content.layout_mode = params.layout_mode
    end
    if params.inter_cell_gap then
        _G.content.inter_cell_gap = constants.to_dimen(params.inter_cell_gap) or 0
    end
    if params.cell_height and params.cell_height ~= "" then
        _G.content.cell_height = constants.to_dimen(params.cell_height)
    end
    if params.cell_width and params.cell_width ~= "" then
        _G.content.cell_width = constants.to_dimen(params.cell_width)
    end
    if params.cell_gap and params.cell_gap ~= "" then
        _G.content.cell_gap = constants.to_dimen(params.cell_gap)
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
        -- Outer border dimensions (stored as sp for direct use)
        outer_border_thickness = _G.content.outer_border_thickness or (65536 * 2),
        outer_border_sep = _G.content.outer_border_sep or (65536 * 2),
        -- Background color (nil means no background)
        background_color = _G.content.background_color,
        -- Cell layout params (unified engine)
        cell_height = _G.content.cell_height
            or ((_G.content.layout_mode == "grid") and _G.content.grid_height or nil),
        cell_width = _G.content.cell_width or nil,
        cell_gap = _G.content.cell_gap
            or ((_G.content.layout_mode ~= "grid") and _G.content.inter_cell_gap or 0),
    }
    if _G.content.font_color then
        base_style.font_color = _G.content.font_color
    end
    if _G.content.font_size then
        base_style.font_size = _G.content.font_size
    end

    style_registry.push(base_style)
end

--- Calculate total box and content area width from page dimensions
-- Implements three-layer structure: Page → Total Box → Content Area
local function calc_content_area_width()
    local p_width = _G.page and _G.page.paper_width or 0
    local m_left = _G.page and _G.page.margin_left or 0
    local m_right = _G.page and _G.page.margin_right or 0

    -- Layer 1: Total Box (Page - Margins)
    local total_width = p_width - m_left - m_right
    _G.content.total_width = total_width

    -- Layer 2: Border overhead
    local b_thickness = _G.content.border_on and _G.content.border_thickness or 0
    local is_outer_border = _G.content.outer_border_on
    local ob_thickness = _G.content.outer_border_thickness or 0
    local ob_sep = _G.content.outer_border_sep or 0

    local border_overhead_width = calc_border_overhead_width(
        _G.content.border_on, is_outer_border, b_thickness, ob_thickness, ob_sep)

    -- Layer 3: Content Area (Total - Border)
    local content_width = total_width - border_overhead_width
    _G.content.content_width = content_width
end

--- Calculate page_columns based on content area width and settings
-- @param explicit_page_cols (number) Explicitly set page columns (0 if not set)
local function calc_page_columns(explicit_page_cols)
    local banxin_on = _G.banxin and _G.banxin.enabled
    local n_column = _G.content.n_column or 8
    local g_width = _G.content.grid_width or 0
    local content_width = _G.content.content_width or 0

    -- Free Mode: n_column=0 means variable-width columns, no fixed page_columns
    if n_column == 0 and explicit_page_cols <= 0 then
        _G.content.page_columns = nil
        return
    end

    -- When col_widths has entries, set page_columns from it directly
    local col_widths = _G.content and _G.content.col_widths
    if col_widths and #col_widths > 0 then
        _G.content.page_columns = #col_widths
        return
    end

    if explicit_page_cols > 0 then
        _G.content.page_columns = explicit_page_cols
        -- Auto-adjust grid_width to fill content area width when page_columns is explicit
        if content_width > 0 then
            _G.content.grid_width = math.floor(content_width / explicit_page_cols)
        end
    elseif banxin_on then
        _G.content.page_columns = (2 * n_column + 1)
    elseif g_width > 0 and content_width > 0 then
        -- Use +0.5 rounding to handle banxin_ratio-induced fractional column counts
        -- e.g. content_width / (content_width / 16.7) = 16.7 → round to 17
        _G.content.page_columns = math.floor(content_width / g_width + 0.5)
        if _G.content.page_columns <= 0 then _G.content.page_columns = 1 end
    else
        _G.content.page_columns = math.max(1, n_column)
    end
end

--- Calculate auto-layout dimensions using three-layer structure
-- Layer 1: Total Box (Page - Margins)
-- Layer 2: Border overhead
-- Layer 3: Content Area (Total - Border)
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

    -- ========== Layer 1: Total Box ==========
    local total_width = p_width - m_left - m_right
    local total_height = p_height - m_top - m_bottom
    _G.content.total_width = total_width
    _G.content.total_height = total_height

    -- ========== Layer 2: Border Overhead ==========
    local border_overhead_width = calc_border_overhead_width(
        _G.content.border_on, is_outer_border, b_thickness, ob_thickness, ob_sep)

    local border_overhead_height = calc_border_overhead_height(
        _G.content.border_on, is_outer_border, b_thickness, ob_thickness, ob_sep, b_padding_top, b_padding_bottom)

    -- Store for backward compatibility
    _G.content.border_overhead_height = border_overhead_height

    -- ========== Layer 3: Content Area ==========
    local content_width = total_width - border_overhead_width
    local content_height = total_height - border_overhead_height
    _G.content.content_width = content_width
    _G.content.content_height = content_height

    -- ========== Grid Parameters Calculation ==========
    -- Auto-calculate grid_width if banxin is on AND no explicit grid_width was provided
    if banxin_on and (_G.content.page_columns or 0) > 0 and (_G.content.grid_width or 0) == 0 then
        local ratio = _G.content.banxin_ratio or 0.7
        local n_col = _G.content.n_column or 8
        _G.content.grid_width = math.floor(content_width / (2 * n_col + ratio))
        _G.content.banxin_width = math.floor(_G.content.grid_width * ratio)
    end

    -- Auto-calculate grid_height from content_height
    local n_char = _G.content.n_char_per_col or 0
    local grid_h = _G.content.grid_height or 0
    local new_grid_h, new_content_h = calc_grid_dimensions(content_height, n_char, grid_h)
    if n_char > 0 or grid_h > 0 then
        _G.content.grid_height = new_grid_h
        -- Note: new_content_h may be grid-aligned, but we keep the raw content_height
        -- for accurate layout decisions (content_height already set above)
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
    calc_content_area_width()
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

    -- I. Width Logic: Calculate grid-width from n-column (with banxin ratio)
    local banxin_ratio = tonumber(params.banxin_ratio) or 0.7
    local border_overhead_width = calc_border_overhead_width(border_on, outer_border_on, b_thickness, ob_thickness, ob_sep)
    local available_width = p_width - m_left - m_right - border_overhead_width
    -- cw * (2 * n_column + ratio) = available_width
    local grid_width = math.floor(available_width / (2 * n_column + banxin_ratio))
    local banxin_width = math.floor(grid_width * banxin_ratio)

    -- II. Height Logic: Calculate available height
    local border_overhead_height = calc_border_overhead_height(border_on, outer_border_on, b_thickness, ob_thickness, ob_sep, b_padding_top, b_padding_bottom)
    local available_height = p_height - m_top - m_bottom - border_overhead_height
    local grid_height, content_height = calc_grid_dimensions(available_height, n_char_per_col, existing_grid_height)

    -- Calculate adjusted margin-top (bottom-aligned content)
    local total_box_height = content_height + border_overhead_height + 2 * 65536 -- +2pt
    local margin_top = p_height - m_bottom - total_box_height

    -- Store banxin dimensions in global state
    _G.content.banxin_width = banxin_width
    _G.content.banxin_ratio = banxin_ratio

    -- Convert sp to pt string and set TeX token lists
    local function to_pt(sp) return string.format("%.5fpt", sp / 65536) end
    token.set_macro("l__luatexcn_content_grid_width_tl", to_pt(grid_width))
    token.set_macro("l__luatexcn_content_grid_height_tl", to_pt(grid_height))
    token.set_macro("l__luatexcn_content_height_tl", to_pt(content_height))
    token.set_macro("l__luatexcn_page_margin_top_tl", to_pt(margin_top))
end

-- ============================================================================
-- Shared Content Dimension Calculation
-- ============================================================================

--- Calculate content area dimensions (shared by render-page and render-border)
-- @param params (table) {is_textbox, actual_cols, actual_height_sp, grid_width, grid_height,
--   content_height_sp, b_padding_top, b_padding_bottom, p_total_cols, border_thickness,
--   banxin_width, interval}
-- @return content_width, content_height, inner_width, inner_height (all in sp)
local function calculate_content_dimensions(params)
    local content_width, content_height
    local col_widths = _G.content and _G.content.col_widths
    if params.is_textbox then
        content_width = (params.actual_cols > 0 and params.actual_cols or 1) * params.grid_width
        content_height = params.actual_height_sp > 0 and params.actual_height_sp or params.grid_height
    elseif col_widths and #col_widths > 0 then
        content_width = 0
        for _, w in ipairs(col_widths) do content_width = content_width + w end
        content_height = params.content_height_sp + params.b_padding_top + params.b_padding_bottom
    else
        local bw = params.banxin_width or 0
        local iv = params.interval or 0
        if iv > 0 and bw > 0 and bw ~= params.grid_width then
            local n_banxin = math.floor(params.p_total_cols / (iv + 1))
            local n_content = params.p_total_cols - n_banxin
            content_width = n_content * params.grid_width + n_banxin * bw
        else
            content_width = params.p_total_cols * params.grid_width
        end
        content_height = params.content_height_sp + params.b_padding_top + params.b_padding_bottom
    end
    local inner_width = content_width + params.border_thickness
    local inner_height = content_height + params.border_thickness
    return content_width, content_height, inner_width, inner_height
end

-- ============================================================================
-- col_widths Lifecycle API
-- ============================================================================

--- Initialize col_widths array (call at TitlePage begin)
local function init_col_widths()
    _G.content = _G.content or {}
    _G.content.col_widths = {}
end

--- Register a column's width (call from Column when width is specified)
-- Only takes effect when col_widths has been initialized (TitlePage mode).
-- In normal BodyText, col_widths is nil and registration is silently ignored.
-- @param width_sp (number) Column width in scaled points
local function register_col_width(width_sp)
    if not (_G.content and _G.content.col_widths) then return end
    table.insert(_G.content.col_widths, width_sp)
end

--- Get the col_widths table (read-only access)
-- @return (table|nil) Array of column widths in sp, or nil
local function get_col_widths()
    return _G.content and _G.content.col_widths
end

--- Sync page_columns from col_widths count (call at TitlePage end)
local function sync_page_columns_from_col_widths()
    local cw = _G.content and _G.content.col_widths
    if cw and #cw > 0 then
        _G.content.page_columns = #cw
    end
end

--- Clear col_widths after page is shipped (call after TitlePage end)
local function clear_col_widths()
    if _G.content then
        _G.content.col_widths = nil
    end
end

-- Create module table
local content = {
    sync_params = sync_params,
    init_style = init_style,
    set_font_color = set_font_color,
    guji_auto_layout = guji_auto_layout,
    calculate_content_dimensions = calculate_content_dimensions,
    init_col_widths = init_col_widths,
    register_col_width = register_col_width,
    get_col_widths = get_col_widths,
    sync_page_columns_from_col_widths = sync_page_columns_from_col_widths,
    clear_col_widths = clear_col_widths,
}

-- Register module in package.loaded
package.loaded['core.luatex-cn-core-content'] = content

return content
