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
-- core_textflow.lua - TextFlow balancing and segmentation logic
-- ============================================================================
-- File: core_textflow.lua
-- Layer: Core Layer
--
-- Module Purpose:
-- This module handles textflow (dual-column small notes) logic:
--   1. Balances textflow nodes across left/right sub-columns.
--   2. Handles continuous break logic based on remaining space.
--   3. Sets ATTR_JIAZHU_SUB attribute (1: right/first, 2: left/second).
--
-- Main Algorithm:
--   Given available height H, capacity C = H * 2.
--   If textflow length L <= C, balance: right = ceil(L/2), left = L - ceil(L/2).
--   If L > C, fill current column (right = H, left = H), overflow to next.
--
--
-- ============================================================================

local constants = package.loaded['core.luatex-cn-constants'] or
    require('core.luatex-cn-constants')
local D = constants.D
local style_registry = package.loaded['util.luatex-cn-style-registry'] or
    require('util.luatex-cn-style-registry')

local textflow = {}

--- Push textflow style to style stack
-- @param font_color (string|nil) Font color string (e.g., "red" or "1 0 0")
-- @param font_size (string|nil) Font size string (e.g., "14pt")
-- @param font (string|nil) Font family name
-- @param textflow_align (string|nil) TextFlow alignment (outward, inward, center, left, right)
-- @return (number) Style ID
function textflow.push_style(font_color, font_size, font, textflow_align)
    local style = {}
    if font_color and font_color ~= "" then
        style.font_color = font_color
    end
    if font_size and font_size ~= "" then
        style.font_size = constants.to_dimen(font_size)
    end
    if font and font ~= "" then
        style.font = font
    end
    -- Only set textflow_align if explicitly provided
    -- Inheritance handled by style_registry
    if textflow_align and textflow_align ~= "" then
        style.textflow_align = textflow_align
    end
    return style_registry.push(style)
end

--- Pop textflow style from style stack
function textflow.pop_style()
    return style_registry.pop()
end

--- Calculate sub-column X offset for textflow
-- @param base_x (number) Base X coordinate (sp)
-- @param grid_width (number) Total cell width (sp)
-- @param w (number) Character width (sp)
-- @param sub_col (number) Sub-column number (1: right, 2: left)
-- @param align (string) Alignment (outward, inward, center, left, right)
-- @return (number) Physical X coordinate (sp)
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

--- Collect consecutive textflow glyph nodes starting from a given node
-- @param start_node (direct node) Starting node (must have ATTR_JIAZHU == 1)
-- @return (table, direct node) Array of textflow glyph nodes, next non-textflow node
function textflow.collect_nodes(start_node)
    local nodes = {}
    local temp_t = start_node

    while temp_t and D.get_attribute(temp_t, constants.ATTR_JIAZHU) == 1 do
        local tid = D.getid(temp_t)
        if tid == constants.GLYPH then
            table.insert(nodes, temp_t)
        end
        temp_t = D.getnext(temp_t)
    end

    return nodes, temp_t
end

--- Process textflow nodes into chunks with balanced distribution
-- @param textflow_nodes (table) Consecutive textflow node list (direct nodes)
-- @param available_rows (number) Remaining rows in current column
-- @param line_limit (number) Total row limit per column
-- @return (table) chunks: { {nodes_with_attr, rows_used, is_full_column}, ... }
function textflow.process_sequence(textflow_nodes, available_rows, line_limit, mode)
    local total_nodes = #textflow_nodes
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
            chunk_size = remaining
            if is_single_column then
                rows_used = remaining
            else
                rows_used = math.ceil(chunk_size / 2)
            end
        else
            chunk_size = capacity
            rows_used = h
            is_full = true
        end

        local chunk_nodes = {}
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
            local n = textflow_nodes[node_idx]

            local sub_col
            local relative_row

            if i < right_count then
                -- Right sub-row (first)
                sub_col = 1
                relative_row = i
            else
                -- Left sub-row (second)
                if is_single_column then
                    sub_col = 2
                    relative_row = i
                else
                    sub_col = 2
                    relative_row = i - right_count
                end
            end

            -- Set attribute for render layer
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

--- Place textflow nodes into layout map
-- @param ctx (table) Grid context
-- @param start_node (node) The starting textflow node
-- @param layout_map (table) The layout map to populate
-- @param params (table) Layout parameters { effective_limit, line_limit, base_indent, r_indent, block_id, first_indent, textflow_mode }
-- @param callbacks (table) Callbacks { flush, wrap, get_indent, debug }
-- @return (node) The next node to process
function textflow.place_nodes(ctx, start_node, layout_map, params, callbacks)
    if callbacks.debug then
        callbacks.debug(string.format("  [layout] TEXTFLOW DETECTED: node=%s", tostring(start_node)))
    end
    callbacks.flush()

    local nodes, temp_t = textflow.collect_nodes(start_node)
    if callbacks.debug then
        callbacks.debug(string.format("  [layout] Collected %d textflow glyphs", #nodes))
    end

    -- Process textflow sequence into chunks
    local available_in_first = params.effective_limit - ctx.cur_row
    local capacity_per_subsequent = params.line_limit - params.base_indent - params.r_indent
    local chunks = textflow.process_sequence(nodes, available_in_first, capacity_per_subsequent,
        params.textflow_mode)

    -- Place chunks into layout_map
    -- Read style from node attribute (set by TeX layer)
    local style_reg_id = nil
    local current_style = nil
    if #nodes > 0 then
        style_reg_id = D.get_attribute(nodes[1], constants.ATTR_STYLE_REG_ID)
        current_style = style_registry.get(style_reg_id)
    end

    -- Extract style attributes for layout_map
    local font_color_str = current_style and current_style.font_color or nil
    local font_size_val = current_style and current_style.font_size or nil
    local font_str = current_style and current_style.font or nil
    local textflow_align_str = current_style and current_style.textflow_align or nil

    for i, chunk in ipairs(chunks) do
        if i > 1 then
            callbacks.wrap()
            local chunk_indent = callbacks.get_indent(params.block_id, params.base_indent, params.first_indent)
            if ctx.cur_row < chunk_indent then ctx.cur_row = chunk_indent end
        end
        for _, node_info in ipairs(chunk.nodes) do
            -- Note: ATTR_STYLE_REG_ID is already set by TeX layer

            local entry = {
                page = ctx.cur_page,
                col = ctx.cur_col,
                row = ctx.cur_row + node_info.relative_row,
                sub_col = node_info.sub_col
            }

            -- Only add style fields if set
            if font_color_str then
                entry.font_color = font_color_str
            end
            if font_size_val then
                entry.font_size = font_size_val
            end
            if font_str then
                entry.font = font_str
            end
            if textflow_align_str then
                entry.textflow_align = textflow_align_str
            end

            layout_map[node_info.node] = entry
        end
        ctx.cur_row = ctx.cur_row + chunk.rows_used
    end

    return temp_t
end

-- Register module
package.loaded['core.luatex-cn-textflow'] = textflow

return textflow
