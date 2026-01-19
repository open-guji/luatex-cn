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
-- render_background.lua - ??????????
-- ============================================================================
-- ???: render_background.lua (? background.lua)
-- ??: ???? - ??? (Stage 3: Render Layer)
--
-- ????? / Module Purpose?
-- ???????????????????:
--   1. draw_background: ???????(?????????????)
--   2. set_font_color: ?????????????
--
-- ??????
--   • ??????? paper_width/height(????),???? inner_width/height
--   • ?? PDF fill ??(rg + re + f),???? stroke(RG + S)??
--   • ??????????(?? insert_before ? p_head ????)
--   • ???????? "rg"(???),???? normalize_rgb ???????
--   • ???????????????????????,????????(???)
--   • ?????? RGB ???(? "blue")??? pdf_literal ????,?????????
--
-- ??????
--   draw_background(p_head, params)
--      +- ??? paper_width/height,?????????
--      +- ???? inner_width/height + outer_shift
--      +- ?? PDF literal: "q 0 w rgb rg x y w h re f Q"
--      +- ?????????(??????)
--
--   set_font_color(p_head, font_rgb_str)
--      +- ?? PDF literal: "rgb rg"(?????)
--
-- ============================================================================

-- Load dependencies
local constants = package.loaded['luatex-cn-vertical-base-constants'] or require('luatex-cn-vertical-base-constants')
local D = constants.D
local utils = package.loaded['luatex-cn-vertical-base-utils'] or require('luatex-cn-vertical-base-utils')

--- ???????
-- @param p_head (node) ??????(????)
-- @param params (table) ???:
--   - bg_rgb_str: ???? RGB ?????
--   - paper_width: ???? (sp, ??)
--   - paper_height: ???? (sp, ??)
--   - margin_left: ??? (sp, ??)
--   - margin_top: ??? (sp, ??)
--   - inner_width: ?????? (sp, ??)
--   - inner_height: ?????? (sp, ??)
--   - outer_shift: ????? (sp, ??)
-- @return (node) ??????
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
    -- Skip background rectangle for full pages (handled by \pagecolor).
    -- Still draw for textboxes, but they should use their own inner dimensions.
    if not is_textbox and p_width > 0 then
        return p_head
    end

    local tx_bp, ty_bp, tw_bp, th_bp

    -- Use inner dimensions for textboxes OR if paper size is not provided/valid
    if not is_textbox and p_width > 0 and p_height > 0 then
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

--- ???????????
-- @param p_head (node) ??????(????)
-- @param font_rgb_str (string) ???? RGB ?????
-- @return (node) ??????
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
-- ????? package.loaded
package.loaded['luatex-cn-vertical-render-background'] = background

-- Return module exports
return background