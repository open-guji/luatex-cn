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
-- render_position.lua - ????????
-- ============================================================================
-- ???: render_position.lua (? text_position.lua)
-- ??: ???? - ??? (Stage 3: Render Layer)
--
-- ????? / Module Purpose?
-- ?????????????????????,?????????????:
--   1. position_glyph: ????????????,??????
--   2. create_vertical_text: ???????(????????)
--   3. position_glyph_in_grid: ??????(?? position_glyph)
--   4. calc_grid_position: ?????(?????,?? render.lua)
--
-- ??????
--   • ????????????? height ? depth,????????
--   • xoffset/yoffset ? LuaTeX ? glyph ????,block ?????
--   • ????????? kern(-width),???? TLT ???????
--   • Kern ? subtype=1(?? kern),??? render.lua ??
--   • vertical_align ?? top/center/bottom ????
--
-- ??????
--   ????:
--      +- calc_grid_position(col, row, dims, params)
--      ¦     ? ?? (x_offset, y_offset),?? render.lua ????
--      +- position_glyph(glyph, x, y, params)
--      ¦     ? ?? glyph.xoffset/yoffset,?? (glyph, kern)
--      +- create_vertical_text(text, params)
--      ¦     ? ????????(????)
--      +- position_glyph_in_grid(glyph, col, row, params)
--            ? ???????
--
--
-- ============================================================================

-- Load dependencies
local constants = package.loaded['luatex-cn-vertical-base-constants'] or require('luatex-cn-vertical-base-constants')
local D = constants.D

--- ??????????????
-- ?????????????????
-- ??? xoffset/yoffset ???? kern ???????
--
-- @param glyph_direct (node) ?????????????
-- @param x (number) ? SCALED POINTS ???? X ??(??????)
-- @param y (number) ? SCALED POINTS ???? Y ??(??????,????)
-- @param params (table) ???:
--   - cell_width (number) ?????,??????
--   - cell_height (number) ?????,??????
--   - h_align (string) ????: "left", "center", "right" (??: "center")
--   - v_align (string) ????: "top", "center", "bottom" (??: "center")
-- @return (node, node) ?????? kern ??(????????)
local function position_glyph(glyph_direct, x, y, params)
    params = params or {}
    local cell_width = params.cell_width or 0
    local cell_height = params.cell_height or 0
    local h_align = params.h_align or "center"
    local v_align = params.v_align or "center"

    -- Get glyph dimensions
    local g_width = params.g_width or D.getfield(glyph_direct, "width") or 0
    local g_height = params.g_height or D.getfield(glyph_direct, "height") or 0
    local g_depth = params.g_depth or D.getfield(glyph_direct, "depth") or 0

    -- If width is 0, try to guess or use a fallback for centering
    if g_width <= 0 then
        local f_data = font.getfont(D.getfield(glyph_direct, "font"))
        if f_data and f_data.size then
            g_width = f_data.size -- Assume square for CJK if unknown
        end
    end

    -- Calculate horizontal offset based on alignment
    local x_offset
    if h_align == "left" then
        x_offset = x
    elseif h_align == "right" then
        x_offset = x + cell_width - g_width
    else -- center
        x_offset = x + (cell_width - g_width) / 2
    end

    -- Calculate vertical offset based on alignment
    local char_total_height = g_height + g_depth
    local y_offset
    if v_align == "top" then
        y_offset = y - g_height
    elseif v_align == "bottom" then
        y_offset = y - cell_height + g_depth
    else -- center
        y_offset = y - (cell_height + char_total_height) / 2 + g_depth
    end

    -- Apply offsets
    D.setfield(glyph_direct, "xoffset", x_offset)
    D.setfield(glyph_direct, "yoffset", y_offset)

    -- --- Trace Logging ---
    if _G.vertical and _G.vertical.debug and _G.vertical.debug.verbose_log then
        local u = package.loaded['luatex-cn-vertical-base-utils'] or require('luatex-cn-vertical-base-utils')
        u.debug_log(string.format("[GlyphPos] char=%d x=%.2f cw=%.2f gw=%.2f -> xoff=%.2f yoff=%.2f",
            D.getfield(glyph_direct, "char"), x/(65536), cell_width/(65536), g_width/(65536), x_offset/(65536), y_offset/(65536)))
    end

    -- Create protected negative kern (subtype 1 = explicit kern, won't be zeroed)
    local kern = D.new(constants.KERN)
    D.setfield(kern, "subtype", 1)
    D.setfield(kern, "kern", -D.getfield(glyph_direct, "width"))

    -- Link glyph to kern
    D.setlink(glyph_direct, kern)

    return glyph_direct, kern
end

--- ??????????
-- ??????????????????
-- ??????,????????????
--
-- @param text (string) ???? UTF-8 ???
-- @param params (table) ???:
--   - x (number) ????? X ?? (sp)
--   - y_top (number) ????? Y ?? (sp, ????)
--   - width (number) ????????? (sp)
--   - height (number) ???????? (sp)
--   - num_cells (number) ??:????? (??: ???)
--   - v_align (string) ???????????: "top", "center", "bottom"
--   - h_align (string) ???????: "left", "center", "right"
--   - font_id (number) ??:?? ID (??: ????)
--   - shift_y (number) ??:??? Y ??? (sp)
-- @return (node) ????????(??????),??????? nil
local function create_vertical_text(text, params)
    if not text or text == "" then
        return nil
    end

    -- Parse UTF-8 characters
    local chars = {}
    for char in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        table.insert(chars, char)
    end

    local num_chars = #chars
    if num_chars == 0 then
        return nil
    end

    local x = params.x or 0
    local y_top = params.y_top or 0
    local width = params.width or 0
    local height = params.height or 0
    local num_cells = params.num_cells or num_chars
    local v_align = params.v_align or "center"
    local h_align = params.h_align or "center"
    local font_id = params.font_id or font.current()
    local shift_y = params.shift_y or 0
    
    local font_scale_factor = 1.0
    local base_font_data = font.getfont(font_id) -- Save original font data for character lookups

    -- Handle font size if provided
    if params.font_size then
        local fs = constants.to_dimen(params.font_size)
        if fs and fs > 0 then
            local current_font_data = font.getfont(font_id)
            if current_font_data then
                font_scale_factor = fs / current_font_data.size
                local new_font_data = {}
                for k,v in pairs(current_font_data) do new_font_data[k] = v end
                new_font_data.size = fs
                font_id = font.define(new_font_data)
            end
        end
    elseif params.font_scale then
        font_scale_factor = params.font_scale
        local current_font_data = font.getfont(font_id)
        if current_font_data then
            local new_font_data = {}
            for k,v in pairs(current_font_data) do new_font_data[k] = v end
            new_font_data.size = math.floor(new_font_data.size * params.font_scale + 0.5)
            font_id = font.define(new_font_data)
        end
    end

    -- Calculate cell height
    local cell_height = height / num_cells

    local u = package.loaded['luatex-cn-vertical-base-utils'] or require('luatex-cn-vertical-base-utils')

    local head = nil
    local tail = nil

    for i, char in ipairs(chars) do
        -- Create glyph node
        local glyph = node.new(node.id("glyph"))
        glyph.char = utf8.codepoint(char)
        glyph.font = font_id
        glyph.lang = 0

        local glyph_direct = D.todirect(glyph)

        -- CRITICAL: Fetch glyph dimensions from base font data (before scaling)
        -- Then apply font_scale_factor to get actual dimensions
        local cp = utf8.codepoint(char)

        -- Default dimensions if not in font (fallback to square em)
        local gw = (base_font_data and base_font_data.size or (65536 * 10)) * font_scale_factor
        local gh = gw * 0.8
        local gd = gw * 0.2

        if base_font_data and base_font_data.characters and base_font_data.characters[cp] then
            local char_data = base_font_data.characters[cp]
            -- Base font character dimensions need to be scaled by font_scale_factor
            gw = (char_data.width or gw) * font_scale_factor
            gh = (char_data.height or gh) * font_scale_factor
            gd = (char_data.depth or gd) * font_scale_factor
            D.setfield(glyph_direct, "width", math.floor(gw + 0.5))
            D.setfield(glyph_direct, "height", math.floor(gh + 0.5))
            D.setfield(glyph_direct, "depth", math.floor(gd + 0.5))
        end

        -- Calculate cell position (0-indexed row)
        local row = i - 1
        local cell_y = y_top - row * cell_height - shift_y

        -- Position the glyph
        local _, kern = position_glyph(glyph_direct, x, cell_y, {
            cell_width = width,
            cell_height = cell_height,
            h_align = h_align,
            v_align = v_align,
            g_width = math.floor(gw + 0.5),
            g_height = math.floor(gh + 0.5),
            g_depth = math.floor(gd + 0.5),
        })

        -- Build the chain
        if head == nil then
            head = glyph_direct
            tail = kern
        else
            D.setlink(tail, glyph_direct)
            tail = kern
        end

        -- --- DEBUG: Draw blue box around each character ---
        if _G.vertical and _G.vertical.debug and _G.vertical.debug.enabled and _G.vertical.debug.show_grid then
            local u = package.loaded['luatex-cn-vertical-base-utils'] or require('luatex-cn-vertical-base-utils')
            if u and u.draw_debug_rect then
                -- Add debug box before the glyph so it's behind the text
                head = u.draw_debug_rect(head, glyph_direct, x, cell_y, width, -cell_height, "0 0 1 RG")
            end
        end
    end

    return head
end

--- ??????????(????????)
-- ??????????,?????????????
--
-- @param glyph_direct (node) ?????????????
-- @param col (number) ???(? 0 ??,RTL ????????)
-- @param row (number) ???(? 0 ??)
-- @param params (table) ???:
--   - grid_width (number) ????????? (sp)
--   - grid_height (number) ????????? (sp)
--   - total_cols (number) ???(?? RTL ??)
--   - shift_x (number) ??/??? X ??? (sp)
--   - shift_y (number) ??/??? Y ??? (sp)
--   - v_align (string) ????: "top", "center", "bottom"
--   - half_thickness (number) ??????? (sp)
-- @return (node, node) ?????? kern ??
local function position_glyph_in_grid(glyph_direct, col, row, params)
    local grid_width = params.grid_width or 0
    local grid_height = params.grid_height or 0
    local total_cols = params.total_cols or 1
    local shift_x = params.shift_x or 0
    local shift_y = params.shift_y or 0
    local v_align = params.v_align or "center"
    local half_thickness = params.half_thickness or 0

    -- Calculate RTL column position
    local rtl_col = total_cols - 1 - col

    -- Calculate cell position
    local cell_x = rtl_col * grid_width + half_thickness + shift_x
    local cell_y = -row * grid_height - shift_y

    return position_glyph(glyph_direct, cell_x, cell_y, {
        cell_width = grid_width,
        cell_height = grid_height,
        h_align = "center",
        v_align = v_align,
    })
end

--- ????????(???,?????)
-- ? render.lua ??,???????,??????????
--
-- @param col (number) ???(? 0 ??)
-- @param row (number) ???(? 0 ??)
-- @param glyph_dims (table) ????: width, height, depth
-- @param params (table) ???:
--   - grid_width (number) ????????? (sp)
--   - grid_height (number) ????????? (sp)
--   - total_cols (number) ???(?? RTL ??)
--   - shift_x (number) ??/??? X ??? (sp)
--   - shift_y (number) ??/??? Y ??? (sp)
--   - v_align (string) ????: "top", "center", "bottom"
--   - half_thickness (number) ??????? (sp)
-- @return (number, number) ??? x_offset, y_offset
local function calc_grid_position(col, row, glyph_dims, params)
    local grid_width = params.grid_width or 0
    local grid_height = params.grid_height or 0
    local total_cols = params.total_cols or 1
    local shift_x = params.shift_x or 0
    local shift_y = params.shift_y or 0
    local v_align = params.v_align or "center"
    local h_align = params.h_align or "center"
    local half_thickness = params.half_thickness or 0

    local w = glyph_dims.width or 0
    local h = glyph_dims.height or 0
    local d = glyph_dims.depth or 0

    -- Calculate RTL column position
    local rtl_col = total_cols - 1 - col
    local sub_col = params.sub_col or 0

    -- Calculate X offset based on horizontal alignment
    local x_offset
    if sub_col > 0 then
        -- Jiazhu (dual-column note) logic
        local sub_width = grid_width / 2
        local inner_padding = sub_width * 0.05 -- 5% internal padding
        local jiazhu_align = params.jiazhu_align or "outward"

        -- Determine alignment for each sub-column based on jiazhu_align setting
        -- sub_col == 1: Right sub-column (??, displayed on right side in RTL)
        -- sub_col == 2: Left sub-column (??, displayed on left side in RTL)
        local col_align
        if jiazhu_align == "outward" then
            -- Default: right col right-aligned, left col left-aligned (????)
            col_align = (sub_col == 1) and "right" or "left"
        elseif jiazhu_align == "inward" then
            -- Opposite: right col left-aligned, left col right-aligned (????)
            col_align = (sub_col == 1) and "left" or "right"
        elseif jiazhu_align == "center" then
            col_align = "center"
        elseif jiazhu_align == "left" then
            col_align = "left"
        elseif jiazhu_align == "right" then
            col_align = "right"
        else
            -- Fallback to outward
            col_align = (sub_col == 1) and "right" or "left"
        end

        -- Calculate base x position for the sub-column
        local sub_base_x = rtl_col * grid_width + half_thickness + shift_x
        if sub_col == 1 then
            sub_base_x = sub_base_x + sub_width  -- Right half
        end

        -- Apply alignment within the sub-column
        if col_align == "right" then
            x_offset = sub_base_x + (sub_width - w) - inner_padding
        elseif col_align == "left" then
            x_offset = sub_base_x + inner_padding
        else -- center
            x_offset = sub_base_x + (sub_width - w) / 2
        end
    elseif h_align == "left" then
        x_offset = rtl_col * grid_width + half_thickness + shift_x
    elseif h_align == "right" then
        x_offset = rtl_col * grid_width + (grid_width - w) + half_thickness + shift_x
    else -- center
        x_offset = rtl_col * grid_width + (grid_width - w) / 2 + half_thickness + shift_x
    end

    -- Calculate Y offset based on vertical alignment
    local y_offset
    if v_align == "top" then
        y_offset = -row * grid_height - h - shift_y
    elseif v_align == "center" then
        local char_total_height = h + d
        y_offset = -row * grid_height - (grid_height + char_total_height) / 2 + d - shift_y
    else -- bottom
        y_offset = -row * grid_height - grid_height + d - shift_y
    end

    return x_offset, y_offset
end

-- Create module table
local text_position = {
    position_glyph = position_glyph,
    create_vertical_text = create_vertical_text,
    position_glyph_in_grid = position_glyph_in_grid,
    calc_grid_position = calc_grid_position,
}

-- Register module in package.loaded for require() compatibility
-- ????? package.loaded
package.loaded['luatex-cn-vertical-render-position'] = text_position

-- Return module exports
return text_position
