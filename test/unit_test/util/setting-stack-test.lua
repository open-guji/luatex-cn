-- Unit tests for util.luatex-cn-setting-stack
local test_utils = require("test.test_utils")
local setting_stack = require("util.luatex-cn-setting-stack")

-- Helper: reset before each test
local function reset()
    setting_stack.clear()
    _G.judou = nil
    _G.punct = nil
    _G.luatex_cn_debug = nil
end

-- ============================================================================
-- current (defaults)
-- ============================================================================

test_utils.run_test("current: returns defaults when stack empty", function()
    reset()
    local s = setting_stack.current()
    test_utils.assert_eq(s.punct_mode, "normal")
    test_utils.assert_eq(s.punct_style, "mainland")
    test_utils.assert_eq(s.debug, false)
end)

test_utils.run_test("current: picks up _G.judou global override", function()
    reset()
    _G.judou = { punct_mode = "judou" }
    local s = setting_stack.current()
    test_utils.assert_eq(s.punct_mode, "judou")
end)

test_utils.run_test("current: picks up _G.punct global override", function()
    reset()
    _G.punct = { style = "taiwan" }
    local s = setting_stack.current()
    test_utils.assert_eq(s.punct_style, "taiwan")
end)

-- ============================================================================
-- push / pop
-- ============================================================================

test_utils.run_test("push: overrides specific key, inherits rest", function()
    reset()
    _G.judou = { punct_mode = "judou" }
    local s = setting_stack.push({ punct_mode = "normal" })
    test_utils.assert_eq(s.punct_mode, "normal")
    test_utils.assert_eq(s.punct_style, "mainland")
end)

test_utils.run_test("push: empty override inherits all from global", function()
    reset()
    _G.judou = { punct_mode = "judou" }
    local s = setting_stack.push({})
    test_utils.assert_eq(s.punct_mode, "judou")
end)

test_utils.run_test("push: nested push inherits from parent stack entry", function()
    reset()
    setting_stack.push({ punct_mode = "judou", punct_style = "taiwan" })
    local s = setting_stack.push({ punct_mode = "normal" })
    test_utils.assert_eq(s.punct_mode, "normal")
    test_utils.assert_eq(s.punct_style, "taiwan", "should inherit from parent")
end)

test_utils.run_test("pop: restores previous settings", function()
    reset()
    _G.judou = { punct_mode = "judou" }
    setting_stack.push({ punct_mode = "normal" })
    test_utils.assert_eq(setting_stack.current().punct_mode, "normal")

    setting_stack.pop()
    test_utils.assert_eq(setting_stack.current().punct_mode, "judou")
end)

test_utils.run_test("pop: returns popped entry", function()
    reset()
    setting_stack.push({ punct_mode = "none" })
    local popped = setting_stack.pop()
    test_utils.assert_eq(popped.punct_mode, "none")
end)

test_utils.run_test("pop: returns nil when stack empty", function()
    reset()
    test_utils.assert_nil(setting_stack.pop())
end)

-- ============================================================================
-- get
-- ============================================================================

test_utils.run_test("get: returns specific key value", function()
    reset()
    setting_stack.push({ punct_mode = "judou" })
    test_utils.assert_eq(setting_stack.get("punct_mode"), "judou")
    test_utils.assert_eq(setting_stack.get("punct_style"), "mainland")
end)

-- ============================================================================
-- push ignores empty string overrides
-- ============================================================================

test_utils.run_test("push: empty string override inherits parent value", function()
    reset()
    _G.judou = { punct_mode = "judou" }
    local s = setting_stack.push({ punct_mode = "" })
    test_utils.assert_eq(s.punct_mode, "judou", "empty string should not override")
end)

-- ============================================================================
-- clear
-- ============================================================================

test_utils.run_test("clear: resets stack", function()
    reset()
    setting_stack.push({ punct_mode = "judou" })
    setting_stack.push({ punct_mode = "none" })
    setting_stack.clear()
    test_utils.assert_eq(setting_stack.current().punct_mode, "normal")
    test_utils.assert_nil(setting_stack.pop())
end)

-- ============================================================================
-- debug setting
-- ============================================================================

test_utils.run_test("debug: defaults to false", function()
    reset()
    test_utils.assert_eq(setting_stack.get("debug"), false)
end)

test_utils.run_test("debug: picks up _G.luatex_cn_debug global", function()
    reset()
    _G.luatex_cn_debug = { global_enabled = true }
    test_utils.assert_eq(setting_stack.get("debug"), true)
end)

test_utils.run_test("debug: push overrides global", function()
    reset()
    _G.luatex_cn_debug = { global_enabled = true }
    setting_stack.push({ debug = false })
    test_utils.assert_eq(setting_stack.get("debug"), false)
    setting_stack.pop()
    test_utils.assert_eq(setting_stack.get("debug"), true)
end)

test_utils.run_test("debug: push true inherits to child", function()
    reset()
    setting_stack.push({ debug = true })
    setting_stack.push({ punct_mode = "judou" })
    test_utils.assert_eq(setting_stack.get("debug"), true, "child should inherit debug")
    test_utils.assert_eq(setting_stack.get("punct_mode"), "judou")
end)

test_utils.run_test("debug: push false inherits correctly (not clobbered by or)", function()
    reset()
    setting_stack.push({ debug = true })
    setting_stack.push({ debug = false })
    test_utils.assert_eq(setting_stack.get("debug"), false, "explicit false should override parent true")
end)
