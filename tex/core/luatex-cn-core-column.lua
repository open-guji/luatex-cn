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
-- core_column.lua - Column (单列排版) logic
-- ============================================================================
-- File: core_column.lua
-- Layer: Core Layer
--
-- Module Purpose:
-- This module handles Column (单列排版) logic:
--   1. Collects all nodes within a \Column{} block
--   2. Places them strictly within a single column
--   3. Supports alignment modes: top, bottom, center, stretch/squeeze
--   4. Works with mixed content: glyphs, textflow (jiazhu), textboxes
--   5. Preserves jiazhu dual-column layout within Column
--
-- Alignment Modes:
--   0 = top     : 向上对齐 (content starts from top)
--   1 = bottom  : 向下对齐 (content ends at bottom)
--   2 = center  : 居中对齐 (content centered vertically)
--   3 = stretch : 拉伸/挤压填充 (content distributed evenly)
--
-- ============================================================================

local constants = package.loaded['core.luatex-cn-constants'] or
    require('core.luatex-cn-constants')
local D = constants.D
local style_registry = package.loaded['util.luatex-cn-style-registry'] or
    require('util.luatex-cn-style-registry')
local helpers = package.loaded['core.luatex-cn-layout-grid-helpers'] or
    require('core.luatex-cn-layout-grid-helpers')
local textflow = package.loaded['core.luatex-cn-core-textflow'] or
    require('core.luatex-cn-core-textflow')

local column = {}

-- Alignment mode constants
-- When align >= 4, it's a LastColumn (align = base_align + 4)
column.ALIGN_TOP = 0
column.ALIGN_BOTTOM = 1
column.ALIGN_CENTER = 2
column.ALIGN_STRETCH = 3
column.LAST_OFFSET = 4  -- Add this to align mode for LastColumn

--- Find the last usable column in current half-page (before banxin or page end)
-- @param cur_col (number) Current column index
-- @param p_cols (number) Total columns per page
-- @param interval (number) Banxin interval (0 = no banxin)
-- @param banxin_on (boolean) Whether banxin is enabled
-- @return (number) The last column index in current half-page
function column.find_last_column_in_half_page(cur_col, p_cols, interval, banxin_on)
    if not banxin_on or interval <= 0 then
        -- No banxin, last column is p_cols - 1
        return p_cols - 1
    end

    -- Find the next banxin column after cur_col
    -- Banxin columns are at interval, 2*interval+1, 3*interval+2, etc.
    -- Using hooks.is_reserved_column logic: col % (interval + 1) == interval
    local hooks = package.loaded['core.luatex-cn-hooks'] or require('core.luatex-cn-hooks')

    -- Find last non-banxin column before the next banxin
    for col = cur_col, p_cols - 1 do
        if _G.core and _G.core.hooks and _G.core.hooks.is_reserved_column then
            if _G.core.hooks.is_reserved_column(col, interval) then
                -- This is a banxin column, return the previous column
                return math.max(cur_col, col - 1)
            end
        else
            -- Fallback: simple modulo check
            if col % (interval + 1) == interval then
                return math.max(cur_col, col - 1)
            end
        end
    end

    -- No banxin found, return last column
    return p_cols - 1
end

--- Push column style to style stack
-- @param font_color (string|nil) Font color string
-- @param font_size (string|nil) Font size string
-- @param font (string|nil) Font family name
-- @param grid_height (string|nil) Grid height string (e.g. "40pt")
-- @param spacing_top (string|nil) Spacing-top (column right spacing) string
-- @param spacing_bottom (string|nil) Spacing-bottom (column left spacing) string
-- @param column_width (string|nil) Column width string
-- @param auto_width (boolean|nil) Auto-width setting
-- @param width_scale (string|nil) Width scale factor string
-- @return (number) Style ID (always returns a valid number)
function column.push_style(font_color, font_size, font, grid_height,
                          spacing_top, spacing_bottom, column_width,
                          auto_width, width_scale)
    local extra = {}
    if grid_height and grid_height ~= "" then
        extra.grid_height = constants.to_dimen(grid_height)
    end
    if spacing_top and spacing_top ~= "" then
        extra.spacing_top = constants.to_dimen(spacing_top)
    end
    if spacing_bottom and spacing_bottom ~= "" then
        extra.spacing_bottom = constants.to_dimen(spacing_bottom)
    end
    if column_width and column_width ~= "" then
        extra.column_width = constants.to_dimen(column_width)
    end
    if auto_width ~= nil then
        extra.auto_width = auto_width
    end
    if width_scale and width_scale ~= "" then
        extra.width_scale = tonumber(width_scale)
    end
    return style_registry.push_content_style(font_color, font_size, font, extra)
end

--- Pop column style from style stack
function column.pop_style()
    return style_registry.pop()
end

--- Collect consecutive column nodes starting from a given node
-- Groups consecutive jiazhu nodes into jiazhu_group for proper dual-column handling
-- @param start_node (direct node) Starting node (must have ATTR_COLUMN == 1)
-- @return (table, direct node) Array of column items with metadata, next non-column node
function column.collect_nodes(start_node)
    local items = {}
    local temp_t = start_node
    local current_jiazhu_group = nil

    local function flush_jiazhu_group()
        if current_jiazhu_group and #current_jiazhu_group > 0 then
            -- Calculate rows needed for this jiazhu group (dual-column)
            local rows_needed = math.ceil(#current_jiazhu_group / 2)
            table.insert(items, {
                type = "jiazhu_group",
                nodes = current_jiazhu_group,
                rows = rows_needed
            })
            current_jiazhu_group = nil
        end
    end

    while temp_t and D.get_attribute(temp_t, constants.ATTR_COLUMN) == 1 do
        local tid = D.getid(temp_t)
        local is_jiazhu = D.get_attribute(temp_t, constants.ATTR_JIAZHU) == 1

        if tid == constants.GLYPH then
            if is_jiazhu then
                -- Start or continue jiazhu group
                if not current_jiazhu_group then
                    current_jiazhu_group = {}
                end
                table.insert(current_jiazhu_group, temp_t)
            else
                -- Flush any pending jiazhu group
                flush_jiazhu_group()
                -- Regular glyph
                local h = (D.getfield(temp_t, "height") or 0) + (D.getfield(temp_t, "depth") or 0)
                table.insert(items, {
                    type = "glyph",
                    node = temp_t,
                    height = h
                })
            end
        elseif tid == constants.HLIST or tid == constants.VLIST then
            flush_jiazhu_group()
            -- Check if it's a textbox
            local tb_w = D.get_attribute(temp_t, constants.ATTR_TEXTBOX_WIDTH) or 0
            local tb_h = D.get_attribute(temp_t, constants.ATTR_TEXTBOX_HEIGHT) or 0
            if tb_w > 0 and tb_h > 0 then
                table.insert(items, {
                    type = "textbox",
                    node = temp_t,
                    width = tb_w,
                    height = tb_h
                })
            end
        elseif tid == constants.KERN then
            flush_jiazhu_group()
            local k = D.getfield(temp_t, "kern") or 0
            if k ~= 0 then
                table.insert(items, {
                    type = "kern",
                    node = temp_t,
                    height = k
                })
            end
        elseif tid == constants.PENALTY then
            -- Check for column boundary marker (penalty -10001)
            local penalty_val = D.getfield(temp_t, "penalty")
            if penalty_val == -10001 then
                -- Column boundary marker - consume and stop
                temp_t = D.getnext(temp_t)
                break
            end
            -- Other penalties are ignored (continue collecting)
        end

        temp_t = D.getnext(temp_t)
    end

    -- Flush any remaining jiazhu group
    flush_jiazhu_group()

    return items, temp_t
end

--- Calculate total height of collected items
-- @param items (table) Array of item info from collect_nodes
-- @param grid_height (number) Grid cell height in sp
-- @return (number) Total height in grid cells (fractional)
local function calculate_total_height(items, grid_height)
    local total = 0
    for _, item in ipairs(items) do
        if item.type == "glyph" then
            total = total + 1
        elseif item.type == "jiazhu_group" then
            total = total + item.rows
        elseif item.type == "textbox" then
            total = total + item.height
        elseif item.type == "kern" then
            total = total + (item.height / grid_height)
        end
    end
    return total
end

--- Place column nodes into layout map
-- @param ctx (table) Grid context
-- @param start_node (node) The starting column node
-- @param layout_map (table) The layout map to populate
-- @param params (table) Layout parameters { line_limit, grid_height }
-- @param callbacks (table) Callbacks { flush, wrap, debug }
-- @return (node) The next node to process
function column.place_nodes(ctx, start_node, layout_map, params, callbacks)
    if callbacks.debug then
        callbacks.debug(string.format("  [layout] COLUMN DETECTED: node=%s", tostring(start_node)))
    end
    callbacks.flush()

    -- Get alignment mode from first node
    -- If align >= 4, it's a LastColumn (subtract LAST_OFFSET to get actual align)
    local raw_align = D.get_attribute(start_node, constants.ATTR_COLUMN_ALIGN) or column.ALIGN_TOP
    local align_mode = raw_align >= column.LAST_OFFSET and (raw_align - column.LAST_OFFSET) or raw_align
    local line_limit = params.line_limit
    local grid_height = params.grid_height

    -- Collect all column items (grouping jiazhu)
    local items, next_node = column.collect_nodes(start_node)
    if callbacks.debug then
        callbacks.debug(string.format("  [layout] Collected %d column items, align=%d", #items, align_mode))
    end

    if #items == 0 then
        callbacks.wrap()
        return next_node
    end

    -- Get style from first node for non-jiazhu items
    local first_node = nil
    for _, item in ipairs(items) do
        if item.node then
            first_node = item.node
            break
        elseif item.nodes and #item.nodes > 0 then
            first_node = item.nodes[1]
            break
        end
    end

    -- Override grid_height from style if set (per-Column grid-height)
    -- row_step: how many grid rows each character occupies
    -- (e.g., style grid_height=65pt, global grid_height=14pt → row_step≈4.64)
    -- In natural mode, also derive from font-size when grid-height is not explicit
    local row_step = 1
    if first_node then
        local style_reg_id = D.get_attribute(first_node, constants.ATTR_STYLE_REG_ID)
        if style_reg_id then
            local style_grid_height = style_registry.get_attr(style_reg_id, "grid_height")
            if style_grid_height and style_grid_height > 0 then
                row_step = style_grid_height / grid_height
            elseif (_G.content.layout_mode or "grid") ~= "grid" then
                -- Natural mode: derive row_step from font-size
                local style_font_size = style_registry.get_font_size(style_reg_id)
                if style_font_size and style_font_size > grid_height then
                    local gap = _G.content.inter_cell_gap or 0
                    row_step = (style_font_size + gap) / grid_height
                end
            end
        end
    end

    -- Calculate total height (in global grid units)
    local total_height = calculate_total_height(items, grid_height)
    -- Adjust for row_step: each glyph uses row_step grid units instead of 1
    if row_step ~= 1 then
        -- Recalculate: count glyphs and adjust
        local glyph_count = 0
        local non_glyph_height = 0
        for _, item in ipairs(items) do
            if item.type == "glyph" then
                glyph_count = glyph_count + 1
            elseif item.type == "jiazhu_group" then
                non_glyph_height = non_glyph_height + item.rows
            elseif item.type == "textbox" then
                non_glyph_height = non_glyph_height + item.height
            elseif item.type == "kern" then
                non_glyph_height = non_glyph_height + (item.height / grid_height)
            end
        end
        total_height = glyph_count * row_step + non_glyph_height
    end

    -- Calculate starting row based on alignment
    local start_row = 0
    local v_scale = 1.0
    local gap = 0

    if align_mode == column.ALIGN_TOP then
        start_row = 0
    elseif align_mode == column.ALIGN_BOTTOM then
        start_row = math.max(0, line_limit - total_height)
    elseif align_mode == column.ALIGN_CENTER then
        start_row = math.max(0, (line_limit - total_height) / 2)
    elseif align_mode == column.ALIGN_STRETCH then
        if total_height > line_limit then
            -- Squeeze mode
            v_scale = line_limit / total_height
        elseif #items > 1 then
            -- Distribute with gaps
            local scaled_height = total_height * v_scale
            gap = (line_limit - scaled_height) / (#items - 1)
        end
    end

    -- Place items
    local cur_row = start_row
    for _, item in ipairs(items) do
        if item.type == "glyph" then
            local entry = {
                page = ctx.cur_page,
                col = ctx.cur_col,
                y_sp = cur_row * grid_height,
                v_scale = v_scale,
                cell_height = helpers.resolve_cell_height(item.node, grid_height, nil, ctx.punct_config),
                cell_width = helpers.resolve_cell_width(item.node, nil),
            }
            helpers.apply_style_attrs(entry, item.node)
            layout_map[item.node] = entry
            cur_row = cur_row + row_step * v_scale + gap

        elseif item.type == "jiazhu_group" then
            -- Handle jiazhu group with dual-column layout (shared with textflow)
            local assignments = textflow.assign_balanced_sub_columns(item.nodes)

            for _, a in ipairs(assignments) do
                local jiazhu_row = cur_row + a.relative_row * v_scale
                local entry = {
                    page = ctx.cur_page,
                    col = ctx.cur_col,
                    y_sp = jiazhu_row * grid_height,
                    sub_col = a.sub_col,
                    v_scale = v_scale,
                    cell_height = grid_height,
                }
                helpers.apply_style_attrs(entry, a.node)
                layout_map[a.node] = entry
            end
            cur_row = cur_row + item.rows * v_scale + gap

        elseif item.type == "textbox" then
            local entry = {
                page = ctx.cur_page,
                col = ctx.cur_col,
                y_sp = cur_row * grid_height,
                is_block = true,
                height = item.height,
                v_scale = v_scale
            }
            helpers.apply_style_attrs(entry, item.node)
            layout_map[item.node] = entry
            cur_row = cur_row + item.height * v_scale + gap

        elseif item.type == "kern" then
            cur_row = cur_row + (item.height / grid_height) * v_scale
        end
    end

    -- Move to next column after placing column content
    callbacks.wrap()

    return next_node
end

-- Register module
package.loaded['core.luatex-cn-core-column'] = column

return column
