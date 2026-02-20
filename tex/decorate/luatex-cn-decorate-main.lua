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
-- decorate_main.lua - Decorate Plugin for Vertical Engine
-- ============================================================================
-- File: luatex-cn-decorate-main.lua
-- Layer: Extension Layer - Text Decoration (circles, dots, etc.)
--
-- Module Purpose:
--   This module provides text decoration functionality (e.g., red circles,
--   emphasis dots) for the vertical typesetting engine.
--
--   1. Registry management for decoration definitions
--   2. Creating decoration marker nodes
--   3. Rendering decorations at glyph positions
--
-- ============================================================================

local constants = package.loaded['core.luatex-cn-constants'] or
    require('core.luatex-cn-constants')
local utils = package.loaded['util.luatex-cn-utils'] or
    require('util.luatex-cn-utils')
local text_position = package.loaded['core.luatex-cn-render-position'] or
    require('luatex-cn-render-position')
local debug = package.loaded['debug.luatex-cn-debug'] or
    require('debug.luatex-cn-debug')

local dbg = debug.get_debugger('decorate')

local D = node.direct

-- Initialize global registry
_G.decorate_registry = _G.decorate_registry or {}

local decorate = {}

--- Register a decoration (delegates to constants.register_decorate)
-- @param char_str (string) The decoration character (e.g., "。", "●")
-- @param xoff_str (string) X offset (e.g., "-0.6em", "5pt")
-- @param yoff_str (string) Y offset
-- @param size_str (string) Font size (nil = inherit from text)
-- @param color_str (string) Color (e.g., "red", "0.8 0 0")
-- @param font_id (number) Font ID (nil = use current font)
-- @param scale (number) Scale multiplier (default 1.0)
-- @return (number) Registry ID for this decoration
function decorate.register(char_str, xoff_str, yoff_str, size_str, color_str, font_id, scale)
    return constants.register_decorate(char_str, xoff_str, yoff_str, size_str, color_str, font_id, scale)
end

--- Get a decoration entry from the registry
-- @param reg_id (number) Registry ID
-- @return (table|nil) Decoration entry or nil if not found
function decorate.get(reg_id)
    return _G.decorate_registry and _G.decorate_registry[reg_id]
end

--- Clear the decoration registry
function decorate.clear_registry()
    _G.decorate_registry = {}
end

-- ============================================================================
-- Rendering Functions (moved from render-page.lua)
-- ============================================================================

-- Color name to RGB mapping
local color_map = {
    red = "1 0 0",
    blue = "0 0 1",
    green = "0 1 0",
    black = "0 0 0",
    purple = "0.5 0 0.5",
    orange = "1 0.5 0"
}

--- Resolve font size for decoration (uses PDF scaling, no new fonts)
-- @param curr (node) Current node
-- @param reg (table) Registry entry
-- @param params (table) Render parameters
-- @param ctx (table) Render context
-- @return font_id, base_size, effective_scale
local function resolve_decorate_font(curr, reg, params, ctx)
    local attr_font_id = constants.ATTR_DECORATE_FONT and D.get_attribute(curr, constants.ATTR_DECORATE_FONT)
    local base_font_id = (attr_font_id and attr_font_id > 0) and attr_font_id or reg.font_id or ctx.last_font_id or
        params.font_id or font.current()

    local base_f_data = font.getfont(base_font_id)
    local base_size = base_f_data and base_f_data.size or 655360

    local scale = reg.scale or 1.0
    local font_size_sp = constants.resolve_dimen(reg.font_size, base_size)

    local target_size = font_size_sp
    if not target_size or target_size == 0 then
        target_size = base_size * scale
    else
        target_size = target_size * scale
    end

    local effective_scale = target_size / base_size
    return base_font_id, base_size, effective_scale
end

--- Calculate decoration position
-- @param pos (table) Position {col, row}
-- @param reg (table) Registry entry
-- @param ctx (table) Render context
-- @param base_size (number) Base font size
-- @param font_id (number) Font ID
-- @param char (number) Character code
-- @param scale (number) Scale factor
-- @param glyph_h (number) Glyph height
-- @param glyph_d (number) Glyph depth
-- @return x_bp, y_bp (in big points)
local function calculate_decorate_position(pos, reg, ctx, base_size, font_id, char, scale, glyph_h, glyph_d)
    local xoffset_sp = constants.resolve_dimen(reg.xoffset, base_size) or 0
    local yoffset_sp = constants.resolve_dimen(reg.yoffset, base_size) or 0

    -- Fetch unscaled metrics
    local f_data = font.getfont(font_id)
    local glyph_w = 0
    if f_data and f_data.characters and f_data.characters[char] then
        glyph_w = (f_data.characters[char].width or 0)
    end

    -- Horizontal Centering: align glyph's visual center to cell center
    local v_center = text_position.get_visual_center(char, font_id) or (glyph_w / 2)
    local scaled_v_center = v_center * scale
    local center_offset = (ctx.grid_width / 2) - scaled_v_center

    -- Position calculation (use previous row as decorations follow characters)
    local target_row = math.max(0, pos.row - 1)
    local rtl_col = ctx.p_total_cols - 1 - pos.col
    local base_x = rtl_col * ctx.grid_width + ctx.half_thickness + ctx.shift_x
    local base_y = -target_row * ctx.grid_height - ctx.shift_y

    -- Vertical Centering: Place the glyph's ink center at cell center
    local cell_center_y = base_y - ctx.grid_height / 2
    local scaled_ink_center = ((glyph_h - glyph_d) / 2) * scale
    local target_baseline_y = cell_center_y - scaled_ink_center

    -- Apply user offsets: Positive xshift moves LEFT (flow direction), positive yshift moves DOWN
    local final_x = base_x + center_offset - xoffset_sp
    local final_y = target_baseline_y - yoffset_sp

    return final_x * utils.sp_to_bp, final_y * utils.sp_to_bp
end

--- Handle decoration node rendering
-- @param curr (node) Current node (marker)
-- @param p_head (node) Page head
-- @param pos (table) Position {col, row}
-- @param params (table) Render parameters
-- @param ctx (table) Render context
-- @param reg_id (number) Registry ID
-- @return p_head (updated)
function decorate.handle_node(curr, p_head, pos, params, ctx, reg_id)
    local reg = _G.decorate_registry and _G.decorate_registry[reg_id]
    if not reg then return p_head end

    -- Get style attributes from style_registry if available (Phase 2)
    local style_registry = package.loaded['util.luatex-cn-style-registry']
    local style_id = style_registry and D.get_attribute(curr, constants.ATTR_STYLE_REG_ID)
    local style_font_color = style_id and style_registry.get_font_color(style_id)
    local style_font_size = style_id and style_registry.get_font_size(style_id)

    -- Augment reg with style registry values (priority: style_registry > reg)
    local effective_reg = {}
    for k, v in pairs(reg) do
        effective_reg[k] = v
    end
    if style_font_color then
        effective_reg.color = style_font_color
    end
    if style_font_size then
        effective_reg.font_size = style_font_size
    end

    -- 1. Resolve font and scale factor
    local font_id, base_size, scale = resolve_decorate_font(curr, effective_reg, params, ctx)
    local char = reg.char

    -- 2. Create glyph (unscaled in TeX stream)
    local g = D.new(constants.GLYPH)
    D.setfield(g, "char", char)
    D.setfield(g, "font", font_id)
    D.setfield(g, "lang", 0)

    -- Retrieve unscaled dimensions to set correct kerning after scaling
    local f_data = font.getfont(font_id)
    local w, h, d = 0, 0, 0
    if f_data and f_data.characters and f_data.characters[char] then
        local c_data = f_data.characters[char]
        w, h, d = c_data.width or 0, c_data.height or 0, c_data.depth or 0
    end
    D.setfield(g, "width", w)
    D.setfield(g, "height", h)
    D.setfield(g, "depth", d)

    -- 3. Calculate position (BP)
    local x_bp, y_bp = calculate_decorate_position(pos, effective_reg, ctx, base_size, font_id, char, scale, h, d)

    -- 4. Render with scaled PDF matrix
    D.setfield(g, "xoffset", 0)
    D.setfield(g, "yoffset", 0)

    local draw_rgb = (effective_reg.color and color_map[effective_reg.color]) or effective_reg.color or "0 0 0"

    -- Build scaled matrix: [scale 0 0 scale x y]
    local color_part = string.format("%s %s", utils.create_color_literal(draw_rgb, false),
        utils.create_color_literal(draw_rgb, true))
    local matrix_part = string.format("%.4f 0 0 %.4f %.4f %.4f cm", scale, scale, x_bp, y_bp)
    local n_start = utils.create_pdf_literal("q " .. color_part .. " " .. matrix_part)
    local n_end = utils.create_pdf_literal(utils.create_graphics_state_end())

    p_head = D.insert_before(p_head, curr, n_start)
    D.insert_after(p_head, n_start, g)

    -- Kern back to avoid shifting TeX's cursor
    local k = D.new(constants.KERN)
    D.setfield(k, "kern", -w)
    D.insert_after(p_head, g, k)
    D.insert_after(p_head, k, n_end)

    dbg.log(string.format("char=%d [c:%d, r:%d] scale=%.2f pos_x=%.4f pos_y=%.4f",
        char, pos.col, pos.row, scale, x_bp, y_bp))

    return p_head
end

package.loaded['decorate.luatex-cn-decorate-main'] = decorate

return decorate
