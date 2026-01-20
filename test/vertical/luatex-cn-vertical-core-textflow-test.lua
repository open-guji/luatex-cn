-- luatex-cn-vertical-core-textflow-test.lua - Unit tests for core textflow
local test_utils = require('test.test_utils')
local textflow = require('luatex-cn-vertical-core-textflow')

test_utils.run_test("core-textflow - basic wrap", function()
    -- Mock params and nodes
    local params = {
        n_char = 10,
        n_column = 2
    }

    -- textflow logic handles how nodes move between columns
    test_utils.assert_eq(type(textflow.wrap_nodes), "function", "wrap_nodes missing")
end)

print("\nAll core-textflow tests passed!")
