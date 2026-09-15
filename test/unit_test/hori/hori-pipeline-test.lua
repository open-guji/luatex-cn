-- Unit tests for hori.luatex-cn-hori-pipeline (mocked node lists)
local test_utils = require("test.test_utils")
local pipeline = require("hori.luatex-cn-hori-pipeline")
local spacing = require("hori.luatex-cn-hori-spacing")

local GLYPH = node.id("glyph")
local GLUE = node.id("glue")
local PENALTY = node.id("penalty")
local KERN = node.id("kern")

local EM = 655360  -- mock font.getfont().size

local function glyph(char)
    return test_utils.make_direct_node(GLYPH, { char = char, font = 0 })
end

-- Collect {id=..., ...} descriptors of a direct list for easy assertions
local function describe(head)
    local out = {}
    local n = head
    while n do
        local d = { id = n.id }
        if n.id == GLYPH then d.char = n.char end
        if n.id == GLUE then
            d.width, d.stretch, d.shrink = n.width, n.stretch, n.shrink
            d.class = node.direct.get_attribute(n, pipeline.ATTR_ADJUST_CLASS)
        end
        if n.id == PENALTY then d.penalty = n.penalty end
        out[#out + 1] = d
        n = n.next
    end
    return out
end

-- Reset options before each scenario
local function run(nodes, setup)
    pipeline.setup({ style = "mainland", level = "basic",
                     cjk_latin_space = true, inter_cjk_stretch = 0.05,
                     quote_style = "keep", hanging_punct = false })
    if setup then pipeline.setup(setup) end
    local head = test_utils.link_nodes(nodes)
    return describe(pipeline.process(head))
end

-- ============================================================================

test_utils.run_test("cjk-cjk: glue inserted between hanzi", function()
    local seq = run({ glyph(0x4E00), glyph(0x4E8C) })  -- 一二
    test_utils.assert_eq(#seq, 3)
    test_utils.assert_eq(seq[1].char, 0x4E00)
    test_utils.assert_eq(seq[2].id, GLUE)
    test_utils.assert_eq(seq[2].width, 0)
    test_utils.assert_eq(seq[2].stretch, math.floor(0.05 * EM + 0.5))
    test_utils.assert_eq(seq[2].class, spacing.ADJUST_CLASS_CODES.fallback)
    test_utils.assert_eq(seq[3].char, 0x4E8C)
end)

test_utils.run_test("kinsoku: penalty precedes the glue before 。", function()
    local seq = run({ glyph(0x4E00), glyph(0x3002) })  -- 一。
    test_utils.assert_eq(#seq, 4)
    test_utils.assert_eq(seq[2].id, PENALTY)
    test_utils.assert_eq(seq[2].penalty, 10000)
    test_utils.assert_eq(seq[3].id, GLUE)
end)

test_utils.run_test("cjk-latin: quarter-em glue with adjust attribute", function()
    local seq = run({ glyph(0x4E00), glyph(0x61) })  -- 一a
    test_utils.assert_eq(#seq, 3)
    test_utils.assert_eq(seq[2].id, GLUE)
    test_utils.assert_eq(seq[2].width, math.floor(0.25 * EM + 0.5))
    test_utils.assert_eq(seq[2].shrink, math.floor(0.125 * EM + 0.5))
    test_utils.assert_eq(seq[2].stretch, math.floor(0.25 * EM + 0.5))
    test_utils.assert_eq(seq[2].class, spacing.ADJUST_CLASS_CODES.cjk_western)
end)

test_utils.run_test("latin-latin: nothing inserted", function()
    local seq = run({ glyph(0x61), glyph(0x62), glyph(0x63) })  -- abc
    test_utils.assert_eq(#seq, 3)
    for _, d in ipairs(seq) do
        test_utils.assert_eq(d.id, GLYPH)
    end
end)

test_utils.run_test("existing glue blocks insertion (source space wins)", function()
    -- 一 [existing space glue] a : clreq 允许用西文词间空格替代中西间距
    local sp = test_utils.make_direct_node(GLUE, { width = 100000, stretch = 0, shrink = 0 })
    local seq = run({ glyph(0x4E00), sp, glyph(0x61) })
    test_utils.assert_eq(#seq, 3)  -- nothing added
    test_utils.assert_eq(seq[2].width, 100000)
end)

-- 西文词距（源码空格）的 clreq 界限：最小 1/4 em、最大 1/2 em
local function word_space(w, stretch, shrink)
    -- subtype 13 = spaceskip（字体空格）
    return test_utils.make_direct_node(GLUE,
        { subtype = 13, width = w, stretch = stretch, shrink = shrink })
end

test_utils.run_test("word space: shrink clamped so the gap stays >= 1/4 em", function()
    -- 0.33 em 空格、shrink 0.2 em：最小只能挤到 1/4 em → shrink 收窄为 0.08 em
    local w = math.floor(0.33 * EM)
    local seq = run({ glyph(0x61), word_space(w, 0, math.floor(0.2 * EM)), glyph(0x62) })
    test_utils.assert_eq(#seq, 3)
    test_utils.assert_eq(seq[2].class, spacing.ADJUST_CLASS_CODES.western_word)
    test_utils.assert_eq(seq[2].shrink, w - math.floor(0.25 * EM))
end)

test_utils.run_test("word space narrower than 1/4 em keeps the font's own shrink", function()
    -- Source Sans 3 的空格只有 0.2 em，本就低于下限：界限只收窄弹性，不能把
    -- shrink 清成 0——否则纯西文行没有任何可挤压量，只能出 Overfull
    local w = math.floor(0.2 * EM)
    local shrink = math.floor(0.07 * EM)
    local seq = run({ glyph(0x61), word_space(w, 0, shrink), glyph(0x62) })
    test_utils.assert_eq(seq[2].shrink, shrink)
    test_utils.assert_eq(seq[2].width, w)
end)

test_utils.run_test("word space wider than 1/2 em keeps the font's own stretch", function()
    local w = math.floor(0.6 * EM)
    local stretch = math.floor(0.3 * EM)
    local seq = run({ glyph(0x61), word_space(w, stretch, 0), glyph(0x62) })
    test_utils.assert_eq(seq[2].stretch, stretch)
end)

test_utils.run_test("word space: stretch clamped so the gap stays <= 1/2 em", function()
    local w = math.floor(0.33 * EM)
    local seq = run({ glyph(0x61), word_space(w, math.floor(0.5 * EM), 0), glyph(0x62) })
    test_utils.assert_eq(seq[2].stretch, math.floor(0.5 * EM) - w)
end)

test_utils.run_test("word space exactly 1/2 em (TW-Kai) still has stretch clamped to 0", function()
    -- 界限含端点：空格已顶到上限，任何 stretch 都会把词距拉过 1/2 em
    local w = math.floor(0.5 * EM)
    local seq = run({ glyph(0x61), word_space(w, math.floor(0.25 * EM), 0), glyph(0x62) })
    test_utils.assert_eq(seq[2].stretch, 0)
end)

test_utils.run_test("word space exactly 1/4 em still has shrink clamped to 0", function()
    local w = math.floor(0.25 * EM)
    local seq = run({ glyph(0x61), word_space(w, 0, math.floor(0.1 * EM)), glyph(0x62) })
    test_utils.assert_eq(seq[2].shrink, 0)
end)

test_utils.run_test("font kern is transparent for the boundary", function()
    local k = test_utils.make_direct_node(KERN, { kern = 500 })
    local seq = run({ glyph(0x4E00), k, glyph(0x4E8C) })
    -- glue inserted after the kern, before the second glyph
    test_utils.assert_eq(#seq, 4)
    test_utils.assert_eq(seq[2].id, KERN)
    test_utils.assert_eq(seq[3].id, GLUE)
    test_utils.assert_eq(seq[4].char, 0x4E8C)
end)

test_utils.run_test("kinsoku level option is honored", function()
    local seq = run({ glyph(0x4E00), glyph(0x2014) }, { level = "strict" })  -- 一—
    test_utils.assert_eq(seq[2].id, PENALTY)
    local seq_basic = run({ glyph(0x4E00), glyph(0x2014) })
    test_utils.assert_eq(seq_basic[2].id, GLUE)  -- no penalty at basic
end)

test_utils.run_test("cjk-latin-space=false falls back to bare break point", function()
    local seq = run({ glyph(0x4E00), glyph(0x61) }, { cjk_latin_space = false })
    test_utils.assert_eq(seq[2].id, GLUE)
    test_utils.assert_eq(seq[2].width, 0)
end)

test_utils.run_test("quote conversion is opt-in: default keep leaves quotes alone", function()
    local seq = run({ glyph(0x300C), glyph(0x4E00) })  -- 「一
    test_utils.assert_eq(seq[1].char, 0x300C)
end)

test_utils.run_test("quote-style=curly converts corner quotes (clreq 引号体例)", function()
    local seq = run({ glyph(0x300C), glyph(0x4E00), glyph(0x300D) },
                    { quote_style = "curly" })
    test_utils.assert_eq(seq[1].char, 0x201C)          -- 「→“
    test_utils.assert_eq(seq[#seq].char, 0x201D)       -- 」→”
    -- 转换后的字符参与禁则：行尾禁断在“ 之后
    -- （“ 属 open 类，boundary 应带 penalty）
    local found_penalty = false
    for _, d in ipairs(seq) do
        if d.penalty == 10000 then found_penalty = true end
    end
    test_utils.assert_true(found_penalty)
end)

test_utils.run_test("quote-style=auto follows style; corner for taiwan", function()
    local seq = run({ glyph(0x201C), glyph(0x4E00) },
                    { style = "taiwan", quote_style = "auto" })
    test_utils.assert_eq(seq[1].char, 0x300C)          -- “→「
end)

-- ============================================================================
-- H5 段末孤字避免（clreq: 段落末行不宜只剩一个汉字）
-- ============================================================================

local function protect(nodes, setup)
    pipeline.setup({ style = "mainland", level = "basic",
                     cjk_latin_space = true, inter_cjk_stretch = 0.05,
                     quote_style = "keep" })
    if setup then pipeline.setup(setup) end
    local head = test_utils.link_nodes(nodes)
    head = pipeline.process(head)
    pipeline.protect_paragraph_end(head)
    return describe(head)
end

test_utils.run_test("orphan-char: penalty guards the break before the last hanzi", function()
    local seq = protect({ glyph(0x4E00), glyph(0x4E8C), glyph(0x4E09) })  -- 一二三
    -- 一 [glue] 二 [P10000] [glue] 三：末字前断点被禁
    test_utils.assert_eq(#seq, 6)
    test_utils.assert_eq(seq[4].id, PENALTY)
    test_utils.assert_eq(seq[4].penalty, 10000)
    test_utils.assert_eq(seq[5].id, GLUE)
    test_utils.assert_eq(seq[6].char, 0x4E09)
end)

test_utils.run_test("orphan-char: trailing punctuation rides with the content char", function()
    local seq = protect({ glyph(0x4E00), glyph(0x4E8C), glyph(0x4E09), glyph(0x3002) })
    -- 内容末字 = 三（。为孤字附属）：三 之前的断点受禁
    local guard = nil
    for i, d in ipairs(seq) do
        if d.char == 0x4E09 then
            test_utils.assert_eq(seq[i - 1].id, GLUE)
            guard = seq[i - 2]
        end
    end
    test_utils.assert_eq(guard.id, PENALTY)
    test_utils.assert_eq(guard.penalty, 10000)
end)

test_utils.run_test("orphan-char: single-char paragraph and western tail untouched", function()
    local seq = protect({ glyph(0x4E00) })
    test_utils.assert_eq(#seq, 1)
    -- 末为西文（ab）：孤字规则只针对汉字，不插任何 penalty
    local seq2 = protect({ glyph(0x4E00), glyph(0x61), glyph(0x62) })
    for _, d in ipairs(seq2) do
        test_utils.assert_false(d.id == PENALTY)
    end
end)

test_utils.run_test("head is preserved", function()
    local g1, g2 = glyph(0x4E00), glyph(0x4E8C)
    test_utils.link_nodes({ g1, g2 })
    local head = pipeline.process(g1)
    test_utils.assert_eq(head, g1)
end)

test_utils.run_test("ink anchor: 中国大陆式把居中字形的点号墨迹挪到左下", function()
    -- 模拟 TW-Kai（字形居中，bbox 中心 (0.495, 0.311)）在中国大陆式横排：
    -- 墨迹应被挪去左下锚点 → xoffset/yoffset 均为负
    local orig_getfont = font.getfont
    font.getfont = function(id)
        return { size = EM, units_per_em = 1000,
                 descriptions = { [0xFF0C] = { boundingbox = { 425, 241, 565, 381 } } } }
    end
    local g = glyph(0xFF0C)
    pipeline.apply_ink_anchor(g)
    font.getfont = orig_getfont
    test_utils.assert_true((g.xoffset or 0) < 0, "应向左挪")
    test_utils.assert_true((g.yoffset or 0) < 0, "应向下挪")
end)

test_utils.run_test("ink anchor: 汉字与无 bbox 字形不动", function()
    local orig_getfont = font.getfont
    font.getfont = function(id)
        return { size = EM, units_per_em = 1000, descriptions = {} }
    end
    local h = glyph(0x4E00)
    pipeline.apply_ink_anchor(h)
    local p = glyph(0xFF0C)   -- 有锚点但查不到 bbox
    pipeline.apply_ink_anchor(p)
    font.getfont = orig_getfont
    test_utils.assert_eq(h.xoffset or 0, 0)
    test_utils.assert_eq(p.xoffset or 0, 0)
end)

print("All hori-pipeline tests passed.")
