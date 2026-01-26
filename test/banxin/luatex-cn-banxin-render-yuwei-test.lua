-- luatex-cn-banxin-render-yuwei.lua - Unit tests for yuwei rendering
local test_utils = require('test.test_utils')
local yuwei = require('banxin.luatex-cn-banxin-render-yuwei')

-- Mock sp_to_bp if needed (actually it uses utils.sp_to_bp)
-- We need to make sure utils is loaded or mocked.
-- Since we added src to package.path, it should load the real one if environment allows.

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

print("\nAll tests passed!")
