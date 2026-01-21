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
-- render_yuwei.lua - 鱼尾（Fish Tail）绘制模块
-- ============================================================================
-- 文件名: render_yuwei.lua (原 yuwei.lua)
-- 层级: 第三阶段 - 渲染层 (Stage 3: Render Layer)
--
-- 【模块功能 / Module Purpose】
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
-- ============================================================================

-- Load dependencies
local constants = package.loaded['vertical.luatex-cn-vertical-base-constants'] or
    require('vertical.luatex-cn-vertical-base-constants')
local utils = package.loaded['vertical.luatex-cn-vertical-base-utils'] or
    require('vertical.luatex-cn-vertical-base-utils')

-- Conversion factor from scaled points to PDF big points
local sp_to_bp = utils.sp_to_bp

--- 绘制鱼尾（燕尾）装饰元素
-- 鱼尾通常是一个带有 V 形缺口的矩形形状
--
-- 几何形状 (direction=1, 上鱼尾 - 缺口在底部):
--
--       ←───── width ─────→
--   ┌─────────────────────────┐  ↑
--   │                         │  │ edge_height (侧边高度)
--   │                         │  │
--   └───╲               ╱───┘  ↓
--         ╲           ╱        ↑
--           ╲       ╱          │ (edge_height - notch_height)
--             ╲   ╱            │
--               V              ↓ 缺口尖端位置（从顶部起算 notch_height）
--
-- @param params (table) 参数表:
--   - x (number) 左边缘 X 坐标 (sp)
--   - y (number) 顶边缘 Y 坐标 (sp)
--   - width (number) 宽度 (sp)
--   - edge_height (number) 侧边高度 (sp)
--   - notch_height (number) 从顶部到 V 尖端的距离 (direction=1) 或从底部到 V 尖端的距离 (direction=-1)
--   - direction (number) 1 = 上鱼尾 (缺口在底部), -1 = 下鱼尾 (缺口在顶部)
--   - style (string) "black" (实心填充) 或 "white"/"hollow" (空心描边)
--   - color_str (string) RGB 颜色字符串 (例如 "0 0 0")
--   - line_width (number) 可选，空心样式的线宽 (默认 0.8bp)
--   - extra_line (bool) 是否在 V 尖端处额外绘制一条水平线
--   - line_gap (number) 尖端与额外线条之间的间距 (默认 4pt)
--   - border_thickness (number) 额外线条的厚度 (默认 0.4pt)
-- @return (string) PDF literal 路径字符串
local function draw_yuwei(params)
    local x = params.x or 0
    local y = params.y or 0
    local width = params.width or (18 * 65536)                      -- Default 18pt
    local edge_height = params.edge_height or params.height or (width * 0.5)
    local notch_height = params.notch_height or (edge_height * 1.5) -- V-tip extends beyond edge_height
    local style = params.style or "black"
    local direction = params.direction or 1
    local color_str = params.color_str or "0 0 0"

    if _G.vertical and _G.vertical.debug and _G.vertical.debug.verbose_log then
        utils.debug_log(string.format("[yuwei] Drawing yuwei with style=%s, direction=%d, color=%s", tostring(style),
            direction, color_str))
    end
    local line_width = params.line_width or 0.8
    local extra_line = params.extra_line or false
    local line_gap = params.line_gap or (65536 * 4)                   -- 4pt default
    local border_thickness = params.border_thickness or (65536 * 0.4) -- 0.4pt default

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
                "%.4f %.4f m " .. -- Top-left
                "%.4f %.4f l " .. -- Top-right
                "%.4f %.4f l " .. -- Bottom-right (at edge_height)
                "%.4f %.4f l " .. -- V-tip (at notch_height from top)
                "%.4f %.4f l " .. -- Bottom-left (at edge_height)
                "h f Q",
                color_str,
                x_bp, y_bp,                       -- Top-left
                x_bp + w_bp, y_bp,                -- Top-right
                x_bp + w_bp, y_bp - edge_h_bp,    -- Bottom-right
                x_bp + half_w, y_bp - notch_h_bp, -- V-tip
                x_bp, y_bp - edge_h_bp            -- Bottom-left
            )
        else
            -- 下鱼尾: V-notch cuts into shape from top (mirrored)
            -- Path: bottom-left → bottom-right → top-right → V-tip → top-left → close
            path = string.format(
                "q %s rg " ..
                "%.4f %.4f m " .. -- Bottom-left
                "%.4f %.4f l " .. -- Bottom-right
                "%.4f %.4f l " .. -- Top-right (at edge_height from bottom)
                "%.4f %.4f l " .. -- V-tip (at notch_height from bottom)
                "%.4f %.4f l " .. -- Top-left (at edge_height from bottom)
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

    -- Draw extra V-shaped line if requested (parallels the yuwei notch)
    if extra_line then
        local gap_bp = line_gap * sp_to_bp
        local thickness_bp = border_thickness * sp_to_bp
        local extra_line_path

        if direction == 1 then
            -- 上鱼尾: V-line below the yuwei's V-notch
            -- The V-line starts at edge_height + gap, and its tip is at notch_height + gap
            local v_left_y = y_bp - edge_h_bp - gap_bp
            local v_tip_y = y_bp - notch_h_bp - gap_bp
            local v_right_y = y_bp - edge_h_bp - gap_bp
            extra_line_path = string.format(
                "q %.2f w %s RG %.4f %.4f m %.4f %.4f l %.4f %.4f l S Q",
                thickness_bp, color_str,
                x_bp, v_left_y,         -- Left point
                x_bp + half_w, v_tip_y, -- V-tip (center bottom)
                x_bp + w_bp, v_right_y  -- Right point
            )
        else
            -- 下鱼尾: V-line above the yuwei's V-notch (inverted)
            local v_left_y = y_bp - notch_h_bp + edge_h_bp + gap_bp
            local v_tip_y = y_bp + gap_bp
            local v_right_y = y_bp - notch_h_bp + edge_h_bp + gap_bp
            extra_line_path = string.format(
                "q %.2f w %s RG %.4f %.4f m %.4f %.4f l %.4f %.4f l S Q",
                thickness_bp, color_str,
                x_bp, v_left_y,         -- Left point
                x_bp + half_w, v_tip_y, -- V-tip (center top)
                x_bp + w_bp, v_right_y  -- Right point
            )
        end
        path = path .. " " .. extra_line_path
    end

    return path
end

--- 为鱼尾创建一个 PDF literal 节点
-- @param params (table) 与 draw_yuwei 相同
-- @return (node) pdf_literal whatsit 节点 (直接引用)
local function create_yuwei_node(params)
    local D = constants.D
    local literal_str = draw_yuwei(params)

    local whatsit_id = node.id("whatsit")
    local pdf_literal_id = node.subtype("pdf_literal")
    local nn = D.new(whatsit_id, pdf_literal_id)
    D.setfield(nn, "data", literal_str)
    D.setfield(nn, "mode", 0) -- mode 0: origin at current position

    return nn
end

-- Create module table
local yuwei = {
    draw_yuwei = draw_yuwei,
    create_yuwei_node = create_yuwei_node,
}

-- Register module in package.loaded for require() compatibility
-- 注册模块到 package.loaded
package.loaded['banxin.luatex-cn-banxin-render-yuwei'] = yuwei

-- Return module exports
return yuwei
