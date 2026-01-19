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
-- core_textflow.lua - ??(Jiazhu)???????
-- ============================================================================
-- ???: core_textflow.lua
-- ??: ??? (Core Layer)
--
-- ????? / Module Purpose?
-- ?????????(????)???:
--   1. ??????????????????(Sub-column)?
--   2. ??????(Continuous Break)??,???????????
--   3. ????? ATTR_JIAZHU_SUB ??(1: ?/??, 2: ?/??)?
--
-- ????? / Main Algorithm?
--   ?????? H,???? C = H * 2?
--   ?????? L <= C,???????:?? = ceil(L/2),?? = L - ceil(L/2)?
--   ?? L > C,??????(?? = H,?? = H),??????????
--
--
-- ============================================================================

local constants = package.loaded['luatex-cn-vertical-base-constants'] or require('luatex-cn-vertical-base-constants')
local D = constants.D

local textflow = {}

--- ?????????????????
-- @param jiazhu_nodes (table) ????????? (direct nodes)
-- @param available_rows (number) ??????????
-- @param line_limit (number) ????????
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
            -- ?????(?)???,??????
            chunk_size = remaining
            rows_used = math.ceil(chunk_size / 2)
        else
            -- ???,?????(?)
            chunk_size = capacity
            rows_used = h
            is_full = true
        end

        local chunk_nodes = {}
        -- ??????
        local right_count = math.ceil(chunk_size / 2)
        
        for i = 0, chunk_size - 1 do
            local node_idx = current_idx + i
            local n = jiazhu_nodes[node_idx]
            
            local sub_col
            local relative_row
            
            if i < right_count then
                -- ??? (??)
                sub_col = 1
                relative_row = i
            else
                -- ??? (??)
                sub_col = 2
                relative_row = i - right_count
            end
            
            -- ???????????
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
package.loaded['luatex-cn-vertical-core-textflow'] = textflow

return textflow