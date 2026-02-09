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
local dbg = debug_mod.get_debugger('punct')

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

--- Get ink center ratio for a glyph in a given font.
-- Returns the horizontal center of the glyph ink as a ratio of advance width.
-- For a perfectly centered glyph this is 0.5.
-- @param fid (number) Font ID
-- @param charcode (number) Unicode codepoint
-- @return (number) Ink center ratio (0..1), or 0.5 if unknown
local function get_ink_center_ratio(fid, charcode)
    -- Check cache first
    local font_cache = font_ink_center_cache[fid]
    if font_cache then
        local ratio = font_cache[charcode]
        if ratio then return ratio end
        -- Already analyzed this font but char not found
        if font_cache._analyzed then return 0.5 end
    end

    -- Analyze font using fontloader
    font_ink_center_cache[fid] = font_ink_center_cache[fid] or {}
    font_cache = font_ink_center_cache[fid]
    font_cache._analyzed = true

    local f = font.getfont(fid)
    if not f or not f.filename then return 0.5 end

    local ok, raw = pcall(fontloader.open, f.filename)
    if not ok or not raw then return 0.5 end

    local ok2, info = pcall(fontloader.to_table, raw)
    fontloader.close(raw)
    if not ok2 or not info or not info.glyphs then return 0.5 end

    -- Scan all glyphs for target characters
    for i = 0, (info.glyphcnt or 0) - 1 do
        local g = info.glyphs[i]
        if g and g.unicode and INK_CENTER_CHARS[g.unicode] and g.width and g.width > 0 then
            if g.boundingbox then
                local cx = (g.boundingbox[1] + g.boundingbox[3]) / 2
                font_cache[g.unicode] = cx / g.width
            end
        end
    end

    dbg.log(string.format("punct: analyzed font %d ink centers: %s",
        fid, f.filename))

    return font_cache[charcode] or 0.5
end

-- ============================================================================
-- Punctuation Character Classification (CLREQ / JLREQ reference)
-- ============================================================================

-- CL_OPEN: Opening brackets / quotes
-- Characterized by: half-width glyph + leading half-width space
local CL_OPEN = {
    [0x300C] = true, -- 「 left corner bracket
    [0x300E] = true, -- 『 left white corner bracket
    [0xFF08] = true, -- （ fullwidth left parenthesis
    [0x3008] = true, -- 〈 left angle bracket
    [0x300A] = true, -- 《 left double angle bracket
    [0x3010] = true, -- 【 left black lenticular bracket
    [0x3014] = true, -- 〔 left tortoise shell bracket
    [0x201C] = true, -- " left double quotation mark
    [0x2018] = true, -- ' left single quotation mark
    -- Vertical presentation forms (after replacement)
    [0xFE41] = true, -- ﹁ vertical left corner bracket
    [0xFE43] = true, -- ﹃ vertical left white corner bracket
    [0xFE35] = true, -- ︵ vertical left parenthesis
    [0xFE39] = true, -- ︹ vertical left tortoise shell bracket
    [0xFE3B] = true, -- ︻ vertical left black lenticular bracket
    [0xFE3D] = true, -- ︽ vertical left double angle bracket
    [0xFE3F] = true, -- ︿ vertical left angle bracket
}

-- CL_CLOSE: Closing brackets / quotes
-- Characterized by: half-width glyph + trailing half-width space
local CL_CLOSE = {
    [0x300D] = true, -- 」 right corner bracket
    [0x300F] = true, -- 』 right white corner bracket
    [0xFF09] = true, -- ） fullwidth right parenthesis
    [0x3009] = true, -- 〉 right angle bracket
    [0x300B] = true, -- 》 right double angle bracket
    [0x3011] = true, -- 】 right black lenticular bracket
    [0x3015] = true, -- 〕 right tortoise shell bracket
    [0x201D] = true, -- " right double quotation mark
    [0x2019] = true, -- ' right single quotation mark
    -- Vertical presentation forms
    [0xFE42] = true, -- ﹂ vertical right corner bracket
    [0xFE44] = true, -- ﹄ vertical right white corner bracket
    [0xFE36] = true, -- ︶ vertical right parenthesis
    [0xFE3A] = true, -- ︺ vertical right tortoise shell bracket
    [0xFE3C] = true, -- ︼ vertical right black lenticular bracket
    [0xFE3E] = true, -- ︾ vertical right double angle bracket
    [0xFE40] = true, -- ﹀ vertical right angle bracket
}

-- CL_FULLSTOP: Full stops (period-like)
-- Characterized by: half-width glyph + trailing half-width space
local CL_FULLSTOP = {
    [0x3002] = true, -- 。 ideographic full stop
    [0xFF0E] = true, -- ． fullwidth full stop
}

-- CL_COMMA: Commas and enumeration comma
-- Characterized by: half-width glyph + trailing half-width space
local CL_COMMA = {
    [0xFF0C] = true, -- ， fullwidth comma
    [0x3001] = true, -- 、 ideographic comma (enumeration)
}

-- CL_MIDDLE: Colon, semicolon, exclamation, question
-- Full-width, centered
local CL_MIDDLE = {
    [0xFF1A] = true, -- ： fullwidth colon
    [0xFF1B] = true, -- ； fullwidth semicolon
    [0xFF01] = true, -- ！ fullwidth exclamation mark
    [0xFF1F] = true, -- ？ fullwidth question mark
}

-- CL_NOBREAK: Non-breakable characters (must stay together when consecutive)
local CL_NOBREAK = {
    [0x2014] = true, -- — em dash
    [0x2026] = true, -- … horizontal ellipsis
}

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
    if CL_OPEN[char_code] then return "open" end
    if CL_CLOSE[char_code] then return "close" end
    if CL_FULLSTOP[char_code] then return "fullstop" end
    if CL_COMMA[char_code] then return "comma" end
    if CL_MIDDLE[char_code] then return "middle" end
    if CL_NOBREAK[char_code] then return "nobreak" end
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

        -- Strategy 1: Check if next visible glyph is line-start-forbidden
        local next_glyph = find_next_glyph(t)
        if next_glyph then
            local next_char = D.getfield(next_glyph, "char")
            local next_ptype = punct.classify(next_char)

            if next_ptype and punct.is_line_start_forbidden(next_ptype) then
                -- Next character cannot start a new column.
                -- Pull the last character from col_buffer and move both to new column.
                local pulled = table.remove(col_buffer)
                if pulled then
                    flush_buffer()
                    wrap_to_next_column(ctx, p_cols, interval, grid_height, indent, false, false)
                    -- Apply indent: wrap_to_next_column resets cur_row to 0 but
                    -- does not apply paragraph indentation for the new column
                    if indent and indent > 0 and ctx.cur_row < indent then
                        ctx.cur_row = indent
                        ctx.cur_column_indent = indent
                    end
                    pulled.page = ctx.cur_page
                    pulled.col = ctx.cur_col
                    pulled.relative_row = ctx.cur_row
                    table.insert(col_buffer, pulled)
                    ctx.cur_row = ctx.cur_row + 1
                    ctx.page_has_content = true

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
                local pulled = table.remove(col_buffer)
                flush_buffer()
                wrap_to_next_column(ctx, p_cols, interval, grid_height, indent, false, false)
                -- Apply indent: wrap_to_next_column resets cur_row to 0 but
                -- does not apply paragraph indentation for the new column
                if indent and indent > 0 and ctx.cur_row < indent then
                    ctx.cur_row = indent
                    ctx.cur_column_indent = indent
                end
                pulled.page = ctx.cur_page
                pulled.col = ctx.cur_col
                pulled.relative_row = ctx.cur_row
                table.insert(col_buffer, pulled)
                ctx.cur_row = ctx.cur_row + 1
                ctx.page_has_content = true

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
end

-- ============================================================================
-- Plugin Standard API
-- ============================================================================

--- Initialize Punctuation Plugin
-- @param params (table) Parameters from TeX
-- @param engine_ctx (table) Shared engine context
-- @return (table|nil) Plugin context, or nil to disable
function punct.initialize(params, engine_ctx)
    -- Read punct mode: if judou module set a non-normal mode, disable punct
    local mode = (_G.judou and _G.judou.punct_mode) or "normal"

    if mode ~= "normal" then
        dbg.log("punct plugin: disabled (punct_mode=" .. tostring(mode) .. ")")
        return nil
    end

    local ctx = {
        style   = (_G.punct and _G.punct.style) or "mainland",
        squeeze = not (_G.punct and _G.punct.squeeze == false), -- default true
        hanging = (_G.punct and _G.punct.hanging) or false,     -- default false
        kinsoku = not (_G.punct and _G.punct.kinsoku == false), -- default true
    }

    dbg.log(string.format("punct plugin: enabled (style=%s, squeeze=%s, kinsoku=%s, hanging=%s)",
        ctx.style,
        tostring(ctx.squeeze),
        tostring(ctx.kinsoku),
        tostring(ctx.hanging)))

    return ctx
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

    while t do
        local id = D.getid(t)
        local next_node = D.getnext(t)

        if id == constants.GLYPH then
            -- Skip decoration characters (e.g. 。、used as decorate markers)
            local dec_id = D.get_attribute(t, constants.ATTR_DECORATE_ID)
            if not (dec_id and dec_id > 0) then
                local char = D.getfield(t, "char")

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
                if ptype then
                    local code = PUNCT_CODES[ptype]
                    D.set_attribute(t, constants.ATTR_PUNCT_TYPE, code)
                    count_classified = count_classified + 1
                end
            end
        end

        t = next_node
    end

    if count_classified > 0 or count_replaced > 0 then
        dbg.log(string.format("punct flatten: classified=%d, quotes_replaced=%d",
            count_classified, count_replaced))
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
    -- Natural mode handles punctuation sizing via get_cell_height() in layout-grid;
    -- squeeze post-processing would overwrite those carefully computed values.
    if engine_ctx.layout_mode == "natural" then return end
    -- Note: punct-hanging requires deeper integration with layout-grid.lua
    -- to allow dot-class punctuation to overflow beyond effective_limit.
    -- This will be implemented in a future version.

    -- Collect all layout entries with their node references, grouped by (page, col)
    local columns = {} -- key: "page:col" → sorted list of {node, pos, ptype}

    for node_d, pos in pairs(layout_map) do
        -- Only process nodes that have a row (actual positioned content)
        if pos.row then
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
        -- Sort by row
        table.sort(col_entries, function(a, b)
            return a.pos.row < b.pos.row
        end)

        -- Sequential cell placement: each character occupies a cell of a certain
        -- height. Punctuation cells are shorter (squeezed), but cells NEVER overlap.
        -- accumulated_squeeze tracks total grid rows saved so far, so subsequent
        -- characters shift up by that amount.
        local accumulated_squeeze = 0
        local prev_orig_row = nil
        local prev_ptype = nil

        for _, entry in ipairs(col_entries) do
            local curr_ptype = entry.ptype
            local squeeze_amount = 0

            -- Close row gaps caused by invisible spacing nodes (e.g. TeX newlines
            -- between sentences). Only close gaps that follow punctuation marks,
            -- as these are almost always interword spaces rather than intentional
            -- paragraph spacing.
            local orig_row = entry.pos.row
            if prev_orig_row and prev_ptype then
                local gap = orig_row - prev_orig_row - 1
                if gap > 0 then
                    accumulated_squeeze = accumulated_squeeze + gap
                end
            end
            prev_orig_row = orig_row
            prev_ptype = curr_ptype

            -- Determine squeeze for this entry
            if curr_ptype then
                if has_leading_space(curr_ptype) or has_trailing_space(curr_ptype) then
                    local char = D.getfield(entry.node, "char")
                    squeeze_amount = (char and CHAR_SQUEEZE[char]) or DEFAULT_SQUEEZE
                    total_squeezed = total_squeezed + 1
                end
            end

            -- Cell height for this entry (in grid units: 1.0 = full cell)
            local cell_height_grid = 1.0 - squeeze_amount

            -- Shift row up by accumulated squeeze (cells are sequential, no overlap)
            entry.pos.row = entry.pos.row - accumulated_squeeze

            -- Store cell height (sp) for render stage to use for centering
            entry.pos.cell_height = math.floor(cell_height_grid * grid_height + 0.5)

            -- Accumulate squeeze for subsequent entries
            accumulated_squeeze = accumulated_squeeze + squeeze_amount
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

-- Taiwan style: all punctuation centered in the grid cell (no extra offset)
-- This is the default rendering behavior, so no offsets needed.

--- Render stage: apply punctuation style offsets
-- For mainland style, shifts dot-class punctuation (fullstop, comma)
-- toward the upper-right corner of the character grid.
-- Taiwan style leaves punctuation centered (no adjustments).
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

    -- Taiwan style: no adjustments needed (punctuation centered by default)
    if ctx.style == "taiwan" then return head end

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

                    -- Font ink-center compensation: some fonts have punctuation
                    -- glyphs whose ink is not centered in the advance width.
                    -- Compensate so the glyph visually centers before applying
                    -- the mainland style offset.
                    local char = D.getfield(t, "char")
                    local fid = D.getfield(t, "font")
                    local glyph_width = grid_width -- fallback
                    if fid and char then
                        local fi = font.getfont(fid)
                        local ci = fi and fi.characters and fi.characters[char]
                        if ci and ci.width then glyph_width = ci.width end

                        if INK_CENTER_CHARS[char] then
                            local ratio = get_ink_center_ratio(fid, char)
                            -- compensation = how far the ink center is from advance center
                            -- ratio < 0.5 means ink is left of center → shift right
                            local comp_x = math.floor((0.5 - ratio) * glyph_width + 0.5)
                            cur_x = cur_x + comp_x
                        end
                    end

                    local dx = math.floor(grid_width * style_offset.x + 0.5)
                    local dy = math.floor(grid_height * style_offset.y + 0.5)

                    D.setfield(t, "xoffset", cur_x + dx)
                    D.setfield(t, "yoffset", cur_y + dy)
                    count = count + 1
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

return punct
