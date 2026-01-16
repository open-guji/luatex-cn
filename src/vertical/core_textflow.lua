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

local constants = package.loaded['base_constants'] or require('base_constants')
local D = constants.D

local textflow = {}

--- 将一段连续的夹注节点进行分块和平衡
-- @param jiazhu_nodes (table) 连续的夹注节点列表 (direct nodes)
-- @param available_rows (number) 当前列剩余的可选行数
-- @param line_limit (number) 每列的总行数限制
-- @return (table) chunks: { {nodes_with_attr, rows_used, is_full_column}, ... }
function textflow.process_jiazhu_sequence(jiazhu_nodes, available_rows, line_limit)
    local total_nodes = #jiazhu_nodes
    if total_nodes == 0 then return {} end

    local chunks = {}
    local current_idx = 1
    local first_chunk = true

    while current_idx <= total_nodes do
        local h = first_chunk and available_rows or line_limit
        local capacity = h * 2
        local remaining = total_nodes - current_idx + 1
        
        local chunk_size
        local rows_used
        local is_full = false

        if remaining <= capacity then
            -- 能够在本块（列）内排完，执行平衡算法
            chunk_size = remaining
            rows_used = math.ceil(chunk_size / 2)
        else
            -- 排不完，填满当前块（列）
            chunk_size = capacity
            rows_used = h
            is_full = true
        end

        local chunk_nodes = {}
        -- 计算平衡界限
        local right_count = math.ceil(chunk_size / 2)
        
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
                sub_col = 2
                relative_row = i - right_count
            end
            
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

-- Register module
package.loaded['core_textflow'] = textflow

return textflow
