-- Unit tests for core.luatex-cn-constants
local test_utils = require("test.test_utils")
local constants = require("core.luatex-cn-constants")

-- ============================================================================
-- Node type constants
-- ============================================================================

test_utils.run_test("GLYPH constant is defined", function()
    test_utils.assert_type(constants.GLYPH, "number")
    test_utils.assert_eq(constants.GLYPH, node.id("glyph"))
end)

test_utils.run_test("KERN constant is defined", function()
    test_utils.assert_type(constants.KERN, "number")
end)

test_utils.run_test("HLIST constant is defined", function()
    test_utils.assert_eq(constants.HLIST, node.id("hlist"))
end)

test_utils.run_test("VLIST constant is defined", function()
    test_utils.assert_eq(constants.VLIST, node.id("vlist"))
end)

test_utils.run_test("WHATSIT constant is defined", function()
    test_utils.assert_eq(constants.WHATSIT, node.id("whatsit"))
end)

test_utils.run_test("GLUE constant is defined", function()
    test_utils.assert_eq(constants.GLUE, node.id("glue"))
end)

test_utils.run_test("PENALTY constant is defined", function()
    test_utils.assert_eq(constants.PENALTY, node.id("penalty"))
end)

test_utils.run_test("LOCAL_PAR constant is defined", function()
    test_utils.assert_eq(constants.LOCAL_PAR, node.id("local_par"))
end)

test_utils.run_test("RULE constant is defined", function()
    test_utils.assert_eq(constants.RULE, node.id("rule"))
end)

-- ============================================================================
-- D (node.direct)
-- ============================================================================

test_utils.run_test("D is node.direct", function()
    test_utils.assert_eq(constants.D, node.direct)
end)

-- ============================================================================
-- Attribute constants are defined and are numbers
-- ============================================================================

test_utils.run_test("ATTR_INDENT is defined", function()
    test_utils.assert_type(constants.ATTR_INDENT, "number")
end)

test_utils.run_test("ATTR_TEXTBOX_WIDTH is defined", function()
    test_utils.assert_type(constants.ATTR_TEXTBOX_WIDTH, "number")
end)

test_utils.run_test("ATTR_JIAZHU is defined", function()
    test_utils.assert_type(constants.ATTR_JIAZHU, "number")
end)

test_utils.run_test("ATTR_DECORATE_ID is defined", function()
    test_utils.assert_eq(constants.ATTR_DECORATE_ID, 202610)
end)

test_utils.run_test("ATTR_STYLE_REG_ID is defined", function()
    test_utils.assert_type(constants.ATTR_STYLE_REG_ID, "number")
end)

test_utils.run_test("ATTR_PUNCT_TYPE is defined", function()
    test_utils.assert_type(constants.ATTR_PUNCT_TYPE, "number")
end)

test_utils.run_test("ATTR_VERT_ROTATE is defined", function()
    test_utils.assert_type(constants.ATTR_VERT_ROTATE, "number")
end)

test_utils.run_test("ATTR_COLUMN is defined", function()
    test_utils.assert_type(constants.ATTR_COLUMN, "number")
end)

test_utils.run_test("ATTR_HALIGN is defined", function()
    test_utils.assert_type(constants.ATTR_HALIGN, "number")
end)

-- ============================================================================
-- User ID constants
-- ============================================================================

test_utils.run_test("SIDENOTE_USER_ID is defined", function()
    test_utils.assert_eq(constants.SIDENOTE_USER_ID, 202601)
end)

test_utils.run_test("FLOATING_TEXTBOX_USER_ID is defined", function()
    test_utils.assert_eq(constants.FLOATING_TEXTBOX_USER_ID, 202602)
end)

test_utils.run_test("FOOTNOTE_USER_ID is defined", function()
    test_utils.assert_eq(constants.FOOTNOTE_USER_ID, 202607)
end)

-- ============================================================================
-- to_dimen
-- ============================================================================

test_utils.run_test("to_dimen: pt dimension", function()
    local result = constants.to_dimen("10pt")
    test_utils.assert_eq(result, tex.sp("10pt"))
end)

test_utils.run_test("to_dimen: bp dimension", function()
    local result = constants.to_dimen("10bp")
    test_utils.assert_eq(result, tex.sp("10bp"))
end)

test_utils.run_test("to_dimen: mm dimension", function()
    local result = constants.to_dimen("10mm")
    test_utils.assert_eq(result, tex.sp("10mm"))
end)

test_utils.run_test("to_dimen: sp dimension", function()
    local result = constants.to_dimen("100sp")
    test_utils.assert_eq(result, 100)
end)

test_utils.run_test("to_dimen: em returns table", function()
    local result = constants.to_dimen("1.5em")
    test_utils.assert_type(result, "table")
    test_utils.assert_eq(result.unit, "em")
    test_utils.assert_near(result.value, 1.5)
end)

test_utils.run_test("to_dimen: negative em", function()
    local result = constants.to_dimen("-0.6em")
    test_utils.assert_type(result, "table")
    test_utils.assert_eq(result.unit, "em")
    test_utils.assert_near(result.value, -0.6)
end)

test_utils.run_test("to_dimen: raw number returns number", function()
    test_utils.assert_eq(constants.to_dimen("12345"), 12345)
end)

test_utils.run_test("to_dimen: number input returns as-is", function()
    test_utils.assert_eq(constants.to_dimen(65536), 65536)
end)

test_utils.run_test("to_dimen: nil returns nil", function()
    test_utils.assert_nil(constants.to_dimen(nil))
end)

test_utils.run_test("to_dimen: empty string returns nil", function()
    test_utils.assert_nil(constants.to_dimen(""))
end)

test_utils.run_test("to_dimen: 'nil' string returns nil", function()
    test_utils.assert_nil(constants.to_dimen("nil"))
end)

test_utils.run_test("to_dimen: braces stripped", function()
    local result = constants.to_dimen("{10pt}")
    test_utils.assert_eq(result, tex.sp("10pt"))
end)

-- ============================================================================
-- resolve_dimen
-- ============================================================================

test_utils.run_test("resolve_dimen: absolute dimension (sp)", function()
    local result = constants.resolve_dimen("10pt", 655360)
    test_utils.assert_eq(result, tex.sp("10pt"))
end)

test_utils.run_test("resolve_dimen: em relative to font size", function()
    local result = constants.resolve_dimen("1em", 655360)
    test_utils.assert_eq(result, 655360)
end)

test_utils.run_test("resolve_dimen: 2em", function()
    local result = constants.resolve_dimen("2em", 655360)
    test_utils.assert_eq(result, 655360 * 2)
end)

test_utils.run_test("resolve_dimen: nil returns nil", function()
    test_utils.assert_nil(constants.resolve_dimen(nil, 655360))
end)

test_utils.run_test("resolve_dimen: empty string returns nil", function()
    test_utils.assert_nil(constants.resolve_dimen("", 655360))
end)

-- ============================================================================
-- is_forced_indent / encode_forced_indent
-- ============================================================================

test_utils.run_test("encode_forced_indent: zero indent", function()
    local encoded = constants.encode_forced_indent(0)
    test_utils.assert_eq(encoded, constants.INDENT_FORCE_ZERO)
end)

test_utils.run_test("encode_forced_indent: positive indent", function()
    local encoded = constants.encode_forced_indent(3)
    test_utils.assert_eq(encoded, constants.INDENT_FORCE_BASE - 3)
end)

test_utils.run_test("is_forced_indent: detects force zero", function()
    local is_forced, value = constants.is_forced_indent(constants.INDENT_FORCE_ZERO)
    test_utils.assert_true(is_forced)
    test_utils.assert_eq(value, 0)
end)

test_utils.run_test("is_forced_indent: detects forced positive", function()
    local encoded = constants.encode_forced_indent(5)
    local is_forced, value = constants.is_forced_indent(encoded)
    test_utils.assert_true(is_forced)
    test_utils.assert_eq(value, 5)
end)

test_utils.run_test("is_forced_indent: roundtrip", function()
    for i = 0, 10 do
        local encoded = constants.encode_forced_indent(i)
        local is_forced, value = constants.is_forced_indent(encoded)
        test_utils.assert_true(is_forced)
        test_utils.assert_eq(value, i, "roundtrip failed for indent=" .. i)
    end
end)

test_utils.run_test("is_forced_indent: normal indent not forced", function()
    local is_forced = constants.is_forced_indent(2)
    test_utils.assert_eq(is_forced, false)
end)

test_utils.run_test("is_forced_indent: nil not forced", function()
    local is_forced = constants.is_forced_indent(nil)
    test_utils.assert_eq(is_forced, false)
end)

test_utils.run_test("is_forced_indent: INDENT_INHERIT not forced", function()
    local is_forced = constants.is_forced_indent(constants.INDENT_INHERIT)
    test_utils.assert_eq(is_forced, false)
end)

-- ============================================================================
-- Indent constants
-- ============================================================================

test_utils.run_test("INDENT_FORCE_ZERO is -2", function()
    test_utils.assert_eq(constants.INDENT_FORCE_ZERO, -2)
end)

test_utils.run_test("INDENT_INHERIT is 0", function()
    test_utils.assert_eq(constants.INDENT_INHERIT, 0)
end)

test_utils.run_test("INDENT_FORCE_BASE is -1000", function()
    test_utils.assert_eq(constants.INDENT_FORCE_BASE, -1000)
end)

-- ============================================================================
-- Penalty constants
-- ============================================================================

test_utils.run_test("PENALTY_SMART_BREAK value", function()
    test_utils.assert_eq(constants.PENALTY_SMART_BREAK, -10001)
end)

test_utils.run_test("PENALTY_FORCE_COLUMN value", function()
    test_utils.assert_eq(constants.PENALTY_FORCE_COLUMN, -10002)
end)

test_utils.run_test("PENALTY_FORCE_PAGE value", function()
    test_utils.assert_eq(constants.PENALTY_FORCE_PAGE, -10003)
end)

test_utils.run_test("PENALTY_PAGE_FILL value", function()
    test_utils.assert_eq(constants.PENALTY_PAGE_FILL, -10000)
end)

-- ============================================================================
-- color_map
-- ============================================================================

test_utils.run_test("color_map: has common colors", function()
    test_utils.assert_eq(constants.color_map.red, "1 0 0")
    test_utils.assert_eq(constants.color_map.blue, "0 0 1")
    test_utils.assert_eq(constants.color_map.green, "0 1 0")
    test_utils.assert_eq(constants.color_map.black, "0 0 0")
end)

test_utils.run_test("color_map: has purple and orange", function()
    test_utils.assert_eq(constants.color_map.purple, "0.5 0 0.5")
    test_utils.assert_eq(constants.color_map.orange, "1 0.5 0")
end)

-- ============================================================================
-- register_decorate
-- ============================================================================

test_utils.run_test("register_decorate: returns incrementing IDs", function()
    _G.decorate_registry = {}
    local id1 = constants.register_decorate("a", "0pt", "0pt", nil, nil, nil, nil)
    local id2 = constants.register_decorate("b", "0pt", "0pt", nil, nil, nil, nil)
    test_utils.assert_eq(id1, 1)
    test_utils.assert_eq(id2, 2)
end)

-- ============================================================================
-- register_line_mark
-- ============================================================================

test_utils.run_test("register_line_mark: returns incrementing IDs", function()
    _G.line_mark_group_counter = 0
    _G.line_mark_registry = {}
    local id1 = constants.register_line_mark("straight", "black", "0.6em", "medium", "0.4pt", "standard")
    local id2 = constants.register_line_mark("wavy", "red", "0.6em", "small", "0.8pt", "cursive")
    test_utils.assert_eq(id1, 1)
    test_utils.assert_eq(id2, 2)
    test_utils.assert_eq(_G.line_mark_registry[1].type, "straight")
    test_utils.assert_eq(_G.line_mark_registry[2].type, "wavy")
end)

print("\nAll core/constants-test tests passed!")
