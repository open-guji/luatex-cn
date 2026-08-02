-- luatex-cn-punct-table.lua
-- Single data source for Chinese punctuation, digitized from the W3C clreq
-- appendix "Punctuation marks in Chinese" (pause/stop marks, indication marks,
-- inter-line marks, and the Unbreakable / Rotated-90°-in-vertical columns),
-- plus the width / adjustable-space rules from clreq "Punctuation width
-- adjustment" and "Procedures for inter-character spacing reduction".
--
-- Pure Lua, zero TeX dependency. Shared by the horizontal and vertical
-- backends. Interface contract: ai_must_read/clreq-shared-core.md
--
-- Units: all widths / spaces are em ratios (font size = 1). Backends convert
-- to sp by multiplying with the font size.

local M = {}

-- ============================================================================
-- Kinsoku level ordering (none < basic < gb < strict)
-- ============================================================================

local LEVEL_RANK = { none = 0, basic = 1, gb = 2, strict = 3 }

M.LEVELS = LEVEL_RANK

-- ============================================================================
-- Entry construction helpers
-- ============================================================================

-- Most entries share per-style symmetric values; these helpers keep the
-- table below readable.
local function both(v) return { mainland = v, taiwan = v } end

-- Shorthand entry builders per clreq punctuation category.
-- Fields: name, class, width, space, shrink, shrink_class,
--         unbreakable, vert_rotate, forbid_start, forbid_end

-- Pause/stop marks in mainland (GB) style sit at the start of the frame with
-- the blank at the end; Taiwan style centers them with blank on both sides.
local function point_mark(name, class, shrink_class, shrink_amount)
    return {
        name = name,
        class = class,
        width = both(1),
        space = { mainland = "end", taiwan = "both" },
        shrink = both(shrink_amount),
        shrink_class = shrink_class,
        forbid_start = "basic",
    }
end

local function open_bracket(name)
    return {
        name = name,
        class = "open",
        width = both(1),
        space = both("start"),
        shrink = both(0.5),
        shrink_class = "bracket",
        vert_rotate = true,
        forbid_end = "basic",
    }
end

local function close_bracket(name)
    return {
        name = name,
        class = "close",
        width = both(1),
        space = both("end"),
        shrink = both(0.5),
        shrink_class = "bracket",
        vert_rotate = true,
        forbid_start = "basic",
    }
end

-- Two-em unit members (dash / ellipsis): fixed width, unbreakable as a pair,
-- rotated in vertical mode. Line-start forbidden only at the strict level.
local function two_em_member(name, class, width)
    return {
        name = name,
        class = class,
        width = both(width),
        space = both("none"),
        shrink = both(0),
        unbreakable = true,
        vert_rotate = true,
        forbid_start = "strict",
    }
end

-- ============================================================================
-- The table (keyed by Unicode codepoint)
-- ============================================================================

local TABLE = {
    -- ------------------------------------------------------------------
    -- Pause or stop punctuation marks (点号)
    -- ------------------------------------------------------------------
    [0x3002] = point_mark("句号", "fullstop", "fullstop_group", 0.5),  -- 。
    [0xFF0E] = point_mark("句号", "fullstop", "fullstop_group", 0.5),  -- ．
    [0xFF0C] = point_mark("逗号", "comma", "comma_group", 0.5),        -- ，
    [0x3001] = point_mark("顿号", "comma", "comma_group", 0.5),        -- 、
    -- Colon is not in the clreq compression priority list: not shrinkable.
    [0xFF1A] = point_mark("冒号", "colon", nil, 0),                    -- ：
    [0xFF1B] = point_mark("分号", "semicolon", "comma_group", 0.5),    -- ；
    [0xFF01] = point_mark("叹号", "exclamation", "fullstop_group", 0.5), -- ！
    [0xFF1F] = point_mark("问号", "question", "fullstop_group", 0.5),  -- ？
    -- Stacked forms take exactly 1 em (clreq appendix note), never adjusted.
    [0x203C] = point_mark("双叹号", "exclamation", nil, 0),            -- ‼
    [0x2047] = point_mark("双问号", "question", nil, 0),               -- ⁇

    -- ------------------------------------------------------------------
    -- Indication punctuation marks (标号)
    -- ------------------------------------------------------------------
    -- Dash (破折号): —— pair or single ⸺ takes two em as one unit.
    [0x2014] = two_em_member("破折号", "dash", 1),                     -- —
    [0x2E3A] = two_em_member("破折号", "dash", 2),                     -- ⸺
    -- Ellipsis (省略号): …… / ⋯⋯ pair takes two em as one unit.
    [0x2026] = two_em_member("省略号", "ellipsis", 1),                 -- …
    [0x22EF] = two_em_member("省略号", "ellipsis", 1),                 -- ⋯

    -- Connector (连接号): GB half-width forms are fixed at 0.5 em
    -- (clreq: 不可调整的标点…中国大陆GB式的半字连接号).
    [0xFF5E] = { name = "连接号", class = "connector",                 -- ～
        width = both(1), space = both("none"), shrink = both(0),
        vert_rotate = true, forbid_start = "basic" },
    [0x002D] = { name = "连接号", class = "connector",                 -- -
        width = both(0.5), space = both("none"), shrink = both(0),
        vert_rotate = true, forbid_start = "basic" },
    [0x2013] = { name = "连接号", class = "connector",                 -- –
        width = both(0.5), space = both("none"), shrink = both(0),
        vert_rotate = true, forbid_start = "basic" },

    -- Interpunct (间隔号): mainland GB style is fixed half width; Taiwan
    -- style takes one em centered, compressible from both sides down to
    -- half width (clreq shrink step 3: 最小挤到 0，即变成半个汉字字宽).
    [0x00B7] = { name = "间隔号", class = "interpunct",                -- ·
        width = { mainland = 0.5, taiwan = 1 },
        space = { mainland = "none", taiwan = "both" },
        shrink = { mainland = 0, taiwan = 0.5 },
        shrink_class = "interpunct",
        forbid_start = "basic" },
    [0x30FB] = { name = "间隔号", class = "interpunct",                -- ・
        width = both(1), space = both("both"), shrink = both(0.5),
        shrink_class = "interpunct",
        forbid_start = "basic" },
    [0x2027] = { name = "间隔号", class = "interpunct",                -- ‧ (Big5)
        width = both(1), space = both("both"), shrink = both(0.5),
        shrink_class = "interpunct",
        forbid_start = "basic" },

    -- Solidus (分隔号): mainland half-width / fixed; fullwidth form is used
    -- in Traditional Chinese, fixed. Line-end forbidden from the GB level.
    [0x002F] = { name = "分隔号", class = "solidus",                   -- /
        width = both(0.5), space = both("none"), shrink = both(0),
        vert_rotate = true,
        forbid_start = "basic", forbid_end = "gb" },
    [0xFF0F] = { name = "分隔号", class = "solidus",                   -- ／
        width = both(1), space = both("none"), shrink = both(0),
        forbid_start = "basic", forbid_end = "gb" },

    -- Quotes (引号)
    [0x300C] = open_bracket("引号"),   -- 「
    [0x300D] = close_bracket("引号"),  -- 」
    [0x300E] = open_bracket("引号"),   -- 『
    [0x300F] = close_bracket("引号"),  -- 』
    -- Curly quotes take one character space in Simplified Chinese (clreq
    -- appendix note); in Traditional Chinese text they are usually Western
    -- proportional glyphs — backends decide whether to treat them as CJK.
    [0x201C] = open_bracket("引号"),   -- "
    [0x201D] = close_bracket("引号"),  -- "
    [0x2018] = open_bracket("引号"),   -- '
    [0x2019] = close_bracket("引号"),  -- '

    -- Parentheses / brackets (夹注号 及其他括号)
    [0xFF08] = open_bracket("括号"),   -- （
    [0xFF09] = close_bracket("括号"),  -- ）
    [0x3010] = open_bracket("括号"),   -- 【
    [0x3011] = close_bracket("括号"),  -- 】
    [0x3016] = open_bracket("括号"),   -- 〖
    [0x3017] = close_bracket("括号"),  -- 〗
    [0x3014] = open_bracket("括号"),   -- 〔
    [0x3015] = close_bracket("括号"),  -- 〕
    [0xFF3B] = open_bracket("括号"),   -- ［
    [0xFF3D] = close_bracket("括号"),  -- ］
    [0xFF5B] = open_bracket("括号"),   -- ｛
    [0xFF5D] = close_bracket("括号"),  -- ｝

    -- Book title marks (书名号乙式 / 篇名号)
    [0x300A] = open_bracket("书名号"),  -- 《
    [0x300B] = close_bracket("书名号"), -- 》
    [0x3008] = open_bracket("篇名号"),  -- 〈
    [0x3009] = close_bracket("篇名号"), -- 〉

    -- ------------------------------------------------------------------
    -- Inter-line indication marks (行间标号): no inline advance of their
    -- own; kept for classification completeness. LOW LINE / WAVY LOW LINE
    -- are listed as rotated in the clreq appendix.
    -- ------------------------------------------------------------------
    [0xFF3F] = { name = "专名号", class = "linemark", vert_rotate = true },   -- ＿
    [0xFE4F] = { name = "书名号甲式", class = "linemark", vert_rotate = true }, -- ﹏
    [0x25CF] = { name = "着重号", class = "emphasis" },                        -- ●
    [0x2022] = { name = "着重号", class = "emphasis" },                        -- •
}

-- ============================================================================
-- Queries
-- ============================================================================

--- Get the raw table entry for a codepoint.
-- @param char (number) Unicode codepoint
-- @return (table|nil)
function M.get(char)
    return TABLE[char]
end

--- Get the clreq class of a codepoint.
-- @param char (number) Unicode codepoint
-- @return (string|nil)
function M.class_of(char)
    local e = TABLE[char]
    return e and e.class
end

local POINT_CLASSES = {
    fullstop = true, comma = true, colon = true,
    semicolon = true, exclamation = true, question = true,
}

--- Whether the codepoint is a pause/stop mark (点号).
-- @param char (number) Unicode codepoint
-- @return (boolean)
function M.is_point(char)
    local e = TABLE[char]
    return (e and POINT_CLASSES[e.class]) or false
end

-- Classes whose width is fixed to one em in vertical mode regardless of
-- style (clreq: 直排的冒号、分号、问号、感叹号固定一个字宽).
local VERT_FIXED_CLASSES = {
    colon = true, semicolon = true, exclamation = true, question = true,
}

local NO_SPACE = { side = "none", shrink = 0 }

--- Adjustable-space info for a codepoint under a style and writing mode.
-- Applies the clreq mode/style overrides:
--   * vertical: colon/semicolon/question/exclamation fixed (both styles)
--   * horizontal taiwan: question/exclamation fixed
-- @param char (number) Unicode codepoint
-- @param style (string) "mainland" | "taiwan"
-- @param mode (string) "horizontal" | "vertical"
-- @return (table|nil) { side = "start"|"end"|"both"|"none", shrink = em }
function M.space_info(char, style, mode)
    local e = TABLE[char]
    if not e or not e.space then return nil end

    if mode == "vertical" and VERT_FIXED_CLASSES[e.class] then
        return NO_SPACE
    end
    if mode == "horizontal" and style == "taiwan"
        and (e.class == "question" or e.class == "exclamation") then
        return NO_SPACE
    end

    local side = e.space[style]
    local shrink = e.shrink and e.shrink[style] or 0
    if not side or side == "none" or shrink <= 0 then
        return { side = side or "none", shrink = 0 }
    end
    return { side = side, shrink = shrink }
end

--- Shrink priority group for adjust.lua, honoring mode/style overrides.
-- @param char (number) Unicode codepoint
-- @param style (string) "mainland" | "taiwan"
-- @param mode (string) "horizontal" | "vertical"
-- @return (string|nil) group name (matches adjust.SHRINK_ORDER) or nil
function M.shrink_class_of(char, style, mode)
    local e = TABLE[char]
    if not e or not e.shrink_class then return nil end
    local info = M.space_info(char, style, mode)
    if not info or info.shrink <= 0 then return nil end
    return e.shrink_class
end

--- Nominal advance width (em) for a codepoint under a style.
-- @param char (number) Unicode codepoint
-- @param style (string) "mainland" | "taiwan"
-- @return (number|nil) em ratio, or nil for inter-line marks / unknown chars
function M.width_of(char, style)
    local e = TABLE[char]
    return e and e.width and e.width[style]
end

--- Whether a codepoint is forbidden at line start under a kinsoku level.
-- @param char (number) Unicode codepoint
-- @param level (string) "none" | "basic" | "gb" | "strict"
-- @return (boolean)
function M.forbid_line_start(char, level)
    local e = TABLE[char]
    if not e or not e.forbid_start then return false end
    local rank = LEVEL_RANK[level]
    if not rank then return false end
    return rank >= LEVEL_RANK[e.forbid_start]
end

--- Whether a codepoint is forbidden at line end under a kinsoku level.
-- @param char (number) Unicode codepoint
-- @param level (string) "none" | "basic" | "gb" | "strict"
-- @return (boolean)
function M.forbid_line_end(char, level)
    local e = TABLE[char]
    if not e or not e.forbid_end then return false end
    local rank = LEVEL_RANK[level]
    if not rank then return false end
    return rank >= LEVEL_RANK[e.forbid_end]
end

--- Whether the codepoint carries the appendix "Unbreakable" flag
-- (two-em dash/ellipsis members).
-- @param char (number) Unicode codepoint
-- @return (boolean)
function M.is_unbreakable(char)
    local e = TABLE[char]
    return (e and e.unbreakable) or false
end

-- 叹问号叠加的序列形式（clreq 非典型标点：？？ ！！ ？！ ！？）。
-- 与预组合码位 ‼(U+203C) ⁇(U+2047) 同义，但以两个全角符号连排出现，
-- 构成一个两字宽的**刚性**整体：内部不挤压、不拆行、不被兜底均分撑开。
local STACKED_MARKS = {
    [0xFF01] = true, -- ！
    [0xFF1F] = true, -- ？
}

--- Whether two adjacent codepoints form a stacked exclamation/question
-- sequence (？？ ！！ ？！ ！？) — a rigid two-em unit per the clreq
-- appendix note on stacked forms (占两个汉字宽度，宽度不可调整).
-- @param a (number) previous codepoint
-- @param b (number) next codepoint
-- @return (boolean)
function M.is_stacked_pair(a, b)
    return (STACKED_MARKS[a] and STACKED_MARKS[b]) or false
end

--- Whether two adjacent codepoints form an unbreakable two-em unit
-- (——, ……, ⋯⋯: identical dash/ellipsis members; ？？ ！！ ？！ ！？:
-- stacked marks — the only case where the two members may differ).
-- @param a (number) previous codepoint
-- @param b (number) next codepoint
-- @return (boolean)
function M.is_unbreakable_pair(a, b)
    if M.is_stacked_pair(a, b) then return true end
    if a ~= b then return false end
    local e = TABLE[a]
    return (e and e.unbreakable and (e.class == "dash" or e.class == "ellipsis"))
        or false
end

--- Whether the codepoint is rotated 90° clockwise in vertical mode
-- (appendix column).
-- @param char (number) Unicode codepoint
-- @return (boolean)
function M.vert_rotate(char)
    local e = TABLE[char]
    return (e and e.vert_rotate) or false
end

-- ============================================================================
-- Quote style conversion (clreq 引号体例)
-- ============================================================================

-- clreq: 横排简体中文用弯引号，嵌套体例先双后单（“…‘…’…”）；
-- 台湾用传统引号，先单后双（「…『…』…」）。两套引号按嵌套深度一一对应，
-- 逐字映射即完成体例转换（外层对外层、内层对内层）。
local TO_CURLY = {
    [0x300C] = 0x201C, -- 「 → “
    [0x300D] = 0x201D, -- 」 → ”
    [0x300E] = 0x2018, -- 『 → ‘
    [0x300F] = 0x2019, -- 』 → ’
}
local TO_CORNER = {
    [0x201C] = 0x300C, -- “ → 「
    [0x201D] = 0x300D, -- ” → 」
    [0x2018] = 0x300E, -- ‘ → 『
    [0x2019] = 0x300F, -- ’ → 』
}

--- Convert a quote codepoint to the target style, preserving nesting depth
-- and open/close role.
-- @param char (number) Unicode codepoint
-- @param target (string) "curly" (简体横排) | "corner" (台湾)
-- @return (number|nil) converted codepoint, or nil if no conversion applies
function M.quote_convert(char, target)
    if target == "curly" then
        return TO_CURLY[char]
    elseif target == "corner" then
        return TO_CORNER[char]
    end
    return nil
end

-- Legacy six-type mapping used by the current vertical engine
-- (open/close/fullstop/comma/middle/nobreak). For the P1 migration:
-- luatex-cn-core-punct.lua derives its CL_* sets from this.
local LEGACY_MAP = {
    open = "open",
    close = "close",
    fullstop = "fullstop",
    comma = "comma",
    colon = "middle",
    semicolon = "middle",
    exclamation = "middle",
    question = "middle",
    dash = "nobreak",
    ellipsis = "nobreak",
}

--- Legacy six-type name for a codepoint (P1 migration helper).
-- @param char (number) Unicode codepoint
-- @return (string|nil) "open"|"close"|"fullstop"|"comma"|"middle"|"nobreak"
function M.legacy_type(char)
    local e = TABLE[char]
    if not e then return nil end
    -- The legacy engine only ever classified the stacked forms ‼⁇ as absent;
    -- keep them out of the legacy view to avoid behavior change before P1.
    if char == 0x203C or char == 0x2047 then return nil end
    return LEGACY_MAP[e.class]
end

--- Iterate all entries: for char, entry in punct_table.entries() do ... end
-- @return (function) stateless iterator over (codepoint, entry)
function M.entries()
    return pairs(TABLE)
end

return M
