-- Unit tests for util.luatex-cn-text-utils
local test_utils = require("test.test_utils")
local text_utils = require("util.luatex-cn-text-utils")

-- ============================================================================
-- normalize_line_endings
-- ============================================================================

test_utils.run_test("normalize_line_endings: CRLF to LF", function()
    test_utils.assert_eq(text_utils.normalize_line_endings("a\r\nb"), "a\nb")
end)

test_utils.run_test("normalize_line_endings: CR to LF", function()
    test_utils.assert_eq(text_utils.normalize_line_endings("a\rb"), "a\nb")
end)

test_utils.run_test("normalize_line_endings: LF unchanged", function()
    test_utils.assert_eq(text_utils.normalize_line_endings("a\nb"), "a\nb")
end)

test_utils.run_test("normalize_line_endings: mixed CRLF and CR", function()
    test_utils.assert_eq(text_utils.normalize_line_endings("a\r\nb\rc"), "a\nb\nc")
end)

test_utils.run_test("normalize_line_endings: nil returns nil", function()
    test_utils.assert_nil(text_utils.normalize_line_endings(nil))
end)

test_utils.run_test("normalize_line_endings: empty string unchanged", function()
    test_utils.assert_eq(text_utils.normalize_line_endings(""), "")
end)

-- ============================================================================
-- remove_bom
-- ============================================================================

test_utils.run_test("remove_bom: removes UTF-8 BOM", function()
    local bom = string.char(0xEF, 0xBB, 0xBF)
    test_utils.assert_eq(text_utils.remove_bom(bom .. "hello"), "hello")
end)

test_utils.run_test("remove_bom: no BOM unchanged", function()
    test_utils.assert_eq(text_utils.remove_bom("hello"), "hello")
end)

test_utils.run_test("remove_bom: nil returns nil", function()
    test_utils.assert_nil(text_utils.remove_bom(nil))
end)

test_utils.run_test("remove_bom: empty string unchanged", function()
    test_utils.assert_eq(text_utils.remove_bom(""), "")
end)

-- ============================================================================
-- normalize_whitespace
-- ============================================================================

test_utils.run_test("normalize_whitespace: collapse multiple spaces", function()
    test_utils.assert_eq(text_utils.normalize_whitespace("a  b   c"), "a b c")
end)

test_utils.run_test("normalize_whitespace: tabs to space", function()
    test_utils.assert_eq(text_utils.normalize_whitespace("a\tb"), "a b")
end)

test_utils.run_test("normalize_whitespace: trim leading/trailing", function()
    test_utils.assert_eq(text_utils.normalize_whitespace("  hello  "), "hello")
end)

test_utils.run_test("normalize_whitespace: preserve_newlines=true", function()
    local result = text_utils.normalize_whitespace("a  b\nc  d", true)
    test_utils.assert_eq(result, "a b\nc d")
end)

test_utils.run_test("normalize_whitespace: preserve_newlines=false collapses newlines", function()
    local result = text_utils.normalize_whitespace("a\n\nb", false)
    test_utils.assert_eq(result, "a b")
end)

test_utils.run_test("normalize_whitespace: nil returns nil", function()
    test_utils.assert_nil(text_utils.normalize_whitespace(nil))
end)

test_utils.run_test("normalize_whitespace: empty string unchanged", function()
    test_utils.assert_eq(text_utils.normalize_whitespace(""), "")
end)

-- ============================================================================
-- normalize_text (pipeline)
-- ============================================================================

test_utils.run_test("normalize_text: default options (BOM + line endings)", function()
    local bom = string.char(0xEF, 0xBB, 0xBF)
    local input = bom .. "a\r\nb"
    test_utils.assert_eq(text_utils.normalize_text(input), "a\nb")
end)

test_utils.run_test("normalize_text: with whitespace normalization", function()
    local result = text_utils.normalize_text("a  b", { normalize_whitespace = true })
    test_utils.assert_eq(result, "a b")
end)

test_utils.run_test("normalize_text: disable BOM removal", function()
    local bom = string.char(0xEF, 0xBB, 0xBF)
    local input = bom .. "hello"
    local result = text_utils.normalize_text(input, { remove_bom = false })
    test_utils.assert_eq(result, input)
end)

test_utils.run_test("normalize_text: nil returns nil", function()
    test_utils.assert_nil(text_utils.normalize_text(nil))
end)

-- ============================================================================
-- normalize_for_typesetting
-- ============================================================================

test_utils.run_test("normalize_for_typesetting: removes BOM and normalizes line endings", function()
    local bom = string.char(0xEF, 0xBB, 0xBF)
    local input = bom .. "a\r\nb"
    test_utils.assert_eq(text_utils.normalize_for_typesetting(input), "a\nb")
end)

test_utils.run_test("normalize_for_typesetting: preserves whitespace", function()
    local result = text_utils.normalize_for_typesetting("a  b")
    test_utils.assert_eq(result, "a  b")
end)

print("\nAll util/text-utils-test tests passed!")
