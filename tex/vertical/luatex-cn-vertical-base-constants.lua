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
-- 文件名: base_constants.lua (原 constants.lua)
-- 层级: 基础层 (Base Layer)
--
-- 【模块功能 / Module Purpose】
-- 本模块是所有子模块的共享基础设施，提供：
--   1. 节点类型 ID 常量（GLYPH、KERN、HLIST、VLIST 等）
--   2. 自定义属性索引（缩进、右缩进、textbox 尺寸等）
--   3. TeX 尺寸字符串到 scaled points 的转换函数 (to_dimen)
--   4. Node.direct 接口的快捷引用 (D)
--
-- 【术语对照 / Terminology】
--   scaled points (sp)  - TeX 内部单位，1pt = 65536sp
--   GLYPH               - 字形节点（glyph node）
--   KERN                - 字距节点（kerning node）
--   HLIST               - 水平列表（horizontal list）
--   VLIST               - 垂直列表（vertical list）
--   GLUE                - 胶水/弹性空白（glue）
--   PENALTY             - 惩罚节点（penalty，用于换行/分页控制）
--   ATTR_INDENT         - 缩进属性（indent attribute）
--   ATTR_TEXTBOX_*      - 文本框属性（textbox attributes）
--
-- 【注意事项】
--   • 本模块必须在所有其他模块之前加载（vertical.sty 确保了这一点）
--   • 属性 ID 由 TeX 层注册（\newluatexattribute），Lua 层通过 luatexbase 访问
--   • to_dimen 函数会过滤空字符串和 "0pt"，返回 nil 而非 0（用于区分未设置）
--
-- 【整体架构 / Architecture】
--   base_constants.lua (本模块)
--      ├─ 导出常量 → 被所有子模块引用
--      ├─ to_dimen() → 被 core_main.lua 用于解析 TeX 参数
--      └─ ATTR_* 索引 → 被 flatten/layout/render 用于读写节点属性
--
-- ============================================================================

-- Create module table
local constants = {}

-- Node.direct interface for performance
constants.D = node.direct

-- Legacy debug table removed in favor of centralized luatex-cn-debug module.
-- Registration is handled by modules (e.g., vertical.sty calls luatex_cn_debug.register_module)

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
-- Note: Attributes are registered in vertical.sty via \newluatexattribute
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
constants.ATTR_DECORATE_WIDTH = 202611

-- Constants for Side Pizhu
constants.SIDENOTE_USER_ID = 202601
constants.FLOATING_TEXTBOX_USER_ID = 202602
constants.JUDOU_USER_ID = 202603
constants.DECORATE_USER_ID = 202604

--- 将 TeX 尺寸字符串转换为 scaled points (sp)
-- @param dim_str (string) TeX 尺寸字符串（例如 "20pt", "1.5em"）
-- @return (number|nil) 以 scaled points 为单位的尺寸，如果无效或为零则返回 nil
-- @usage local sp = constants.to_dimen("20pt")
local function to_dimen(dim_str)
    if not dim_str or dim_str == "" then
        return nil
    end

    -- If it's already a number, return it (assume sp)
    if type(dim_str) == "number" then
        return dim_str
    end

    -- Strip curly braces if present (handle nested/multiple braces)
    dim_str = tostring(dim_str):gsub("[{}]", ""):gsub("^%s*(.-)%s*$", "%1")

    if dim_str == "" then return nil end

    -- Fallback: try to parse as pure number (assume em per refined requirement)
    if tonumber(dim_str) then
        local ok, res = pcall(tex.sp, dim_str .. "em")
        if ok then return res end
    end

    -- Try standard tex.sp parsing (handles units like "10pt", "5em")
    local ok, res = pcall(tex.sp, dim_str)
    if ok then
        return res
    end

    return nil
end

constants.to_dimen = to_dimen

local function register_decorate(char_str, xoff_str, yoff_str, size_str, color_str, font_id)
    _G.decorate_registry = _G.decorate_registry or {}

    local char_code = 63 -- Default '?'
    if char_str and char_str ~= "" then
        char_code = utf8.codepoint(char_str, 1)
    end

    local reg = {
        char = char_code,
        xoffset = to_dimen(xoff_str) or 0,
        yoffset = to_dimen(yoff_str) or 0,
        font_size = to_dimen(size_str) or tex.sp("6pt"),
        color = color_str,
        font_id = font_id or font.current()
    }
    table.insert(_G.decorate_registry, reg)
    local reg_id = #_G.decorate_registry

    local D = node.direct
    local g = D.new(constants.GLYPH)
    D.setfield(g, "char", reg.char)
    D.setfield(g, "font", reg.font_id)

    -- Save actual width to attribute for later centering calculation
    if constants.ATTR_DECORATE_WIDTH then
        local f = font.getfont(reg.font_id)
        if f and f.characters and f.characters[reg.char] then
            local w = f.characters[reg.char].width
            D.set_attribute(g, constants.ATTR_DECORATE_WIDTH, w)
        end
    end

    -- Set glyph dimensions to zero so it doesn't take up horizontal space
    D.setfield(g, "width", 0)
    D.setfield(g, "height", 0)
    D.setfield(g, "depth", 0)
    if constants.ATTR_DECORATE_ID then
        D.set_attribute(g, constants.ATTR_DECORATE_ID, reg_id)
    end

    -- Wrap in HLIST to be compatible with tex.box
    local h = D.new(node.id("hlist"))
    D.setfield(h, "list", g) -- Correct field for head of list in direct mode is often "list" or "head" depending on version?
    -- in direct mode, list head is "head" or we use setfield(h, "head", g)
    D.setfield(h, "head", g)
    D.setfield(h, "width", 0)
    D.setfield(h, "height", 0)
    D.setfield(h, "depth", 0)

    -- Use box 0 to pass node back to TeX
    tex.box[0] = D.tonode(h)
end

constants.register_decorate = register_decorate

-- Register module in package.loaded for require() compatibility
-- 注册模块到 package.loaded
package.loaded['vertical.luatex-cn-vertical-base-constants'] = constants

-- Return module
return constants
