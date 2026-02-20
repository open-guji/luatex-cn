-- Unit tests for core.luatex-cn-core-flatten-nodes
local test_utils = require("test.test_utils")
local flatten = require("core.luatex-cn-core-flatten-nodes")
local constants = require("core.luatex-cn-constants")
local D = node.direct

-- ============================================================================
-- _internal.get_box_indentation
-- ============================================================================

test_utils.run_test("get_box_indentation: no shift, no glue → current indent", function()
    local hlist = D.new(constants.HLIST)
    -- Empty hlist, no shift
    D.setfield(hlist, "shift", 0)
    local indent = flatten._internal.get_box_indentation(hlist, 0, 65536 * 10)
    test_utils.assert_eq(indent, 0)
end)

test_utils.run_test("get_box_indentation: with shift", function()
    local hlist = D.new(constants.HLIST)
    local char_width = 65536 * 10  -- 10pt
    -- Shift = 2 chars worth
    D.setfield(hlist, "shift", char_width * 2)
    local indent = flatten._internal.get_box_indentation(hlist, 0, char_width)
    test_utils.assert_eq(indent, 2)
end)

test_utils.run_test("get_box_indentation: shift takes max with current", function()
    local hlist = D.new(constants.HLIST)
    local char_width = 65536 * 10
    D.setfield(hlist, "shift", char_width * 1)
    local indent = flatten._internal.get_box_indentation(hlist, 3, char_width)
    -- max(3, 1) = 3
    test_utils.assert_eq(indent, 3)
end)

test_utils.run_test("get_box_indentation: with ATTR_INDENT attribute", function()
    local hlist = D.new(constants.HLIST)
    D.setfield(hlist, "shift", 0)
    D.set_attribute(hlist, constants.ATTR_INDENT, 5)
    local indent = flatten._internal.get_box_indentation(hlist, 0, 65536 * 10)
    test_utils.assert_eq(indent, 5)
end)

test_utils.run_test("get_box_indentation: with leading glue in hlist", function()
    local hlist = D.new(constants.HLIST)
    D.setfield(hlist, "shift", 0)
    local char_width = 65536 * 10
    -- Create a glue node as the list head
    local glue = D.new(constants.GLUE)
    D.setfield(glue, "width", char_width * 3) -- 3 chars indentation
    D.setfield(hlist, "list", glue)
    local indent = flatten._internal.get_box_indentation(hlist, 0, char_width)
    test_utils.assert_eq(indent, 3)
end)

-- ============================================================================
-- _internal.copy_node_with_attributes
-- ============================================================================

test_utils.run_test("copy_node_with_attributes: copies glyph", function()
    local g = D.new(constants.GLYPH)
    D.setfield(g, "char", 0x4E00)
    local copy = flatten._internal.copy_node_with_attributes(g, 0, 0)
    test_utils.assert_eq(D.getfield(copy, "char"), 0x4E00)
end)

test_utils.run_test("copy_node_with_attributes: sets indent attribute", function()
    local g = D.new(constants.GLYPH)
    local copy = flatten._internal.copy_node_with_attributes(g, 2, 0)
    test_utils.assert_eq(D.get_attribute(copy, constants.ATTR_INDENT), 2)
end)

test_utils.run_test("copy_node_with_attributes: zero indent not set", function()
    local g = D.new(constants.GLYPH)
    local copy = flatten._internal.copy_node_with_attributes(g, 0, 0)
    -- When indent is 0, it should not set the attribute (or leave default)
    local attr = D.get_attribute(copy, constants.ATTR_INDENT)
    test_utils.assert_true(attr == nil or attr == 0)
end)

test_utils.run_test("copy_node_with_attributes: preserves forced indent", function()
    local g = D.new(constants.GLYPH)
    local forced = constants.encode_forced_indent(3)
    D.set_attribute(g, constants.ATTR_INDENT, forced)
    local copy = flatten._internal.copy_node_with_attributes(g, 5, 0)
    -- Should NOT overwrite the forced indent
    test_utils.assert_eq(D.get_attribute(copy, constants.ATTR_INDENT), forced)
end)

-- ============================================================================
-- _internal.process_textbox_node
-- ============================================================================

test_utils.run_test("process_textbox_node: returns nil for non-textbox", function()
    local n = D.new(constants.HLIST)
    D.set_attribute(n, constants.ATTR_TEXTBOX_WIDTH, 0)
    D.set_attribute(n, constants.ATTR_TEXTBOX_HEIGHT, 0)
    local result, is_tb = flatten._internal.process_textbox_node(n, 0, 0)
    test_utils.assert_eq(is_tb, false)
    test_utils.assert_nil(result)
end)

test_utils.run_test("process_textbox_node: returns copy for textbox", function()
    local n = D.new(constants.HLIST)
    D.set_attribute(n, constants.ATTR_TEXTBOX_WIDTH, 100000)
    D.set_attribute(n, constants.ATTR_TEXTBOX_HEIGHT, 200000)
    local result, is_tb = flatten._internal.process_textbox_node(n, 0, 0)
    test_utils.assert_eq(is_tb, true)
    test_utils.assert_true(result ~= nil)
end)

test_utils.run_test("process_textbox_node: applies running indent", function()
    local n = D.new(constants.HLIST)
    D.set_attribute(n, constants.ATTR_TEXTBOX_WIDTH, 100000)
    D.set_attribute(n, constants.ATTR_TEXTBOX_HEIGHT, 200000)
    local result, is_tb = flatten._internal.process_textbox_node(n, 2, 0)
    test_utils.assert_eq(is_tb, true)
    test_utils.assert_eq(D.get_attribute(result, constants.ATTR_INDENT), 2)
end)

-- ============================================================================
-- flatten_vbox (integration-level tests with simple node structures)
-- ============================================================================

test_utils.run_test("flatten_vbox: empty vbox returns nil", function()
    local vbox = D.new(constants.VLIST)
    local vbox_node = D.tonode(vbox)
    local result = flatten.flatten_vbox(vbox_node, 65536 * 20, 65536 * 20)
    -- Empty vbox has no content, result should be nil
    test_utils.assert_true(result == nil)
end)

test_utils.run_test("flatten_vbox: single glyph in hlist", function()
    local gw = 65536 * 20
    -- Create: vlist > hlist > glyph using direct API
    local vbox = D.new(constants.VLIST)
    local hlist = D.new(constants.HLIST)
    local g = D.new(constants.GLYPH)
    D.setfield(g, "char", 0x4E00)
    D.setfield(g, "font", 1)
    D.setfield(hlist, "list", g)
    D.setfield(vbox, "list", hlist)
    -- flatten_vbox expects a non-direct node
    local vbox_node = D.tonode(vbox)
    local result = flatten.flatten_vbox(vbox_node, gw, gw)
    test_utils.assert_true(result ~= nil, "should return non-nil for vbox with glyph")
end)

print("\nAll core/flatten-nodes-test tests passed!")
