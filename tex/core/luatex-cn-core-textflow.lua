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
local helpers = package.loaded['core.luatex-cn-layout-grid-helpers'] or
    require('core.luatex-cn-layout-grid-helpers')

local textflow = {}

--- Push textflow style to style stack
-- @param font_color (string|nil) Font color string (e.g., "red" or "1 0 0")
-- @param font_size (string|nil) Font size string (e.g., "14pt")
-- @param font (string|nil) Font family name
-- @param textflow_align (string|nil) TextFlow alignment (outward, inward, center, left, right)
-- @param auto_balance (boolean|nil) Whether to auto-balance last column (default true)
-- @return (number) Style ID
function textflow.push_style(font_color, font_size, font, textflow_align, auto_balance)
    local extra = {}
    if textflow_align and textflow_align ~= "" then
        extra.textflow_align = textflow_align
    end
    extra.auto_balance = (auto_balance ~= false)
    return style_registry.push_content_style(font_color, font_size, font, extra)
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
--- Collect consecutive textflow glyph nodes, stopping at end or force-column penalty.
-- Decorate marker nodes (ATTR_DECORATE_ID > 0, e.g., judou marks) are NOT collected
-- as content glyphs. Instead they are recorded in a separate table keyed by the
-- preceding content glyph so that place_textflow_segment can position them correctly.
-- @param start_node (node) Starting node
-- @return nodes (table) List of glyph nodes collected
-- @return next_node (node|nil) The next node after collected segment
-- @return hit_column_break (boolean) True if stopped due to PENALTY_FORCE_COLUMN
-- @return decorate_map (table) Map: content_node → {decorate_node, ...}
function textflow.collect_nodes(start_node)
    local nodes = {}
    local decorate_map = {}
    local temp_t = start_node
    local hit_column_break = false
    local initial_mode = nil  -- Track mode of first glyph to detect segment boundaries
    local last_content_node = nil  -- Track last content glyph for decorate association

    while temp_t do
        -- Check if this node belongs to the textflow sequence.
        -- Decorate markers (e.g., judou marks created by judou.flatten) are
        -- zero-width glyph nodes that do NOT carry ATTR_JIAZHU because they
        -- were newly created after flatten_vbox. They must be skipped over
        -- (not collected as content) so they don't break the textflow sequence.
        local is_jiazhu = D.get_attribute(temp_t, constants.ATTR_JIAZHU) == 1
        local tid = D.getid(temp_t)
        local is_decorate = false
        if not is_jiazhu and tid == constants.GLYPH then
            local dec_id = D.get_attribute(temp_t, constants.ATTR_DECORATE_ID)
            if dec_id and dec_id > 0 then
                is_decorate = true
            end
        end

        if not is_jiazhu and not is_decorate then
            break
        end

        -- Stop at textbox nodes (HLIST/VLIST with textbox attributes).
        -- Textbox inside textflow cannot be handled as textflow glyphs;
        -- they will be processed independently by layout-grid's textbox path.
        if (tid == constants.HLIST or tid == constants.VLIST) then
            local tw = D.get_attribute(temp_t, constants.ATTR_TEXTBOX_WIDTH) or 0
            local th = D.get_attribute(temp_t, constants.ATTR_TEXTBOX_HEIGHT) or 0
            if tw > 0 and th > 0 then
                break
            end
        end

        if is_decorate then
            -- Associate decorate marker with the last content glyph
            if last_content_node then
                if not decorate_map[last_content_node] then
                    decorate_map[last_content_node] = {}
                end
                table.insert(decorate_map[last_content_node], temp_t)
            end
        elseif tid == constants.PENALTY then
            local p_val = D.getfield(temp_t, "penalty")
            if p_val == constants.PENALTY_FORCE_COLUMN or p_val == constants.PENALTY_TAITOU
                or p_val == constants.PENALTY_DIGITAL_NEWLINE then
                -- Column break inside textflow: stop collecting, skip penalty
                temp_t = D.getnext(temp_t)
                hit_column_break = true
                break
            end
        elseif tid == constants.GLYPH then
            -- Stop when JIAZHU_MODE changes (e.g., right-only → left-only in \双列).
            -- Each mode segment must be processed separately for correct sub-column placement.
            local mode = D.get_attribute(temp_t, constants.ATTR_JIAZHU_MODE) or 0
            if initial_mode == nil then
                initial_mode = mode
            elseif mode ~= initial_mode then
                break
            end
            table.insert(nodes, temp_t)
            last_content_node = temp_t
        end
        temp_t = D.getnext(temp_t)
    end

    return nodes, temp_t, hit_column_break, decorate_map
end

--- Helper: get height of node at index from node_heights table or default
local function get_node_h(node_heights, idx, default_gh)
    if node_heights then return node_heights[idx] or default_gh end
    return default_gh
end

--- Process textflow nodes into chunks with balanced distribution (sp-based).
-- All capacity parameters are in scaled points (sp), not row counts.
-- @param textflow_nodes (table) Consecutive textflow node list (direct nodes)
-- @param available_height_sp (number) Remaining height in current column (sp)
-- @param column_height_sp (number) Total column height per subsequent column (sp)
-- @param mode (number) Mode: 1=right only, 2=left only, 0=balanced
-- @param auto_balance (boolean) Whether to auto-balance last chunk (default true)
-- @param start_sub_col (number|nil) Starting sub-column (1=right, 2=left), nil means start fresh
-- @param start_row_offset (number|nil) Starting row offset when continuing (unused, kept for API compat)
-- @param first_sub_extra_sp (number|nil) Extra height for first sub-column only (sp, from forced indent)
-- @param global_gh (number) Global grid height in sp (for fallback and row conversion)
-- @param node_heights (table|nil) Per-node heights in sp, indexed by node position; nil = all use global_gh
-- @return (table) chunks: { {nodes_with_attr, height_used_sp, is_full_column, end_sub_col, end_height_used_sp}, ... }
function textflow.process_sequence(textflow_nodes, available_height_sp, column_height_sp, mode, auto_balance,
                                   start_sub_col, _start_row_offset, first_sub_extra_sp,
                                   global_gh, node_heights)
    local total_nodes = #textflow_nodes
    if total_nodes == 0 then return {}, nil, nil end

    -- Default auto_balance to true
    if auto_balance == nil then auto_balance = true end
    first_sub_extra_sp = first_sub_extra_sp or 0
    global_gh = global_gh or 655360  -- fallback 10pt

    -- Track sub-column continuation state
    local continue_on_left = (start_sub_col == 2)

    local chunks = {}
    local current_idx = 1
    local first_chunk = true

    -- Mode 1: Right only, Mode 2: Left only, Other: Balanced
    local is_single_column = (mode == 1 or mode == 2)

    while current_idx <= total_nodes do
        -- h_sp: available sub-column height for this chunk
        local h_sp = first_chunk and available_height_sp or column_height_sp
        local fse_sp = first_chunk and first_sub_extra_sp or 0
        local h_first_sub_sp = h_sp + fse_sp

        -- Fill sub-columns by accumulating node heights
        local right_nodes_info = {}  -- {node_idx, y_offset_sp}
        local left_nodes_info = {}
        local right_h = 0
        local left_h = 0
        local idx = current_idx
        local is_full = false

        if first_chunk and continue_on_left and not auto_balance then
            -- Continuing on left sub-column only (must check BEFORE is_single_column,
            -- because mode=2 is also single-column but needs the left continuation path)
            while idx <= total_nodes do
                local nh = get_node_h(node_heights, idx, global_gh)
                if left_h + nh > h_first_sub_sp and #left_nodes_info > 0 then
                    is_full = true
                    break
                end
                table.insert(left_nodes_info, {idx = idx, y_offset_sp = left_h})
                left_h = left_h + nh
                idx = idx + 1
            end

        elseif is_single_column then
            -- Single column: fill until height exceeded
            while idx <= total_nodes do
                local nh = get_node_h(node_heights, idx, global_gh)
                if right_h + nh > h_sp and #right_nodes_info > 0 then
                    is_full = true
                    break
                end
                table.insert(right_nodes_info, {idx = idx, y_offset_sp = right_h})
                right_h = right_h + nh
                idx = idx + 1
            end

        elseif auto_balance then
            -- Auto-balance: collect all that fit in both columns, then split
            local all_indices = {}
            local total_h = 0
            while idx <= total_nodes do
                local nh = get_node_h(node_heights, idx, global_gh)
                -- Two sub-columns: total capacity is 2 * h_sp (with extra for first sub)
                if total_h + nh > h_sp + h_first_sub_sp and #all_indices > 0 then
                    is_full = true
                    break
                end
                table.insert(all_indices, idx)
                total_h = total_h + nh
                idx = idx + 1
            end
            -- Split: right column gets ceil(count/2) nodes worth of height.
            -- For uniform heights this matches the old row-based ceil(N/2).
            -- For variable heights, we fill right first, switching to left once
            -- right has accumulated more than half the total.
            local target_right_h = total_h / 2
            local accumulated = 0
            local filling_right = true
            for _, ni in ipairs(all_indices) do
                local nh = get_node_h(node_heights, ni, global_gh)
                if filling_right then
                    table.insert(right_nodes_info, {idx = ni, y_offset_sp = accumulated})
                    accumulated = accumulated + nh
                    right_h = accumulated
                    -- Switch to left after right has reached or exceeded half
                    if accumulated >= target_right_h then
                        filling_right = false
                    end
                else
                    table.insert(left_nodes_info, {idx = ni, y_offset_sp = left_h})
                    left_h = left_h + nh
                end
            end
            -- Re-compute left y_offsets from 0
            left_h = 0
            for _, info in ipairs(left_nodes_info) do
                info.y_offset_sp = left_h
                left_h = left_h + get_node_h(node_heights, info.idx, global_gh)
            end

        else
            -- No auto-balance: fill right first, then left
            while idx <= total_nodes do
                local nh = get_node_h(node_heights, idx, global_gh)
                if right_h + nh > h_first_sub_sp and #right_nodes_info > 0 then break end
                table.insert(right_nodes_info, {idx = idx, y_offset_sp = right_h})
                right_h = right_h + nh
                idx = idx + 1
            end
            while idx <= total_nodes do
                local nh = get_node_h(node_heights, idx, global_gh)
                if left_h + nh > h_sp and #left_nodes_info > 0 then
                    is_full = true
                    break
                end
                table.insert(left_nodes_info, {idx = idx, y_offset_sp = left_h})
                left_h = left_h + nh
                idx = idx + 1
            end
            -- Check if we consumed all remaining and still have room
            if idx > total_nodes then
                is_full = false
            end
        end

        -- Build chunk_nodes
        local chunk_nodes = {}

        -- Right sub-column nodes
        for _, info in ipairs(right_nodes_info) do
            local n = textflow_nodes[info.idx]
            local sub_col = 1
            D.set_attribute(n, constants.ATTR_JIAZHU_SUB, sub_col)
            table.insert(chunk_nodes, {
                node = n,
                sub_col = sub_col,
                relative_row = info.y_offset_sp,  -- now stores y_offset_sp
            })
        end

        -- Left sub-column nodes
        for _, info in ipairs(left_nodes_info) do
            local n = textflow_nodes[info.idx]
            local sub_col = (is_single_column and mode == 1) and 1 or 2
            D.set_attribute(n, constants.ATTR_JIAZHU_SUB, sub_col)
            table.insert(chunk_nodes, {
                node = n,
                sub_col = sub_col,
                relative_row = info.y_offset_sp,  -- now stores y_offset_sp
            })
        end

        -- height_used_sp: the max of right and left heights (determines column advancement)
        local height_used_sp = math.max(right_h, left_h)

        -- Track ending state for next textflow continuation
        local end_sub_col = nil
        local end_height_used_sp = nil
        if not auto_balance and not is_full then
            if #right_nodes_info > 0 and #left_nodes_info == 0 then
                end_sub_col = 1
                end_height_used_sp = right_h
            elseif #right_nodes_info == 0 and #left_nodes_info > 0 then
                end_sub_col = 2
                end_height_used_sp = left_h
            end
        end

        -- Compute rows_used for cur_row advancement.
        -- Special case: when not auto_balance and only right sub-column used,
        -- rows_used = 0 to allow next textflow to continue on left.
        local rows_used
        if not auto_balance and not is_full and #right_nodes_info > 0 and #left_nodes_info == 0 then
            rows_used = 0  -- Only right used, don't advance cur_row
        else
            rows_used = math.ceil(height_used_sp / global_gh)
        end

        table.insert(chunks, {
            nodes = chunk_nodes,
            height_used_sp = height_used_sp,
            is_full_column = is_full,
            end_sub_col = end_sub_col,
            end_height_used_sp = end_height_used_sp,
            rows_used = rows_used,
            end_row_used = end_height_used_sp and math.ceil(end_height_used_sp / global_gh) or nil,
        })

        current_idx = idx
        first_chunk = false
        continue_on_left = false
    end

    -- Return chunks and final state for potential continuation
    local final_chunk = chunks[#chunks]
    local final_sub_col = final_chunk and final_chunk.end_sub_col or nil
    local final_row_used = final_chunk and final_chunk.end_row_used or nil

    return chunks, final_sub_col, final_row_used
end

--- Place textflow nodes into layout map
-- @param ctx (table) Grid context
-- @param start_node (node) The starting textflow node
-- @param layout_map (table) The layout map to populate
-- @param params (table) Layout parameters { effective_limit, line_limit, base_indent, r_indent, block_id, first_indent, textflow_mode }
-- @param callbacks (table) Callbacks { flush, wrap, get_indent, debug }
-- @return (node) The next node to process
--- Place a single segment of textflow nodes into the layout map.
-- @param ctx (table) Grid context
-- @param nodes (table) List of glyph nodes
-- @param layout_map (table) The layout map to populate
-- @param params (table) Layout parameters
-- @param callbacks (table) Callbacks { flush, wrap, get_indent, debug }
-- @param decorate_map (table|nil) Map: content_node → {decorate_node, ...} for judou marks
local function place_textflow_segment(ctx, nodes, layout_map, params, callbacks, decorate_map)
    if #nodes == 0 then
        -- Even with no glyphs, if the previous segment left pending_sub_col=1
        -- and this is a left-only segment (mode=2), consume the pending state.
        -- This happens when \双列{\右小列{...}\左小列{}} has an empty left column.
        if ctx.textflow_pending_sub_col == 1 and params.textflow_mode == 2 then
            ctx.cur_row = ctx.cur_row + (ctx.textflow_pending_row_used or 0)
            ctx.cur_y_sp = ctx.cur_row * (params.grid_height or 655360)
            ctx.textflow_pending_sub_col = nil
            ctx.textflow_pending_row_used = nil
        end
        return
    end

    -- When forced indent is active (e.g., from \相对抬头), params.base_indent and
    -- params.first_indent may be polluted with the forced value (e.g., 1 instead of 2).
    -- We need the original paragraph indent for subsequent columns.
    -- Recover the original indent from the style stack.
    local orig_base_indent = params.base_indent
    local orig_first_indent = params.first_indent
    local node_indent_attr = D.get_attribute(nodes[1], constants.ATTR_INDENT)
    local is_forced, forced_indent_value = constants.is_forced_indent(node_indent_attr)
    if is_forced then
        local sid = D.get_attribute(nodes[1], constants.ATTR_STYLE_REG_ID)
        if sid then
            local stack_indent = style_registry.get_indent(sid)
            if stack_indent and stack_indent > 0 then
                orig_base_indent = stack_indent
            end
            local stack_first_indent = style_registry.get_first_indent(sid)
            if stack_first_indent and stack_first_indent ~= -1 then
                orig_first_indent = stack_first_indent
            end
        end
    end

    -- Process textflow sequence into chunks (sp-based)
    local gh = params.grid_height or 655360
    local available_in_first = params.effective_limit - ctx.cur_row
    local capacity_per_subsequent = params.line_limit - orig_base_indent - params.r_indent

    -- Convert row-based values to sp for process_sequence
    -- When auto_column_wrap is disabled, use unlimited height so textflow
    -- never splits across columns (all nodes stay in one chunk).
    local available_height_sp, column_height_sp
    if ctx.auto_column_wrap == false then
        available_height_sp = 0x7FFFFFFF  -- max int: no overflow splitting
        column_height_sp = 0x7FFFFFFF
    else
        available_height_sp = available_in_first * gh
        column_height_sp = capacity_per_subsequent * gh
    end

    -- Check if first node has forced indent (e.g., from \相对抬头)
    -- If so, the first sub-column starts from a lower indent, giving extra rows
    -- for that sub-column only (not the other sub-column or subsequent columns).
    local forced_indent_extra_sp = 0
    if is_forced and forced_indent_value < ctx.cur_row then
        forced_indent_extra_sp = (ctx.cur_row - forced_indent_value) * gh
    end

    -- Build node_heights table: per-node grid-height from style override
    local node_heights = nil
    for i, n in ipairs(nodes) do
        local sid = D.get_attribute(n, constants.ATTR_STYLE_REG_ID)
        if sid and sid > 0 then
            local sgh = style_registry.get_grid_height(sid)
            if sgh and sgh > 0 and sgh ~= gh then
                if not node_heights then
                    -- Lazy init: fill previous entries with default
                    node_heights = {}
                    for j = 1, i - 1 do node_heights[j] = gh end
                end
                node_heights[i] = sgh
            elseif node_heights then
                node_heights[i] = gh
            end
        elseif node_heights then
            node_heights[i] = gh
        end
    end

    -- Get auto_balance from style (read from first node)
    local auto_balance = true
    local style_id = D.get_attribute(nodes[1], constants.ATTR_STYLE_REG_ID)
    local style = style_registry.get(style_id)
    if style and style.auto_balance == false then
        auto_balance = false
    end

    -- Get continuation state from ctx (if available)
    local start_sub_col = nil
    if not auto_balance and ctx.textflow_pending_sub_col == 1 then
        -- Previous textflow ended on right, continue on left
        start_sub_col = 2
    end

    local chunks, final_sub_col, final_row_used = textflow.process_sequence(
        nodes, available_height_sp, column_height_sp,
        params.textflow_mode, auto_balance, start_sub_col, nil,
        forced_indent_extra_sp, gh, node_heights)

    -- Determine the "first sub-col" where forced indent applies.
    -- Forced indent (from \相对抬头) only affects the first sub-column after the break.
    -- When the text flows to the other sub-column or next big column, revert to normal indent.
    local forced_first_sub_col = nil
    if is_forced then
        if start_sub_col == 2 then
            forced_first_sub_col = 2  -- Started on left sub-col
        else
            forced_first_sub_col = 1  -- Started on right sub-col (default)
        end
    end

    -- Place chunks into layout_map
    for i, chunk in ipairs(chunks) do
        if i > 1 then
            callbacks.wrap()
            local chunk_indent = callbacks.get_indent(params.block_id, orig_base_indent, orig_first_indent)
            if ctx.cur_row < chunk_indent then
                ctx.cur_row = chunk_indent
                ctx.cur_y_sp = ctx.cur_row * (params.grid_height or 655360)
            end
        end
        for _, node_info in ipairs(chunk.nodes) do
            -- Note: ATTR_STYLE_REG_ID is already set by TeX layer

            -- Check if this node has forced indent (e.g., from \平抬 command)
            local ni_attr = D.get_attribute(node_info.node, constants.ATTR_INDENT)
            local ni_forced, ni_indent_val = constants.is_forced_indent(ni_attr)

            -- Forced indent only applies in the first chunk AND the first sub-column.
            -- When text flows to the other sub-column or overflows to next big column,
            -- revert to normal indent.
            if ni_forced then
                if i > 1 or node_info.sub_col ~= forced_first_sub_col then
                    D.set_attribute(node_info.node, constants.ATTR_INDENT, 0)
                    ni_forced = false
                end
            end

            -- Resolve per-node cell height for entry.cell_height
            local node_cell_h
            if node_info.sub_col then
                node_cell_h = gh  -- default: global grid_height
                local sid = D.get_attribute(node_info.node, constants.ATTR_STYLE_REG_ID)
                if sid and sid > 0 then
                    local style_ch = style_registry.get_grid_height(sid)
                    if style_ch and style_ch > 0 then
                        node_cell_h = style_ch
                    end
                end
            else
                node_cell_h = helpers.resolve_cell_height(node_info.node, gh, nil, ctx.punct_config)
            end

            -- y_sp calculation: base position uses global grid_height,
            -- relative_row now stores y_offset_sp (cumulative offset from process_sequence)
            local base_y_sp
            if ni_forced then
                base_y_sp = ni_indent_val * gh
            else
                base_y_sp = ctx.cur_row * gh
            end
            local entry = {
                page = ctx.cur_page,
                col = ctx.cur_col,
                y_sp = base_y_sp + node_info.relative_row,  -- relative_row is y_offset_sp
                sub_col = node_info.sub_col,
                cell_height = node_cell_h,
            }
            if not node_info.sub_col then
                entry.cell_width = helpers.resolve_cell_width(node_info.node, nil)
            end
            helpers.apply_style_attrs(entry, node_info.node)

            -- Check for line mark attribute (专名号/书名号)
            local lm_id = D.get_attribute(node_info.node, constants.ATTR_LINE_MARK_ID)
            if lm_id and lm_id > 0 then
                entry.line_mark_id = lm_id
            end

            layout_map[node_info.node] = entry

            -- Place associated decorate markers (e.g., judou marks) at the
            -- same position as their anchor glyph. They are zero-width overlays
            -- and do not occupy any grid space.
            if decorate_map then
                local dec_nodes = decorate_map[node_info.node]
                if dec_nodes then
                    for _, dec_node in ipairs(dec_nodes) do
                        local dec_entry = {
                            page = entry.page,
                            col = entry.col,
                            y_sp = entry.y_sp + node_cell_h,
                            sub_col = entry.sub_col,
                        }
                        helpers.apply_style_attrs(dec_entry, dec_node)
                        layout_map[dec_node] = dec_entry
                    end
                end
            end
        end

        -- Advance cur_row appropriately
        if i == 1 and start_sub_col == 2 then
            -- Continuing on left: advance by max of pending (right) and current (left) rows
            local pending_rows = ctx.textflow_pending_row_used or 0
            ctx.cur_row = ctx.cur_row + math.max(pending_rows, chunk.rows_used)
        else
            ctx.cur_row = ctx.cur_row + chunk.rows_used
        end
        ctx.cur_y_sp = ctx.cur_row * gh
    end

    -- Update ctx with final sub-column state for next textflow
    if not auto_balance and final_sub_col == 1 then
        -- Ended on right sub-column, next textflow can continue on left
        ctx.textflow_pending_sub_col = 1
        ctx.textflow_pending_row_used = final_row_used
    else
        -- Clear pending state (used both sub-columns or auto-balanced)
        ctx.textflow_pending_sub_col = nil
        ctx.textflow_pending_row_used = nil
    end
end

--- Place textflow nodes into layout map, handling column breaks within textflow.
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
    -- Recover original paragraph indent from style stack.
    -- params.base_indent/first_indent may be polluted by forced indent (\相对抬头).
    local orig_base_indent = params.base_indent
    local orig_first_indent = params.first_indent
    if D.get_attribute(start_node, constants.ATTR_JIAZHU) == 1 then
        local first_glyph = start_node
        -- Find first glyph node for style lookup
        while first_glyph and D.getid(first_glyph) ~= constants.GLYPH do
            first_glyph = D.getnext(first_glyph)
        end
        if first_glyph then
            local ni = D.get_attribute(first_glyph, constants.ATTR_INDENT)
            local forced = constants.is_forced_indent(ni)
            if forced then
                local sid = D.get_attribute(first_glyph, constants.ATTR_STYLE_REG_ID)
                if sid then
                    local si = style_registry.get_indent(sid)
                    if si and si > 0 then orig_base_indent = si end
                    local sfi = style_registry.get_first_indent(sid)
                    if sfi and sfi ~= -1 then orig_first_indent = sfi end
                end
            end
        end
    end

    local temp_t = start_node

    -- Loop: collect segments separated by force-column penalties
    while true do
        local nodes, next_t, hit_column_break, decorate_map = textflow.collect_nodes(temp_t)
        if callbacks.debug then
            callbacks.debug(string.format("  [layout] Collected %d textflow glyphs (column_break=%s)",
                #nodes, tostring(hit_column_break)))
        end

        -- Place this segment
        place_textflow_segment(ctx, nodes, layout_map, params, callbacks, decorate_map)

        if hit_column_break then
            -- Column break inside textflow: advance to next sub-column.
            -- Two cases:
            --   (a) Previous segment ended on RIGHT sub-col (pending_sub_col==1):
            --       → Next segment starts on LEFT sub-col of same big column.
            --       → Keep pending state so place_textflow_segment uses start_sub_col=2.
            --   (b) Previous segment ended on LEFT sub-col or both filled (pending_sub_col==nil or 2):
            --       → Next segment goes to the next big column's RIGHT sub-col.
            --       → Call callbacks.wrap() to advance to next big column.
            if ctx.textflow_pending_sub_col == 1 then
                -- Case (a): right → left in same big column
                temp_t = next_t
            else
                -- Case (b): left or both → next big column
                ctx.textflow_pending_sub_col = nil
                ctx.textflow_pending_row_used = nil
                callbacks.wrap()
                local chunk_indent = callbacks.get_indent(params.block_id, orig_base_indent, orig_first_indent)
                if ctx.cur_row < chunk_indent then
                    ctx.cur_row = chunk_indent
                    ctx.cur_y_sp = ctx.cur_row * (params.grid_height or 655360)
                end
                temp_t = next_t
            end
        else
            -- No more column breaks; done
            temp_t = next_t
            break
        end
    end

    return temp_t
end

-- Register module
package.loaded['core.luatex-cn-textflow'] = textflow

return textflow
