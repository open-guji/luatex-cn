-- luatex-cn-hori-linemark.lua
-- H3: horizontal inter-line indication marks (行间标号, 单面装) — all drawn
-- BELOW the characters per clreq:
--   * 专名号: straight underline, hugging the hanzi (紧贴汉字)
--   * 书名号甲式: wavy underline
--   * 着重号: a dot under each character; never placed under punctuation
--     (clreq: 标点符号上不加着重号)
-- clreq "先线后点": the inter-line line sits closest to the glyphs, the
-- emphasis dots below that level.
-- Adjacent separate marks are shortened at the junction (两侧共缩短 ≤ 1/8 em)
-- so 「\专名{汉}\专名{高祖}」 remain visually distinct.
--
-- Marks ride on ATTR_LINEMARK, set through TeX grouping (tex.setattribute is
-- group-local); a per-call serial keeps adjacent same-kind marks apart.
-- Drawing happens per finished line in post_linebreak (after the H2
-- redistribution, so x positions are final) via origin-mode pdf literals —
-- no font glyphs involved, like the vertical decorate/linemark module.
--
-- plan_line() and the path builders are pure Lua (texlua-testable);
-- decorate() is the only node-touching part.

local punct_table = require("shared.luatex-cn-punct-table")

local M = {}

M.KIND_ZHUANMING = 1 -- 专名号 underline
M.KIND_SHUMING = 2   -- 书名号甲式 wavy line
M.KIND_EMPHASIS = 3  -- 着重号 dots

-- Attribute value = kind + 4 * serial; serial changes per \专名{...} call so
-- adjacent marks of the same kind stay separate runs.
local N_KINDS = 4
local serial = 0

M.ATTR_LINEMARK = luatexbase.attributes.cnhorilinemark
    or luatexbase.new_attribute("cnhorilinemark")

--- Group-local activation (called inside a TeX group).
-- @param kind (number) KIND_* constant
function M.mark_on(kind)
    serial = (serial + 1) % 4096
    tex.setattribute(M.ATTR_LINEMARK, kind + N_KINDS * serial)
end

-- ============================================================================
-- Geometry constants (em ratios)
-- ============================================================================

local LINE_DEPTH = 0.18     -- underline / wave center below baseline
local DOT_DEPTH = 0.30      -- 先线后点: dots sit below the line level
local LINE_WIDTH = 0.04     -- stroke width
local WAVE_AMPLITUDE = 0.045
local WAVE_PERIOD = 0.4     -- ideal period, scaled to fit the run
local DOT_RADIUS = 0.055
local JUNCTION_INSET = 1 / 16 -- per side; adjacent pair total = 1/8 em (clreq)

-- ============================================================================
-- Pure planning
-- ============================================================================

--- Plan the marks of one line.
-- @param items (table) array of glyph descriptors, in line order:
--   { mark = attr value|nil, x0, x1 (sp, line-relative), em (sp),
--     is_punct = boolean }
-- @return (table) array of draws:
--   { type = "underline"|"wave", anchor (item index), x0, x1 (sp), em } |
--   { type = "dots", anchor, centers = {sp...}, em }
function M.plan_line(items)
    -- Split into runs of identical mark value
    local runs = {}
    for i, it in ipairs(items) do
        if it.mark then
            local last = runs[#runs]
            if last and last.mark == it.mark and last.last_index == i - 1 then
                last.last_index = i
            else
                runs[#runs + 1] = { mark = it.mark, first_index = i, last_index = i }
            end
        end
    end

    local draws = {}
    for r, run in ipairs(runs) do
        local kind = run.mark % N_KINDS
        local first, last = items[run.first_index], items[run.last_index]
        local em = first.em
        -- Junction insets against an immediately adjacent marked run
        local inset_l, inset_r = 0, 0
        local prev_run, next_run = runs[r - 1], runs[r + 1]
        if prev_run and prev_run.last_index == run.first_index - 1 then
            inset_l = JUNCTION_INSET * em
        end
        if next_run and next_run.first_index == run.last_index + 1 then
            inset_r = JUNCTION_INSET * em
        end

        if kind == M.KIND_EMPHASIS then
            local centers = {}
            for i = run.first_index, run.last_index do
                local it = items[i]
                if not it.is_punct then
                    centers[#centers + 1] = (it.x0 + it.x1) / 2
                end
            end
            if #centers > 0 then
                draws[#draws + 1] = { type = "dots", anchor = run.first_index,
                                      centers = centers, em = em }
            end
        elseif kind == M.KIND_ZHUANMING or kind == M.KIND_SHUMING then
            draws[#draws + 1] = {
                type = (kind == M.KIND_ZHUANMING) and "underline" or "wave",
                anchor = run.first_index,
                x0 = first.x0 + inset_l,
                x1 = last.x1 - inset_r,
                em = em,
            }
        end
    end
    return draws
end

-- ============================================================================
-- Pure path builders (origin-mode pdf literal, units bp, x relative to the
-- anchor glyph's start, baseline at y = 0)
-- ============================================================================

local SP_PER_BP = 65781.76

local function bp(sp)
    return sp / SP_PER_BP
end

--- Straight underline path.
-- @param x0,x1 (sp) run extent relative to the anchor glyph start
-- @param em (sp)
-- @return (string) PDF path
function M.underline_path(x0, x1, em)
    local y = -LINE_DEPTH * bp(em)
    return string.format("q %.4f w %.4f %.4f m %.4f %.4f l S Q",
        LINE_WIDTH * bp(em), bp(x0), y, bp(x1), y)
end

--- Wavy underline path: C1-continuous sine approximation, four cubic Bézier
-- quarters per period (same construction as the vertical
-- decorate/linemark module, axis swapped to horizontal). The period is
-- scaled so a whole number of periods fits the run.
function M.wave_path(x0, x1, em)
    local len = x1 - x0
    if len <= 0 then return "" end
    local yc = -LINE_DEPTH * bp(em)
    local A = WAVE_AMPLITUDE * bp(em)
    local n = math.max(1, math.floor(len / (WAVE_PERIOD * em) + 0.5))
    local period = bp(len) / n
    local h = period / 4
    local cx = math.pi * A / 6 -- amplitude handle at zero crossings
    local cy = period / 12     -- along-axis handle
    local parts = {
        string.format("q %.4f w %.4f %.4f m", LINE_WIDTH * bp(em), bp(x0), yc),
    }
    for i = 1, n do
        local x = bp(x0) + (i - 1) * period
        parts[#parts + 1] = string.format(
            "%.4f %.4f %.4f %.4f %.4f %.4f c",
            x + cy, yc + cx, x + h - cy, yc + A, x + h, yc + A)
        parts[#parts + 1] = string.format(
            "%.4f %.4f %.4f %.4f %.4f %.4f c",
            x + h + cy, yc + A, x + 2 * h - cy, yc + cx, x + 2 * h, yc)
        parts[#parts + 1] = string.format(
            "%.4f %.4f %.4f %.4f %.4f %.4f c",
            x + 2 * h + cy, yc - cx, x + 3 * h - cy, yc - A, x + 3 * h, yc - A)
        parts[#parts + 1] = string.format(
            "%.4f %.4f %.4f %.4f %.4f %.4f c",
            x + 3 * h + cy, yc - A, x + 4 * h - cy, yc - cx, x + 4 * h, yc)
    end
    parts[#parts + 1] = "S Q"
    return table.concat(parts, " ")
end

--- Emphasis dots path: one filled circle per character center.
-- @param centers (table) array of sp x positions relative to the anchor
function M.dots_path(centers, em)
    local r = DOT_RADIUS * bp(em)
    local k = 0.5523 * r
    local y = -DOT_DEPTH * bp(em)
    local parts = { "q" }
    for _, c in ipairs(centers) do
        local x = bp(c)
        parts[#parts + 1] = string.format(
            "%.4f %.4f m "
            .. "%.4f %.4f %.4f %.4f %.4f %.4f c "
            .. "%.4f %.4f %.4f %.4f %.4f %.4f c "
            .. "%.4f %.4f %.4f %.4f %.4f %.4f c "
            .. "%.4f %.4f %.4f %.4f %.4f %.4f c f",
            x + r, y,
            x + r, y + k, x + k, y + r, x, y + r,
            x - k, y + r, x - r, y + k, x - r, y,
            x - r, y - k, x - k, y - r, x, y - r,
            x + k, y - r, x + r, y - k, x + r, y)
    end
    parts[#parts + 1] = "Q"
    return table.concat(parts, " ")
end

-- ============================================================================
-- Node application
-- ============================================================================

local D = node.direct
local HLIST = node.id("hlist")
local VLIST = node.id("vlist")
local RULE = node.id("rule")
local GLYPH = node.id("glyph")
local GLUE = node.id("glue")
local KERN = node.id("kern")
local WHATSIT = node.id("whatsit")
local PDF_LITERAL = node.subtype("pdf_literal")

local function em_size(glyph_d)
    local fid = D.getfield(glyph_d, "font")
    local f = fid and font.getfont(fid)
    return (f and f.size) or 655360
end

local function make_literal(str)
    local w = D.new(WHATSIT, PDF_LITERAL)
    D.setfield(w, "mode", 0) -- origin: coordinates relative to current point
    D.setfield(w, "data", str)
    return w
end

--- Draw the marks of one packed line: collect glyph positions, plan, and
-- insert one origin-mode pdf literal before each run's first glyph.
-- @param line (direct node) hlist (subtype line)
-- @return (boolean) whether anything was drawn
function M.decorate_line(line)
    local head = D.getlist(line)
    if not head then return false end

    local items, nodes = {}, {}
    local x = 0
    local any_marked = false
    local n = head
    while n do
        local id = D.getid(n)
        if id == GLYPH then
            local w = D.getfield(n, "width")
            local mark = D.get_attribute(n, M.ATTR_LINEMARK)
            if mark then any_marked = true end
            local c = D.getfield(n, "char")
            items[#items + 1] = {
                mark = mark, x0 = x, x1 = x + w, em = em_size(n),
                is_punct = (c and punct_table.class_of(c)) and true or false,
            }
            nodes[#nodes + 1] = n
            x = x + w
        elseif id == GLUE then
            x = x + (D.effective_glue(n, line) or D.getfield(n, "width"))
        elseif id == KERN then
            x = x + D.getfield(n, "kern")
        elseif id == HLIST or id == VLIST or id == RULE then
            x = x + (D.getfield(n, "width") or 0)
        end
        n = D.getnext(n)
    end
    if not any_marked then return false end

    local drew = false
    for _, draw in ipairs(M.plan_line(items)) do
        local anchor = nodes[draw.anchor]
        local ax = items[draw.anchor].x0
        local path
        if draw.type == "underline" then
            path = M.underline_path(draw.x0 - ax, draw.x1 - ax, draw.em)
        elseif draw.type == "wave" then
            path = M.wave_path(draw.x0 - ax, draw.x1 - ax, draw.em)
        else
            local rel = {}
            for i, c in ipairs(draw.centers) do rel[i] = c - ax end
            path = M.dots_path(rel, draw.em)
        end
        if path and path ~= "" then
            head = D.insert_before(head, anchor, make_literal(path))
            drew = true
        end
    end
    if drew then D.setlist(line, head) end
    return drew
end

-- clreq 行距下限: 单面装的行间标注要求行距（行的间空）≥ 0.5 em；
-- 不足时标注会贴到下一行字面。检测到第一次违反时给出一次性 warning。
local MIN_LEADING_EM = 0.5
local leading_warned = false

local function check_leading(line)
    if leading_warned then return end
    local first_glyph = nil
    local n = D.getlist(line)
    while n do
        if D.getid(n) == GLYPH then first_glyph = n break end
        n = D.getnext(n)
    end
    if not first_glyph then return end
    local em = em_size(first_glyph)
    local baselineskip = tex.getglue and tex.getglue("baselineskip")
        or tex.baselineskip.width
    local leading = baselineskip - em
    if leading < MIN_LEADING_EM * em then
        leading_warned = true
        texio.write_nl("term and log", string.format(
            "Package luatex-cn-hori Warning: 行间标注要求行距 >= 0.5em "
            .. "(clreq 单面装), 当前约 %.2fem — 标注可能触及下一行, "
            .. "建议加大 \\linespread 或 \\baselineskip。",
            leading / em))
    end
end

--- Walk a post_linebreak vertical list and decorate every line.
-- @param head_d (direct node)
-- @return (direct node) head (unchanged)
function M.decorate(head_d)
    local n = head_d
    while n do
        if D.getid(n) == HLIST and D.getsubtype(n) == 1 then
            if M.decorate_line(n) then check_leading(n) end
        end
        n = D.getnext(n)
    end
    return head_d
end

return M
