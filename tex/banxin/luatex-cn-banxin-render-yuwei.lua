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
-- 层级: 第三阶段 - 渲染层 (Stage 3: Render Layer)
--
-- 【模块功能】
-- 绘制古籍版刻中的"鱼尾"装饰符号：
--   1. 实心鱼尾（black）：填充的燕尾形状
--   2. 空心鱼尾（white/hollow）：仅描边的轮廓
--   3. 支持上下两个方向
--   4. 可选的额外 V 形装饰线
--
-- 【整体架构】
--   draw_yuwei(params)
--      ├─ parse_params() - 解析参数
--      ├─ convert_to_bp() - 坐标转换
--      ├─ create_black_path() / create_hollow_path() - 生成主路径
--      └─ create_extra_line_path() - 生成额外 V 形线
--
-- ============================================================================

-- Load dependencies
local constants = package.loaded['vertical.luatex-cn-vertical-base-constants'] or
    require('vertical.luatex-cn-vertical-base-constants')
local utils = package.loaded['vertical.luatex-cn-vertical-base-utils'] or
    require('vertical.luatex-cn-vertical-base-utils')

-- Conversion factor from scaled points to PDF big points
local sp_to_bp = utils.sp_to_bp

-- ============================================================================
-- Parameter Parsing (参数解析)
-- ============================================================================

--- 解析并规范化鱼尾参数
-- @param params (table) 原始参数表
-- @return (table) 规范化后的参数表
local function parse_params(params)
    local width = params.width or (18 * 65536)
    local edge_height = params.edge_height or params.height or (width * 0.5)
    local notch_height = params.notch_height or (edge_height * 1.5)

    return {
        x = params.x or 0,
        y = params.y or 0,
        width = width,
        edge_height = edge_height,
        notch_height = notch_height,
        style = params.style or "black",
        direction = params.direction or 1,
        color_str = params.color_str or "0 0 0",
        line_width = params.line_width or 0.8,
        extra_line = params.extra_line or false,
        line_gap = params.line_gap or (65536 * 4),
        border_thickness = params.border_thickness or (65536 * 0.4),
    }
end

-- ============================================================================
-- Coordinate Conversion (坐标转换)
-- ============================================================================

--- 将 sp 坐标转换为 bp 坐标
-- @param p (table) 包含 sp 坐标的参数表
-- @return (table) bp 坐标表
local function convert_to_bp(p)
    return {
        x_bp = (p.x or 0) * sp_to_bp,
        y_bp = (p.y or 0) * sp_to_bp,
        w_bp = (p.width or 0) * sp_to_bp,
        edge_h_bp = (p.edge_height or 0) * sp_to_bp,
        notch_h_bp = (p.notch_height or 0) * sp_to_bp,
        half_w = ((p.width or 0) * sp_to_bp) / 2,
        gap_bp = (p.line_gap or 0) * sp_to_bp,
        thickness_bp = (p.border_thickness or 0) * sp_to_bp,
    }
end

-- ============================================================================
-- Path Generation (路径生成)
-- ============================================================================

--- 生成实心上鱼尾路径 (direction=1, V 缺口在底部)
-- @param bp (table) bp 坐标
-- @param color_str (string) 颜色字符串
-- @return (string) PDF 路径字符串
local function create_black_up_path(bp, color_str)
    return string.format(
        "q %s rg " ..
        "%.4f %.4f m " .. -- Top-left
        "%.4f %.4f l " .. -- Top-right
        "%.4f %.4f l " .. -- Bottom-right
        "%.4f %.4f l " .. -- V-tip
        "%.4f %.4f l " .. -- Bottom-left
        "h f Q",
        color_str,
        bp.x_bp, bp.y_bp,
        bp.x_bp + bp.w_bp, bp.y_bp,
        bp.x_bp + bp.w_bp, bp.y_bp - bp.edge_h_bp,
        bp.x_bp + bp.half_w, bp.y_bp - bp.notch_h_bp,
        bp.x_bp, bp.y_bp - bp.edge_h_bp
    )
end

--- 生成实心下鱼尾路径 (direction=-1, V 缺口在顶部)
-- @param bp (table) bp 坐标
-- @param color_str (string) 颜色字符串
-- @return (string) PDF 路径字符串
local function create_black_down_path(bp, color_str)
    return string.format(
        "q %s rg " ..
        "%.4f %.4f m " .. -- Bottom-left
        "%.4f %.4f l " .. -- Bottom-right
        "%.4f %.4f l " .. -- Top-right
        "%.4f %.4f l " .. -- V-tip
        "%.4f %.4f l " .. -- Top-left
        "h f Q",
        color_str,
        bp.x_bp, bp.y_bp - bp.notch_h_bp,
        bp.x_bp + bp.w_bp, bp.y_bp - bp.notch_h_bp,
        bp.x_bp + bp.w_bp, bp.y_bp - bp.notch_h_bp + bp.edge_h_bp,
        bp.x_bp + bp.half_w, bp.y_bp,
        bp.x_bp, bp.y_bp - bp.notch_h_bp + bp.edge_h_bp
    )
end

--- 生成空心上鱼尾路径 (direction=1)
-- @param bp (table) bp 坐标
-- @param color_str (string) 颜色字符串
-- @param line_width (number) 线宽
-- @return (string) PDF 路径字符串
local function create_hollow_up_path(bp, color_str, line_width)
    return string.format(
        "q %s RG %.2f w " ..
        "%.4f %.4f m %.4f %.4f l %.4f %.4f l %.4f %.4f l %.4f %.4f l h S Q",
        color_str, line_width,
        bp.x_bp, bp.y_bp,
        bp.x_bp + bp.w_bp, bp.y_bp,
        bp.x_bp + bp.w_bp, bp.y_bp - bp.edge_h_bp,
        bp.x_bp + bp.half_w, bp.y_bp - bp.notch_h_bp,
        bp.x_bp, bp.y_bp - bp.edge_h_bp
    )
end

--- 生成空心下鱼尾路径 (direction=-1)
-- @param bp (table) bp 坐标
-- @param color_str (string) 颜色字符串
-- @param line_width (number) 线宽
-- @return (string) PDF 路径字符串
local function create_hollow_down_path(bp, color_str, line_width)
    return string.format(
        "q %s RG %.2f w " ..
        "%.4f %.4f m %.4f %.4f l %.4f %.4f l %.4f %.4f l %.4f %.4f l h S Q",
        color_str, line_width,
        bp.x_bp, bp.y_bp - bp.notch_h_bp,
        bp.x_bp + bp.w_bp, bp.y_bp - bp.notch_h_bp,
        bp.x_bp + bp.w_bp, bp.y_bp - bp.notch_h_bp + bp.edge_h_bp,
        bp.x_bp + bp.half_w, bp.y_bp,
        bp.x_bp, bp.y_bp - bp.notch_h_bp + bp.edge_h_bp
    )
end

--- 生成额外 V 形线路径 (上鱼尾，direction=1)
-- @param bp (table) bp 坐标
-- @param color_str (string) 颜色字符串
-- @return (string) PDF 路径字符串
local function create_extra_line_up_path(bp, color_str)
    local v_left_y = bp.y_bp - bp.edge_h_bp - bp.gap_bp
    local v_tip_y = bp.y_bp - bp.notch_h_bp - bp.gap_bp
    local v_right_y = bp.y_bp - bp.edge_h_bp - bp.gap_bp

    return string.format(
        "q %.2f w %s RG %.4f %.4f m %.4f %.4f l %.4f %.4f l S Q",
        bp.thickness_bp, color_str,
        bp.x_bp, v_left_y,
        bp.x_bp + bp.half_w, v_tip_y,
        bp.x_bp + bp.w_bp, v_right_y
    )
end

--- 生成额外 V 形线路径 (下鱼尾，direction=-1)
-- @param bp (table) bp 坐标
-- @param color_str (string) 颜色字符串
-- @return (string) PDF 路径字符串
local function create_extra_line_down_path(bp, color_str)
    local v_left_y = bp.y_bp - bp.notch_h_bp + bp.edge_h_bp + bp.gap_bp
    local v_tip_y = bp.y_bp + bp.gap_bp
    local v_right_y = bp.y_bp - bp.notch_h_bp + bp.edge_h_bp + bp.gap_bp

    return string.format(
        "q %.2f w %s RG %.4f %.4f m %.4f %.4f l %.4f %.4f l S Q",
        bp.thickness_bp, color_str,
        bp.x_bp, v_left_y,
        bp.x_bp + bp.half_w, v_tip_y,
        bp.x_bp + bp.w_bp, v_right_y
    )
end

-- ============================================================================
-- Main Path Builders (主路径构建器)
-- ============================================================================

--- 生成实心鱼尾路径
-- @param bp (table) bp 坐标
-- @param direction (number) 方向 (1 或 -1)
-- @param color_str (string) 颜色字符串
-- @return (string) PDF 路径字符串
local function create_black_path(bp, direction, color_str)
    if direction == 1 then
        return create_black_up_path(bp, color_str)
    else
        return create_black_down_path(bp, color_str)
    end
end

--- 生成空心鱼尾路径
-- @param bp (table) bp 坐标
-- @param direction (number) 方向 (1 或 -1)
-- @param color_str (string) 颜色字符串
-- @param line_width (number) 线宽
-- @return (string) PDF 路径字符串
local function create_hollow_path(bp, direction, color_str, line_width)
    if direction == 1 then
        return create_hollow_up_path(bp, color_str, line_width)
    else
        return create_hollow_down_path(bp, color_str, line_width)
    end
end

--- 生成额外 V 形线路径
-- @param bp (table) bp 坐标
-- @param direction (number) 方向 (1 或 -1)
-- @param color_str (string) 颜色字符串
-- @return (string) PDF 路径字符串
local function create_extra_line_path(bp, direction, color_str)
    if direction == 1 then
        return create_extra_line_up_path(bp, color_str)
    else
        return create_extra_line_down_path(bp, color_str)
    end
end

-- ============================================================================
-- Main Entry Point (主入口函数)
-- ============================================================================

--- 绘制鱼尾装饰元素
-- @param params (table) 参数表
-- @return (string) PDF literal 路径字符串
local function draw_yuwei(params)
    -- 1. Parse parameters
    local p = parse_params(params)

    -- 2. Debug logging
    if luatex_cn_debug and luatex_cn_debug.is_enabled("vertical") then
        utils.debug_log(string.format("[yuwei] Drawing yuwei with style=%s, direction=%d, color=%s",
            tostring(p.style), p.direction, p.color_str))
    end

    -- 3. Convert to bp coordinates
    local bp = convert_to_bp(p)

    -- 4. Generate main path
    local path
    if p.style == "black" then
        path = create_black_path(bp, p.direction, p.color_str)
    else
        path = create_hollow_path(bp, p.direction, p.color_str, p.line_width)
    end

    -- 5. Add extra V-line if requested
    if p.extra_line then
        local extra_path = create_extra_line_path(bp, p.direction, p.color_str)
        path = path .. " " .. extra_path
    end

    return path
end

-- ============================================================================
-- Node Creation (节点创建)
-- ============================================================================

--- 创建鱼尾 PDF literal 节点
-- @param params (table) 与 draw_yuwei 相同
-- @return (node) pdf_literal whatsit 节点
local function create_yuwei_node(params)
    local D = constants.D
    local literal_str = draw_yuwei(params)

    local whatsit_id = node.id("whatsit")
    local pdf_literal_id = node.subtype("pdf_literal")
    local nn = D.new(whatsit_id, pdf_literal_id)
    D.setfield(nn, "data", literal_str)
    D.setfield(nn, "mode", 0)

    return nn
end

-- ============================================================================
-- Module Export
-- ============================================================================

local yuwei = {
    draw_yuwei = draw_yuwei,
    create_yuwei_node = create_yuwei_node,
    -- Internal functions exported for testing
    _internal = {
        parse_params = parse_params,
        convert_to_bp = convert_to_bp,
        create_black_up_path = create_black_up_path,
        create_black_down_path = create_black_down_path,
        create_hollow_up_path = create_hollow_up_path,
        create_hollow_down_path = create_hollow_down_path,
        create_extra_line_up_path = create_extra_line_up_path,
        create_extra_line_down_path = create_extra_line_down_path,
        create_black_path = create_black_path,
        create_hollow_path = create_hollow_path,
        create_extra_line_path = create_extra_line_path,
    },
}

package.loaded['banxin.luatex-cn-banxin-render-yuwei'] = yuwei

return yuwei
