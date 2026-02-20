-- Unit tests for decorate.luatex-cn-decorate
local test_utils = require("test.test_utils")
local decorate = require("decorate.luatex-cn-decorate")

-- ============================================================================
-- register / get / clear_registry
-- ============================================================================

test_utils.run_test("register: returns incrementing IDs", function()
    decorate.clear_registry()
    local id1 = decorate.register("●", "0pt", "0pt", nil, nil, nil, nil)
    local id2 = decorate.register("○", "0pt", "0pt", nil, nil, nil, nil)
    test_utils.assert_type(id1, "number")
    test_utils.assert_type(id2, "number")
    test_utils.assert_true(id2 > id1)
end)

test_utils.run_test("get: retrieves registered decoration", function()
    decorate.clear_registry()
    local id = decorate.register("●", "1pt", "2pt", nil, "red", nil, nil)
    local reg = decorate.get(id)
    test_utils.assert_type(reg, "table")
    -- register_decorate stores char as codepoint number, not the original string
    test_utils.assert_eq(reg.char, utf8.codepoint("●", 1))
    test_utils.assert_eq(reg.color, "red")
end)

test_utils.run_test("get: nil for invalid ID", function()
    decorate.clear_registry()
    test_utils.assert_nil(decorate.get(999))
end)

test_utils.run_test("clear_registry: clears all entries", function()
    decorate.clear_registry()
    local id = decorate.register("●", "0pt", "0pt", nil, nil, nil, nil)
    test_utils.assert_true(decorate.get(id) ~= nil)
    decorate.clear_registry()
    test_utils.assert_nil(decorate.get(id))
end)

print("\nAll decorate/decorate-test tests passed!")
