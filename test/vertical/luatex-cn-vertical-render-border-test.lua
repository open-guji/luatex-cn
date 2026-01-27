-- luatex-cn-vertical-render-border-test.lua - Unit tests for render border
local test_utils = require('test.test_utils')
local test_utils = require('test.test_utils')
local border = require('vertical.luatex-cn-vertical-render-border')
local internal = border._internal or {}

test_utils.run_test("render-border - create_border_literal", function()
    if not internal.create_border_literal then return end
    local lit = internal.create_border_literal(1.0, "0 0 0", 10, 20, 100, 200)
    -- "q 1.00 w 0 0 0 RG 10.0000 20.0000 100.0000 200.0000 re S Q"
    test_utils.assert_match(lit, "q 1.0", "Literal should start with q")
    test_utils.assert_match(lit, "re S Q", "Literal should end with re S Q")
end)

test_utils.run_test("render-border - draw outer", function()
    local head = {}
    local params = {
        inner_width = 100 * 65536,
        inner_height = 100 * 65536,
        outer_border_thickness = 1 * 65536,
        outer_border_sep = 0,
        border_rgb_str = "0 0 0"
    }
    -- draw_outer_border returns the updated head
    local new_head = border.draw_outer_border(head, params)

    -- The PDF literal node should be inserted before the head
    local literal_node = new_head
    test_utils.assert_match(literal_node.data, "RG", "Should contain stroke color operator")
    test_utils.assert_match(literal_node.data, "w", "Should contain line width operator")
end)

print("\nAll render-border tests passed!")
