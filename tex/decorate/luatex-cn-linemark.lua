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
-- luatex-cn-linemark.lua - PDF Line Mark Renderer
-- ============================================================================
-- Renders straight lines (专名号) and wavy lines (书名号) using PDF graphics
-- commands, independent of font glyphs.
--
-- This module:
--   1. Collects character positions with line_mark_id from layout_map
--   2. Groups them by group_id and splits into continuous segments
--   3. Draws PDF lines (straight or wavy) for each segment
-- ============================================================================

local constants = package.loaded['core.luatex-cn-constants'] or
    require('core.luatex-cn-constants')
local utils = package.loaded['util.luatex-cn-utils'] or
    require('util.luatex-cn-utils')
local text_position = package.loaded['core.luatex-cn-render-position'] or
    require('luatex-cn-render-position')
local debug = package.loaded['debug.luatex-cn-debug'] or
    require('debug.luatex-cn-debug')

local dbg = debug.get_debugger('linemark')
local D = node.direct
local sp_to_bp = utils.sp_to_bp

local linemark = {}

-- Color name to RGB mapping (same as decorate module)
local color_map = {
    red = "1 0 0",
    blue = "0 0 1",
    green = "0 1 0",
    black = "0 0 0",
    purple = "0.5 0 0.5",
    orange = "1 0.5 0"
}

-- Wavy amplitude presets (as fraction of 1em), keyed by style
local amplitude_presets = {
    -- Standard: tight wave like U+FE34 ︴, multiple periods per character
    standard = {
        small  = 0.020,
        medium = 0.030,
        large  = 0.045,
    },
    -- Cursive: wide expressive wave, 1 period per character
    cursive = {
        small  = 0.06,
        medium = 0.10,
        large  = 0.15,
    },
}

-- Number of full sine-wave periods per character height
local periods_per_char = {
    standard = 3,
    cursive  = 1,
}

--- Resolve color string to RGB triplet
-- @param color_str (string) Color name or "r g b" triplet
-- @return (string) "r g b" format
local function resolve_color(color_str)
    if not color_str or color_str == "" then return "0 0 0" end
    return color_map[color_str] or color_str
end

--- Build PDF command string for a straight line segment
-- @param x_bp (number) X position in big points
-- @param y_start_bp (number) Y start (top) in big points
-- @param y_end_bp (number) Y end (bottom) in big points
-- @param rgb (string) Color "r g b"
-- @param lw_bp (number) Line width in big points
-- @return (string) PDF literal command
local function build_straight_line(x_bp, y_start_bp, y_end_bp, rgb, lw_bp)
    return string.format("q %s RG %.4f w %.4f %.4f m %.4f %.4f l S Q",
        rgb, lw_bp, x_bp, y_start_bp, x_bp, y_end_bp)
end

--- Build PDF command string for a wavy line segment
-- @param x_bp (number) Base X position (center of wave)
-- @param y_start_bp (number) Y start (top) in big points
-- @param period_bp (number) One wave period height in big points
-- @param count (number) Number of complete periods
-- @param amp_bp (number) Wave amplitude in big points
-- @param rgb (string) Color "r g b"
-- @param lw_bp (number) Line width in big points
-- @return (string) PDF literal command
local function build_wavy_line(x_bp, y_start_bp, period_bp, count, amp_bp, rgb, lw_bp)
    local parts = {}
    parts[#parts + 1] = string.format("q %s RG %.4f w", rgb, lw_bp)
    parts[#parts + 1] = string.format("%.4f %.4f m", x_bp, y_start_bp)

    local ctrl = amp_bp * 0.55 -- control point offset for smooth sine approximation

    for i = 1, count do
        local y0 = y_start_bp - (i - 1) * period_bp
        -- First half-period: bulge to the right (+x direction)
        parts[#parts + 1] = string.format("%.4f %.4f %.4f %.4f %.4f %.4f c",
            x_bp + ctrl, y0 - period_bp * 0.07,
            x_bp + amp_bp, y0 - period_bp * 0.25,
            x_bp + amp_bp * 0.5, y0 - period_bp * 0.5)
        -- Second half-period: bulge to the left (-x direction)
        parts[#parts + 1] = string.format("%.4f %.4f %.4f %.4f %.4f %.4f c",
            x_bp, y0 - period_bp * 0.75,
            x_bp - ctrl, y0 - period_bp * 0.93,
            x_bp, y0 - period_bp)
    end

    parts[#parts + 1] = "S Q"
    return table.concat(parts, " ")
end

--- Render line marks for a single page
-- Called after all glyph nodes on the page have been positioned.
--
-- @param p_head (node) Page head (direct node)
-- @param entries (table) Array of {group_id, col, row, font_size}
-- @param ctx (table) Render context (grid_width, grid_height, p_total_cols, shift_x, shift_y, etc.)
-- @return (node) Updated p_head
function linemark.render_line_marks(p_head, entries, ctx)
    if not entries or #entries == 0 then return p_head end

    -- Group entries by group_id
    local groups = {}
    for _, e in ipairs(entries) do
        local gid = e.group_id
        if not groups[gid] then groups[gid] = {} end
        groups[gid][#groups[gid] + 1] = e
    end

    -- Process each group
    for gid, group_entries in pairs(groups) do
        local reg = _G.line_mark_registry and _G.line_mark_registry[gid]
        if reg then
            -- Sort by col, sub_col, then row
            table.sort(group_entries, function(a, b)
                if a.col ~= b.col then return a.col < b.col end
                local a_sc = a.sub_col or 0
                local b_sc = b.sub_col or 0
                if a_sc ~= b_sc then return a_sc < b_sc end
                return a.row < b.row
            end)

            -- Split into continuous segments (same col + sub_col, consecutive rows)
            local segments = {}
            local cur_seg = { group_entries[1] }

            for i = 2, #group_entries do
                local prev = group_entries[i - 1]
                local curr = group_entries[i]
                local same_col = curr.col == prev.col
                local same_sub = (curr.sub_col or 0) == (prev.sub_col or 0)
                if same_col and same_sub and (curr.row - prev.row) <= 1.01 then
                    cur_seg[#cur_seg + 1] = curr
                else
                    segments[#segments + 1] = cur_seg
                    cur_seg = { curr }
                end
            end
            segments[#segments + 1] = cur_seg

            -- Resolve styling from registry
            local rgb = resolve_color(reg.color)
            local base_font_size = ctx.grid_height or 655360

            -- Resolve offset (distance from character center to line)
            local offset_sp = constants.resolve_dimen(reg.offset, base_font_size) or
                math.floor(base_font_size * 0.6 + 0.5)

            -- Resolve line width
            local lw_sp = reg.linewidth
            if type(lw_sp) == "table" then
                lw_sp = constants.resolve_dimen(lw_sp, base_font_size)
            end
            lw_sp = lw_sp or tex.sp("0.4pt")
            local lw_bp = lw_sp * sp_to_bp

            -- Resolve amplitude for wavy lines (depends on style)
            local style = reg.style or "standard"
            local style_amps = amplitude_presets[style] or amplitude_presets.standard
            local amp_fraction = style_amps[reg.amplitude] or style_amps.medium
            local amp_sp = math.floor(base_font_size * amp_fraction + 0.5)
            local amp_bp = amp_sp * sp_to_bp

            -- Gap between different groups: font_size * 3/10
            local gap_sp = math.floor(base_font_size * 0.3 + 0.5)
            local gap_half_bp = (gap_sp / 2) * sp_to_bp

            -- Draw each segment
            for _, seg in ipairs(segments) do
                local first = seg[1]
                local last = seg[#seg]
                local col = first.col

                -- Font size scaling for smaller text (jiazhu, sidenote)
                local font_scale = 1.0
                if first.font_size and first.font_size > 0 and base_font_size > 0 then
                    font_scale = first.font_size / base_font_size
                end
                local seg_lw_bp = lw_bp
                local seg_amp_bp = amp_bp
                local seg_offset = offset_sp
                local seg_gap = gap_sp
                if font_scale < 0.9 then
                    seg_lw_bp = lw_bp * font_scale
                    seg_amp_bp = amp_bp * font_scale
                    seg_offset = offset_sp * font_scale
                    seg_gap = gap_sp * font_scale
                end

                -- Calculate X position (left side of character in vertical typesetting)
                -- In RTL layout, "left of text" = smaller x values (toward next column)
                local sub_col = first.sub_col or 0
                local effective_offset = seg_offset
                local cell_center_x

                if first.x_center_sp then
                    -- Pre-calculated center (e.g., sidenote with non-standard positioning)
                    cell_center_x = first.x_center_sp
                elseif sub_col > 0 then
                    -- Jiazhu sub-column: use half-width positioning
                    local rtl_col = ctx.p_total_cols - 1 - col
                    local cell_left_x = rtl_col * ctx.grid_width + (ctx.half_thickness or 0) + (ctx.shift_x or 0)
                    local half_w = ctx.grid_width / 2
                    if sub_col == 1 then
                        -- Right sub-column (physically right half of cell)
                        cell_center_x = cell_left_x + half_w + half_w / 2
                    else
                        -- Left sub-column (physically left half of cell)
                        cell_center_x = cell_left_x + half_w / 2
                    end
                    -- Scale offset for smaller text
                    effective_offset = seg_offset / 2
                else
                    local rtl_col = ctx.p_total_cols - 1 - col
                    local cell_left_x = rtl_col * ctx.grid_width + (ctx.half_thickness or 0) + (ctx.shift_x or 0)
                    cell_center_x = cell_left_x + ctx.grid_width / 2
                end
                -- Line is at: cell center - offset (to the left of text in physical coordinates)
                local line_x_sp = cell_center_x - effective_offset
                local line_x_bp = line_x_sp * sp_to_bp

                -- Calculate Y range
                -- Top of first character cell
                local y_top_sp = -(first.row) * ctx.grid_height - (ctx.shift_y or 0)
                -- Bottom of last character cell
                local y_bot_sp = -(last.row + 1) * ctx.grid_height - (ctx.shift_y or 0)

                -- Apply gap (shrink from edges)
                local y_start_bp = (y_top_sp + seg_gap / 2) * sp_to_bp
                local y_end_bp = (y_bot_sp - seg_gap / 2) * sp_to_bp

                local pdf_cmd
                if reg.type == "wavy" then
                    local char_height_bp = ctx.grid_height * sp_to_bp
                    local ppc = periods_per_char[style] or 3
                    local period_bp = char_height_bp / ppc
                    local wave_count = #seg * ppc
                    pdf_cmd = build_wavy_line(line_x_bp, y_start_bp, period_bp, wave_count, seg_amp_bp, rgb, seg_lw_bp)
                else
                    -- straight line
                    pdf_cmd = build_straight_line(line_x_bp, y_start_bp, y_end_bp, rgb, seg_lw_bp)
                end

                -- Insert PDF literal at the beginning of the page (bottom layer, under text)
                local lit = utils.create_pdf_literal(pdf_cmd)
                p_head = D.insert_before(p_head, p_head, lit)

                dbg.log(string.format("gid=%d type=%s col=%d rows=%.1f-%.1f sub_col=%s x=%.2fbp y=%.2f..%.2fbp",
                    gid, reg.type, col, first.row, last.row, tostring(sub_col), line_x_bp, y_start_bp, y_end_bp))
            end
        end
    end

    return p_head
end

package.loaded['decorate.luatex-cn-linemark'] = linemark

return linemark
