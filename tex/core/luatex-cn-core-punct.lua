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

--- Modern Punctuation Plugin for luatex-cn
-- Provides punctuation squeeze, kinsoku (line-breaking rules),
-- vertical quote replacement, and punctuation hanging.
-- Active when punct-mode = "normal" (default for ltc-book).
-- Mutually exclusive with the judou plugin.

local punct = {}

local D = node.direct
local constants = require('core.luatex-cn-constants')
local debug_mod = require('debug.luatex-cn-debug')
local shared_punct = require('shared.luatex-cn-punct-table')
local punct_squeeze = require('shared.luatex-cn-punct-squeeze')
local punct_anchors = require('shared.luatex-cn-punct-anchors')
local adjust = require('shared.luatex-cn-adjust')
local kinsoku = require('shared.luatex-cn-kinsoku')
local dbg = debug_mod.get_debugger('punct')

-- clreq 挤压优先顺序的类别 → 序号（写进 ATTR_PUNCT_SHRINK_CLASS，
-- layout 阶段再还原成类别名交给求解器；顺序表本身只有共享层持有）
local SHRINK_CLASS_INDEX = {}
for i, cls in ipairs(adjust.SHRINK_ORDER) do SHRINK_CLASS_INDEX[cls] = i end

-- ============================================================================
-- Font ink-center cache for punctuation auto-centering
-- ============================================================================
-- Some fonts (e.g. FZShuSong-Z01) have punctuation glyphs whose ink is not
-- centered in the advance width. This cache stores the ink center ratio
-- (ink_center_x / advance_width) so we can compensate at render time.
-- Key: font_id, Value: { [charcode] = ratio (0..1), ... }
local font_ink_center_cache = {}

-- Characters whose ink center we need to measure
local INK_CENTER_CHARS = {
    [0xFF0C] = true, -- ，
    [0x3001] = true, -- 、
    [0x3002] = true, -- 。
    [0xFF0E] = true, -- ．
    [0xFF1A] = true, -- ：
    [0xFF1B] = true, -- ；
    [0xFF01] = true, -- ！
    [0xFF1F] = true, -- ？
}

--- Parse a tounicode string (hex) into a numeric codepoint.
-- Only handles single codepoints (4 hex digits). Multi-codepoint tounicode
-- (surrogate pairs, ligatures) returns nil.
-- @param tu_str (string) Hex string like "FF0C" or "3001"
-- @return (number|nil) Codepoint, or nil if not a single codepoint
local function parse_tounicode(tu_str)
    if not tu_str or #tu_str ~= 4 then return nil end
    return tonumber(tu_str, 16)
end

--- Get ink center ratios for a glyph in a given font.
-- Returns the center of the glyph ink as ratios of advance width (x and y).
-- For a perfectly centered glyph both are 0.5.
-- @param fid (number) Font ID
-- @param charcode (number) Unicode codepoint
-- @return (number, number) Ink center ratio x, y (0..1), or 0.5, 0.5 if unknown
local function get_ink_center_ratio(fid, charcode)
    -- Check cache first
    local font_cache = font_ink_center_cache[fid]
    if font_cache then
        local entry = font_cache[charcode]
        if entry then return entry.x, entry.y end
        -- Already analyzed this font but char not found
        if font_cache._analyzed then return 0.5, 0.5 end
    end

    -- Analyze font using fontloader
    font_ink_center_cache[fid] = font_ink_center_cache[fid] or {}
    font_cache = font_ink_center_cache[fid]
    font_cache._analyzed = true

    local f = font.getfont(fid)
    if not f or not f.filename then return 0.5, 0.5 end

    local ok, raw = pcall(fontloader.open, f.filename)
    if not ok or not raw then return 0.5, 0.5 end

    local ok2, info = pcall(fontloader.to_table, raw)
    fontloader.close(raw)
    if not ok2 or not info or not info.glyphs then return 0.5, 0.5 end

    -- Scan all glyphs for target characters (by Unicode)
    for i = 0, (info.glyphcnt or 0) - 1 do
        local g = info.glyphs[i]
        if g and g.unicode and INK_CENTER_CHARS[g.unicode] and g.width and g.width > 0 then
            if g.boundingbox then
                local cx = (g.boundingbox[1] + g.boundingbox[3]) / 2
                local cy = (g.boundingbox[2] + g.boundingbox[4]) / 2
                font_cache[g.unicode] = { x = cx / g.width, y = cy / g.width }
            end
        end
    end

    -- Also cache ink centers for PUA chars whose tounicode points to
    -- INK_CENTER_CHARS (e.g. vert GSUB substituted punctuation).
    -- Use glyph index from font.getfont() to look up fontloader bounding box.
    if f.characters then
        for code, ch_data in pairs(f.characters) do
            if ((code >= 0xE000 and code <= 0xF8FF) or
                (code >= 0xF0000 and code <= 0xFFFFF) or
                code >= 0x100000) and ch_data.tounicode and ch_data.index then
                local orig = parse_tounicode(ch_data.tounicode)
                if orig and INK_CENTER_CHARS[orig] then
                    local g = info.glyphs[ch_data.index]
                    if g and g.width and g.width > 0 and g.boundingbox then
                        local cx = (g.boundingbox[1] + g.boundingbox[3]) / 2
                        local cy = (g.boundingbox[2] + g.boundingbox[4]) / 2
                        font_cache[code] = { x = cx / g.width, y = cy / g.width }
                    end
                end
            end
        end
    end

    dbg.log(string.format("punct: analyzed font %d ink centers: %s",
        fid, f.filename))

    local entry = font_cache[charcode]
    if entry then return entry.x, entry.y end
    return 0.5, 0.5
end

-- ============================================================================
-- Punctuation Character Classification (derived from the shared clreq table)
-- ============================================================================
-- The six legacy classes (open/close/fullstop/comma/middle/nobreak) are no
-- longer hand-maintained here: they derive from shared.luatex-cn-punct-table
-- via legacy_type() — single data source per the clreq shared-core contract
-- (ai_must_read/clreq-shared-core.md). Vertical presentation forms (the
-- replacement targets in VERT_FORM_MAP below) inherit the class of their
-- horizontal source character. The derived map is built after VERT_FORM_MAP.

-- Vertical form replacement map (horizontal → vertical presentation forms)
-- Replaces CJK brackets/parentheses with their Unicode Vertical Presentation
-- Forms (U+FE30–U+FE4F) for correct display in vertical text.
-- Also replaces curly quotes with corner bracket vertical forms.
local VERT_FORM_MAP = {
    -- CJK corner brackets → vertical forms
    [0x300C] = 0xFE41, -- 「 → ﹁ (left corner bracket)
    [0x300D] = 0xFE42, -- 」 → ﹂ (right corner bracket)
    [0x300E] = 0xFE43, -- 『 → ﹃ (left white corner bracket)
    [0x300F] = 0xFE44, -- 』 → ﹄ (right white corner bracket)
    -- Fullwidth parentheses → vertical forms
    [0xFF08] = 0xFE35, -- （ → ︵ (left parenthesis)
    [0xFF09] = 0xFE36, -- ） → ︶ (right parenthesis)
    -- Angle brackets → vertical forms
    [0x3008] = 0xFE3F, -- 〈 → ︿ (left angle bracket)
    [0x3009] = 0xFE40, -- 〉 → ﹀ (right angle bracket)
    -- Double angle brackets → vertical forms
    [0x300A] = 0xFE3D, -- 《 → ︽ (left double angle bracket)
    [0x300B] = 0xFE3E, -- 》 → ︾ (right double angle bracket)
    -- Lenticular brackets → vertical forms
    [0x3010] = 0xFE3B, -- 【 → ︻ (left black lenticular bracket)
    [0x3011] = 0xFE3C, -- 】 → ︼ (right black lenticular bracket)
    -- Tortoise shell brackets → vertical forms
    [0x3014] = 0xFE39, -- 〔 → ︹ (left tortoise shell bracket)
    [0x3015] = 0xFE3A, -- 〕 → ︺ (right tortoise shell bracket)
    -- Em dash and ellipsis → vertical forms
    [0x2014] = 0xFE31, -- — → ︱ (em dash → vertical em dash)
    [0x2026] = 0xFE19, -- … → ︙ (horizontal ellipsis → vertical ellipsis)
    -- Curly quotes → corner bracket vertical forms (mainland convention)
    -- Mainland: "" = first level → 「」, '' = second level → 『』
    [0x201C] = 0xFE41, -- " → ﹁ (left double → vertical left corner bracket)
    [0x201D] = 0xFE42, -- " → ﹂ (right double → vertical right corner bracket)
    [0x2018] = 0xFE43, -- ' → ﹃ (left single → vertical left white corner bracket)
    [0x2019] = 0xFE44, -- ' → ﹄ (right single → vertical right white corner bracket)
}

-- Derived legacy classification map: codepoint → "open"|"close"|"fullstop"|
-- "comma"|"middle"|"nobreak". Built from the shared clreq table, then
-- extended with the vertical presentation forms, which inherit the class of
-- their horizontal source (e.g. ﹁ inherits "open" from 「).
local LEGACY_CLASS = {}
for char in shared_punct.entries() do
    LEGACY_CLASS[char] = shared_punct.legacy_type(char)
end
for h_char, v_char in pairs(VERT_FORM_MAP) do
    LEGACY_CLASS[v_char] = shared_punct.legacy_type(h_char)
end

-- ============================================================================
-- tounicode-based reverse mapping for GSUB-substituted punctuation
-- ============================================================================
-- Some fonts (e.g. KingHwa_OldSong) have vert GSUB entries that map punctuation
-- to glyphs without a standard Unicode codepoint. luaotfload's node mode then
-- assigns these glyphs Private Use Area (PUA) codepoints (U+F0000+), causing
-- punct.classify() to fail.
--
-- This cache maps (font_id, substituted_char) → original_codepoint by reading
-- the glyph's tounicode field from font.getfont().characters.
-- Key: font_id, Value: { [pua_char] = original_codepoint, ... }
local font_tounicode_cache = {}

--- Resolve the original Unicode codepoint for a possibly-substituted glyph.
-- If the glyph's char is in the PUA range and has a tounicode pointing to
-- a known punctuation codepoint, return that original codepoint.
-- Results are cached per font.
-- @param fid (number) Font ID
-- @param char (number) Current char code (possibly PUA)
-- @return (number|nil) Original codepoint if resolved, nil otherwise
local function resolve_original_codepoint(fid, char)
    -- Only attempt resolution for PUA-range chars
    -- Supplementary PUA-A: U+F0000..U+FFFFF
    -- Supplementary PUA-B: U+100000..U+10FFFD
    -- BMP PUA: U+E000..U+F8FF
    if not (char >= 0xE000 and char <= 0xF8FF)
       and not (char >= 0xF0000 and char <= 0xFFFFF)
       and not (char >= 0x100000) then
        return nil
    end

    -- Check cache
    local fc = font_tounicode_cache[fid]
    if fc then
        return fc[char]  -- may be nil (already checked, not a punct)
    end

    -- Build cache for this font: scan characters for PUA entries with
    -- tounicode pointing to known punctuation
    fc = {}
    font_tounicode_cache[fid] = fc

    local fdata = font.getfont(fid)
    if not fdata or not fdata.characters then return nil end

    for code, ch_data in pairs(fdata.characters) do
        -- Only cache PUA-range chars
        if ((code >= 0xE000 and code <= 0xF8FF) or
            (code >= 0xF0000 and code <= 0xFFFFF) or
            code >= 0x100000) and ch_data.tounicode then
            local orig = parse_tounicode(ch_data.tounicode)
            if orig and punct.classify(orig) then
                fc[code] = orig
            end
        end
    end

    return fc[char]
end

-- Punctuation type numeric codes (for ATTR_PUNCT_TYPE attribute)
local PUNCT_CODES = {
    open     = 1,
    close    = 2,
    fullstop = 3,
    comma    = 4,
    middle   = 5,
    nobreak  = 6,
}

-- Reverse mapping: code → type name
local PUNCT_NAMES = {}
for name, code in pairs(PUNCT_CODES) do
    PUNCT_NAMES[code] = name
end

-- ============================================================================
-- Classification Functions
-- ============================================================================

--- Classify a character code into punctuation type
-- @param char_code (number) Unicode code point
-- @return (string|nil) "open", "close", "fullstop", "comma", "middle", "nobreak", or nil
function punct.classify(char_code)
    return LEGACY_CLASS[char_code]
end

--- 识别破折号合字，返回它代表几个 em dash。
--
-- 带 ccmp 的字体（思源宋体 / Noto CJK 等）在 shaping 阶段就把 —— 合成一个
-- 字形，早于 flatten。合字只有横排形（无 ︱），宽度约 1.7 em，塞进一字一格
-- 的竖排网格里就成了「两个字只占一格的横杠」。做法是把它拆回 N 个 em dash，
-- 每个各自走标准流程（一格一个、竖排形/旋转、连排规则）。
-- 两种形态：
--   * U+2E3A（⸺ 两字破折号）/ U+2E3B（⸻ 三字）：思源走这一路，有正式码位
--   * 无码位的合字：luaotfload 给它派 PUA 码位，靠 tounicode 是 2–3 个
--     破折号码位连排来识别
-- @param fid (number) Font ID
-- @param char (number) Current char code
-- @return (number|nil) 组成它的破折号个数（2 或 3），不是合字则为 nil
function punct.dash_ligature_count(fid, char)
    if char == 0x2E3A then return 2 end
    if char == 0x2E3B then return 3 end
    if (char >= 0xE000 and char <= 0xF8FF)
        or (char >= 0xF0000 and char <= 0xFFFFF)
        or char >= 0x100000 then
        local fdata = font.getfont(fid)
        local ch = fdata and fdata.characters and fdata.characters[char]
        local tu = ch and ch.tounicode
        if type(tu) == "string" and (#tu == 8 or #tu == 12) then
            local n = 0
            for i = 1, #tu, 4 do
                local cp = tonumber(tu:sub(i, i + 3), 16)
                -- U+2015 横杠：部分字体的破折号合字以它为构件
                if cp ~= 0x2014 and cp ~= 0x2015 then return nil end
                n = n + 1
            end
            return n
        end
    end
    return nil
end

--- Check if a punctuation type is forbidden at line start (column top)
-- @param ptype (string) Punctuation type
-- @return (boolean)
function punct.is_line_start_forbidden(ptype)
    return ptype == "close"
        or ptype == "fullstop"
        or ptype == "comma"
        or ptype == "middle"
end

--- Check if a punctuation type is forbidden at line end (column bottom)
-- @param ptype (string) Punctuation type
-- @return (boolean)
function punct.is_line_end_forbidden(ptype)
    return ptype == "open"
end

--- Get punctuation type name from ATTR_PUNCT_TYPE attribute value
-- @param code (number) Attribute value
-- @return (string|nil) Type name
function punct.type_from_code(code)
    return PUNCT_NAMES[code]
end

--- Get ATTR_PUNCT_TYPE attribute value from type name
-- @param name (string) Type name
-- @return (number|nil) Attribute value
function punct.code_from_type(name)
    return PUNCT_CODES[name]
end

-- ============================================================================
-- Kinsoku (Line-breaking Rules) Implementation
-- ============================================================================

--- Find the next visible GLYPH node after the current one, skipping glue/kern/penalty/whatsit
-- @param current_node (direct node) Current node in the direct node list
-- @return (direct node|nil) Next visible glyph, or nil if none
local function find_next_glyph(current_node)
    local n = D.getnext(current_node)
    while n do
        local nid = D.getid(n)
        if nid == constants.GLYPH then
            return n
        elseif nid == constants.GLUE or nid == constants.KERN
            or nid == constants.PENALTY or nid == constants.WHATSIT then
            n = D.getnext(n)
        else
            return nil -- Unknown node type, stop looking
        end
    end
    return nil
end

--- Create the kinsoku check hook callback for layout-grid.lua
-- This function is called after each GLYPH is placed in col_buffer.
-- When the column is full (ctx.cur_row >= effective_limit), it looks ahead
-- to see if the next character is forbidden at line start. If so, it
-- pulls the current character out and wraps them together to the new column.
--
-- @param punct_ctx (table) Punctuation plugin context
-- @return (function) The hook callback
function punct.make_kinsoku_hook(punct_ctx)
    if not punct_ctx or not punct_ctx.kinsoku then
        return nil
    end

    return function(t, ctx, effective_limit, col_buffer,
                    flush_buffer, wrap_to_next_column,
                    p_cols, interval, grid_height, indent)
        -- Only act when the column is full or nearly full
        if ctx.cur_row < effective_limit then
            return
        end

        -- Column is full (ctx.cur_row >= effective_limit)
        -- The character at col_buffer[#col_buffer] was just placed at the last row

        --- 把列尾的 n 个字连同换列一起挪到下一列
        local function pull_tail(n)
            local pulled = {}
            for _ = 1, n do
                local e = table.remove(col_buffer)
                if not e then break end
                table.insert(pulled, 1, e)
            end
            if #pulled == 0 then return false end
            flush_buffer()
            wrap_to_next_column(ctx, p_cols, interval, grid_height, indent, false, false)
            -- Apply indent: wrap_to_next_column resets cur_row to 0 but
            -- does not apply paragraph indentation for the new column
            if indent and indent > 0 and ctx.cur_row < indent then
                ctx.cur_row = indent
                ctx.cur_column_indent = indent
                ctx.cur_y_sp = ctx.cur_row * grid_height
            end
            for _, e in ipairs(pulled) do
                e.page = ctx.cur_page
                e.col = ctx.cur_col
                e.relative_row = ctx.cur_y_sp / grid_height
                e.y_sp = ctx.cur_y_sp
                table.insert(col_buffer, e)
                ctx.cur_row = ctx.cur_row + 1
                ctx.cur_y_sp = ctx.cur_row * grid_height
            end
            ctx.page_has_content = true
            return true
        end

        -- Strategy 0: 下一个字与列尾字同属两字幅标点单元（—— …… ？！）。
        -- clreq 符号分离禁则：这类符号占两个汉字宽度，是一个整体，断在中间
        -- 就把一个符号劈成了两半。把列尾这半（若是 ——— 这样的长串则是整
        -- 个尾串）一起带到下一列。
        local next_glyph = find_next_glyph(t)
        if next_glyph and #col_buffer > 0
                and D.get_attribute(next_glyph, constants.ATTR_RIGID_PREV) == 2 then
            -- 至少留一个字在本列，否则空列 → 死循环
            local n = 0
            while n < #col_buffer - 1 do
                n = n + 1
                local e = col_buffer[#col_buffer - n + 1]
                if D.get_attribute(e.node, constants.ATTR_RIGID_PREV) ~= 2 then
                    break
                end
            end
            if n > 0 and pull_tail(n) then
                dbg.log(string.format(
                    "kinsoku: 两字幅单元不拆开，尾部 %d 字随下一字移入新列 [p:%d c:%d]",
                    n, ctx.cur_page, ctx.cur_col))
                return
            end
        end

        -- Strategy 1: Check if next visible glyph is line-start-forbidden
        if next_glyph then
            local next_char = D.getfield(next_glyph, "char")
            local next_ptype = punct.classify(next_char)

            if next_ptype and punct.is_line_start_forbidden(next_ptype) then
                -- Next character cannot start a new column.
                -- Pull the last character from col_buffer and move both to new column.
                if pull_tail(1) then
                    dbg.log(string.format(
                        "kinsoku: pulled char to new col (next=0x%04X type=%s) [p:%d c:%d]",
                        next_char, next_ptype, ctx.cur_page, ctx.cur_col))
                end
                return
            end
        end

        -- Strategy 2: Check if current character (last in buffer) is line-end-forbidden
        if #col_buffer > 0 then
            local last_entry = col_buffer[#col_buffer]
            local last_char = D.getfield(last_entry.node, "char")
            local last_ptype = punct.classify(last_char)

            if last_ptype and punct.is_line_end_forbidden(last_ptype) then
                -- Current character (opening bracket) cannot end a column.
                pull_tail(1)
                dbg.log(string.format(
                    "kinsoku: moved line-end-forbidden char to new col (0x%04X type=%s) [p:%d c:%d]",
                    last_char, last_ptype, ctx.cur_page, ctx.cur_col))
                return
            end
        end
    end
end

-- ============================================================================
-- Configuration
-- ============================================================================

--- Setup function called from TeX layer to sync configuration
-- @param cfg (table) Configuration table
function punct.setup(cfg)
    _G.punct = _G.punct or {}
    if cfg.style then _G.punct.style = cfg.style end
    if cfg.squeeze ~= nil then _G.punct.squeeze = cfg.squeeze end
    if cfg.hanging ~= nil then _G.punct.hanging = cfg.hanging end
    if cfg.kinsoku ~= nil then _G.punct.kinsoku = cfg.kinsoku end
    -- clreq 上下文相关宽度调整（squeeze_mode = "legacy" | "context"）
    if cfg.squeeze_mode then _G.punct.squeeze_mode = cfg.squeeze_mode end
    if cfg.adjacent_punct then _G.punct.adjacent_punct = cfg.adjacent_punct end
    if cfg.line_start_bracket then
        _G.punct.line_start_bracket = cfg.line_start_bracket
    end
    if cfg.line_end_punct then _G.punct.line_end_punct = cfg.line_end_punct end
end

-- ============================================================================
-- Plugin Standard API
-- ============================================================================

--- Initialize Punctuation Plugin
-- @param params (table) Parameters from TeX
-- @param engine_ctx (table) Shared engine context
-- @param plugin_contexts (table) Already-initialized plugin contexts (judou must init before punct)
-- @return (table|nil) Plugin context, or nil to disable
function punct.initialize(params, engine_ctx, plugin_contexts)
    -- Read punct mode from judou plugin context (judou initializes before punct)
    local judou_ctx = plugin_contexts and plugin_contexts["judou"]
    local mode = judou_ctx and judou_ctx.punct_mode or "normal"

    if mode ~= "normal" then
        dbg.log("punct plugin: disabled (punct_mode=" .. tostring(mode) .. ")")
        return nil
    end

    local style = (_G.punct and _G.punct.style) or "mainland"
    local ctx = {
        style   = style,
        -- style=none 是 clreq「不调整」预设：既不挤压也不偏靠
        squeeze = (style ~= "none")
            and not (_G.punct and _G.punct.squeeze == false), -- default true
        hanging = (_G.punct and _G.punct.hanging) or false,     -- default false
        kinsoku = not (_G.punct and _G.punct.kinsoku == false), -- default true
        -- clreq 上下文相关宽度调整。默认 legacy = 现行无条件挤压，
        -- 保证 ltc-guji 版面零变化（CLREQ-GAP-ANALYSIS R5 分档）；
        -- vbook 两个类在配置里切到 context。
        squeeze_mode = (_G.punct and _G.punct.squeeze_mode) or "legacy",
        adjacent_punct = (_G.punct and _G.punct.adjacent_punct) or "1.5",
        line_start_bracket = (_G.punct and _G.punct.line_start_bracket) or "trim",
        line_end_punct = (_G.punct and _G.punct.line_end_punct) or "compress",
    }

    dbg.log(string.format(
        "punct plugin: enabled (style=%s, squeeze=%s/%s, kinsoku=%s, hanging=%s)",
        ctx.style,
        tostring(ctx.squeeze),
        ctx.squeeze_mode,
        tostring(ctx.kinsoku),
        tostring(ctx.hanging)))

    return ctx
end

-- ============================================================================
-- Context-sensitive squeeze annotation (clreq 标点符号的宽度调整)
-- ============================================================================

--- Build the shared-layer options table from the plugin context.
-- @param ctx (table) Plugin context
-- @return (table) opts for shared.luatex-cn-punct-squeeze
local function squeeze_opts(ctx)
    return {
        style = ctx.style,
        mode = "vertical",
        adjacent_punct = ctx.adjacent_punct,
        line_start_bracket = ctx.line_start_bracket,
        line_end_punct = ctx.line_end_punct,
    }
end

--- Annotate every punctuation glyph with the blank it may reclaim, judged
-- from its neighbours (clreq: 只有相邻标点连排才无条件缩减；夹在汉字之间
-- 的标点占满一字幅). 行首/行尾的收回量要等断列结果才知道，留给 P2 的
-- flush_buffer 接线（见 docs/CLREQ-VERTICAL-ADJUST-DESIGN.md）。
-- @param seq (table) {{node, char, punct}, ...} in list order
-- @param ctx (table) Plugin context
-- @return (number) how many glyphs were annotated
local function annotate_context_squeeze(seq, ctx)
    if ctx.squeeze_mode ~= "context" or not ctx.squeeze then return 0 end
    local opts = squeeze_opts(ctx)
    local count = 0
    -- 脚注标号组（︻一︼）整组不参与标点宽度调整：组内字幅由 flush_buffer 的
    -- marker 预处理按组高分配，不是正文字幅，再叠加收回量会把组内的括号挤歪；
    -- 组外的标点也不该把标号的括号当作行文中的夹注符号来做连续标点缩减
    -- （clreq 的连续标点缩减针对夹注符号，注释记号是另一回事）。
    -- 因此把整组视作不透明：组内不标注，组外判定时它既不是标点也不是汉字。
    local is_marker = {}
    for i, item in ipairs(seq) do
        local marker = D.get_attribute(item.node, constants.ATTR_FOOTNOTE_MARKER)
        is_marker[i] = (marker and marker > 0) or false
    end

    for i, item in ipairs(seq) do
        if item.punct and not is_marker[i] then
            local prev_c = (not is_marker[i - 1]) and seq[i - 1]
                and seq[i - 1].char or nil
            local next_c = (not is_marker[i + 1]) and seq[i + 1]
                and seq[i + 1].char or nil
            local plan = punct_squeeze.plan(prev_c, item.char, next_c, nil, opts)
            D.set_attribute(item.node, constants.ATTR_PUNCT_SQUEEZE,
                1 + math.floor(plan.total * 1000 + 0.5))
            D.set_attribute(item.node, constants.ATTR_PUNCT_SQUEEZE_HEAD,
                1 + math.floor(plan.head * 1000 + 0.5))
            -- 潜在空白与挤压类别：相邻规则强制收回的只是其中一部分，余量留给
            -- flush_buffer 的求解器按 clreq 优先顺序处置（P2 接线）。
            local blank_head, blank_tail = punct_squeeze.blanks(item.char, opts)
            local blank_total = blank_head + blank_tail
            if blank_total > 0 then
                D.set_attribute(item.node, constants.ATTR_PUNCT_BLANK,
                    1 + math.floor(blank_total * 1000 + 0.5))
                D.set_attribute(item.node, constants.ATTR_PUNCT_BLANK_HEAD,
                    1 + math.floor(blank_head * 1000 + 0.5))
                local cls = shared_punct.shrink_class_of(item.char, opts.style,
                    "vertical")
                local cls_idx = cls and SHRINK_CLASS_INDEX[cls]
                if cls_idx then
                    D.set_attribute(item.node,
                        constants.ATTR_PUNCT_SHRINK_CLASS, 1 + cls_idx)
                end
                -- 落在列首 / 列末时的额外收回量（设计 §2.3）：断列结果这里还
                -- 不知道，先把两种情形各算一遍，差额留给 flush_buffer 取用。
                local at_start = punct_squeeze.plan(prev_c, item.char, next_c,
                    { at_line_start = true }, opts)
                local at_end = punct_squeeze.plan(prev_c, item.char, next_c,
                    { at_line_end = true }, opts)
                local d_start = at_start.head - plan.head
                local d_end = at_end.tail - plan.tail
                if d_start > 0 then
                    D.set_attribute(item.node, constants.ATTR_PUNCT_TRIM_START,
                        1 + math.floor(d_start * 1000 + 0.5))
                end
                if d_end > 0 then
                    D.set_attribute(item.node, constants.ATTR_PUNCT_TRIM_END,
                        1 + math.floor(d_end * 1000 + 0.5))
                end
            end
            count = count + 1
        end
    end
    return count
end

-- 刚性单元（clreq 符号分离禁则）的原因标签：这些边界不只是「不能断」，
-- 而是「内部不能有任何伸缩」——两字幅标点、数字串、数字+单位、正负号+数字、
-- 货币符号+数字、西文单词。行首/行尾禁则不在此列（「一。」不能断开，但
-- 「一」与「。」之间的间距照常参与调整）。与横排 hori-spacing 的
-- RIGID_REASONS 同一份口径。
local RIGID_REASONS = {
    unbreakable_pair = true,
    digit_run = true,
    digit_suffix = true,
    sign_prefix = true,
    currency = true,
    western_word = true,
}

--- 标注刚性单元边界：字符 i 与 i−1 同属一个不可分单元时，在 i 上打标记。
-- layout 阶段据此把该边界上的字距与两侧标点空白全部锁死（横排的教训：
-- 叠加符号自带可挤空白，只清 stretch 不清 shrink 会让两字幅单元被压扁）。
--
-- 属性取值区分两档，因为竖排对两者的处置不同：
--   1 = 一般刚性单元（数字串、西文词……）：锁死既有字距即可
--   2 = 两字幅标点单元（—— …… ？！）：字距还要**归零**。clreq 说它「占两个
--       汉字宽度」，中间夹 0.1em 竖排字距就成了 2.1em，破折号还会现出断口。
--       横排 hori-spacing 的 CJK 间边界本来就是 width=0，这里对齐同一口径。
-- @param seq (table) {{node, char, punct}, ...}
-- @return (number) 标注的边界数
local function annotate_rigid_units(seq)
    local count = 0
    for i = 2, #seq do
        local prev_c, cur_c = seq[i - 1].char, seq[i].char
        local _, reason = kinsoku.no_break_between(prev_c, cur_c)
        if reason and RIGID_REASONS[reason] then
            local two_em = shared_punct.is_unbreakable_pair(prev_c, cur_c)
            D.set_attribute(seq[i].node, constants.ATTR_RIGID_PREV,
                two_em and 2 or 1)
            -- 连排破折号的两端都要标记：render 把每一段的墨迹拉满字幅，
            -- 串起来才是一条不断的线（省略号不在此列——…… 的墨迹是圆点，
            -- 拉伸只会把点扯成椭圆）
            if two_em and shared_punct.class_of(cur_c) == "dash" then
                D.set_attribute(seq[i - 1].node, constants.ATTR_DASH_RUN, 1)
                D.set_attribute(seq[i].node, constants.ATTR_DASH_RUN, 1)
            end
            count = count + 1
        end
    end
    return count
end

--- Flatten stage: classify punctuation and replace vertical quotes
-- @param head (node) The node list head
-- @param params (table) Parameters
-- @param ctx (table) Plugin context
-- @return (node) The modified head
function punct.flatten(head, params, ctx)
    if not ctx then return head end

    local d_head = D.todirect(head)
    local t = d_head
    local count_classified = 0
    local count_replaced = 0
    -- 字符序列（逻辑码位，直排字形替换与 PUA 还原之前的那一个），
    -- 供 flatten 之后的上下文判定使用。非字形节点视为透明。
    local seq = {}

    while t do
        local id = D.getid(t)
        local next_node = D.getnext(t)

        if id == constants.GLYPH then
            -- Skip decoration characters (e.g. 。、used as decorate markers)
            local dec_id = D.get_attribute(t, constants.ATTR_DECORATE_ID)
            if not (dec_id and dec_id > 0) then
                local char = D.getfield(t, "char")
                local logical_char = char

                -- 0. 拆解破折号合字（⸺/⸻ 或 ccmp 派生的 PUA 字形），还原成
                -- N 个 em dash，各自走下面的标准流程
                local n_dash = punct.dash_ligature_count(D.getfont(t), char)
                if n_dash then
                    D.setfield(t, "char", 0x2014)
                    char = 0x2014
                    logical_char = 0x2014
                    for _ = 2, n_dash do
                        D.insert_after(d_head, t, D.copy(t))
                    end
                    -- 复制品排在 t 之后，下一轮循环依次处理
                    next_node = D.getnext(t)
                    count_replaced = count_replaced + 1
                    dbg.log(string.format(
                        "punct: 破折号合字拆解为 %d 个 em dash", n_dash))
                end

                -- 1. Vertical form replacement: brackets/quotes → vertical presentation forms
                local vert_char = VERT_FORM_MAP[char]
                if vert_char then
                    -- Check font has the target glyph before replacing
                    local fid = D.getfont(t)
                    local fdata = font.getfont(fid)
                    if fdata and fdata.characters and fdata.characters[vert_char] then
                        D.setfield(t, "char", vert_char)
                        char = vert_char
                        count_replaced = count_replaced + 1
                    else
                        -- Font lacks vertical glyph - mark for rotation fallback
                        -- Only rotate horizontally-oriented glyphs (ellipsis, em dash)
                        if char == 0x2026 or char == 0x2014 then
                            D.set_attribute(t, constants.ATTR_VERT_ROTATE, 1)
                            dbg.log(string.format("marked for rotation: char=0x%04X", char))
                        end
                    end
                end

                -- 2. Classify punctuation and set attribute
                local ptype = punct.classify(char)

                -- 2b. If classification failed, the char may have been GSUB-substituted
                -- by the font's vert/vrt2 feature to a PUA codepoint. Try to resolve
                -- the original Unicode codepoint via the glyph's tounicode field.
                if not ptype then
                    local fid = D.getfont(t)
                    local orig = resolve_original_codepoint(fid, char)
                    if orig then
                        ptype = punct.classify(orig)
                        if ptype then
                            logical_char = orig
                            dbg.log(string.format(
                                "punct: resolved PUA 0x%05X -> 0x%04X (%s) via tounicode",
                                char, orig, ptype))
                        end
                    end
                end

                if ptype then
                    local code = PUNCT_CODES[ptype]
                    D.set_attribute(t, constants.ATTR_PUNCT_TYPE, code)
                    count_classified = count_classified + 1
                end

                seq[#seq + 1] = { node = t, char = logical_char, punct = ptype ~= nil }
            end
        end

        t = next_node
    end

    local count_context = annotate_context_squeeze(seq, ctx)
    local count_rigid = annotate_rigid_units(seq)

    if count_classified > 0 or count_replaced > 0 then
        dbg.log(string.format(
            "punct flatten: classified=%d, quotes_replaced=%d, context_squeeze=%d, rigid=%d",
            count_classified, count_replaced, count_context, count_rigid))
    end

    return D.tonode(d_head)
end

-- ============================================================================
-- Punctuation Squeeze (CLREQ Standard)
-- ============================================================================

--- Check if a punctuation type has trailing half-width space
-- (close brackets, fullstop, comma all have glyph in first half, space in second)
local function has_trailing_space(ptype)
    return ptype == "close" or ptype == "fullstop" or ptype == "comma"
end

--- Check if a punctuation type has leading half-width space
-- (open brackets have space in first half, glyph in second)
local function has_leading_space(ptype)
    return ptype == "open"
end

--- Default squeeze amount (0.5 = half grid cell)
local DEFAULT_SQUEEZE = 0.5

--- Per-character squeeze overrides (default is 0.5 = occupy half grid cell)
local CHAR_SQUEEZE = {
    [0x3002] = 0,  -- 。fullstop: full cell (no squeeze)
    [0xFF0E] = 0,  -- ．fullstop: full cell (no squeeze)
}

--- Get the punctuation type for a node from its attribute
-- @param node_d (direct node) The node
-- @return (string|nil) Punctuation type name
local function get_node_punct_type(node_d)
    local code = D.get_attribute(node_d, constants.ATTR_PUNCT_TYPE)
    if code and code > 0 then
        return PUNCT_NAMES[code]
    end
    return nil
end

--- Layout stage: post-process layout_map for squeeze adjustments
-- Scans each column for consecutive punctuation and adjusts row positions.
-- @param list (node) The node list
-- @param layout_map (table) Layout map (node → position)
-- @param engine_ctx (table) Engine context
-- @param ctx (table) Plugin context
function punct.layout(list, layout_map, engine_ctx, ctx)
    if not ctx then return end
    if not ctx.squeeze then return end
    local context_mode = (ctx.squeeze_mode == "context")
    -- Taiwan style (legacy mode): no squeeze — all punctuation occupies a full
    -- grid cell. In context mode 台湾式仍适用 clreq 的连续标点缩减
    -- （「无论文本整体采用何种风格」），故不再整体跳过。
    if ctx.style == "taiwan" and not context_mode then return end
    -- Natural mode (no default_cell_height) handles punctuation sizing via
    -- get_cell_height() in layout-grid; squeeze post-processing would overwrite
    -- those carefully computed values.
    if not engine_ctx.default_cell_height then return end
    -- Note: punct-hanging requires deeper integration with layout-grid.lua
    -- to allow dot-class punctuation to overflow beyond effective_limit.
    -- This will be implemented in a future version.

    -- Collect all layout entries with their node references, grouped by (page, col)
    local columns = {} -- key: "page:col" → sorted list of {node, pos, ptype}

    for node_d, pos in pairs(layout_map) do
        -- Only process nodes that have y_sp (actual positioned content)
        if pos.y_sp then
            local ptype = get_node_punct_type(node_d)
            local key = string.format("%d:%d", pos.page, pos.col)
            if not columns[key] then
                columns[key] = {}
            end
            table.insert(columns[key], {
                node = node_d,
                pos = pos,
                ptype = ptype, -- may be nil for non-punct
            })
        end
    end

    local total_squeezed = 0
    local grid_height = engine_ctx.g_height

    -- Process each column
    for _, col_entries in pairs(columns) do
        -- Sort by y_sp position
        table.sort(col_entries, function(a, b)
            return a.pos.y_sp < b.pos.y_sp
        end)

        -- Sequential cell placement: each character occupies a cell of a certain
        -- height. Punctuation cells are shorter (squeezed), but cells NEVER overlap.
        -- accumulated_squeeze_sp tracks total sp saved so far, so subsequent
        -- characters shift up by that amount.
        local accumulated_squeeze_sp = 0
        local prev_orig_y_sp = nil
        local prev_ptype = nil

        for _, entry in ipairs(col_entries) do
            local curr_ptype = entry.ptype
            local squeeze_amount = 0

            -- Close gaps caused by invisible spacing nodes (e.g. TeX newlines
            -- between sentences). Only close gaps that follow punctuation marks,
            -- as these are almost always interword spaces rather than intentional
            -- paragraph spacing.
            local orig_y_sp = entry.pos.y_sp
            if prev_orig_y_sp and prev_ptype then
                local gap_sp = orig_y_sp - prev_orig_y_sp - grid_height
                if gap_sp > 0 then
                    accumulated_squeeze_sp = accumulated_squeeze_sp + gap_sp
                end
            end
            prev_orig_y_sp = orig_y_sp
            prev_ptype = curr_ptype

            -- Determine squeeze for this entry
            if context_mode then
                -- clreq 上下文相关：收回量已由 flatten 阶段按相邻上下文算好
                local attr = D.get_attribute(entry.node,
                    constants.ATTR_PUNCT_SQUEEZE)
                if attr and attr > 1 then
                    squeeze_amount = (attr - 1) / 1000
                    total_squeezed = total_squeezed + 1
                end
            elseif curr_ptype then
                if has_leading_space(curr_ptype) or has_trailing_space(curr_ptype) then
                    local char = D.getfield(entry.node, "char")
                    squeeze_amount = (char and CHAR_SQUEEZE[char]) or DEFAULT_SQUEEZE
                    total_squeezed = total_squeezed + 1
                end
            end

            -- Cell height for this entry (in sp)
            local cell_height_sp = math.floor((1.0 - squeeze_amount) * grid_height + 0.5)

            -- Shift up by accumulated squeeze (cells are sequential, no overlap)
            entry.pos.y_sp = entry.pos.y_sp - accumulated_squeeze_sp

            -- Store cell height (sp) for render stage to use for centering
            entry.pos.cell_height = cell_height_sp

            -- Accumulate squeeze for subsequent entries (in sp)
            accumulated_squeeze_sp = accumulated_squeeze_sp + math.floor(squeeze_amount * grid_height + 0.5)
        end
    end

    if total_squeezed > 0 then
        dbg.log(string.format("punct layout: squeezed %d punctuation marks", total_squeezed))
    end
end

-- ============================================================================
-- Punctuation Style Positioning (Mainland vs Taiwan)
-- ============================================================================

-- Mainland style: dot-class punctuation (fullstop, comma) offset toward
-- the upper-right corner of the grid cell (when viewed in vertical layout).
-- In the coordinate system:
--   x offset > 0 = rightward (toward the column's outer edge)
--   y offset > 0 = upward
-- The offset is expressed as a fraction of grid dimensions.
local MAINLAND_OFFSETS = {
    fullstop = { x = 0.20, y = 0.25 }, -- 。full cell, upper-right
    comma    = { x = 0.20, y = 0 },   -- ，、 half cell, right-shifted
    middle   = { x = 0.20, y = 0 },   -- ：；！？ right-shifted
    open     = { x = 0, y = 0 },       -- 「【（ centered in cell by calc_grid_position
    close    = { x = 0, y = 0 },       -- 」】）centered in cell by calc_grid_position
}

-- 度量驱动的字面分布（差距分析 4.1 第 5 条）：不再「经验偏移 + 部分字体
-- 补偿」，而是直接把字形**墨迹**锚到字幅内的规范位置。锚点表与位移计算
-- 在共享层 shared/luatex-cn-punct-anchors.lua（HR5：clreq 规则只写在
-- tex/shared/，横排 hori-pipeline 用同一模块）：
--   中国大陆式直排：点号偏靠右上（x=0.857，贴前字）；
--   台湾式：字面居中——**字体自己居不居中无所谓**：中国大陆惯例设计的字体
--   （思源宋体、京華老宋体）横排形在左下、vert 形在右上，不锚定的话
--   台湾式版面会随字体漂移。
-- 教训：锚点不能从 Tm 相对坐标量——xoffset 会写进 Tm，量出来的只是
-- 字形自身的 bbox 中心，偏靠会整个丢失、退化为居中。
-- 无 boundingbox 可查时，中国大陆式退回上面的经验偏移路径，台湾式不动。

--- Render stage: apply punctuation style offsets
-- Anchors the ink of dot/middle punctuation per style (mainland 偏靠 /
-- taiwan 居中). style=none is the clreq 不调整 preset — no offsets.
-- @param head (node) The page node list head
-- @param layout_map (table) Layout map
-- @param render_ctx (table) Render context
-- @param ctx (table) Plugin context
-- @param engine_ctx (table) Engine context
-- @param page_idx (number) Current page index
-- @param p_total_cols (number) Total columns on this page
-- @return (node) The modified head
function punct.render(head, layout_map, render_ctx, ctx, engine_ctx, page_idx, p_total_cols)
    if not ctx then return head end

    -- style=none：clreq 不调整预设，字面不挪动。
    -- 台湾式的度量锚定只在 context 挡位（vbook 类）启用：ltc-guji 默认
    -- taiwan + legacy，字面位置维持字体原样（R5：古籍版面不动）。
    -- 中国大陆式沿 #138 的口径不加挡位（现存中国大陆式文档类均为 context）。
    local do_taiwan = (ctx.style == "taiwan" and ctx.squeeze_mode == "context")
    if ctx.style ~= "mainland" and not do_taiwan then return head end

    -- Mainland style: offset dot-class punctuation
    local grid_width = engine_ctx.g_width
    local grid_height = engine_ctx.g_height

    local d_head = D.todirect(head)
    local t = d_head
    local count = 0

    while t do
        local id = D.getid(t)
        if id == constants.GLYPH then
            local pos = layout_map[t]
            if pos and pos.page == page_idx then
                local ptype = get_node_punct_type(t)
                local style_offset = ptype and MAINLAND_OFFSETS[ptype]

                if style_offset then
                    -- Read current offsets and add style adjustment
                    local cur_x = D.getfield(t, "xoffset") or 0
                    local cur_y = D.getfield(t, "yoffset") or 0

                    local char = D.getfield(t, "char")
                    local fid = D.getfield(t, "font")

                    -- 度量驱动路径：有墨迹 bbox 就直接锚定，跳过下面的
                    -- 「经验偏移 + 字体补偿」。锚点表按**原始码位**查
                    -- （vert GSUB 落到 PUA 的字形先解析回来），bbox 用
                    -- 实际绘制的字形查。
                    local metric_done = false
                    if fid and char then
                        local fi = font.getfont(fid)
                        local desc = fi and fi.descriptions and fi.descriptions[char]
                        local bb = desc and desc.boundingbox
                        local upem = fi and fi.units_per_em or 1000
                        local em_sp = fi and fi.size
                        local orig = char
                        if char >= 0xE000 then
                            orig = resolve_original_codepoint(fid, char) or char
                        end
                        local dx, dy = punct_anchors.offsets(
                            orig, ctx.style, "vertical", bb, upem, em_sp)
                        if dx then
                            D.setfield(t, "xoffset", cur_x + dx)
                            D.setfield(t, "yoffset", cur_y + dy)
                            count = count + 1
                            metric_done = true
                        end
                        -- 夹注号：字面归到上/下半格（clreq 图 30，两风格同值）。
                        -- 位移相对引擎落点算，见 punct_anchors.vert_bracket_dy。
                        -- 字体缺竖排形时引擎自己旋转字形（ATTR_VERT_ROTATE），
                        -- 位置写在 pdf_literal 的变换矩阵里、xoffset/yoffset 被清零，
                        -- 这里挪不动它——那条退路仍是字面居中。
                        -- 脚注标号组（︻一︼）同样不参与：组内字幅由 flush_buffer
                        -- 按组高分配、括号已按真实墨迹缩放居中（#134），再挪半格
                        -- 会把一对括号推出组外。
                        local is_marker =
                            (D.get_attribute(t, constants.ATTR_FOOTNOTE_MARKER) or 0) > 0
                        if not metric_done and em_sp and em_sp > 0 and not is_marker
                            and D.get_attribute(t, constants.ATTR_VERT_ROTATE) ~= 1 then
                            local h_em = (D.getfield(t, "height") or 0) / em_sp
                            local d_em = (D.getfield(t, "depth") or 0) / em_sp
                            local dy_em = punct_anchors.vert_bracket_dy(
                                ptype, bb, upem, h_em, d_em)
                            if dy_em then
                                D.setfield(t, "yoffset",
                                    cur_y + math.floor(dy_em * em_sp + 0.5))
                                count = count + 1
                                metric_done = true
                            end
                        end
                    end

                    -- Font ink-center compensation: some fonts have punctuation
                    -- glyphs whose ink is not centered in the advance width.
                    -- Compensate so the glyph visually centers before applying
                    -- the mainland style offset.
                    -- 经验偏移是中国大陆式的退路；台湾式无 bbox 时不动（字体原样）。
                    local glyph_width = grid_width -- fallback
                    if not metric_done and ctx.style == "mainland" and fid and char then
                        local fi = font.getfont(fid)
                        local ci = fi and fi.characters and fi.characters[char]
                        if ci and ci.width then glyph_width = ci.width end

                        local needs_ink_comp = INK_CENTER_CHARS[char]
                        local is_pua_char = false
                        if not needs_ink_comp then
                            local orig = resolve_original_codepoint(fid, char)
                            if orig and INK_CENTER_CHARS[orig] then
                                needs_ink_comp = true
                                is_pua_char = true  -- This is a PUA char (vert GSUB substituted)
                            end
                        end
                        if needs_ink_comp then
                            local ratio_x, ratio_y = get_ink_center_ratio(fid, char)
                            -- X-axis compensation: ink left of center → shift right (positive offset)
                            -- ratio_x < 0.5 means ink is left → (0.5 - ratio_x) > 0 → shift right
                            local comp_x = math.floor((0.5 - ratio_x) * glyph_width + 0.5)
                            cur_x = cur_x + comp_x

                            -- Y-axis compensation: ONLY for PUA chars (vert GSUB substituted glyphs)
                            -- Normal fonts have well-centered punctuation, but vert forms from
                            -- fonts like KingHwa_OldSong may have significant y-axis deviation.
                            -- ratio_y > 0.5 means ink is high → negative offset shifts down
                            if is_pua_char then
                                local y_deviation = math.abs(ratio_y - 0.5)
                                if y_deviation > 0.03 then
                                    -- Use 1.5x multiplier for stronger downward compensation
                                    -- Note: positive yoffset moves UP, so we need (0.5 - ratio_y) for downward
                                    local comp_y = math.floor((0.5 - ratio_y) * glyph_width * 1.5 + 0.5)
                                    cur_y = cur_y + comp_y
                                end
                            end
                        end
                    end

                    -- 偏靠量按**该字自身的字幅**计，不是版面网格：夹注、
                    -- 批注、脚注等小字的字幅小于正文，用版面网格算会让小字
                    -- 的标点偏出所在列（偏移量固定而字幅变小）。
                    if not metric_done and ctx.style == "mainland" then
                        local own_w, own_h = grid_width, grid_height
                        if fid then
                            local fi = font.getfont(fid)
                            local fs = fi and fi.size
                            if fs and fs > 0 and grid_height > 0 then
                                local scale = fs / grid_height
                                own_w = grid_width * scale
                                own_h = fs
                            end
                        end
                        local dx = math.floor(own_w * style_offset.x + 0.5)
                        local dy = math.floor(own_h * style_offset.y + 0.5)

                        D.setfield(t, "xoffset", cur_x + dx)
                        D.setfield(t, "yoffset", cur_y + dy)
                        count = count + 1
                    end
                end
            end
        end
        t = D.getnext(t)
    end

    if count > 0 then
        dbg.log(string.format("punct render: applied mainland offsets to %d marks (page %d)",
            count, page_idx))
    end

    return D.tonode(d_head)
end

-- Export internal functions for unit testing
punct._internal = {
    parse_tounicode = parse_tounicode,
    annotate_rigid_units = annotate_rigid_units,
    resolve_original_codepoint = resolve_original_codepoint,
    get_ink_center_ratio = get_ink_center_ratio,
    INK_CENTER_CHARS = INK_CENTER_CHARS,
    font_tounicode_cache = font_tounicode_cache,
    font_ink_center_cache = font_ink_center_cache,
}

return punct
