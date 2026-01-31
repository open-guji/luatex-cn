local test_utils = require('test.test_utils')
local position = require('luatex-cn-render-position')

local internal = position._internal or {}

-- ============================================================================
-- RTL Position Calculation Tests
-- ============================================================================

test_utils.run_test("calculate_rtl_position - basic", function()
    if not position.calculate_rtl_position then return end
    local rtl_col, x_pos = position.calculate_rtl_position(
        0,     -- col
        10,    -- total_cols
        65536, -- grid_width
        1000,  -- half_thickness
        500    -- shift_x
    )
    test_utils.assert_eq(rtl_col, 9, "RTL col for col 0 with 10 cols")
    -- x_pos = 9 * 65536 + 1000 + 500 = 590824 + 1500 = 591324
    test_utils.assert_eq(x_pos, 9 * 65536 + 1000 + 500, "X position calculation")
end)

test_utils.run_test("calculate_rtl_position - last column", function()
    if not position.calculate_rtl_position then return end
    local rtl_col, x_pos = position.calculate_rtl_position(
        9,     -- col (last)
        10,    -- total_cols
        65536, -- grid_width
        0,     -- half_thickness
        0      -- shift_x
    )
    test_utils.assert_eq(rtl_col, 0, "RTL col for last col")
    test_utils.assert_eq(x_pos, 0, "X position at origin")
end)

test_utils.run_test("calculate_rtl_position - middle column", function()
    if not position.calculate_rtl_position then return end
    local rtl_col, x_pos = position.calculate_rtl_position(
        5,          -- col (middle)
        10,         -- total_cols
        65536 * 10, -- grid_width = 10pt
        0,
        0
    )
    test_utils.assert_eq(rtl_col, 4, "RTL col for middle col")
    test_utils.assert_eq(x_pos, 4 * 65536 * 10, "X position for middle col")
end)

test_utils.run_test("calculate_rtl_position - with shifts", function()
    if not position.calculate_rtl_position then return end
    local rtl_col, x_pos = position.calculate_rtl_position(
        0,
        5,
        65536,
        65536 * 2, -- half_thickness = 2pt
        65536 * 3  -- shift_x = 3pt
    )
    test_utils.assert_eq(rtl_col, 4, "RTL col")
    -- x_pos = 4 * 65536 + 2*65536 + 3*65536 = 9 * 65536
    test_utils.assert_eq(x_pos, 9 * 65536, "X position with shifts")
end)

-- ============================================================================
-- RTL Block Position Tests
-- ============================================================================

test_utils.run_test("calculate_rtl_block_position - basic", function()
    if not position.calculate_rtl_block_position then return end
    local x_pos = position.calculate_rtl_block_position(
        5,     -- col
        2,     -- width
        10,    -- total_cols
        65536, -- grid_width
        0,     -- half_thickness
        0      -- shift_x
    )
    -- rtl_col_left = 10 - (5 + 2) = 3
    test_utils.assert_eq(x_pos, 3 * 65536, "Block X position")
end)

test_utils.run_test("calculate_rtl_block_position - single column block", function()
    if not position.calculate_rtl_block_position then return end
    local x_pos = position.calculate_rtl_block_position(
        0,     -- col
        1,     -- width
        10,    -- total_cols
        65536, -- grid_width
        0,
        0
    )
    -- rtl_col_left = 10 - (0 + 1) = 9
    test_utils.assert_eq(x_pos, 9 * 65536, "Single col block X position")
end)

test_utils.run_test("calculate_rtl_block_position - full width block", function()
    if not position.calculate_rtl_block_position then return end
    local x_pos = position.calculate_rtl_block_position(
        0,  -- col
        10, -- width (full page)
        10, -- total_cols
        65536,
        0,
        0
    )
    -- rtl_col_left = 10 - (0 + 10) = 0
    test_utils.assert_eq(x_pos, 0, "Full width block starts at 0")
end)

test_utils.run_test("calculate_rtl_block_position - with shifts", function()
    if not position.calculate_rtl_block_position then return end
    local x_pos = position.calculate_rtl_block_position(
        2,
        3,
        10,
        65536,
        65536,    -- half_thickness = 1pt
        65536 * 2 -- shift_x = 2pt
    )
    -- rtl_col_left = 10 - (2 + 3) = 5
    -- x_pos = 5 * 65536 + 65536 + 2*65536 = 8 * 65536
    test_utils.assert_eq(x_pos, 8 * 65536, "Block X with shifts")
end)

-- ============================================================================
-- Y Position Calculation Tests
-- ============================================================================

test_utils.run_test("calculate_y_position - row 0", function()
    if not position.calculate_y_position then return end
    local y_pos = position.calculate_y_position(0, 65536 * 10, 0)
    test_utils.assert_eq(y_pos, 0, "Row 0 Y position")
end)

test_utils.run_test("calculate_y_position - row 1", function()
    if not position.calculate_y_position then return end
    local y_pos = position.calculate_y_position(1, 65536 * 10, 0)
    test_utils.assert_eq(y_pos, -65536 * 10, "Row 1 Y position")
end)

test_utils.run_test("calculate_y_position - with shift", function()
    if not position.calculate_y_position then return end
    local y_pos = position.calculate_y_position(2, 65536 * 10, 65536 * 5)
    -- y = -2 * 65536*10 - 65536*5 = -20*65536 - 5*65536 = -25*65536
    test_utils.assert_eq(y_pos, -25 * 65536, "Row 2 with shift Y position")
end)

-- ============================================================================
-- calc_grid_position Tests
-- ============================================================================

test_utils.run_test("calc_grid_position - basic center alignment", function()
    local glyph_dims = { width = 65536 * 8, height = 65536 * 8, depth = 65536 * 2 }
    local params = {
        grid_width = 65536 * 10,
        grid_height = 65536 * 10,
        total_cols = 10,
        shift_x = 0,
        shift_y = 0,
        half_thickness = 0,
        v_align = "center",
        h_align = "center"
    }
    local x_off, y_off = position.calc_grid_position(0, 0, glyph_dims, params)
    test_utils.assert_eq(type(x_off), "number", "X offset should be number")
    test_utils.assert_eq(type(y_off), "number", "Y offset should be number")
end)

test_utils.run_test("calc_grid_position - left alignment", function()
    local glyph_dims = { width = 65536 * 5, height = 65536 * 5, depth = 0 }
    local params = {
        grid_width = 65536 * 10,
        grid_height = 65536 * 10,
        total_cols = 10,
        shift_x = 0,
        shift_y = 0,
        half_thickness = 0,
        v_align = "center",
        h_align = "left"
    }
    local x_off, _ = position.calc_grid_position(0, 0, glyph_dims, params)
    -- For col 0 with 10 cols, rtl_col = 9
    -- left align: x_off = 9 * grid_width + half_thickness + shift_x
    test_utils.assert_eq(x_off, 9 * 65536 * 10, "Left aligned X offset")
end)

test_utils.run_test("calc_grid_position - sub_col jiazhu", function()
    local glyph_dims = { width = 65536 * 3, height = 65536 * 3, depth = 0 }
    local params = {
        grid_width = 65536 * 10,
        grid_height = 65536 * 10,
        total_cols = 10,
        shift_x = 0,
        shift_y = 0,
        half_thickness = 0,
        v_align = "center",
        h_align = "center",
        sub_col = 1,
        jiazhu_align = "outward"
    }
    local x_off, y_off = position.calc_grid_position(0, 0, glyph_dims, params)
    test_utils.assert_eq(type(x_off), "number", "Jiazhu X offset should be number")
    test_utils.assert_eq(type(y_off), "number", "Jiazhu Y offset should be number")
end)

print("\nAll render-position tests passed!")
