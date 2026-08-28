-- Unit tests for decorate.luatex-cn-decorate
local test_utils = require("test.test_utils")
local decorate = require("decorate.luatex-cn-decorate")

-- ============================================================================
-- register / get / clear_registry
-- ============================================================================

test_utils.run_test("register: returns incrementing IDs", function()
    decorate.clear_registry()
    local id1 = decorate.register("●", "0pt", "0pt", nil, nil, nil, nil)
    local id2 = decorate.register("○", "0pt", "0pt", nil, nil, nil, nil)
    test_utils.assert_type(id1, "number")
    test_utils.assert_type(id2, "number")
    test_utils.assert_true(id2 > id1)
end)

test_utils.run_test("get: retrieves registered decoration", function()
    decorate.clear_registry()
    local id = decorate.register("●", "1pt", "2pt", nil, "red", nil, nil)
    local reg = decorate.get(id)
    test_utils.assert_type(reg, "table")
    -- register_decorate stores char as codepoint number, not the original string
    test_utils.assert_eq(reg.char, utf8.codepoint("●", 1))
    test_utils.assert_eq(reg.color, "red")
end)

test_utils.run_test("get: nil for invalid ID", function()
    decorate.clear_registry()
    test_utils.assert_nil(decorate.get(999))
end)

test_utils.run_test("clear_registry: clears all entries", function()
    decorate.clear_registry()
    local id = decorate.register("●", "0pt", "0pt", nil, nil, nil, nil)
    test_utils.assert_true(decorate.get(id) ~= nil)
    decorate.clear_registry()
    test_utils.assert_nil(decorate.get(id))
end)

-- ============================================================================
-- clreq 5.3.1「标点符号上不加着重号」
-- ============================================================================
-- \EmphasisMark 在 skip-punct 开启时逐字调用此判定；判定的是**基字**，
-- 与装饰字符无关。分类走共享标点表，与横排 hori-linemark 同一口径。

test_utils.run_test("is_punct_char: 标点为真、汉字与西文为假", function()
    test_utils.assert_true(decorate.is_punct_char("，"))
    test_utils.assert_true(decorate.is_punct_char("。"))
    test_utils.assert_true(decorate.is_punct_char("："))
    test_utils.assert_true(decorate.is_punct_char("「"))
    test_utils.assert_true(decorate.is_punct_char("—"))
    test_utils.assert_true(decorate.is_punct_char("·"))   -- P1 扩类
    test_utils.assert_true(not decorate.is_punct_char("天"))
    test_utils.assert_true(not decorate.is_punct_char("A"))
end)

test_utils.run_test("is_punct_char: 非法输入不抛错", function()
    test_utils.assert_true(not decorate.is_punct_char(""))
    test_utils.assert_true(not decorate.is_punct_char(nil))
    test_utils.assert_true(not decorate.is_punct_char(42))
end)


-- ============================================================================
-- resolve_rgb（issue #163 同族：颜色值格式）
-- ============================================================================
-- 装饰件（句读点、圈发等）的颜色以前是 color_map[c] or c：颜色名之外的写法
-- 原样写进 PDF literal。"255,128,0" 不是合法的 PDF 语法，于是整条 literal
-- 失效，\句读设置{句读颜色={255,128,0}} 的点直接没有颜色。

test_utils.run_test("resolve_rgb: 颜色名走 color_map", function()
    local resolve_rgb = decorate._internal.resolve_rgb
    test_utils.assert_eq(resolve_rgb("red"), "1 0 0")
    test_utils.assert_eq(resolve_rgb("orange"), "1 0.5 0")
end)

test_utils.run_test("resolve_rgb: 0-255 三元组归一化（逗号或空格分隔）", function()
    local resolve_rgb = decorate._internal.resolve_rgb
    test_utils.assert_eq(resolve_rgb("255,128,0"), "1.0000 0.5020 0.0000")
    test_utils.assert_eq(resolve_rgb("255, 128, 0"), "1.0000 0.5020 0.0000")
    test_utils.assert_eq(resolve_rgb("255 128 0"), "1.0000 0.5020 0.0000")
end)

test_utils.run_test("resolve_rgb: 0-1 三元组原样保留数值", function()
    local resolve_rgb = decorate._internal.resolve_rgb
    test_utils.assert_eq(resolve_rgb("0.5 0.5 0"), "0.5000 0.5000 0.0000")
end)

test_utils.run_test("resolve_rgb: 空值与无法解析的值回落到黑色", function()
    local resolve_rgb = decorate._internal.resolve_rgb
    test_utils.assert_eq(resolve_rgb(nil), "0 0 0")
    test_utils.assert_eq(resolve_rgb(""), "0 0 0")
    test_utils.assert_eq(resolve_rgb("完全不是颜色"), "0 0 0")
end)

print("\nAll decorate/decorate-test tests passed!")
