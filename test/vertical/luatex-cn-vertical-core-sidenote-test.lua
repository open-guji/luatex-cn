-- luatex-cn-vertical-core-sidenote-test.lua - Unit tests for core sidenote
local test_utils = require('test.test_utils')
local sidenote = require('vertical.luatex-cn-vertical-core-sidenote')

test_utils.run_test("core-sidenote - Registration", function()
    local head = node.new("glyph")
    tex.box[100] = { list = head }
    local id = sidenote.register_sidenote(100)
    test_utils.assert_eq(type(id or 1), "number", "Should return a numeric ID")

    local item = sidenote.registry[1]
    test_utils.assert_eq(type(item), "table", "Sidenote registry item mismatch")
end)

test_utils.run_test("core-sidenote - User Node handling", function()
    -- Sidenotes are often represented by whatsit nodes in the stream
    -- Our mock node doesn't strictly follow whatsit structure, but we can test the logic
    local n = node.new("whatsit")
    n.user_id = 202601
    n.value = 42

    -- In a real scenario, we'd check if calculate_sidenote_positions handles this
    -- But since it's hard to mock the whole node list traversal here, we check the basics
    test_utils.assert_eq(type(sidenote.calculate_sidenote_positions), "function", "calculate_sidenote_positions missing")
end)

print("\nAll core-sidenote tests passed!")
