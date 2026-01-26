-- luatex-cn-vertical-flatten-nodes-test.lua - Unit tests for flatten nodes
local test_utils = require('test.test_utils')
local flatten = require('vertical.luatex-cn-vertical-flatten-nodes')
local constants = require('vertical.luatex-cn-vertical-base-constants')

test_utils.run_test("flatten-nodes - basic flattening", function()
    local v = node.new("vlist")
    local h = node.new("hlist")
    local g = node.new("glyph")
    h.list = g
    v.list = h

    local n1 = flatten.flatten_vbox(v, 655360, 655360)
    test_utils.assert_eq(type(n1), "table", "Should return a flattened list")
    test_utils.assert_eq(n1.id, constants.GLYPH, "First flattened node should be a glyph")
end)

print("\nAll flatten-nodes tests passed!")
