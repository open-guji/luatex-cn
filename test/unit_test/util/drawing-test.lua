-- Unit tests for util.luatex-cn-drawing
local test_utils = require("test.test_utils")
local drawing = require("util.luatex-cn-drawing")

-- Helper: create a simple head node for testing
local function make_head()
    return node.direct.new(node.id("whatsit"), 1)
end

-- ============================================================================
-- draw_rect_frame
-- ============================================================================

test_utils.run_test("draw_rect_frame: returns a node", function()
    local head = make_head()
    local result = drawing.draw_rect_frame(head, {
        x = 65536, y = 65536, width = 655360, height = 327680,
        line_width = 3277, color_str = "0 0 0"
    })
    test_utils.assert_type(result, "table")
end)

test_utils.run_test("draw_rect_frame: default color", function()
    local head = make_head()
    local result = drawing.draw_rect_frame(head, {
        x = 0, y = 0, width = 100000, height = 100000,
        line_width = 1000
    })
    test_utils.assert_type(result, "table")
end)

-- ============================================================================
-- draw_octagon_fill
-- ============================================================================

test_utils.run_test("draw_octagon_fill: returns a node", function()
    local head = make_head()
    local result = drawing.draw_octagon_fill(head, {
        x = 0, y = 0, width = 655360, height = 655360,
        color_str = "1 0 0"
    })
    test_utils.assert_type(result, "table")
end)

-- ============================================================================
-- draw_octagon_frame
-- ============================================================================

test_utils.run_test("draw_octagon_frame: returns a node", function()
    local head = make_head()
    local result = drawing.draw_octagon_frame(head, {
        x = 0, y = 0, width = 655360, height = 655360,
        line_width = 3277, color_str = "0 0 1"
    })
    test_utils.assert_type(result, "table")
end)

-- ============================================================================
-- draw_circle_fill
-- ============================================================================

test_utils.run_test("draw_circle_fill: returns a node", function()
    local head = make_head()
    local result = drawing.draw_circle_fill(head, {
        cx = 327680, cy = 327680, radius = 327680,
        color_str = "0 1 0"
    })
    test_utils.assert_type(result, "table")
end)

-- ============================================================================
-- draw_circle_frame
-- ============================================================================

test_utils.run_test("draw_circle_frame: returns a node", function()
    local head = make_head()
    local result = drawing.draw_circle_frame(head, {
        cx = 327680, cy = 327680, radius = 327680,
        line_width = 3277, color_str = "0 0 0"
    })
    test_utils.assert_type(result, "table")
end)

print("\nAll util/drawing-test tests passed!")
