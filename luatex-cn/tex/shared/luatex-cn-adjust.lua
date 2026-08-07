-- luatex-cn-adjust.lua
-- One-dimensional priority-driven space allocator implementing the clreq
-- line adjustment rules:
--   * "Procedures for inter-character spacing reduction" (挤压处理的优先顺序,
--     7 steps) — classes are exhausted strictly in order, and within a class
--     all gaps are reduced simultaneously by equal amounts (同时、同等量处理).
--   * "Procedures for inter-character space expansion" (拉伸处理的优先顺序,
--     2 steps) — then the remainder is distributed evenly over the fallback
--     gaps (最后…按平均拉大字距的方式处理).
--
-- Pure Lua, zero TeX dependency, no unit assumption: callers must pass all
-- lengths in one consistent unit (em ratios or sp). Never mutates its input.
-- Interface contract: ai_must_read/clreq-shared-core.md
--
-- Gap fields:
--   width         (number, required) ideal value
--   min           (number, default width) shrink floor
--   max           (number, default width) stretch ceiling
--   shrink_class  (string|nil) member of SHRINK_ORDER, nil = never shrunk
--   stretch_class (string|nil) member of STRETCH_ORDER, nil = never stretched
--   fallback      (boolean) participates in the even-distribution fallback

local M = {}

-- clreq compression priority (挤压处理的优先顺序). The min values mandated
-- by clreq (western word space ≥ 1/4 em, CJK–Western gap ≥ 1/8 em, punctuation
-- ≥ half em, interpunct space → 0) are encoded by the caller in each gap's
-- `min` field; the solver itself is unit- and rule-agnostic.
M.SHRINK_ORDER = {
    "line_end_punct",  -- 1 位于行末的标点（调成固定半字）
    "western_word",    -- 2 西文词距
    "interpunct",      -- 3 间隔号
    "bracket",         -- 4 夹注符号
    "comma_group",     -- 5 逗号/顿号/分号
    "cjk_western",     -- 6 中西间距
    "fullstop_group",  -- 7 句号/问号/叹号
    -- 8（超出 clreq 列举的七步）：字间距本身。clreq 假定行内密排，字距无可
    -- 压缩；本项目直排以 0.1em 为基准字距，是本项目的版式选择，因此在 clreq
    -- 七步全部耗尽后才允许压缩它，绝不能排在标点空白之前。横排不使用本类。
    "inter_char",
}

-- clreq expansion priority (拉伸处理的优先顺序), before the fallback.
M.STRETCH_ORDER = {
    "western_word",    -- 1 西文词距
    "cjk_western",     -- 2 中西间距
}

local EPS = 1e-9

-- Reduce (dir = -1) or grow (dir = +1) every member of `idx` (indices into
-- `widths`) simultaneously by equal amounts, each bounded by bounds[i],
-- until `amount` is consumed or every member saturates.
-- Returns the amount actually applied.
local function apply_equally(widths, bounds, idx, amount, dir)
    local applied = 0
    local active = {}
    for _, i in ipairs(idx) do
        if (bounds[i] - widths[i]) * dir > EPS then
            active[#active + 1] = i
        end
    end
    while amount - applied > EPS and #active > 0 do
        local per_gap = (amount - applied) / #active
        -- Smallest remaining headroom among active gaps
        local head = math.huge
        for _, i in ipairs(active) do
            local h = (bounds[i] - widths[i]) * dir
            if h < head then head = h end
        end
        local step = math.min(per_gap, head)
        for _, i in ipairs(active) do
            widths[i] = widths[i] + step * dir
        end
        applied = applied + step * #active
        -- Drop saturated gaps
        local still = {}
        for _, i in ipairs(active) do
            if (bounds[i] - widths[i]) * dir > EPS then
                still[#still + 1] = i
            end
        end
        if #still == #active then break end -- per_gap satisfied, done
        active = still
    end
    return applied
end

--- Solve the line adjustment problem.
-- @param target (number) target total length
-- @param gaps (table) array of gap descriptors (see module header)
-- @return (table) {
--   widths   = array of final values (same order as gaps),
--   total    = sum of widths,
--   achieved = boolean, whether total == target (within tolerance),
--   deficit  = number, remaining excess (>0) or shortfall (<0), 0 if achieved,
-- }
function M.solve(target, gaps)
    local widths, mins, maxs = {}, {}, {}
    local by_shrink, by_stretch, fallback_idx = {}, {}, {}
    local natural = 0

    for i, g in ipairs(gaps) do
        local w = g.width
        widths[i] = w
        mins[i] = g.min or w
        maxs[i] = g.max or w
        natural = natural + w
        if g.shrink_class then
            local t = by_shrink[g.shrink_class]
            if not t then t = {}; by_shrink[g.shrink_class] = t end
            t[#t + 1] = i
        end
        if g.stretch_class then
            local t = by_stretch[g.stretch_class]
            if not t then t = {}; by_stretch[g.stretch_class] = t end
            t[#t + 1] = i
        end
        if g.fallback then
            fallback_idx[#fallback_idx + 1] = i
        end
    end

    local delta = natural - target

    if delta > EPS then
        -- Too long: compress class by class in clreq order
        for _, class in ipairs(M.SHRINK_ORDER) do
            local idx = by_shrink[class]
            if idx then
                delta = delta - apply_equally(widths, mins, idx, delta, -1)
                if delta <= EPS then break end
            end
        end
    elseif delta < -EPS then
        -- Too short: expand class by class, then distribute the remainder
        -- evenly over fallback gaps (no upper bound, per clreq)
        local need = -delta
        for _, class in ipairs(M.STRETCH_ORDER) do
            local idx = by_stretch[class]
            if idx then
                need = need - apply_equally(widths, maxs, idx, need, 1)
                if need <= EPS then break end
            end
        end
        if need > EPS and #fallback_idx > 0 then
            local per_gap = need / #fallback_idx
            for _, i in ipairs(fallback_idx) do
                widths[i] = widths[i] + per_gap
            end
            need = 0
        end
        delta = -need
    end

    local total = 0
    for i = 1, #widths do total = total + widths[i] end

    local achieved = math.abs(delta) <= EPS
    return {
        widths = widths,
        total = total,
        achieved = achieved,
        deficit = achieved and 0 or delta,
    }
end

return M
