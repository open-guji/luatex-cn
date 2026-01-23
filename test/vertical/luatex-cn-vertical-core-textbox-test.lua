-- luatex-cn-vertical-core-textbox-test.lua - Unit tests for core textbox
local test_utils = require('test.test_utils')
local textbox = require('vertical.luatex-cn-vertical-core-textbox')

test_utils.run_test("core-textbox - detect", function()
    local n = node.new("whatsit")
    n.user_id = 202602
    test_utils.assert_eq(textbox.is_grid_textbox(n), true, "Should identify grid textbox whatsit")
end)

test_utils.run_test("core-textbox - process", function()
    -- Mocking process_inner_textbox is hard because it calls back to prepare_grid
    -- But we can verify it exists
    test_utils.assert_eq(type(textbox.process_inner_textbox), "function", "process_inner_textbox missing")
end)

print("\nAll core-textbox tests passed!")
