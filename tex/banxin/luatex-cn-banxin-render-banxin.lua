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

--
-- 文件名: render_banxin.lua  - 版心（鱼尾）绘制模块
-- 层级: 第三阶段 - 渲染层 (Stage 3: Render Layer)
--
-- 【模块功能 / Module Purpose】
-- 本模块负责绘制古籍排版中的"版心"（中间的分隔列），包括：
--   1. 绘制版心列的边框（与普通列边框样式相同）
--   2. 在版心内绘制两条水平分隔线，将版心分为三个区域
--   3. 在版心第一区域绘制竖排文字（鱼尾文字，如书名、卷号等）
--   4. 支持自定义三个区域的高度比例（默认 0.28:0.56:0.16）
--
-- 【整体架构】
--   draw_banxin_column(p_head, params)
--      ├─ render_border() - 绘制边框
--      ├─ draw_banxin() - 绘制分隔线和鱼尾
--      ├─ render_book_name() - 绘制书名文字
--      ├─ render_chapter_title() - 绘制章节标题
--      ├─ render_page_number() - 绘制页码
--      ├─ render_publisher() - 绘制出版社/刊号
--      └─ render_debug_rects() - 调试矩形
--
-- ============================================================================

-- Load dependencies
local constants = package.loaded['core.luatex-cn-constants'] or
    require('core.luatex-cn-constants')
local D = constants.D
local utils = package.loaded['util.luatex-cn-utils'] or
    require('util.luatex-cn-utils')
local text_position = package.loaded['core.luatex-cn-render-position'] or
    require('luatex-cn-render-position')
local yuwei = package.loaded['banxin.luatex-cn-banxin-render-yuwei'] or require('banxin.luatex-cn-banxin-render-yuwei')
local banxin_layout = package.loaded['banxin.luatex-cn-banxin-layout'] or require('banxin.luatex-cn-banxin-layout')

-- Register banxin module if debug module is available
local debug = package.loaded['debug.luatex-cn-debug'] or
    require('debug.luatex-cn-debug')

local dbg = debug.get_debugger('banxin')

-- Conversion factor from scaled points to PDF big points
local sp_to_bp = utils.sp_to_bp

-- ============================================================================
-- Helper Functions (纯函数，只计算不产生副作用)
-- ============================================================================

-- Reuse shared helpers from banxin-layout module
local count_utf8_chars = banxin_layout.count_utf8_chars
local calculate_yuwei_dimensions = banxin_layout.calculate_yuwei_dimensions
local calculate_yuwei_total_height = banxin_layout.calculate_yuwei_total_height

--- 将节点链插入到链表头部
-- @param p_head (node) 当前链表头
-- @param glyph_chain (node) 要插入的节点链
-- @return (node) 新的链表头
local function prepend_chain(p_head, glyph_chain)
    if not glyph_chain then return p_head end
    local chain_tail = glyph_chain
    while D.getnext(chain_tail) do
        chain_tail = D.getnext(chain_tail)
    end
    D.setlink(chain_tail, p_head)
    return glyph_chain
end

-- ============================================================================
-- PDF Literal Generators (生成 PDF 指令字符串)
-- ============================================================================

--- 生成边框矩形的 PDF literal
-- @param x (number) X 坐标 (sp)
-- @param y (number) Y 坐标 (sp)
-- @param width (number) 宽度 (sp)
-- @param height (number) 高度 (sp, 正值)
-- @param thickness (number) 线宽 (sp)
-- @param color_str (string) RGB 颜色字符串
-- @return (string) PDF literal 字符串
local function create_border_literal(x, y, width, height, thickness, color_str)
    local x_bp = x * sp_to_bp
    local y_bp = y * sp_to_bp
    local width_bp = width * sp_to_bp
    local height_bp = -height * sp_to_bp -- Negative because Y goes downward
    local thickness_bp = thickness * sp_to_bp

    return string.format(
        "q %.2f w %s RG %.4f %.4f %.4f %.4f re S Q",
        thickness_bp, color_str, x_bp, y_bp, width_bp, height_bp
    )
end

--- 生成水平分隔线的 PDF literal
-- @param x (number) X 坐标 (sp)
-- @param y (number) Y 坐标 (sp)
-- @param width (number) 宽度 (sp)
-- @param thickness (number) 线宽 (sp)
-- @param color_str (string) RGB 颜色字符串
-- @return (string) PDF literal 字符串
local function create_divider_literal(x, y, width, thickness, color_str)
    local x_bp = x * sp_to_bp
    local y_bp = y * sp_to_bp
    local width_bp = width * sp_to_bp
    local thickness_bp = thickness * sp_to_bp

    return string.format(
        "q %.2f w %s RG %.4f %.4f m %.4f %.4f l S Q",
        thickness_bp, color_str,
        x_bp, y_bp,
        x_bp + width_bp, y_bp
    )
end

-- ============================================================================
-- Node Creation Functions (创建节点)
-- ============================================================================

--- 创建 PDF literal 节点
-- @param literal_str (string) PDF literal 字符串
-- @return (node) PDF literal 节点 (direct node)
local function create_literal_node(literal_str)
    local n = node.new("whatsit", "pdf_literal")
    n.data = literal_str
    n.mode = 0
    return D.todirect(n)
end

-- ============================================================================
-- Draw Banxin Internals (版心内部绘制)
-- ============================================================================

--- 绘制版心分隔线
-- @param x (number) X 坐标 (sp)
-- @param y (number) Y 坐标 (sp, 顶边缘)
-- @param width (number) 宽度 (sp)
-- @param upper_height (number) 上区域高度 (sp)
-- @param middle_height (number) 中区域高度 (sp)
-- @param thickness (number) 线宽 (sp)
-- @param color_str (string) RGB 颜色字符串
-- @return (table) PDF literal 字符串数组
local function draw_dividers(x, y, width, upper_height, middle_height, thickness, color_str)
    local div1_y = y - upper_height
    local div2_y = div1_y - middle_height

    return {
        create_divider_literal(x, div1_y, width, thickness, color_str),
        create_divider_literal(x, div2_y, width, thickness, color_str),
    }
end

--- 绘制上鱼尾
-- @param x (number) X 坐标 (sp)
-- @param div1_y (number) 第一分隔线 Y 坐标 (sp)
-- @param width (number) 宽度 (sp)
-- @param yuwei_dims (table) 鱼尾尺寸
-- @param color_str (string) RGB 颜色字符串
-- @param thickness (number) 线宽 (sp)
-- @return (string) PDF literal 字符串
local function draw_upper_yuwei(x, div1_y, width, yuwei_dims, color_str, thickness)
    local yuwei_y = div1_y - yuwei_dims.gap
    return yuwei.draw_yuwei({
        x = x,
        y = yuwei_y,
        width = width,
        edge_height = yuwei_dims.edge_height,
        notch_height = yuwei_dims.notch_height,
        style = "black",
        direction = 1, -- Notch at bottom (上鱼尾)
        color_str = color_str,
        extra_line = true,
        border_thickness = thickness,
    })
end

--- 绘制下鱼尾
-- @param x (number) X 坐标 (sp)
-- @param div2_y (number) 第二分隔线 Y 坐标 (sp)
-- @param width (number) 宽度 (sp)
-- @param yuwei_dims (table) 鱼尾尺寸
-- @param color_str (string) RGB 颜色字符串
-- @param thickness (number) 线宽 (sp)
-- @return (string) PDF literal 字符串
local function draw_lower_yuwei(x, div2_y, width, yuwei_dims, color_str, thickness)
    local yuwei_y = div2_y + yuwei_dims.notch_height + yuwei_dims.gap
    return yuwei.draw_yuwei({
        x = x,
        y = yuwei_y,
        width = width,
        edge_height = yuwei_dims.edge_height,
        notch_height = yuwei_dims.notch_height,
        style = "black",
        direction = -1, -- Notch at top (下鱼尾)
        color_str = color_str,
        extra_line = true,
        border_thickness = thickness,
    })
end

--- 绘制版心的分隔线和鱼尾
-- @param params (table) 绘制参数
-- @return (table) { literals: string[], upper_height: number }
local function draw_banxin(params)
    local x = params.x or 0
    local y = params.y or 0
    local width = params.width or 0
    local total_height = params.total_height or 0
    local r1 = params.upper_ratio or 0.28
    local r2 = params.middle_ratio or 0.56
    local color_str = params.color_str or "0 0 0"
    local thickness = params.border_thickness or 26214
    local upper_height = total_height * r1
    local middle_height = total_height * r2

    local literals = {}

    -- Draw dividers
    if params.banxin_divider ~= false then
        local divider_literals = draw_dividers(x, y, width, upper_height, middle_height, thickness, color_str)
        for _, lit in ipairs(divider_literals) do
            table.insert(literals, lit)
        end
    end

    -- Draw yuwei
    local yuwei_dims = calculate_yuwei_dimensions(width)
    local div1_y = y - upper_height
    local div2_y = div1_y - middle_height

    if params.upper_yuwei ~= false then
        table.insert(literals, draw_upper_yuwei(x, div1_y, width, yuwei_dims, color_str, thickness))
    end

    local lower_yuwei_enabled = params.lower_yuwei
    if lower_yuwei_enabled == nil then lower_yuwei_enabled = true end
    if lower_yuwei_enabled then
        table.insert(literals, draw_lower_yuwei(x, div2_y, width, yuwei_dims, color_str, thickness))
    end

    return {
        literals = literals,
        upper_height = upper_height,
    }
end

-- ============================================================================
-- Text Rendering Functions (文字渲染)
-- ============================================================================

-- Forward declaration
local create_vertical_text

--- 创建竖向排列的文字链
-- 将字符按从上到下的顺序排列在单列中。
create_vertical_text = function(text, params)
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
    local base_font_data = font.getfont(font_id)

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

    local head = nil
    local tail = nil

    for i, char in ipairs(chars) do
        -- Create glyph node
        local glyph = node.new(node.id("glyph"))
        glyph.char = utf8.codepoint(char)
        glyph.font = font_id
        glyph.lang = 0

        local glyph_direct = D.todirect(glyph)

        -- Fetch glyph dimensions
        local cp = utf8.codepoint(char)
        local gw = (base_font_data and base_font_data.size or (65536 * 10)) * font_scale_factor
        local gh = gw * 0.8
        local gd = gw * 0.2

        if base_font_data and base_font_data.characters and base_font_data.characters[cp] then
            local char_data = base_font_data.characters[cp]
            gw = (char_data.width or gw) * font_scale_factor
            gh = (char_data.height or gh) * font_scale_factor
            gd = (char_data.depth or gd) * font_scale_factor
            D.setfield(glyph_direct, "width", math.floor(gw + 0.5))
            D.setfield(glyph_direct, "height", math.floor(gh + 0.5))
            D.setfield(glyph_direct, "depth", math.floor(gd + 0.5))
        end

        local row = i - 1
        local cell_y = y_top - row * cell_height - shift_y

        -- Position the glyph using core utility
        local _, kern = text_position.position_glyph(glyph_direct, x, cell_y, {
            cell_width = width,
            cell_height = cell_height,
            h_align = h_align,
            v_align = v_align,
            g_width = math.floor(gw + 0.5),
            g_height = math.floor(gh + 0.5),
            g_depth = math.floor(gd + 0.5),
        })

        if head == nil then
            head = glyph_direct
            tail = kern
        else
            D.setlink(tail, glyph_direct)
            tail = kern
        end

        -- Debug rects
        if dbg.is_enabled() then
            if utils and utils.draw_debug_rect then
                head = utils.draw_debug_rect(head, glyph_direct, x, cell_y, width, -cell_height, "0 0 1 RG")
            end
        end
    end

    return head
end

--- Generic function to render a text section
-- Consolidates the common pattern used by book_name, chapter, page_number, publisher
-- @param p_head (node) Current list head
-- @param layout (table|nil) Layout params with: text, x, y_top, width, height, v_align, h_align, font_size
-- @return (node) Updated list head
local function render_text_section(p_head, layout)
    if not layout or not layout.text or layout.text == "" then
        return p_head
    end
    local chain = create_vertical_text(layout.text, {
        x = layout.x,
        y_top = layout.y_top,
        width = layout.width,
        height = layout.height,
        num_cells = layout.num_cells,
        v_align = layout.v_align or "center",
        h_align = layout.h_align or "center",
        font_size = layout.font_size,
        font_scale = layout.font_scale,
    })
    if chain then
        p_head = prepend_chain(p_head, chain)
    end
    return p_head
end

-- Reuse parse_chapter_title from banxin-layout module
local parse_chapter_title = banxin_layout.parse_chapter_title

-- ============================================================================
-- Debug Functions (调试功能)
-- ============================================================================

--- 渲染调试矩形
-- @param p_head (node) 当前链表头
-- @param x, y, width, height (number) 矩形位置和尺寸 (sp)
-- @return (node) 新的链表头
local function render_debug_rects(p_head, x, y, width, height)
    if not (dbg.is_enabled()) then
        return p_head
    end

    p_head = utils.draw_debug_rect(p_head, nil, x, y, width, -height, "0 1 0 RG [2 2] 0 d")
    p_head = utils.draw_debug_rect(p_head, nil, x, y, width, -height, "1 0 0 RG")

    return p_head
end

-- ============================================================================
-- Layout-Based Rendering Functions (布局驱动渲染)
-- ============================================================================

--- Render chapter title from layout data with runtime content
-- @param p_head (node) Node list head
-- @param element (table) Chapter title layout element
-- @param chapter_title (string) Runtime chapter title content
-- @return (node) Updated node list head
local function render_chapter_title_from_layout(p_head, element, chapter_title)
    if not chapter_title or chapter_title == "" then return p_head end

    local parts = parse_chapter_title(chapter_title)
    if #parts == 0 then return p_head end

    local n_cols = math.max(#parts, element.n_cols or 1)
    local col_width = element.width / n_cols

    for i, sub_text in ipairs(parts) do
        local c = i - 1
        local sub_x = element.x + (n_cols - 1 - c) * col_width

        local col_h_align = "center"
        if n_cols > 1 then
            if i == 1 then
                col_h_align = "right"
            elseif i == #parts then
                col_h_align = "left"
            end
        end

        local num_chars = count_utf8_chars(sub_text)
        local total_h = num_chars * element.grid_height

        p_head = render_text_section(p_head, {
            text = sub_text,
            x = sub_x,
            y_top = element.y_top,
            width = col_width,
            height = total_h,
            v_align = "center",
            h_align = col_h_align,
            font_size = element.font_size,
            font_scale = element.font_scale,
        })
    end

    return p_head
end

--- Render page number from layout data with runtime content
-- @param p_head (node) Node list head
-- @param element (table) Page number layout element
-- @param page_number (number) Runtime page number
-- @return (node) Updated node list head
local function render_page_number_from_layout(p_head, element, page_number, explicit_page_number)
    if not page_number and not explicit_page_number then return p_head end

    -- Use explicit page number string if provided (digital mode),
    -- otherwise auto-convert numeric page number to Chinese numeral
    local page_str = explicit_page_number or utils.to_chinese_numeral(page_number)
    if page_str == "" then return p_head end

    local num_chars = count_utf8_chars(page_str)
    local container_height = element.grid_height * num_chars

    -- Recalculate y_top based on actual character count
    local page_y_top
    if element.v_align == "center" then
        local available_middle_h = element.middle_height - element.upper_yuwei_total - element.lower_yuwei_total
        local center_y = element.middle_y_bottom + element.lower_yuwei_total + available_middle_h / 2
        page_y_top = center_y + container_height / 2
    else
        page_y_top = element.middle_y_bottom + element.lower_yuwei_total + element.page_bottom_margin + container_height
    end

    p_head = render_text_section(p_head, {
        text = page_str,
        x = element.x,
        y_top = page_y_top,
        width = element.width,
        height = container_height,
        v_align = element.v_align,
        h_align = element.h_align,
        font_size = element.font_size,
    })

    return p_head
end

--- Draw banxin column from pre-calculated layout
-- This function uses layout data calculated in the layout stage
-- and resolves runtime content (page number, chapter title) at render time.
-- @param p_head (node) Node list head
-- @param layout (table) Pre-calculated layout from banxin-layout module
-- @param runtime (table) Runtime content { chapter_title, page_number }
-- @return (node) Updated node list head
local function draw_from_layout(p_head, layout, runtime)
    local col = layout.column
    local decorations = layout.decorations
    local regions = layout.regions

    -- 1. Draw border
    if col.draw_border then
        local border_literal = create_border_literal(
            col.x, col.y, col.width, col.height,
            col.border_thickness, col.color_str
        )
        p_head = D.insert_before(p_head, p_head, create_literal_node(border_literal))
    end

    -- 2. Draw dividers
    if decorations.draw_dividers then
        local divider_literals = draw_dividers(
            col.x, col.y, col.width,
            regions.upper.height, regions.middle.height,
            col.border_thickness, col.color_str
        )
        for _, lit in ipairs(divider_literals) do
            p_head = D.insert_before(p_head, p_head, create_literal_node(lit))
        end
    end

    -- 3. Draw fish tails (yuwei)
    local div1_y = col.y - regions.upper.height
    local div2_y = div1_y - regions.middle.height

    if decorations.upper_yuwei then
        local upper_lit = draw_upper_yuwei(
            col.x, div1_y, col.width,
            decorations.yuwei_dims, col.color_str, col.border_thickness
        )
        p_head = D.insert_before(p_head, p_head, create_literal_node(upper_lit))
    end

    if decorations.lower_yuwei then
        local lower_lit = draw_lower_yuwei(
            col.x, div2_y, col.width,
            decorations.yuwei_dims, col.color_str, col.border_thickness
        )
        p_head = D.insert_before(p_head, p_head, create_literal_node(lower_lit))
    end

    -- 4. Render text elements
    for _, element in ipairs(layout.elements) do
        if element.type == "book_name" then
            p_head = render_text_section(p_head, element)
        elseif element.type == "chapter_title" then
            p_head = render_chapter_title_from_layout(p_head, element, runtime.chapter_title)
        elseif element.type == "page_number" then
            p_head = render_page_number_from_layout(p_head, element, runtime.page_number, runtime.explicit_page_number)
        elseif element.type == "publisher" then
            p_head = render_text_section(p_head, element)
        end
    end

    -- 5. Debug rectangles
    p_head = render_debug_rects(p_head, col.x, col.y, col.width, col.height)

    return p_head
end

-- ============================================================================
-- Module Export
-- ============================================================================

local banxin = {
    draw_banxin = draw_banxin,
    draw_from_layout = draw_from_layout,
    -- Internal functions exported for testing
    _internal = {
        count_utf8_chars = count_utf8_chars,
        calculate_yuwei_dimensions = calculate_yuwei_dimensions,
        calculate_yuwei_total_height = calculate_yuwei_total_height,
        create_border_literal = create_border_literal,
        create_divider_literal = create_divider_literal,
        parse_chapter_title = parse_chapter_title,
    },
}

package.loaded['banxin.luatex-cn-banxin-render-banxin'] = banxin

return banxin
