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
-- File: luatex-cn-decorate.lua
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

--- clreq 5.3.1「标点符号上不加着重号」：基字是否该跳过着重标记。
-- 由 \EmphasisMark 在 skip-punct 开启时逐字调用（判定的是**基字**，
-- 与 decorate 的装饰字符无关，故不并入 register）。分类走共享标点表，
-- 与横排 hori-linemark 的 is_punct 同一口径。
-- @param s (string) 基字（UTF-8，通常一个字符）
-- @return (boolean) true 表示是标点，不应加着重号
function decorate.is_punct_char(s)
    if type(s) ~= "string" or s == "" then return false end
    local ok, cp = pcall(utf8.codepoint, s, 1)
    if not ok or not cp then return false end
    local punct_table = require("shared.luatex-cn-punct-table")
    return punct_table.class_of(cp) ~= nil
end

-- ============================================================================
-- Rendering Functions (moved from render-page.lua)
-- ============================================================================

local color_map = constants.color_map

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
    local xshift_sp = constants.resolve_dimen(reg.xshift, base_size) or 0
    local yshift_sp = constants.resolve_dimen(reg.yshift, base_size) or 0

    -- Fetch unscaled metrics
    local f_data = font.getfont(font_id)
    local glyph_w = 0
    if f_data and f_data.characters and f_data.characters[char] then
        glyph_w = (f_data.characters[char].width or 0)
    end

    -- Get actual column width (may differ for banxin columns)
    local col_width = text_position.get_column_width(pos.col, ctx.col_geom)

    -- Position calculation (use previous row as decorations follow characters)
    local _, base_x = text_position.calculate_rtl_position(pos.col, ctx.p_total_cols, ctx.col_geom,
        ctx.half_thickness, ctx.shift_x)

    -- TextFlow sub-column support: when decoration is inside jiazhu (sub_col > 0),
    -- use half-column width and offset base_x to the correct sub-column.
    local sub_col = pos.sub_col or 0
    local effective_col_width = col_width
    if sub_col > 0 then
        local sub_width = col_width / 2
        effective_col_width = sub_width
        if sub_col == 1 then
            base_x = base_x + sub_width  -- right sub-column
        end
        -- sub_col == 2: left sub-column stays at base_x
    end

    -- Horizontal Centering: align glyph's visual center to cell center
    local v_center = text_position.get_visual_center(char, font_id) or (glyph_w / 2)
    local scaled_v_center = v_center * scale
    local center_offset = (effective_col_width / 2) - scaled_v_center

    local dec_cell_h = pos.cell_height or ctx.grid_height or 0
    local target_y_sp = math.max(0, pos.y_sp - dec_cell_h)
    local band_y_off = pos.band_y_offset_sp or 0
    local base_y = -target_y_sp - band_y_off - ctx.shift_y

    -- Vertical Centering: Place the glyph's ink center at cell center
    local cell_center_y = base_y - dec_cell_h / 2
    local scaled_ink_center = ((glyph_h - glyph_d) / 2) * scale
    local target_baseline_y = cell_center_y - scaled_ink_center

    -- Apply user offsets: Positive xshift moves LEFT (flow direction), positive yshift moves DOWN
    local final_x = base_x + center_offset - xshift_sp
    local final_y = target_baseline_y - yshift_sp

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

    dbg.log(string.format("char=%d [c:%d, y_sp:%.0f] scale=%.2f pos_x=%.4f pos_y=%.4f",
        char, pos.col, pos.y_sp or 0, scale, x_bp, y_bp))

    return p_head
end

-- ============================================================================
-- Side Text Rendering (左右旁注 - small text on sides of main character)
-- ============================================================================

--- Handle side text decoration rendering
-- Places small characters vertically stacked on left/right sides of the main character.
-- @param curr (node) Current marker node
-- @param p_head (node) Page head
-- @param pos (table) Position from layout_map
-- @param params (table) Render parameters
-- @param ctx (table) Render context
-- @param reg_id (number) Registry ID
-- @return p_head (updated)
function decorate.handle_side_text_node(curr, p_head, pos, params, ctx, reg_id)
    local reg = _G.decorate_registry and _G.decorate_registry[reg_id]
    if not reg or reg.type ~= "side_text" then return p_head end

    local scale = reg.scale or 0.5
    local font_id = reg.font_id or ctx.last_font_id or params.font_id or font.current()
    local f_data = font.getfont(font_id)
    local base_size = f_data and f_data.size or 655360

    local draw_rgb = (reg.color and color_map[reg.color]) or reg.color or "0 0 0"
    local color_part = string.format("%s %s",
        utils.create_color_literal(draw_rgb, false),
        utils.create_color_literal(draw_rgb, true))

    -- Main character cell geometry
    local cell_h = pos.cell_height or ctx.grid_height or base_size
    local col_width = text_position.get_column_width(pos.col, ctx.col_geom)
    local _, base_x = text_position.calculate_rtl_position(
        pos.col, ctx.p_total_cols, ctx.col_geom, ctx.half_thickness, ctx.shift_x)

    -- Main character vertical center (PDF y direction, in sp)
    -- Marker y_sp points to row below main char; subtract cell_h to get main char top
    local target_y_sp = math.max(0, pos.y_sp - cell_h)
    local band_y_off = pos.band_y_offset_sp or 0
    local main_top_y = -target_y_sp - band_y_off - ctx.shift_y
    local main_center_y = main_top_y - cell_h / 2

    -- Offset from default position (positive = inward toward column center)
    local offset_sp = constants.resolve_dimen(reg.offset, base_size) or 0

    -- Column visual center
    local col_center_x = base_x + col_width / 2

    -- Render a glyph at given (x_sp, y_sp) baseline, with given scale and color.
    -- Returns nothing; mutates p_head.
    local function emit_glyph(char_code, x_sp, y_sp, g_scale, rgb_str)
        local gw, gh, gd = 0, 0, 0
        if f_data and f_data.characters and f_data.characters[char_code] then
            local c = f_data.characters[char_code]
            gw = c.width or 0
            gh = c.height or 0
            gd = c.depth or 0
        end

        local g = D.new(constants.GLYPH)
        D.setfield(g, "char", char_code)
        D.setfield(g, "font", font_id)
        D.setfield(g, "lang", 0)
        D.setfield(g, "width", gw)
        D.setfield(g, "height", gh)
        D.setfield(g, "depth", gd)
        D.setfield(g, "xoffset", 0)
        D.setfield(g, "yoffset", 0)

        local cp = string.format("%s %s",
            utils.create_color_literal(rgb_str, false),
            utils.create_color_literal(rgb_str, true))
        local matrix_part = string.format("%.4f 0 0 %.4f %.4f %.4f cm",
            g_scale, g_scale, x_sp * utils.sp_to_bp, y_sp * utils.sp_to_bp)
        local n_start = utils.create_pdf_literal("q " .. cp .. " " .. matrix_part)
        local n_end = utils.create_pdf_literal(utils.create_graphics_state_end())

        p_head = D.insert_before(p_head, curr, n_start)
        D.insert_after(p_head, n_start, g)
        local k = D.new(constants.KERN)
        D.setfield(k, "kern", -gw)
        D.insert_after(p_head, g, k)
        D.insert_after(p_head, k, n_end)

        return gw, gh, gd
    end

    -- Render a vertical column of units on one side. Each unit is
    -- {char=<codepoint>, decorations={...}}. Decorations attach to the unit
    -- (e.g., 板眼 dot on a 工尺 char) and are positioned relative to the
    -- unit's center using deco.xshift/yshift (sign convention identical to
    -- main-text \decorate: xshift>0 visual LEFT, yshift>0 visual DOWN).
    local function render_side_units(units, side)
        if not units or #units == 0 then return end

        local n_units = #units
        local char_step = math.floor(base_size * scale)
        local total_h = n_units * char_step

        -- X target: position side text just outside the main character.
        local main_half = base_size / 2
        local side_half = math.floor(base_size * scale / 2)
        local gap = math.floor(base_size * 0.05)
        local target_x
        if side == "right" then
            target_x = col_center_x + main_half + side_half + gap - offset_sp
        else
            target_x = col_center_x - main_half - side_half - gap + offset_sp
        end

        for i, unit in ipairs(units) do
            local char_code = unit.char

            -- Vertical: stack units centered on main character (i=1 topmost).
            local char_top_y = main_center_y + total_h / 2 - (i - 1) * char_step

            -- Position the gongche/yin char itself
            local gw_u = 0
            if f_data and f_data.characters and f_data.characters[char_code] then
                gw_u = f_data.characters[char_code].width or 0
            end
            local v_center = text_position.get_visual_center(char_code, font_id) or (gw_u / 2)
            local unit_glyph_x = target_x - v_center * scale
            local _, gh, gd = 0, 0, 0
            if f_data and f_data.characters and f_data.characters[char_code] then
                local c = f_data.characters[char_code]
                gh = c.height or 0
                gd = c.depth or 0
            end
            local ink_center_y = ((gh - gd) / 2) * scale
            local unit_glyph_y = char_top_y - char_step / 2 - ink_center_y
            emit_glyph(char_code, unit_glyph_x, unit_glyph_y, scale, draw_rgb)

            -- Per-unit decorations (e.g., \音[板]{尺} -> red beat dot)
            if unit.decorations and #unit.decorations > 0 then
                local unit_center_x = target_x
                local unit_center_y = char_top_y - char_step / 2
                for _, deco in ipairs(unit.decorations) do
                    local d_char = deco.char
                    if d_char and d_char > 0 then
                        -- xshift/yshift may be raw sp, em-tables {value,unit}, or strings;
                        -- resolve against base font size first, then multiply by `scale`
                        -- so 0.45em behaves relative to the gongche char's visual size,
                        -- not the full-size lyric char.
                        local raw_dx = constants.resolve_dimen(deco.xshift, base_size) or 0
                        local raw_dy = constants.resolve_dimen(deco.yshift, base_size) or 0
                        local dx_sp = raw_dx * scale
                        local dy_sp = raw_dy * scale
                        local d_scale = scale * (tonumber(deco.scale) or 1)
                        local dgw, dgh, dgd = 0, 0, 0
                        if f_data and f_data.characters and f_data.characters[d_char] then
                            local c = f_data.characters[d_char]
                            dgw = c.width or 0
                            dgh = c.height or 0
                            dgd = c.depth or 0
                        end
                        local dv_center = text_position.get_visual_center(d_char, font_id) or (dgw / 2)
                        local d_target_x = unit_center_x - dx_sp
                        local d_glyph_x = d_target_x - dv_center * d_scale
                        local d_ink_center = ((dgh - dgd) / 2) * d_scale
                        local d_glyph_y = unit_center_y - dy_sp - d_ink_center
                        local d_rgb = (deco.color and color_map[deco.color]) or deco.color or "0 0 0"
                        emit_glyph(d_char, d_glyph_x, d_glyph_y, d_scale, d_rgb)
                    end
                end
            end
        end
    end

    -- Render a pre-rendered TextBox on one side (kern+shift positioning like floating box)
    local function render_side_box(box_node, side)
        if not box_node then return end

        local box_copy = D.todirect(node.copy_list(box_node))
        local box_w = D.getfield(box_copy, "width") or 0
        local box_h = D.getfield(box_copy, "height") or 0

        -- Horizontal: position box just outside the main character
        local main_half = base_size / 2
        local gap = math.floor(base_size * 0.05)
        local target_x
        if side == "right" then
            target_x = col_center_x + main_half + gap - offset_sp
        else
            target_x = col_center_x - main_half - gap - box_w + offset_sp
        end

        -- Vertical: center box on main character
        -- rel_y is distance from top of content area (positive = down)
        local rel_y = target_y_sp + band_y_off + ctx.shift_y
        local main_center_rel_y = rel_y + cell_h / 2
        local box_top_rel_y = main_center_rel_y - box_h / 2

        -- Compensate for page margins (same as render_floating_box)
        local m_top = (_G.page and _G.page.margin_top) or 0
        local m_left = (_G.page and _G.page.margin_left) or 0
        local final_x = target_x - m_left
        local final_y = box_top_rel_y - m_top

        D.setfield(box_copy, "shift", final_y + box_h)

        local k_pre = D.new(constants.KERN)
        D.setfield(k_pre, "kern", final_x)

        local k_post = D.new(constants.KERN)
        D.setfield(k_post, "kern", -(final_x + box_w))

        local q_push = utils.create_pdf_literal("q")
        local q_pop = utils.create_pdf_literal("Q")

        -- Insert at tail of node list (renders on top, like floating box)
        local tail = D.tail(p_head)
        D.insert_after(p_head, tail, q_push)
        D.insert_after(p_head, q_push, k_pre)
        D.insert_after(p_head, k_pre, box_copy)
        D.insert_after(p_head, box_copy, k_post)
        D.insert_after(p_head, k_post, q_pop)
    end

    -- Dispatch: TextBox (box path) or unit list (char-by-char with optional decorations)
    if reg.right_box then
        render_side_box(reg.right_box, "right")
    elseif reg.right_units then
        render_side_units(reg.right_units, "right")
    end

    if reg.left_box then
        render_side_box(reg.left_box, "left")
    elseif reg.left_units then
        render_side_units(reg.left_units, "left")
    end

    local ru = reg.right_units and #reg.right_units or 0
    local lu = reg.left_units and #reg.left_units or 0
    local rb = reg.right_box and 1 or 0
    local lb = reg.left_box and 1 or 0
    dbg.log(string.format("side_text [c:%d, y_sp:%.0f] scale=%.2f units(r=%d,l=%d) box(r=%d,l=%d)",
        pos.col, pos.y_sp or 0, scale, ru, lu, rb, lb))

    return p_head
end

package.loaded['decorate.luatex-cn-decorate'] = decorate

return decorate
