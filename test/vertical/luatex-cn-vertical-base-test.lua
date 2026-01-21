-- luatex-cn-vertical-base-test.lua - Unit tests for vertical base modules
local test_utils = require('test.test_utils')
local constants = require('tex.vertical.luatex-cn-vertical-base-constants')
local utils = require('tex.vertical.luatex-cn-vertical-base-utils')
local text_utils = require('tex.vertical.luatex-cn-vertical-base-text-utils')

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

print("\nAll vertical-base tests passed!")
