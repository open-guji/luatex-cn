-- luatex-cn-vertical-render-page-test.lua - Unit tests for render page
local test_utils = require('test.test_utils')
local render = require('vertical.luatex-cn-vertical-render-page')

test_utils.run_test("render-page - apply positions", function()
    local n1 = node.new("glyph")
    local map = {
        [n1] = { page = 1, col = 0, row = 0 }
    }
    local params = {
        grid_width = 655360,
        grid_height = 655360,
        page_columns = 10,
        margin_top = 0,
        margin_left = 0
    }

    local pages = render.apply_positions(n1, map, params)
    test_utils.assert_eq(#pages, 1, "Should generate 1 page list")
    test_utils.assert_eq(type(pages[1].head), "table", "Page head should be a node")
end)

print("\nAll render-page tests passed!")
