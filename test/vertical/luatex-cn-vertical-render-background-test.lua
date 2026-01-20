-- luatex-cn-vertical-render-background-test.lua - Unit tests for render background
local test_utils = require('test.test_utils')
local background = require('luatex-cn-vertical-render-background')

test_utils.run_test("render-background - fill rect", function()
    -- draw_background returns a string of PDF literals
    local pdf = background.draw_background(0, 0, 100, 100, "1 0 0")
    test_utils.assert_match(pdf, "rg", "Should contain fill color operator")
    test_utils.assert_match(pdf, "re f", "Should contain rectangle fill operator")
end)

print("\nAll render-background tests passed!")
