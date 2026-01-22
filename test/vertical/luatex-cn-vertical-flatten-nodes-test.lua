-- luatex-cn-vertical-flatten-nodes-test.lua - Unit tests for flatten nodes
local test_utils = require('test.test_utils')
local flatten = require('tex.vertical.luatex-cn-vertical-flatten-nodes')

test_utils.run_test("flatten-nodes - basic flattening", function()
    local n1 = node.new("glyph")
    local h = node.new("hlist")
    local n2 = node.new("glyph")
    h.list = n2
    n1.next = h

    local flat_head = flatten.flatten_nodes(n1)
    test_utils.assert_eq(flat_head, n1, "Head should be same")
    test_utils.assert_eq(n1.next, n2, "n1.next should be n2 after flattening hlist")
end)

print("\nAll flatten-nodes tests passed!")
