local test_utils = require('test.test_utils')
local sidenote = require('vertical.luatex-cn-vertical-core-sidenote')
local constants = require('vertical.luatex-cn-vertical-base-constants')

local internal = sidenote._internal or {}

-- ============================================================================
-- Internal Helper Functions Tests
-- ============================================================================

test_utils.run_test("serialize - Simple table", function()
    if not internal.serialize then return end
    local result = internal.serialize({ a = 1, b = 2 })
    test_utils.assert_eq(type(result), "string", "Should return a string")
    test_utils.assert_match(result, "a=1", "Should contain a=1")
    test_utils.assert_match(result, "b=2", "Should contain b=2")
end)

test_utils.run_test("create_gap_tracker - Set and get", function()
    if not internal.create_gap_tracker then return end
    local tracker = internal.create_gap_tracker()
    tracker.set(0, 1, 5)
    test_utils.assert_eq(tracker.get(0, 1), 5, "Should return set value")
    test_utils.assert_eq(tracker.get(0, 0), -1, "Default value should be -1")
end)

test_utils.run_test("is_reserved_column - Basic", function()
    if not internal.is_reserved_column then return end
    test_utils.assert_eq(internal.is_reserved_column(5, false, 0), false, "Should be false when banxin off")
end)

test_utils.run_test("extract_registry_content - table", function()
    if not internal.extract_registry_content then return end
    local item = { head = "head", metadata = { x = 1 } }
    local c, m = internal.extract_registry_content(item)
    test_utils.assert_eq(c, "head")
    test_utils.assert_eq(m.x, 1)
end)

test_utils.run_test("calculate_start_position - basic", function()
    if not internal.calculate_start_position then return end
    local row = internal.calculate_start_position(5, { yoffset = 65536 * 20 }, 65536 * 20)
    test_utils.assert_eq(row, 7, "anchor_row + 1 + yoffset_grid")
end)

test_utils.run_test("calculate_next_node_pos - wrapping", function()
    if not internal.calculate_next_node_pos then return end
    local config = {
        step = 1,
        padding_bottom_grid = 0,
        line_limit = 10,
        p_cols = 10,
        banxin_on = false,
        interval = 0,
        padding_top_grid = 0,
        tracker = { get = function() return -1 end }
    }
    local p, c, r = internal.calculate_next_node_pos(0, 0, 9, constants.GLYPH, config)
    test_utils.assert_eq(p, 0)
    test_utils.assert_eq(c, 1)
    test_utils.assert_eq(r, 0)
end)

-- ============================================================================
-- Integration Tests (Simplified)
-- ============================================================================

test_utils.run_test("core-sidenote - Registration", function()
    local head = node.new("glyph")
    tex.box[100] = { list = head }
    sidenote.register_sidenote(100, { yoffset = 10 })
    test_utils.assert_eq(sidenote.registry_counter > 0, true, "Counter should increment")
    test_utils.assert_eq(sidenote.registry[sidenote.registry_counter].metadata.yoffset, 10)
end)

test_utils.run_test("sidenote - clear_registry", function()
    sidenote.registry_counter = 1
    sidenote.clear_registry()
    test_utils.assert_eq(sidenote.registry_counter, 0)
    test_utils.assert_eq(next(sidenote.registry), nil)
end)

print("\nAll core-sidenote tests passed!")
