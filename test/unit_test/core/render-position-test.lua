-- Unit tests for core.luatex-cn-render-position
local test_utils = require("test.test_utils")

-- Mock textflow module (required by calc_grid_position)
package.loaded['core.luatex-cn-textflow'] = {
    calculate_sub_column_x_offset = function(base_x, col_width, glyph_width, sub_col, align)
        return base_x
    end,
}

local pos = require("core.luatex-cn-render-position")

-- ============================================================================
-- get_column_x (uniform columns, with banxin width support)
-- ============================================================================

test_utils.run_test("get_column_x: uniform columns (no banxin)", function()
    local col_geom = { grid_width = 65536 * 20, banxin_width = 0, interval = 0 }
    test_utils.assert_eq(pos.get_column_x(0, col_geom), 0)
    test_utils.assert_eq(pos.get_column_x(1, col_geom), 65536 * 20)
    test_utils.assert_eq(pos.get_column_x(3, col_geom), 65536 * 60)
end)

test_utils.run_test("get_column_x: with banxin (same width as grid)", function()
    local gw = 65536 * 20
    local col_geom = { grid_width = gw, banxin_width = gw, interval = 5 }
    -- Same width means simple multiplication
    test_utils.assert_eq(pos.get_column_x(0, col_geom), 0)
    test_utils.assert_eq(pos.get_column_x(1, col_geom), gw)
end)

test_utils.run_test("get_column_x: with banxin (different width)", function()
    local gw = 65536 * 20
    local bw = 65536 * 10  -- banxin col is narrower
    local col_geom = { grid_width = gw, banxin_width = bw, interval = 3 }
    -- Group size = interval+1 = 4
    -- rtl_col 0-2: regular cols → 0, gw, 2*gw
    -- rtl_col 3: banxin col → 3*gw (but with banxin width subtracted from accumulation)
    test_utils.assert_eq(pos.get_column_x(0, col_geom), 0)
    test_utils.assert_eq(pos.get_column_x(1, col_geom), gw)
    test_utils.assert_eq(pos.get_column_x(2, col_geom), 2 * gw)
    -- rtl_col 3 is banxin → x = 3*gw (interval cols) ... actually need to check formula
    -- full_groups = floor(3/4) = 0, remainder = 3
    -- remainder == interval (3 == 3): x = 0 + interval * gw = 3*gw
    test_utils.assert_eq(pos.get_column_x(3, col_geom), 3 * gw)
    -- rtl_col 4: full_groups = 1, remainder = 0
    -- x = 1 * (3*gw + bw) + 0 = 3*gw + bw
    test_utils.assert_eq(pos.get_column_x(4, col_geom), 3 * gw + bw)
end)

-- ============================================================================
-- get_column_width
-- ============================================================================

test_utils.run_test("get_column_width: uniform columns", function()
    local gw = 65536 * 20
    local col_geom = { grid_width = gw, banxin_width = 0, interval = 0 }
    test_utils.assert_eq(pos.get_column_width(0, col_geom), gw)
    test_utils.assert_eq(pos.get_column_width(5, col_geom), gw)
end)

test_utils.run_test("get_column_width: banxin column returns banxin_width", function()
    local gw = 65536 * 20
    local bw = 65536 * 10
    local col_geom = { grid_width = gw, banxin_width = bw, interval = 3 }
    -- col % (interval+1) == interval → banxin
    -- interval = 3, group_size = 4
    -- col 3 % 4 == 3 → banxin
    test_utils.assert_eq(pos.get_column_width(3, col_geom), bw)
    test_utils.assert_eq(pos.get_column_width(7, col_geom), bw)
    -- col 0 % 4 == 0 → regular
    test_utils.assert_eq(pos.get_column_width(0, col_geom), gw)
    test_utils.assert_eq(pos.get_column_width(1, col_geom), gw)
end)

-- ============================================================================
-- get_column_x_var / get_column_width_var (variable-width columns)
-- ============================================================================

test_utils.run_test("get_column_x_var: basic variable-width", function()
    local col_widths = { 100, 200, 150 }  -- logical cols 0, 1, 2
    local total_cols = 3
    -- rtl_col 0 is leftmost visual col. x starts at 0.
    test_utils.assert_eq(pos.get_column_x_var(0, col_widths, total_cols), 0)
    -- rtl_col 1: accumulate col_widths for rtl_col 0
    -- logical_col for rtl_col 0 = 3-1-0 = 2 → width = 150
    test_utils.assert_eq(pos.get_column_x_var(1, col_widths, total_cols), 150)
    -- rtl_col 2: accumulate for rtl_col 0 and 1
    -- logical 2 → 150, logical 1 → 200
    test_utils.assert_eq(pos.get_column_x_var(2, col_widths, total_cols), 150 + 200)
end)

test_utils.run_test("get_column_width_var: returns correct width", function()
    local col_widths = { 100, 200, 150 }
    test_utils.assert_eq(pos.get_column_width_var(0, col_widths), 100)
    test_utils.assert_eq(pos.get_column_width_var(1, col_widths), 200)
    test_utils.assert_eq(pos.get_column_width_var(2, col_widths), 150)
end)

test_utils.run_test("get_column_width_var: out of range returns 0", function()
    local col_widths = { 100, 200 }
    test_utils.assert_eq(pos.get_column_width_var(5, col_widths), 0)
end)

-- ============================================================================
-- _internal.calculate_rtl_position
-- ============================================================================

test_utils.run_test("calculate_rtl_position: basic RTL conversion", function()
    local col_geom = { grid_width = 65536 * 20, banxin_width = 0, interval = 0 }
    local gw = 65536 * 20
    -- col=0 in 10-column layout → rtl_col = 9
    local rtl, x = pos._internal.calculate_rtl_position(0, 10, col_geom, 0, 0)
    test_utils.assert_eq(rtl, 9)
    test_utils.assert_eq(x, 9 * gw)
end)

test_utils.run_test("calculate_rtl_position: with shift_x and half_thickness", function()
    local gw = 65536 * 20
    local col_geom = { grid_width = gw, banxin_width = 0, interval = 0 }
    local half_t = 1000
    local shift_x = 5000
    local rtl, x = pos._internal.calculate_rtl_position(0, 5, col_geom, half_t, shift_x)
    test_utils.assert_eq(rtl, 4)
    test_utils.assert_eq(x, 4 * gw + half_t + shift_x)
end)

-- ============================================================================
-- _internal.calculate_y_position
-- ============================================================================

test_utils.run_test("calculate_y_position: row 0", function()
    local y = pos._internal.calculate_y_position(0, 65536 * 20, 0)
    test_utils.assert_eq(y, 0)
end)

test_utils.run_test("calculate_y_position: row 3", function()
    local gh = 65536 * 20
    local y = pos._internal.calculate_y_position(3, gh, 0)
    test_utils.assert_eq(y, -3 * gh)
end)

test_utils.run_test("calculate_y_position: with shift_y", function()
    local gh = 65536 * 20
    local shift_y = 10000
    local y = pos._internal.calculate_y_position(2, gh, shift_y)
    test_utils.assert_eq(y, -2 * gh - shift_y)
end)

-- ============================================================================
-- calc_grid_position (basic tests)
-- ============================================================================

test_utils.run_test("calc_grid_position: basic single column center alignment", function()
    local gw = 65536 * 20
    local gh = 65536 * 20
    local dims = { width = gw, height = 65536 * 15, depth = 65536 * 5 }
    local params = {
        grid_width = gw,
        grid_height = gh,
        total_cols = 1,
        shift_x = 0,
        shift_y = 0,
        v_align = "center",
        h_align = "center",
        half_thickness = 0,
        y_sp = 0,
        cell_height = gh,
    }
    local x_off, y_off = pos.calc_grid_position(0, dims, params)
    test_utils.assert_type(x_off, "number")
    test_utils.assert_type(y_off, "number")
end)

test_utils.run_test("calc_grid_position: RTL multi-column", function()
    local gw = 65536 * 20
    local gh = 65536 * 20
    local dims = { width = gw, height = 65536 * 15, depth = 65536 * 5 }
    local params = {
        grid_width = gw,
        grid_height = gh,
        total_cols = 5,
        shift_x = 0,
        shift_y = 0,
        v_align = "center",
        h_align = "center",
        half_thickness = 0,
        y_sp = gh * 2,
        cell_height = gh,
    }
    local x0, y0 = pos.calc_grid_position(0, dims, params)
    local x4, y4 = pos.calc_grid_position(4, dims, params)
    -- Col 0 (rightmost) should have larger x than col 4 (leftmost)
    test_utils.assert_true(x0 > x4, "col 0 should be to the right of col 4")
end)

-- ============================================================================
-- position_glyph (basic test)
-- ============================================================================

test_utils.run_test("position_glyph: returns glyph and kern", function()
    local g = node.direct.new(node.id("glyph"))
    node.direct.setfield(g, "width", 65536 * 10)
    node.direct.setfield(g, "height", 65536 * 8)
    node.direct.setfield(g, "depth", 65536 * 2)
    node.direct.setfield(g, "font", 1)

    local glyph_out, kern_out = pos.position_glyph(g, 0, 0, {
        cell_width = 65536 * 20,
        cell_height = 65536 * 20,
    })
    test_utils.assert_true(glyph_out ~= nil)
    test_utils.assert_true(kern_out ~= nil)
    -- kern should be negative of glyph width
    local kern_val = node.direct.getfield(kern_out, "kern")
    test_utils.assert_eq(kern_val, -(65536 * 10))
end)

print("\nAll core/render-position-test tests passed!")
