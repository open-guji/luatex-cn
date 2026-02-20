-- Unit tests for core.luatex-cn-layout-grid (smoke tests)
-- The full calculate_grid_positions function has many dependencies,
-- so we test _internal helpers that are more isolated.
local test_utils = require("test.test_utils")

-- Mock hooks module
_G.core = _G.core or {}
_G.core.hooks = _G.core.hooks or {}
_G.core.hooks.is_reserved_column = function(col, interval)
    return col % (interval + 1) == interval
end
package.loaded['core.luatex-cn-hooks'] = {
    is_reserved_column = _G.core.hooks.is_reserved_column,
    get_plugins = function() return {} end,
}

-- Mock textflow module
package.loaded['core.luatex-cn-textflow'] = package.loaded['core.luatex-cn-textflow'] or {
    calculate_sub_column_x_offset = function(base_x) return base_x end,
}

local layout_grid = require("core.luatex-cn-layout-grid")
local constants = require("core.luatex-cn-constants")
local D = node.direct

-- ============================================================================
-- Module loads successfully
-- ============================================================================

test_utils.run_test("layout_grid: module loads", function()
    test_utils.assert_type(layout_grid, "table")
    test_utils.assert_type(layout_grid.calculate_grid_positions, "function")
end)

test_utils.run_test("layout_grid: _internal exported", function()
    test_utils.assert_type(layout_grid._internal, "table")
end)

-- ============================================================================
-- _internal.accumulate_spacing
-- ============================================================================

test_utils.run_test("accumulate_spacing: single glue", function()
    local glue = D.new(constants.GLUE)
    D.setfield(glue, "width", 65536 * 10)
    local total, next_node = layout_grid._internal.accumulate_spacing(glue)
    test_utils.assert_eq(total, 65536 * 10)
end)

test_utils.run_test("accumulate_spacing: glue followed by glyph", function()
    local glue = D.new(constants.GLUE)
    D.setfield(glue, "width", 65536 * 5)
    local glyph = D.new(constants.GLYPH)
    D.setfield(glyph, "char", 0x4E00)
    D.setlink(glue, glyph)
    local total, next_node = layout_grid._internal.accumulate_spacing(glue)
    test_utils.assert_eq(total, 65536 * 5)
    test_utils.assert_eq(next_node, glyph)
end)

test_utils.run_test("accumulate_spacing: consecutive glues", function()
    local g1 = D.new(constants.GLUE)
    D.setfield(g1, "width", 65536 * 3)
    local g2 = D.new(constants.GLUE)
    D.setfield(g2, "width", 65536 * 7)
    D.setlink(g1, g2)
    local total, next_node = layout_grid._internal.accumulate_spacing(g1)
    test_utils.assert_eq(total, 65536 * 10)
end)

test_utils.run_test("accumulate_spacing: kern node", function()
    local kern = D.new(constants.KERN)
    D.setfield(kern, "kern", 65536 * 2)
    local total, next_node = layout_grid._internal.accumulate_spacing(kern)
    test_utils.assert_eq(total, 65536 * 2)
end)

-- ============================================================================
-- _internal.handle_penalty_breaks (smoke test)
-- ============================================================================

test_utils.run_test("handle_penalty_breaks: non-break penalty returns false", function()
    local ctx = {
        cur_row = 3,
        cur_col = 0,
        cur_page = 1,
        cur_y_sp = 0,
        page_has_content = true,
        cur_column_indent = 0,
    }
    local flush = function() end
    local penalty_node = D.new(constants.PENALTY)
    D.setfield(penalty_node, "penalty", 0)
    local handled = layout_grid._internal.handle_penalty_breaks(
        0, ctx, flush, 10, 0, 65536 * 20, 0, penalty_node)
    test_utils.assert_eq(handled, false)
end)

test_utils.run_test("handle_penalty_breaks: PENALTY_FORCE_COLUMN handled", function()
    local ctx = {
        cur_row = 3,
        cur_col = 0,
        cur_page = 1,
        cur_y_sp = 65536 * 60,
        page_has_content = true,
        cur_column_indent = 0,
        occupancy = {},
        just_wrapped_column = false,
        col_widths_sp = {},
    }
    _G.page = _G.page or {}
    _G.content = _G.content or {}
    local flushed = false
    local flush = function() flushed = true end
    local penalty_node = D.new(constants.PENALTY)
    D.setfield(penalty_node, "penalty", constants.PENALTY_FORCE_COLUMN)
    local handled = layout_grid._internal.handle_penalty_breaks(
        constants.PENALTY_FORCE_COLUMN, ctx, flush, 10, 0, 65536 * 20, 0, penalty_node)
    test_utils.assert_eq(handled, true)
    test_utils.assert_eq(flushed, true)
end)

print("\nAll core/layout-grid-test tests passed!")
