-- Unit tests for util.luatex-cn-utils
local test_utils = require("test.test_utils")
local utils = require("util.luatex-cn-utils")

-- ============================================================================
-- normalize_rgb
-- ============================================================================

test_utils.run_test("normalize_rgb: named color black", function()
    test_utils.assert_eq(utils.normalize_rgb("black"), "0.0000 0.0000 0.0000")
end)

test_utils.run_test("normalize_rgb: named color red", function()
    test_utils.assert_eq(utils.normalize_rgb("red"), "1.0000 0.0000 0.0000")
end)

test_utils.run_test("normalize_rgb: named color white", function()
    test_utils.assert_eq(utils.normalize_rgb("white"), "1.0000 1.0000 1.0000")
end)

test_utils.run_test("normalize_rgb: named color blue", function()
    test_utils.assert_eq(utils.normalize_rgb("blue"), "0.0000 0.0000 1.0000")
end)

test_utils.run_test("normalize_rgb: named color yellow", function()
    test_utils.assert_eq(utils.normalize_rgb("yellow"), "1.0000 1.0000 0.0000")
end)

test_utils.run_test("normalize_rgb: named color gray", function()
    test_utils.assert_eq(utils.normalize_rgb("gray"), "0.5000 0.5000 0.5000")
end)

test_utils.run_test("normalize_rgb: named color case insensitive", function()
    test_utils.assert_eq(utils.normalize_rgb("BLACK"), "0.0000 0.0000 0.0000")
    test_utils.assert_eq(utils.normalize_rgb("Red"), "1.0000 0.0000 0.0000")
end)

test_utils.run_test("normalize_rgb: decimal format 0-1", function()
    test_utils.assert_eq(utils.normalize_rgb("0.5 0.3 0.1"), "0.5000 0.3000 0.1000")
end)

test_utils.run_test("normalize_rgb: integer 0-1 range", function()
    test_utils.assert_eq(utils.normalize_rgb("1 0 0"), "1.0000 0.0000 0.0000")
end)

test_utils.run_test("normalize_rgb: 255 scale", function()
    test_utils.assert_eq(utils.normalize_rgb("255 128 0"), "1.0000 0.5020 0.0000")
end)

test_utils.run_test("normalize_rgb: comma separated", function()
    test_utils.assert_eq(utils.normalize_rgb("0.5,0.3,0.1"), "0.5000 0.3000 0.1000")
end)

test_utils.run_test("normalize_rgb: TeX braces artifact", function()
    local result = utils.normalize_rgb("{0.5} {0.3} {0.1}")
    test_utils.assert_eq(result, "0.5000 0.3000 0.1000")
end)

test_utils.run_test("normalize_rgb: nil input", function()
    test_utils.assert_nil(utils.normalize_rgb(nil))
end)

test_utils.run_test("normalize_rgb: empty string", function()
    test_utils.assert_nil(utils.normalize_rgb(""))
end)

test_utils.run_test("normalize_rgb: invalid string", function()
    test_utils.assert_nil(utils.normalize_rgb("not a color"))
end)

test_utils.run_test("normalize_rgb: rgb: prefix", function()
    local result = utils.normalize_rgb("rgb: 0.5 0.3 0.1")
    test_utils.assert_eq(result, "0.5000 0.3000 0.1000")
end)

-- ============================================================================
-- sp_to_bp constant
-- ============================================================================

test_utils.run_test("sp_to_bp: is a number close to 1/65536", function()
    test_utils.assert_type(utils.sp_to_bp, "number")
    test_utils.assert_near(utils.sp_to_bp, 1.0 / 65781, 0.0001)
end)

-- ============================================================================
-- to_chinese_numeral
-- ============================================================================

test_utils.run_test("to_chinese_numeral: single digits", function()
    test_utils.assert_eq(utils.to_chinese_numeral(1), "一")
    test_utils.assert_eq(utils.to_chinese_numeral(5), "五")
    test_utils.assert_eq(utils.to_chinese_numeral(9), "九")
end)

test_utils.run_test("to_chinese_numeral: ten", function()
    test_utils.assert_eq(utils.to_chinese_numeral(10), "十")
end)

test_utils.run_test("to_chinese_numeral: teens", function()
    test_utils.assert_eq(utils.to_chinese_numeral(11), "十一")
    test_utils.assert_eq(utils.to_chinese_numeral(19), "十九")
end)

test_utils.run_test("to_chinese_numeral: tens", function()
    test_utils.assert_eq(utils.to_chinese_numeral(20), "二十")
    test_utils.assert_eq(utils.to_chinese_numeral(21), "二十一")
    test_utils.assert_eq(utils.to_chinese_numeral(99), "九十九")
end)

test_utils.run_test("to_chinese_numeral: hundreds", function()
    test_utils.assert_eq(utils.to_chinese_numeral(100), "一百")
    test_utils.assert_eq(utils.to_chinese_numeral(101), "一百零一")
    test_utils.assert_eq(utils.to_chinese_numeral(123), "一百二十三")
end)

test_utils.run_test("to_chinese_numeral: zero/negative", function()
    test_utils.assert_eq(utils.to_chinese_numeral(0), "")
    test_utils.assert_eq(utils.to_chinese_numeral(-1), "")
end)

test_utils.run_test("to_chinese_numeral: nil", function()
    test_utils.assert_eq(utils.to_chinese_numeral(nil), "")
end)

-- ============================================================================
-- to_chinese_digits
-- ============================================================================

test_utils.run_test("to_chinese_digits: single digit", function()
    test_utils.assert_eq(utils.to_chinese_digits(5), "五")
end)

test_utils.run_test("to_chinese_digits: multi-digit (915)", function()
    test_utils.assert_eq(utils.to_chinese_digits(915), "九一五")
end)

test_utils.run_test("to_chinese_digits: with zero", function()
    test_utils.assert_eq(utils.to_chinese_digits(103), "一〇三")
end)

test_utils.run_test("to_chinese_digits: zero/negative", function()
    test_utils.assert_eq(utils.to_chinese_digits(0), "")
    test_utils.assert_eq(utils.to_chinese_digits(-1), "")
end)

-- ============================================================================
-- to_circled_numeral
-- ============================================================================

test_utils.run_test("to_circled_numeral: 1-20 range", function()
    local r1 = utils.to_circled_numeral(1)
    test_utils.assert_type(r1, "string")
    test_utils.assert_true(#r1 > 0, "should produce non-empty string")
end)

test_utils.run_test("to_circled_numeral: 0 returns empty", function()
    test_utils.assert_eq(utils.to_circled_numeral(0), "")
end)

test_utils.run_test("to_circled_numeral: >50 fallback", function()
    test_utils.assert_eq(utils.to_circled_numeral(51), "(51)")
end)

-- ============================================================================
-- create_color_literal
-- ============================================================================

test_utils.run_test("create_color_literal: fill (rg)", function()
    test_utils.assert_eq(utils.create_color_literal("1 0 0", false), "1 0 0 rg")
end)

test_utils.run_test("create_color_literal: stroke (RG)", function()
    test_utils.assert_eq(utils.create_color_literal("0 0 1", true), "0 0 1 RG")
end)

-- ============================================================================
-- create_position_cm
-- ============================================================================

test_utils.run_test("create_position_cm: positive coordinates", function()
    test_utils.assert_eq(utils.create_position_cm(10, 20), "1 0 0 1 10.0000 20.0000 cm")
end)

test_utils.run_test("create_position_cm: zero coordinates", function()
    test_utils.assert_eq(utils.create_position_cm(0, 0), "1 0 0 1 0.0000 0.0000 cm")
end)

test_utils.run_test("create_position_cm: negative coordinates", function()
    test_utils.assert_match(utils.create_position_cm(-5.5, -3.2), "%-5%.5000 %-3%.2000 cm")
end)

-- ============================================================================
-- wrap_graphics_state
-- ============================================================================

test_utils.run_test("wrap_graphics_state: wraps content", function()
    test_utils.assert_eq(utils.wrap_graphics_state("1 0 0 rg"), "q 1 0 0 rg Q")
end)

-- ============================================================================
-- create_graphics_state_end
-- ============================================================================

test_utils.run_test("create_graphics_state_end: returns Q", function()
    test_utils.assert_eq(utils.create_graphics_state_end(), "Q")
end)

-- ============================================================================
-- create_border_literal
-- ============================================================================

test_utils.run_test("create_border_literal: produces wrapped rect", function()
    local result = utils.create_border_literal(0.5, "0 0 0", 10, 20, 100, 50)
    test_utils.assert_match(result, "^q ")
    test_utils.assert_match(result, " Q$")
    test_utils.assert_match(result, "0 0 0 RG")
    test_utils.assert_match(result, "re S")
end)

-- ============================================================================
-- create_fill_rect_literal
-- ============================================================================

test_utils.run_test("create_fill_rect_literal: produces wrapped filled rect", function()
    local result = utils.create_fill_rect_literal("1 0 0", 10, 20, 100, 50)
    test_utils.assert_match(result, "^q ")
    test_utils.assert_match(result, " Q$")
    test_utils.assert_match(result, "1 0 0 rg")
    test_utils.assert_match(result, "re f")
end)

-- ============================================================================
-- create_color_position_literal
-- ============================================================================

test_utils.run_test("create_color_position_literal: combines color + position", function()
    local result = utils.create_color_position_literal("1 0 0", 5.0, 10.0)
    test_utils.assert_match(result, "1 0 0 rg")
    test_utils.assert_match(result, "1 0 0 RG")
    test_utils.assert_match(result, "cm")
end)

-- ============================================================================
-- parse_dim_to_sp
-- ============================================================================

test_utils.run_test("parse_dim_to_sp: pt dimension", function()
    local result = utils.parse_dim_to_sp("10pt")
    test_utils.assert_eq(result, tex.sp("10pt"))
end)

test_utils.run_test("parse_dim_to_sp: empty string returns 0", function()
    test_utils.assert_eq(utils.parse_dim_to_sp(""), 0)
end)

test_utils.run_test("parse_dim_to_sp: nil returns 0", function()
    test_utils.assert_eq(utils.parse_dim_to_sp(nil), 0)
end)

-- ============================================================================
-- insert_chapter_marker
-- ============================================================================

test_utils.run_test("insert_chapter_marker: returns incrementing IDs", function()
    _G.chapter_registry = {}
    local id1 = utils.insert_chapter_marker("Chapter 1")
    local id2 = utils.insert_chapter_marker("Chapter 2")
    test_utils.assert_eq(id1, 1)
    test_utils.assert_eq(id2, 2)
end)

print("\nAll util/utils-test tests passed!")
