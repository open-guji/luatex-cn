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
-- render_border.lua - 边框绘制模块
-- ============================================================================
-- 文件名: render_border.lua (原 border.lua)
-- 层级: 第三阶段 - 渲染层 (Stage 3: Render Layer)
--
-- 【模块功能 / Module Purpose】
-- 本模块负责绘制普通列边框和外边框（版心边框由 banxin.lua 单独处理）：
--   1. draw_column_borders: 绘制普通列的边框（跳过版心列）
--   2. draw_outer_border: 绘制整个内容区域的外围边框
--
-- 【注意事项】
--   • 版心列会被跳过（通过 banxin_cols 参数传入）
--   • 使用 PDF rectangle 指令（re + S）绘制矩形边框
--   • 边框厚度通过 linewidth (w) 控制
--   • 颜色使用 RGB 格式（0.0-1.0，通过 utils.normalize_rgb 归一化）
--
-- 【整体架构】
--   draw_column_borders(p_head, params)
--      ├─ 遍历所有列（0 到 total_cols-1）
--      ├─ 跳过 banxin_cols 中的列
--      ├─ 计算 RTL 列位置（rtl_col = total_cols - 1 - col）
--      ├─ 生成 PDF literal: "q w RG x y w h re S Q"
--      └─ 插入到节点链最前面（使其在底层）
--
--   draw_outer_border(p_head, params)
--      └─ 在整个内容区域外围绘制一个大矩形
--
-- ============================================================================

-- Load dependencies
local constants = package.loaded['vertical.luatex-cn-vertical-base-constants'] or
    require('vertical.luatex-cn-vertical-base-constants')
local D = constants.D
local utils = package.loaded['vertical.luatex-cn-vertical-base-utils'] or
    require('vertical.luatex-cn-vertical-base-utils')

local _internal = {}

-- (create_border_literal and insert_literal_node removed as they are now in base-utils.lua)

_internal.create_border_literal = utils.create_border_literal
_internal.insert_literal_node = utils.insert_pdf_literal

--- 绘制列边框（仅限普通列，不含版心列）
-- 版心列应由 banxin.draw_banxin_column 单独绘制
-- @param p_head (node) 节点列表头部（直接引用）
-- @param params (table) 参数表:
--   - total_cols: 要绘制的总列数
--   - grid_width: 每列的宽度 (sp)
--   - grid_height: 每行的高度 (sp)
--   - line_limit: 每列的行数限制
--   - border_thickness: 边框厚度 (sp)
--   - b_padding_top: 顶部内边距 (sp)
--   - b_padding_bottom: 底部内边距 (sp)
--   - shift_x: 水平偏移 (sp)
--   - outer_shift: 外边框偏移 (sp)
--   - border_rgb_str: 归一化的 RGB 颜色字符串
--   - banxin_cols: 可选，要跳过的列索引集合（版心列）
-- @return (node) 更新后的头部
local function draw_column_borders(p_head, params)
    local sp_to_bp = utils.sp_to_bp
    local total_cols = params.total_cols
    local grid_width = params.grid_width
    local grid_height = params.grid_height
    local line_limit = params.line_limit
    local border_thickness = params.border_thickness
    local b_padding_top = params.b_padding_top
    local b_padding_bottom = params.b_padding_bottom
    local shift_x = params.shift_x
    local outer_shift = params.outer_shift
    local border_rgb_str = params.border_rgb_str
    local banxin_cols = params.banxin_cols or {} -- Set of column indices to skip

    local b_thickness_bp = border_thickness * sp_to_bp
    local half_thickness = math.floor(border_thickness / 2)

    for col = 0, total_cols - 1 do
        -- Skip banxin columns (they are drawn separately by banxin module)
        if not banxin_cols[col] then
            local rtl_col = total_cols - 1 - col
            local tx_bp = (rtl_col * grid_width + half_thickness + shift_x) * sp_to_bp
            local ty_bp = -(half_thickness + outer_shift) * sp_to_bp
            local tw_bp = grid_width * sp_to_bp
            local th_bp = -(line_limit * grid_height + b_padding_top + b_padding_bottom) * sp_to_bp

            -- Draw column border
            local literal = utils.create_border_literal(b_thickness_bp, border_rgb_str, tx_bp, ty_bp, tw_bp, th_bp)
            p_head = utils.insert_pdf_literal(p_head, literal)
        end
    end

    return p_head
end

--- 在整个内容区域外围绘制外边框
-- @param p_head (node) 节点列表头部（直接引用）
-- @param params (table) 参数表:
--   - inner_width: 内部内容宽度 (sp)
--   - inner_height: 内部内容高度 (sp)
--   - outer_border_thickness: 外边框厚度 (sp)
--   - outer_border_sep: 内外边框间距 (sp)
--   - border_rgb_str: 归一化的 RGB 颜色字符串
-- @return (node) 更新后的头部
local function draw_outer_border(p_head, params)
    local sp_to_bp = utils.sp_to_bp
    local inner_width = params.inner_width
    local inner_height = params.inner_height
    local ob_thickness_val = params.outer_border_thickness
    local ob_sep_val = params.outer_border_sep
    local border_rgb_str = params.border_rgb_str

    local ob_thickness_bp = ob_thickness_val * sp_to_bp

    local tx_bp = (ob_thickness_bp / 2)
    local ty_bp = -(ob_thickness_bp / 2)
    local tw_bp = (inner_width + ob_sep_val * 2 + ob_thickness_val) * sp_to_bp
    local th_bp = -(inner_height + ob_sep_val * 2 + ob_thickness_val) * sp_to_bp

    local literal = utils.create_border_literal(ob_thickness_bp, border_rgb_str, tx_bp, ty_bp, tw_bp, th_bp)
    p_head = utils.insert_pdf_literal(p_head, literal)

    return p_head
end

-- Create module table
local border = {
    draw_column_borders = draw_column_borders,
    draw_outer_border = draw_outer_border,
}

-- 注册模块到 package.loaded
package.loaded['vertical.luatex-cn-vertical-render-border'] = border

-- Return module exports
return border
