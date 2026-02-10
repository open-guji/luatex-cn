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
-- @return (number) Style ID (always returns a valid number)
function column.push_style(font_color, font_size, font, grid_height)
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
    if grid_height and grid_height ~= "" then
        style.grid_height = constants.to_dimen(grid_height)
    end
    local id = style_registry.push(style)
    -- push() may return nil if style is empty, ensure we return 0
    return id or 0
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

    local style_reg_id = first_node and D.get_attribute(first_node, constants.ATTR_STYLE_REG_ID)
    local current_style = style_registry.get(style_reg_id)
    local font_color_str = current_style and current_style.font_color or nil
    local font_size_val = current_style and current_style.font_size or nil
    local font_str = current_style and current_style.font or nil

    -- Override grid_height from style if set (per-Column grid-height)
    -- row_step: how many grid rows each character occupies
    -- (e.g., style grid_height=65pt, global grid_height=14pt → row_step≈4.64)
    local row_step = 1
    if current_style and current_style.grid_height and current_style.grid_height > 0 then
        row_step = current_style.grid_height / grid_height
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
                row = cur_row,
                v_scale = v_scale
            }
            if font_color_str then entry.font_color = font_color_str end
            if font_size_val then entry.font_size = font_size_val end
            if font_str then entry.font = font_str end
            layout_map[item.node] = entry
            cur_row = cur_row + row_step * v_scale + gap

        elseif item.type == "jiazhu_group" then
            -- Handle jiazhu group with dual-column layout
            local jiazhu_nodes = item.nodes
            local N = #jiazhu_nodes
            local right_count = math.ceil(N / 2)

            -- Get jiazhu style from first jiazhu node
            local jiazhu_style_id = D.get_attribute(jiazhu_nodes[1], constants.ATTR_STYLE_REG_ID)
            local jiazhu_style = style_registry.get(jiazhu_style_id)
            local jiazhu_color = jiazhu_style and jiazhu_style.font_color or nil
            local jiazhu_size = jiazhu_style and jiazhu_style.font_size or nil
            local jiazhu_font = jiazhu_style and jiazhu_style.font or nil
            local jiazhu_align = jiazhu_style and jiazhu_style.textflow_align or nil

            for i, jnode in ipairs(jiazhu_nodes) do
                local sub_col, relative_row
                if i <= right_count then
                    sub_col = 1
                    relative_row = i - 1
                else
                    sub_col = 2
                    relative_row = i - right_count - 1
                end

                D.set_attribute(jnode, constants.ATTR_JIAZHU_SUB, sub_col)

                local entry = {
                    page = ctx.cur_page,
                    col = ctx.cur_col,
                    row = cur_row + relative_row * v_scale,
                    sub_col = sub_col,
                    v_scale = v_scale
                }
                if jiazhu_color then entry.font_color = jiazhu_color end
                if jiazhu_size then entry.font_size = jiazhu_size end
                if jiazhu_font then entry.font = jiazhu_font end
                if jiazhu_align then entry.textflow_align = jiazhu_align end
                layout_map[jnode] = entry
            end
            cur_row = cur_row + item.rows * v_scale + gap

        elseif item.type == "textbox" then
            local entry = {
                page = ctx.cur_page,
                col = ctx.cur_col,
                row = cur_row,
                is_block = true,
                height = item.height,
                v_scale = v_scale
            }
            if font_color_str then entry.font_color = font_color_str end
            if font_size_val then entry.font_size = font_size_val end
            if font_str then entry.font = font_str end
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
