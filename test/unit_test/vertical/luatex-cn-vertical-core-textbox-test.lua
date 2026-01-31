-- luatex-cn-vertical-core-textbox-test.lua - Unit tests for core textbox
local test_utils = require('test.test_utils')
local textbox = require('luatex-cn-core-textbox')

-- Access internal functions for unit testing
local internal = textbox._internal or {}

-- ============================================================================
-- Internal Helper Functions Tests
-- ============================================================================

test_utils.run_test("parse_column_aligns - Empty string", function()
    if not internal.parse_column_aligns then return end
    local result = internal.parse_column_aligns("")
    test_utils.assert_eq(type(result), "table", "Should return a table")
end)

test_utils.run_test("parse_column_aligns - Single value", function()
    if not internal.parse_column_aligns then return end
    local result = internal.parse_column_aligns("center")
    test_utils.assert_eq(result[0], "center", "Should parse single value")
end)

test_utils.run_test("parse_column_aligns - Multiple values", function()
    if not internal.parse_column_aligns then return end
    local result = internal.parse_column_aligns("right,left,center")
    test_utils.assert_eq(result[0], "right", "First value")
    test_utils.assert_eq(result[1], "left", "Second value")
    test_utils.assert_eq(result[2], "center", "Third value")
end)

test_utils.run_test("parse_column_aligns - With whitespace", function()
    if not internal.parse_column_aligns then return end
    local result = internal.parse_column_aligns("  right , left  ")
    test_utils.assert_eq(result[0], "right", "Should trim whitespace")
    test_utils.assert_eq(result[1], "left", "Should trim whitespace")
end)

test_utils.run_test("get_effective_n_cols - Explicit value", function()
    if not internal.get_effective_n_cols then return end
    local result = internal.get_effective_n_cols(5)
    test_utils.assert_eq(result, 5, "Should use explicit value")
end)

test_utils.run_test("get_effective_n_cols - Zero fallback", function()
    if not internal.get_effective_n_cols then return end
    local result = internal.get_effective_n_cols(0)
    test_utils.assert_eq(result, 100, "Zero should fallback to 100")
end)

test_utils.run_test("get_effective_n_cols - Nil fallback", function()
    if not internal.get_effective_n_cols then return end
    local result = internal.get_effective_n_cols(nil)
    test_utils.assert_eq(result, 100, "Nil should fallback to 100")
end)

test_utils.run_test("build_sub_params - Basic params", function()
    if not internal.build_sub_params then return end
    local params = {
        n_cols = 3,
        height = 6,
        grid_width = "12pt",
        grid_height = "14pt",
        box_align = "top",
    }
    local result = internal.build_sub_params(params, {})
    test_utils.assert_eq(result.n_cols, 3, "n_cols should be set")
    test_utils.assert_eq(result.col_limit, 6, "col_limit should be height")
    test_utils.assert_eq(result.is_textbox, true, "is_textbox should be true")
end)

test_utils.run_test("build_sub_params - Fill alignment", function()
    if not internal.build_sub_params then return end
    local params = {
        box_align = "fill",
    }
    local result = internal.build_sub_params(params, {})
    test_utils.assert_eq(result.distribute, true, "distribute should be true for fill")
end)

test_utils.run_test("build_sub_params - Debug mode", function()
    if not internal.build_sub_params then return end
    local params = {
        debug = "true",
    }
    local result = internal.build_sub_params(params, {})
    test_utils.assert_eq(result.debug_on, true, "debug_on should be true")
end)

test_utils.run_test("build_sub_params - Border mode", function()
    if not internal.build_sub_params then return end
    local params = {
        border = true,
    }
    local result = internal.build_sub_params(params, {})
    test_utils.assert_eq(result.border_on, true, "border_on should be true")
end)

test_utils.run_test("build_sub_params - Floating params", function()
    if not internal.build_sub_params then return end
    local params = {
        floating = "true",
        floating_x = "10pt",
        floating_y = "20pt",
    }
    local result = internal.build_sub_params(params, {})
    test_utils.assert_eq(result.floating, true, "floating should be true")
end)

-- ============================================================================
-- Module Function Tests
-- ============================================================================

test_utils.run_test("textbox - process_inner_box exists", function()
    test_utils.assert_eq(type(textbox.process_inner_box), "function", "process_inner_box should be a function")
end)

test_utils.run_test("textbox - register_floating_box exists", function()
    test_utils.assert_eq(type(textbox.register_floating_box), "function", "register_floating_box should be a function")
end)

test_utils.run_test("textbox - calculate_floating_positions exists", function()
    test_utils.assert_eq(type(textbox.calculate_floating_positions), "function",
        "calculate_floating_positions should be a function")
end)

test_utils.run_test("textbox - clear_registry exists", function()
    test_utils.assert_eq(type(textbox.clear_registry), "function", "clear_registry should be a function")
end)

test_utils.run_test("textbox - clear_registry resets state", function()
    -- Add something to registry
    textbox.floating_counter = 5
    textbox.floating_registry = { [1] = "test" }

    textbox.clear_registry()

    test_utils.assert_eq(textbox.floating_counter, 0, "Counter should be reset")
    test_utils.assert_eq(next(textbox.floating_registry), nil, "Registry should be empty")
end)

test_utils.run_test("textbox - calculate_floating_positions empty list", function()
    local result = textbox.calculate_floating_positions({}, { list = nil })
    test_utils.assert_eq(type(result), "table", "Should return a table")
    test_utils.assert_eq(#result, 0, "Should be empty for nil list")
end)

print("\nAll core-textbox tests passed!")
