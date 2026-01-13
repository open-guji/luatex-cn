-- cn_vertical_border.lua
-- Chinese vertical typesetting module for LuaTeX - Border Drawing
--
-- This module is part of the cn_vertical package.
-- For documentation, see cn_vertical/README.md
--
-- Module: border
-- Purpose: Draw column borders, outer borders, and banxin dividers
-- Dependencies: constants, utils, banxin
-- Exports: draw_column_borders, draw_outer_border
-- Version: 0.3.0
-- Date: 2026-01-12

-- Load dependencies
local constants = package.loaded['constants'] or require('constants')
local D = constants.D
local utils = package.loaded['utils'] or require('utils')
local banxin = package.loaded['banxin'] or require('banxin')

--- Check if a column is a banxin column
-- @param col (number) Column index
-- @param interval (number) Column interval
-- @return (boolean) True if this is a banxin column
local function is_banxin_col(col, interval)
    if interval <= 0 then return false end
    return (col % (interval + 1)) == interval
end

--- Draw column borders with optional banxin dividers
-- @param p_head (node) Direct node head
-- @param params (table) Parameters:
--   - total_cols: number of columns to draw
--   - grid_width: width of each column in sp
--   - grid_height: height of each row in sp
--   - line_limit: number of rows per column
--   - border_thickness: thickness of border in sp
--   - b_padding_top: top padding in sp
--   - b_padding_bottom: bottom padding in sp
--   - shift_x: horizontal shift in sp
--   - shift_y: vertical shift in sp (includes outer_shift)
--   - outer_shift: outer border shift in sp
--   - border_rgb_str: normalized RGB color string
--   - n_column: number of columns per interval
--   - banxin_enabled: whether to draw banxin dividers
--   - banxin params: s1_ratio, s2_ratio, s3_ratio, text, font_size
-- @return (node) Updated head
local function draw_column_borders(p_head, params)
    local sp_to_bp = utils.sp_to_bp
    local total_cols = params.total_cols
    local grid_width = params.grid_width
    local grid_height = params.grid_height
    local line_limit = params.line_limit
    local border_thickness = params.border_thickness
    local b_padding_top = params.b_padding_top
    local b_padding_bottom = params.b_padding_bottom
    local shift_x = params.shift_x
    local shift_y = params.shift_y
    local outer_shift = params.outer_shift
    local border_rgb_str = params.border_rgb_str
    local interval = tonumber(params.n_column) or 0
    local banxin_enabled = params.banxin_enabled

    local b_thickness_bp = border_thickness * sp_to_bp
    local half_thickness = math.floor(border_thickness / 2)

    for col = 0, total_cols - 1 do
        local rtl_col = total_cols - 1 - col
        local tx_bp = (rtl_col * grid_width + half_thickness + shift_x) * sp_to_bp
        local ty_bp = -(half_thickness + outer_shift) * sp_to_bp
        local tw_bp = grid_width * sp_to_bp
        local th_bp = -(line_limit * grid_height + b_padding_top + b_padding_bottom) * sp_to_bp

        -- Draw column border
        local literal = string.format("q %.2f w %s RG %.4f %.4f %.4f %.4f re S Q",
            b_thickness_bp, border_rgb_str, tx_bp, ty_bp, tw_bp, th_bp)
        local n_node = node.new("whatsit", "pdf_literal")
        n_node.data = literal
        n_node.mode = 0
        p_head = D.insert_before(p_head, p_head, D.todirect(n_node))

        -- Draw banxin dividers for banxin columns
        if banxin_enabled and is_banxin_col(col, interval) then
            local banxin_x = rtl_col * grid_width + half_thickness + shift_x
            local banxin_y = -(half_thickness + outer_shift)
            local banxin_height = line_limit * grid_height + b_padding_top + b_padding_bottom
            local banxin_params = {
                x = banxin_x,
                y = banxin_y,
                width = grid_width,
                total_height = banxin_height,
                section1_ratio = params.banxin_s1_ratio or 0.28,
                section2_ratio = params.banxin_s2_ratio or 0.56,
                section3_ratio = params.banxin_s3_ratio or 0.16,
                color_str = border_rgb_str,
                border_thickness = border_thickness,
                banxin_text = params.banxin_text or "",
                font_size = grid_height -- Use grid height as base font size
            }
            local banxin_result = banxin.draw_banxin(banxin_params)

            -- Insert line drawing literals
            for _, lit in ipairs(banxin_result.literals) do
                local bn = node.new("whatsit", "pdf_literal")
                bn.data = lit
                bn.mode = 0
                p_head = D.insert_before(p_head, p_head, D.todirect(bn))
            end

            -- Insert text nodes for banxin text
            if banxin_result.text_nodes then
                for _, text_data in ipairs(banxin_result.text_nodes) do
                    -- Create glyph node
                    local glyph = node.new(node.id("glyph"))
                    glyph.char = utf8.codepoint(text_data.char)
                    glyph.font = font.current()
                    glyph.lang = 0

                    -- Create hlist to hold the glyph
                    local hlist = node.new(node.id("hlist"))
                    hlist.head = glyph
                    hlist.width = 0
                    hlist.height = text_data.font_size
                    hlist.depth = 0

                    -- Insert the glyph
                    p_head = D.insert_before(p_head, p_head, D.todirect(hlist))
                end
            end
        end
    end

    return p_head
end

--- Draw outer border around the entire content area
-- @param p_head (node) Direct node head
-- @param params (table) Parameters:
--   - inner_width: width of inner content in sp
--   - inner_height: height of inner content in sp
--   - outer_border_thickness: thickness of outer border in sp
--   - outer_border_sep: separation between inner and outer border in sp
--   - border_rgb_str: normalized RGB color string
-- @return (node) Updated head
local function draw_outer_border(p_head, params)
    local sp_to_bp = utils.sp_to_bp
    local inner_width = params.inner_width
    local inner_height = params.inner_height
    local ob_thickness_val = params.outer_border_thickness
    local ob_sep_val = params.outer_border_sep
    local border_rgb_str = params.border_rgb_str

    local ob_thickness_bp = ob_thickness_val * sp_to_bp

    local tx_bp = (ob_thickness_bp / 2)
    local ty_bp = -(ob_thickness_bp / 2)
    local tw_bp = (inner_width + ob_sep_val * 2 + ob_thickness_val) * sp_to_bp
    local th_bp = -(inner_height + ob_sep_val * 2 + ob_thickness_val) * sp_to_bp

    local literal = string.format("q %.2f w %s RG %.4f %.4f %.4f %.4f re S Q",
        ob_thickness_bp, border_rgb_str, tx_bp, ty_bp, tw_bp, th_bp)
    local n_node = node.new("whatsit", "pdf_literal")
    n_node.data = literal
    n_node.mode = 0
    p_head = D.insert_before(p_head, p_head, D.todirect(n_node))

    return p_head
end

-- Create module table
local border = {
    draw_column_borders = draw_column_borders,
    draw_outer_border = draw_outer_border,
}

-- Register module in package.loaded for require() compatibility
package.loaded['border'] = border

-- Return module exports
return border
