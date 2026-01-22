-- luatex-cn-vertical-base-hooks-test.lua - Unit tests for base hooks
local test_utils = require('test.test_utils')
local hooks = require('tex.vertical.luatex-cn-vertical-base-hooks')

test_utils.run_test("base-hooks - Registry Check", function()
    test_utils.assert_eq(type(hooks.registry), "table", "hooks.registry missing")
end)

test_utils.run_test("base-hooks - Register and Run", function()
    local called = false
    hooks.register("test_hook", function(data)
        called = true
        test_utils.assert_eq(data, "hello", "Hook data mismatch")
    end)

    hooks.run("test_hook", "hello")
    test_utils.assert_eq(called, true, "Hook was not called")
end)

test_utils.run_test("base-hooks - Multiple Hooks", function()
    local count = 0
    hooks.register("multi", function() count = count + 1 end)
    hooks.register("multi", function() count = count + 1 end)

    hooks.run("multi")
    test_utils.assert_eq(count, 2, "Multiple hooks were not all called")
end)

print("\nAll base-hooks tests passed!")
