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
-- base_constants.lua - ??????????
-- ============================================================================
-- ???: base_constants.lua (? constants.lua)
-- ??: ??? (Base Layer)
--
-- ????? / Module Purpose?
-- ????????????????,??:
--   1. ???? ID ??(GLYPH?KERN?HLIST?VLIST ?)
--   2. ???????(???????textbox ???)
--   3. TeX ?????? scaled points ????? (to_dimen)
--   4. Node.direct ??????? (D)
--
-- ????? / Terminology?
--   scaled points (sp)  - TeX ????,1pt = 65536sp
--   GLYPH               - ????(glyph node)
--   KERN                - ????(kerning node)
--   HLIST               - ????(horizontal list)
--   VLIST               - ????(vertical list)
--   GLUE                - ??/????(glue)
--   PENALTY             - ????(penalty,????/????)
--   ATTR_INDENT         - ????(indent attribute)
--   ATTR_TEXTBOX_*      - ?????(textbox attributes)
--
-- ??????
--   • ????????????????(vertical.sty ??????)
--   • ?? ID ? TeX ???(\newluatexattribute),Lua ??? luatexbase ??
--   • to_dimen ?????????? "0pt",?? nil ?? 0(???????)
--
-- ????? / Architecture?
--   base_constants.lua (???)
--      +- ???? ? ????????
--      +- to_dimen() ? ? core_main.lua ???? TeX ??
--      +- ATTR_* ?? ? ? flatten/layout/render ????????
--
-- ============================================================================

-- Create module table
local constants = {}

-- Node.direct interface for performance
constants.D = node.direct

-- Global debug configuration
_G.vertical = _G.vertical or {}
_G.vertical.debug = {
    enabled = false,        -- ????????
    show_grid = true,      -- ?????
    show_boxes = true,     -- ????????
    show_banxin = true,    -- ???????
    verbose_log = true     -- ??? .log ???????
}

-- Node type IDs
constants.GLYPH = node.id("glyph")
constants.KERN = node.id("kern")
constants.HLIST = node.id("hlist")
constants.VLIST = node.id("vlist")
constants.WHATSIT = node.id("whatsit")
constants.GLUE = node.id("glue")
constants.PENALTY = node.id("penalty")
constants.LOCAL_PAR = node.id("local_par")

-- Custom attributes for indentation
-- Note: Attributes are registered in vertical.sty via \newluatexattribute
constants.ATTR_INDENT = luatexbase.attributes.cnverticalindent or luatexbase.new_attribute("cnverticalindent")
constants.ATTR_RIGHT_INDENT = luatexbase.attributes.cnverticalrightindent or luatexbase.new_attribute("cnverticalrightindent")
constants.ATTR_TEXTBOX_WIDTH = luatexbase.attributes.cnverticaltextboxwidth or luatexbase.new_attribute("cnverticaltextboxwidth")
constants.ATTR_TEXTBOX_HEIGHT = luatexbase.attributes.cnverticaltextboxheight or luatexbase.new_attribute("cnverticaltextboxheight")
constants.ATTR_TEXTBOX_DISTRIBUTE = luatexbase.attributes.cnverticaltextboxdistribute or luatexbase.new_attribute("cnverticaltextboxdistribute")

-- Block Indentation Attributes
constants.ATTR_BLOCK_ID = luatexbase.attributes.cnverticalblockid or luatexbase.new_attribute("cnverticalblockid")
constants.ATTR_FIRST_INDENT = luatexbase.attributes.cnverticalfirstindent or luatexbase.new_attribute("cnverticalfirstindent")

-- Attributes for Jiazhu (Interlinear Note)
constants.ATTR_JIAZHU = luatexbase.attributes.cnverticaljiazhu or luatexbase.new_attribute("cnverticaljiazhu")
constants.ATTR_JIAZHU_SUB = luatexbase.attributes.cnverticaljiazhusub or luatexbase.new_attribute("cnverticaljiazhusub")

-- Constants for Side Pizhu
constants.SIDENOTE_USER_ID = 202601
constants.FLOATING_TEXTBOX_USER_ID = 202602

--- ? TeX ???????? scaled points (sp)
-- @param dim_str (string) TeX ?????(?? "20pt", "1.5em")
-- @return (number|nil) ? scaled points ??????,?????????? nil
-- @usage local sp = constants.to_dimen("20pt")
local function to_dimen(dim_str)
    if not dim_str or dim_str == "" then
        return nil
    end

    -- If it's already a number, return it (assume sp)
    if type(dim_str) == "number" then
        return dim_str
    end

    -- Strip curly braces if present
    dim_str = tostring(dim_str):gsub("^%s*{", ""):gsub("}%s*$", "")

    if dim_str == "" then return nil end

    -- Try standard tex.sp parsing (handles units like "10pt")
    local ok, res = pcall(tex.sp, dim_str)
    if ok then
        return res
    end
    
    -- Fallback: try to parse as pure number (assume sp)
    local num = tonumber(dim_str)
    if num then
        return num
    end
    
    return nil
end

constants.to_dimen = to_dimen

-- Register module in package.loaded for require() compatibility
-- ????? package.loaded
package.loaded['luatex-cn-vertical-base-constants'] = constants

-- Return module
return constants