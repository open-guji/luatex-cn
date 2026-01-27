-- Unit test for unified color and dimension parsing
local test_utils = require("test.test_utils")

-- Load modules
local utils = require("vertical.luatex-cn-vertical-base-utils")
local constants = require("vertical.luatex-cn-vertical-base-constants")

-- Test normalize_rgb
test_utils.run_test("normalize_rgb basic names", function()
    test_utils.assert_eq(utils.normalize_rgb("red"), "1.0000 0.0000 0.0000")
    test_utils.assert_eq(utils.normalize_rgb("  BLUE  "), "0.0000 0.0000 1.0000")
end)

test_utils.run_test("normalize_rgb numeric formats", function()
    test_utils.assert_eq(utils.normalize_rgb("0.1, 0.2, 0.3"), "0.1000 0.2000 0.3000")
    test_utils.assert_eq(utils.normalize_rgb("0.1 0.2 0.3"), "0.1000 0.2000 0.3000")
    test_utils.assert_eq(utils.normalize_rgb("122, 233, 255"), "0.4784 0.9137 1.0000")
    test_utils.assert_eq(utils.normalize_rgb("(122, 233, 255)"), "0.4784 0.9137 1.0000")
end)

test_utils.run_test("normalize_rgb prefixes", function()
    test_utils.assert_eq(utils.normalize_rgb("rgb:(0.1, 0.2, 0.3)"), "0.1000 0.2000 0.3000")
    test_utils.assert_eq(utils.normalize_rgb("RGB:(255, 255, 255)"), "1.0000 1.0000 1.0000")
    test_utils.assert_eq(utils.normalize_rgb("color: 0.5 0.5 0.5"), "0.5000 0.5000 0.5000")
end)

test_utils.run_test("normalize_rgb TeX artifacts", function()
    test_utils.assert_eq(utils.normalize_rgb("{0.1 0.2 0.3}"), "0.1000 0.2000 0.3000")
    test_utils.assert_eq(utils.normalize_rgb("[0.1, 0.2, 0.3]"), "0.1000 0.2000 0.3000")
end)

-- Test to_dimen
test_utils.run_test("to_dimen with units", function()
    test_utils.assert_eq(constants.to_dimen("10pt"), 655360)
    test_utils.assert_eq(constants.to_dimen("1em"), 655360) -- Mock em is 10pt
end)

test_utils.run_test("to_dimen unit-less (em)", function()
    test_utils.assert_eq(constants.to_dimen("5"), 5 * 655360) -- 5em (mock em is 10pt)
    test_utils.assert_eq(constants.to_dimen("1.5"), 1.5 * 655360)
end)

test_utils.run_test("to_dimen TeX artifacts", function()
    test_utils.assert_eq(constants.to_dimen("{10pt}"), 655360)
    test_utils.assert_eq(constants.to_dimen("{{5}}"), 5 * 655360) -- 5em
end)

print("\nAll parsing tests passed!")
