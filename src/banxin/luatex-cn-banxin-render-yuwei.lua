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
-- render_yuwei.lua - ??(Fish Tail)????
-- ============================================================================
-- ???: render_yuwei.lua (? yuwei.lua)
-- ??: ???? - ??? (Stage 3: Render Layer)
--
-- ????? / Module Purpose?
-- ?????????????"??"????:
--   1. ??????(black):???????
--   2. ??????(white/hollow):??????
--   3. ????????:????(???)?????(???)
--   4. ??????????????
--
-- ??????
--   ??????????????"??"??:
--
--      ? ??(direction=1 ???)
--     / \
--    /   \        ?? = width × 0.6
--   /     \
--   ---V---       ??
--    width
--
-- ??????
--   • ???:y ????,x ????
--   • ????:?????? RGB ???(? "0 0 0")
--   • direction=1 ?????(????),direction=-1 ?????
--
-- ??????
--   draw_yuwei(params)
--      +- ??????
--      +- ?? style ???????
--      +- ??????? PDF ??
--      +- ?? PDF literal ???
--
-- ============================================================================

-- Load dependencies
local constants = package.loaded['vertical.base_constants'] or require('vertical.luatex-cn-vertical-base-constants')
local utils = package.loaded['vertical.base_utils'] or require('vertical.luatex-cn-vertical-base-utils')

-- Conversion factor from scaled points to PDF big points
local sp_to_bp = utils.sp_to_bp

--- ????(??)????
-- ????????? V ????????
--
-- ???? (direction=1, ??? - ?????):
--
--       ?----- width -----?
--   +-------------------------+  ?
--   ¦                         ¦  ¦ edge_height (????)
--   ¦                         ¦  ¦
--   +---?               ?---+  ?
--         ?           ?        ?
--           ?       ?          ¦ (edge_height - notch_height)
--             ?   ?            ¦
--               V              ? ??????(????? notch_height)
--
-- @param params (table) ???:
--   - x (number) ??? X ?? (sp)
--   - y (number) ??? Y ?? (sp)
--   - width (number) ?? (sp)
--   - edge_height (number) ???? (sp)
--   - notch_height (number) ???? V ????? (direction=1) ????? V ????? (direction=-1)
--   - direction (number) 1 = ??? (?????), -1 = ??? (?????)
--   - style (string) "black" (????) ? "white"/"hollow" (????)
--   - color_str (string) RGB ????? (?? "0 0 0")
--   - line_width (number) ??,??????? (?? 0.8bp)
--   - extra_line (bool) ??? V ????????????
--   - line_gap (number) ???????????? (?? 4pt)
--   - border_thickness (number) ??????? (?? 0.4pt)
-- @return (string) PDF literal ?????
local function draw_yuwei(params)
    local x = params.x or 0
    local y = params.y or 0
    local width = params.width or (18 * 65536)  -- Default 18pt
    local edge_height = params.edge_height or params.height or (width * 0.5)
    local notch_height = params.notch_height or (edge_height * 1.5)  -- V-tip extends beyond edge_height
    local style = params.style or "black"
    local direction = params.direction or 1
    local color_str = params.color_str or "0 0 0"
    
    if _G.vertical and _G.vertical.debug and _G.vertical.debug.verbose_log then
        utils.debug_log(string.format("[yuwei] Drawing yuwei with style=%s, direction=%d, color=%s", tostring(style), direction, color_str))
    end
    local line_width = params.line_width or 0.8
    local extra_line = params.extra_line or false
    local line_gap = params.line_gap or (65536 * 4)  -- 4pt default
    local border_thickness = params.border_thickness or (65536 * 0.4)  -- 0.4pt default
    
    -- Calculate dimensions in bp
    local w_bp = width * sp_to_bp
    local edge_h_bp = edge_height * sp_to_bp
    local notch_h_bp = notch_height * sp_to_bp
    local half_w = w_bp / 2
    
    -- Position in bp (x,y is left-top corner)
    local x_bp = x * sp_to_bp
    local y_bp = y * sp_to_bp
    
    local path
    if style == "black" then
        if direction == 1 then
            -- ???: V-notch cuts into shape from bottom
            -- Path: top-left ? top-right ? bottom-right ? V-tip ? bottom-left ? close
            path = string.format(
                "q %s rg " ..
                "%.4f %.4f m " ..           -- Top-left
                "%.4f %.4f l " ..           -- Top-right
                "%.4f %.4f l " ..           -- Bottom-right (at edge_height)
                "%.4f %.4f l " ..           -- V-tip (at notch_height from top)
                "%.4f %.4f l " ..           -- Bottom-left (at edge_height)
                "h f Q",
                color_str,
                x_bp, y_bp,                                 -- Top-left
                x_bp + w_bp, y_bp,                          -- Top-right
                x_bp + w_bp, y_bp - edge_h_bp,              -- Bottom-right
                x_bp + half_w, y_bp - notch_h_bp,           -- V-tip
                x_bp, y_bp - edge_h_bp                      -- Bottom-left
            )
        else
            -- ???: V-notch cuts into shape from top (mirrored)
            -- Path: bottom-left ? bottom-right ? top-right ? V-tip ? top-left ? close
            path = string.format(
                "q %s rg " ..
                "%.4f %.4f m " ..           -- Bottom-left
                "%.4f %.4f l " ..           -- Bottom-right
                "%.4f %.4f l " ..           -- Top-right (at edge_height from bottom)
                "%.4f %.4f l " ..           -- V-tip (at notch_height from bottom)
                "%.4f %.4f l " ..           -- Top-left (at edge_height from bottom)
                "h f Q",
                color_str,
                x_bp, y_bp - notch_h_bp,                    -- Bottom-left
                x_bp + w_bp, y_bp - notch_h_bp,             -- Bottom-right
                x_bp + w_bp, y_bp - notch_h_bp + edge_h_bp, -- Top-right
                x_bp + half_w, y_bp,                        -- V-tip (at top)
                x_bp, y_bp - notch_h_bp + edge_h_bp         -- Top-left
            )
        end
    else
        -- Hollow/white fish tail - stroke the outline
        if direction == 1 then
            path = string.format(
                "q %s RG %.2f w " ..
                "%.4f %.4f m %.4f %.4f l %.4f %.4f l %.4f %.4f l %.4f %.4f l h S Q",
                color_str, line_width,
                x_bp, y_bp,
                x_bp + w_bp, y_bp,
                x_bp + w_bp, y_bp - edge_h_bp,
                x_bp + half_w, y_bp - notch_h_bp,
                x_bp, y_bp - edge_h_bp
            )
        else
            path = string.format(
                "q %s RG %.2f w " ..
                "%.4f %.4f m %.4f %.4f l %.4f %.4f l %.4f %.4f l %.4f %.4f l h S Q",
                color_str, line_width,
                x_bp, y_bp - notch_h_bp,
                x_bp + w_bp, y_bp - notch_h_bp,
                x_bp + w_bp, y_bp - notch_h_bp + edge_h_bp,
                x_bp + half_w, y_bp,
                x_bp, y_bp - notch_h_bp + edge_h_bp
            )
        end
    end
    
    -- Draw extra V-shaped line if requested (parallels the yuwei notch)
    if extra_line then
        local gap_bp = line_gap * sp_to_bp
        local thickness_bp = border_thickness * sp_to_bp
        local extra_line_path
        
        if direction == 1 then
            -- ???: V-line below the yuwei's V-notch
            -- The V-line starts at edge_height + gap, and its tip is at notch_height + gap
            local v_left_y = y_bp - edge_h_bp - gap_bp
            local v_tip_y = y_bp - notch_h_bp - gap_bp
            local v_right_y = y_bp - edge_h_bp - gap_bp
            extra_line_path = string.format(
                "q %.2f w %s RG %.4f %.4f m %.4f %.4f l %.4f %.4f l S Q",
                thickness_bp, color_str,
                x_bp, v_left_y,                    -- Left point
                x_bp + half_w, v_tip_y,            -- V-tip (center bottom)
                x_bp + w_bp, v_right_y             -- Right point
            )
        else
            -- ???: V-line above the yuwei's V-notch (inverted)
            local v_left_y = y_bp - notch_h_bp + edge_h_bp + gap_bp
            local v_tip_y = y_bp + gap_bp
            local v_right_y = y_bp - notch_h_bp + edge_h_bp + gap_bp
            extra_line_path = string.format(
                "q %.2f w %s RG %.4f %.4f m %.4f %.4f l %.4f %.4f l S Q",
                thickness_bp, color_str,
                x_bp, v_left_y,                    -- Left point
                x_bp + half_w, v_tip_y,            -- V-tip (center top)
                x_bp + w_bp, v_right_y             -- Right point
            )
        end
        path = path .. " " .. extra_line_path
    end
    
    return path
end

--- ??????? PDF literal ??
-- @param params (table) ? draw_yuwei ??
-- @return (node) pdf_literal whatsit ?? (????)
local function create_yuwei_node(params)
    local D = constants.D
    local literal_str = draw_yuwei(params)
    
    local whatsit_id = node.id("whatsit")
    local pdf_literal_id = node.subtype("pdf_literal")
    local nn = D.new(whatsit_id, pdf_literal_id)
    D.setfield(nn, "data", literal_str)
    D.setfield(nn, "mode", 0)  -- mode 0: origin at current position
    
    return nn
end

-- Create module table
local yuwei = {
    draw_yuwei = draw_yuwei,
    create_yuwei_node = create_yuwei_node,
}

-- Register module in package.loaded for require() compatibility
-- ????? package.loaded
package.loaded['banxin.render_yuwei'] = yuwei
package.loaded['render_yuwei'] = yuwei

-- Return module exports
return yuwei