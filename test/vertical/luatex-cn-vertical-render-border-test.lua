-- luatex-cn-vertical-render-border-test.lua - Unit tests for render border
local test_utils = require('test.test_utils')
local border = require('luatex-cn-vertical-render-border')

test_utils.run_test("render-border - draw outer", function()
    local params = {
        outer_border_thickness = 65536,
        border_color = "0 0 0"
    }
    local pdf = border.draw_outer_border(0, 0, 100, 100, params)
    test_utils.assert_match(pdf, "RG", "Should contain stroke color operator")
    test_utils.assert_match(pdf, "w", "Should contain line width operator")
end)

print("\nAll render-border tests passed!")
