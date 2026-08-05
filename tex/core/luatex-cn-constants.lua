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

-- Context-sensitive punctuation squeeze (clreq 标点符号的宽度调整).
-- Value: 1 + round(1000 * 收回的字面空白/em)，即 1 表示「不挤压」、
-- 251 表示收回 0.25 em；0/unset 表示这一节点未参与上下文判定。
-- 由 punct.flatten 在分类之后按相邻上下文写入，layout 阶段据此缩短字幅。
constants.ATTR_PUNCT_SQUEEZE = luatexbase.attributes.cnverticalpunctsqueeze or
    luatexbase.new_attribute("cnverticalpunctsqueeze")

-- 其中**始端**（直排为上侧）收回的量，同样是 1 + 千分比。
-- clreq 规定字面空白有确定的一侧（中国大陆式点号在末端、开始夹注符号在始端），
-- 收回哪一侧决定字面往哪边贴：收末端空白不移动字面（后字上移），收始端
-- 空白才让字面向后贴紧被夹注内容。渲染阶段据此还原字面位置。
constants.ATTR_PUNCT_SQUEEZE_HEAD = luatexbase.attributes.cnverticalpunctsqhead or
    luatexbase.new_attribute("cnverticalpunctsqhead")

-- 该标点**总共**携带多少字面空白（潜在可收回量，1 + 千分比），与
-- ATTR_PUNCT_SQUEEZE 的区别是后者只记「相邻规则已经强制收回」的那部分。
-- 两者之差就是弹性余量：列排不下时，flush_buffer 的求解器可以按 clreq
-- 挤压优先顺序继续收回它，而不必先去压字距。
constants.ATTR_PUNCT_BLANK = luatexbase.attributes.cnverticalpunctblank or
    luatexbase.new_attribute("cnverticalpunctblank")

-- 其中始端那部分（1 + 千分比），语义同 ATTR_PUNCT_SQUEEZE_HEAD。
constants.ATTR_PUNCT_BLANK_HEAD = luatexbase.attributes.cnverticalpunctblankhead or
    luatexbase.new_attribute("cnverticalpunctblankhead")

-- 该空白在 clreq 挤压优先顺序里的类别：1 + shared/adjust.lua SHRINK_ORDER 的
-- 序号。layout 阶段据此给 gap 填 shrink_class，规则表仍只有共享层持有。
constants.ATTR_PUNCT_SHRINK_CLASS = luatexbase.attributes.cnverticalpunctshrinkcls or
    luatexbase.new_attribute("cnverticalpunctshrinkcls")

-- 该标点若落在列首 / 列末，还能**额外**收回多少空白（1 + 千分比）。
-- clreq 的行首开始夹注符号、行末点号处理是硬性规定而非弹性，但「在不在
-- 列首列末」要等断列结果才知道，所以 flatten 阶段先把两种情形的增量算好，
-- flush_buffer 定下断列后按位置取用（设计 §2.3）。
constants.ATTR_PUNCT_TRIM_START = luatexbase.attributes.cnverticalpuncttrimstart or
    luatexbase.new_attribute("cnverticalpuncttrimstart")
constants.ATTR_PUNCT_TRIM_END = luatexbase.attributes.cnverticalpuncttrimend or
    luatexbase.new_attribute("cnverticalpuncttrimend")

-- 该字与**前一个字**之间是中西边界（clreq：汉字与西文字母/数字间加不多于
-- 1/4 汉字宽的间距，可挤至 1/8、拉至 1/2；点号旁与夹注号内侧不加）。
-- 1 = 是。flatten 按共享层 shared/luatex-cn-cjk-western.lua 判定（仅
-- context 挡位），layout 的 inter_gap_desc 据此把 0.1em 基准字距换成
-- 带 cjk_western 类的 1/4em 间距 gap。
constants.ATTR_CJK_WESTERN_PREV = luatexbase.attributes.cnverticalcjkwestern or
    luatexbase.new_attribute("cnverticalcjkwestern")

-- 该字形属于「横置」西文串（clreq 直排中西混排配置之「顺时针旋转 90°」，
-- \横置{...} 标记）。1 = 是。三处协同：字幅 = 字形 advance 宽度（旋转后
-- 沿列方向的长度）、串内字距归零（字母连排成词）、渲染绕**基线**旋转
-- （串内各字形共用同一条竖直基线——按各自墨心旋转会左右摇摆）。
constants.ATTR_SIDEWAYS = luatexbase.attributes.cnverticalsideways or
    luatexbase.new_attribute("cnverticalsideways")

-- 该字形属于「中横排」短串（clreq 直排中西混排配置之「横排入一个字格」，
-- \中横排{...} 标记，即 CSS text-combine-upright / 日文縦中横）。值为
-- 递增的组号（≥1），同组同号——相邻两个组因组号不同不会误并成一格。
-- 三处协同：组首字幅 = 一字（组内其余为 0，整组共占一格）、组内字距归零
-- 且刚性、渲染把整组横排进这一格（超过 1em 时只做横向压缩，字高不变）。
constants.ATTR_TCY = luatexbase.attributes.cnverticaltcy or
    luatexbase.new_attribute("cnverticaltcy")

-- 该标点是可悬挂的点号（clreq 行尾点号悬挂，仅 hanging-punct=true 时标）。
-- 1 = 是。与 TRIM_END 的区别：TRIM_END 只收回**空白**，悬挂让整个字幅
-- （含墨迹）移出列内——落在列末时列高预算完全不含它，字形挂在版口之外。
-- clreq 注明悬挂适用于直排（横排港台式点号居中不宜），是本引擎的主场。
constants.ATTR_PUNCT_HANG = luatexbase.attributes.cnverticalpuncthang or
    luatexbase.new_attribute("cnverticalpuncthang")

-- 该字与**前一个字**同属一个刚性单元（clreq 符号分离禁则：两字幅标点、
-- 数字串、数字+单位、符号+数字、西文单词）。1 = 是。layout 阶段据此把该
-- 边界上的字距与两侧标点空白全部锁死（不可伸、不可缩）。
constants.ATTR_RIGID_PREV = luatexbase.attributes.cnverticalrigidprev or
    luatexbase.new_attribute("cnverticalrigidprev")

-- 该字是连续破折号（—— / ———）中的一员。1 = 是。破折号的墨迹在多数字体里
-- 够不到字幅两端，竖排连排时会在字与字之间露出断口；render 据此把墨迹沿列
-- 方向拉满整个字幅，使一串破折号连成一条线（横向不缩放，笔画粗细不变）。
constants.ATTR_DASH_RUN = luatexbase.attributes.cnverticaldashrun or
    luatexbase.new_attribute("cnverticaldashrun")

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

--- Process a captured side content box.
-- Examines the vbox: if it contains a TextBox result (has ATTR_TEXTBOX_WIDTH),
-- copies the box for direct positioning during render.
-- Otherwise builds a unit list — each "real" glyph starts a new unit; glyphs
-- carrying ATTR_DECORATE_ID are decoration markers (e.g., 板眼 dots from
-- \音[板]{尺}) and attach to the most recent unit's `decorations` list.
-- @param box_num (number) TeX box register number
-- @return (table|nil) { units = {...} } or { box = <node> }
local function process_side_box(box_num)
    if not box_num or box_num < 0 then return nil end
    local box = tex.box[box_num]
    if not box then return nil end

    local D = node.direct
    local head = D.todirect(box.head)
    if not head then return nil end

    -- Check if the vbox contains a TextBox result (vlist with ATTR_TEXTBOX_WIDTH)
    local n = head
    while n do
        local id = D.getid(n)
        if id == constants.VLIST then
            local attr = D.get_attribute(n, constants.ATTR_TEXTBOX_WIDTH)
            if attr and attr > 0 then
                return { box = node.copy_list(box) }
            end
        end
        n = D.getnext(n)
    end

    -- Plain text: build units. Real glyphs start a unit; decoration markers
    -- (ATTR_DECORATE_ID set, registry entry not "side_text") attach to current.
    local units = {}
    local current = nil
    local function walk(nd)
        while nd do
            local id = D.getid(nd)
            if id == constants.GLYPH then
                local char = D.getfield(nd, "char")
                local decor_id = constants.ATTR_DECORATE_ID and
                    D.get_attribute(nd, constants.ATTR_DECORATE_ID)
                if decor_id and decor_id > 0 then
                    local r = _G.decorate_registry and _G.decorate_registry[decor_id]
                    if current and r and r.type ~= "side_text" then
                        table.insert(current.decorations, {
                            char = r.char,
                            xshift = r.xshift,
                            yshift = r.yshift,
                            scale = r.scale,
                            color = r.color,
                            font_size = r.font_size,
                        })
                    end
                else
                    if char and char > 0 then
                        current = { char = char, decorations = {} }
                        table.insert(units, current)
                    end
                end
            elseif id == constants.HLIST or id == constants.VLIST then
                local child = D.getfield(nd, "head")
                if child then walk(child) end
            end
            nd = D.getnext(nd)
        end
    end
    walk(head)
    if #units == 0 then return nil end
    return { units = units }
end

--- Register a side text decoration (small text on left/right of main character)
-- Content is passed as box register numbers (captured via \vbox_set:Nn in TeX).
-- Supports both plain text and \文本框 content.
-- @param right_box_num (number) Box register number for right content
-- @param left_box_num (number|nil) Box register number for left content (nil = no left)
-- @param scale (string|number) Scale factor for plain text (default 0.5)
-- @param color_str (string) Color for plain text (default "black")
-- @param font_id (number) Font ID (nil = use current font)
-- @param offset_str (string) Horizontal offset from column edge
-- @return (number) Registry ID
local function register_side_text(right_box_num, left_box_num, scale, color_str, font_id, offset_str)
    _G.decorate_registry = _G.decorate_registry or {}

    local right_data = process_side_box(right_box_num)
    local left_data = process_side_box(left_box_num)

    local reg = {
        type = "side_text",
        right_units = right_data and right_data.units,
        right_box = right_data and right_data.box,
        left_units = left_data and left_data.units,
        left_box = left_data and left_data.box,
        scale = tonumber(scale) or 0.5,
        color = color_str or "black",
        font_id = font_id,
        offset = to_dimen(offset_str),
    }
    table.insert(_G.decorate_registry, reg)
    local reg_id = #_G.decorate_registry

    -- Create zero-width marker node (same pattern as register_decorate)
    local D = node.direct
    local g = D.new(constants.GLYPH)
    D.setfield(g, "char", 0x3000) -- ideographic space as placeholder
    D.setfield(g, "font", font_id or font.current())
    D.setfield(g, "width", 0)
    D.setfield(g, "height", 0)
    D.setfield(g, "depth", 0)

    if constants.ATTR_DECORATE_ID then
        D.set_attribute(g, constants.ATTR_DECORATE_ID, reg_id)
    end

    local h = D.new(node.id("hlist"))
    D.setfield(h, "head", g)
    D.setfield(h, "width", 0)
    D.setfield(h, "height", 0)
    D.setfield(h, "depth", 0)

    tex.box[0] = D.tonode(h)
    return reg_id
end

constants.register_side_text = register_side_text

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
