-- luatex-cn-punct-squeeze.lua
-- clreq 《标点符号的宽度调整》的**上下文判定**（共享层）。
--
-- clreq 规定标点的字面空白只在两种情形被收回：
--   ① 相邻标点连排（夹注符号参与时「无论何种风格都应该」把 2 字宽减到
--      1.5 字宽，风格可进一步到 1 字宽）；
--   ② 标点位于行首 / 行尾（行首开始夹注符号可缩始侧半字；行末点号缩末
--      侧半字，或整字悬挂）。
-- 夹在汉字之间的单个标点**不挤压**——它占满一个字幅。
--
-- 纯 Lua、零 TeX 依赖，横排与竖排两条后端共用（HR5：clreq 规则只写在
-- tex/shared/）。单位一律为以字号为 1 的 em 比值。
-- 契约见 ai_must_read/clreq-shared-core.md。

local punct_table = require("shared.luatex-cn-punct-table")

local M = {}

-- ============================================================================
-- 选项
-- ============================================================================

M.DEFAULT_OPTS = {
    style              = "mainland",  -- mainland | taiwan | none（none = 不调整）
    mode               = "vertical",  -- horizontal | vertical
    adjacent_punct     = "1.5",       -- 连续标点缩减：1.5（clreq 原则）| 1 | natural
    line_start_bracket = "trim",      -- 行首开始夹注符号：trim | natural
    line_end_punct     = "compress",  -- 行末点号：compress | natural
}

-- 夹注符号（开/结括号、引号、书名号）——clreq 连续标点缩减的触发条件是
-- 「夹注符号与其他符号连排，或夹注符号重复出现」。
local BRACKET_CLASSES = { open = true, close = true }

--- 连续标点的缩减上限（一对标点合计可收回的空白，em）。
-- "1.5" → 2 字宽减到 1.5；"1" → 减到 1；"natural" → 不做无条件缩减。
-- @param mode (string) adjacent_punct 取值
-- @return (number) em
function M.adjacent_reduction_cap(mode)
    if mode == "1" then return 1.0 end
    if mode == "natural" then return 0 end
    return 0.5 -- "1.5" 默认
end

--- 是否夹注符号（开或结）
-- @param char (number) 码位
-- @return (boolean)
function M.is_bracket(char)
    return BRACKET_CLASSES[punct_table.class_of(char)] or false
end

-- ============================================================================
-- 字面空白
-- ============================================================================

--- 一个标点在始端 / 末端各自携带的可收回空白（em）。
-- side="both" 时两端各半。style="none"（不调整预设）一律为零。
-- 「始端」横排为左、直排为上。
-- @param char (number) 码位
-- @param opts (table|nil) { style, mode }
-- @return (number, number) head_blank, tail_blank
function M.blanks(char, opts)
    opts = opts or M.DEFAULT_OPTS
    local style = opts.style or M.DEFAULT_OPTS.style
    if style == "none" then return 0, 0 end
    local info = punct_table.space_info(char, style, opts.mode or M.DEFAULT_OPTS.mode)
    if not info or info.shrink <= 0 then return 0, 0 end
    if info.side == "start" then
        return info.shrink, 0
    elseif info.side == "end" then
        return 0, info.shrink
    elseif info.side == "both" then
        return info.shrink / 2, info.shrink / 2
    end
    return 0, 0
end

-- 一个边界上两侧空白按 cap 分摊后，本侧应收回的量。
-- 例：「，「」的边界上逗号末端 0.5 + 开引号始端 0.5 = 1.0，cap=0.5 时
-- 各收回 0.25，两符号合计仍占 1.5 字宽（clreq 原则调整量）。
local function share_of(own_blank, other_blank, cap)
    if own_blank <= 0 or cap <= 0 then return 0 end
    local total = own_blank + other_blank
    if total <= 0 then return 0 end
    local reduction = math.min(cap, total)
    return math.min(own_blank, reduction * own_blank / total)
end

-- ============================================================================
-- 上下文判定
-- ============================================================================

--- 计算一个标点在给定上下文下实际收回的空白。
--
-- @param prev (number|nil) 前一个字符码位（nil = 行/列首之前无字符）
-- @param cur (number) 本标点码位
-- @param next_c (number|nil) 后一个字符码位
-- @param ctx (table|nil) { at_line_start = bool, at_line_end = bool }
--   （行 = 横排的行、直排的列；由后端在知道断行结果后提供）
-- @param opts (table|nil) 见 DEFAULT_OPTS
-- @return (table) {
--   head = em,           -- 始端收回量
--   tail = em,           -- 末端收回量
--   total = em,          -- head + tail，后端按此缩短字幅
--   reasons = { ... },   -- "adjacent" | "line_start" | "line_end"，供调试/断言
-- }
function M.plan(prev, cur, next_c, ctx, opts)
    opts = opts or M.DEFAULT_OPTS
    ctx = ctx or {}
    local result = { head = 0, tail = 0, total = 0, reasons = {} }

    local head_blank, tail_blank = M.blanks(cur, opts)
    if head_blank <= 0 and tail_blank <= 0 then return result end

    local cap = M.adjacent_reduction_cap(
        opts.adjacent_punct or M.DEFAULT_OPTS.adjacent_punct)
    local cur_is_bracket = M.is_bracket(cur)

    -- ① 相邻标点连排（clreq：夹注符号参与时无条件缩减）
    if prev and head_blank > 0 and punct_table.class_of(prev)
        and (cur_is_bracket or M.is_bracket(prev)) then
        local _, prev_tail = M.blanks(prev, opts)
        local r = share_of(head_blank, prev_tail, cap)
        if r > 0 then
            result.head = r
            table.insert(result.reasons, "adjacent")
        end
    end
    if next_c and tail_blank > 0 and punct_table.class_of(next_c)
        and (cur_is_bracket or M.is_bracket(next_c)) then
        local next_head = M.blanks(next_c, opts)
        local r = share_of(tail_blank, next_head, cap)
        if r > 0 then
            result.tail = r
            if result.reasons[#result.reasons] ~= "adjacent" then
                table.insert(result.reasons, "adjacent")
            end
        end
    end

    -- ② 行首 / 行尾（整段空白收回，覆盖①的分摊量）
    local start_mode = opts.line_start_bracket or M.DEFAULT_OPTS.line_start_bracket
    if ctx.at_line_start and cur_is_bracket and head_blank > 0
        and start_mode ~= "natural" then
        result.head = head_blank
        table.insert(result.reasons, "line_start")
    end
    local end_mode = opts.line_end_punct or M.DEFAULT_OPTS.line_end_punct
    if ctx.at_line_end and tail_blank > 0 and end_mode ~= "natural"
        and (punct_table.is_point(cur) or cur_is_bracket) then
        result.tail = tail_blank
        table.insert(result.reasons, "line_end")
    end

    result.total = result.head + result.tail
    return result
end

return M
