-- luatex-cn-banxin-render-yuwei.lua - Unit tests for yuwei rendering
local test_utils = require('test.test_utils')
local yuwei = require('banxin.luatex-cn-banxin-render-yuwei')

-- Access internal functions for unit testing
local internal = yuwei._internal or {}

-- ============================================================================
-- Internal Helper Functions Tests
-- ============================================================================

test_utils.run_test("parse_params - Default values", function()
    if not internal.parse_params then
        -- Skip if internal functions not yet exported
        return
    end
    local params = internal.parse_params({})
    test_utils.assert_eq(params.direction, 1, "Default direction should be 1")
    test_utils.assert_eq(params.style, "black", "Default style should be 'black'")
    test_utils.assert_eq(params.color_str, "0 0 0", "Default color should be '0 0 0'")
end)

test_utils.run_test("convert_to_bp - Coordinate conversion", function()
    if not internal.convert_to_bp then
        return
    end
    local bp_coords = internal.convert_to_bp({
        x = 65536,      -- 1pt
        y = 65536 * 2,  -- 2pt
        width = 65536 * 18,
        edge_height = 65536 * 9,
        notch_height = 65536 * 12,
    })
    -- 1pt ≈ 1bp (approximately)
    test_utils.assert_eq(bp_coords.x_bp > 0.99 and bp_coords.x_bp < 1.01, true, "x_bp should be ~1")
    test_utils.assert_eq(bp_coords.half_w > 8.9 and bp_coords.half_w < 9.1, true, "half_w should be ~9")
end)

test_utils.run_test("create_black_up_path - Format check", function()
    if not internal.create_black_up_path then return end
    local bp = {
        x_bp = 0, y_bp = 0, w_bp = 18, edge_h_bp = 9, notch_h_bp = 12, half_w = 9
    }
    local path = internal.create_black_up_path(bp, "0 0 0")
    test_utils.assert_match(path, "q 0 0 0 rg", "Should start with color")
    test_utils.assert_match(path, "h f Q", "Should close and fill")
end)

test_utils.run_test("create_black_down_path - Format check", function()
    if not internal.create_black_down_path then return end
    local bp = {
        x_bp = 0, y_bp = 0, w_bp = 18, edge_h_bp = 9, notch_h_bp = 12, half_w = 9
    }
    local path = internal.create_black_down_path(bp, "1 0 0")
    test_utils.assert_match(path, "1 0 0 rg", "Should have color")
    test_utils.assert_match(path, "h f Q", "Should close and fill")
end)

test_utils.run_test("create_hollow_up_path - Format check", function()
    if not internal.create_hollow_up_path then return end
    local bp = {
        x_bp = 0, y_bp = 0, w_bp = 18, edge_h_bp = 9, notch_h_bp = 12, half_w = 9
    }
    local path = internal.create_hollow_up_path(bp, "0 0 0", 1.5)
    test_utils.assert_match(path, "0 0 0 RG", "Should have stroke color")
    test_utils.assert_match(path, "1.50 w", "Should have line width")
    test_utils.assert_match(path, "h S Q", "Should stroke")
end)

test_utils.run_test("create_hollow_down_path - Format check", function()
    if not internal.create_hollow_down_path then return end
    local bp = {
        x_bp = 0, y_bp = 0, w_bp = 18, edge_h_bp = 9, notch_h_bp = 12, half_w = 9
    }
    local path = internal.create_hollow_down_path(bp, "0 1 0", 2.0)
    test_utils.assert_match(path, "0 1 0 RG", "Should have stroke color")
    test_utils.assert_match(path, "2.00 w", "Should have line width")
end)

test_utils.run_test("create_extra_line_up_path - Format check", function()
    if not internal.create_extra_line_up_path then return end
    local bp = {
        x_bp = 0, y_bp = 0, w_bp = 18, edge_h_bp = 9, notch_h_bp = 12, half_w = 9,
        gap_bp = 4, thickness_bp = 0.5
    }
    local path = internal.create_extra_line_up_path(bp, "0 0 0")
    test_utils.assert_match(path, "0.50 w", "Should have thickness")
    test_utils.assert_match(path, "S Q", "Should stroke")
end)

test_utils.run_test("create_extra_line_down_path - Format check", function()
    if not internal.create_extra_line_down_path then return end
    local bp = {
        x_bp = 0, y_bp = 0, w_bp = 18, edge_h_bp = 9, notch_h_bp = 12, half_w = 9,
        gap_bp = 4, thickness_bp = 0.5
    }
    local path = internal.create_extra_line_down_path(bp, "0 0 1")
    test_utils.assert_match(path, "0 0 1 RG", "Should have color")
end)

test_utils.run_test("create_black_path - Direction routing", function()
    if not internal.create_black_path then return end
    local bp = {
        x_bp = 0, y_bp = 0, w_bp = 18, edge_h_bp = 9, notch_h_bp = 12, half_w = 9
    }
    local up_path = internal.create_black_path(bp, 1, "0 0 0")
    local down_path = internal.create_black_path(bp, -1, "0 0 0")
    -- They should be different
    test_utils.assert_eq(up_path ~= down_path, true, "Up and down paths should differ")
end)

test_utils.run_test("create_hollow_path - Direction routing", function()
    if not internal.create_hollow_path then return end
    local bp = {
        x_bp = 0, y_bp = 0, w_bp = 18, edge_h_bp = 9, notch_h_bp = 12, half_w = 9
    }
    local up_path = internal.create_hollow_path(bp, 1, "0 0 0", 1.0)
    local down_path = internal.create_hollow_path(bp, -1, "0 0 0", 1.0)
    test_utils.assert_eq(up_path ~= down_path, true, "Up and down hollow paths should differ")
end)

-- ============================================================================
-- draw_yuwei Tests - Black Style
-- ============================================================================

test_utils.run_test("draw_yuwei - Default Black Up Direction", function()
    local params = {
        x = 0,
        y = 0,
        width = 18 * 65536,
        edge_height = 9 * 65536,
        notch_height = 12 * 65536,
        direction = 1,
        style = "black",
        color_str = "0 0 0"
    }
    local result = yuwei.draw_yuwei(params)

    -- Expected values in bp:
    -- width = 18.0000, edge_height = 9.0000, notch_height = 12.0000
    -- half_w = 9.0000
    -- Path: top-left (0,0) → top-right (18,0) → bottom-right (18,-9) → V-tip (9,-12) → bottom-left (0,-9)

    test_utils.assert_match(result, "0%.0000 0%.0000 m", "Should start at top-left")
    test_utils.assert_match(result, "17%.%d+ 0%.0000 l", "Should draw to top-right")
    test_utils.assert_match(result, "17%.%d+ %-8%.%d+ l", "Should draw to bottom-right")
    test_utils.assert_match(result, "8%.%d+ %-11%.%d+ l", "Should draw to V-tip")
    test_utils.assert_match(result, "0%.0000 %-8%.%d+ l", "Should draw to bottom-left")
    test_utils.assert_match(result, "h f Q", "Should close and fill")
end)

test_utils.run_test("draw_yuwei - Black Down Direction", function()
    local params = {
        x = 0,
        y = 0,
        width = 18 * 65536,
        edge_height = 9 * 65536,
        notch_height = 12 * 65536,
        direction = -1,
        style = "black",
        color_str = "1 0 0"
    }
    local result = yuwei.draw_yuwei(params)

    -- Path: bottom-left (0,-12) → bottom-right (18,-12) → top-right (18,-3) → V-tip (9,0) → top-left (0,-3)
    -- Wait, looking at the code:
    -- x_bp, y_bp - notch_h_bp,                    -- Bottom-left: (0, -12)
    -- x_bp + w_bp, y_bp - notch_h_bp,             -- Bottom-right: (18, -12)
    -- x_bp + w_bp, y_bp - notch_h_bp + edge_h_bp, -- Top-right: (18, -3)
    -- x_bp + half_w, y_bp,                        -- V-tip (at top): (9, 0)
    -- x_bp, y_bp - notch_h_bp + edge_h_bp         -- Top-left: (0, -3)

    test_utils.assert_match(result, "1 0 0 rg", "Should set color")
    test_utils.assert_match(result, "0%.0000 %-11%.%d+ m", "Should start at bottom-left")
    test_utils.assert_match(result, "17%.%d+ %-11%.%d+ l", "Should draw to bottom-right")
    test_utils.assert_match(result, "17%.%d+ %-2%.%d+ l", "Should draw to top-right")
    test_utils.assert_match(result, "8%.%d+ 0%.0000 l", "Should draw to V-tip")
    test_utils.assert_match(result, "0%.0000 %-2%.%d+ l", "Should draw to top-left")
end)

test_utils.run_test("draw_yuwei - Hollow Style", function()
    local params = {
        x = 10 * 65536,
        y = 20 * 65536,
        width = 20 * 65536,
        style = "white",
        line_width = 1.5
    }
    local result = yuwei.draw_yuwei(params)

    test_utils.assert_match(result, "1.50 w", "Should set line width")
    test_utils.assert_match(result, "h S Q", "Should stroke")
end)

test_utils.run_test("draw_yuwei - Extra Line", function()
    local params = {
        width = 18 * 65536,
        extra_line = true,
        line_gap = 4 * 65536,
        border_thickness = 0.5 * 65536
    }
    local result = yuwei.draw_yuwei(params)

    -- Should contain two paths
    test_utils.assert_match(result, "0%.50 w", "Should set extra line thickness")
end)

-- ============================================================================
-- Additional Tests
-- ============================================================================

test_utils.run_test("draw_yuwei - Default parameters", function()
    local result = yuwei.draw_yuwei({})
    -- Should produce valid output with defaults
    test_utils.assert_eq(type(result), "string", "Should return a string")
    test_utils.assert_eq(string.len(result) > 0, true, "Should not be empty")
    test_utils.assert_match(result, "q", "Should start with 'q'")
    test_utils.assert_match(result, "Q", "Should end with 'Q'")
end)

test_utils.run_test("draw_yuwei - Custom position", function()
    local params = {
        x = 100 * 65536,
        y = -50 * 65536,
        width = 20 * 65536,
    }
    local result = yuwei.draw_yuwei(params)
    -- Position should be reflected in output
    test_utils.assert_match(result, "99%.%d+", "Should contain x position ~100")
end)

test_utils.run_test("draw_yuwei - Custom color", function()
    local params = {
        color_str = "0.5 0.3 0.1",
        style = "black",
    }
    local result = yuwei.draw_yuwei(params)
    test_utils.assert_match(result, "0.5 0.3 0.1 rg", "Should contain custom color for fill")
end)

test_utils.run_test("draw_yuwei - Hollow with custom color", function()
    local params = {
        color_str = "0.8 0.2 0.4",
        style = "hollow",
    }
    local result = yuwei.draw_yuwei(params)
    test_utils.assert_match(result, "0.8 0.2 0.4 RG", "Should contain custom color for stroke")
end)

test_utils.run_test("draw_yuwei - Extra line up direction", function()
    local params = {
        width = 20 * 65536,
        direction = 1,
        extra_line = true,
    }
    local result = yuwei.draw_yuwei(params)
    -- Should have two separate paths (main path and extra line)
    local q_count = 0
    for _ in result:gmatch("q ") do q_count = q_count + 1 end
    test_utils.assert_eq(q_count, 2, "Should have 2 'q' commands for main and extra line")
end)

test_utils.run_test("draw_yuwei - Extra line down direction", function()
    local params = {
        width = 20 * 65536,
        direction = -1,
        extra_line = true,
    }
    local result = yuwei.draw_yuwei(params)
    local q_count = 0
    for _ in result:gmatch("q ") do q_count = q_count + 1 end
    test_utils.assert_eq(q_count, 2, "Should have 2 'q' commands for main and extra line")
end)

test_utils.run_test("draw_yuwei - Hollow down direction", function()
    local params = {
        direction = -1,
        style = "white",
        line_width = 2.0,
    }
    local result = yuwei.draw_yuwei(params)
    test_utils.assert_match(result, "2.00 w", "Should set line width")
    test_utils.assert_match(result, "h S Q", "Should stroke not fill")
end)

test_utils.run_test("draw_yuwei - Custom edge and notch height", function()
    local params = {
        width = 30 * 65536,
        edge_height = 15 * 65536,
        notch_height = 20 * 65536,
    }
    local result = yuwei.draw_yuwei(params)
    test_utils.assert_eq(type(result), "string", "Should return a string")
end)

test_utils.run_test("draw_yuwei - Extra line custom gap", function()
    local params = {
        extra_line = true,
        line_gap = 10 * 65536,
        border_thickness = 1 * 65536,
    }
    local result = yuwei.draw_yuwei(params)
    test_utils.assert_match(result, "1%.00 w", "Should set border thickness")
end)

-- ============================================================================
-- create_yuwei_node Tests
-- ============================================================================

test_utils.run_test("create_yuwei_node - Returns node", function()
    local params = {
        width = 18 * 65536,
    }
    local n = yuwei.create_yuwei_node(params)
    test_utils.assert_eq(n ~= nil, true, "Should return a node")
end)

print("\nAll yuwei tests passed!")
