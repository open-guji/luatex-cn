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
-- core_textbox.lua - 文本框（GridTextbox）处理模块
-- ============================================================================
-- 层级: 协调层 (Core/Coordinator Layer)
--
-- 【模块功能】
-- 处理"内嵌文本框"（GridTextbox）的竖排逻辑：
--   1. 接收 TeX 传递的盒子（hlist/vlist）
--   2. 将其视为一个"微型页面"，根据网格参数重新进行布局
--   3. 应用特殊的属性，使其能被外部布局识别
--   4. 处理缩进继承
--
-- 【整体架构】
--   process_inner_box(box_num, params)
--      ├─ get_current_indent() - 获取缩进
--      ├─ parse_column_aligns() - 解析列对齐
--      ├─ build_sub_params() - 构建子参数
--      ├─ execute_layout_pipeline() - 执行布局
--      └─ apply_result_attributes() - 应用属性
--
-- ============================================================================

local constants = package.loaded['vertical.luatex-cn-vertical-base-constants'] or
    require('vertical.luatex-cn-vertical-base-constants')
local utils = package.loaded['vertical.luatex-cn-vertical-base-utils'] or
    require('vertical.luatex-cn-vertical-base-utils')
local D = node.direct

-- ============================================================================
-- Helper Functions (辅助函数)
-- ============================================================================

--- 解析列对齐字符串
-- @param column_aligns_str (string) 逗号分隔的对齐方式 (例如 "right,left")
-- @return (table) 索引从 0 开始的对齐方式表
local function parse_column_aligns(column_aligns_str)
    local col_aligns = {}
    if not column_aligns_str or column_aligns_str == "" then
        return col_aligns
    end

    local idx = 0
    for align in string.gmatch(column_aligns_str, '([^,]+)') do
        align = align:gsub("^%s*(.-)%s*$", "%1") -- Trim whitespace
        col_aligns[idx] = align
        idx = idx + 1
    end
    return col_aligns
end

--- 获取有效的列数
-- @param n_cols (number|nil) 用户指定的列数
-- @return (number) 有效的列数
local function get_effective_n_cols(n_cols)
    local cols = tonumber(n_cols) or 0
    if cols <= 0 then
        return 100 -- Auto columns: large enough to accommodate any content
    end
    return cols
end

--- 获取当前缩进值
-- @param params (table) 参数表
-- @return (number) 缩进值（以网格为单位）
local function get_current_indent(params)
    local current_indent = 0

    -- 从属性获取缩进
    local ci = tex.attribute[constants.ATTR_INDENT]
    if ci and ci > -1 then
        current_indent = ci
    end

    -- 检查 TeX 的 leftskip（列表环境缩进）
    local char_height = constants.to_dimen(params.grid_height) or (65536 * 12)
    local ls_width = tex.leftskip.width
    if ls_width > 0 then
        local ls_indent = math.floor(ls_width / char_height + 0.5)
        current_indent = math.max(current_indent, ls_indent)
    end

    return current_indent
end

--- 构建子网格布局参数
-- @param params (table) 原始参数
-- @param col_aligns (table) 列对齐表
-- @return (table) 子布局参数
local function build_sub_params(params, col_aligns)
    local ba = params.box_align or "top"
    local n_cols = get_effective_n_cols(params.n_cols)

    return {
        n_cols = n_cols,
        page_columns = n_cols,
        col_limit = tonumber(params.height) or 6,
        grid_width = params.grid_width,
        grid_height = params.grid_height,
        box_align = params.box_align,
        column_aligns = col_aligns,
        debug_on = (luatex_cn_debug and luatex_cn_debug.is_enabled("vertical")),
        border_on = (params.border == "true" or params.border == true),
        background_color = params.background_color,
        font_color = params.font_color,
        font_size = params.font_size,
        is_textbox = true,
        distribute = (ba == "fill"),
        border_color = params.border_color,
        floating = (params.floating == "true" or params.floating == true),
        floating_x = constants.to_dimen(params.floating_x) or 0,
        floating_y = constants.to_dimen(params.floating_y) or 0,
        floating_paper_width = constants.to_dimen(params.floating_paper_width) or 0,
    }
end

--- 执行核心排版流水线
-- @param box_num (number) TeX 盒子编号
-- @param sub_params (table) 子布局参数
-- @param current_indent (number) 当前缩进
-- @return (node|nil) 渲染结果盒子
local function execute_layout_pipeline(box_num, sub_params, current_indent)
    local vertical = _G.vertical
    if not vertical or not vertical.prepare_grid then
        utils.debug_log("[textbox] Error: vertical.prepare_grid not found")
        return nil
    end

    -- 临时保存并清空主文档的分页缓存
    local saved_pages = _G.vertical_pending_pages
    _G.vertical_pending_pages = {}

    utils.debug_log("--- textbox.process_inner_box: START (box=" ..
        box_num .. ", indent=" .. tostring(current_indent) .. ") ---")

    -- 调用三阶段流水线
    vertical.prepare_grid(box_num, sub_params)

    -- 获取渲染结果（应当只有 1 "页"）
    local res_box = _G.vertical_pending_pages[1]

    -- Flush any other pages produced
    for i = 2, #_G.vertical_pending_pages do
        if _G.vertical_pending_pages[i] then
            node.flush_list(_G.vertical_pending_pages[i])
        end
    end

    -- 恢复主文档分页缓存
    _G.vertical_pending_pages = saved_pages

    return res_box
end

--- 应用结果属性到盒子
-- @param res_box (node) 结果盒子
-- @param params (table) 原始参数
-- @param current_indent (number) 当前缩进
local function apply_result_attributes(res_box, params, current_indent)
    if not res_box then return end

    -- 获取实际渲染的列数
    local actual_cols = node.get_attribute(res_box, constants.ATTR_TEXTBOX_WIDTH) or 1
    node.set_attribute(res_box, constants.ATTR_TEXTBOX_WIDTH, actual_cols)
    node.set_attribute(res_box, constants.ATTR_TEXTBOX_HEIGHT, tonumber(params.height) or 1)

    -- 应用缩进属性
    if current_indent > 0 then
        node.set_attribute(res_box, constants.ATTR_INDENT, current_indent)
    end
end

-- ============================================================================
-- Floating Textbox Helpers (浮动文本框辅助函数)
-- ============================================================================

--- 创建浮动盒子锚点节点
-- @param id (number) 浮动盒子 ID
-- @return (node) whatsit 节点
local function create_floating_anchor(id)
    local n = node.new("whatsit", "user_defined")
    n.user_id = constants.FLOATING_TEXTBOX_USER_ID
    n.type = 100 -- Integer type
    n.value = id
    return n
end

--- 遍历节点列表查找浮动盒子
-- @param list (node) 节点列表头
-- @param layout_map (table) 布局映射表
-- @param registry (table) 浮动盒子注册表
-- @return (table) 浮动盒子位置数组
local function find_floating_boxes(list, layout_map, registry)
    local floating_map = {}
    if not list then return floating_map end

    local t = D.todirect(list)
    local last_page = 0

    while t do
        local id = D.getid(t)
        if id == constants.WHATSIT then
            local uid = D.getfield(t, "user_id")
            if uid == constants.FLOATING_TEXTBOX_USER_ID then
                local fid = D.getfield(t, "value")
                local item = registry[fid]
                if item then
                    table.insert(floating_map, {
                        box = item.box,
                        page = last_page,
                        x = item.x,
                        y = item.y
                    })
                    utils.debug_log(string.format("[textbox] Placed floating box %d on page %d", fid, last_page))
                end
            end
        else
            local pos = layout_map[t]
            if pos then
                last_page = pos.page or 0
            end
        end
        t = D.getnext(t)
    end

    return floating_map
end

-- ============================================================================
-- Module Table
-- ============================================================================

local textbox = {}

-- Registry for floating textboxes
textbox.floating_registry = {}
textbox.floating_counter = 0

-- ============================================================================
-- Public Functions (公开函数)
-- ============================================================================

--- 将一个 TeX 盒子转化为竖排网格文本框
-- @param box_num (number) TeX 盒子寄存器编号
-- @param params (table) 配置参数
function textbox.process_inner_box(box_num, params)
    local box = tex.box[box_num]
    if not box then return end

    -- Debug log
    utils.debug_log(string.format("[textbox] process_inner_box: floating=%s, floating_x=%s, floating_y=%s",
        tostring(params.floating), tostring(params.floating_x), tostring(params.floating_y)))

    -- 1. 获取缩进上下文
    local current_indent = get_current_indent(params)

    -- 2. 解析列对齐
    local col_aligns = parse_column_aligns(params.column_aligns)

    -- 3. 构建子参数
    local sub_params = build_sub_params(params, col_aligns)

    -- 4. 执行布局流水线
    local res_box = execute_layout_pipeline(box_num, sub_params, current_indent)

    -- 5. 应用属性并写回
    if res_box then
        apply_result_attributes(res_box, params, current_indent)
        tex.box[box_num] = res_box
    end
end

--- Register a floating textbox from a TeX box
-- @param box_num (number) TeX box register number
-- @param params (table) { x = string/dim, y = string/dim }
function textbox.register_floating_box(box_num, params)
    local box = tex.box[box_num]
    if not box then return end

    textbox.floating_counter = textbox.floating_counter + 1
    local id = textbox.floating_counter

    -- Capture the box
    local b = node.copy_list(box)

    textbox.floating_registry[id] = {
        box = b,
        x = constants.to_dimen(params.x) or 0,
        y = constants.to_dimen(params.y) or 0
    }

    utils.debug_log(string.format("[textbox] Registered floating box ID=%d at (%s, %s)",
        id, tostring(params.x), tostring(params.y)))

    -- Write anchor node
    node.write(create_floating_anchor(id))
end

--- Calculate positions for floating boxes
-- @param layout_map (table) Main layout map
-- @param params (table) { list = head_node }
-- @return (table) Array of floating box positions
function textbox.calculate_floating_positions(layout_map, params)
    return find_floating_boxes(params.list, layout_map, textbox.floating_registry)
end

--- Clear the floating textbox registry
function textbox.clear_registry()
    textbox.floating_registry = {}
    textbox.floating_counter = 0
end

-- ============================================================================
-- Module Export
-- ============================================================================

-- Internal functions exported for testing
textbox._internal = {
    parse_column_aligns = parse_column_aligns,
    get_effective_n_cols = get_effective_n_cols,
    get_current_indent = get_current_indent,
    build_sub_params = build_sub_params,
    execute_layout_pipeline = execute_layout_pipeline,
    apply_result_attributes = apply_result_attributes,
    create_floating_anchor = create_floating_anchor,
    find_floating_boxes = find_floating_boxes,
}

package.loaded['vertical.luatex-cn-vertical-core-textbox'] = textbox

return textbox
