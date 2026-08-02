-- luatex-cn-kinsoku.lua
-- Line-breaking prohibition rules from clreq:
--   * "Prohibition rules for line start and line end" (行首行尾禁则),
--     four strictness levels: none / basic / gb / strict.
--   * "Prohibition rules for unbreakable punctuation" (符号分离禁则):
--     two-em punctuation units, numeral runs, numeral + unit suffix,
--     sign prefix + numeral, currency + numeral, Western words.
--
-- Pure Lua, zero TeX dependency. Outputs are backend-neutral:
--   * horizontal backend: penalty_between() → TeX penalty value
--   * vertical backend:   check_wrap() → violation kind (the squeeze-in vs
--     push-out cost comparison stays in the backend)
-- Interface contract: ai_must_read/clreq-shared-core.md
--
-- Superscript/subscript/annotation-mark separation rules need node
-- attributes and therefore live in the backends, not here.

local punct_table = require("shared.luatex-cn-punct-table")

local M = {}

M.LEVELS = { none = 0, basic = 1, gb = 2, strict = 3 }

local DEFAULT_LEVEL = "basic" -- clreq: 这是最推荐的方法

local FORBIDDEN_PENALTY = 10000

-- ============================================================================
-- Character sets for the unbreakable rules (符号分离禁则)
-- ============================================================================

local function is_digit(c)
    return (c >= 0x30 and c <= 0x39)          -- 0-9
        or (c >= 0xFF10 and c <= 0xFF19)      -- ０-９
end

local function is_western_letter(c)
    return (c >= 0x41 and c <= 0x5A)          -- A-Z
        or (c >= 0x61 and c <= 0x7A)          -- a-z
        or (c >= 0xC0 and c <= 0x24F          -- Latin-1 supp / Extended A-B
            and c ~= 0xD7 and c ~= 0xF7)      -- × ÷ are not letters
end

-- Unit suffixes that must not be separated from a preceding numeral
-- (clreq: 百分号、千分号、度数符号与其前面的阿拉伯数字之间不能拆).
local UNIT_SUFFIX = {
    [0x25] = true,    -- %
    [0xFF05] = true,  -- ％
    [0x2030] = true,  -- ‰
    [0x2031] = true,  -- ‱
    [0xB0] = true,    -- °
    [0x2103] = true,  -- ℃
    [0x2109] = true,  -- ℉
    [0x2032] = true,  -- ′
    [0x2033] = true,  -- ″
}

-- Sign prefixes that must not be separated from a following numeral
-- (clreq: 正号、负号、正负号与其后面的阿拉伯数字之间不能拆).
local SIGN_PREFIX = {
    [0x2B] = true,    -- +
    [0xFF0B] = true,  -- ＋
    [0x2D] = true,    -- - (as sign; also connector, both unbreakable here)
    [0xFF0D] = true,  -- －
    [0xB1] = true,    -- ±
    [0x2212] = true,  -- − minus sign
}

-- Currency symbols placed before the numeral (clreq: 前置货币符号).
local CURRENCY_PREFIX = {
    [0x24] = true,    -- $
    [0xFF04] = true,  -- ＄
    [0xA2] = true,    -- ¢
    [0xA3] = true,    -- £
    [0xFFE1] = true,  -- ￡
    [0xA5] = true,    -- ¥
    [0xFFE5] = true,  -- ￥
    [0x20AC] = true,  -- €
    [0xFFE0] = true,  -- ￠
}

-- Currency symbols placed after the numeral (clreq: 后置货币符号，如越南盾).
local CURRENCY_SUFFIX = {
    [0x20AB] = true,  -- ₫
}

-- ============================================================================
-- Line start / line end prohibition (delegated to the shared table)
-- ============================================================================

--- Whether `char` may not appear at line start under `level`.
-- @param char (number) Unicode codepoint
-- @param level (string) "none"|"basic"|"gb"|"strict"
-- @return (boolean)
function M.forbid_line_start(char, level)
    return punct_table.forbid_line_start(char, level or DEFAULT_LEVEL)
end

--- Whether `char` may not appear at line end under `level`.
-- @param char (number) Unicode codepoint
-- @param level (string) "none"|"basic"|"gb"|"strict"
-- @return (boolean)
function M.forbid_line_end(char, level)
    return punct_table.forbid_line_end(char, level or DEFAULT_LEVEL)
end

-- ============================================================================
-- Break opportunity between two adjacent characters
-- ============================================================================

--- Whether a line break between `prev` and `next` is forbidden.
-- Rules are checked in clreq order; the first hit wins.
-- @param prev (number) codepoint before the break candidate
-- @param next_c (number) codepoint after the break candidate
-- @param opts (table|nil) { level = "none"|"basic"|"gb"|"strict" }
-- @return (boolean) forbidden
-- @return (string|nil) reason tag (for tests/debugging):
--   "forbid_start" | "forbid_end" | "unbreakable_pair" | "digit_run" |
--   "digit_suffix" | "sign_prefix" | "currency" | "western_word"
function M.no_break_between(prev, next_c, opts)
    local level = (opts and opts.level) or DEFAULT_LEVEL

    -- 1. Two-em punctuation unit (——, ……, ⋯⋯, and stacked ？！ forms).
    -- Checked before the start/end prohibitions: it is the stronger claim —
    -- not merely "no break here" but "rigid interior" (no stretch/shrink),
    -- and callers key that off this reason tag. 叠加符号（？！等）本身也是
    -- 行首禁则字符，若先查禁则会把原因错报成 forbid_start，刚性就丢了。
    -- For runs longer than one pair, clreq allows breaking between pairs;
    -- callers with run context use pair_boundary_breakable() to lift this
    -- rule at pair boundaries.
    if punct_table.is_unbreakable_pair(prev, next_c) then
        return true, "unbreakable_pair"
    end

    -- 2/3. Line start / line end prohibition
    if punct_table.forbid_line_start(next_c, level) then
        return true, "forbid_start"
    end
    if punct_table.forbid_line_end(prev, level) then
        return true, "forbid_end"
    end

    -- 4. Numeral run (阿拉伯数字应作为一个整体)
    if is_digit(prev) and is_digit(next_c) then
        return true, "digit_run"
    end

    -- 5. Numeral + unit suffix (%, ‰, °, ℃ …)
    if is_digit(prev) and UNIT_SUFFIX[next_c] then
        return true, "digit_suffix"
    end

    -- 6. Sign prefix + numeral (+, -, ±)
    if SIGN_PREFIX[prev] and is_digit(next_c) then
        return true, "sign_prefix"
    end

    -- 7. Currency symbol + numeral (both placements)
    if CURRENCY_PREFIX[prev] and is_digit(next_c) then
        return true, "currency"
    end
    if is_digit(prev) and CURRENCY_SUFFIX[next_c] then
        return true, "currency"
    end

    -- 8. Western word: no break inside letter sequences except after an
    -- explicit hyphen (clreq: 在可使用连字符处之外，不得分隔为两行)
    if is_western_letter(prev) and is_western_letter(next_c) then
        return true, "western_word"
    end

    return false, nil
end

--- Penalty value for the break candidate between `prev` and `next`
-- (horizontal backend: inserted before TeX's line breaker runs).
-- @param prev (number) codepoint
-- @param next_c (number) codepoint
-- @param opts (table|nil) { level = ... }
-- @return (number) 10000 if forbidden, 0 otherwise
function M.penalty_between(prev, next_c, opts)
    local forbidden = M.no_break_between(prev, next_c, opts)
    return forbidden and FORBIDDEN_PENALTY or 0
end

--- Wrap-point check for the vertical backend: the column is full after
-- `last_char`, and `next_char` would start the next column.
-- @param last_char (number) codepoint at the current column end
-- @param next_char (number) codepoint that would start the next column
-- @param opts (table|nil) { level = ... }
-- @return (string|nil) "start_violation" if next_char may not start a line,
--   "end_violation" if last_char may not end a line, nil if the wrap is fine.
--   The squeeze-in vs push-out decision (and its cost model) belongs to the
--   backend.
function M.check_wrap(last_char, next_char, opts)
    local level = (opts and opts.level) or DEFAULT_LEVEL
    if next_char and punct_table.forbid_line_start(next_char, level) then
        return "start_violation"
    end
    if last_char and punct_table.forbid_line_end(last_char, level) then
        return "end_violation"
    end
    return nil
end

--- For a run of `run_len` identical two-em members (dash/ellipsis), whether
-- a break after the `index`-th member (1-based) is allowed: clreq permits
-- breaking between complete pairs when more than one pair is present.
-- @param run_len (number) total members in the run
-- @param index (number) position of the character before the break candidate
-- @return (boolean) true if the pair rule may be lifted at this boundary
function M.pair_boundary_breakable(run_len, index)
    if run_len <= 2 then return false end
    return index % 2 == 0
end

return M
