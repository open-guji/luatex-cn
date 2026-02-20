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
-- luatex-cn-banxin-layout.lua - Banxin Layout Calculation Module
-- ============================================================================
-- Layer: Stage 2 - Layout Layer
--
-- This module calculates banxin column layout data without rendering.
-- It provides pure functions that return layout data structures,
-- which can be used by the render stage to produce PDF output.
--
-- Design:
--   - Pure functions: no side effects, no node creation
--   - Returns data structures describing positions and dimensions
--   - Separates layout logic from rendering logic
--
-- ============================================================================

local constants = package.loaded['core.luatex-cn-constants'] or
    require('core.luatex-cn-constants')
local utils = package.loaded['util.luatex-cn-utils'] or
    require('util.luatex-cn-utils')

local banxin_layout = {}

-- ============================================================================
-- Helper Functions (Pure)
-- ============================================================================

--- Count UTF-8 characters in a string
-- @param text (string) UTF-8 string
-- @return (number) Character count
local function count_utf8_chars(text)
    if not text then return 0 end
    local count = 0
    for _ in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        count = count + 1
    end
    return count
end

--- Calculate fish tail (yuwei) dimensions
-- @param width (number) Banxin column width (sp)
-- @return (table) { edge_height, notch_height, gap }
local function calculate_yuwei_dimensions(width)
    return {
        edge_height = width * 0.39,
        notch_height = width * 0.17,
        gap = 65536 * 3.7, -- 3.7pt gap from dividing lines
    }
end

--- Calculate total yuwei height including gap
-- @param yuwei_dims (table) Yuwei dimensions
-- @return (number) Total height (sp)
local function calculate_yuwei_total_height(yuwei_dims)
    return yuwei_dims.gap + yuwei_dims.edge_height + yuwei_dims.notch_height
end

--- Parse chapter title into parts (supports \\\\ line breaks)
-- @param chapter_title (string) Chapter title
-- @return (table) Array of title parts
local function parse_chapter_title(chapter_title)
    if not chapter_title then return {} end
    -- Handle both \\ and \\\\ (TeX vs Lua literal escaping)
    local raw_title = chapter_title:gsub("\\\\+", "\n")
    local parts = {}
    for s in raw_title:gmatch("[^\n]+") do
        table.insert(parts, s)
    end
    return parts
end

-- ============================================================================
-- Region Layout Calculations
-- ============================================================================

--- Calculate the three region boundaries
-- @param params (table) { height, upper_ratio, middle_ratio }
-- @return (table) { upper, middle, lower } region data
local function calculate_regions(params)
    local total_height = params.height or 0
    local upper_ratio = params.upper_ratio or 0.28
    local middle_ratio = params.middle_ratio or 0.56
    local lower_ratio = 1 - upper_ratio - middle_ratio

    local upper_height = total_height * upper_ratio
    local middle_height = total_height * middle_ratio
    local lower_height = total_height * lower_ratio

    return {
        upper = {
            y_start = 0,
            height = upper_height,
        },
        middle = {
            y_start = upper_height,
            height = middle_height,
        },
        lower = {
            y_start = upper_height + middle_height,
            height = lower_height,
        },
    }
end

--- Calculate decoration positions (dividers, fish tails)
-- @param params (table) Layout params
-- @param regions (table) Region data
-- @return (table) Decoration layout
local function calculate_decorations(params, regions)
    local yuwei_dims = calculate_yuwei_dimensions(params.width or 0)
    local y = params.y or 0

    return {
        divider_1_y = y - regions.upper.height,
        divider_2_y = y - regions.upper.height - regions.middle.height,
        draw_dividers = params.banxin_divider ~= false,
        upper_yuwei = params.upper_yuwei ~= false,
        lower_yuwei = params.lower_yuwei ~= false,
        yuwei_dims = yuwei_dims,
    }
end

-- ============================================================================
-- Text Element Layout Calculations
-- ============================================================================

--- Calculate book name layout
-- @param params (table) Layout params
-- @param regions (table) Region data
-- @return (table|nil) Book name layout element
local function calculate_book_name_layout(params, regions)
    local book_name = params.book_name or ""
    if book_name == "" then return nil end

    local upper_height = regions.upper.height
    local base_f_size = constants.resolve_dimen(params.font_size, 655360)
    -- Use book_name_font_size if specified, otherwise fall back to base font size
    local f_size = constants.resolve_dimen(params.book_name_font_size, base_f_size) or base_f_size
    local b_padding_top = constants.resolve_dimen(params.b_padding_top, base_f_size)
    local b_padding_bottom = constants.resolve_dimen(params.b_padding_bottom, base_f_size)
    local effective_b = params.draw_border and constants.resolve_dimen(params.border_thickness, base_f_size) or 0
    local adj_height = upper_height - effective_b - b_padding_top - b_padding_bottom
    local num_chars = count_utf8_chars(book_name)

    local grid_h = constants.resolve_dimen(constants.to_dimen(params.book_name_grid_height), f_size)
    local total_text_height
    if grid_h and grid_h > 0 then
        total_text_height = grid_h * num_chars
    else
        if num_chars * f_size > adj_height then
            f_size = adj_height / num_chars
        end
        total_text_height = num_chars * f_size
    end

    local block_y_top = params.y - effective_b - b_padding_top
    local y_start
    if params.book_name_align == "top" then
        y_start = block_y_top
    else
        y_start = block_y_top - (adj_height - total_text_height) / 2
    end

    return {
        type = "book_name",
        is_runtime = false,
        text = book_name,
        x = params.x,
        y_top = y_start,
        width = params.width,
        height = total_text_height,
        num_cells = num_chars,
        v_align = "center",
        h_align = "center",
        font_size = f_size,
    }
end

--- Calculate chapter title layout
-- @param params (table) Layout params
-- @param regions (table) Region data
-- @param decorations (table) Decoration data
-- @return (table|nil) Chapter title layout (marked as runtime)
local function calculate_chapter_title_layout(params, regions, decorations)
    -- Chapter title is runtime content (changes per page)
    -- We calculate the position/dimensions but mark text as runtime
    local chapter_title = params.chapter_title or ""

    local yuwei_dims = decorations.yuwei_dims
    local upper_yuwei_total = decorations.upper_yuwei and calculate_yuwei_total_height(yuwei_dims) or 0
    local lower_yuwei_total = decorations.lower_yuwei and calculate_yuwei_total_height(yuwei_dims) or 0

    local middle_y_top = params.y - regions.upper.height
    local base_f_size = constants.resolve_dimen(params.font_size, 655360)
    local title_top_margin = constants.resolve_dimen(params.chapter_title_top_margin, base_f_size) or 0

    local chapter_y_top = middle_y_top - upper_yuwei_total - title_top_margin
    local available_height = regions.middle.height - upper_yuwei_total - lower_yuwei_total - title_top_margin
    if available_height <= 0 then
        available_height = regions.middle.height * 0.3 -- Fallback
    end

    local title_font_size = constants.resolve_dimen(params.chapter_title_font_size, base_f_size)
    local font_scale = nil
    if not title_font_size then
        font_scale = 0.5 -- Default scale for banxin titles if not specified
        title_font_size = base_f_size * font_scale
    end

    local desired_grid_h = constants.resolve_dimen(params.chapter_title_grid_height, title_font_size)
    if not desired_grid_h or desired_grid_h <= 0 then
        desired_grid_h = title_font_size * 1.1
    end

    return {
        type = "chapter_title",
        is_runtime = true,  -- Content resolved at render time
        text = nil,         -- Will be filled at render time
        x = params.x,
        y_top = chapter_y_top,
        width = params.width,
        available_height = available_height,
        font_size = title_font_size,
        font_scale = font_scale,
        grid_height = desired_grid_h,
        n_cols = params.chapter_title_cols or 1,
        h_align = params.chapter_title_align or "center",
    }
end

--- Calculate page number layout
-- @param params (table) Layout params
-- @param regions (table) Region data
-- @param decorations (table) Decoration data
-- @return (table|nil) Page number layout (marked as runtime)
local function calculate_page_number_layout(params, regions, decorations)
    -- Page number is runtime content (changes per page)
    local yuwei_dims = decorations.yuwei_dims
    local upper_yuwei_total = decorations.upper_yuwei and calculate_yuwei_total_height(yuwei_dims) or 0
    local lower_yuwei_total = decorations.lower_yuwei and calculate_yuwei_total_height(yuwei_dims) or 0

    local middle_y_bottom = params.y - regions.upper.height - regions.middle.height
    local page_right_margin = 65536 * 2
    local page_bottom_margin = params.b_padding_bottom or (65536 * 15)

    local base_f_size = constants.resolve_dimen(params.font_size, 655360)
    local f_size = constants.resolve_dimen(params.page_number_font_size, base_f_size) or (65536 * 10)
    local grid_h = constants.resolve_dimen(params.page_number_grid_height, f_size)
    if not grid_h or grid_h <= 0 then
        grid_h = f_size * 1.2
    end

    -- Estimate container height (actual depends on page number digits)
    -- We use a placeholder assuming 3-digit page numbers
    local estimated_chars = 3
    local container_height = grid_h * estimated_chars

    local p_v_align = "bottom"
    local p_h_align = "right"
    local page_y_top = middle_y_bottom + lower_yuwei_total + page_bottom_margin + container_height

    if params.page_number_align == "center" then
        p_v_align = "center"
        p_h_align = "center"
        local available_middle_h = regions.middle.height - upper_yuwei_total - lower_yuwei_total
        local center_y = middle_y_bottom + lower_yuwei_total + available_middle_h / 2
        page_y_top = center_y + container_height / 2
    elseif params.page_number_align == "bottom-center" then
        p_v_align = "bottom"
        p_h_align = "center"
    end

    return {
        type = "page_number",
        is_runtime = true,  -- Content resolved at render time
        text = nil,         -- Will be filled at render time
        x = params.x,
        y_top = page_y_top,
        width = params.width - (params.page_number_align == "center" and 0 or page_right_margin),
        grid_height = grid_h,
        v_align = p_v_align,
        h_align = p_h_align,
        font_size = f_size,
        middle_y_bottom = middle_y_bottom,
        lower_yuwei_total = lower_yuwei_total,
        page_bottom_margin = page_bottom_margin,
        upper_yuwei_total = upper_yuwei_total,
        middle_height = regions.middle.height,
    }
end

--- Calculate publisher layout
-- @param params (table) Layout params
-- @param regions (table) Region data
-- @return (table|nil) Publisher layout element
local function calculate_publisher_layout(params, regions)
    local publisher = params.publisher or ""
    if publisher == "" then return nil end

    local base_f_size = constants.resolve_dimen(params.font_size, 655360) or 655360
    local f_size = constants.resolve_dimen(params.publisher_font_size, base_f_size)
    if not f_size or f_size <= 0 then
        f_size = 65536 * 10 -- Default 10pt
    end

    local grid_h = constants.resolve_dimen(params.publisher_grid_height, f_size)
    if not grid_h or grid_h <= 0 then
        grid_h = math.floor(f_size * 1.2 + 0.5) -- Default 1.2 line height
    end

    local num_chars = count_utf8_chars(publisher)
    local container_height = grid_h * num_chars
    local bottom_margin = constants.resolve_dimen(params.publisher_bottom_margin, f_size) or (65536 * 5)

    local banxin_bottom_y = params.y - params.height
    local y_top = banxin_bottom_y + bottom_margin + container_height

    return {
        type = "publisher",
        is_runtime = false,
        text = publisher,
        x = params.x,
        y_top = y_top,
        width = params.width,
        height = container_height,
        v_align = "bottom",
        h_align = params.publisher_align == "center" and "center" or "right",
        font_size = f_size,
    }
end

-- ============================================================================
-- Main Layout Function
-- ============================================================================

--- Calculate complete banxin column layout
-- @param params (table) Configuration parameters
-- @return (table) Complete layout specification
function banxin_layout.calculate_column_layout(params)
    -- Calculate regions
    local regions = calculate_regions(params)

    -- Calculate decorations
    local decorations = calculate_decorations(params, regions)

    -- Calculate text elements
    local elements = {}

    local book_name_elem = calculate_book_name_layout(params, regions)
    if book_name_elem then
        table.insert(elements, book_name_elem)
    end

    local chapter_elem = calculate_chapter_title_layout(params, regions, decorations)
    if chapter_elem then
        table.insert(elements, chapter_elem)
    end

    local page_num_elem = calculate_page_number_layout(params, regions, decorations)
    if page_num_elem then
        table.insert(elements, page_num_elem)
    end

    local publisher_elem = calculate_publisher_layout(params, regions)
    if publisher_elem then
        table.insert(elements, publisher_elem)
    end

    return {
        -- Column geometry
        column = {
            x = params.x,
            y = params.y,
            width = params.width,
            height = params.height,
            draw_border = params.draw_border,
            border_thickness = params.border_thickness,
            color_str = params.color_str or "0 0 0",
        },
        -- Region boundaries
        regions = regions,
        -- Decoration positions
        decorations = decorations,
        -- Text elements
        elements = elements,
        -- Original params for render-time calculations
        params = params,
    }
end

-- ============================================================================
-- Exported Helper Functions (for testing and render module)
-- ============================================================================

banxin_layout.count_utf8_chars = count_utf8_chars
banxin_layout.calculate_yuwei_dimensions = calculate_yuwei_dimensions
banxin_layout.calculate_yuwei_total_height = calculate_yuwei_total_height
banxin_layout.parse_chapter_title = parse_chapter_title
banxin_layout.calculate_regions = calculate_regions

-- Register in package.loaded
package.loaded['banxin.luatex-cn-banxin-layout'] = banxin_layout

return banxin_layout
