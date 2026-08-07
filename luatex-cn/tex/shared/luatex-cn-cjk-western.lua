-- luatex-cn-cjk-western.lua
-- CJK–Western mixed-text spacing rules from clreq (horizontal: "Mixed text
-- composition in horizontal writing mode" 横排的中、西文混排配置; the same
-- 1/4-em principle applies to vertical per "汉字与西文之间的间距"):
--   * a boundary between a Hanzi and a Western letter/digit carries a
--     1/4-em spacing, compressible to 1/8 em (clreq compression step 6),
--     stretchable to 1/2 em (clreq expansion step 2);
--   * three exceptions where no spacing is added: next to pause/stop marks
--     (在中文点号前后), after an opening bracket / before a closing bracket
--     (开始夹注符号之后、结束夹注符号之前).
--
-- Pure Lua, zero TeX dependency. Single data source per the clreq
-- shared-core contract (ai_must_read/clreq-shared-core.md): both the
-- horizontal backend (hori-spacing) and the vertical backend (punct.flatten)
-- take the classification and the glue values from here.

local punct_table = require("shared.luatex-cn-punct-table")

local M = {}

-- 1/4 em spacing, em ratios. min/max are the clreq bounds ([1/8, 1/2] em).
M.GLUE = { width = 0.25, shrink = 0.125, stretch = 0.25 }

-- ============================================================================
-- Character kind classification
-- ============================================================================

local function is_han(c)
    return (c >= 0x4E00 and c <= 0x9FFF)      -- CJK Unified
        or (c >= 0x3400 and c <= 0x4DBF)      -- Ext A
        or (c >= 0xF900 and c <= 0xFAFF)      -- Compatibility
        or (c >= 0x20000 and c <= 0x3FFFF)    -- Ext B+
        or c == 0x3005 or c == 0x3007 or c == 0x303B  -- 々 〇 〻
end

local function is_fullwidth_alnum(c)
    return (c >= 0xFF10 and c <= 0xFF19)      -- ０-９
        or (c >= 0xFF21 and c <= 0xFF3A)      -- Ａ-Ｚ
        or (c >= 0xFF41 and c <= 0xFF5A)      -- ａ-ｚ
end

local function is_latin(c)
    return (c >= 0x41 and c <= 0x5A)
        or (c >= 0x61 and c <= 0x7A)
        or (c >= 0xC0 and c <= 0x24F and c ~= 0xD7 and c ~= 0xF7)
end

local function is_digit(c)
    return c >= 0x30 and c <= 0x39
end

--- Classify a codepoint for boundary decisions.
-- @param c (number) Unicode codepoint
-- @return (string) "cjk" | "cjk_punct" | "western" | "other"
function M.kind(c)
    local cls = punct_table.class_of(c)
    if cls then
        -- Inter-line marks have no inline advance; treat as other
        if cls == "linemark" or cls == "emphasis" then return "other" end
        return "cjk_punct"
    end
    if is_han(c) or is_fullwidth_alnum(c) then return "cjk" end
    if is_latin(c) or is_digit(c) then return "western" end
    return "other"
end

--- clreq exception set for CJK–Western spacing: no spacing next to pause/stop
-- marks, after an opening bracket, or before a closing bracket.
-- @param c (number) codepoint of the CJK-side character at the boundary
-- @return (boolean)
function M.suppresses(c)
    if punct_table.is_point(c) then return true end
    local cls = punct_table.class_of(c)
    return cls == "open" or cls == "close"
end

--- Whether the boundary prev→next_c takes the 1/4-em CJK–Western spacing.
-- True only for a Hanzi↔Western boundary not covered by the exceptions.
-- (Boundaries involving punctuation classify as cjk_punct, so the exception
-- check via suppresses() only ever sees the punctuation codepoint itself.)
-- @param prev (number) codepoint before the boundary
-- @param next_c (number) codepoint after the boundary
-- @return (boolean)
function M.takes_spacing(prev, next_c)
    if not prev or not next_c then return false end
    local pk, nk = M.kind(prev), M.kind(next_c)
    if pk == "cjk" and nk == "western" then
        return not M.suppresses(prev)
    elseif pk == "western" and nk == "cjk" then
        return not M.suppresses(next_c)
    elseif pk == "western" and nk == "cjk_punct" then
        return false   -- 例外：点号旁、结束夹注号前不加
    elseif pk == "cjk_punct" and nk == "western" then
        return false   -- 例外：点号旁、开始夹注号后不加
    end
    return false
end

return M
