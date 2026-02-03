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
-- flatten_nodes.lua - 盒子展平与缩进提取（第一阶段）
-- ============================================================================
-- 文件名: flatten_nodes.lua (原 flatten.lua)
-- 层级: 第一阶段 - 展平层 (Stage 1: Flatten Layer)
--
-- 【模块功能 / Module Purpose】
-- 本模块负责排版流水线的第一阶段，将 TeX 复杂的嵌套盒子结构转化为一维节点流：
--   1. 递归遍历 VBox/HBox，将多层嵌套展平为线性节点列表
--   2. 自动检测并提取缩进信息（leftskip glue、box shift）
--   3. 将缩进值转换为字符数并附加为节点属性（ATTR_INDENT）
--   4. 在适当位置插入列中断标记（penalty -10001）
--   5. 过滤无用节点（保留 glyph、kern、特定 glue、textbox 块）
--
-- 【术语对照 / Terminology】
--   flatten         - 展平（将嵌套结构转为线性结构）
--   indent          - 缩进（首行或悬挂缩进）
--   leftskip        - 左侧跳过（TeX 的段落左缩进机制）
--   shift           - 盒子偏移（box.shift 属性）
--   penalty         - 惩罚值（用于控制换行/换列）
--   column break    - 列中断（-10001 触发强制换列）
--   running_indent  - 当前累积缩进（随遍历更新）
--   has_content     - 是否有可见内容（字形或文本框）
--
-- 【注意事项】
--   • 缩进检测依赖 TeX 的 \leftskip 和 box.shift 机制，支持标准的 itemize/enumerate
--   • "列中断"（penalty -10001）在每个 HLIST 行之后插入，用于 layout_grid.lua 识别强制换列
--   • 重点：展平算法高度依赖 TeX 的段落构建，若节点在垂直模式输出（如列表开头的 Textbox），
--     其缩进属性（leftskip）将无法被检测。因此 TeX 端必须确保进入水平模式（如使用 \leavevmode）
--   • Textbox 块通过属性 ATTR_TEXTBOX_WIDTH/HEIGHT 识别，会被完整保留
--   • 右缩进（rightskip）功能已预留但未完全实现（当前只在 layout 中使用）
--   • 节点会被复制（D.copy），原始盒子不会被修改
--
-- 【整体架构 / Architecture】
--   输入: TeX VBox.list (嵌套的 vlist/hlist/glyph 树)
--      ↓
--   flatten_vbox(head, grid_width, char_width)
--      ├─ collect_nodes() 递归遍历
--      │   ├─ 检测 leftskip → 更新 indent
--      │   ├─ 检测 shift → 更新 indent
--      │   └─ 递归处理子盒子
--      ├─ 为每个节点附加 ATTR_INDENT 属性
--      └─ 在行尾插入 penalty -10001
--      ↓
--   输出: 一维节点流（glyph + kern + glue + penalty + textbox块）
--
-- ============================================================================

-- Load dependencies
-- Check if already loaded via dofile (package.loaded set manually)
local constants = package.loaded['core.luatex-cn-constants'] or
    require('core.luatex-cn-constants')
local D = constants.D
local utils = package.loaded['util.luatex-cn-utils'] or
    require('util.luatex-cn-utils')
local debug = package.loaded['debug.luatex-cn-debug'] or
    require('debug.luatex-cn-debug')

local dbg = debug.get_debugger('flatten')

local _internal = {}

--- 计算盒子的缩进（基于 shift 和 leftskip）
-- @param box (direct node) HLIST 或 VLIST 节点
-- @param current_indent (number) 当前累积的缩进值
-- @param char_width (number) 字符宽度
-- @return (number) 新的缩进值
local function get_box_indentation(box, current_indent, char_width)
    local box_indent = current_indent
    local tid = D.getid(box)

    -- Detect Shift on any box
    local shift = D.getfield(box, "shift") or 0
    if shift > 0 then
        box_indent = math.max(box_indent, math.floor(shift / char_width + 0.5))
    end

    -- Priority 2: Check for direct attribute on the box (set by \Paragraph environment)
    local attr_indent = D.get_attribute(box, constants.ATTR_INDENT) or 0
    if attr_indent > 0 then
        box_indent = math.max(box_indent, attr_indent)
    end

    if tid == constants.HLIST then
        -- Check for indent glue/kern inside HLIST
        local s = D.getfield(box, "list")
        while s do
            local sid = D.getid(s)
            if sid == constants.GLYPH or sid == constants.WHATSIT then break end
            if sid == constants.GLUE or sid == constants.KERN then
                local w = D.getfield(s, "width") or 0
                if w > 0 then
                    local calc = w / char_width
                    box_indent = math.max(box_indent, math.floor(calc + 0.5))
                end
            end
            s = D.getnext(s)
        end
    end
    return box_indent
end

--- 判断是否保留该节点
-- @param tid (number) 节点 ID
-- @param subtype (number) 节点子类型
-- @return (boolean) 是否保留
local function should_keep_node(tid, subtype)
    if tid == constants.GLYPH or tid == constants.KERN then
        return true
    elseif tid == constants.GLUE or tid == constants.WHATSIT then
        -- Keep typical glues (0), spaces (13, 14), and WHATITS
        if tid == constants.WHATSIT or subtype == 0 or subtype == 13 or subtype == 14 then
            return true
        end
    elseif tid == constants.PENALTY then
        return true
    end
    return false
end

_internal.get_box_indentation = get_box_indentation

--- 复制节点并应用属性
-- @param t (direct node) 源节点
-- @param indent (number) 缩进值
-- @param r_indent (number) 右缩进值
-- @return (direct node) 复制后的节点
local function copy_node_with_attributes(t, indent, r_indent)
    local copy = D.copy(t)
    if indent > 0 then D.set_attribute(copy, constants.ATTR_INDENT, indent) end
    if r_indent > 0 then D.set_attribute(copy, constants.ATTR_RIGHT_INDENT, r_indent) end

    -- CRITICAL: Preserve textflow attributes (they are set by \TextFlow command)
    local textflow_attr = D.get_attribute(t, constants.ATTR_JIAZHU)
    if textflow_attr then
        D.set_attribute(copy, constants.ATTR_JIAZHU, textflow_attr)
    end
    local textflow_sub_attr = D.get_attribute(t, constants.ATTR_JIAZHU_SUB)
    if textflow_sub_attr then
        D.set_attribute(copy, constants.ATTR_JIAZHU_SUB, textflow_sub_attr)
    end
    local textflow_mode_attr = D.get_attribute(t, constants.ATTR_JIAZHU_MODE)
    if textflow_mode_attr then
        D.set_attribute(copy, constants.ATTR_JIAZHU_MODE, textflow_mode_attr)
    end

    -- CRITICAL: Preserve block indentation attributes
    local block_id = D.get_attribute(t, constants.ATTR_BLOCK_ID)
    if block_id then D.set_attribute(copy, constants.ATTR_BLOCK_ID, block_id) end
    local first_indent = D.get_attribute(t, constants.ATTR_FIRST_INDENT)
    if first_indent then D.set_attribute(copy, constants.ATTR_FIRST_INDENT, first_indent) end

    return copy
end

--- 处理 Textbox 节点
local function process_textbox_node(t, running_indent, running_r_indent)
    local tb_w = D.get_attribute(t, constants.ATTR_TEXTBOX_WIDTH) or 0
    local tb_h = D.get_attribute(t, constants.ATTR_TEXTBOX_HEIGHT) or 0

    if tb_w > 0 and tb_h > 0 then
        local copy = D.copy(t)
        -- Apply running indent (inherited from previous lines if needed)
        if running_indent > 0 then D.set_attribute(copy, constants.ATTR_INDENT, running_indent) end
        if running_r_indent > 0 then D.set_attribute(copy, constants.ATTR_RIGHT_INDENT, running_r_indent) end

        -- Preserve block indentation attributes
        local block_id = D.get_attribute(t, constants.ATTR_BLOCK_ID)
        if block_id then D.set_attribute(copy, constants.ATTR_BLOCK_ID, block_id) end
        local first_indent = D.get_attribute(t, constants.ATTR_FIRST_INDENT)
        if first_indent then D.set_attribute(copy, constants.ATTR_FIRST_INDENT, first_indent) end

        return copy, true
    end
    return nil, false
end

_internal.copy_node_with_attributes = copy_node_with_attributes
_internal.process_textbox_node = process_textbox_node

--- 将 vlist（来自 vbox）展平为单一节点列表
-- 从行首提取缩进并将其应用为属性。
-- 同时清理节点（保留有效的胶水/字形）。
--
-- @param head (node) vlist 的头部
-- @param grid_width (number) 以 SCALED POINTS 为单位网格列宽
-- @param char_width (number) 用于缩进计算的字符宽度（通常为 grid_height）
-- @return (node) 带有缩进属性的展平节点列表
local function flatten_vbox(head, grid_width, char_width)
    local d_head = D.todirect(head)
    local result_head_d = nil
    local result_tail_d = nil

    --- 向结果列表追加一个节点
    -- @param n (direct node) 要追加的节点
    local function append_node(n)
        if not n then return end
        D.setnext(n, nil)
        if not result_head_d then
            result_head_d = n
            result_tail_d = n
        else
            D.setlink(result_tail_d, n)
            result_tail_d = n
        end
    end

    --- 递归节点收集器
    -- @param n_head (direct node) 要收集的节点列表头部（将被消耗）
    -- @param indent_lvl (number) 当前缩进
    -- @param r_indent_lvl (number) 当前右缩进
    -- @param parent_is_vlist (boolean) 父节点是否为 VLIST（用于判断是否为行盒子）
    -- @return (boolean) 如果收集到了任何可见内容（字形/文本框），则返回 true
    local function collect_nodes(n_head, indent_lvl, r_indent_lvl, parent_is_vlist)
        local t = n_head
        local running_indent = indent_lvl
        local running_r_indent = r_indent_lvl
        local has_content = false

        while t do
            local tid = D.getid(t)
            local subtype = D.getsubtype(t)

            -- 1. Try to process as Textbox Block
            local tb_node, is_tb = process_textbox_node(t, running_indent, running_r_indent)
            if is_tb then
                append_node(tb_node)
                has_content = true
            elseif tid == constants.HLIST or tid == constants.VLIST then
                -- 2. Process recursable box (HList/VList)
                local inner = D.getfield(t, "list")

                -- Calculate indentation for this box
                local box_indent = get_box_indentation(t, running_indent, char_width)
                local box_r_indent = running_r_indent -- Right indent logic propagation (if needed)

                -- Recurse
                -- If current node is VLIST, its children are in vertical flow.
                -- If current node is HLIST, its children are inline.
                local inner_parent_is_vlist = (tid == constants.VLIST)
                local inner_has_content = collect_nodes(inner, box_indent, box_r_indent, inner_parent_is_vlist)
                if inner_has_content then has_content = true end

                -- IMPORTANT: Only add penalty for HLIST lines that are part of
                -- the main vertical flow. This prevents inline HLISTs (like \box0 in decorate)
                -- from triggering unwanted column breaks.
                if tid == constants.HLIST and inner_has_content and parent_is_vlist then
                    dbg.log("Adding Column Break after Line=" .. tostring(t))
                    local p = D.new(constants.PENALTY)
                    D.setfield(p, "penalty", -10002)
                    append_node(p)
                end
            else
                -- 3. Process leaf nodes
                if should_keep_node(tid, subtype) then
                    local copy = copy_node_with_attributes(t, running_indent, running_r_indent)

                    D.set_attribute(copy, constants.ATTR_TEXTBOX_WIDTH, 0)
                    D.set_attribute(copy, constants.ATTR_TEXTBOX_HEIGHT, 0)

                    append_node(copy)

                    if tid == constants.GLYPH or tid == constants.WHATSIT then
                        has_content = true
                    end
                end
            end
            t = D.getnext(t)
        end
        return has_content
    end

    -- Initial call: treat input as VList content (true)
    collect_nodes(d_head, 0, 0, true)
    return D.tonode(result_head_d)
end

-- Create module table
local flatten = {
    flatten_vbox = flatten_vbox,
}

-- Register module in package.loaded for require() compatibility
-- 注册模块到 package.loaded
package.loaded['core.luatex-cn-core-flatten-nodes'] = flatten

-- Return module exports
return flatten
