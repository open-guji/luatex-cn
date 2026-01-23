-- luatex-cn-vertical-layout-grid-test.lua - Unit tests for layout grid
local test_utils = require('test.test_utils')
local layout = require('vertical.luatex-cn-vertical-layout-grid')

test_utils.run_test("layout-grid - basic positioning", function()
    local n1 = node.new("glyph")
    local params = {
        n_char = 10,
        n_column = 2,
        grid_width = 655360,
        grid_height = 655360
    }

    local head, map, pages = layout.calculate_grid_positions(n1, params)
    test_utils.assert_eq(pages, 1, "Should be 1 page")
    test_utils.assert_eq(map[n1].col, 0, "First glyph should be in col 0")
    test_utils.assert_eq(map[n1].row, 0, "First glyph should be in row 0")
end)

print("\nAll layout-grid tests passed!")
