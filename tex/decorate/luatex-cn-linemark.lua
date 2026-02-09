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

--- Build PDF command for a standard wavy line (smooth sine wave)
-- Uses 4 cubic Bézier curves per period (one per quarter), with control
-- points derived from the parametric derivative of sin(). This ensures:
--   - At peaks (±amplitude): tangent is purely vertical
--   - At center crossings: tangent is diagonal (matching sine slope)
--   - Tangent continuity (C1) at all junctions
local function build_wavy_standard(x_bp, y_start_bp, period_bp, count, amp_bp, rgb, lw_bp)
    local parts = {}
    parts[#parts + 1] = string.format("q %s RG %.4f w", rgb, lw_bp)
    parts[#parts + 1] = string.format("%.4f %.4f m", x_bp, y_start_bp)

    -- Control point offsets derived from sin() parametric derivative:
    -- cx = π*A/6 (horizontal handle at zero crossings)
    -- cy = P/12  (vertical handle, = quarter_period / 3)
    local cx = math.pi * amp_bp / 6
    local cy = period_bp / 12
    local h = period_bp / 4 -- quarter period
    local A = amp_bp

    for i = 1, count do
        local y0 = y_start_bp - (i - 1) * period_bp
        -- Q1: center → right peak
        parts[#parts + 1] = string.format("%.4f %.4f %.4f %.4f %.4f %.4f c",
            x_bp + cx, y0 - cy,
            x_bp + A, y0 - h + cy,
            x_bp + A, y0 - h)
        -- Q2: right peak → center
        parts[#parts + 1] = string.format("%.4f %.4f %.4f %.4f %.4f %.4f c",
            x_bp + A, y0 - h - cy,
            x_bp + cx, y0 - 2 * h + cy,
            x_bp, y0 - 2 * h)
        -- Q3: center → left peak
        parts[#parts + 1] = string.format("%.4f %.4f %.4f %.4f %.4f %.4f c",
            x_bp - cx, y0 - 2 * h - cy,
            x_bp - A, y0 - 3 * h + cy,
            x_bp - A, y0 - 3 * h)
        -- Q4: left peak → center
        parts[#parts + 1] = string.format("%.4f %.4f %.4f %.4f %.4f %.4f c",
            x_bp - A, y0 - 3 * h - cy,
            x_bp - cx, y0 - 4 * h + cy,
            x_bp, y0 - 4 * h)
    end

    parts[#parts + 1] = "S Q"
    return table.concat(parts, " ")
end

--- Build PDF command for a cursive wavy line (expressive, calligraphic feel)
-- Asymmetric Bézier curves with hand-drawn character.
local function build_wavy_cursive(x_bp, y_start_bp, period_bp, count, amp_bp, rgb, lw_bp)
    local parts = {}
    parts[#parts + 1] = string.format("q %s RG %.4f w", rgb, lw_bp)
    parts[#parts + 1] = string.format("%.4f %.4f m", x_bp, y_start_bp)

    local ctrl = amp_bp * 0.55

    for i = 1, count do
        local y0 = y_start_bp - (i - 1) * period_bp
        -- First half: bulge right with expressive control points
        parts[#parts + 1] = string.format("%.4f %.4f %.4f %.4f %.4f %.4f c",
            x_bp + ctrl, y0 - period_bp * 0.07,
            x_bp + amp_bp, y0 - period_bp * 0.25,
            x_bp + amp_bp * 0.5, y0 - period_bp * 0.5)
        -- Second half: bulge left
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

            -- Style and amplitude fraction (shared across segments)
            local style = reg.style or "standard"
            local style_amps = amplitude_presets[style] or amplitude_presets.standard
            local amp_fraction = style_amps[reg.amplitude] or style_amps.medium

            -- Base linewidth in sp (absolute value, scaled per-segment)
            local base_lw_sp = reg.linewidth
            if type(base_lw_sp) == "table" then
                base_lw_sp = constants.resolve_dimen(base_lw_sp, base_font_size)
            end
            base_lw_sp = base_lw_sp or tex.sp("0.8pt")

            -- Draw each segment
            for _, seg in ipairs(segments) do
                local first = seg[1]
                local last = seg[#seg]
                local col = first.col

                -- Effective font size: use entry's font_size when available,
                -- so all parameters automatically scale with the environment
                -- (jiazhu ≈ half, sidenote ≈ smaller, normal text = base)
                local efs = (first.font_size and first.font_size > 0)
                    and first.font_size or base_font_size
                local scale = efs / base_font_size

                -- All em-based parameters computed from effective font size
                local seg_offset = constants.resolve_dimen(reg.offset, efs) or
                    math.floor(efs * 0.6 + 0.5)
                local seg_lw_bp = base_lw_sp * scale * sp_to_bp
                local seg_amp_bp = math.floor(efs * amp_fraction + 0.5) * sp_to_bp

                -- Gap: center line on the character within the grid cell
                -- For normal text (efs ≈ grid_height), centering is zero
                -- For smaller text (jiazhu/sidenote), adds centering offset
                local centering = math.max(0, ctx.grid_height - efs)
                local padding = math.floor(efs * 0.15 + 0.5)
                local seg_gap = centering + 2 * padding

                -- Calculate X position
                -- Line is always on the LEFT side of the character (smaller x in RTL layout)
                local sub_col = first.sub_col or 0
                local effective_offset = seg_offset
                local char_center_x

                if first.x_center_sp then
                    -- Pre-calculated character center (jiazhu sub-column, sidenote, etc.)
                    -- This already accounts for textflow alignment (outward/inward/left/right)
                    -- Reduce offset in tight environments (jiazhu/sidenote have smaller margins)
                    char_center_x = first.x_center_sp
                    effective_offset = math.floor(seg_offset * 0.8 + 0.5)
                else
                    -- Normal full-width cell: center of cell
                    local _, cell_left_x = text_position.calculate_rtl_position(col, ctx.p_total_cols,
                        ctx.grid_width, ctx.half_thickness, ctx.shift_x, ctx.banxin_width, ctx.interval)
                    local col_w = text_position.get_column_width(col, ctx.grid_width, ctx.banxin_width or 0, ctx.interval or 0)
                    char_center_x = cell_left_x + col_w / 2
                end
                -- Line is at: character center - offset (to the left in physical coordinates)
                local line_x_sp = char_center_x - effective_offset
                local line_x_bp = line_x_sp * sp_to_bp

                -- Calculate Y range
                -- Top of first character cell
                local y_top_sp = -(first.row) * ctx.grid_height - (ctx.shift_y or 0)
                -- Bottom of last character cell
                local y_bot_sp = -(last.row + 1) * ctx.grid_height - (ctx.shift_y or 0)

                -- Apply gap (shrink inward from edges, centered on character)
                -- In PDF coords: Y+ is up, y_top > y_bot
                -- Shrink top down: y_top - gap/2; Shrink bottom up: y_bot + gap/2
                local y_start_bp = (y_top_sp - seg_gap / 2) * sp_to_bp
                local y_end_bp = (y_bot_sp + seg_gap / 2) * sp_to_bp

                local pdf_cmd
                if reg.type == "wavy" then
                    -- Wave must fit exactly within y_start..y_end (same range as straight line)
                    local total_length_bp = y_start_bp - y_end_bp
                    local ppc = periods_per_char[style] or 3
                    local wave_count = #seg * ppc
                    local period_bp = total_length_bp / wave_count
                    local build_wave = style == "cursive" and build_wavy_cursive or build_wavy_standard
                    pdf_cmd = build_wave(line_x_bp, y_start_bp, period_bp, wave_count, seg_amp_bp, rgb, seg_lw_bp)
                else
                    -- straight line
                    pdf_cmd = build_straight_line(line_x_bp, y_start_bp, y_end_bp, rgb, seg_lw_bp)
                end

                -- Insert PDF literal at the beginning of the page (bottom layer, under text)
                local lit = utils.create_pdf_literal(pdf_cmd)
                p_head = D.insert_before(p_head, p_head, lit)

                dbg.log(string.format("gid=%d type=%s col=%d rows=%.1f-%.1f sub_col=%s efs=%d x=%.2fbp y=%.2f..%.2fbp",
                    gid, reg.type, col, first.row, last.row, tostring(sub_col), efs, line_x_bp, y_start_bp, y_end_bp))
            end
        end
    end

    return p_head
end

package.loaded['decorate.luatex-cn-linemark'] = linemark

return linemark
