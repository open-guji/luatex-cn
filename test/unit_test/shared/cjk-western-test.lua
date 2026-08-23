-- Unit tests for shared.luatex-cn-cjk-western (clreq 中西混排间距规则)
-- 规则单一来源：横排 hori-spacing 与竖排 punct.flatten 都消费本模块。
local test_utils = require("test.test_utils")
local cw = require("shared.luatex-cn-cjk-western")

test_utils.run_test("kind: 汉字/全角字母数字为 cjk", function()
    test_utils.assert_eq(cw.kind(0x4E2D), "cjk")   -- 中
    test_utils.assert_eq(cw.kind(0x3007), "cjk")   -- 〇
    test_utils.assert_eq(cw.kind(0xFF21), "cjk")   -- Ａ
    test_utils.assert_eq(cw.kind(0xFF10), "cjk")   -- ０
end)

test_utils.run_test("kind: 西文字母/数字为 western，标点为 cjk_punct", function()
    test_utils.assert_eq(cw.kind(0x41), "western")   -- A
    test_utils.assert_eq(cw.kind(0x39), "western")   -- 9
    test_utils.assert_eq(cw.kind(0xE9), "western")   -- é
    test_utils.assert_eq(cw.kind(0xFF0C), "cjk_punct")  -- ，
    test_utils.assert_eq(cw.kind(0x300C), "cjk_punct")  -- 「
    test_utils.assert_eq(cw.kind(0x20), "other")     -- 空格
end)

test_utils.run_test("takes_spacing: 汉字↔西文边界加间距，双向", function()
    test_utils.assert_true(cw.takes_spacing(0x4E2D, 0x41))  -- 中→A
    test_utils.assert_true(cw.takes_spacing(0x41, 0x4E2D))  -- A→中
    test_utils.assert_true(cw.takes_spacing(0x4E2D, 0x31))  -- 中→1
end)

test_utils.run_test("takes_spacing: 纯中文/纯西文边界不加", function()
    test_utils.assert_true(not cw.takes_spacing(0x4E2D, 0x6587))  -- 中→文
    test_utils.assert_true(not cw.takes_spacing(0x41, 0x42))      -- A→B
    test_utils.assert_true(not cw.takes_spacing(0x41, 0x31))      -- A→1
end)

test_utils.run_test("takes_spacing: clreq 三类例外不加间距", function()
    -- 点号旁
    test_utils.assert_true(not cw.takes_spacing(0xFF0C, 0x41))  -- ，→A
    test_utils.assert_true(not cw.takes_spacing(0x41, 0x3002))  -- A→。
    -- 开始夹注符号之后
    test_utils.assert_true(not cw.takes_spacing(0x300C, 0x41))  -- 「→A
    -- 结束夹注符号之前
    test_utils.assert_true(not cw.takes_spacing(0x41, 0x300D))  -- A→」
end)

test_utils.run_test("takes_spacing: 非点号非夹注的中文标点同样不加", function()
    -- 连接号 / 分隔号 / 间隔号 / 破折号 / 省略号本身不是汉字，
    -- 「汉字与西文之间」这条规则从一开始就不覆盖它们。
    -- `1/4 em` 曾因此在 / 两侧各多出一个 1/4 em。
    test_utils.assert_true(not cw.takes_spacing(0x31, 0x2F))    -- 1→/
    test_utils.assert_true(not cw.takes_spacing(0x2F, 0x34))    -- /→4
    test_utils.assert_true(not cw.takes_spacing(0x61, 0x2D))    -- a→-
    test_utils.assert_true(not cw.takes_spacing(0xB7, 0x61))    -- ·→a
    test_utils.assert_true(not cw.takes_spacing(0x2014, 0x61))  -- —→a
end)

test_utils.run_test("GLUE: clreq 1/4em，可挤 1/8、拉 1/2", function()
    test_utils.assert_eq(cw.GLUE.width, 0.25)
    test_utils.assert_eq(cw.GLUE.shrink, 0.125)
    test_utils.assert_eq(cw.GLUE.stretch, 0.25)
end)

print("\nAll shared/cjk-western-test tests passed!")
