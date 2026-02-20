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
-- luatex-cn-guji-meipi.lua - MeiPi (眉批) auto-positioned annotation module
-- ============================================================================
-- MeiPi (眉批) is a type of annotation that appears above the main text.
-- Unlike PiZhu (批注) which requires manual x,y coordinates, MeiPi
-- automatically calculates positions:
--   - Y coordinate: Bottom of annotation aligned to just above the main text
--   - X coordinate: Arranged from right to left, avoiding overlap with other MeiPi
-- ============================================================================

local constants = package.loaded['core.luatex-cn-constants'] or
    require('core.luatex-cn-constants')
local style_registry = package.loaded['util.luatex-cn-style-registry'] or
    require('util.luatex-cn-style-registry')

local meipi = {}

-- Registry for MeiPi annotations on current page
-- Each entry: { width = sp, height = sp }
-- Reset at the start of each page
meipi.current_page_annotations = {}

-- Default spacing between MeiPi annotations (in sp)
meipi.spacing = 65536 * 10 -- 10pt default

-- Default gap between MeiPi bottom and main text top (in sp)
meipi.gap = 0 -- 0pt default

--- Setup MeiPi parameters
-- @param params (table) Parameters from TeX
function meipi.setup(params)
    params = params or {}
    if params.spacing then
        meipi.spacing = constants.to_dimen(params.spacing) or meipi.spacing
    end
    if params.gap then
        meipi.gap = constants.to_dimen(params.gap) or meipi.gap
    end
end

--- Reset the annotation registry (called at the start of each page/document)
function meipi.reset()
    meipi.current_page_annotations = {}
end

--- Calculate the X coordinate for a new MeiPi annotation
-- Arranges from right to left with spacing
-- NOTE: TextBox.render_floating_box interprets 'x' as distance from the RIGHT edge of the logical page.
-- So we just need to return the accumulated offset from the right.
-- @param width (number) Width of the new annotation in sp
-- @return (number) X coordinate in sp (distance from RIGHT edge)
function meipi.calculate_x(width)
    local margin_right = _G.page and _G.page.margin_right or (20 * 65536)

    -- Get outer border settings from style stack
    local current_id = style_registry.current_id()
    local outer_border = style_registry.get_outer_border(current_id)
    local ob_thickness = style_registry.get_outer_border_thickness(current_id) or 0
    local ob_sep = style_registry.get_outer_border_sep(current_id) or 0

    -- Start offset from the right edge of the paper
    -- If there is an outer border, we need to push further in (increase x from right)
    local x = margin_right
    if outer_border then
        x = x + ob_thickness + ob_sep
    end

    -- Add widths of existing annotations plus spacing
    -- This pushes the new annotation further to the left (increasing distance from right)
    for _, ann in ipairs(meipi.current_page_annotations) do
        x = x + ann.width + meipi.spacing
    end

    return x
end

--- Calculate the Y coordinate for a MeiPi annotation
-- Positions the annotation so its bottom is above the main text
-- @param height (number) Height of the annotation in sp
-- @return (number) Y coordinate in sp (from top edge of paper)
function meipi.calculate_y(height)
    local margin_top = _G.page and _G.page.margin_top or (20 * 65536)
    -- border_padding_top is page-level config, still from _G.content
    local border_padding_top = _G.content and _G.content.border_padding_top or 0

    -- Get outer border settings from style stack
    local current_id = style_registry.current_id()
    local outer_border = style_registry.get_outer_border(current_id)
    local ob_thickness = style_registry.get_outer_border_thickness(current_id) or 0
    local ob_sep = style_registry.get_outer_border_sep(current_id) or 0

    -- Calculate where the main text starts
    local text_top = margin_top
    if outer_border then
        text_top = text_top + ob_thickness + ob_sep
    end
    text_top = text_top + border_padding_top

    -- Position the annotation so its bottom is at (text_top - gap)
    -- Y coordinate is usually measured from top-left in PDF, but TeX/TextBox might expect
    -- coordinates relative to paper top-left (y increases downwards) OR bottom-left (y increases upwards).
    -- TextBox documentation says: "y is distance from top of paper".

    -- The annotation box origin is its top-left corner.
    -- We want (y + height) = (text_top - gap)
    -- So y = text_top - gap - height
    local y = text_top - meipi.gap - height

    return y
end

--- Register a MeiPi annotation and get its calculated coordinates
-- @param width (number) Width of the annotation in sp
-- @param height (number) Height of the annotation in sp
-- @return x, y (number, number) Calculated coordinates in sp
function meipi.register(width, height)
    local x = meipi.calculate_x(width)
    local y = meipi.calculate_y(height)

    -- Register this annotation
    table.insert(meipi.current_page_annotations, {
        width = width,
        height = height,
        x = x,
        y = y
    })

    return x, y
end

--- Get coordinates for the next MeiPi annotation
-- This is the main entry point called from TeX
-- @param width_str (string) Width as a dimension string or sp value
-- @param height_str (string) Height as a dimension string or sp value
-- @return (string) "x,y" coordinates in pt for TeX to parse
function meipi.get_coordinates(width_str, height_str)
    -- Handle both dimension strings and raw sp values
    local width = tonumber(width_str)
    if not width then
        width = constants.to_dimen(width_str) or 0
    end
    local height = tonumber(height_str)
    if not height then
        height = constants.to_dimen(height_str) or 0
    end

    local x, y = meipi.register(width, height)

    -- Convert to pt for TeX visualization (TextBox uses pt usually if unit not specified?)
    -- Here we return "NNNpt,NNNpt" string.
    local x_pt = x / 65536
    local y_pt = y / 65536

    return string.format("%.5fpt,%.5fpt", x_pt, y_pt)
end

--- Calculate coordinates and store them in global meipi_x and meipi_y
-- This simplifies the TeX side by avoiding string parsing
function meipi.calculate_and_store(width_str, height_str)
    local width = tonumber(width_str) or 0
    local height = tonumber(height_str) or 0

    local x, y = meipi.register(width, height)

    _G.meipi_x = string.format("%.5fpt", x / 65536)
    _G.meipi_y = string.format("%.5fpt", y / 65536)
end

--- Register annotation with fixed Y, calculate X only
-- Used when only Y is provided by user
-- @param width (number) Width of the annotation in sp
-- @param height (number) Height of the annotation in sp
-- @param fixed_y (number) User-provided Y coordinate in sp
-- @return x (number) Calculated X coordinate in sp
function meipi.register_with_fixed_y(width, height, fixed_y)
    local x = meipi.calculate_x(width)

    -- Register this annotation with the fixed y
    table.insert(meipi.current_page_annotations, {
        width = width,
        height = height,
        x = x,
        y = fixed_y
    })

    return x
end

--- Calculate X and store in global meipi_x (for case when only Y is provided)
function meipi.calculate_x_and_store(width_str, height_str, y_str)
    local width = tonumber(width_str) or 0
    local height = tonumber(height_str) or 0
    local fixed_y = constants.to_dimen(y_str) or 0

    local x = meipi.register_with_fixed_y(width, height, fixed_y)

    _G.meipi_x = string.format("%.5fpt", x / 65536)
end

--- Calculate Y and store in global meipi_y (for case when only X is provided)
-- Also registers the annotation so subsequent meipi can consider it
function meipi.calculate_y_and_store(width_str, height_str, x_str)
    local width = tonumber(width_str) or 0
    local height = tonumber(height_str) or 0
    local fixed_x = constants.to_dimen(x_str) or 0

    local y = meipi.calculate_y(height)

    -- Register this annotation so next meipi knows about it
    table.insert(meipi.current_page_annotations, {
        width = width,
        height = height,
        x = fixed_x,
        y = y
    })

    _G.meipi_y = string.format("%.5fpt", y / 65536)
end

--- Register annotation with both fixed X and Y (for case when both are provided)
-- This ensures the annotation is tracked for subsequent meipi positioning
function meipi.register_with_fixed_xy(width_str, height_str, x_str, y_str)
    local width = tonumber(width_str) or 0
    local height = tonumber(height_str) or 0
    local fixed_x = constants.to_dimen(x_str) or 0
    local fixed_y = constants.to_dimen(y_str) or 0

    -- Register this annotation so next meipi knows about it
    table.insert(meipi.current_page_annotations, {
        width = width,
        height = height,
        x = fixed_x,
        y = fixed_y
    })
end

--- Get the starting X position for the next MeiPi annotation without registering
-- This is used to pre-calculate X for center gap detection
-- @return (string) X coordinate in pt format (e.g., "123.45pt")
function meipi.get_next_x_pt()
    local x = meipi.calculate_x(0)  -- 0 width just gets the starting position
    return string.format("%.5fpt", x / 65536)
end

--- Output X coordinate for the next MeiPi annotation directly to TeX
-- @param width_sp (string|number) Width in scaled points
-- @param height_sp (string|number) Height in scaled points
function meipi.output_x(width_sp, height_sp)
    local width = tonumber(width_sp) or 0
    local height = tonumber(height_sp) or 0

    local x, _ = meipi.register(width, height)

    -- Convert to pt and output directly
    local x_pt = x / 65536
    tex.sprint(string.format("%.5fpt", x_pt))
end

--- Output Y coordinate for MeiPi annotation directly to TeX
-- @param height_sp (string|number) Height in scaled points
function meipi.output_y(height_sp)
    local height = tonumber(height_sp) or 0
    local y = meipi.calculate_y(height)

    -- Convert to pt and output directly
    local y_pt = y / 65536
    tex.sprint(string.format("%.5fpt", y_pt))
end

--- Output both X and Y coordinates separated by comma
-- @param width_sp (string|number) Width in scaled points
-- @param height_sp (string|number) Height in scaled points
function meipi.output_coordinates(width_sp, height_sp)
    local width = tonumber(width_sp) or 0
    local height = tonumber(height_sp) or 0

    local x, y = meipi.register(width, height)

    -- Convert to pt and output directly
    local x_pt = x / 65536
    local y_pt = y / 65536
    tex.sprint(string.format("%.5fpt,%.5fpt", x_pt, y_pt))
end

-- Register module
package.loaded['guji.luatex-cn-guji-meipi'] = meipi

return meipi
