-- luatex-cn-vertical-base-test.lua - Unit tests for vertical base modules
local test_utils = require('test.test_utils')
local utils = require('luatex-cn-utils')
local text_utils = require('luatex-cn-text-utils')

test_utils.run_test("base-utils - sp_to_bp", function()
    -- 65536 sp = 1 pt
    -- 1 pt = 1/72.27 inch
    -- 1 bp = 1/72 inch
    -- sp_to_bp should be roughly 0.0000152018
    local bp = 65536 * utils.sp_to_bp
    test_utils.assert_eq(string.format("%.4f", bp), "0.9963", "sp to bp conversion mismatch (expected ~0.9963bp for 1pt)")
end)

test_utils.run_test("base-utils - to_chinese_numeral", function()
    test_utils.assert_eq(utils.to_chinese_numeral(1), "一", "1 -> 一 failure")
    test_utils.assert_eq(utils.to_chinese_numeral(10), "十", "10 -> 十 failure")
    test_utils.assert_eq(utils.to_chinese_numeral(11), "十一", "11 -> 十一 failure")
    test_utils.assert_eq(utils.to_chinese_numeral(20), "二十", "20 -> 二十 failure")
    test_utils.assert_eq(utils.to_chinese_numeral(123), "一百二十三", "123 -> 一百二十三 failure")
end)

test_utils.run_test("base-text-utils - normalize_line_endings", function()
    test_utils.assert_eq(text_utils.normalize_line_endings("A\r\nB\rC"), "A\nB\nC", "Line ending normalization failure")
end)

test_utils.run_test("base-text-utils - remove_bom", function()
    local bom = string.char(0xEF, 0xBB, 0xBF)
    test_utils.assert_eq(text_utils.remove_bom(bom .. "Hello"), "Hello", "BOM removal failure")
    test_utils.assert_eq(text_utils.remove_bom("Hello"), "Hello", "Should not remove text if no BOM")
end)

test_utils.run_test("base-text-utils - normalize_whitespace", function()
    test_utils.assert_eq(text_utils.normalize_whitespace("  A    B  "), "A B", "Whitespace normalization failure")
    test_utils.assert_eq(text_utils.normalize_whitespace("A\nB", true), "A\nB", "Should preserve newlines")
end)

test_utils.run_test("base-text-utils - normalize_for_typesetting", function()
    local input = string.char(0xEF, 0xBB, 0xBF) .. "Line 1\r\nLine 2"
    local expected = "Line 1\nLine 2"
    test_utils.assert_eq(text_utils.normalize_for_typesetting(input), expected,
        "Typesetting normalization pipeline failure")
end)

-- ============================================================================
-- PDF Literal Utility Functions Tests
-- ============================================================================

test_utils.run_test("base-utils - create_color_literal fill", function()
    local lit = utils.create_color_literal("1 0 0", false)
    test_utils.assert_eq(lit, "1 0 0 rg", "Fill color literal")
end)

test_utils.run_test("base-utils - create_color_literal stroke", function()
    local lit = utils.create_color_literal("0 1 0", true)
    test_utils.assert_eq(lit, "0 1 0 RG", "Stroke color literal")
end)

test_utils.run_test("base-utils - create_position_cm", function()
    local lit = utils.create_position_cm(10.5, -20.3)
    test_utils.assert_match(lit, "1 0 0 1 10.5000", "Position CM X")
    test_utils.assert_match(lit, "%-20.3000 cm", "Position CM Y")
end)

test_utils.run_test("base-utils - wrap_graphics_state", function()
    local lit = utils.wrap_graphics_state("1 0 0 rg")
    test_utils.assert_eq(lit, "q 1 0 0 rg Q", "Wrapped literal")
end)

test_utils.run_test("base-utils - create_color_position_literal", function()
    local lit = utils.create_color_position_literal("0.5 0 0.5", 100, -50)
    test_utils.assert_match(lit, "q 0.5 0 0.5 rg", "Color fill")
    test_utils.assert_match(lit, "0.5 0 0.5 RG", "Color stroke")
    test_utils.assert_match(lit, "100.0000", "X position")
    test_utils.assert_match(lit, "%-50.0000 cm", "Y position")
end)

test_utils.run_test("base-utils - create_graphics_state_end", function()
    local lit = utils.create_graphics_state_end()
    test_utils.assert_eq(lit, "Q", "Graphics state end")
end)

test_utils.run_test("base-utils - normalize_rgb named colors", function()
    test_utils.assert_eq(utils.normalize_rgb("black"), "0.0000 0.0000 0.0000", "Black")
    test_utils.assert_eq(utils.normalize_rgb("white"), "1.0000 1.0000 1.0000", "White")
    test_utils.assert_eq(utils.normalize_rgb("red"), "1.0000 0.0000 0.0000", "Red")
    test_utils.assert_eq(utils.normalize_rgb("blue"), "0.0000 0.0000 1.0000", "Blue")
end)

test_utils.run_test("base-utils - normalize_rgb numeric values", function()
    test_utils.assert_eq(utils.normalize_rgb("0.5 0.5 0.5"), "0.5000 0.5000 0.5000", "Decimal RGB")
    test_utils.assert_eq(utils.normalize_rgb("255, 0, 0"), "1.0000 0.0000 0.0000", "255 scale RGB")
    test_utils.assert_eq(utils.normalize_rgb("128,128,128"), "0.5020 0.5020 0.5020", "128 scale RGB")
end)

test_utils.run_test("base-utils - normalize_rgb nil handling", function()
    test_utils.assert_eq(utils.normalize_rgb(nil), nil, "Nil input")
    test_utils.assert_eq(utils.normalize_rgb(""), nil, "Empty string")
end)

print("\nAll vertical-base tests passed!")
