-- luatex-cn-vertical-render-border-test.lua - Unit tests for render border
local test_utils = require('test.test_utils')
local border = require('luatex-cn-vertical-render-border')

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
