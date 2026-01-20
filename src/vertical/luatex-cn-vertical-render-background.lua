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
-- render_background.lua - 背景色与字体颜色模块
-- ============================================================================
-- 文件名: render_background.lua (原 background.lua)
-- 层级: 第三阶段 - 渲染层 (Stage 3: Render Layer)
--
-- 【模块功能 / Module Purpose】
-- 本模块负责设置页面背景色和全局字体颜色：
--   1. draw_background: 绘制背景色矩形（可选覆盖整个页面或仅内容区）
--   2. set_font_color: 设置后续所有文字的填充颜色
--
-- 【注意事项】
--   • 背景色优先使用 paper_width/height（覆盖整页），否则使用 inner_width/height
--   • 使用 PDF fill 指令（rg + re + f），与边框的 stroke（RG + S）不同
--   • 背景必须在最底层绘制（通过 insert_before 到 p_head 前面插入）
--   • 字体颜色使用小写 "rg"（填充色），必须经过 normalize_rgb 转换为数字格式
--   • 【重要】如果由于逻辑错误导致背景在文字之后绘制，文字将被完全覆盖（不可见）
--   • 【重要】非法 RGB 字符串（如 "blue"）会导致 pdf_literal 解析失败，从而使页面内容消失
--
-- 【整体架构】
--   draw_background(p_head, params)
--      ├─ 如果有 paper_width/height，计算覆盖整页的矩形
--      ├─ 否则使用 inner_width/height + outer_shift
--      ├─ 生成 PDF literal: "q 0 w rgb rg x y w h re f Q"
--      └─ 插入到节点链最前面（确保在最底层）
--
--   set_font_color(p_head, font_rgb_str)
--      └─ 生成 PDF literal: "rgb rg"（设置填充色）
--
-- ============================================================================

-- Load dependencies
local constants = package.loaded['luatex-cn-vertical-base-constants'] or require('luatex-cn-vertical-base-constants')
local D = constants.D
local utils = package.loaded['luatex-cn-vertical-base-utils'] or require('luatex-cn-vertical-base-utils')

--- 绘制背景色矩形
-- @param p_head (node) 节点列表头部（直接引用）
-- @param params (table) 参数表:
--   - bg_rgb_str: 归一化的 RGB 颜色字符串
--   - paper_width: 纸张宽度 (sp, 可选)
--   - paper_height: 纸张高度 (sp, 可选)
--   - margin_left: 左边距 (sp, 可选)
--   - margin_top: 上边距 (sp, 可选)
--   - inner_width: 内部内容宽度 (sp, 备选)
--   - inner_height: 内部内容高度 (sp, 备选)
--   - outer_shift: 外边框偏移 (sp, 备选)
-- @return (node) 更新后的头部
local function draw_background(p_head, params)
    local sp_to_bp = utils.sp_to_bp
    local bg_rgb_str = params.bg_rgb_str

    if not bg_rgb_str then
        return p_head
    end

    local p_width = params.paper_width or 0
    local p_height = params.paper_height or 0
    local m_left = params.margin_left or 0
    local m_top = params.margin_top or 0
    -- Skip background rectangle for full pages (handled by \pagecolor).
    -- Still draw for textboxes, but they should use their own inner dimensions.
    if not params.is_textbox and p_width > 0 then
        return p_head
    end

    local tx_bp, ty_bp, tw_bp, th_bp

    -- Use inner dimensions for textboxes OR if paper size is not provided/valid
    if not params.is_textbox and p_width > 0 and p_height > 0 then
        -- Background covers the entire page
        -- The origin (0,0) in our box is at (margin_left, paper_height - margin_top)
        tx_bp = -m_left * sp_to_bp
        ty_bp = m_top * sp_to_bp
        tw_bp = p_width * sp_to_bp
        th_bp = -p_height * sp_to_bp
    else
        -- Fallback to box-sized background if paper size is not provided
        local inner_width = params.inner_width or 0
        local inner_height = params.inner_height or 0
        local outer_shift = params.outer_shift or 0
        tx_bp = 0
        ty_bp = 0
        tw_bp = (inner_width + outer_shift * 2) * sp_to_bp
        th_bp = -(inner_height + outer_shift * 2) * sp_to_bp
    end


    -- Draw filled rectangle for background
    local literal = string.format("q 0 w %s rg %.4f %.4f %.4f %.4f re f Q",
        bg_rgb_str, tx_bp, ty_bp, tw_bp, th_bp)
    local n_node = node.new("whatsit", "pdf_literal")
    n_node.data = literal
    n_node.mode = 0
    p_head = D.insert_before(p_head, p_head, D.todirect(n_node))

    return p_head
end

--- 设置后续文字的字体颜色
-- @param p_head (node) 节点列表头部（直接引用）
-- @param font_rgb_str (string) 归一化的 RGB 颜色字符串
-- @return (node) 更新后的头部
local function set_font_color(p_head, font_rgb_str)
    if not font_rgb_str then
        return p_head
    end

    -- Set fill color for text (uses lowercase 'rg' for fill color)
    local literal = string.format("%s rg", font_rgb_str)
    local n_node = node.new("whatsit", "pdf_literal")
    n_node.data = literal
    n_node.mode = 0
    p_head = D.insert_before(p_head, p_head, D.todirect(n_node))

    return p_head
end

-- Create module table
local background = {
    draw_background = draw_background,
    set_font_color = set_font_color,
}

-- Register module in package.loaded for require() compatibility
-- 注册模块到 package.loaded
package.loaded['luatex-cn-vertical-render-background'] = background

-- Return module exports
return background
