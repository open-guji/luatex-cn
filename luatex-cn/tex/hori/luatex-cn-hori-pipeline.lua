-- luatex-cn-hori-pipeline.lua
-- Node pipeline for the horizontal (clreq) backend.
--
-- pre_linebreak_filter (H1): walks each paragraph and inserts, at every
-- CJK-involved character boundary, the penalty / adjustable glue decided by
-- hori-spacing.lua; Western word spaces get tagged with the western_word
-- adjustment class (clreq 挤压第 2 级 / 拉伸第 1 级). TeX's line breaker then
-- handles break search globally (禁则 = penalty, 可调空间 = glue).
--
-- post_linebreak_filter (H2/H3): re-distributes each line's surplus or
-- shortfall by clreq priority via hori-adjust-line.lua (overriding TeX's
-- proportional distribution, reclaiming the line-final punctuation blank),
-- then draws the inter-line marks (专名号/书名号甲式/着重号) via
-- hori-linemark.lua.
--
-- Standalone: depends only on tex/shared/ and the hori/ siblings (never on
-- the vertical engine's core/).

local spacing = require("hori.luatex-cn-hori-spacing")
local adjust_line = require("hori.luatex-cn-hori-adjust-line")
local linemark = require("hori.luatex-cn-hori-linemark")
local punct_table = require("shared.luatex-cn-punct-table")
local punct_anchors = require("shared.luatex-cn-punct-anchors")

local pipeline = {}

local D = node.direct
local GLYPH = node.id("glyph")
local GLUE = node.id("glue")
local KERN = node.id("kern")
local PENALTY = node.id("penalty")
local WHATSIT = node.id("whatsit")
local MATH = node.id("math")

-- Adjustment-class attribute for the H2 redistribution pass
local ATTR_ADJUST_CLASS = luatexbase.attributes.cnhoriadjustclass
    or luatexbase.new_attribute("cnhoriadjustclass")
pipeline.ATTR_ADJUST_CLASS = ATTR_ADJUST_CLASS

-- Runtime options (set via setup)
local opts = {
    style = "mainland",
    level = "basic",
    cjk_latin_space = true,
    inter_cjk_stretch = 0.05,
    line_adjust = true,          -- H2 priority redistribution on/off
    line_end_punct = "compress", -- "compress" | "natural"
    quote_style = "keep",        -- "keep" | "auto" | "curly" | "corner"
    hanging_punct = false,       -- 行尾点号悬挂 (opt-in)
    avoid_orphan_char = true,    -- H5 段末孤字避免 (clreq: 前行借字)
    last_line = "left",          -- H5 段末行对齐: left|center|right|justify
    adjacent_punct = "1.5",      -- 连续标点缩减: "1.5"|"1"|"natural"
    line_start_bracket = "trim", -- 行首开始夹注符号: trim|natural
}

-- Resolved quote conversion target ("curly"/"corner"/nil). clreq 引号体例:
-- 简体横排用弯引号（先双后单），台湾用传统引号（先单后双）。默认 keep
-- （不改动来稿用字，体例转换须用户显式开启）；auto 按 style 选择。
local quote_target = nil

local function resolve_quote_target()
    local q = opts.quote_style
    if q == "curly" or q == "corner" then
        quote_target = q
    elseif q == "keep" then
        quote_target = nil
    else -- auto
        if opts.style == "taiwan" then
            quote_target = "corner"
        elseif opts.style == "mainland" then
            quote_target = "curly"
        else
            quote_target = nil
        end
    end
end

--- Configure the pipeline.
-- @param o (table) { style, level, cjk_latin_space, inter_cjk_stretch,
--   line_adjust, line_end_punct, quote_style, hanging_punct }
function pipeline.setup(o)
    if not o then return end
    if o.style ~= nil then opts.style = o.style end
    if o.level ~= nil then opts.level = o.level end
    if o.cjk_latin_space ~= nil then opts.cjk_latin_space = o.cjk_latin_space end
    if o.inter_cjk_stretch ~= nil then opts.inter_cjk_stretch = o.inter_cjk_stretch end
    if o.line_adjust ~= nil then opts.line_adjust = o.line_adjust end
    if o.line_end_punct ~= nil then opts.line_end_punct = o.line_end_punct end
    if o.quote_style ~= nil then opts.quote_style = o.quote_style end
    if o.hanging_punct ~= nil then opts.hanging_punct = o.hanging_punct end
    if o.avoid_orphan_char ~= nil then opts.avoid_orphan_char = o.avoid_orphan_char end
    if o.last_line ~= nil then opts.last_line = o.last_line end
    if o.adjacent_punct ~= nil then opts.adjacent_punct = o.adjacent_punct end
    if o.line_start_bracket ~= nil then opts.line_start_bracket = o.line_start_bracket end
    resolve_quote_target()
end

-- Interword space glue subtypes (LuaTeX: spaceskip / xspaceskip; ordinary
-- font spaces are emitted as spaceskip)
local SPACE_SUBTYPES = { [13] = true, [14] = true }

local function em_size(glyph_d)
    local fid = D.getfield(glyph_d, "font")
    local f = fid and font.getfont(fid)
    return (f and f.size) or 655360  -- fallback 10pt
end

local function make_penalty(value)
    local p = D.new(PENALTY)
    D.setfield(p, "penalty", value)
    return p
end

local function make_glue(width_sp, stretch_sp, shrink_sp, class_name)
    local g = D.new(GLUE)
    D.setfield(g, "width", width_sp)
    D.setfield(g, "stretch", stretch_sp)
    D.setfield(g, "shrink", shrink_sp)
    local code = spacing.ADJUST_CLASS_CODES[class_name]
    if code then
        D.set_attribute(g, ATTR_ADJUST_CLASS, code)
    end
    return g
end

-- Nodes transparent when walking for the previous/next glyph
local TRANSPARENT = {
    [KERN] = true, [GLUE] = true, [PENALTY] = true, [WHATSIT] = true,
}

local function prev_glyph_of(n)
    local p = D.getprev(n)
    while p do
        local id = D.getid(p)
        if id == GLYPH then return p end
        if not TRANSPARENT[id] then return nil end
        p = D.getprev(p)
    end
    return nil
end

-- 段末孤字避免（clreq H5: 段落最后一行不宜只剩一个汉字，孤字可带
-- 后随标点）：在段末「内容字」前的断点补 penalty 10000。TeX 的全局
-- 断行随之把前一行的字借到末行（前行借字），末行至少两字。
local function protect_paragraph_end(head_d)
    -- 最后一个字形（跳过段尾的 glue/penalty 等）
    local n = D.tail(head_d)
    while n and D.getid(n) ~= GLYPH do
        if not TRANSPARENT[D.getid(n)] then return end
        n = D.getprev(n)
    end
    if not n then return end
    -- 跳过末尾标点串，得到段末内容字
    local content = n
    while content do
        local c = D.getfield(content, "char")
        if not c or spacing.kind(c) ~= "cjk_punct" then break end
        content = prev_glyph_of(content)
    end
    if not content then return end
    local cc = D.getfield(content, "char")
    if not cc or spacing.kind(cc) ~= "cjk" then return end
    -- 内容字之前最近的断点 glue；其前已有禁断 penalty 则天然受保护
    local g = D.getprev(content)
    while g and (D.getid(g) == KERN or D.getid(g) == WHATSIT) do
        g = D.getprev(g)
    end
    if not g or D.getid(g) ~= GLUE then return end
    local before = D.getprev(g)
    if before and D.getid(before) == PENALTY
        and D.getfield(before, "penalty") >= 10000 then
        return
    end
    -- 须有前字可借
    if not prev_glyph_of(g) then return end
    D.insert_before(head_d, g, make_penalty(10000))
end

--- Process one node list: insert boundary nodes between adjacent glyphs.
-- Boundaries are only considered between glyphs separated by nothing or by
-- font kerns; an existing glue or penalty between two glyphs means the
-- document (or TeX) already decided that boundary — leave it alone. Math is
-- skipped wholesale; boxes/discretionaries reset the boundary context.
--
-- Insertion is done by relinking between the current node's predecessor and
-- the current node; since a boundary always has a preceding glyph, the list
-- head never changes.
-- @param head_d (direct node) list head
-- @return (direct node) list head (unchanged)
-- clreq 字面分布（度量锚定，共享层 punct-anchors）：把点号/中点类的墨迹
-- 挪到本风格的规范位置——中国大陆式靠左下（GB 惯例）、台湾式居中。字体把
-- 墨迹画在哪是字体的设计惯例（TW-Kai 两向居中、思源宋体左下），排版
-- 风格不应随字体漂移：中国大陆式文档用 TW-Kai 时点号也应落到左下，台湾式
-- 文档用思源宋体时也应居中。xoffset/yoffset 只挪字面不动 advance，
-- 对断行、间隙与 H2 二次分配均无影响。style=none / 无 bbox 时不动。
local function apply_ink_anchor(g)
    local c = D.getfield(g, "char")
    if not c then return end
    -- 先查锚点表（一次哈希查找），绝大多数字形（汉字/西文）在此返回，
    -- 不触碰 font.getfont
    if not punct_anchors.anchor(c, opts.style, "horizontal") then return end
    local fid = D.getfield(g, "font")
    local f = fid and font.getfont(fid)
    local desc = f and f.descriptions and f.descriptions[c]
    local bb = desc and desc.boundingbox
    local dx, dy = punct_anchors.offsets(c, opts.style, "horizontal",
        bb, (f and f.units_per_em) or 1000, f and f.size)
    if dx then
        D.setfield(g, "xoffset", dx)   -- 绝对写入：重复处理幂等
        D.setfield(g, "yoffset", dy)
    end
end
pipeline.apply_ink_anchor = apply_ink_anchor

function pipeline.process(head_d)
    local prev_glyph = nil
    local prev_node = nil     -- node immediately before curr in the walk
    local blocked = false     -- an intervening glue/penalty blocks insertion
    local math_level = 0

    local curr = head_d
    while curr do
        local id = D.getid(curr)

        if id == MATH then
            -- subtype 0 = math on, 1 = math off
            if D.getsubtype(curr) == 0 then
                math_level = math_level + 1
            else
                math_level = math_level - 1
                if math_level < 0 then math_level = 0 end
            end
            prev_glyph = nil
        elseif math_level > 0 then
            -- inside math: ignore everything
        elseif id == GLYPH then
            -- Opt-in quote style conversion (clreq 引号体例). Depth/role are
            -- preserved by the shared 1:1 map, so boundary decisions below
            -- see the converted character.
            if quote_target then
                local c0 = D.getfield(curr, "char")
                local conv = c0 and punct_table.quote_convert(c0, quote_target)
                if conv then D.setfield(curr, "char", conv) end
            end
            apply_ink_anchor(curr)
            if prev_glyph and not blocked then
                local a = D.getfield(prev_glyph, "char")
                local c = D.getfield(curr, "char")
                if a and c then
                    local action = spacing.boundary(a, c, opts)
                    if action and action.glue then
                        local em = em_size(prev_glyph)
                        local g = make_glue(
                            math.floor(action.glue.width * em + 0.5),
                            math.floor(action.glue.stretch * em + 0.5),
                            math.floor(action.glue.shrink * em + 0.5),
                            action.glue.class)
                        -- prev_node → [penalty] → glue → curr
                        if action.penalty then
                            local p = make_penalty(action.penalty)
                            D.setlink(prev_node, p)
                            D.setlink(p, g)
                        else
                            D.setlink(prev_node, g)
                        end
                        D.setlink(g, curr)
                    end
                end
            end
            prev_glyph = curr
            blocked = false
        elseif id == KERN or id == WHATSIT then
            -- transparent for boundary purposes (font kerns, marks)
        elseif id == GLUE or id == PENALTY then
            -- The boundary already has spacing/break semantics; skip it.
            -- Word spaces (from source blanks) get the western_word class so
            -- the H2 pass manages them at clreq 挤压第 2 级 / 拉伸第 1 级.
            -- clreq 数值界限按汉字宽夹紧：西文词距最小可挤到 1/4 汉字宽、
            -- 最大可拉到半个汉字宽（字体自身弹性越界时收窄）。
            if id == GLUE and SPACE_SUBTYPES[D.getsubtype(curr)]
                and D.getfield(curr, "width") > 0
                and not D.get_attribute(curr, ATTR_ADJUST_CLASS) then
                D.set_attribute(curr, ATTR_ADJUST_CLASS,
                    spacing.ADJUST_CLASS_CODES.western_word)
                if prev_glyph then
                    local em = em_size(prev_glyph)
                    local w = D.getfield(curr, "width")
                    local floor_w = math.min(w, math.floor(0.25 * em))
                    if w - D.getfield(curr, "shrink") < floor_w then
                        D.setfield(curr, "shrink", w - floor_w)
                    end
                    local ceil_w = math.max(w, math.floor(0.5 * em))
                    if w + D.getfield(curr, "stretch") > ceil_w then
                        D.setfield(curr, "stretch", ceil_w - w)
                    end
                end
            end
            blocked = true
        else
            -- boxes, discretionaries, rules, dirs, ...: reset context
            prev_glyph = nil
            blocked = false
        end

        prev_node = curr
        curr = D.getnext(curr)
    end

    return head_d
end

-- ============================================================================
-- Callback registration
-- ============================================================================

local CALLBACK_NAME = "luatexcn.hori.pre_linebreak"
local POST_CALLBACK_NAME = "luatexcn.hori.post_linebreak"
local enabled = false

local function pre_linebreak(head, groupcode)
    local d = D.todirect(head)
    d = pipeline.process(d)
    if opts.avoid_orphan_char then
        protect_paragraph_end(d)
    end
    return D.tonode(d)
end

-- Exposed for unit tests
pipeline.protect_paragraph_end = protect_paragraph_end

local function post_linebreak(head, groupcode)
    local d = D.todirect(head)
    if opts.line_adjust then
        d = adjust_line.process_lines(d, ATTR_ADJUST_CLASS, opts)
    end
    d = linemark.decorate(d)
    return D.tonode(d)
end

--- Register the pre/post_linebreak_filter pair (idempotent).
function pipeline.enable()
    if enabled then return end
    luatexbase.add_to_callback("pre_linebreak_filter", pre_linebreak, CALLBACK_NAME)
    luatexbase.add_to_callback("post_linebreak_filter", post_linebreak, POST_CALLBACK_NAME)
    enabled = true
end

--- Remove the callbacks (for tests / package unloading).
function pipeline.disable()
    if not enabled then return end
    luatexbase.remove_from_callback("pre_linebreak_filter", CALLBACK_NAME)
    luatexbase.remove_from_callback("post_linebreak_filter", POST_CALLBACK_NAME)
    enabled = false
end

return pipeline
