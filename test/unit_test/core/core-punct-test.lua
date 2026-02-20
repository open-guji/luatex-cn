-- Unit tests for core.luatex-cn-core-punct
local test_utils = require("test.test_utils")
local punct = require("core.luatex-cn-core-punct")

-- ============================================================================
-- classify
-- ============================================================================

test_utils.run_test("classify: opening brackets", function()
    test_utils.assert_eq(punct.classify(0x300C), "open")   -- 「
    test_utils.assert_eq(punct.classify(0x300E), "open")   -- 『
    test_utils.assert_eq(punct.classify(0xFF08), "open")   -- （
    test_utils.assert_eq(punct.classify(0x3008), "open")   -- 〈
    test_utils.assert_eq(punct.classify(0x300A), "open")   -- 《
    test_utils.assert_eq(punct.classify(0x3010), "open")   -- 【
    test_utils.assert_eq(punct.classify(0x201C), "open")   -- "
    test_utils.assert_eq(punct.classify(0x2018), "open")   -- '
end)

test_utils.run_test("classify: vertical presentation forms (open)", function()
    test_utils.assert_eq(punct.classify(0xFE41), "open")   -- ﹁
    test_utils.assert_eq(punct.classify(0xFE43), "open")   -- ﹃
    test_utils.assert_eq(punct.classify(0xFE35), "open")   -- ︵
    test_utils.assert_eq(punct.classify(0xFE3D), "open")   -- ︽
end)

test_utils.run_test("classify: closing brackets", function()
    test_utils.assert_eq(punct.classify(0x300D), "close")  -- 」
    test_utils.assert_eq(punct.classify(0x300F), "close")  -- 』
    test_utils.assert_eq(punct.classify(0xFF09), "close")  -- ）
    test_utils.assert_eq(punct.classify(0x3009), "close")  -- 〉
    test_utils.assert_eq(punct.classify(0x300B), "close")  -- 》
    test_utils.assert_eq(punct.classify(0x201D), "close")  -- "
    test_utils.assert_eq(punct.classify(0x2019), "close")  -- '
end)

test_utils.run_test("classify: vertical presentation forms (close)", function()
    test_utils.assert_eq(punct.classify(0xFE42), "close")  -- ﹂
    test_utils.assert_eq(punct.classify(0xFE44), "close")  -- ﹄
    test_utils.assert_eq(punct.classify(0xFE36), "close")  -- ︶
    test_utils.assert_eq(punct.classify(0xFE3C), "close")  -- ︼
end)

test_utils.run_test("classify: fullstop", function()
    test_utils.assert_eq(punct.classify(0x3002), "fullstop") -- 。
    test_utils.assert_eq(punct.classify(0xFF0E), "fullstop") -- ．
end)

test_utils.run_test("classify: comma", function()
    test_utils.assert_eq(punct.classify(0xFF0C), "comma")  -- ，
    test_utils.assert_eq(punct.classify(0x3001), "comma")  -- 、
end)

test_utils.run_test("classify: middle punctuation", function()
    test_utils.assert_eq(punct.classify(0xFF1A), "middle") -- ：
    test_utils.assert_eq(punct.classify(0xFF1B), "middle") -- ；
    test_utils.assert_eq(punct.classify(0xFF01), "middle") -- ！
    test_utils.assert_eq(punct.classify(0xFF1F), "middle") -- ？
end)

test_utils.run_test("classify: nobreak characters", function()
    test_utils.assert_eq(punct.classify(0x2014), "nobreak") -- — em dash
    test_utils.assert_eq(punct.classify(0x2026), "nobreak") -- … ellipsis
end)

test_utils.run_test("classify: non-punctuation returns nil", function()
    test_utils.assert_nil(punct.classify(0x4E00))  -- 一 (CJK character)
    test_utils.assert_nil(punct.classify(0x0041))  -- A (Latin)
    test_utils.assert_nil(punct.classify(0x0020))  -- space
end)

-- ============================================================================
-- is_line_start_forbidden
-- ============================================================================

test_utils.run_test("is_line_start_forbidden: close/fullstop/comma/middle forbidden", function()
    test_utils.assert_true(punct.is_line_start_forbidden("close"))
    test_utils.assert_true(punct.is_line_start_forbidden("fullstop"))
    test_utils.assert_true(punct.is_line_start_forbidden("comma"))
    test_utils.assert_true(punct.is_line_start_forbidden("middle"))
end)

test_utils.run_test("is_line_start_forbidden: open/nobreak allowed", function()
    test_utils.assert_eq(punct.is_line_start_forbidden("open"), false)
    test_utils.assert_eq(punct.is_line_start_forbidden("nobreak"), false)
end)

test_utils.run_test("is_line_start_forbidden: nil type allowed", function()
    test_utils.assert_eq(punct.is_line_start_forbidden(nil), false)
end)

-- ============================================================================
-- is_line_end_forbidden
-- ============================================================================

test_utils.run_test("is_line_end_forbidden: open forbidden", function()
    test_utils.assert_true(punct.is_line_end_forbidden("open"))
end)

test_utils.run_test("is_line_end_forbidden: close/fullstop/comma/middle allowed", function()
    test_utils.assert_eq(punct.is_line_end_forbidden("close"), false)
    test_utils.assert_eq(punct.is_line_end_forbidden("fullstop"), false)
    test_utils.assert_eq(punct.is_line_end_forbidden("comma"), false)
    test_utils.assert_eq(punct.is_line_end_forbidden("middle"), false)
end)

test_utils.run_test("is_line_end_forbidden: nil type allowed", function()
    test_utils.assert_eq(punct.is_line_end_forbidden(nil), false)
end)

-- ============================================================================
-- type_from_code / code_from_type
-- ============================================================================

test_utils.run_test("type_from_code: valid codes", function()
    test_utils.assert_eq(punct.type_from_code(1), "open")
    test_utils.assert_eq(punct.type_from_code(2), "close")
    test_utils.assert_eq(punct.type_from_code(3), "fullstop")
    test_utils.assert_eq(punct.type_from_code(4), "comma")
    test_utils.assert_eq(punct.type_from_code(5), "middle")
    test_utils.assert_eq(punct.type_from_code(6), "nobreak")
end)

test_utils.run_test("type_from_code: invalid code returns nil", function()
    test_utils.assert_nil(punct.type_from_code(0))
    test_utils.assert_nil(punct.type_from_code(7))
    test_utils.assert_nil(punct.type_from_code(99))
end)

test_utils.run_test("code_from_type: valid types", function()
    test_utils.assert_eq(punct.code_from_type("open"), 1)
    test_utils.assert_eq(punct.code_from_type("close"), 2)
    test_utils.assert_eq(punct.code_from_type("fullstop"), 3)
    test_utils.assert_eq(punct.code_from_type("comma"), 4)
    test_utils.assert_eq(punct.code_from_type("middle"), 5)
    test_utils.assert_eq(punct.code_from_type("nobreak"), 6)
end)

test_utils.run_test("code_from_type: invalid type returns nil", function()
    test_utils.assert_nil(punct.code_from_type("unknown"))
    test_utils.assert_nil(punct.code_from_type(""))
end)

test_utils.run_test("type_from_code/code_from_type: roundtrip", function()
    local types = {"open", "close", "fullstop", "comma", "middle", "nobreak"}
    for _, t in ipairs(types) do
        local code = punct.code_from_type(t)
        test_utils.assert_eq(punct.type_from_code(code), t, "roundtrip failed for " .. t)
    end
end)

-- ============================================================================
-- setup
-- ============================================================================

test_utils.run_test("setup: sets global punct config", function()
    _G.punct = nil
    punct.setup({ style = "taiwan", squeeze = false, hanging = true, kinsoku = false })
    test_utils.assert_eq(_G.punct.style, "taiwan")
    test_utils.assert_eq(_G.punct.squeeze, false)
    test_utils.assert_eq(_G.punct.hanging, true)
    test_utils.assert_eq(_G.punct.kinsoku, false)
end)

test_utils.run_test("setup: partial config", function()
    _G.punct = { style = "mainland" }
    punct.setup({ kinsoku = true })
    test_utils.assert_eq(_G.punct.style, "mainland")
    test_utils.assert_eq(_G.punct.kinsoku, true)
end)

-- ============================================================================
-- initialize
-- ============================================================================

test_utils.run_test("initialize: returns context when no judou plugin context", function()
    _G.punct = nil
    local ctx = punct.initialize({}, {}, {})
    test_utils.assert_type(ctx, "table")
    test_utils.assert_eq(ctx.style, "mainland")
    test_utils.assert_eq(ctx.squeeze, true)
    test_utils.assert_eq(ctx.kinsoku, true)
    test_utils.assert_eq(ctx.hanging, false)
end)

test_utils.run_test("initialize: returns nil when judou plugin context has non-normal mode", function()
    local plugin_contexts = { judou = { punct_mode = "judou" } }
    local ctx = punct.initialize({}, {}, plugin_contexts)
    test_utils.assert_nil(ctx)
end)

test_utils.run_test("initialize: reads _G.punct config", function()
    _G.punct = { style = "taiwan", squeeze = false, hanging = true, kinsoku = false }
    local ctx = punct.initialize({}, {}, {})
    test_utils.assert_eq(ctx.style, "taiwan")
    test_utils.assert_eq(ctx.squeeze, false)
    test_utils.assert_eq(ctx.hanging, true)
    test_utils.assert_eq(ctx.kinsoku, false)
    _G.punct = nil
end)

-- ============================================================================
-- make_kinsoku_hook
-- ============================================================================

test_utils.run_test("make_kinsoku_hook: returns nil when no ctx", function()
    test_utils.assert_nil(punct.make_kinsoku_hook(nil))
end)

test_utils.run_test("make_kinsoku_hook: returns nil when kinsoku disabled", function()
    test_utils.assert_nil(punct.make_kinsoku_hook({ kinsoku = false }))
end)

test_utils.run_test("make_kinsoku_hook: returns function when kinsoku enabled", function()
    local hook = punct.make_kinsoku_hook({ kinsoku = true })
    test_utils.assert_type(hook, "function")
end)

print("\nAll core/core-punct-test tests passed!")
