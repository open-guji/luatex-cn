-- Unit tests for shared.luatex-cn-punct-anchors
-- clreq《标点符号的字面分布》与 6.3.2.1 图 30《标点符号的调整空间》：
-- 点号的字面分布分风格（中国大陆式偏靠 / 台湾式居中），夹注号则**两种风格
-- 都是单侧**——开始夹注符号空白在始端、结束夹注符号空白在末端；图 30 的
-- 「字面上下两侧（居中）」一组只有点号与间隔号，没有夹注号。
-- 夹注号只锚直排（横排 advance 起点即字幅始端，字面分布交给字体）。
local test_utils = require("test.test_utils")
local anchors = require("shared.luatex-cn-punct-anchors")

local COMMA = 0xFF0C      -- ，
local FULLSTOP = 0x3002   -- 。
local OPEN_QUOTE = 0x300C -- 「
local CLOSE_QUOTE = 0x300D -- 」
local OPEN_BOOK = 0x300A  -- 《
local CLOSE_BOOK = 0x300B -- 》
local OPEN_PAREN = 0xFF08 -- （
local CLOSE_PAREN = 0xFF09 -- ）
local HANZI = 0x5B57      -- 字

local function approx(a, b)
    test_utils.assert_true(a and math.abs(a - b) < 1e-9,
        string.format("expected %.6f, got %s", b, tostring(a)))
end

-- ============================================================================
-- 点号：风格相关（回归守卫，锁住既有落点）
-- ============================================================================

test_utils.run_test("点号：中国大陆式直排偏靠右上、台湾式居中", function()
    test_utils.assert_eq(anchors.anchor(COMMA, "mainland", "vertical").x, 0.857)
    approx(anchors.anchor(FULLSTOP, "mainland", "vertical").y, 0.55)
    approx(anchors.anchor(COMMA, "taiwan", "vertical").x, 0.495)
end)

test_utils.run_test("style=none 不调整预设：点号与夹注号都不锚定", function()
    test_utils.assert_eq(anchors.anchor(COMMA, "none", "vertical"), nil)
    test_utils.assert_eq(anchors.anchor(FULLSTOP, "none", "horizontal"), nil)
end)

-- ============================================================================
-- 夹注号横排：不锚定（横排 advance 起点即字幅始端，字面分布交给字体）
-- ============================================================================

test_utils.run_test("横排夹注号不进锚点表：字面分布交给字体", function()
    test_utils.assert_eq(anchors.anchor(OPEN_BOOK, "mainland", "horizontal"), nil)
    test_utils.assert_eq(anchors.anchor(CLOSE_BOOK, "taiwan", "horizontal"), nil)
    test_utils.assert_eq(anchors.anchor(OPEN_PAREN, "mainland", "horizontal"), nil)
    test_utils.assert_eq(anchors.anchor(CLOSE_QUOTE, "mainland", "vertical"), nil)
end)

-- ============================================================================
-- 夹注号直排（clreq 图 30：字面上侧 = 开始，字面下侧 = 结束）
-- ============================================================================

-- 直排按「字形 height/depth 盒居中于字幅」落点，故位移是相对量：
--   dy = ±0.25 + (h − d)/2 − 墨心
local function dy(class, bb, h_em, d_em)
    return anchors.vert_bracket_dy(class, bb, 1000, h_em, d_em)
end

test_utils.run_test("直排结束夹注符号：字面移到上半格中点", function()
    -- 墨迹 [0.30, 0.68] → 墨心 0.49；luaotfload 的 depth 被截为 0，h = 0.68
    -- 落点把 [0, 0.68] 盒居中 → 字面中心比字幅中心低 (0.49 − 0.34) = 0.15
    -- 期望上移到 +0.25：dy = 0.25 + 0.34 − 0.49 = 0.10
    approx(dy("close", { 300, 300, 700, 680 }, 0.68, 0), 0.10)
end)

test_utils.run_test("直排开始夹注符号：字面移到下半格中点", function()
    approx(dy("open", { 300, 300, 700, 680 }, 0.68, 0), -0.40)
end)

test_utils.run_test("直排夹注号：墨迹上下对称的字形只需半格位移", function()
    -- 墨心 = 0.25，h = 0.5、d = 0 → (h−d)/2 = 0.25 = 墨心，落点即字幅中心
    approx(dy("close", { 300, 0, 700, 500 }, 0.5, 0), 0.25)
    approx(dy("open", { 300, 0, 700, 500 }, 0.5, 0), -0.25)
end)

test_utils.run_test("直排夹注号：非夹注号与数据不全时不给位移", function()
    test_utils.assert_eq(dy("comma", { 300, 0, 700, 500 }, 0.5, 0), nil)
    test_utils.assert_eq(dy("close", nil, 0.5, 0), nil)
    test_utils.assert_eq(anchors.vert_bracket_dy("close", { 300, 0, 700, 500 },
        0, 0.5, 0), nil)
    test_utils.assert_eq(dy("close", { 300, 0, 700, 500 }, nil, 0), nil)
end)

test_utils.run_test("汉字不在锚点表内（快路径：一次哈希查找即返回）", function()
    test_utils.assert_eq(anchors.anchor(HANZI, "mainland", "horizontal"), nil)
    test_utils.assert_eq(anchors.anchor(HANZI, "taiwan", "vertical"), nil)
end)
