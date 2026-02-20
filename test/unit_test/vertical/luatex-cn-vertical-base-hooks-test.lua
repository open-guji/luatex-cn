-- luatex-cn-vertical-base-hooks-test.lua - Unit tests for base hooks
local test_utils = require('test.test_utils')
local hooks = require('vertical.luatex-cn-vertical-base-hooks')

test_utils.run_test("base-hooks - Export Check", function()
    test_utils.assert_eq(type(hooks.is_reserved_column), "function", "is_reserved_column missing")
    test_utils.assert_eq(type(hooks.render_reserved_column), "function", "render_reserved_column missing")
end)

test_utils.run_test("base-hooks - Default Behavior", function()
    -- Default behavior: (col % (interval + 1)) == interval
    -- Interval 8: 0..7 normal, 8 banxin
    test_utils.assert_eq(hooks.is_reserved_column(8, 8), true, "Column 8 should be reserved with interval 8")
    test_utils.assert_eq(hooks.is_reserved_column(0, 8), false, "Column 0 should not be reserved")
end)

print("\nAll base-hooks tests passed!")
