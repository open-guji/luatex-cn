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
constants.ATTR_TEXTBOX_HEIGHT_SP = luatexbase.attributes.cnverticaltextboxheightsp or
    luatexbase.new_attribute("cnverticaltextboxheightsp")
constants.ATTR_TEXTBOX_GRID_WIDTH = luatexbase.attributes.cnverticaltextboxgridwidth or
    luatexbase.new_attribute("cnverticaltextboxgridwidth")
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
constants.ATTR_LINE_MARK_ID = luatexbase.attributes.cnverticallinemark or luatexbase.new_attribute("cnverticallinemark")

-- Style Registry Attribute (for cross-page style preservation - Phase 2)
constants.ATTR_STYLE_REG_ID = luatexbase.attributes.cnverticalstyle or luatexbase.new_attribute("cnverticalstyle")

-- Punctuation type attribute (for modern punctuation plugin)
-- Values: 0=none, 1=open, 2=close, 3=fullstop, 4=comma, 5=middle, 6=nobreak
constants.ATTR_PUNCT_TYPE = luatexbase.attributes.cnverticalpuncttype or
    luatexbase.new_attribute("cnverticalpuncttype")

-- Vertical rotation attribute (for glyphs that need 90° clockwise rotation)
-- Used when font lacks vertical glyph forms (e.g., ellipsis, em dash)
-- Value: 1 = needs rotation, 0 or unset = normal
constants.ATTR_VERT_ROTATE = luatexbase.attributes.cnverticalrotate or
    luatexbase.new_attribute("cnverticalrotate")

-- Attributes for Column (单列排版)
-- ATTR_COLUMN: 1 = 标记为 Column 内容
-- ATTR_COLUMN_ALIGN: 对齐方式 0=top, 1=bottom, 2=center, 3=stretch
--                    当 >= 4 时为 LastColumn (值 = base_align + 4)
constants.ATTR_COLUMN = luatexbase.attributes.cnverticalcolumn or luatexbase.new_attribute("cnverticalcolumn")
constants.ATTR_COLUMN_ALIGN = luatexbase.attributes.cnverticalcolumnalign or
    luatexbase.new_attribute("cnverticalcolumnalign")

-- Column break with indent: value = number of grid cells to skip after column break
constants.ATTR_COLUMN_BREAK_INDENT = luatexbase.attributes.cnverticalcolbreakindent or
    luatexbase.new_attribute("cnverticalcolbreakindent")

-- Horizontal alignment override for individual glyphs
-- Values: 0=unset, 1=left, 2=center, 3=right
constants.ATTR_HALIGN = luatexbase.attributes.cnverticalhalign or
    luatexbase.new_attribute("cnverticalhalign")

-- Footnote marker group: value = marker_height (number of content grid cells)
constants.ATTR_FOOTNOTE_MARKER = luatexbase.attributes.cnverticalfnmarker or
    luatexbase.new_attribute("cnverticalfnmarker")

-- Constants for Side Pizhu
constants.SIDENOTE_USER_ID = 202601
constants.FLOATING_TEXTBOX_USER_ID = 202602
constants.JUDOU_USER_ID = 202603
constants.DECORATE_USER_ID = 202604
constants.CHAPTER_MARKER_USER_ID = 202605
constants.BANXIN_USER_ID = 202606
constants.FOOTNOTE_USER_ID = 202607

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

--- Register a decoration and create a marker node
-- @param char_str (string) The decoration character (e.g., "。", "●")
-- @param xoff_str (string) X offset (e.g., "-0.6em", "5pt")
-- @param yoff_str (string) Y offset
-- @param size_str (string) Font size (nil = inherit from text)
-- @param color_str (string) Color (e.g., "red", "0.8 0 0")
-- @param font_id (number) Font ID (nil = use current font)
-- @param scale (number) Scale multiplier (default 1.0)
-- @return (number) Registry ID for this decoration
local function register_decorate(char_str, xoff_str, yoff_str, size_str, color_str, font_id, scale)
    _G.decorate_registry = _G.decorate_registry or {}

    local char_code = 63 -- Default '?'
    if char_str and char_str ~= "" then
        char_code = utf8.codepoint(char_str, 1)
    end

    -- Register style attributes in style_registry (Phase 2: Style Registry)
    local style_registry = package.loaded['util.luatex-cn-style-registry'] or
        require('util.luatex-cn-style-registry')

    local style = {}
    if color_str and color_str ~= "" then
        style.font_color = color_str
    end
    if size_str and size_str ~= "" then
        style.font_size = to_dimen(size_str)
    end
    -- Note: font_id is numeric, not storing in style registry (would need font name)

    local style_reg_id = nil
    if next(style) then
        style_reg_id = style_registry.register(style)
    end

    -- Keep decoration-specific attributes in decorate_registry
    local reg = {
        char = char_code,
        xshift = to_dimen(xoff_str) or 0,
        yshift = to_dimen(yoff_str) or 0,
        scale = tonumber(scale) or 1.0, -- Multiplier for font size
        font_id = font_id,              -- Store provided ID (may be nil)
        font_size = to_dimen(size_str),
        color = color_str,
    }
    table.insert(_G.decorate_registry, reg)
    local reg_id = #_G.decorate_registry

    local D = node.direct
    local g = D.new(constants.GLYPH)
    D.setfield(g, "char", reg.char)
    D.setfield(g, "font", reg.font_id or font.current())

    -- Set glyph dimensions to zero so it doesn't take up horizontal space
    D.setfield(g, "width", 0)
    D.setfield(g, "height", 0)
    D.setfield(g, "depth", 0)

    -- Set both decorate ID and style registry ID attributes
    if constants.ATTR_DECORATE_ID then
        D.set_attribute(g, constants.ATTR_DECORATE_ID, reg_id)
    end
    if style_reg_id and constants.ATTR_STYLE_REG_ID then
        D.set_attribute(g, constants.ATTR_STYLE_REG_ID, style_reg_id)
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

-- ============================================================================
-- Line Mark Registration (for 专名号/书名号 - PDF-drawn lines)
-- ============================================================================
_G.line_mark_registry = _G.line_mark_registry or {}
_G.line_mark_group_counter = _G.line_mark_group_counter or 0

--- Register a line mark group and return group_id
-- @param type_str (string) "straight" or "wavy"
-- @param color_str (string) Color name or RGB (e.g., "red", "0 0 0")
-- @param offset_str (string) Offset from text center (e.g., "0.6em")
-- @param amplitude_str (string) Wavy amplitude: "small", "medium", "large"
-- @param linewidth_str (string) Line width (e.g., "0.4pt")
-- @param style_str (string) Wavy style: "standard" (tight, like U+FE34) or "cursive" (wide, expressive)
-- @return (number) group_id
local function register_line_mark(type_str, color_str, offset_str, amplitude_str, linewidth_str, style_str)
    _G.line_mark_group_counter = _G.line_mark_group_counter + 1
    local gid = _G.line_mark_group_counter

    _G.line_mark_registry[gid] = {
        type = type_str or "straight",
        color = color_str or "black",
        offset = to_dimen(offset_str) or { value = 0.6, unit = "em" },
        amplitude = amplitude_str or "medium",
        linewidth = to_dimen(linewidth_str) or tex.sp("0.8pt"),
        style = style_str or "standard",
    }

    -- Pass group_id back to TeX via macro
    token.set_macro("g__luatexcn_line_mark_gid", tostring(gid))
    return gid
end

constants.register_line_mark = register_line_mark

-- ============================================================================
-- Indent Constants
-- ============================================================================
-- Two categories of forced indent encoding:
--   1. Taitou indent: from \抬头/\平抬/\相对抬头, scoped to one column (taitou scope)
--   2. Suojin indent: from \缩进[N], scoped until \\ or \end{段落} (temp style)
-- Each category uses a separate encoding range so resolve_node_indent can
-- apply the correct scope rules.

--- Inherit indent from style stack (default when attribute is 0 or unset)
constants.INDENT_INHERIT = 0

-- -- Taitou encoding (from \抬头 family) -- --

--- Taitou force indent=0 (\平抬 = \抬头[0])
constants.INDENT_TAITOU_ZERO = -2

--- Base for taitou forced indent: attr = INDENT_TAITOU_BASE - N
--- Example: \单抬 → indent=-1 → attr = -1000 - (-1) = -999
constants.INDENT_TAITOU_BASE = -1000

-- -- Suojin encoding (from \缩进 command) -- --

--- Suojin force indent=0 (\缩进[0])
constants.INDENT_SUOJIN_ZERO = -3

--- Base for suojin forced indent: attr = INDENT_SUOJIN_BASE - N
--- Example: \缩进[3] → attr = -2000 - 3 = -2003
constants.INDENT_SUOJIN_BASE = -2000

-- -- Backward-compatible aliases (deprecated, use taitou/suojin variants) -- --
constants.INDENT_FORCE_ZERO = constants.INDENT_TAITOU_ZERO
constants.INDENT_FORCE_BASE = constants.INDENT_TAITOU_BASE

--- Check if attr is a taitou indent (from \抬头/\平抬/\相对抬头)
--- @param attr_value number The indent attribute value
--- @return boolean, number|nil
function constants.is_taitou_indent(attr_value)
    if not attr_value then return false, nil end
    if attr_value == constants.INDENT_TAITOU_ZERO then
        return true, 0
    end
    -- Taitou range: (SUOJIN_BASE, TAITOU_ZERO) excluding SUOJIN_ZERO
    -- Positive indent N>0: attr = BASE - N → attr < BASE (e.g., -1001, -1002, ...)
    -- Negative indent N<0: attr = BASE - N → attr > BASE (e.g., -999, -998, ...)
    -- Both directions are covered by: attr < -2 and attr > -2000 and attr != -3
    if attr_value < constants.INDENT_TAITOU_ZERO
        and attr_value > constants.INDENT_SUOJIN_BASE
        and attr_value ~= constants.INDENT_SUOJIN_ZERO then
        return true, constants.INDENT_TAITOU_BASE - attr_value
    end
    return false, nil
end

--- Check if attr is a suojin indent (from \缩进[N])
--- @param attr_value number The indent attribute value
--- @return boolean, number|nil
function constants.is_suojin_indent(attr_value)
    if not attr_value then return false, nil end
    if attr_value == constants.INDENT_SUOJIN_ZERO then
        return true, 0
    end
    -- Range: attr <= -2000
    if attr_value <= constants.INDENT_SUOJIN_BASE then
        return true, constants.INDENT_SUOJIN_BASE - attr_value
    end
    return false, nil
end

--- Check if attr is any command-level forced indent (taitou or suojin)
--- @param attr_value number The indent attribute value
--- @return boolean, number|nil
function constants.is_any_command_indent(attr_value)
    local ok, val = constants.is_taitou_indent(attr_value)
    if ok then return true, val end
    return constants.is_suojin_indent(attr_value)
end

--- Encode a taitou indent value (from \抬头/\平抬/\相对抬头)
--- @param indent_value number The indent value to force
--- @return number The encoded attribute value
function constants.encode_taitou_indent(indent_value)
    if indent_value == 0 then
        return constants.INDENT_TAITOU_ZERO
    end
    return constants.INDENT_TAITOU_BASE - indent_value
end

--- Encode a suojin indent value (from \缩进[N])
--- @param indent_value number The indent value to force
--- @return number The encoded attribute value
function constants.encode_suojin_indent(indent_value)
    if indent_value == 0 then
        return constants.INDENT_SUOJIN_ZERO
    end
    return constants.INDENT_SUOJIN_BASE - indent_value
end

--- Deprecated: use is_taitou_indent or is_any_command_indent instead
function constants.is_forced_indent(attr_value)
    return constants.is_any_command_indent(attr_value)
end

--- Deprecated: use encode_taitou_indent or encode_suojin_indent instead
function constants.encode_forced_indent(indent_value)
    return constants.encode_taitou_indent(indent_value)
end

-- ============================================================================
-- Penalty Constants for Column/Page Breaks
-- ============================================================================
-- Special penalty values to control column and page breaking behavior

--- Smart column break: Check next node type before deciding
--- If next is textflow, don't break; if next is regular text, break to new column
--- Used by: Paragraph environment end
constants.PENALTY_SMART_BREAK = -10001

--- Force column break: Unconditionally wrap to next column
--- Used by: \换行 command, some \\ commands
constants.PENALTY_FORCE_COLUMN = -10002

--- Force page break: Unconditionally wrap to new page
--- Used by: \newpage, \clearpage commands
constants.PENALTY_FORCE_PAGE = -10003

--- Taitou column break: Force column break for 抬头 commands
--- Like PENALTY_FORCE_COLUMN, but marks the next column as the taitou scope.
--- Used by: \抬头, \相对抬头 commands
constants.PENALTY_TAITOU = -10004

--- Digital newline: Column break from DigitalContent ^^M (obeylines).
--- Like PENALTY_FORCE_COLUMN, but consecutive occurrences always produce
--- empty columns (even when cur_row == 0). This is needed because every
--- newline in the .tex source must map to a column in the PDF output.
--- Used by: DigitalContent environment obeylines handler
constants.PENALTY_DIGITAL_NEWLINE = -10005

--- Band break: Force wrap to next band (horizontal strip) in multi-band layout.
--- In band mode, a page is divided into N horizontal bands, each with its own
--- set of columns. This penalty forces the layout to skip to the next band.
--- Used by: \换栏 command
constants.PENALTY_BAND_BREAK = -10006

--- Cell break: Force jump to next column group in table mode.
--- In table mode, each cell occupies a column group (a set of consecutive columns).
--- This penalty forces the layout to skip to the start of the next column group.
--- Used by: \单元格 / \Cell command
constants.PENALTY_CELL_BREAK = -10007

--- Table start: Begin inline table section within BodyText.
--- Triggers dynamic switch to band mode. Table parameters are read from
--- _G.content.table_params (n_bands, band_gap_sp, band_heights).
--- Used by: \begin{表格} / \begin{Table}
constants.PENALTY_TABLE_START = -10008

--- Table end: End inline table section, restore single-band mode.
--- Used by: \end{表格} / \end{Table}
constants.PENALTY_TABLE_END = -10009

--- Half page break: Skip to next half-page boundary.
--- In butterfly-binding (筒子页) mode, each page has two halves separated by
--- the banxin column. This penalty fills the current half-page with empty columns
--- and advances to the start of the next half-page.
--- Used by: \换半页 / \NewHalfPage command
constants.PENALTY_HALF_PAGE = -10010

--- Page fill marker: Allow page break, used in page splitting
--- Note: This keeps standard TeX value for compatibility
constants.PENALTY_PAGE_FILL = -10000

-- ============================================================================
-- Shared color name to RGB mapping
-- ============================================================================

constants.color_map = {
    red = "1 0 0",
    blue = "0 0 1",
    green = "0 1 0",
    black = "0 0 0",
    purple = "0.5 0 0.5",
    orange = "1 0.5 0",
}

package.loaded['core.luatex-cn-constants'] = constants
return constants
