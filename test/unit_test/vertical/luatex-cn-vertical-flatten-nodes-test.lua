-- luatex-cn-vertical-flatten-nodes-test.lua - Unit tests for flatten nodes
local test_utils = require('test.test_utils')
local flatten = require('luatex-cn-core-flatten-nodes')
local constants = require('luatex-cn-constants')
local internal = flatten._internal or {}

test_utils.run_test("flatten-nodes - should_keep_node", function()
    if not internal.should_keep_node then return end
    test_utils.assert_eq(internal.should_keep_node(constants.GLYPH, 0), true)
    test_utils.assert_eq(internal.should_keep_node(constants.PENALTY, 0), true)
    -- Discard random glues? Actually we keep typical glues
    test_utils.assert_eq(internal.should_keep_node(constants.GLUE, 13), true) -- spaces
end)

test_utils.run_test("flatten-nodes - get_box_indentation", function()
    if not internal.get_box_indentation then return end
    local h = node.new("hlist")
    node.setfield(h, "shift", 65536 * 20) -- 20pt shift
    -- char_width 10pt -> indent 2
    local indent = internal.get_box_indentation(h, 0, 65536 * 10)
    test_utils.assert_eq(indent, 2)
end)

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
