-- luatex-cn-vertical-layout-grid-test.lua - Unit tests for layout grid
local test_utils = require('test.test_utils')
local layout = require('luatex-cn-layout-grid')
local internal = layout._internal or {}

test_utils.run_test("layout-grid - context creation", function()
    if not internal.create_grid_context then return end
    local ctx = internal.create_grid_context({}, 20, 5)
    test_utils.assert_eq(ctx.cur_page, 0)
    test_utils.assert_eq(ctx.cur_col, 0)
    test_utils.assert_eq(ctx.line_limit, 20)
    test_utils.assert_eq(ctx.p_cols, 5)
end)

test_utils.run_test("layout-grid - occupancy", function()
    if not internal.mark_occupied then return end
    local occ = {}
    internal.mark_occupied(occ, 0, 1, 2)
    test_utils.assert_eq(internal.is_occupied(occ, 0, 1, 2), true)
    test_utils.assert_eq(internal.is_occupied(occ, 0, 1, 3), false)
end)

test_utils.run_test("layout-grid - move_next (skip occupied)", function()
    if not internal.move_to_next_valid_position then return end
    local ctx = internal.create_grid_context({ banxin_on = false }, 10, 5)
    -- Mark current spot occupied
    internal.mark_occupied(ctx.occupancy, 0, 0, 0)

    internal.move_to_next_valid_position(ctx, 0, 100)
    -- Should move to row 1
    test_utils.assert_eq(ctx.cur_row, 1)
    test_utils.assert_eq(ctx.cur_col, 0)
end)

test_utils.run_test("layout-grid - basic positioning", function()
    local n1 = node.new("glyph")
    local params = {
        n_char = 10,
        n_column = 2,
        grid_width = 655360,
        grid_height = 655360
    }

    local map, pages = layout.calculate_grid_positions(n1, params.grid_height, params.n_char or 20, params
        .n_column, 2 * params.n_column + 1, params)
    test_utils.assert_eq(pages, 1, "Should be 1 page")
    test_utils.assert_eq(map[n1].col, 0, "First glyph should be in col 0")
    test_utils.assert_eq(map[n1].row, 0, "First glyph should be in row 0")
end)

print("\nAll layout-grid tests passed!")
