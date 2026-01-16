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
        black = "0.0000 0.0000 0.0000",
        white = "1.0000 1.0000 1.0000",
        red   = "1.0000 0.0000 0.0000",
        green = "0.0000 1.0000 0.0000",
        blue  = "0.0000 0.0000 1.0000",
        yellow = "1.0000 1.0000 0.0000",
        gray  = "0.5000 0.5000 0.5000",
    }
    local mapped = color_map[s:lower()]
    if mapped then return mapped end

    -- Replace commas with spaces and strip braces/brackets
    s = s:gsub(",", " "):gsub("[{}%[%]]", "")

    -- Extract RGB values
    local r, g, b = s:match("([%d%.]+)%s+([%d%.]+)%s+([%d%.]+)")
    if not r then 
        -- If it's not a numeric RGB, return nil instead of the original string
        -- to avoid injecting invalid PDF literal commands
        return nil 
    end

    r, g, b = tonumber(r), tonumber(g), tonumber(b)
    if not r or not g or not b then return nil end

    -- Convert 0-255 range to 0-1 range
    if r > 1 or g > 1 or b > 1 then
        return string.format("%.4f %.4f %.4f", r/255, g/255, b/255)
    end

    return string.format("%.4f %.4f %.4f", r, g, b)
end

--- 如果开启了 verbose_log，则向日志输出调试消息
-- @param message string 调试消息内容
local function debug_log(message)
    if _G.vertical and _G.vertical.debug and _G.vertical.debug.verbose_log then
        if texio and texio.write_nl then
            texio.write_nl("log", "[Guji-Debug] " .. message)
        end
    end
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
    local literal = string.format("q 0.5 w %s 1 0 0 1 %.4f %.4f cm 0 0 %.4f %.4f re S Q", color_cmd, tx_bp, ty_bp, tw_bp, th_bp)
    
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

--- 创建具有给定数据的 PDF literal 节点
-- @param literal_str string PDF literal 字符串（例如 "q 0.5 w 0 0 0 RG ... Q"）
-- @param mode number 可选模式（默认 0: 原点位于当前位置）
-- @return node 直接节点引用 (pdf_literal whatsit)
local function create_pdf_literal(literal_str, mode)
    local n_node = node.new("whatsit", "pdf_literal")
    n_node.data = literal_str
    n_node.mode = mode or 0
    return n_node
end

--- 在节点列表头部插入 PDF literal 节点
-- @param head node 直接节点链头部
-- @param literal_str string PDF literal 字符串
-- @return node 更新后的头部（直接节点引用）
local function insert_pdf_literal(head, literal_str)
    local n_node = create_pdf_literal(literal_str)
    return node.direct.insert_before(head, head, node.direct.todirect(n_node))
end

--- 将整数转换为传统的中文数字字符串
-- 例如：1 -> "一", 10 -> "十", 21 -> "二十一"
-- @param n number 要转换的数字
-- @return string 中文数字字符串
local function to_chinese_numeral(n)
    if not n or n <= 0 then return "" end
    local digits = {"一", "二", "三", "四", "五", "六", "七", "八", "九"}
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

-- Create module table
-- 模块导出表
local utils = {
    normalize_rgb = normalize_rgb,
    sp_to_bp = sp_to_bp,
    debug_log = debug_log,
    draw_debug_rect = draw_debug_rect,
    create_pdf_literal = create_pdf_literal,
    insert_pdf_literal = insert_pdf_literal,
    to_chinese_numeral = to_chinese_numeral,
}

-- Register module in package.loaded for require() compatibility
-- 注册模块到 package.loaded
package.loaded['base_utils'] = utils

-- Return module exports
return utils
