-- cn_vertical_background.lua
-- Chinese vertical typesetting module for LuaTeX - Background and Color Drawing
--
-- This module is part of the cn_vertical package.
-- For documentation, see cn_vertical/README.md
--
-- Module: background
-- Purpose: Draw background color and set font color
-- Dependencies: constants, utils
-- Exports: draw_background, set_font_color
-- Version: 0.3.0
-- Date: 2026-01-12

-- Load dependencies
local constants = package.loaded['constants'] or require('constants')
local D = constants.D
local utils = package.loaded['utils'] or require('utils')

--- Draw background color rectangle
-- @param p_head (node) Direct node head
-- @param params (table) Parameters:
--   - bg_rgb_str: normalized RGB color string
--   - paper_width: width of paper in sp (optional)
--   - paper_height: height of paper in sp (optional)
--   - margin_left: left margin in sp (optional)
--   - margin_top: top margin in sp (optional)
--   - inner_width: width of inner content in sp (fallback)
--   - inner_height: height of inner content in sp (fallback)
--   - outer_shift: outer border shift in sp (fallback)
-- @return (node) Updated head
local function draw_background(p_head, params)
    local sp_to_bp = utils.sp_to_bp
    local bg_rgb_str = params.bg_rgb_str

    if not bg_rgb_str then
        return p_head
    end

    local p_width = params.paper_width or 0
    local p_height = params.paper_height or 0
    local m_left = params.margin_left or 0
    local m_top = params.margin_top or 0

    local tx_bp, ty_bp, tw_bp, th_bp

    if p_width > 0 and p_height > 0 then
        -- Background covers the entire page
        -- The origin (0,0) in our box is at (margin_left, paper_height - margin_top)
        tx_bp = -m_left * sp_to_bp
        ty_bp = m_top * sp_to_bp
        tw_bp = p_width * sp_to_bp
        th_bp = -p_height * sp_to_bp
    else
        -- Fallback to box-sized background if paper size is not provided
        local inner_width = params.inner_width or 0
        local inner_height = params.inner_height or 0
        local outer_shift = params.outer_shift or 0
        tx_bp = 0
        ty_bp = 0
        tw_bp = (inner_width + outer_shift * 2) * sp_to_bp
        th_bp = -(inner_height + outer_shift * 2) * sp_to_bp
    end

    -- Draw filled rectangle for background
    local literal = string.format("q 0 w %s rg %.4f %.4f %.4f %.4f re f Q",
        bg_rgb_str, tx_bp, ty_bp, tw_bp, th_bp)
    local n_node = node.new("whatsit", "pdf_literal")
    n_node.data = literal
    n_node.mode = 0
    p_head = D.insert_before(p_head, p_head, D.todirect(n_node))

    return p_head
end

--- Set font color for subsequent text
-- @param p_head (node) Direct node head
-- @param font_rgb_str (string) Normalized RGB color string
-- @return (node) Updated head
local function set_font_color(p_head, font_rgb_str)
    if not font_rgb_str then
        return p_head
    end

    -- Set fill color for text (uses lowercase 'rg' for fill color)
    local literal = string.format("%s rg", font_rgb_str)
    local n_node = node.new("whatsit", "pdf_literal")
    n_node.data = literal
    n_node.mode = 0
    p_head = D.insert_before(p_head, p_head, D.todirect(n_node))

    return p_head
end

-- Create module table
local background = {
    draw_background = draw_background,
    set_font_color = set_font_color,
}

-- Register module in package.loaded for require() compatibility
package.loaded['background'] = background

-- Return module exports
return background
