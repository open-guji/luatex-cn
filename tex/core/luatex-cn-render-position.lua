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
-- render_position.lua - 统一文字定位工具
-- ============================================================================
-- 文件名: render_position.lua (原 text_position.lua)
-- 层级: 第三阶段 - 渲染层 (Stage 3: Render Layer)
--
-- 【模块功能 / Module Purpose】
-- 本模块提供了文字字符在网格单元中的定位计算，被主文本和版心文本共同复用：
--   1. position_glyph: 在指定坐标处放置单个字符，处理居中对齐
--   2. create_vertical_text: 创建竖排文字链（用于版心鱼尾文字）
--   3. calc_grid_position: 纯坐标计算（不创建节点，用于 render.lua）
--
-- 【注意事项】
--   • 所有定位函数都考虑了字符的 height 和 depth，保证基线对齐正确
--   • xoffset/yoffset 是 LuaTeX 的 glyph 专用字段，block 节点不支持
--   • 每个字符后会插入负 kern（-width），用于抵消 TLT 盒子的水平推进
--   • Kern 的 subtype=1（显式 kern），防止被 render.lua 清零
--   • vertical_align 支持 top/center/bottom 三种模式
--
-- 【整体架构】
--   公共接口:
--      ├─ calc_grid_position(col, row, dims, params)
--      │     → 返回 (x_offset, y_offset)，用于 render.lua 直接设置
--      ├─ position_glyph(glyph, x, y, params)
--      │     → 设置 glyph.xoffset/yoffset，返回 (glyph, kern)
--      └─ create_vertical_text(text, params)
--            → 创建完整的字符链（用于版心）
--
--
-- ============================================================================

-- Load dependencies
local constants = package.loaded['core.luatex-cn-constants'] or
    require('core.luatex-cn-constants')
local debug = package.loaded['debug.luatex-cn-debug'] or
    require('debug.luatex-cn-debug')
local dbg = debug.get_debugger('render')
local D = constants.D


--- 变宽列 X 偏移（用于 col_widths 模式）
-- col_widths 中的索引为逻辑列号+1（1-indexed），逻辑列0=最右列
-- @param rtl_col (number) 物理列号（从左数，0-indexed）
-- @param col_widths (table) 每列宽度数组（1-indexed，按逻辑列顺序）
-- @param total_cols (number) 总列数
-- @return (number) X 偏移 (sp)
local function get_column_x_var(rtl_col, col_widths, total_cols)
    local x = 0
    for i = 0, rtl_col - 1 do
        local logical_col = total_cols - 1 - i
        x = x + (col_widths[logical_col + 1] or 0)
    end
    return x
end

--- 变宽列宽度（用于 col_widths 模式）
-- @param col (number) 逻辑列号 (0-indexed)
-- @param col_widths (table) 每列宽度数组（1-indexed）
-- @return (number) 列宽 (sp)
local function get_column_width_var(col, col_widths)
    return col_widths[col + 1] or 0
end

--- 计算列的 X 偏移（支持版心列窄化）
-- 当版心列宽度与正文列不同时，不能用 rtl_col * grid_width。
-- @param rtl_col (number) 物理列号（RTL 转换后，从左数，0-indexed）
-- @param col_geom (table) 列几何参数 { grid_width, banxin_width, interval }
-- @return (number) X 偏移 (sp)
local function get_column_x(rtl_col, col_geom)
    local grid_width = col_geom.grid_width
    local banxin_width = col_geom.banxin_width or 0
    local interval = col_geom.interval or 0
    if interval <= 0 or banxin_width <= 0 or banxin_width == grid_width then
        return rtl_col * grid_width
    end
    local group_size = interval + 1
    local full_groups = math.floor(rtl_col / group_size)
    local remainder = rtl_col % group_size
    local x = full_groups * (interval * grid_width + banxin_width)
    if remainder < interval then
        x = x + remainder * grid_width
    else
        x = x + interval * grid_width
    end
    return x
end

--- 获取指定逻辑列的宽度
-- @param col (number) 逻辑列号 (0-indexed)
-- @param col_geom (table) 列几何参数 { grid_width, banxin_width, interval }
-- @return (number) 列宽 (sp)
local function get_column_width(col, col_geom)
    local grid_width = col_geom.grid_width
    local banxin_width = col_geom.banxin_width or 0
    local interval = col_geom.interval or 0
    if interval > 0 and banxin_width > 0 and banxin_width ~= grid_width then
        if (col % (interval + 1)) == interval then
            return banxin_width
        end
    end
    return grid_width
end

--- 计算 RTL 布局中的物理列号和 X 坐标
-- 在竖排 RTL 布局中，逻辑列号（从0开始向右）需要转换为物理列号（从右向左）。
--
-- @param col (number) 逻辑列号 (0-indexed)
-- @param total_cols (number) 总列数
-- @param col_geom (table) 列几何参数 { grid_width, banxin_width, interval }
-- @param half_thickness (number) 边框半厚度 (sp)
-- @param shift_x (number) X 偏移量 (sp)
-- @return (number, number) rtl_col, x_position
local function calculate_rtl_position(col, total_cols, col_geom, half_thickness, shift_x)
    local rtl_col = total_cols - 1 - col
    local x_pos = get_column_x(rtl_col, col_geom)
        + (half_thickness or 0) + (shift_x or 0)
    return rtl_col, x_pos
end

--- 计算 Y 坐标（基于行号）
-- @param row (number) 行号 (0-indexed)
-- @param grid_height (number) 网格高度 (sp)
-- @param shift_y (number) Y 偏移量 (sp)
-- @return (number) y_position
local function calculate_y_position(row, grid_height, shift_y)
    -- Original: -row * grid_height - shift_y
    return (-row * grid_height) - (shift_y or 0)
end

--- 在指定坐标处定位单个字形节点
-- 这是在精确位置放置字符的核心函数。
-- 它设置 xoffset/yoffset 并创建负 kern 以使字符堆叠。
--
-- @param glyph_direct (node) 要定位的字形节点的直接引用
-- @param x (number) 以 SCALED POINTS 为单位的 X 坐标（单元格左边缘）
-- @param y (number) 以 SCALED POINTS 为单位的 Y 坐标（单元格顶边缘，向下为负）
-- @param params (table) 参数表:
--   - cell_width (number) 单元格宽度，用于水平居中
--   - cell_height (number) 单元格高度，用于垂直居中
--   - h_align (string) 水平对齐: "left", "center", "right" (默认: "center")
--   - v_align (string) 垂直对齐: "top", "center", "bottom" (默认: "center")
-- @return (node, node) 字形节点和负 kern 节点（均为直接节点引用）
local function position_glyph(glyph_direct, x, y, params)
    params = params or {}
    local cell_width = params.cell_width or 0
    local cell_height = params.cell_height or 0
    local h_align = params.h_align or "center"
    local v_align = params.v_align or "center"

    -- Get glyph dimensions
    local g_width = params.g_width or D.getfield(glyph_direct, "width") or 0
    local g_height = params.g_height or D.getfield(glyph_direct, "height") or 0
    local g_depth = params.g_depth or D.getfield(glyph_direct, "depth") or 0

    -- If width is 0, try to guess or use a fallback for centering
    if g_width <= 0 then
        local f_data = font.getfont(D.getfield(glyph_direct, "font"))
        if f_data and f_data.size then
            g_width = f_data.size -- Assume square for CJK if unknown
        end
    end

    -- Calculate horizontal offset based on alignment
    local x_offset
    if h_align == "left" then
        x_offset = x
    elseif h_align == "right" then
        x_offset = x + cell_width - g_width
    else -- center
        x_offset = x + (cell_width - g_width) / 2
    end

    -- Calculate vertical offset based on alignment
    local char_total_height = g_height + g_depth
    local y_offset
    if v_align == "top" then
        y_offset = y - g_height
    elseif v_align == "bottom" then
        y_offset = y - cell_height + g_depth
    else -- center
        y_offset = y - (cell_height + char_total_height) / 2 + g_depth
    end

    -- Apply offsets
    D.setfield(glyph_direct, "xoffset", x_offset)
    D.setfield(glyph_direct, "yoffset", y_offset)

    -- --- Trace Logging (Removed for simplicity) ---
    -- if debug.is_enabled("render") then ... end

    -- Create protected negative kern (subtype 1 = explicit kern, won't be zeroed)
    local kern = D.new(constants.KERN)
    D.setfield(kern, "subtype", 1)
    D.setfield(kern, "kern", -D.getfield(glyph_direct, "width"))

    -- Link glyph to kern
    D.setlink(glyph_direct, kern)

    return glyph_direct, kern
end


--- 计算网格位置坐标（纯计算，不操作节点）
-- 供 render.lua 使用，用于主文本定位，其中节点被就地修改。
--
-- @param col (number) 列索引（从 0 开始）
-- @param row (number) 行索引（从 0 开始）
-- @param glyph_dims (table) 字形尺寸: width, height, depth
-- @param params (table) 参数表:
--   - grid_width (number) 每个网格单元的宽度 (sp)
--   - grid_height (number) 每个网格单元的高度 (sp)
--   - total_cols (number) 总列数（用于 RTL 计算）
--   - shift_x (number) 边距/边框的 X 轴偏移 (sp)
--   - shift_y (number) 边距/边框的 Y 轴偏移 (sp)
--   - v_align (string) 垂直对齐: "top", "center", "bottom"
--   - half_thickness (number) 边框厚度的一半 (sp)
-- @return (number, number) 字形的 x_offset, y_offset
local function get_visual_center(char_code, font_id)
    local f = font.getfont(font_id)
    if not (f and f.characters and f.characters[char_code]) then return nil end
    local c = f.characters[char_code]

    local bbox = c.boundingbox
    -- If not in characters table, try descriptions in raw data using character index
    if not bbox and c.index and f.shared and f.shared.rawdata and f.shared.rawdata.descriptions then
        local desc = f.shared.rawdata.descriptions[c.index]
        if desc and desc.boundingbox then
            bbox = desc.boundingbox
        end
    end

    -- This function is used ONLY for decoration symbols (●, │, ︴, etc.)
    -- Main text uses simple width-based centering in calc_grid_position
    local res
    if bbox and #bbox >= 3 then
        local units_per_em = f.units_per_em or 1000
        local raw_v_center = (bbox[1] + bbox[3]) / 2
        res = raw_v_center * (f.size / units_per_em)
    else
        -- Fallback: width-based centering
        res = (c.width or 0) / 2
    end

    return res
end

--- 计算网格位置坐标（纯计算，不操作节点）
-- 供 render.lua 使用，用于主文本定位，其中节点被就地修改。
--
-- @param col (number) 列索引（从 0 开始）
-- @param glyph_dims (table) 字形尺寸: width, height, depth, char, font
-- @param params (table) 参数表:
--   - col_geom (table) 列几何参数 { grid_width, banxin_width, interval }
--   - y_sp (number) Y 位置 (sp)
--   ...
local function calc_grid_position(col, glyph_dims, params)
    local total_cols = params.total_cols or 1
    local shift_x = params.shift_x or 0
    local shift_y = params.shift_y or 0
    local v_align = params.v_align or "center"
    local h_align = params.h_align or "center"
    local half_thickness = params.half_thickness or 0

    local w = glyph_dims.width or 0
    local h = glyph_dims.height or 0
    local d = glyph_dims.depth or 0

    local textflow = package.loaded['core.luatex-cn-textflow'] or
        require('core.luatex-cn-textflow')

    local col_geom = params.col_geom or {
        grid_width = params.grid_width or 0,
        banxin_width = params.banxin_width or 0,
        interval = params.interval or 0,
    }
    local col_widths = params.col_widths

    -- Calculate RTL column position and base X
    local rtl_col, base_x
    local col_width
    if col_widths and #col_widths > 0 then
        -- Variable-width columns mode
        rtl_col = total_cols - 1 - col
        base_x = get_column_x_var(rtl_col, col_widths, total_cols)
            + (half_thickness or 0) + (shift_x or 0)
        col_width = get_column_width_var(col, col_widths)
    else
        -- Uniform-width columns mode
        rtl_col, base_x = calculate_rtl_position(col, total_cols, col_geom, half_thickness, shift_x)
        col_width = get_column_width(col, col_geom)
    end
    local sub_col = params.sub_col or 0

    -- Cell width for character centering (default to column width)
    -- cell_width may differ from col_width when per-character width override is set
    local cell_w = params.cell_width or col_width
    local center_offset = (col_width - w) / 2

    -- Calculate X offset based on horizontal alignment
    local x_offset
    if sub_col > 0 then
        -- TextFlow logic
        x_offset = textflow.calculate_sub_column_x_offset(base_x, col_width, w, sub_col, params.textflow_align)
    elseif h_align == "left" then
        x_offset = base_x
    elseif h_align == "right" then
        -- Align right edge to body text's right edge (body text is centered in cell)
        local body_fs = params.body_font_size or cell_w
        x_offset = base_x + (col_width + body_fs) / 2 - w
    else -- center
        -- Center char within cell, center cell within column
        x_offset = base_x + (col_width - cell_w) / 2 + (cell_w - w) / 2
    end

    -- Calculate Y offset based on vertical alignment
    -- cell_height: actual cell height for this glyph (set by layout for all glyph entries)
    local cell_height = params.cell_height
    local y_offset = -params.y_sp - (shift_y or 0)

    if v_align == "top" then
        y_offset = y_offset - h
    elseif v_align == "center" then
        local char_total_height = h + d
        y_offset = y_offset - (cell_height + char_total_height) / 2 + d
    else -- bottom
        y_offset = y_offset - cell_height + d
    end

    return x_offset, y_offset
end



-- Internal functions for unit testing
local _internal = {
    calculate_rtl_position = calculate_rtl_position,
    calculate_y_position = calculate_y_position,
}

-- Create module table
local text_position = {
    get_visual_center = get_visual_center,
    position_glyph = position_glyph,
    calc_grid_position = calc_grid_position,
    calculate_rtl_position = calculate_rtl_position,
    calculate_y_position = calculate_y_position,
    get_column_x = get_column_x,
    get_column_width = get_column_width,
    get_column_x_var = get_column_x_var,
    get_column_width_var = get_column_width_var,
    _internal = _internal,
}

-- Register module in package.loaded for require() compatibility
-- 注册模块到 package.loaded
package.loaded['core.luatex-cn-render-position'] = text_position

-- Return module exports
return text_position
