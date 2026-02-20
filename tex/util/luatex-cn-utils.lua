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
-- base_utils.lua - 通用工具函数库
-- ============================================================================
-- 文件名: base_utils.lua (原 utils.lua)
-- 层级: 基础层 (Base Layer)
--
-- 【模块功能 / Module Purpose】
-- 本模块提供跨模块共享的工具函数，主要用于数据格式转换：
--   1. normalize_rgb: 将各种 RGB 格式（0-1 或 0-255）归一化为 PDF 标准格式
--   2. sp_to_bp: scaled points 到 PDF big points 的转换系数
--   3. debug_log: 调试日志输出到 .log 文件
--   4. draw_debug_rect: 绘制调试用的矩形边框
--
-- 【术语对照 / Terminology】
--   sp_to_bp            - scaled points 转 big points 系数（1bp = 65536sp）
--   normalize_rgb       - RGB 颜色归一化（统一为 PDF 可用格式 "r g b"）
--   pdf_literal         - PDF 直写节点（直接写入底层 PDF 指令）
--   rg/RG               - PDF 填充色/描边色指令（小写=fill，大写=stroke）
--   whatsit             - TeX 特殊节点类型（用于嵌入非标准内容）
--
-- 【注意事项】
--   • normalize_rgb 自动检测并转换 0-255 范围到 0-1 范围
--   • 支持逗号和空格分隔的 RGB 值（"255,0,0" 或 "1.0 0 0"）
--   • 返回的字符串格式为 "r g b"（空格分隔，保留 4 位小数）
--   • 【重要】PDF 颜色指令必须是纯数字（如 "0 0 0 rg"），
--     直接传入 "black" 会导致 PDF 渲染错误使文字消失
--   • sp_to_bp = 1/65536 ≈ 0.0000152018（TeX 内部单位到 PDF 单位）
--
-- 【整体架构 / Architecture】
--   normalize_rgb(rgb_str)
--      ├─ 替换逗号为空格
--      ├─ 提取 r、g、b 数值
--      ├─ 如果任一值 > 1，则除以 255
--      └─ 返回格式化字符串 "r.rrrr g.gggg b.bbbb"
--
-- ============================================================================

-- Conversion factor from scaled points to PDF big points
local sp_to_bp = 0.0000152018

--- 归一化 RGB 颜色字符串
-- 将多种 RGB 格式转换为归一化的 0-1 范围
-- 支持的格式包括：
--   - "r,g,b" 或 "r g b"，数值范围为 0-1 或 0-255
--   - 自动检测并转换 0-255 范围到 0-1
--   - 将基础颜色名称（black, white, red 等）映射为 RGB
--
-- @param s (string|nil) RGB 颜色字符串
-- @return (string|nil) 归一化的 "r g b" 字符串或 nil
local function normalize_rgb(s)
    if s == nil then return nil end
    s = tostring(s)
    if s == "nil" or s == "" then return nil end

    -- Map basic color names
    local color_map = {
        black  = "0.0000 0.0000 0.0000",
        white  = "1.0000 1.0000 1.0000",
        red    = "1.0000 0.0000 0.0000",
        green  = "0.0000 1.0000 0.0000",
        blue   = "0.0000 0.0000 1.0000",
        yellow = "1.0000 1.0000 0.0000",
        gray   = "0.5000 0.5000 0.5000",
    }
    local low_s = s:lower():gsub("^%s*(.-)%s*$", "%1")
    local mapped = color_map[low_s]
    if mapped then return mapped end

    -- Strip common prefixes and suffixes
    -- Handle rgb:(...), RGB:(...), color:...
    s = s:gsub("^rgb%s*:%s*", ""):gsub("^RGB%s*:%s*", ""):gsub("^color%s*:%s*", "")
    s = s:gsub("[{}%[%]%(%)]", " ")
    s = s:gsub("[,;]", " ")
    s = s:gsub("%s+", " "):gsub("^%s*(.-)%s*$", "%1")

    -- Extract RGB values (supports 3 numbers)
    local r_raw, g_raw, b_raw = s:match("([%d%.]+)%s+([%d%.]+)%s+([%d%.]+)")
    if not r_raw then
        return nil
    end

    local r, g, b = tonumber(r_raw), tonumber(g_raw), tonumber(b_raw)
    if not r or not g or not b then return nil end

    -- Convert 0-255 range to 0-1 range
    -- If any value is > 1.0, assume it's 0-255 scale
    if r > 1.0 or g > 1.0 or b > 1.0 then
        return string.format("%.4f %.4f %.4f", r / 255, g / 255, b / 255)
    end

    return string.format("%.4f %.4f %.4f", r, g, b)
end

--- 使用 PDF literal 绘制调试矩形
-- @param head node 节点列表头部（直接引用）
-- @param anchor node 要在其前插入的节点（直接引用）。如果为 nil，则插入到头部。
-- @param x_sp number X 轴起始坐标 (sp)
-- @param y_sp number Y 轴起始坐标 (sp, 顶边缘)
-- @param w_sp number 宽度 (sp)
-- @param h_sp number 高度 (sp, 向下为负)
-- @param color_cmd string PDF 颜色指令（例如 "1 0 0 RG"）
-- @return node 更新后的头部
local function draw_debug_rect(head, anchor, x_sp, y_sp, w_sp, h_sp, color_cmd)
    local tx_bp = x_sp * sp_to_bp
    local ty_bp = y_sp * sp_to_bp
    local tw_bp = w_sp * sp_to_bp
    local th_bp = h_sp * sp_to_bp

    -- literal for rectangle: q (save state) 0.5 w (line width) <color> 1 0 0 1 <x> <y> cm (move) 0 0 <w> <h> re (rect) S (stroke) Q (restore)
    local literal = string.format("q 0.5 w %s 1 0 0 1 %.4f %.4f cm 0 0 %.4f %.4f re S Q", color_cmd, tx_bp, ty_bp, tw_bp,
        th_bp)

    -- Use more robust node creation
    local whatsit_id = node.id("whatsit")
    local pdf_literal_id = node.subtype("pdf_literal")
    local nn = node.direct.new(whatsit_id, pdf_literal_id)
    node.direct.setfield(nn, "data", literal)
    node.direct.setfield(nn, "mode", 0)

    if anchor then
        return node.direct.insert_before(head, anchor, nn)
    else
        return node.direct.insert_before(head, head, nn)
    end
end

local function draw_debug_grid(head, x_sp, y_sp, w_sp, h_total_sp, color_name)
    local tx_bp = x_sp * sp_to_bp
    local ty_bp = y_sp * sp_to_bp
    local tw_bp = w_sp * sp_to_bp
    local th_bp = h_total_sp * sp_to_bp

    local color_str = "0 0 1 RG" -- Default blue
    if color_name == "red" then color_str = "1 0 0 RG" end
    if color_name == "green" then color_str = "0 1 0 RG" end

    -- Draw a single rectangle for the column
    local literal = string.format("q 0.2 w %s %.4f %.4f %.4f %.4f re S Q", color_str, tx_bp, ty_bp, tw_bp, -th_bp)

    local whatsit_id = node.id("whatsit")
    local pdf_literal_id = node.subtype("pdf_literal")
    local nn = node.direct.new(whatsit_id, pdf_literal_id)
    node.direct.setfield(nn, "data", literal)
    node.direct.setfield(nn, "mode", 0)

    return node.direct.insert_before(head, head, nn)
end

--- 创建具有给定数据的 PDF literal 节点（直接节点版本）
-- @param literal_str string PDF literal 字符串
-- @param mode number 可选模式（默认 0: 原点位于当前位置）
-- @return node 直接节点引用
local function create_pdf_literal(literal_str, mode)
    local whatsit_id = node.id("whatsit")
    local pdf_literal_id = node.subtype("pdf_literal")
    local nn = node.direct.new(whatsit_id, pdf_literal_id)
    node.direct.setfield(nn, "data", literal_str)
    node.direct.setfield(nn, "mode", mode or 0)
    return nn
end

--- 在节点列表中插入 PDF literal 节点
-- @param head node 直接节点链头部
-- @param literal_str string PDF literal 字符串
-- @param anchor node 可选，要在其前插入的节点。如果为 nil，则插入到头部。
-- @return node 更新后的头部（直接节点引用）
local function insert_pdf_literal(head, literal_str, anchor)
    local nn = create_pdf_literal(literal_str)
    return node.direct.insert_before(head, anchor or head, nn)
end

--- 创建颜色设置 PDF literal 字符串
-- @param rgb string RGB 颜色字符串 "r g b"
-- @param is_stroke boolean 是否为描边色 (RG) 而非填充色 (rg)
-- @return string PDF literal 字符串
local function create_color_literal(rgb, is_stroke)
    local op = is_stroke and "RG" or "rg"
    return string.format("%s %s", rgb, op)
end

--- 创建位置变换 PDF literal 字符串
-- @param x_bp number X 坐标 (bp)
-- @param y_bp number Y 坐标 (bp)
-- @return string PDF literal 字符串
local function create_position_cm(x_bp, y_bp)
    return string.format("1 0 0 1 %.4f %.4f cm", x_bp, y_bp)
end

--- 包裹 PDF 指令在图形状态中 (q ... Q)
-- @param inner string 内部 PDF 指令
-- @return string 包裹后的 PDF literal
local function wrap_graphics_state(inner)
    return "q " .. inner .. " Q"
end

--- 创建完整的着色定位 PDF literal 字符串（起始部分，需配对 Q）
-- @param rgb string RGB 颜色
-- @param x_bp number X 坐标 (bp)
-- @param y_bp number Y 坐标 (bp)
-- @return string PDF literal 字符串（用于开始：q ... cm）
local function create_color_position_literal(rgb, x_bp, y_bp)
    return string.format("%s %s %s", create_color_literal(rgb, false), create_color_literal(rgb, true),
        create_position_cm(x_bp, y_bp))
end

--- 创建完整的着色定位 PDF literal 字符串（起始部分，含 q）
-- @param rgb string RGB 颜色
-- @param x_bp number X 坐标 (bp)
-- @param y_bp number Y 坐标 (bp)
-- @return string PDF literal 字符串（用于开始：q ... cm）
local function create_color_position_q_literal(rgb, x_bp, y_bp)
    return "q " .. create_color_position_literal(rgb, x_bp, y_bp)
end

--- 生成 PDF 矩形指令 (raw)
-- @param x number X 坐标 (bp)
-- @param y number Y 坐标 (bp)
-- @param w number 宽度 (bp)
-- @param h number 高度 (bp)
-- @param op string PDF 指令后缀 (例如 "re S" 或 "re f")
-- @return string PDF literal 字符串
local function create_rect_literal_raw(x, y, w, h, op)
    return string.format("%.4f %.4f %.4f %.4f %s", x, y, w, h, op)
end

--- 生成带图形状态保护的边框矩形指令
-- @param thickness number 边框厚度 (bp)
-- @param rgb_str string RGB 颜色字符串
-- @param x number X 坐标 (bp)
-- @param y number Y 坐标 (bp)
-- @param w number 宽度 (bp)
-- @param h number 高度 (bp)
-- @return string PDF literal 字符串
local function create_border_literal(thickness, rgb_str, x, y, w, h)
    local inner = string.format("%.2f w %s RG %s", thickness, rgb_str, create_rect_literal_raw(x, y, w, h, "re S"))
    return wrap_graphics_state(inner)
end

--- 生成带图形状态保护的填充矩形指令
-- @param rgb_str string RGB 颜色字符串
-- @param x number X 坐标 (bp)
-- @param y number Y 坐标 (bp)
-- @param w number 宽度 (bp)
-- @param h number 高度 (bp)
-- @return string PDF literal 字符串
local function create_fill_rect_literal(rgb_str, x, y, w, h)
    local inner = string.format("0 w %s rg %s", rgb_str, create_rect_literal_raw(x, y, w, h, "re f"))
    return wrap_graphics_state(inner)
end

--- 创建图形状态结束 PDF literal
-- @return string PDF literal 字符串 "Q"
local function create_graphics_state_end()
    return "Q"
end

--- 将整数转换为传统的中文数字字符串
-- 例如：1 -> "一", 10 -> "十", 21 -> "二十一"
-- @param n number 要转换的数字
-- @return string 中文数字字符串
local function to_chinese_numeral(n)
    if not n or n <= 0 then return "" end
    local digits = { "一", "二", "三", "四", "五", "六", "七", "八", "九" }
    if n < 10 then
        return digits[n]
    elseif n == 10 then
        return "十"
    elseif n < 20 then
        return "十" .. digits[n - 10]
    elseif n < 100 then
        local tens = math.floor(n / 10)
        local ones = n % 10
        local s = digits[tens] .. "十"
        if ones > 0 then
            s = s .. digits[ones]
        end
        return s
    else
        -- Simple support up to 999 for now
        local hundreds = math.floor(n / 100)
        local rest = n % 100
        local s = digits[hundreds] .. "百"
        if rest > 0 then
            if rest < 10 then
                s = s .. "零" .. digits[rest]
            else
                s = s .. to_chinese_numeral(rest)
            end
        end
        return s
    end
end

--- 将整数逐位转换为中文数字（915 → 九一五）
-- 每一位数字独立转换，不使用位值（百/十）
-- @param n number 要转换的数字
-- @return string 中文数字字符串
local function to_chinese_digits(n)
    if not n or n <= 0 then return "" end
    local digit_map = {
        [0] = "〇", "一", "二", "三", "四",
        "五", "六", "七", "八", "九"
    }
    local s = tostring(n)
    local parts = {}
    for i = 1, #s do
        local d = tonumber(s:sub(i, i))
        table.insert(parts, digit_map[d] or tostring(d))
    end
    return table.concat(parts)
end

--- 将整数转换为圆圈数字（①②③...）
-- Unicode circled numbers: ① U+2460 through ⑳ U+2473, then ㉑ U+3251 through ㊿ U+32BF
-- @param n number 要转换的数字
-- @return string 圆圈数字字符串
local function to_circled_numeral(n)
    if not n or n <= 0 then return "" end
    if n <= 20 then
        return utf8.char(0x2460 + n - 1)  -- ① = U+2460
    elseif n <= 50 then
        return utf8.char(0x3251 + n - 21) -- ㉑ = U+3251
    else
        return "(" .. tostring(n) .. ")"  -- fallback for n > 50
    end
end

-- Chapter Marker Registry
_G.chapter_registry = _G.chapter_registry or {}
-- _G.chapter_registry = _G.chapter_registry or {} -- Moved inside function

--- 注册章节标题并返回 ID
-- @param title string 章节标题文字
-- @return number 注册 ID
local function insert_chapter_marker(title)
    _G.chapter_registry = _G.chapter_registry or {}
    table.insert(_G.chapter_registry, title)
    return #_G.chapter_registry
end

-- =============================================================================
-- TeX Variable Reading Helpers
-- =============================================================================
-- These functions allow Lua code to read LaTeX3 variables directly from TeX
-- using LuaTeX's token interface.

--- Read a TeX token list variable (tl) as a string
-- @param var_name string The LaTeX3 variable name (e.g., "l__luatexcn_banxin_upper_ratio_tl")
-- @return string|nil The value of the variable, or nil if not defined
local function get_tex_tl(var_name)
    local cs_name = var_name
    -- Use token.get_macro to get the expansion of the macro
    local value = token.get_macro(cs_name)
    if value == nil or value == "" then return nil end
    return value
end

--- Read a TeX boolean variable (bool) as a Lua boolean
-- LaTeX3 bools are stored as \chardef tokens: 0 for false, 1 for true
-- @param var_name string The LaTeX3 variable name (e.g., "l__luatexcn_banxin_on_bool")
-- @return boolean The boolean value (defaults to false if not defined)
local function get_tex_bool(var_name)
    -- For LaTeX3 bool variables, check the chardef value
    local tok = token.create(var_name)
    if tok and tok.cmdname == "char_given" then
        return tok.index == 1
    end
    return false
end

--- Read a TeX integer variable (int) as a Lua number
-- @param var_name string The LaTeX3 variable name (e.g., "l__luatexcn_banxin_chapter_title_cols_int")
-- @return number The integer value (defaults to 0 if not defined)
local function get_tex_int(var_name)
    local tok = token.create(var_name)
    if tok and tok.cmdname == "assign_int" then
        return tex.count[tok.index] or 0
    elseif tok and tok.cmdname == "char_given" then
        return tok.index or 0
    end
    return 0
end

--- Read a TeX dimension and convert to scaled points
-- @param tl_value string The dimension string (e.g., "10pt", "2cm")
-- @return number The dimension in scaled points
local function parse_dim_to_sp(tl_value)
    if not tl_value or tl_value == "" then return 0 end
    -- Use tex.sp to parse dimension strings
    local ok, result = pcall(tex.sp, tl_value)
    if ok then return result end
    return 0
end

-- Create module table
-- 模块导出表
local utils = {
    normalize_rgb = normalize_rgb,
    sp_to_bp = sp_to_bp,

    draw_debug_rect = draw_debug_rect,
    draw_debug_grid = draw_debug_grid,
    create_pdf_literal = create_pdf_literal,
    insert_pdf_literal = insert_pdf_literal,
    create_color_literal = create_color_literal,
    create_position_cm = create_position_cm,
    wrap_graphics_state = wrap_graphics_state,
    create_color_position_literal = create_color_position_literal,
    create_color_position_q_literal = create_color_position_q_literal,
    create_fill_rect_literal = create_fill_rect_literal,
    create_border_literal = create_border_literal,
    create_graphics_state_end = create_graphics_state_end,
    to_chinese_numeral = to_chinese_numeral,
    to_chinese_digits = to_chinese_digits,
    to_circled_numeral = to_circled_numeral,

    insert_chapter_marker = insert_chapter_marker,

    -- TeX variable reading helpers
    get_tex_tl = get_tex_tl,
    get_tex_bool = get_tex_bool,
    get_tex_int = get_tex_int,
    parse_dim_to_sp = parse_dim_to_sp,
}

-- Register module in package.loaded for require() compatibility
-- 注册模块到 package.loaded
package.loaded['util.luatex-cn-utils'] = utils

-- Return module exports
return utils
