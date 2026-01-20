-- luatex-cn-splitpage-test.lua - Unit tests for splitpage module
local test_utils = require('test.test_utils')
local splitpage = require('splitpage.luatex-cn-splitpage')

test_utils.run_test("splitpage - Internal to_sp (via configure)", function()
    -- Reset state
    splitpage.source_width = 0
    splitpage.source_height = 0
    
    -- Test mm
    splitpage.configure({ source_width = "100mm", source_height = "200mm" })
    -- 1mm = 65536 * 72.27 / 25.4 sp
    local expected_w = math.floor(100 * 65536 * 72.27 / 25.4)
    test_utils.assert_eq(splitpage.source_width, expected_w, "mm conversion failure")
    test_utils.assert_eq(splitpage.target_width, math.floor(expected_w / 2), "half-width calculation failure")
    
    -- Test cm
    splitpage.configure({ source_width = "10cm" })
    local expected_cm = math.floor(10 * 65536 * 72.27 / 2.54)
    test_utils.assert_eq(splitpage.source_width, expected_cm, "cm conversion failure")
    
    -- Test pt
    splitpage.configure({ source_width = "72.27pt" })
    test_utils.assert_eq(splitpage.source_width, math.floor(72.27 * 65536), "pt conversion failure")
end)

test_utils.run_test("splitpage - enable/disable", function()
    splitpage.configure({ source_width = "100mm", source_height = "100mm" })
    
    splitpage.enable()
    test_utils.assert_eq(splitpage.is_enabled(), true, "Enable failed")
    
    splitpage.disable()
    test_utils.assert_eq(splitpage.is_enabled(), false, "Disable failed")
end)

test_utils.run_test("splitpage - is_right_page logic", function()
    -- Scenario 1: right_first = true (default)
    -- Odd pages (1, 3, ...) are Right
    -- Even pages (2, 4, ...) are Left
    splitpage.configure({ right_first = true })
    test_utils.assert_eq(splitpage.is_right_page(1), true, "Page 1 should be Right (right_first=true)")
    test_utils.assert_eq(splitpage.is_right_page(2), false, "Page 2 should be Left (right_first=true)")
    
    -- Scenario 2: right_first = false (left_first)
    -- Odd pages (1, 3, ...) are Left
    -- Even pages (2, 4, ...) are Right
    splitpage.configure({ right_first = false })
    test_utils.assert_eq(splitpage.is_right_page(1), false, "Page 1 should be Left (right_first=false)")
    test_utils.assert_eq(splitpage.is_right_page(2), true, "Page 2 should be Right (right_first=false)")
end)

test_utils.run_test("splitpage - get dimensions", function()
    splitpage.configure({ source_width = "200bp", source_height = "300bp" })
    
    local bp_factor = 65536 * 72.27 / 72
    test_utils.assert_eq(splitpage.get_source_width(), math.floor(200 * bp_factor), "get_source_width failed")
    test_utils.assert_eq(splitpage.get_target_width(), math.floor(100 * bp_factor), "get_target_width failed")
end)

print("\nAll splitpage tests passed!")
