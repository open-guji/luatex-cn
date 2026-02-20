-- Unit tests for guji.luatex-cn-guji-danye
local test_utils = require("test.test_utils")
local danye = require("guji.luatex-cn-guji-danye")

-- ============================================================================
-- get_single_page_dims
-- ============================================================================

test_utils.run_test("get_single_page_dims: halves paper width", function()
    _G.page = {
        paper_width = 65536 * 200,  -- 200pt
        margin_left = 65536 * 20,   -- 20pt
        margin_right = 65536 * 30,  -- 30pt
    }
    local dims = danye.get_single_page_dims()
    test_utils.assert_eq(dims.paper_width, math.floor(65536 * 200 / 2))
    test_utils.assert_eq(dims.margin_left, math.floor(65536 * 20 / 2))
    test_utils.assert_eq(dims.margin_right, math.floor(65536 * 30 / 2))
end)

test_utils.run_test("get_single_page_dims: zero dimensions", function()
    _G.page = { paper_width = 0, margin_left = 0, margin_right = 0 }
    local dims = danye.get_single_page_dims()
    test_utils.assert_eq(dims.paper_width, 0)
end)

-- ============================================================================
-- String conversion functions
-- ============================================================================

test_utils.run_test("get_paper_width_str: returns pt string", function()
    _G.page = { paper_width = 65536 * 200, margin_left = 0, margin_right = 0 }
    local result = danye.get_paper_width_str()
    test_utils.assert_type(result, "string")
    test_utils.assert_match(result, "pt$")
end)

test_utils.run_test("get_margin_left_str: returns pt string", function()
    _G.page = { paper_width = 65536 * 200, margin_left = 65536 * 20, margin_right = 0 }
    local result = danye.get_margin_left_str()
    test_utils.assert_type(result, "string")
    test_utils.assert_match(result, "pt$")
end)

test_utils.run_test("get_margin_right_str: returns pt string", function()
    _G.page = { paper_width = 65536 * 200, margin_left = 0, margin_right = 65536 * 30 }
    local result = danye.get_margin_right_str()
    test_utils.assert_type(result, "string")
    test_utils.assert_match(result, "pt$")
end)

print("\nAll guji/danye-test tests passed!")
