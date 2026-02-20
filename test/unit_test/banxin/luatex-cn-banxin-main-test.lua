-- luatex-cn-banxin-main.lua - Unit tests for banxin main module
local test_utils = require('test.test_utils')

-- Setup environment before requiring main
_G.vertical = { hooks = {} }

local banxin_main = require('banxin.luatex-cn-banxin-main')

test_utils.run_test("banxin_main - Hook Registration", function()
    test_utils.assert_eq(type(_G.vertical.hooks.render_reserved_column), "function", "Hook not registered")
end)

test_utils.run_test("banxin_main - Export Checks", function()
    test_utils.assert_eq(type(banxin_main.render_reserved_column), "function", "Export missing")
end)

test_utils.run_test("banxin_main - require check", function()
    local m1 = require('banxin.luatex-cn-banxin-main')
    local m2 = require('banxin.luatex-cn-banxin-main')
    test_utils.assert_eq(m1, m2, "Module name aliasing failed")
end)

print("\nAll banxin-main tests passed!")
