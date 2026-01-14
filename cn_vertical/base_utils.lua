-- ============================================================================
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
-- Version: 0.4.0
-- Date: 2026-01-13
-- ============================================================================

-- Conversion factor from scaled points to PDF big points
local sp_to_bp = 0.0000152018

--- Normalize RGB color string
-- Converts various RGB formats to normalized 0-1 range
-- Accepts formats:
--   - "r,g,b" or "r g b" where values are 0-1 or 0-255
--   - Automatically detects and converts 0-255 range to 0-1
--   - Maps basic color names (black, white, red, etc.) to RGB
--
-- @param s (string|nil) RGB color string
-- @return (string|nil) Normalized "r g b" string or nil
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

    -- Replace commas with spaces
    s = s:gsub(",", " ")

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

--- Output debug message to log if verbose_log is enabled
--- @param message string
local function debug_log(message)
    if _G.cn_vertical and _G.cn_vertical.debug and _G.cn_vertical.debug.verbose_log then
        if texio and texio.write_nl then
            texio.write_nl("log", "[Guji-Debug] " .. message)
        end
    end
end

--- Draw a debug rectangle using PDF literals
--- @param head node Head of node list (direct)
--- @param anchor node Node to insert before (direct). If nil, prepends to head.
--- @param x_sp number X position in scaled points
--- @param y_sp number Y position in scaled points (top edge)
--- @param w_sp number Width in scaled points
--- @param h_sp number Height in scaled points (negative for downward)
--- @param color_cmd string PDF color command (e.g., "1 0 0 RG")
--- @return node Updated head
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

--- Create a PDF literal node with the given data
--- 创建 PDF 直写节点（pdf_literal whatsit）
--- @param literal_str string PDF literal string (e.g., "q 0.5 w 0 0 0 RG ... Q")
--- @param mode number Optional mode (default 0: origin at current position)
--- @return node Direct node (pdf_literal whatsit)
local function create_pdf_literal(literal_str, mode)
    local n_node = node.new("whatsit", "pdf_literal")
    n_node.data = literal_str
    n_node.mode = mode or 0
    return n_node
end

--- Insert a PDF literal node before the head of a node list (direct API version)
--- 在节点链头部插入 PDF 直写节点（使用 direct API）
--- @param head node Direct node head
--- @param literal_str string PDF literal string
--- @return node Updated head (direct node)
local function insert_pdf_literal(head, literal_str)
    local n_node = create_pdf_literal(literal_str)
    return node.direct.insert_before(head, head, node.direct.todirect(n_node))
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
}

-- Register module in package.loaded for require() compatibility
-- 注册模块到 package.loaded
package.loaded['base_utils'] = utils

-- Return module exports
return utils
