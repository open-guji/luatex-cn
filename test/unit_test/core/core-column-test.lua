-- Unit tests for core.luatex-cn-core-column
local test_utils = require("test.test_utils")

-- Mock hooks module
_G.core = _G.core or {}
_G.core.hooks = _G.core.hooks or {}
_G.core.hooks.is_reserved_column = function(col, interval)
    return col % (interval + 1) == interval
end
package.loaded['core.luatex-cn-hooks'] = { is_reserved_column = _G.core.hooks.is_reserved_column }

local column = require("core.luatex-cn-core-column")
local style_registry = require("util.luatex-cn-style-registry")

-- ============================================================================
-- Alignment constants
-- ============================================================================

test_utils.run_test("alignment constants defined", function()
    test_utils.assert_eq(column.ALIGN_TOP, 0)
    test_utils.assert_eq(column.ALIGN_BOTTOM, 1)
    test_utils.assert_eq(column.ALIGN_CENTER, 2)
    test_utils.assert_eq(column.ALIGN_STRETCH, 3)
    test_utils.assert_eq(column.LAST_OFFSET, 4)
end)

-- ============================================================================
-- find_last_column_in_half_page
-- ============================================================================

test_utils.run_test("find_last_column_in_half_page: no banxin", function()
    local result = column.find_last_column_in_half_page(0, 10, 0, false)
    test_utils.assert_eq(result, 9)
end)

test_utils.run_test("find_last_column_in_half_page: banxin disabled", function()
    local result = column.find_last_column_in_half_page(0, 10, 5, false)
    test_utils.assert_eq(result, 9)
end)

test_utils.run_test("find_last_column_in_half_page: with banxin interval=5", function()
    -- interval=5 means banxin at col 5, 11, 17, ...
    -- (col % 6 == 5)
    local result = column.find_last_column_in_half_page(0, 12, 5, true)
    -- col 5 is banxin, so last column before it is 4
    test_utils.assert_eq(result, 4)
end)

test_utils.run_test("find_last_column_in_half_page: cur_col past first banxin", function()
    -- Starting from col 6, next banxin at col 11
    local result = column.find_last_column_in_half_page(6, 12, 5, true)
    test_utils.assert_eq(result, 10)
end)

test_utils.run_test("find_last_column_in_half_page: no banxin in range", function()
    -- interval=5, banxin at 5, 11...
    -- p_cols = 4, so no banxin column exists
    local result = column.find_last_column_in_half_page(0, 4, 5, true)
    test_utils.assert_eq(result, 3)
end)

-- ============================================================================
-- push_style / pop_style
-- ============================================================================

test_utils.run_test("push_style: returns style ID", function()
    style_registry.clear()
    local id = column.push_style("1 0 0", nil, nil, nil, nil, nil, nil, nil, nil)
    test_utils.assert_type(id, "number")
    test_utils.assert_true(id >= 1)
end)

test_utils.run_test("push_style: with grid_height dimension", function()
    style_registry.clear()
    local id = column.push_style(nil, nil, nil, "40pt", nil, nil, nil, nil, nil)
    test_utils.assert_type(id, "number")
    local cur = style_registry.current()
    test_utils.assert_true(cur.grid_height ~= nil)
end)

test_utils.run_test("pop_style: pops style", function()
    style_registry.clear()
    style_registry.push({ font_color = "0 0 0" })
    column.push_style("1 0 0", nil, nil, nil, nil, nil, nil, nil, nil)
    column.pop_style()
    local cur = style_registry.current()
    test_utils.assert_eq(cur.font_color, "0 0 0")
end)

-- ============================================================================
-- collect_nodes (smoke test)
-- ============================================================================

test_utils.run_test("collect_nodes: returns table from glyph with ATTR_COLUMN", function()
    local constants = require("core.luatex-cn-constants")
    local D = node.direct
    local g = D.new(constants.GLYPH)
    D.setfield(g, "char", 0x4E00)
    D.setfield(g, "font", 1)
    D.set_attribute(g, constants.ATTR_COLUMN, 1)
    -- Need a termination: next node without ATTR_COLUMN
    local g2 = D.new(constants.GLYPH)
    D.setfield(g2, "char", 0x4E8C)
    D.setfield(g2, "font", 1)
    D.setlink(g, g2)

    local items, next_node = column.collect_nodes(g)
    test_utils.assert_type(items, "table")
    test_utils.assert_true(#items >= 1)
end)

print("\nAll core/core-column-test tests passed!")
