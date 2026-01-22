-- luatex-cn-vertical-render-background-test.lua - Unit tests for render background
local test_utils = require('test.test_utils')
local background = require('tex.vertical.luatex-cn-vertical-render-background')

test_utils.run_test("render-background - fill rect", function()
    local head = {}
    local params = {
        bg_rgb_str = "1 0 0",
        inner_width = 100 * 65536,
        inner_height = 100 * 65536,
        outer_shift = 0,
        is_textbox = true -- Force drawing even if paper_width is 0
    }
    -- draw_background returns the updated head
    local new_head = background.draw_background(head, params)

    -- The PDF literal node should be inserted before the head
    -- In our mock, n.next = anchor, and it returns n.
    local literal_node = new_head
    test_utils.assert_match(literal_node.data, "rg", "Should contain fill color operator")
    test_utils.assert_match(literal_node.data, "re f", "Should contain rectangle fill operator")
end)

print("\nAll render-background tests passed!")
