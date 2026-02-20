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

local function apply_style_attrs(map_entry, node_ptr)
    local style_id = D.get_attribute(node_ptr, constants.ATTR_STYLE_REG_ID)
    if not style_id or style_id <= 0 then return end
    local style = style_registry.get(style_id)
    if not style then return end
    if style.font_color then map_entry.font_color = style.font_color end
    if style.font_size then map_entry.font_size = style.font_size end
    if style.font then map_entry.font = style.font end
    if style.textflow_align then map_entry.textflow_align = style.textflow_align end
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

    local paper_w = params.paper_width  -- 0 set at layout_params definition
    if paper_w <= 0 then return false end

    local center = paper_w / 2
    local gap_half_width = 15 * 65536 -- 15pt in sp

    local floating_x = params.floating_x  -- 0 set at layout_params definition
    if floating_x <= 0 then
        floating_x = get_margin_right(params)
    end

    local col_right_x = floating_x + col * g_width
    local col_left_x = col_right_x + g_width

    local gap_left = center - gap_half_width
    local gap_right = center + gap_half_width

    local overlaps = (col_right_x < gap_right) and (col_left_x > gap_left)

    return overlaps
end

-- =============================================================================
-- Occupancy map functions
-- =============================================================================

local function is_occupied(occupancy, p, c, r)
    if not occupancy[p] then return false end
    if not occupancy[p][c] then return false end
    return occupancy[p][c][r] == true
end

local function mark_occupied(occupancy, p, c, r)
    if not occupancy[p] then occupancy[p] = {} end
    if not occupancy[p][c] then occupancy[p][c] = {} end
    occupancy[p][c][r] = true
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
    -- 1. Check node style for per-character/paragraph cell_height override
    local sid = D.get_attribute(node, constants.ATTR_STYLE_REG_ID)
    if sid and sid > 0 then
        local style_ch = style_registry.get_cell_height(sid)
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
