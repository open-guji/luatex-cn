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
--   3. position_glyph_in_grid: 网格坐标定位（包装 position_glyph）
--   4. calc_grid_position: 纯坐标计算（不创建节点，用于 render.lua）
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
--      ├─ create_vertical_text(text, params)
--      │     → 创建完整的字符链（用于版心）
--      └─ position_glyph_in_grid(glyph, col, row, params)
--            → 网格坐标包装器
--
--
-- ============================================================================

-- Load dependencies
local constants = package.loaded['vertical.luatex-cn-vertical-base-constants'] or
    require('vertical.luatex-cn-vertical-base-constants')
local D = constants.D

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

    -- --- Trace Logging ---
    if _G.vertical and _G.vertical.debug and _G.vertical.debug.verbose_log then
        local u = package.loaded['vertical.luatex-cn-vertical-base-utils'] or
            require('vertical.luatex-cn-vertical-base-utils')
        u.debug_log(string.format("[GlyphPos] char=%d x=%.2f cw=%.2f gw=%.2f -> xoff=%.2f yoff=%.2f",
            D.getfield(glyph_direct, "char"), x / (65536), cell_width / (65536), g_width / (65536), x_offset / (65536),
            y_offset / (65536)))
    end

    -- Create protected negative kern (subtype 1 = explicit kern, won't be zeroed)
    local kern = D.new(constants.KERN)
    D.setfield(kern, "subtype", 1)
    D.setfield(kern, "kern", -D.getfield(glyph_direct, "width"))

    -- Link glyph to kern
    D.setlink(glyph_direct, kern)

    return glyph_direct, kern
end

--- 创建竖向排列的文字链
-- 将字符按从上到下的顺序排列在单列中。
-- 用于版心文字，也可用于任何竖排文字块。
--
-- @param text (string) 要渲染的 UTF-8 字符串
-- @param params (table) 参数表:
--   - x (number) 列左边缘的 X 坐标 (sp)
--   - y_top (number) 列顶边缘的 Y 坐标 (sp, 向下为负)
--   - width (number) 用于水平居中的列宽 (sp)
--   - height (number) 文字区域的总高度 (sp)
--   - num_cells (number) 可选：单元格数量 (默认: 字符数)
--   - v_align (string) 每个单元格内的垂直对齐: "top", "center", "bottom"
--   - h_align (string) 列内的水平对齐: "left", "center", "right"
--   - font_id (number) 可选：字体 ID (默认: 当前字体)
--   - shift_y (number) 可选：额外的 Y 轴偏移 (sp)
-- @return (node) 链接节点链的头部（直接节点引用），若无文字则返回 nil
local function create_vertical_text(text, params)
    if not text or text == "" then
        return nil
    end

    -- Parse UTF-8 characters
    local chars = {}
    for char in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        table.insert(chars, char)
    end

    local num_chars = #chars
    if num_chars == 0 then
        return nil
    end

    local x = params.x or 0
    local y_top = params.y_top or 0
    local width = params.width or 0
    local height = params.height or 0
    local num_cells = params.num_cells or num_chars
    local v_align = params.v_align or "center"
    local h_align = params.h_align or "center"
    local font_id = params.font_id or font.current()
    local shift_y = params.shift_y or 0

    local font_scale_factor = 1.0
    local base_font_data = font.getfont(font_id) -- Save original font data for character lookups

    -- Handle font size if provided
    if params.font_size then
        local fs = constants.to_dimen(params.font_size)
        if fs and fs > 0 then
            local current_font_data = font.getfont(font_id)
            if current_font_data then
                font_scale_factor = fs / current_font_data.size
                local new_font_data = {}
                for k, v in pairs(current_font_data) do new_font_data[k] = v end
                new_font_data.size = fs
                font_id = font.define(new_font_data)
            end
        end
    elseif params.font_scale then
        font_scale_factor = params.font_scale
        local current_font_data = font.getfont(font_id)
        if current_font_data then
            local new_font_data = {}
            for k, v in pairs(current_font_data) do new_font_data[k] = v end
            new_font_data.size = math.floor(new_font_data.size * params.font_scale + 0.5)
            font_id = font.define(new_font_data)
        end
    end

    -- Calculate cell height
    local cell_height = height / num_cells

    local u = package.loaded['vertical.luatex-cn-vertical-base-utils'] or
    require('vertical.luatex-cn-vertical-base-utils')

    local head = nil
    local tail = nil

    for i, char in ipairs(chars) do
        -- Create glyph node
        local glyph = node.new(node.id("glyph"))
        glyph.char = utf8.codepoint(char)
        glyph.font = font_id
        glyph.lang = 0

        local glyph_direct = D.todirect(glyph)

        -- CRITICAL: Fetch glyph dimensions from base font data (before scaling)
        -- Then apply font_scale_factor to get actual dimensions
        local cp = utf8.codepoint(char)

        -- Default dimensions if not in font (fallback to square em)
        local gw = (base_font_data and base_font_data.size or (65536 * 10)) * font_scale_factor
        local gh = gw * 0.8
        local gd = gw * 0.2

        if base_font_data and base_font_data.characters and base_font_data.characters[cp] then
            local char_data = base_font_data.characters[cp]
            -- Base font character dimensions need to be scaled by font_scale_factor
            gw = (char_data.width or gw) * font_scale_factor
            gh = (char_data.height or gh) * font_scale_factor
            gd = (char_data.depth or gd) * font_scale_factor
            D.setfield(glyph_direct, "width", math.floor(gw + 0.5))
            D.setfield(glyph_direct, "height", math.floor(gh + 0.5))
            D.setfield(glyph_direct, "depth", math.floor(gd + 0.5))
        end

        -- Calculate cell position (0-indexed row)
        local row = i - 1
        local cell_y = y_top - row * cell_height - shift_y

        -- Position the glyph
        local _, kern = position_glyph(glyph_direct, x, cell_y, {
            cell_width = width,
            cell_height = cell_height,
            h_align = h_align,
            v_align = v_align,
            g_width = math.floor(gw + 0.5),
            g_height = math.floor(gh + 0.5),
            g_depth = math.floor(gd + 0.5),
        })

        -- Build the chain
        if head == nil then
            head = glyph_direct
            tail = kern
        else
            D.setlink(tail, glyph_direct)
            tail = kern
        end

        -- --- DEBUG: Draw blue box around each character ---
        if _G.vertical and _G.vertical.debug and _G.vertical.debug.enabled and _G.vertical.debug.show_grid then
            local u = package.loaded['vertical.luatex-cn-vertical-base-utils'] or
                require('vertical.luatex-cn-vertical-base-utils')
            if u and u.draw_debug_rect then
                -- Add debug box before the glyph so it's behind the text
                head = u.draw_debug_rect(head, glyph_direct, x, cell_y, width, -cell_height, "0 0 1 RG")
            end
        end
    end

    return head
end

--- 在网格单元中定位字形（供主文本渲染使用）
-- 这是一个便捷包装函数，用于在行列网格中定位字形。
--
-- @param glyph_direct (node) 要定位的字形节点的直接引用
-- @param col (number) 列索引（从 0 开始，RTL 转换由调用者处理）
-- @param row (number) 行索引（从 0 开始）
-- @param params (table) 参数表:
--   - grid_width (number) 每个网格单元的宽度 (sp)
--   - grid_height (number) 每个网格单元的高度 (sp)
--   - total_cols (number) 总列数（用于 RTL 计算）
--   - shift_x (number) 边距/边框的 X 轴偏移 (sp)
--   - shift_y (number) 边距/边框的 Y 轴偏移 (sp)
--   - v_align (string) 垂直对齐: "top", "center", "bottom"
--   - half_thickness (number) 边框厚度的一半 (sp)
-- @return (node, node) 字形节点和负 kern 节点
local function position_glyph_in_grid(glyph_direct, col, row, params)
    local grid_width = params.grid_width or 0
    local grid_height = params.grid_height or 0
    local total_cols = params.total_cols or 1
    local shift_x = params.shift_x or 0
    local shift_y = params.shift_y or 0
    local v_align = params.v_align or "center"
    local half_thickness = params.half_thickness or 0

    -- Calculate RTL column position
    local rtl_col = total_cols - 1 - col

    -- Calculate cell position
    local cell_x = rtl_col * grid_width + half_thickness + shift_x
    local cell_y = -row * grid_height - shift_y

    return position_glyph(glyph_direct, cell_x, cell_y, {
        cell_width = grid_width,
        cell_height = grid_height,
        h_align = "center",
        v_align = v_align,
    })
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
local function calc_grid_position(col, row, glyph_dims, params)
    local grid_width = params.grid_width or 0
    local grid_height = params.grid_height or 0
    local total_cols = params.total_cols or 1
    local shift_x = params.shift_x or 0
    local shift_y = params.shift_y or 0
    local v_align = params.v_align or "center"
    local h_align = params.h_align or "center"
    local half_thickness = params.half_thickness or 0

    local w = glyph_dims.width or 0
    local h = glyph_dims.height or 0
    local d = glyph_dims.depth or 0

    -- Calculate RTL column position
    local rtl_col = total_cols - 1 - col
    local sub_col = params.sub_col or 0

    -- Calculate X offset based on horizontal alignment
    local x_offset
    if sub_col > 0 then
        -- Jiazhu (dual-column note) logic
        local sub_width = grid_width / 2
        local inner_padding = sub_width * 0.05 -- 5% internal padding
        local jiazhu_align = params.jiazhu_align or "outward"

        -- Determine alignment for each sub-column based on jiazhu_align setting
        -- sub_col == 1: Right sub-column (先行, displayed on right side in RTL)
        -- sub_col == 2: Left sub-column (后行, displayed on left side in RTL)
        local col_align
        if jiazhu_align == "outward" then
            -- Default: right col right-aligned, left col left-aligned (向外对齐)
            col_align = (sub_col == 1) and "right" or "left"
        elseif jiazhu_align == "inward" then
            -- Opposite: right col left-aligned, left col right-aligned (向内对齐)
            col_align = (sub_col == 1) and "left" or "right"
        elseif jiazhu_align == "center" then
            col_align = "center"
        elseif jiazhu_align == "left" then
            col_align = "left"
        elseif jiazhu_align == "right" then
            col_align = "right"
        else
            -- Fallback to outward
            col_align = (sub_col == 1) and "right" or "left"
        end

        -- Calculate base x position for the sub-column
        local sub_base_x = rtl_col * grid_width + half_thickness + shift_x
        if sub_col == 1 then
            sub_base_x = sub_base_x + sub_width -- Right half
        end

        -- Apply alignment within the sub-column
        if col_align == "right" then
            x_offset = sub_base_x + (sub_width - w) - inner_padding
        elseif col_align == "left" then
            x_offset = sub_base_x + inner_padding
        else -- center
            x_offset = sub_base_x + (sub_width - w) / 2
        end
    elseif h_align == "left" then
        x_offset = rtl_col * grid_width + half_thickness + shift_x
    elseif h_align == "right" then
        x_offset = rtl_col * grid_width + (grid_width - w) + half_thickness + shift_x
    else -- center
        x_offset = rtl_col * grid_width + (grid_width - w) / 2 + half_thickness + shift_x
    end

    -- Calculate Y offset based on vertical alignment
    local y_offset
    if v_align == "top" then
        y_offset = -row * grid_height - h - shift_y
    elseif v_align == "center" then
        local char_total_height = h + d
        y_offset = -row * grid_height - (grid_height + char_total_height) / 2 + d - shift_y
    else -- bottom
        y_offset = -row * grid_height - grid_height + d - shift_y
    end

    return x_offset, y_offset
end

-- Create module table
local text_position = {
    position_glyph = position_glyph,
    create_vertical_text = create_vertical_text,
    position_glyph_in_grid = position_glyph_in_grid,
    calc_grid_position = calc_grid_position,
}

-- Register module in package.loaded for require() compatibility
-- 注册模块到 package.loaded
package.loaded['vertical.luatex-cn-vertical-render-position'] = text_position

-- Return module exports
return text_position
