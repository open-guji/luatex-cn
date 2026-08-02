-- Unit tests for hori.luatex-cn-hori-spacing
-- Each test cites the clreq clause it verifies.
local test_utils = require("test.test_utils")
local spacing = require("hori.luatex-cn-hori-spacing")

local function b(prev, next_c, opts)
    return spacing.boundary(prev, next_c, opts)
end

-- ============================================================================
-- kind()
-- ============================================================================

test_utils.run_test("kind: han / fullwidth alnum are cjk", function()
    test_utils.assert_eq(spacing.kind(0x4E00), "cjk")   -- 一
    test_utils.assert_eq(spacing.kind(0x3007), "cjk")   -- 〇
    test_utils.assert_eq(spacing.kind(0xFF21), "cjk")   -- Ａ
    test_utils.assert_eq(spacing.kind(0xFF11), "cjk")   -- １
end)

test_utils.run_test("kind: classified punctuation is cjk_punct", function()
    test_utils.assert_eq(spacing.kind(0x3002), "cjk_punct")  -- 。
    test_utils.assert_eq(spacing.kind(0x300C), "cjk_punct")  -- 「
    test_utils.assert_eq(spacing.kind(0x2014), "cjk_punct")  -- —
end)

test_utils.run_test("kind: latin letters and digits are western", function()
    test_utils.assert_eq(spacing.kind(0x41), "western")  -- A
    test_utils.assert_eq(spacing.kind(0x39), "western")  -- 9
    test_utils.assert_eq(spacing.kind(0xE9), "western")  -- é
end)

test_utils.run_test("kind: inter-line marks and symbols are other", function()
    test_utils.assert_eq(spacing.kind(0xFF3F), "other")  -- ＿ 专名号
    test_utils.assert_eq(spacing.kind(0x25CF), "other")  -- ● 着重号
    test_utils.assert_eq(spacing.kind(0x20), "other")    -- space
end)

-- ============================================================================
-- Pure Western boundaries: leave to TeX
-- ============================================================================

test_utils.run_test("western-western boundary inserts nothing", function()
    -- clreq: 西文单词在可使用连字符处之外不得分隔 —— 正是 TeX 默认行为，
    -- 不插入任何节点以免破坏连字与词距
    test_utils.assert_nil(b(0x61, 0x62))   -- a|b
    test_utils.assert_nil(b(0x31, 0x32))   -- 1|2
    test_utils.assert_nil(b(0x61, 0x20))   -- a|space
end)

-- ============================================================================
-- Inter-CJK boundaries (clreq: 密排 + 拉伸兜底均分)
-- ============================================================================

test_utils.run_test("cjk-cjk: zero-width glue with fallback stretch", function()
    local r = b(0x4E00, 0x4E8C)  -- 一|二
    test_utils.assert_nil(r.penalty)
    test_utils.assert_eq(r.glue.width, 0)
    test_utils.assert_eq(r.glue.stretch, 0.05)
    test_utils.assert_eq(r.glue.class, "fallback")
end)

test_utils.run_test("cjk-punct: kinsoku penalty + glue kept for stretch", function()
    -- 一|。 行首禁则 → penalty 10000，但间隙仍保留拉伸能力
    local r = b(0x4E00, 0x3002)
    test_utils.assert_eq(r.penalty, 10000)
    test_utils.assert_not_nil(r.glue)
end)

test_utils.run_test("punct-cjk: break allowed after closing punctuation", function()
    local r = b(0x3002, 0x4E00)  -- 。|一
    test_utils.assert_nil(r.penalty)
end)

test_utils.run_test("open bracket may not end a line", function()
    local r = b(0x300C, 0x4E00)  -- 「|一
    test_utils.assert_eq(r.penalty, 10000)
end)

test_utils.run_test("kinsoku level is honored", function()
    -- — 行首禁止仅严格级
    test_utils.assert_nil(b(0x4E00, 0x2014, { level = "gb" }).penalty)
    test_utils.assert_eq(b(0x4E00, 0x2014, { level = "strict" }).penalty, 10000)
end)

test_utils.run_test("fullwidth digit run is unbreakable AND rigid", function()
    local r = b(0xFF11, 0xFF12)  -- １|２ (digit run via kinsoku)
    test_utils.assert_eq(r.penalty, 10000)
    -- 符号分离禁则单元内部不得被拉伸（clreq: 作为一个整体）：
    -- 无 stretch、无 adjust class（H2 兜底均分跳过）
    test_utils.assert_eq(r.glue.stretch, 0)
    test_utils.assert_nil(r.glue.class)
end)

test_utils.run_test("two-em pair interior is rigid; 一。boundary is not", function()
    local dash = b(0x2014, 0x2014)  -- —|—
    test_utils.assert_eq(dash.glue.stretch, 0)
    test_utils.assert_nil(dash.glue.class)
    -- 行末禁则边界（一|。）保有拉伸与 class：禁排不禁伸
    local stop = b(0x4E00, 0x3002)
    test_utils.assert_eq(stop.penalty, 10000)
    test_utils.assert_true(stop.glue.stretch > 0)
    test_utils.assert_not_nil(stop.glue.class)
end)

test_utils.run_test("stacked ？！ interior is rigid: no break, no stretch, no shrink", function()
    -- clreq 非典型标点：？？ ！！ ？！ ！？ 是两字宽刚性整体。
    -- 与 —— 不同，？！ 是点号、字面自带可挤空白——若不清零 shrink，
    -- TeX 的比例压缩仍会把这一对压到 2 字宽以下。
    for _, pair in ipairs({ { 0xFF1F, 0xFF01 }, { 0xFF01, 0xFF1F },
                            { 0xFF1F, 0xFF1F }, { 0xFF01, 0xFF01 } }) do
        local r = b(pair[1], pair[2])
        test_utils.assert_eq(r.penalty, 10000)
        test_utils.assert_eq(r.glue.stretch, 0)
        test_utils.assert_eq(r.glue.shrink, 0)
        test_utils.assert_nil(r.glue.class)
        test_utils.assert_eq(r.glue.width, 0, "对内不得有宽度缩减或间距")
    end
    -- 对外边界不受影响：叹问号与后续汉字之间照常（禁排不禁伸不适用——
    -- ？|汉 无禁则，属普通字间）
    local outer = b(0xFF01, 0x4E00)
    test_utils.assert_nil(outer.penalty)
end)

-- ============================================================================
-- CJK–Western spacing (clreq: 不多于 1/4 汉字宽，可挤 1/8、拉 1/2)
-- ============================================================================

test_utils.run_test("cjk-latin: quarter em glue, shrink to 1/8, stretch to 1/2", function()
    local r = b(0x4E00, 0x61)  -- 一|a
    test_utils.assert_nil(r.penalty)
    test_utils.assert_eq(r.glue.width, 0.25)
    test_utils.assert_eq(r.glue.shrink, 0.125)   -- 0.25 - 0.125 = 1/8 em floor
    test_utils.assert_eq(r.glue.stretch, 0.25)   -- 0.25 + 0.25 = 1/2 em cap
    test_utils.assert_eq(r.glue.class, "cjk_western")
end)

test_utils.run_test("latin-cjk: symmetric", function()
    local r = b(0x61, 0x4E00)  -- a|一
    test_utils.assert_eq(r.glue.width, 0.25)
    test_utils.assert_eq(r.glue.class, "cjk_western")
end)

test_utils.run_test("digit-cjk gets the spacing too", function()
    local r = b(0x39, 0x4E00)  -- 9|一
    test_utils.assert_eq(r.glue.width, 0.25)
end)

test_utils.run_test("exception: no spacing next to pause/stop marks", function()
    -- clreq: 在中文点号前后的西文字母，不调整字距或加入空白
    -- （。的字面末侧空白仍可挤压，故 shrink > 0、class 为句号组）
    local r = b(0x3002, 0x61)   -- 。|a
    test_utils.assert_eq(r.glue.width, 0)
    test_utils.assert_eq(r.glue.class, "fullstop_group")
    r = b(0x61, 0xFF0C)         -- a|，（，的空白在末侧，不贡献到此边界）
    test_utils.assert_eq(r.glue.width, 0)
    test_utils.assert_eq(r.glue.class, "fallback")
end)

-- ============================================================================
-- Punctuation blank-side shrink (clreq 标点符号的宽度调整)
-- ============================================================================

test_utils.run_test("mainland comma: trailing blank shrinkable after it", function()
    local r = b(0xFF0C, 0x4E00)  -- ，|一
    test_utils.assert_eq(r.glue.shrink, 0.5)
    test_utils.assert_eq(r.glue.class, "comma_group")
    -- but not before it (blank sits at the end side)
    r = b(0x4E00, 0xFF0C)        -- 一|，
    test_utils.assert_eq(r.glue.shrink, 0)
end)

test_utils.run_test("opening bracket: leading blank shrinkable before it", function()
    local r = b(0x4E00, 0xFF08)  -- 一|（
    test_utils.assert_eq(r.glue.shrink, 0.5)
    test_utils.assert_eq(r.glue.class, "bracket")
end)

test_utils.run_test("adjacent punctuation: unconditional 2→1.5 reduction (clreq 连续标点)", function()
    -- clreq: 夹注符号参与的标点连排「无论何种风格都应该」缩减——
    -- 。末侧 0.5 + 「始侧 0.5 共 1.0 空白：固定扣 0.5（对占 1.5 字宽），
    -- 余 0.5 仍作行内挤压容量
    local r = b(0x3002, 0x300C)  -- 。|「
    test_utils.assert_eq(r.glue.width, -0.5)
    test_utils.assert_eq(r.glue.shrink, 0.5)
end)

test_utils.run_test("adjacent punctuation: close+comma reduces its only half blank", function()
    -- 」|，：」末侧无空白（close 空白在 end？——close_bracket space=end），
    -- ，始侧无空白（mainland 逗号空白在末端）……以 ）|，验证：
    -- ）末侧 0.5、，始侧 0 → 空白 0.5 全部固定扣除，紧靠（对占 1.5）
    local r = b(0xFF09, 0xFF0C)  -- ）|，
    test_utils.assert_eq(r.glue.width, -0.5)
    test_utils.assert_eq(r.glue.shrink, 0)
end)

test_utils.run_test("adjacent punctuation: style '1' removes both blanks; natural keeps", function()
    local r = b(0x3002, 0x300C, { adjacent_punct = "1" })  -- 。|「 → 1 字宽
    test_utils.assert_eq(r.glue.width, -1.0)
    test_utils.assert_eq(r.glue.shrink, 0)
    local rn = b(0x3002, 0x300C, { adjacent_punct = "natural" })
    test_utils.assert_eq(rn.glue.width, 0)
    test_utils.assert_eq(rn.glue.shrink, 1.0)
end)

test_utils.run_test("adjacent punctuation: point+point pairs are NOT unconditional", function()
    -- 无夹注符号参与（如 。|，）：clreq 无条件条款不适用，仍为纯挤压容量
    local r = b(0x3002, 0xFF0C)  -- 。|，
    test_utils.assert_eq(r.glue.width, 0)
    test_utils.assert_eq(r.glue.shrink, 0.5)
end)

test_utils.run_test("taiwan centered marks contribute half per side", function()
    local r = b(0x3002, 0x4E00, { style = "taiwan" })  -- 。|一
    test_utils.assert_eq(r.glue.shrink, 0.25)
end)

test_utils.run_test("taiwan ？！ fixed: no shrink (horizontal)", function()
    local r = b(0xFF1F, 0x4E00, { style = "taiwan" })  -- ？|一
    test_utils.assert_eq(r.glue.shrink, 0)
end)

test_utils.run_test("colon is never shrinkable", function()
    local r = b(0xFF1A, 0x4E00)  -- ：|一
    test_utils.assert_eq(r.glue.shrink, 0)
end)

test_utils.run_test("style=none disables punctuation shrink", function()
    local r = b(0xFF0C, 0x4E00, { style = "none" })  -- ，|一
    test_utils.assert_eq(r.glue.shrink, 0)
    test_utils.assert_eq(r.glue.class, "fallback")
end)

test_utils.run_test("exception: no spacing inside brackets", function()
    -- clreq: 开始夹注符号之后、结束夹注符号之前不加
    local r = b(0xFF08, 0x61)   -- （|a
    test_utils.assert_eq(r.glue.width, 0)
    r = b(0x61, 0xFF09)         -- a|）
    test_utils.assert_eq(r.glue.width, 0)
end)

test_utils.run_test("cjk_latin_space=false disables the spacing", function()
    local r = b(0x4E00, 0x61, { cjk_latin_space = false })
    test_utils.assert_eq(r.glue.width, 0)
end)

test_utils.run_test("inter_cjk_stretch is configurable", function()
    local r = b(0x4E00, 0x4E8C, { inter_cjk_stretch = 0.1 })
    test_utils.assert_eq(r.glue.stretch, 0.1)
end)

print("All hori-spacing tests passed.")
