-- ============================================================================
-- yuwei.lua - 鱼尾（Fish Tail）绘制模块
-- ============================================================================
--
-- 【模块功能】
-- 本模块负责绘制古籍版刻中的"鱼尾"装饰符号：
--   1. 支持实心鱼尾（black）：填充的燕尾形状
--   2. 支持空心鱼尾（white/hollow）：仅描边的轮廓
--   3. 支持上下两个方向：开口朝下（上鱼尾）和开口朝上（下鱼尾）
--   4. 使用贝塞尔曲线构建平滑的弧线
--
-- 【几何模型】
--   鱼尾简化为由贝塞尔曲线组成的"燕尾"形状：
--
--      ▲ 开口（direction=1 时朝下）
--     / \
--    /   \        高度 = width × 0.6
--   /     \
--   ───V───       尾尖
--    width
--
-- 【注意事项】
--   • 坐标系：y 向下为负，x 向右为正
--   • 颜色格式：需要归一化的 RGB 字符串（如 "0 0 0"）
--   • direction=1 表示上鱼尾（尾尖朝下），direction=-1 表示下鱼尾
--
-- 【整体架构】
--   draw_yuwei(params)
--      ├─ 计算宽高比例
--      ├─ 根据 style 选择填充或描边
--      ├─ 生成贝塞尔曲线 PDF 路径
--      └─ 返回 PDF literal 字符串
--
-- Version: 0.1.0
-- Date: 2026-01-13
-- ============================================================================

-- Load dependencies
local constants = package.loaded['constants'] or require('constants')
local utils = package.loaded['utils'] or require('utils')

-- Conversion factor from scaled points to PDF big points
local sp_to_bp = utils.sp_to_bp

--- Draw a yuwei (fish tail) decorative element
-- The yuwei is a filled rectangle with a V-shaped notch cut into it
-- 
-- Shape (direction=1, 上鱼尾 - notch at bottom):
--
--       ←───── width ─────→
--   ┌─────────────────────────┐  ↑
--   │                         │  │ edge_height (longer side edges)
--   │                         │  │
--   └───╲               ╱───┘  ↓
--         ╲           ╱        ↑
--           ╲       ╱          │ (edge_height - notch_height)
--             ╲   ╱            │
--               V              ↓ notch_height from top
--
-- Shape (direction=-1, 下鱼尾 - notch at top):
--               ∧              ↑ notch_height from bottom
--             ╱   ╲            │
--           ╱       ╲          │
--         ╱           ╲        ↓
--   ┌───╱               ╲───┐  ↑
--   │                         │  │ edge_height
--   │                         │  │
--   └─────────────────────────┘  ↓
--
-- @param params (table) Parameters:
--   - x (number) X position of LEFT edge in scaled points
--   - y (number) Y position of TOP edge in scaled points
--   - width (number) Width in scaled points
--   - edge_height (number) Height of the side edges (the longer dimension)
--   - notch_height (number) Distance from top to V-tip (for direction=1) or bottom to V-tip (for direction=-1)
--   - direction (number) 1 = 上鱼尾 (notch at bottom), -1 = 下鱼尾 (notch at top)
--   - style (string) "black" (filled) or "white"/"hollow" (stroked)
--   - color_str (string) RGB color string (e.g., "0 0 0")
--   - line_width (number) Optional line width for hollow style (default 0.8bp)
-- @return (string) PDF literal string
local function draw_yuwei(params)
    local x = params.x or 0
    local y = params.y or 0
    local width = params.width or (18 * 65536)  -- Default 18pt
    local edge_height = params.edge_height or params.height or (width * 0.5)
    local notch_height = params.notch_height or (edge_height * 1.5)  -- V-tip extends beyond edge_height
    local style = params.style or "black"
    local direction = params.direction or 1
    local color_str = params.color_str or "0 0 0"
    local line_width = params.line_width or 0.8
    
    -- Calculate dimensions in bp
    local w_bp = width * sp_to_bp
    local edge_h_bp = edge_height * sp_to_bp
    local notch_h_bp = notch_height * sp_to_bp
    local half_w = w_bp / 2
    
    -- Position in bp (x,y is left-top corner)
    local x_bp = x * sp_to_bp
    local y_bp = y * sp_to_bp
    
    local path
    if style == "black" then
        if direction == 1 then
            -- 上鱼尾: V-notch cuts into shape from bottom
            -- Path: top-left → top-right → bottom-right → V-tip → bottom-left → close
            path = string.format(
                "q %s rg " ..
                "%.4f %.4f m " ..           -- Top-left
                "%.4f %.4f l " ..           -- Top-right
                "%.4f %.4f l " ..           -- Bottom-right (at edge_height)
                "%.4f %.4f l " ..           -- V-tip (at notch_height from top)
                "%.4f %.4f l " ..           -- Bottom-left (at edge_height)
                "h f Q",
                color_str,
                x_bp, y_bp,                                 -- Top-left
                x_bp + w_bp, y_bp,                          -- Top-right
                x_bp + w_bp, y_bp - edge_h_bp,              -- Bottom-right
                x_bp + half_w, y_bp - notch_h_bp,           -- V-tip
                x_bp, y_bp - edge_h_bp                      -- Bottom-left
            )
        else
            -- 下鱼尾: V-notch cuts into shape from top (mirrored)
            -- Path: bottom-left → bottom-right → top-right → V-tip → top-left → close
            path = string.format(
                "q %s rg " ..
                "%.4f %.4f m " ..           -- Bottom-left
                "%.4f %.4f l " ..           -- Bottom-right
                "%.4f %.4f l " ..           -- Top-right (at edge_height from bottom)
                "%.4f %.4f l " ..           -- V-tip (at notch_height from bottom)
                "%.4f %.4f l " ..           -- Top-left (at edge_height from bottom)
                "h f Q",
                color_str,
                x_bp, y_bp - notch_h_bp,                    -- Bottom-left
                x_bp + w_bp, y_bp - notch_h_bp,             -- Bottom-right
                x_bp + w_bp, y_bp - notch_h_bp + edge_h_bp, -- Top-right
                x_bp + half_w, y_bp,                        -- V-tip (at top)
                x_bp, y_bp - notch_h_bp + edge_h_bp         -- Top-left
            )
        end
    else
        -- Hollow/white fish tail - stroke the outline
        if direction == 1 then
            path = string.format(
                "q %s RG %.2f w " ..
                "%.4f %.4f m %.4f %.4f l %.4f %.4f l %.4f %.4f l %.4f %.4f l h S Q",
                color_str, line_width,
                x_bp, y_bp,
                x_bp + w_bp, y_bp,
                x_bp + w_bp, y_bp - edge_h_bp,
                x_bp + half_w, y_bp - notch_h_bp,
                x_bp, y_bp - edge_h_bp
            )
        else
            path = string.format(
                "q %s RG %.2f w " ..
                "%.4f %.4f m %.4f %.4f l %.4f %.4f l %.4f %.4f l %.4f %.4f l h S Q",
                color_str, line_width,
                x_bp, y_bp - notch_h_bp,
                x_bp + w_bp, y_bp - notch_h_bp,
                x_bp + w_bp, y_bp - notch_h_bp + edge_h_bp,
                x_bp + half_w, y_bp,
                x_bp, y_bp - notch_h_bp + edge_h_bp
            )
        end
    end
    
    return path
end

--- Create a PDF literal node for yuwei
-- @param params (table) Same as draw_yuwei
-- @return (node) pdf_literal whatsit node (direct)
local function create_yuwei_node(params)
    local D = constants.D
    local literal_str = draw_yuwei(params)
    
    local whatsit_id = node.id("whatsit")
    local pdf_literal_id = node.subtype("pdf_literal")
    local nn = D.new(whatsit_id, pdf_literal_id)
    D.setfield(nn, "data", literal_str)
    D.setfield(nn, "mode", 0)  -- mode 0: origin at current position
    
    return nn
end

-- Create module table
local yuwei = {
    draw_yuwei = draw_yuwei,
    create_yuwei_node = create_yuwei_node,
}

-- Register module in package.loaded for require() compatibility
package.loaded['yuwei'] = yuwei

-- Return module exports
return yuwei
