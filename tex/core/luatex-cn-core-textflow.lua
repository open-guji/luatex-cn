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
-- core_textflow.lua - 夹注（Jiazhu）平衡与分段逻辑
-- ============================================================================
-- 文件名: core_textflow.lua
-- 层级: 协调层 (Core Layer)
--
-- 【模块功能 / Module Purpose】
-- 本模块负责处理夹注（双行小注）的逻辑：
--   1. 将一段夹注节点平衡分配到左右两个子列（Sub-column）。
--   2. 处理夹注跨列（Continuous Break）逻辑，根据剩余空间进行切分。
--   3. 为节点添加 ATTR_JIAZHU_SUB 属性（1: 右/先行, 2: 左/后行）。
--
-- 【主要算法 / Main Algorithm】
--   设可用高度为 H，则容量为 C = H * 2。
--   如果夹注长度 L <= C，则进行平衡分配：右方 = ceil(L/2)，左方 = L - ceil(L/2)。
--   如果 L > C，则填满当前列（右方 = H，左方 = H），剩余部分跨到下一列。
--
--
-- ============================================================================

local constants = package.loaded['core.luatex-cn-constants'] or
    require('core.luatex-cn-constants')
local D = constants.D

local textflow = {}

--- 计算子列（如双行注 Jiazhu）的 X 偏移
-- @param base_x (number) 基础 X 坐标 (sp)
-- @param grid_width (number) 单元格总宽度 (sp)
-- @param w (number) 字符宽度 (sp)
-- @param sub_col (number) 子列号 (1: 右, 2: 左)
-- @param align (string) 对齐方式 (outward, inward, center, left, right)
-- @return (number) 物理 X 坐标 (sp)
function textflow.calculate_sub_column_x_offset(base_x, grid_width, w, sub_col, align)
    local sub_width = grid_width / 2
    local inner_padding = sub_width * 0.05 -- 5% internal padding

    align = align or "outward"

    local col_align
    if align == "inward" then
        col_align = (sub_col == 1) and "left" or "right"
    elseif align == "center" then
        col_align = "center"
    elseif align == "left" then
        col_align = "left"
    elseif align == "right" then
        col_align = "right"
    else -- outward (default)
        col_align = (sub_col == 1) and "right" or "left"
    end

    local sub_base_x = base_x
    if sub_col == 1 then sub_base_x = sub_base_x + sub_width end

    if col_align == "right" then
        return sub_base_x + (sub_width - w) - inner_padding
    elseif col_align == "left" then
        return sub_base_x + inner_padding
    else -- center
        return sub_base_x + (sub_width - w) / 2
    end
end

--- Collect consecutive jiazhu glyph nodes starting from a given node
-- @param start_node (direct node) Starting node (must have ATTR_JIAZHU == 1)
-- @return (table, direct node) Array of jiazhu glyph nodes, next non-jiazhu node
function textflow.collect_jiazhu_nodes(start_node)
    local j_nodes = {}
    local temp_t = start_node

    while temp_t and D.get_attribute(temp_t, constants.ATTR_JIAZHU) == 1 do
        local tid = D.getid(temp_t)
        if tid == constants.GLYPH then
            table.insert(j_nodes, temp_t)
        end
        temp_t = D.getnext(temp_t)
    end

    return j_nodes, temp_t
end

--- 将一段连续的夹注节点进行分块和平衡
-- @param jiazhu_nodes (table) 连续的夹注节点列表 (direct nodes)
-- @param available_rows (number) 当前列剩余的可选行数
-- @param line_limit (number) 每列的总行数限制
-- @return (table) chunks: { {nodes_with_attr, rows_used, is_full_column}, ... }
function textflow.process_jiazhu_sequence(jiazhu_nodes, available_rows, line_limit, mode)
    local total_nodes = #jiazhu_nodes
    if total_nodes == 0 then return {} end

    local chunks = {}
    local current_idx = 1
    local first_chunk = true

    -- Mode 1: Right only, Mode 2: Left only, Other: Balanced
    local is_single_column = (mode == 1 or mode == 2)

    while current_idx <= total_nodes do
        local h = first_chunk and available_rows or line_limit
        local capacity
        if is_single_column then
            capacity = h
        else
            capacity = h * 2
        end

        local remaining = total_nodes - current_idx + 1

        local chunk_size
        local rows_used
        local is_full = false

        if remaining <= capacity then
            -- 能够在本块（列）内排完
            chunk_size = remaining
            if is_single_column then
                rows_used = remaining
            else
                rows_used = math.ceil(chunk_size / 2)
            end
        else
            -- 排不完，填满当前块（列）
            chunk_size = capacity
            rows_used = h
            is_full = true
        end

        local chunk_nodes = {}
        -- 计算平衡界限
        local right_count
        if is_single_column then
            if mode == 1 then            -- Right only
                right_count = chunk_size -- All go to right (sub_col 1)
            else                         -- Left only (mode 2)
                right_count = 0          -- None go to right
            end
        else
            right_count = math.ceil(chunk_size / 2)
        end

        for i = 0, chunk_size - 1 do
            local node_idx = current_idx + i
            local n = jiazhu_nodes[node_idx]

            local sub_col
            local relative_row

            if i < right_count then
                -- 右小行 (先行)
                sub_col = 1
                relative_row = i
            else
                -- 左小行 (后行)
                if is_single_column then
                    -- If left only mode, relative_row is just i, because there are no right nodes
                    sub_col = 2
                    relative_row = i
                else
                    sub_col = 2
                    relative_row = i - right_count
                end
            end

            -- if is_single_column then
            --    texio.write_nl("term_and_log", string.format("DEBUG: Mode=%s, NodeIdx=%d, Assigned SubCol=%d", tostring(mode), node_idx, sub_col))
            -- end

            -- 设置属性以便渲染层识别
            D.set_attribute(n, constants.ATTR_JIAZHU_SUB, sub_col)

            table.insert(chunk_nodes, {
                node = n,
                sub_col = sub_col,
                relative_row = relative_row
            })
        end

        table.insert(chunks, {
            nodes = chunk_nodes,
            rows_used = rows_used,
            is_full_column = is_full
        })

        current_idx = current_idx + chunk_size
        first_chunk = false
    end

    return chunks
end

--- Place jiazhu nodes into layout map
-- @param ctx (table) Grid context
-- @param start_node (node) The starting jiazhu node
-- @param layout_map (table) The layout map to populate
-- @param params (table) Layout parameters { effective_limit, line_limit, base_indent, r_indent, block_id, first_indent, jiazhu_mode }
-- @param callbacks (table) Callbacks { flush, wrap, get_indent, debug }
-- @return (node) The next node to process
function textflow.place_jiazhu_nodes(ctx, start_node, layout_map, params, callbacks)
    if callbacks.debug then
        callbacks.debug(string.format("  [layout] JIAZHU DETECTED: node=%s", tostring(start_node)))
    end
    callbacks.flush()

    local j_nodes, temp_t = textflow.collect_jiazhu_nodes(start_node)
    if callbacks.debug then
        callbacks.debug(string.format("  [layout] Collected %d jiazhu glyphs", #j_nodes))
    end

    -- Ensure we have at least 2 rows available (prevent orphan rows)
    if params.effective_limit - ctx.cur_row < 2 then
        callbacks.flush()
        callbacks.wrap()
    end

    -- Process jiazhu sequence into chunks
    local available_in_first = params.effective_limit - ctx.cur_row
    local capacity_per_subsequent = params.line_limit - params.base_indent - params.r_indent
    local chunks = textflow.process_jiazhu_sequence(j_nodes, available_in_first, capacity_per_subsequent,
        params.jiazhu_mode)

    -- Place chunks into layout_map
    for i, chunk in ipairs(chunks) do
        if i > 1 then
            callbacks.wrap()
            local chunk_indent = callbacks.get_indent(params.block_id, params.base_indent, params.first_indent)
            if ctx.cur_row < chunk_indent then ctx.cur_row = chunk_indent end
        end
        for _, node_info in ipairs(chunk.nodes) do
            layout_map[node_info.node] = {
                page = ctx.cur_page,
                col = ctx.cur_col,
                row = ctx.cur_row + node_info.relative_row,
                sub_col = node_info.sub_col
            }
        end
        ctx.cur_row = ctx.cur_row + chunk.rows_used
    end

    return temp_t
end

-- Register module
package.loaded['core.luatex-cn-textflow'] = textflow

return textflow
