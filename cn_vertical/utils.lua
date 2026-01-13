-- ============================================================================
-- utils.lua - 通用工具函数库
-- ============================================================================
--
-- 【模块功能】
-- 本模块提供跨模块共享的工具函数，主要用于数据格式转换：
--   1. normalize_rgb: 将各种 RGB 格式（0-1 或 0-255）归一化为 PDF 标准格式
--   2. sp_to_bp: scaled points 到 PDF big points 的转换系数
--
-- 【注意事项】
--   • normalize_rgb 自动检测并转换 0-255 范围到 0-1 范围
--   • 支持逗号和空格分隔的 RGB 值（"255,0,0" 或 "1.0 0 0"）
--   • 返回的字符串格式为 "r g b"（空格分隔，保留 4 位小数）
--   • sp_to_bp = 1/65536 = 0.0000152018（TeX 内部单位到 PDF 单位）
--
-- 【整体架构】
--   normalize_rgb(rgb_str)
--      ├─ 替换逗号为空格
--      ├─ 提取 r、g、b 数值
--      ├─ 如果任一值 > 1，则除以 255
--      └─ 返回格式化字符串 "r.rrrr g.gggg b.bbbb"
--
-- Version: 0.3.0
-- Date: 2026-01-12
-- ============================================================================

-- Conversion factor from scaled points to PDF big points
local sp_to_bp = 0.0000152018

--- Normalize RGB color string
-- Converts various RGB formats to normalized 0-1 range
-- Accepts formats:
--   - "r,g,b" or "r g b" where values are 0-1 or 0-255
--   - Automatically detects and converts 0-255 range to 0-1
--
-- @param s (string|nil) RGB color string
-- @return (string|nil) Normalized "r g b" string or nil
local function normalize_rgb(s)
    if s == nil then return nil end
    s = tostring(s)
    if s == "nil" or s == "" then return nil end

    -- Replace commas with spaces
    s = s:gsub(",", " ")

    -- Extract RGB values
    local r, g, b = s:match("([%d%.]+)%s+([%d%.]+)%s+([%d%.]+)")
    if not r then return s end

    r, g, b = tonumber(r), tonumber(g), tonumber(b)
    if not r or not g or not b then return s end

    -- Convert 0-255 range to 0-1 range
    if r > 1 or g > 1 or b > 1 then
        return string.format("%.4f %.4f %.4f", r/255, g/255, b/255)
    end

    return string.format("%.4f %.4f %.4f", r, g, b)
end

-- Create module table
local utils = {
    normalize_rgb = normalize_rgb,
    sp_to_bp = sp_to_bp,
}

-- Register module in package.loaded for require() compatibility
package.loaded['utils'] = utils

-- Return module exports
return utils
