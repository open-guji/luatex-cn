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
-- render_border.lua - ??????
-- ============================================================================
-- ???: render_border.lua (? border.lua)
-- ??: ???? - ??? (Stage 3: Render Layer)
--
-- ????? / Module Purpose?
-- ????????????????(????? banxin.lua ????):
--   1. draw_column_borders: ????????(?????)
--   2. draw_outer_border: ?????????????
--
-- ??????
--   • ???????(?? banxin_cols ????)
--   • ?? PDF rectangle ??(re + S)??????
--   • ?????? linewidth (w) ??
--   • ???? RGB ??(0.0-1.0,?? utils.normalize_rgb ???)
--
-- ??????
--   draw_column_borders(p_head, params)
--      +- ?????(0 ? total_cols-1)
--      +- ?? banxin_cols ???
--      +- ?? RTL ???(rtl_col = total_cols - 1 - col)
--      +- ?? PDF literal: "q w RG x y w h re S Q"
--      +- ?????????(?????)
--
--   draw_outer_border(p_head, params)
--      +- ????????????????
--
-- ============================================================================

-- Load dependencies
local constants = package.loaded['luatex-cn-vertical-base-constants'] or require('luatex-cn-vertical-base-constants')
local D = constants.D
local utils = package.loaded['luatex-cn-vertical-base-utils'] or require('luatex-cn-vertical-base-utils')

--- ?????(?????,?????)
-- ????? banxin.draw_banxin_column ????
-- @param p_head (node) ??????(????)
-- @param params (table) ???:
--   - total_cols: ???????
--   - grid_width: ????? (sp)
--   - grid_height: ????? (sp)
--   - line_limit: ???????
--   - border_thickness: ???? (sp)
--   - b_padding_top: ????? (sp)
--   - b_padding_bottom: ????? (sp)
--   - shift_x: ???? (sp)
--   - outer_shift: ????? (sp)
--   - border_rgb_str: ???? RGB ?????
--   - banxin_cols: ??,?????????(???)
-- @return (node) ??????
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
    local outer_shift = params.outer_shift
    local border_rgb_str = params.border_rgb_str
    local banxin_cols = params.banxin_cols or {}  -- Set of column indices to skip

    local b_thickness_bp = border_thickness * sp_to_bp
    local half_thickness = math.floor(border_thickness / 2)

    for col = 0, total_cols - 1 do
        -- Skip banxin columns (they are drawn separately by banxin module)
        if not banxin_cols[col] then
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
        end
    end

    return p_head
end

--- ??????????????
-- @param p_head (node) ??????(????)
-- @param params (table) ???:
--   - inner_width: ?????? (sp)
--   - inner_height: ?????? (sp)
--   - outer_border_thickness: ????? (sp)
--   - outer_border_sep: ?????? (sp)
--   - border_rgb_str: ???? RGB ?????
-- @return (node) ??????
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
-- ????? package.loaded
package.loaded['luatex-cn-vertical-render-border'] = border

-- Return module exports
return border