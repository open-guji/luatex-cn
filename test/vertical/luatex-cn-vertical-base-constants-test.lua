-- luatex-cn-vertical-base-constants-test.lua - Unit tests for base constants
local test_utils = require('test.test_utils')
local constants = require('tex.vertical.luatex-cn-vertical-base-constants')

test_utils.run_test("base-constants - Export Check", function()
    test_utils.assert_eq(type(constants.D), "table", "constants.D missing")
    test_utils.assert_eq(type(constants.NODE_IDS), "table", "constants.NODE_IDS missing")
    test_utils.assert_eq(type(constants.to_dimen), "function", "constants.to_dimen missing")
end)

test_utils.run_test("base-constants - to_dimen", function()
    -- 10pt = 655360 sp
    test_utils.assert_eq(constants.to_dimen("10pt"), 655360, "10pt to_dimen failure")
    test_utils.assert_eq(constants.to_dimen(655360), 655360, "number to_dimen failure")
    test_utils.assert_eq(constants.to_dimen(nil), nil, "nil to_dimen failure")
    test_utils.assert_eq(constants.to_dimen(""), nil, "empty string to_dimen failure")
end)

test_utils.run_test("base-constants - Node IDs", function()
    -- Common node types
    test_utils.assert_eq(constants.GLYPH, 1, "constants.GLYPH mismatch")
    test_utils.assert_eq(constants.HLIST, 1, "constants.HLIST mismatch") -- Mock is simplified
    test_utils.assert_eq(constants.VLIST, 1, "constants.VLIST mismatch")
    test_utils.assert_eq(constants.KERN, 1, "constants.KERN mismatch")
end)

print("\nAll base-constants tests passed!")
