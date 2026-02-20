-- Unit tests for debug.luatex-cn-debug
local test_utils = require("test.test_utils")

-- Reset debug state before loading
_G.luatex_cn_debug = nil
local debug_mod = require("debug.luatex-cn-debug")

-- Helper: reset debug state
local function reset()
    debug_mod.global_enabled = false
    debug_mod.modules = {}
    debug_mod.show_grid = false
end

-- ============================================================================
-- register_module
-- ============================================================================

test_utils.run_test("register_module: registers a module", function()
    reset()
    debug_mod.register_module("test_mod")
    test_utils.assert_true(debug_mod.modules.test_mod ~= nil)
    test_utils.assert_eq(debug_mod.modules.test_mod.enabled, true)
end)

test_utils.run_test("register_module: with custom config", function()
    reset()
    debug_mod.register_module("test_mod", { enabled = false, color = "red" })
    test_utils.assert_eq(debug_mod.modules.test_mod.enabled, false)
    test_utils.assert_eq(debug_mod.modules.test_mod.color, "red")
end)

test_utils.run_test("register_module: default color is cyan", function()
    reset()
    debug_mod.register_module("test_mod")
    test_utils.assert_eq(debug_mod.modules.test_mod.color, "cyan")
end)

-- ============================================================================
-- set_global_status
-- ============================================================================

test_utils.run_test("set_global_status: enable with true", function()
    reset()
    debug_mod.set_global_status(true)
    test_utils.assert_eq(debug_mod.global_enabled, true)
end)

test_utils.run_test("set_global_status: enable with string 'true'", function()
    reset()
    debug_mod.set_global_status("true")
    test_utils.assert_eq(debug_mod.global_enabled, true)
end)

test_utils.run_test("set_global_status: disable with false", function()
    reset()
    debug_mod.set_global_status(true)
    debug_mod.set_global_status(false)
    test_utils.assert_eq(debug_mod.global_enabled, false)
end)

-- ============================================================================
-- set_module_status
-- ============================================================================

test_utils.run_test("set_module_status: existing module", function()
    reset()
    debug_mod.register_module("test_mod")
    debug_mod.set_module_status("test_mod", false)
    test_utils.assert_eq(debug_mod.modules.test_mod.enabled, false)
end)

test_utils.run_test("set_module_status: auto-registers new module", function()
    reset()
    debug_mod.set_module_status("new_mod", true)
    test_utils.assert_true(debug_mod.modules.new_mod ~= nil)
    test_utils.assert_eq(debug_mod.modules.new_mod.enabled, true)
end)

-- ============================================================================
-- is_enabled
-- ============================================================================

test_utils.run_test("is_enabled: false when global disabled", function()
    reset()
    debug_mod.register_module("test_mod")
    test_utils.assert_eq(debug_mod.is_enabled("test_mod"), false)
end)

test_utils.run_test("is_enabled: true when global enabled and module enabled", function()
    reset()
    debug_mod.set_global_status(true)
    debug_mod.register_module("test_mod", { enabled = true })
    test_utils.assert_eq(debug_mod.is_enabled("test_mod"), true)
end)

test_utils.run_test("is_enabled: false when module disabled", function()
    reset()
    debug_mod.set_global_status(true)
    debug_mod.register_module("test_mod", { enabled = false })
    test_utils.assert_eq(debug_mod.is_enabled("test_mod"), false)
end)

test_utils.run_test("is_enabled: true for unregistered module when global on", function()
    reset()
    debug_mod.set_global_status(true)
    test_utils.assert_eq(debug_mod.is_enabled("unknown_mod"), true)
end)

-- ============================================================================
-- get_debugger
-- ============================================================================

test_utils.run_test("get_debugger: returns table with log and is_enabled", function()
    reset()
    local dbg = debug_mod.get_debugger("my_mod")
    test_utils.assert_type(dbg, "table")
    test_utils.assert_type(dbg.log, "function")
    test_utils.assert_type(dbg.is_enabled, "function")
end)

test_utils.run_test("get_debugger: auto-registers module", function()
    reset()
    debug_mod.get_debugger("auto_mod")
    test_utils.assert_true(debug_mod.modules.auto_mod ~= nil)
end)

test_utils.run_test("get_debugger: is_enabled reflects global state", function()
    reset()
    local dbg = debug_mod.get_debugger("my_mod")
    test_utils.assert_eq(dbg.is_enabled(), false)
    debug_mod.set_global_status(true)
    test_utils.assert_eq(dbg.is_enabled(), true)
end)

-- ============================================================================
-- log (smoke test - should not error)
-- ============================================================================

test_utils.run_test("log: does not error when global disabled", function()
    reset()
    debug_mod.log("test_mod", "test message")
end)

test_utils.run_test("log: does not error when global enabled", function()
    reset()
    debug_mod.set_global_status(true)
    debug_mod.register_module("test_mod")
    debug_mod.log("test_mod", "test message")
end)

-- ============================================================================
-- format_coordinate
-- ============================================================================

test_utils.run_test("format_coordinate: pt format", function()
    -- 655360 sp = 10pt
    local result = debug_mod.format_coordinate(655360, "pt")
    test_utils.assert_eq(result, "10.0")
end)

test_utils.run_test("format_coordinate: cm format", function()
    -- 1cm ≈ 28.3465pt ≈ 1857713sp
    -- format_coordinate uses sp/65536/28.3465
    local sp = math.floor(28.3465 * 65536)
    local result = debug_mod.format_coordinate(sp, "cm")
    test_utils.assert_eq(result, "1.00")
end)

test_utils.run_test("format_coordinate: mm format", function()
    -- 1mm ≈ 2.83465pt
    local sp = math.floor(2.83465 * 65536)
    local result = debug_mod.format_coordinate(sp, "mm")
    test_utils.assert_eq(result, "1.0")
end)

-- ============================================================================
-- enable_grid / disable_grid / set_grid_measure
-- ============================================================================

test_utils.run_test("enable_grid: sets show_grid", function()
    reset()
    debug_mod.enable_grid()
    test_utils.assert_eq(debug_mod.show_grid, true)
end)

test_utils.run_test("enable_grid: with measure", function()
    reset()
    debug_mod.enable_grid("pt")
    test_utils.assert_eq(debug_mod.show_grid, true)
    test_utils.assert_eq(debug_mod.grid_measure, "pt")
end)

test_utils.run_test("disable_grid: clears show_grid", function()
    reset()
    debug_mod.enable_grid()
    debug_mod.disable_grid()
    test_utils.assert_eq(debug_mod.show_grid, false)
end)

test_utils.run_test("set_grid_measure: valid units", function()
    reset()
    debug_mod.set_grid_measure("mm")
    test_utils.assert_eq(debug_mod.grid_measure, "mm")
    debug_mod.set_grid_measure("pt")
    test_utils.assert_eq(debug_mod.grid_measure, "pt")
    debug_mod.set_grid_measure("cm")
    test_utils.assert_eq(debug_mod.grid_measure, "cm")
end)

test_utils.run_test("set_grid_measure: invalid unit ignored", function()
    reset()
    debug_mod.grid_measure = "cm"
    debug_mod.set_grid_measure("invalid")
    test_utils.assert_eq(debug_mod.grid_measure, "cm")
end)

-- ============================================================================
-- generate_grid_pdf (smoke test)
-- ============================================================================

test_utils.run_test("generate_grid_pdf: returns string", function()
    reset()
    local result = debug_mod.generate_grid_pdf(655360 * 100, 655360 * 200, 0, "cm")
    test_utils.assert_type(result, "string")
    test_utils.assert_true(#result > 0)
    test_utils.assert_match(result, "^q ")
    test_utils.assert_match(result, " Q$")
end)

print("\nAll debug/debug-test tests passed!")
