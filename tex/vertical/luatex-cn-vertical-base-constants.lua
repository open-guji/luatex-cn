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
-- base_constants.lua - 基础常量与工具函数库
-- ============================================================================

-- Create module table
local constants = {}

-- Node.direct interface for performance
constants.D = node.direct

-- Node type IDs
constants.GLYPH = node.id("glyph")
constants.KERN = node.id("kern")
constants.HLIST = node.id("hlist")
constants.VLIST = node.id("vlist")
constants.WHATSIT = node.id("whatsit")
constants.GLUE = node.id("glue")
constants.PENALTY = node.id("penalty")
constants.LOCAL_PAR = node.id("local_par")
constants.RULE = node.id("rule")

-- Custom attributes for indentation
constants.ATTR_INDENT = luatexbase.attributes.cnverticalindent or luatexbase.new_attribute("cnverticalindent")
constants.ATTR_RIGHT_INDENT = luatexbase.attributes.cnverticalrightindent or
    luatexbase.new_attribute("cnverticalrightindent")
constants.ATTR_TEXTBOX_WIDTH = luatexbase.attributes.cnverticaltextboxwidth or
    luatexbase.new_attribute("cnverticaltextboxwidth")
constants.ATTR_TEXTBOX_HEIGHT = luatexbase.attributes.cnverticaltextboxheight or
    luatexbase.new_attribute("cnverticaltextboxheight")
constants.ATTR_TEXTBOX_DISTRIBUTE = luatexbase.attributes.cnverticaltextboxdistribute or
    luatexbase.new_attribute("cnverticaltextboxdistribute")

-- Block Indentation Attributes
constants.ATTR_BLOCK_ID = luatexbase.attributes.cnverticalblockid or luatexbase.new_attribute("cnverticalblockid")
constants.ATTR_FIRST_INDENT = luatexbase.attributes.cnverticalfirstindent or
    luatexbase.new_attribute("cnverticalfirstindent")

-- Attributes for Jiazhu (Interlinear Note)
constants.ATTR_JIAZHU = luatexbase.attributes.cnverticaljiazhu or luatexbase.new_attribute("cnverticaljiazhu")
constants.ATTR_JIAZHU_SUB = luatexbase.attributes.cnverticaljiazhusub or luatexbase.new_attribute("cnverticaljiazhusub")
constants.ATTR_JIAZHU_MODE = luatexbase.attributes.cnverticaljiazhumode or
    luatexbase.new_attribute("cnverticaljiazhumode")
constants.ATTR_JUDOU_FONT = luatexbase.attributes.cnverticaljudoufont or luatexbase.new_attribute("cnverticaljudoufont")
constants.ATTR_DECORATE_ID = 202610
constants.ATTR_DECORATE_VISUAL_CENTER = 202611
constants.ATTR_DECORATE_FONT = 202612
constants.ATTR_CHAPTER_REG_ID = 202613

-- Constants for Side Pizhu
constants.SIDENOTE_USER_ID = 202601
constants.FLOATING_TEXTBOX_USER_ID = 202602
constants.JUDOU_USER_ID = 202603
constants.DECORATE_USER_ID = 202604
constants.CHAPTER_MARKER_USER_ID = 202605
constants.BANXIN_USER_ID = 202606

--- 将 TeX 尺寸字符串转换为 scaled points (sp)
local function to_dimen(dim_str)
    if not dim_str or dim_str == "" or dim_str == "nil" then return nil end
    if type(dim_str) == "number" then return dim_str end

    -- Clean string: remove braces and whitespace
    dim_str = tostring(dim_str):gsub("[{}]", ""):gsub("^%s*(.-)%s*$", "%1")
    if dim_str == "" then return nil end

    -- Handle em units (relative to font size)
    -- Normalize: remove space between number and 'em' if present
    local clean_em = dim_str:lower():gsub("%s+", "")
    local em_val = clean_em:match("^([%-%d%.]+)em$")
    if em_val then
        return { value = tonumber(em_val), unit = "em" }
    end

    -- If it's a raw number (no units), assume it's scaled points (sp)
    if tonumber(dim_str) then
        return tonumber(dim_str)
    end

    -- Absolute dimensions (pt, mm, bp, etc.)
    -- tex.sp handles spaces if they are between number and unit usually,
    -- but we clean it just in case
    local clean_abs = dim_str:gsub("%s+", "")
    local ok, res = pcall(tex.sp, clean_abs)
    if ok and res then return res end

    -- Final fallback: try raw tex.sp if cleaning failed
    ok, res = pcall(tex.sp, dim_str)
    if ok and res then return res end

    return nil
end

constants.to_dimen = to_dimen

local function resolve_dimen(val, font_size_sp)
    if not val or val == "" then return nil end
    local d = val
    if type(d) == "string" then
        d = to_dimen(d)
    end

    if type(d) == "table" and d.unit == "em" then
        return math.floor(d.value * (font_size_sp or 655360) + 0.5)
    end

    local num = tonumber(d)
    return num
end

constants.resolve_dimen = resolve_dimen

local function register_decorate(char_str, xoff_str, yoff_str, size_str, color_str, font_id, scale)
    _G.decorate_registry = _G.decorate_registry or {}

    local char_code = 63 -- Default '?'
    if char_str and char_str ~= "" then
        char_code = utf8.codepoint(char_str, 1)
    end

    local reg = {
        char = char_code,
        xoffset = to_dimen(xoff_str) or 0,
        yoffset = to_dimen(yoff_str) or 0,
        font_size = to_dimen(size_str), -- Nil means inherit from text font
        scale = tonumber(scale) or 1.0, -- Multiplier for font size
        color = color_str,
        font_id = font_id               -- Store provided ID (may be nil)
    }
    table.insert(_G.decorate_registry, reg)
    local reg_id = #_G.decorate_registry

    local D = node.direct
    local g = D.new(constants.GLYPH)
    D.setfield(g, "char", reg.char)
    D.setfield(g, "font", reg.font_id or font.current()) -- Placeholder for TeX box

    -- Set glyph dimensions to zero so it doesn't take up horizontal space
    D.setfield(g, "width", 0)
    D.setfield(g, "height", 0)
    D.setfield(g, "depth", 0)
    if constants.ATTR_DECORATE_ID then
        D.set_attribute(g, constants.ATTR_DECORATE_ID, reg_id)
    end

    -- Wrap in HLIST
    local h = D.new(node.id("hlist"))
    D.setfield(h, "head", g)
    D.setfield(h, "width", 0)
    D.setfield(h, "height", 0)
    D.setfield(h, "depth", 0)

    -- Use box 0 to pass node back to TeX
    tex.box[0] = D.tonode(h)
    return reg_id
end

constants.register_decorate = register_decorate

package.loaded['vertical.luatex-cn-vertical-base-constants'] = constants
return constants
