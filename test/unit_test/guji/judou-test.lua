-- Unit tests for guji.luatex-cn-guji-judou
local test_utils = require("test.test_utils")
local judou = require("guji.luatex-cn-guji-judou")

-- ============================================================================
-- get_punctuation_type
-- ============================================================================

test_utils.run_test("get_punctuation_type: ju (句) characters", function()
    test_utils.assert_eq(judou.get_punctuation_type(0x3002), "ju") -- 。
    test_utils.assert_eq(judou.get_punctuation_type(0xFF1F), "ju") -- ？
    test_utils.assert_eq(judou.get_punctuation_type(0xFF01), "ju") -- ！
end)

test_utils.run_test("get_punctuation_type: dou (读) characters", function()
    test_utils.assert_eq(judou.get_punctuation_type(0xFF0C), "dou") -- ，
    test_utils.assert_eq(judou.get_punctuation_type(0xFF1B), "dou") -- ；
    test_utils.assert_eq(judou.get_punctuation_type(0xFF1A), "dou") -- ：
    test_utils.assert_eq(judou.get_punctuation_type(0x3001), "dou") -- 、
end)

test_utils.run_test("get_punctuation_type: close brackets", function()
    test_utils.assert_eq(judou.get_punctuation_type(0x300D), "close") -- 」
    test_utils.assert_eq(judou.get_punctuation_type(0x300F), "close") -- 』
    test_utils.assert_eq(judou.get_punctuation_type(0xFF09), "close") -- ）
    test_utils.assert_eq(judou.get_punctuation_type(0x300B), "close") -- 》
end)

test_utils.run_test("get_punctuation_type: open brackets", function()
    test_utils.assert_eq(judou.get_punctuation_type(0x300C), "open") -- 「
    test_utils.assert_eq(judou.get_punctuation_type(0x300E), "open") -- 『
    test_utils.assert_eq(judou.get_punctuation_type(0xFF08), "open") -- （
    test_utils.assert_eq(judou.get_punctuation_type(0x300A), "open") -- 《
end)

test_utils.run_test("get_punctuation_type: non-punctuation returns nil", function()
    test_utils.assert_nil(judou.get_punctuation_type(0x4E00))  -- 一
    test_utils.assert_nil(judou.get_punctuation_type(0x0041))  -- A
    test_utils.assert_nil(judou.get_punctuation_type(0x0020))  -- space
end)

-- ============================================================================
-- setup
-- ============================================================================

test_utils.run_test("setup: sets global judou config", function()
    -- _G.judou is initialized at module load time; setup modifies existing fields
    _G.judou = { punct_mode = "normal", pos = "right-bottom", size = "1em", color = "red" }
    judou.setup({ punct_mode = "judou", pos = "left-top", size = "2em", color = "blue" })
    test_utils.assert_eq(_G.judou.punct_mode, "judou")
    test_utils.assert_eq(_G.judou.pos, "left-top")
    test_utils.assert_eq(_G.judou.size, "2em")
    test_utils.assert_eq(_G.judou.color, "blue")
end)

test_utils.run_test("setup: ignores empty strings", function()
    _G.judou = { punct_mode = "normal", pos = "right-bottom", size = "1em", color = "red" }
    judou.setup({ punct_mode = "", pos = "" })
    test_utils.assert_eq(_G.judou.punct_mode, "normal")
    test_utils.assert_eq(_G.judou.pos, "right-bottom")
end)

-- ============================================================================
-- initialize
-- ============================================================================

test_utils.run_test("initialize: returns full context for judou mode", function()
    _G.judou = { punct_mode = "judou", pos = "left-top", size = "2em", color = "blue" }
    local ctx = judou.initialize({}, {})
    test_utils.assert_type(ctx, "table")
    test_utils.assert_eq(ctx.mode, "judou")
    test_utils.assert_eq(ctx.punct_mode, "judou")
    test_utils.assert_eq(ctx.pos, "left-top")
    test_utils.assert_eq(ctx.size, "2em")
    test_utils.assert_eq(ctx.color, "blue")
end)

test_utils.run_test("initialize: returns full context for none mode", function()
    _G.judou = { punct_mode = "none", pos = "right-bottom", size = "1em", color = "red" }
    local ctx = judou.initialize({}, {})
    test_utils.assert_type(ctx, "table")
    test_utils.assert_eq(ctx.mode, "none")
    test_utils.assert_eq(ctx.punct_mode, "none")
    test_utils.assert_eq(ctx.pos, "right-bottom")
    test_utils.assert_eq(ctx.size, "1em")
    test_utils.assert_eq(ctx.color, "red")
end)

test_utils.run_test("initialize: returns nil for normal mode", function()
    _G.judou = { punct_mode = "normal", pos = "right-bottom", size = "1em", color = "red" }
    local ctx = judou.initialize({}, {})
    test_utils.assert_nil(ctx)
end)

print("\nAll guji/judou-test tests passed!")
