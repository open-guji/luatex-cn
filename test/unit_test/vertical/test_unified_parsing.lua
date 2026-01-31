-- Unit test for unified color and dimension parsing
local test_utils = require("test.test_utils")

-- Load modules
local utils = require("luatex-cn-utils")
local constants = require("luatex-cn-constants")

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
    local em = constants.to_dimen("1em")
    test_utils.assert_eq(type(em), "table")
    if type(em) == "table" then
        test_utils.assert_eq(em.value, 1)
        test_utils.assert_eq(em.unit, "em")
    end
end)

test_utils.run_test("resolve_dimen (em)", function()
    -- Mock em is 10pt (655360 sp)
    test_utils.assert_eq(constants.resolve_dimen("1em", 655360), 655360)
    test_utils.assert_eq(constants.resolve_dimen("1.5em", 655360), 1.5 * 655360)
end)

test_utils.run_test("to_dimen unit-less (sp)", function()
    -- unit-less numbers in to_dimen are treated as raw sp
    test_utils.assert_eq(constants.to_dimen("65536"), 65536)
end)

test_utils.run_test("to_dimen TeX artifacts", function()
    test_utils.assert_eq(constants.to_dimen("{10pt}"), 655360)
    local em5 = constants.to_dimen("{{5em}}")
    if type(em5) == "table" then
        test_utils.assert_eq(em5.value, 5)
        test_utils.assert_eq(em5.unit, "em")
    end
end)

print("\nAll parsing tests passed!")
