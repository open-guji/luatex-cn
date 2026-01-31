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

-- Register banxin module if debug module is available
local debug = package.loaded['debug.luatex-cn-debug'] or
    require('debug.luatex-cn-debug')

local dbg = debug.get_debugger('banxin')

-- Conversion factor from scaled points to PDF big points
local sp_to_bp = utils.sp_to_bp

-- ============================================================================
-- Helper Functions (纯函数，只计算不产生副作用)
-- ============================================================================

--- 统计 UTF-8 字符串中的字符数
-- @param text (string) UTF-8 字符串
-- @return (number) 字符数
local function count_utf8_chars(text)
    local count = 0
    for _ in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        count = count + 1
    end
    return count
end

--- 计算鱼尾的尺寸
-- @param width (number) 版心宽度 (sp)
-- @return (table) { edge_height, notch_height, gap } 鱼尾尺寸
local function calculate_yuwei_dimensions(width)
    return {
        edge_height = width * 0.39,
        notch_height = width * 0.17,
        gap = 65536 * 3.7, -- 3.7pt gap from dividing lines
    }
end

--- 计算鱼尾总高度（包含间隙）
-- @param yuwei_dims (table) 鱼尾尺寸
-- @return (number) 鱼尾总高度 (sp)
local function calculate_yuwei_total_height(yuwei_dims)
    return yuwei_dims.gap + yuwei_dims.edge_height + yuwei_dims.notch_height
end

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

--- 批量插入 PDF literal 节点到链表头部
-- @param p_head (node) 当前链表头
-- @param literals (table) PDF literal 字符串数组
-- @return (node) 新的链表头
local function insert_literals(p_head, literals)
    for _, lit in ipairs(literals) do
        local lit_node = create_literal_node(lit)
        p_head = D.insert_before(p_head, p_head, lit_node)
    end
    return p_head
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

--- 创建竖向排列的文字链
-- 将字符按从上到下的顺序排列在单列中。
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

--- 计算书名文字的渲染参数
-- @param params (table) 输入参数
-- @param upper_height (number) 上区域高度 (sp)
-- @return (table|nil) 渲染参数，如果书名为空则返回 nil
local function calculate_book_name_params(params, upper_height)
    local book_name = params.book_name or ""
    if book_name == "" then return nil end

    -- Use resolve_dimen for safety
    local f_size = constants.resolve_dimen(params.font_size, 655360)
    local b_padding_top = constants.resolve_dimen(params.b_padding_top, f_size)
    local b_padding_bottom = constants.resolve_dimen(params.b_padding_bottom, f_size)
    local effective_b = params.draw_border and constants.resolve_dimen(params.border_thickness, f_size) or 0
    local adj_height = upper_height - effective_b - b_padding_top - b_padding_bottom
    local num_chars = count_utf8_chars(book_name)

    local grid_h = constants.resolve_dimen(constants.to_dimen(params.book_name_grid_height), f_size)
    local total_text_height
    if grid_h and grid_h > 0 then
        total_text_height = grid_h * num_chars
    else
        if num_chars * f_size > adj_height then
            f_size = adj_height / num_chars
        end
        total_text_height = num_chars * f_size
    end

    local block_y_top = params.y - effective_b - b_padding_top
    local y_start
    if params.book_name_align == "top" then
        y_start = block_y_top
    else
        y_start = block_y_top - (adj_height - total_text_height) / 2
    end


    return {
        text = book_name,
        x = params.x,
        y_top = y_start,
        width = params.width,
        height = total_text_height,
        num_cells = num_chars,
        v_align = "center",
        h_align = "center",
        font_size = f_size,
    }
end

--- 渲染书名文字
-- @param p_head (node) 当前链表头
-- @param params (table) 输入参数
-- @param upper_height (number) 上区域高度 (sp)
-- @return (node) 新的链表头
local function render_book_name(p_head, params, upper_height)
    local text_params = calculate_book_name_params(params, upper_height)
    if not text_params then return p_head end

    local glyph_chain = create_vertical_text(text_params.text, {
        x = text_params.x,
        y_top = text_params.y_top,
        width = text_params.width,
        height = text_params.height,
        num_cells = text_params.num_cells,
        v_align = text_params.v_align,
        h_align = text_params.h_align,
        font_size = text_params.font_size,
    })

    if glyph_chain then
        p_head = prepend_chain(p_head, glyph_chain)
    end

    return p_head
end

--- 解析章节标题（支持 \\\\ 换行）
-- @param chapter_title (string) 章节标题
-- @return (table) 标题部分数组
local function parse_chapter_title(chapter_title)
    if not chapter_title then return {} end
    -- Handle both \\ and \\\\ (TeX vs Lua literal escaping)
    local raw_title = chapter_title:gsub("\\\\+", "\n")
    local parts = {}
    for s in raw_title:gmatch("[^\n]+") do
        table.insert(parts, s)
    end
    return parts
end

--- 计算章节标题的布局参数
-- @param params (table) 输入参数
-- @param upper_height (number) 上区域高度 (sp)
-- @param middle_height (number) 中区域高度 (sp)
-- @param yuwei_dims (table) 鱼尾尺寸
-- @return (table|nil) 布局参数，如果标题为空则返回 nil
local function calculate_chapter_title_layout(params, upper_height, middle_height, yuwei_dims)
    local chapter_title = params.chapter_title or ""
    if chapter_title == "" then return nil end

    local parts = parse_chapter_title(chapter_title)
    if #parts == 0 then return nil end

    local chapter_top_margin = params.chapter_title_top_margin or (65536 * 40)
    local upper_yuwei_total = params.upper_yuwei ~= false and calculate_yuwei_total_height(yuwei_dims) or 0
    local lower_yuwei_total = params.lower_yuwei ~= false and calculate_yuwei_total_height(yuwei_dims) or 0

    local middle_y_top = params.y - upper_height
    local base_f_size = constants.resolve_dimen(params.font_size, 655360)
    local title_top_margin = constants.resolve_dimen(params.chapter_title_top_margin, base_f_size) or 0


    local chapter_y_top = middle_y_top - upper_yuwei_total - title_top_margin
    local available_height = middle_height - upper_yuwei_total - lower_yuwei_total - title_top_margin
    if available_height <= 0 then
        available_height = middle_height * 0.3 -- Fallback
    end

    local n_cols = math.max(#parts, params.chapter_title_cols or 1)


    return {
        parts = parts,
        n_cols = n_cols,
        chapter_title = chapter_title,
        y_top = chapter_y_top, -- This is the top of the available area for the title
        available_height = available_height,
    }
end

--- 渲染章节标题
-- @param p_head (node) 当前链表头
-- @param params (table) 输入参数
-- @param upper_height (number) 上区域高度 (sp)
-- @param middle_height (number) 中区域高度 (sp)
-- @param yuwei_dims (table) 鱼尾尺寸
-- @return (node) 新的链表头
local function render_chapter_title(p_head, params, upper_height, middle_height, yuwei_dims)
    local layout = calculate_chapter_title_layout(params, upper_height, middle_height, yuwei_dims)
    if not layout then return p_head end

    local parts = layout.parts
    local n_cols = math.max(#parts, params.chapter_title_cols or 1)
    local col_width = params.width / n_cols

    -- Use resolve_dimen for safety
    local base_f_size = constants.resolve_dimen(params.font_size, 655360)
    local title_font_size = constants.resolve_dimen(params.chapter_title_font_size, base_f_size)
    local font_scale = nil
    if not title_font_size then
        font_scale = 0.5 -- Default scale for banxin titles if not specified
        title_font_size = base_f_size * font_scale
    end

    local desired_grid_h = constants.resolve_dimen(params.chapter_title_grid_height, title_font_size)
    if not desired_grid_h or desired_grid_h <= 0 then
        -- Default spacing: slightly more than font size to avoid overlap
        desired_grid_h = title_font_size * 1.1
    end

    for i, sub_text in ipairs(parts) do
        local c = i - 1
        local sub_x = params.x + (n_cols - 1 - c) * col_width

        local col_h_align = "center"
        if n_cols > 1 then
            if i == 1 then
                col_h_align = "right"
            elseif i == #parts then
                col_h_align = "left"
            end
        end

        local num_chars = count_utf8_chars(sub_text)
        local total_h = num_chars * desired_grid_h

        -- Top-align (respecting layout.y_top which already accounts for margin)
        local new_y_top = layout.y_top

        local chapter_chain = create_vertical_text(sub_text, {
            x = sub_x,
            y_top = new_y_top,
            width = col_width,
            height = total_h,
            v_align = "center",
            h_align = col_h_align,
            font_size = title_font_size,
            font_scale = font_scale,
        })

        if chapter_chain then
            p_head = prepend_chain(p_head, chapter_chain)
        end
    end

    return p_head
end

--- 计算页码的布局参数
-- @param params (table) 输入参数
-- @param upper_height (number) 上区域高度 (sp)
-- @param middle_height (number) 中区域高度 (sp)
-- @param yuwei_dims (table) 鱼尾尺寸
-- @return (table|nil) 布局参数，如果页码为空则返回 nil
local function calculate_page_number_layout(params, upper_height, middle_height, yuwei_dims)
    if not params.page_number then return nil end

    local page_str = utils.to_chinese_numeral(params.page_number)
    if page_str == "" then return nil end

    local upper_yuwei_total = params.upper_yuwei and calculate_yuwei_total_height(yuwei_dims) or 0
    local lower_yuwei_total = params.lower_yuwei and calculate_yuwei_total_height(yuwei_dims) or 0

    local middle_y_bottom = params.y - upper_height - middle_height
    local page_right_margin = 65536 * 2
    local page_bottom_margin = params.b_padding_bottom or (65536 * 15)

    local num_chars = count_utf8_chars(page_str)

    local base_f_size = constants.resolve_dimen(params.font_size, 655360)
    local f_size = constants.resolve_dimen(params.page_number_font_size, base_f_size) or (65536 * 10)
    local grid_h = constants.resolve_dimen(params.page_number_grid_height, f_size)
    if not grid_h or grid_h <= 0 then
        grid_h = f_size * 1.2
    end
    local container_height = grid_h * num_chars


    local p_v_align = "bottom"
    local p_h_align = "right"
    local page_y_top = middle_y_bottom + lower_yuwei_total + page_bottom_margin + container_height

    if params.page_number_align == "center" then
        p_v_align = "center"
        p_h_align = "center"
        local available_middle_h = middle_height - upper_yuwei_total - lower_yuwei_total
        local center_y = middle_y_bottom + lower_yuwei_total + available_middle_h / 2
        page_y_top = center_y + container_height / 2
    elseif params.page_number_align == "bottom-center" then
        p_v_align = "bottom"
        p_h_align = "center"
    end

    return {
        text = page_str,
        x = params.x,
        y_top = page_y_top,
        width = params.width - (params.page_number_align == "center" and 0 or page_right_margin),
        height = container_height,
        v_align = p_v_align,
        h_align = p_h_align,
        font_size = f_size,
    }
end

--- 渲染页码
-- @param p_head (node) 当前链表头
-- @param params (table) 输入参数
-- @param upper_height (number) 上区域高度 (sp)
-- @param middle_height (number) 中区域高度 (sp)
-- @param yuwei_dims (table) 鱼尾尺寸
-- @return (node) 新的链表头
local function render_page_number(p_head, params, upper_height, middle_height, yuwei_dims)
    local layout = calculate_page_number_layout(params, upper_height, middle_height, yuwei_dims)
    if not layout then return p_head end

    local page_chain = create_vertical_text(layout.text, {
        x = layout.x,
        y_top = layout.y_top,
        width = layout.width,
        height = layout.height,
        v_align = layout.v_align,
        h_align = layout.h_align,
        font_size = layout.font_size,
    })

    if page_chain then
        p_head = prepend_chain(p_head, page_chain)
    end

    return p_head
end

--- 计算出版社的布局参数
-- @param params (table) 输入参数
-- @param height (number) 版心总高度
-- @return (table|nil) 布局参数
local function calculate_publisher_layout(params, height)
    local publisher = params.publisher or ""
    if publisher == "" then return nil end

    -- Use resolve_dimen for safety
    local base_f_size = constants.resolve_dimen(params.font_size, 655360) or 655360
    local f_size = constants.resolve_dimen(params.publisher_font_size, base_f_size)
    if not f_size or f_size <= 0 then
        f_size = 65536 * 10 -- Default 10pt
    end

    local grid_h = constants.resolve_dimen(params.publisher_grid_height, f_size)
    if not grid_h or grid_h <= 0 then
        grid_h = math.floor(f_size * 1.2 + 0.5) -- Default 1.2 line height
    end

    local num_chars = count_utf8_chars(publisher)
    local container_height = grid_h * num_chars
    local bottom_margin = constants.resolve_dimen(params.publisher_bottom_margin, f_size) or (65536 * 5)

    local banxin_bottom_y = params.y - height
    local y_top = banxin_bottom_y + bottom_margin + container_height


    return {
        text = publisher,
        x = params.x,
        y_top = y_top,
        width = params.width,
        height = container_height,
        v_align = "bottom",
        h_align = params.publisher_align == "center" and "center" or "right",
        font_size = f_size,
    }
end

--- 渲染出版社文字
-- @param p_head (node) 当前链表头
-- @param params (table) 输入参数
-- @param height (number) 版心总高度
-- @return (node) 新的链表头
local function render_publisher(p_head, params, height)
    local layout = calculate_publisher_layout(params, height)
    if not layout then return p_head end

    local pub_chain = create_vertical_text(layout.text, {
        x = layout.x,
        y_top = layout.y_top,
        width = layout.width,
        height = layout.height,
        v_align = layout.v_align,
        h_align = layout.h_align,
        font_size = layout.font_size,
    })

    if pub_chain then
        p_head = prepend_chain(p_head, pub_chain)
    end

    return p_head
end

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
-- Main Entry Point (主入口函数)
-- ============================================================================

--- 绘制完整的版心列，包括边框、分隔线、鱼尾和文字
-- @param p_head (node) 节点列表头部
-- @param params (table) 参数表
-- @return (node) 更新后的头部
local function draw_banxin_column(p_head, params)
    local x = params.x
    local y = params.y
    local width = params.width
    local height = params.height
    local border_thickness = params.border_thickness
    local color_str = params.color_str or "0 0 0"


    -- 1. Draw border
    if params.draw_border then
        local border_literal = create_border_literal(x, y, width, height, border_thickness, color_str)
        p_head = D.insert_before(p_head, p_head, create_literal_node(border_literal))
    end

    -- 2. Draw banxin dividers and yuwei
    local banxin_params = {
        x = x,
        y = y,
        width = width,
        total_height = height,
        upper_ratio = params.upper_ratio or 0.28,
        middle_ratio = params.middle_ratio or 0.56,
        color_str = color_str,
        border_thickness = border_thickness,
        lower_yuwei = params.lower_yuwei,
        upper_yuwei = params.upper_yuwei,
        banxin_divider = params.banxin_divider,
    }
    local banxin_result = draw_banxin(banxin_params)
    p_head = insert_literals(p_head, banxin_result.literals)

    -- Calculate shared values for text rendering
    local upper_height = banxin_result.upper_height
    local middle_height = height * (params.middle_ratio or 0.56)
    local yuwei_dims = calculate_yuwei_dimensions(width)

    -- 3. Render book name
    p_head = render_book_name(p_head, params, upper_height)

    -- 4. Render chapter title
    p_head = render_chapter_title(p_head, params, upper_height, middle_height, yuwei_dims)

    -- 5. Render page number
    p_head = render_page_number(p_head, params, upper_height, middle_height, yuwei_dims)

    -- 6. Render publisher
    p_head = render_publisher(p_head, params, height)

    -- 7. Debug rectangles
    p_head = render_debug_rects(p_head, x, y, width, height)

    return p_head
end

-- ============================================================================
-- Module Export
-- ============================================================================

local banxin = {
    draw_banxin = draw_banxin,
    draw_banxin_column = draw_banxin_column,
    -- Internal functions exported for testing
    _internal = {
        count_utf8_chars = count_utf8_chars,
        calculate_yuwei_dimensions = calculate_yuwei_dimensions,
        calculate_yuwei_total_height = calculate_yuwei_total_height,
        create_border_literal = create_border_literal,
        create_divider_literal = create_divider_literal,
        calculate_book_name_params = calculate_book_name_params,
        parse_chapter_title = parse_chapter_title,
        calculate_chapter_title_layout = calculate_chapter_title_layout,
        calculate_page_number_layout = calculate_page_number_layout,
    },
}

package.loaded['banxin.luatex-cn-banxin-render-banxin'] = banxin

return banxin
