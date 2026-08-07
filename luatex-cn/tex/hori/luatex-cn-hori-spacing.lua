-- luatex-cn-hori-spacing.lua
-- Pure boundary-decision logic for the horizontal (clreq) pipeline: given two
-- adjacent characters, decide what to insert between them — a break penalty
-- (from the shared kinsoku rules) and/or an adjustable glue (inter-CJK
-- break/stretch point, or the clreq CJK–Western spacing).
--
-- clreq rules implemented here:
--   * 中西混排: 汉字与西文字母、数字间使用不多于 1/4 汉字宽的字距，
--     行内调整时可挤压至 1/8、拉伸至 1/2。
--   * 例外: 在中文点号前后、开始夹注符号之后、结束夹注符号之前的西文，
--     不调整字距或加入空白。（行首/行尾不加由 TeX 断行天然保证：
--     断点处的 glue 会被丢弃。）
--   * 行首行尾禁则 / 符号分离禁则: 由 shared/kinsoku 提供 penalty。
--
-- Pure Lua, zero TeX dependency (node insertion lives in hori-pipeline.lua).
-- All glue amounts are em ratios; the pipeline multiplies by the font size.

local punct_table = require("shared.luatex-cn-punct-table")
local kinsoku = require("shared.luatex-cn-kinsoku")
local punct_squeeze = require("shared.luatex-cn-punct-squeeze")
local cjk_western = require("shared.luatex-cn-cjk-western")

local M = {}

-- Adjustment classes carried on inserted glues (attribute values consumed by
-- the H2 post-linebreak redistribution; codes must stay stable).
M.ADJUST_CLASS_CODES = {
    fallback     = 1, -- inter-hanzi gap: even-distribution stretch of last resort
    cjk_western  = 2, -- CJK–Western spacing (clreq shrink step 6 / stretch step 2)
    western_word = 3, -- Western word space (clreq shrink step 2 / stretch step 1)
    -- Punctuation blank-side shrink, keyed by the shared table's shrink
    -- classes (clreq compression steps 3/4/5/7):
    interpunct     = 4,
    bracket        = 5,
    comma_group    = 6,
    fullstop_group = 7,
}

-- ============================================================================
-- Character kind classification
-- ============================================================================
-- 分类与例外规则的本体在共享层 shared/luatex-cn-cjk-western.lua（P3 起
-- 竖排也消费同一份），这里只保留同名入口。

M.kind = cjk_western.kind
local suppresses_western_spacing = cjk_western.suppresses

-- ============================================================================
-- Boundary decision
-- ============================================================================

local DEFAULT_OPTS = {
    style = "mainland",        -- punctuation style: mainland | taiwan | none
    level = "basic",           -- kinsoku level
    cjk_latin_space = true,    -- insert the 1/4 em CJK–Western spacing
    inter_cjk_stretch = 0.05,  -- em; stretch of last resort between hanzi
                               -- (H2 replaces TeX's proportional use of it
                               -- with the priority-ordered redistribution)
    adjacent_punct = "1.5",    -- 连续标点缩减: "1.5"(clreq 原则) | "1" | "natural"
}

-- clreq 连续标点符号的调整：夹注符号与其他符号连排、或夹注符号重复出现
-- （开+开/结+结/结+开）时，「无论文本整体采用何种风格」都应把 2 字宽的
-- 相邻标点缩减成 1.5 字宽（风格可进一步到 1 字宽）。缩减量从两符号之间
-- 的空白中扣除（方向天然满足「夹注符号紧靠被夹注的内容」——夹注符号
-- 靠内容一侧无空白，可缩的只有外侧）。
-- 规则本体在共享层（HR5：clreq 规则只写在 tex/shared/）；这里只做接线。
local is_bracket = punct_squeeze.is_bracket
local adjacent_reduction_cap = punct_squeeze.adjacent_reduction_cap

-- Shrinkable blank contributed by a punctuation glyph to the boundary on one
-- of its sides (clreq 标点符号的宽度调整: the fullwidth glyph carries its
-- blank; compression removes up to that blank). side "both" splits the
-- shrink between the two boundaries. Style "none" = 不调整 preset.
-- @return shrink_em (number), shrink_class (string|nil)
local function punct_side_shrink(c, which_side, style)
    if style == "none" then return 0, nil end
    local info = punct_table.space_info(c, style, "horizontal")
    if not info or info.shrink <= 0 then return 0, nil end
    local cls = punct_table.shrink_class_of(c, style, "horizontal")
    if info.side == which_side then
        return info.shrink, cls
    elseif info.side == "both" then
        return info.shrink / 2, cls
    end
    return 0, nil
end

--- Decide what to insert between two adjacent characters.
-- @param prev (number) codepoint before the boundary
-- @param next_c (number) codepoint after the boundary
-- @param opts (table|nil) { level, cjk_latin_space, inter_cjk_stretch }
-- @return (table|nil) nil = insert nothing (pure Western boundary: TeX's own
--   spacing/hyphenation applies). Otherwise:
--   {
--     penalty = 10000|nil,     -- break prohibition (before the glue)
--     glue = {                 -- adjustable break point, em ratios
--       width, shrink, stretch,
--       class = "fallback"|"cjk_western",
--     } | nil,
--   }
-- Boundaries protected by the symbol-separation rules form an indivisible
-- UNIT (数字串、两字宽标点对……): besides forbidding the break, no stretch may
-- open inside them — the H2 fallback distribution (兜底均分) must skip these
-- gaps. Line start/end kinsoku ("forbid_start"/"forbid_end") is NOT a unit:
-- 一。may not break, but the gap before 。 stretches like any other.
local RIGID_REASONS = {
    unbreakable_pair = true,
    digit_run = true,
    digit_suffix = true,
    sign_prefix = true,
    currency = true,
    western_word = true,
}

function M.boundary(prev, next_c, opts)
    opts = opts or DEFAULT_OPTS
    local pk = M.kind(prev)
    local nk = M.kind(next_c)

    -- Pure Western/other boundary: leave it to TeX (word spaces come from
    -- the source; hyphenation provides break points — clreq: 西文单词在
    -- 可使用连字符处之外不得分隔，正是 TeX 的默认行为)
    local prev_cjk = (pk == "cjk" or pk == "cjk_punct")
    local next_cjk = (nk == "cjk" or nk == "cjk_punct")
    if not prev_cjk and not next_cjk then
        return nil
    end

    local forbidden, reason = kinsoku.no_break_between(prev, next_c,
        { level = opts.level or DEFAULT_OPTS.level })

    local glue
    if (prev_cjk and nk == "western") or (pk == "western" and next_cjk) then
        -- CJK–Western boundary: 1/4 em spacing unless suppressed by the
        -- adjacent punctuation exception
        local cjk_char = prev_cjk and prev or next_c
        local space_on = opts.cjk_latin_space
        if space_on == nil then space_on = DEFAULT_OPTS.cjk_latin_space end
        if space_on and not suppresses_western_spacing(cjk_char) then
            local G = cjk_western.GLUE
            glue = { width = G.width, shrink = G.shrink, stretch = G.stretch,
                     class = "cjk_western" }
        else
            glue = { width = 0, shrink = 0, stretch = 0, class = "fallback" }
        end
    elseif prev_cjk and next_cjk then
        -- Inter-CJK boundary: zero-width break point with a small stretch
        -- of last resort (clreq: 行内文字原则上密排；拉伸兜底均分)
        local st = opts.inter_cjk_stretch or DEFAULT_OPTS.inter_cjk_stretch
        glue = { width = 0, shrink = 0, stretch = st, class = "fallback" }
    else
        -- CJK next to "other" (symbols etc.): break point without spacing
        glue = { width = 0, shrink = 0, stretch = 0, class = "fallback" }
    end

    -- Punctuation blank-side shrink (clreq 标点宽度调整): the trailing blank
    -- of prev / leading blank of next may be compressed at this boundary.
    -- TeX's proportional use of this shrink is an approximation; the H2 pass
    -- redistributes it by clreq priority using the class attribute.
    -- Both sides may contribute (adjacent punctuation: clreq allows 2 → 1.5
    -- → 1 em by removing both half-blanks); the class comes from the larger
    -- contributor.
    local style = opts.style or DEFAULT_OPTS.style
    local prev_s, prev_cls = 0, nil
    local next_s, next_cls = 0, nil
    if pk == "cjk_punct" then
        prev_s, prev_cls = punct_side_shrink(prev, "end", style)
    end
    if nk == "cjk_punct" then
        next_s, next_cls = punct_side_shrink(next_c, "start", style)
    end
    local shrink_amount = prev_s + next_s
    -- 连续标点无条件缩减（clreq: 2 → 1.5 字宽，风格可至 1）：夹注符号
    -- 参与的标点连排，先把两符号间的空白固定扣掉 cap，余量仍作行内
    -- 挤压容量。glue 因此可为负宽。
    if pk == "cjk_punct" and nk == "cjk_punct" and shrink_amount > 0
        and (is_bracket(prev) or is_bracket(next_c)) then
        local cap = adjacent_reduction_cap(
            opts.adjacent_punct or DEFAULT_OPTS.adjacent_punct)
        local reduction = math.min(cap, shrink_amount)
        if reduction > 0 then
            glue.width = glue.width - reduction
            shrink_amount = shrink_amount - reduction
        end
    end
    if shrink_amount > 0 then
        glue.shrink = glue.shrink + shrink_amount
        local cls = (next_s > prev_s) and next_cls or prev_cls
        if cls then glue.class = cls end
    end

    -- Rigid unit interior: keep the glue as a (penalty-protected) break
    -- point, but strip its stretch AND its adjustment class — an unclassed
    -- gap is invisible to the H2 solver, so neither TeX's proportional pass
    -- nor the fallback even-distribution can open space inside the unit.
    -- Shrink is stripped too: dash/ellipsis members carry none anyway, but
    -- stacked ？！ marks are point marks whose blank-side shrink would
    -- otherwise let the pair be compressed below its fixed two-em width
    -- (clreq appendix: stacked forms 宽度不可调整).
    if forbidden and RIGID_REASONS[reason] then
        glue.stretch = 0
        glue.shrink = 0
        glue.class = nil
    end

    return {
        penalty = forbidden and 10000 or nil,
        glue = glue,
    }
end

return M
