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
constants.ATTR_JUDOU_FONT = luatexbase.attributes.cnverticaljudoufont or luatexbase.new_attribute("cnverticaljudoufont")
constants.ATTR_DECORATE_ID = 202610
-- Stores the visual center X coordinate (relative to glyph origin)
constants.ATTR_DECORATE_VISUAL_CENTER = 202611
constants.ATTR_DECORATE_FONT = 202612

-- Constants for Side Pizhu
constants.SIDENOTE_USER_ID = 202601
constants.FLOATING_TEXTBOX_USER_ID = 202602
constants.JUDOU_USER_ID = 202603
constants.DECORATE_USER_ID = 202604

--- 将 TeX 尺寸字符串转换为 scaled points (sp)
local function to_dimen(dim_str)
    if not dim_str or dim_str == "" then return nil end
    if type(dim_str) == "number" then return dim_str end
    dim_str = tostring(dim_str):gsub("[{}]", ""):gsub("^%s*(.-)%s*$", "%1")
    if dim_str == "" then return nil end

    -- Check for em units
    local em_val = dim_str:match("^([%-%d%.]+)%s*em$")
    if not em_val then
        -- If it's a raw number, treat as em (standard behavior in this package)
        if tonumber(dim_str) then
            em_val = dim_str
        end
    end

    if em_val then
        return { value = tonumber(em_val), unit = "em" }
    end

    -- Absolute dimensions (pt, mm, bp, etc.)
    local ok, res = pcall(tex.sp, dim_str)
    if ok then return res end
    return nil
end

constants.to_dimen = to_dimen

local function resolve_dimen(val, font_size_sp)
    if type(val) == "table" and val.unit == "em" then
        return math.floor(val.value * font_size_sp + 0.5)
    end
    return tonumber(val) or 0
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
        font_id = font_id or font.current()
    }
    table.insert(_G.decorate_registry, reg)
    local reg_id = #_G.decorate_registry

    local D = node.direct
    local g = D.new(constants.GLYPH)
    D.setfield(g, "char", reg.char)
    D.setfield(g, "font", reg.font_id)

    -- Calculate Visual Center for alignment
    if constants.ATTR_DECORATE_VISUAL_CENTER then
        local visual_center = 0
        local f = font.getfont(reg.font_id)
        if f and f.characters and f.characters[reg.char] then
            local c = f.characters[reg.char]
            if c.boundingbox and #c.boundingbox >= 3 then
                -- BBox is in design units (typically 1/1000 em), convert to sp
                local units_per_em = f.units_per_em or 1000
                local raw_v_center = (c.boundingbox[1] + c.boundingbox[3]) / 2
                visual_center = raw_v_center * (f.size / units_per_em)
            else
                -- Fallback: Use Advance Width / 2 (already in sp)
                -- HACK: Special handling for Stars in Fandol fonts which are left-aligned
                if reg.char == 9733 or reg.char == 9734 then
                    visual_center = (c.width or 0) * 0.25
                else
                    visual_center = (c.width or 0) / 2
                end
            end
            D.set_attribute(g, constants.ATTR_DECORATE_VISUAL_CENTER, visual_center)
        end
    end

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
