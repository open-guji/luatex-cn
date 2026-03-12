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
-- layout_grid_helpers.lua - 布局网格辅助函数
-- ============================================================================
-- 从 layout_grid.lua 提取的参数获取、样式属性、列验证、占用地图等辅助函数。
-- 这些函数不依赖布局上下文 (ctx)，是纯粹的工具函数。
-- ============================================================================

local constants = package.loaded['core.luatex-cn-constants'] or
    require('core.luatex-cn-constants')
local D = constants.D
local style_registry = package.loaded['util.luatex-cn-style-registry'] or
    require('util.luatex-cn-style-registry')

local helpers = {}

-- =============================================================================
-- Parameter getters (all values must be provided via params)
-- =============================================================================

local function get_banxin_on(params)
    if params.banxin_on ~= nil then
        return params.banxin_on
    end
    return false
end

local function get_grid_width(params, fallback)
    if params.grid_width and type(params.grid_width) == "number" and params.grid_width > 0 then
        return params.grid_width
    end
    return fallback
end

local function get_margin_right(params)
    if params.margin_right then
        if type(params.margin_right) == "number" then
            return params.margin_right
        else
            return constants.to_dimen(params.margin_right) or 0
        end
    end
    return 0
end

local function get_chapter_title(params)
    if params.chapter_title and params.chapter_title ~= "" then
        return params.chapter_title
    end
    return ""
end

-- =============================================================================
-- Style attribute helpers
-- =============================================================================

local function get_node_font_color(node)
    local style_id = D.get_attribute(node, constants.ATTR_STYLE_REG_ID)
    if style_id and style_id > 0 then
        return style_registry.get_font_color(style_id)
    end
    return nil
end

local function get_node_font_size(node)
    local style_id = D.get_attribute(node, constants.ATTR_STYLE_REG_ID)
    if style_id and style_id > 0 then
        return style_registry.get_font_size(style_id)
    end
    return nil
end

local function get_node_font(node)
    local style_id = D.get_attribute(node, constants.ATTR_STYLE_REG_ID)
    if style_id and style_id > 0 then
        return style_registry.get_font(style_id)
    end
    return nil
end

-- P1: style fields (font_color, font_size, font, textflow_align, xshift, yshift)
-- are no longer copied into layout_map entries. Renderers read directly from
-- style_registry via ATTR_STYLE_REG_ID. This function is kept as a no-op for
-- backward compatibility with existing call sites.
local function apply_style_attrs(map_entry, node_ptr)
    -- no-op: style fields now read directly from style_registry at render time
end

-- =============================================================================
-- P2: Absolute coordinate computation
-- Mirrors render-position.lua's get_column_x / calculate_rtl_position logic,
-- but callable from the layout stage (Stage 2) without requiring Stage 3 modules.
-- =============================================================================

--- Compute the grid X offset for a given rtl_col in uniform-column mode.
-- Mirrors render-position.lua:get_column_x.
local function get_column_x_uniform(rtl_col, params)
    local grid_width = get_grid_width(params, params.grid_height or 0)
    local banxin_width = params.banxin_width or 0
    local interval = params.n_column or 0
    if interval <= 0 or banxin_width <= 0 or banxin_width == grid_width then
        return rtl_col * grid_width
    end
    local group_size = interval + 1
    local full_groups = math.floor(rtl_col / group_size)
    local remainder = rtl_col % group_size
    local x = full_groups * (interval * grid_width + banxin_width)
    if remainder < interval then
        x = x + remainder * grid_width
    else
        x = x + interval * grid_width
    end
    return x
end

--- Compute the X coordinate (sp) for a layout_map entry.
-- Coordinate system: origin at content area right edge, X increases from right to left.
-- col=0 (rightmost) → x=0, col=1 → x=grid_width, etc.
-- Does NOT depend on total_cols — each node only needs its own col.
-- Pure grid coordinate: no half_thickness, no shift_x.
-- @param col (number) Logical column index (0-indexed, 0 = rightmost)
-- @param page (number) Page index (0-indexed)
-- @param ctx (table) Layout context (has params, col_widths_sp, col_interval, col_banxin_width)
-- @return (number) X coordinate from right edge (sp)
local function compute_x(col, page, ctx)
    -- Only use variable-width col_widths_sp in Free Mode.
    -- Non-free-mode \行[width=...] columns also write to col_widths_sp,
    -- but only for specific columns — using var mode with incomplete data
    -- produces wrong results. Non-free-mode always uses uniform calculation.
    if ctx.is_free_mode then
        local col_widths = ctx.col_widths_sp and ctx.col_widths_sp[page]
        if col_widths and next(col_widths) then
            local x = 0
            for c = 0, col - 1 do
                x = x + (col_widths[c + 1] or 0)
            end
            return x
        end
    end
    -- Uniform-width column mode with banxin support
    local grid_width = get_grid_width(ctx.params, ctx.params.grid_height or 0)
    local interval = ctx.col_interval or 0
    local banxin_width = ctx.col_banxin_width or 0
    if interval <= 0 or banxin_width <= 0 or banxin_width == grid_width then
        return col * grid_width
    end
    local group_size = interval + 1
    local full_groups = math.floor(col / group_size)
    local remainder = col % group_size
    local x = full_groups * (interval * grid_width + banxin_width)
    if remainder < interval then
        x = x + remainder * grid_width
    else
        x = x + interval * grid_width
    end
    return x
end

--- Compute the absolute Y coordinate (sp) for a layout_map entry.
-- Origin: page top-right corner. Positive direction: top-to-bottom.
-- Includes shift_y (page geometry offset).
-- @param y_sp (number) Row Y position (sp, from grid top)
-- @param band_y_offset_sp (number) Band Y offset (sp)
-- @param ctx (table) Layout context (has shift_y)
-- @return (number) Y coordinate (sp)
local function compute_y(y_sp, band_y_offset_sp, ctx)
    return (y_sp or 0) + (band_y_offset_sp or 0) + (ctx.shift_y or 0)
end

-- =============================================================================
-- Column validation functions
-- =============================================================================

local function is_reserved_col(col, interval, banxin_on)
    if not banxin_on then return false end
    if interval <= 0 then return false end
    return _G.core.hooks.is_reserved_column(col, interval)
end

local function is_center_gap_col(col, params, grid_height)
    local banxin_on = get_banxin_on(params)
    if not banxin_on then return false end

    local g_width = get_grid_width(params, grid_height)

    local paper_w = params.paper_width
    if paper_w <= 0 then return false end

    local center = paper_w / 2
    local gap_half_width = 15 * 65536 -- 15pt in sp

    local floating_x = params.floating_x or 0

    -- Determine physical column position based on context:
    -- TextBox with floating_x > 0 (e.g. meipi): col is physical (left-to-right)
    -- Main text (floating_x = 0): col is logical (right-to-left), need RTL conversion
    local phys_col
    if floating_x > 0 then
        -- TextBox: col is physical column index, floating_x is absolute x position
        phys_col = col
    else
        -- Main text: convert logical RTL col to physical LTR col
        local total_cols = params.page_columns or 1
        if total_cols <= 0 then total_cols = 1 end
        phys_col = total_cols - 1 - col
        floating_x = get_margin_right(params)
    end

    local col_right_x = floating_x + phys_col * g_width
    local col_left_x = col_right_x + g_width

    local gap_left = center - gap_half_width
    local gap_right = center + gap_half_width

    local overlaps = (col_right_x < gap_right) and (col_left_x > gap_left)

    return overlaps
end

-- =============================================================================
-- Occupancy map functions
-- =============================================================================

local function is_occupied(occupancy, p, b, c, r)
    if not occupancy[p] then return false end
    if not occupancy[p][b] then return false end
    if not occupancy[p][b][c] then return false end
    return occupancy[p][b][c][r] == true
end

local function mark_occupied(occupancy, p, b, c, r)
    if not occupancy[p] then occupancy[p] = {} end
    if not occupancy[p][b] then occupancy[p][b] = {} end
    if not occupancy[p][b][c] then occupancy[p][b][c] = {} end
    occupancy[p][b][c][r] = true
end

-- =============================================================================
-- Cell height calculation (natural layout mode)
-- =============================================================================

--- Get cell height for a node in natural layout mode
-- Returns font_size from style registry, or actual font size,
-- or grid_height as fallback.
-- Punctuation nodes (ATTR_PUNCT_TYPE > 0) get half height in mainland+squeeze mode.
-- @param node (direct node) The glyph node
-- @param grid_height (number) Base grid height in sp
-- @param punct_config (table) Punctuation config {style, squeeze}.
--   Callers must provide this; defaults are set at the parameter source (core-main.lua).
local function get_cell_height(node, grid_height, punct_config)
    local base
    local fs = get_node_font_size(node)
    if fs and fs > 0 then
        base = fs
    else
        local fid = D.getfield(node, "font")
        if fid then
            local f = font.getfont(fid)
            if f and f.size then base = f.size end
        end
    end
    base = base or grid_height
    -- Punctuation occupies half cell in mainland mode (squeeze enabled)
    -- Taiwan style: all punctuation occupies full cell (no squeeze)
    local punct_type = D.get_attribute(node, constants.ATTR_PUNCT_TYPE)
    if punct_type and punct_type > 0 and punct_config then
        local style = punct_config.style
        local squeeze = punct_config.squeeze
        if style ~= "taiwan" and squeeze then
            -- Only comma(4)/open(1)/close(2) get half height
            -- fullstop(3), middle(5), nobreak(6) stay full height
            if punct_type == 4 or punct_type == 1 or punct_type == 2 then
                return math.floor(base * 0.5)
            end
        end
    end
    return base
end

-- =============================================================================
-- Unified cell size resolution
-- =============================================================================

--- Resolve cell height for a node in the unified layout engine
-- Priority: 1) node style cell_height → 2) column default_cell_height → 3) font-size based
-- @param node (direct node) The glyph node
-- @param grid_height (number) Base grid height in sp
-- @param default_cell_height (number|nil) Fixed cell height (grid mode) or nil (natural mode)
-- @param punct_config (table|nil) Punctuation config for natural mode fallback
-- @return (number) Cell height in sp
local function resolve_cell_height(node, grid_height, default_cell_height, punct_config)
    -- 1. Check node style for per-character/paragraph grid_height override
    local sid = D.get_attribute(node, constants.ATTR_STYLE_REG_ID)
    if sid and sid > 0 then
        local style_ch = style_registry.get_grid_height(sid)
        if style_ch and style_ch > 0 then
            return style_ch
        end
    end
    -- 2. Column-level default (grid mode)
    if default_cell_height and default_cell_height > 0 then
        return default_cell_height
    end
    -- 3. Natural mode: font-size based
    return get_cell_height(node, grid_height, punct_config)
end

--- Resolve cell width for a node in the unified layout engine
-- Priority: 1) node style cell_width → 2) column default_cell_width
-- @param node (direct node) The glyph node
-- @param default_cell_width (number|nil) Column-level default cell width in sp
-- @return (number|nil) Cell width in sp, or nil (use grid_width)
local function resolve_cell_width(node, default_cell_width)
    local sid = D.get_attribute(node, constants.ATTR_STYLE_REG_ID)
    if sid and sid > 0 then
        local style_cw = style_registry.get_cell_width(sid)
        if style_cw and style_cw > 0 then
            return style_cw
        end
    end
    return default_cell_width
end

--- Resolve cell gap for a node in the unified layout engine
-- Priority: 1) node style cell_gap → 2) column default_cell_gap
-- @param node (direct node) The glyph node
-- @param default_cell_gap (number) Column-level default cell gap in sp
-- @return (number) Cell gap in sp
local function resolve_cell_gap(node, default_cell_gap)
    local sid = D.get_attribute(node, constants.ATTR_STYLE_REG_ID)
    if sid and sid > 0 then
        local style_gap = style_registry.get_cell_gap(sid)
        if style_gap then
            return style_gap
        end
    end
    return default_cell_gap or 0
end

-- =============================================================================
-- Module exports
-- =============================================================================

helpers.get_banxin_on = get_banxin_on
helpers.get_grid_width = get_grid_width
helpers.get_margin_right = get_margin_right
helpers.get_chapter_title = get_chapter_title

helpers.get_node_font_color = get_node_font_color
helpers.get_node_font_size = get_node_font_size
helpers.get_node_font = get_node_font
helpers.apply_style_attrs = apply_style_attrs
helpers.compute_x = compute_x
helpers.compute_y = compute_y

helpers.is_reserved_col = is_reserved_col
helpers.is_center_gap_col = is_center_gap_col

helpers.is_occupied = is_occupied
helpers.mark_occupied = mark_occupied

helpers.get_cell_height = get_cell_height
helpers.resolve_cell_height = resolve_cell_height
helpers.resolve_cell_width = resolve_cell_width
helpers.resolve_cell_gap = resolve_cell_gap

--- Create a linemark entry with standard fields
-- @param opts (table) { group_id, col, y_sp, cell_height, font_size, sub_col, x_center_sp }
-- @return (table) Linemark entry
local function create_linemark_entry(opts)
    return {
        group_id = opts.group_id,
        col = opts.col,
        y_sp = opts.y_sp,
        cell_height = opts.cell_height,
        font_size = opts.font_size,
        sub_col = opts.sub_col,
        x_center_sp = opts.x_center_sp,
    }
end

helpers.create_linemark_entry = create_linemark_entry

package.loaded['core.luatex-cn-layout-grid-helpers'] = helpers
return helpers
