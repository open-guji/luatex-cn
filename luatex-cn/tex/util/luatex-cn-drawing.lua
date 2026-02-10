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
-- luatex-cn-drawing.lua - PDF Drawing Utilities
-- ============================================================================
-- Generic PDF drawing functions for shapes (rectangles, octagons, circles)
-- These are low-level utilities used by content rendering modules.
-- ============================================================================

local utils = package.loaded['util.luatex-cn-utils'] or
    require('util.luatex-cn-utils')

--- Draw a rectangular frame (stroke only)
-- @param p_head (node) Node list head
-- @param params (table) Parameters:
--   - x: Top-left X coordinate (sp)
--   - y: Top-left Y coordinate (sp, negative = down)
--   - width: Width (sp)
--   - height: Height (sp)
--   - line_width: Line width (sp)
--   - color_str: RGB color string (default "0 0 0")
-- @return (node) Updated head
local function draw_rect_frame(p_head, params)
    local sp_to_bp = utils.sp_to_bp
    local x_bp = params.x * sp_to_bp
    local y_bp = params.y * sp_to_bp
    local w_bp = params.width * sp_to_bp
    local h_bp = params.height * sp_to_bp
    local lw_bp = params.line_width * sp_to_bp
    local color_str = params.color_str or "0 0 0"

    local literal = string.format([[
q %s RG %.2f w
%.4f %.4f %.4f %.4f re S Q]],
        color_str, lw_bp,
        x_bp, y_bp - h_bp, w_bp, h_bp
    )

    return utils.insert_pdf_literal(p_head, literal)
end

--- Draw a filled octagon (background)
-- @param p_head (node) Node list head
-- @param params (table) Parameters:
--   - x: Top-left X coordinate (sp)
--   - y: Top-left Y coordinate (sp, negative = down)
--   - width: Width (sp)
--   - height: Height (sp)
--   - color_str: RGB fill color string (default "0.5 0.5 0.5")
-- @return (node) Updated head
local function draw_octagon_fill(p_head, params)
    local sp_to_bp = utils.sp_to_bp
    local x_bp = params.x * sp_to_bp
    local y_bp = params.y * sp_to_bp
    local w_bp = params.width * sp_to_bp
    local h_bp = params.height * sp_to_bp
    local color_str = params.color_str or "0.5 0.5 0.5"

    -- Corner cut size: 20% of smaller dimension
    local corner = math.min(w_bp, h_bp) * 0.2

    local literal = string.format([[
q %s rg
%.4f %.4f m
%.4f %.4f l %.4f %.4f l %.4f %.4f l %.4f %.4f l
%.4f %.4f l %.4f %.4f l %.4f %.4f l h f Q]],
        color_str,
        x_bp + corner, y_bp,
        x_bp + w_bp - corner, y_bp,
        x_bp + w_bp, y_bp - corner,
        x_bp + w_bp, y_bp - h_bp + corner,
        x_bp + w_bp - corner, y_bp - h_bp,
        x_bp + corner, y_bp - h_bp,
        x_bp, y_bp - h_bp + corner,
        x_bp, y_bp - corner
    )

    return utils.insert_pdf_literal(p_head, literal)
end

--- Draw an octagon frame (stroke only)
-- @param p_head (node) Node list head
-- @param params (table) Parameters:
--   - x: Top-left X coordinate (sp)
--   - y: Top-left Y coordinate (sp, negative = down)
--   - width: Width (sp)
--   - height: Height (sp)
--   - line_width: Line width (sp)
--   - color_str: RGB color string (default "0 0 0")
-- @return (node) Updated head
local function draw_octagon_frame(p_head, params)
    local sp_to_bp = utils.sp_to_bp
    local x_bp = params.x * sp_to_bp
    local y_bp = params.y * sp_to_bp
    local w_bp = params.width * sp_to_bp
    local h_bp = params.height * sp_to_bp
    local lw_bp = params.line_width * sp_to_bp
    local color_str = params.color_str or "0 0 0"

    -- Corner cut size: 20% of smaller dimension
    local corner = math.min(w_bp, h_bp) * 0.2

    local literal = string.format([[
q %s RG %.2f w
%.4f %.4f m
%.4f %.4f l %.4f %.4f l %.4f %.4f l %.4f %.4f l
%.4f %.4f l %.4f %.4f l %.4f %.4f l h S Q]],
        color_str, lw_bp,
        x_bp + corner, y_bp,
        x_bp + w_bp - corner, y_bp,
        x_bp + w_bp, y_bp - corner,
        x_bp + w_bp, y_bp - h_bp + corner,
        x_bp + w_bp - corner, y_bp - h_bp,
        x_bp + corner, y_bp - h_bp,
        x_bp, y_bp - h_bp + corner,
        x_bp, y_bp - corner
    )

    return utils.insert_pdf_literal(p_head, literal)
end

--- Draw a filled circle (background)
-- Uses Bezier curve approximation for circle
-- @param p_head (node) Node list head
-- @param params (table) Parameters:
--   - cx: Center X coordinate (sp)
--   - cy: Center Y coordinate (sp)
--   - radius: Radius (sp)
--   - color_str: RGB fill color string (default "0.5 0.5 0.5")
-- @return (node) Updated head
local function draw_circle_fill(p_head, params)
    local sp_to_bp = utils.sp_to_bp
    local cx_bp = params.cx * sp_to_bp
    local cy_bp = params.cy * sp_to_bp
    local r_bp = params.radius * sp_to_bp
    local color_str = params.color_str or "0.5 0.5 0.5"

    -- Bezier approximation constant: 4/3 * (sqrt(2) - 1)
    local k = 0.5523
    local kappa = r_bp * k

    local literal = string.format([[
q %s rg
%.4f %.4f m
%.4f %.4f %.4f %.4f %.4f %.4f c
%.4f %.4f %.4f %.4f %.4f %.4f c
%.4f %.4f %.4f %.4f %.4f %.4f c
%.4f %.4f %.4f %.4f %.4f %.4f c f Q]],
        color_str,
        cx_bp + r_bp, cy_bp,
        cx_bp + r_bp, cy_bp + kappa, cx_bp + kappa, cy_bp + r_bp, cx_bp, cy_bp + r_bp,
        cx_bp - kappa, cy_bp + r_bp, cx_bp - r_bp, cy_bp + kappa, cx_bp - r_bp, cy_bp,
        cx_bp - r_bp, cy_bp - kappa, cx_bp - kappa, cy_bp - r_bp, cx_bp, cy_bp - r_bp,
        cx_bp + kappa, cy_bp - r_bp, cx_bp + r_bp, cy_bp - kappa, cx_bp + r_bp, cy_bp
    )

    return utils.insert_pdf_literal(p_head, literal)
end

--- Draw a circle frame (stroke only)
-- Uses Bezier curve approximation for circle
-- @param p_head (node) Node list head
-- @param params (table) Parameters:
--   - cx: Center X coordinate (sp)
--   - cy: Center Y coordinate (sp)
--   - radius: Radius (sp)
--   - line_width: Line width (sp)
--   - color_str: RGB color string (default "0 0 0")
-- @return (node) Updated head
local function draw_circle_frame(p_head, params)
    local sp_to_bp = utils.sp_to_bp
    local cx_bp = params.cx * sp_to_bp
    local cy_bp = params.cy * sp_to_bp
    local r_bp = params.radius * sp_to_bp
    local lw_bp = params.line_width * sp_to_bp
    local color_str = params.color_str or "0 0 0"

    -- Bezier approximation constant: 4/3 * (sqrt(2) - 1)
    local k = 0.5523
    local kappa = r_bp * k

    local literal = string.format([[
q %s RG %.2f w
%.4f %.4f m
%.4f %.4f %.4f %.4f %.4f %.4f c
%.4f %.4f %.4f %.4f %.4f %.4f c
%.4f %.4f %.4f %.4f %.4f %.4f c
%.4f %.4f %.4f %.4f %.4f %.4f c S Q]],
        color_str, lw_bp,
        cx_bp + r_bp, cy_bp,
        cx_bp + r_bp, cy_bp + kappa, cx_bp + kappa, cy_bp + r_bp, cx_bp, cy_bp + r_bp,
        cx_bp - kappa, cy_bp + r_bp, cx_bp - r_bp, cy_bp + kappa, cx_bp - r_bp, cy_bp,
        cx_bp - r_bp, cy_bp - kappa, cx_bp - kappa, cy_bp - r_bp, cx_bp, cy_bp - r_bp,
        cx_bp + kappa, cy_bp - r_bp, cx_bp + r_bp, cy_bp - kappa, cx_bp + r_bp, cy_bp
    )

    return utils.insert_pdf_literal(p_head, literal)
end

-- Module exports
local drawing = {
    draw_rect_frame = draw_rect_frame,
    draw_octagon_fill = draw_octagon_fill,
    draw_octagon_frame = draw_octagon_frame,
    draw_circle_fill = draw_circle_fill,
    draw_circle_frame = draw_circle_frame,
}

-- Register module
package.loaded['util.luatex-cn-drawing'] = drawing

return drawing
