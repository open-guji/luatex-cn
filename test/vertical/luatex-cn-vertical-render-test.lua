-- luatex-cn-vertical-render-test.lua - Unit tests for vertical rendering modules
local test_utils = require('test.test_utils')
-- We need to mock constants for render-position
local constants = require('vertical.luatex-cn-vertical-base-constants')
local render_pos = require('vertical.luatex-cn-vertical-render-position')

test_utils.run_test("render-position - create_vertical_text", function()
    local text = "测试"
    local params = {
        x = 0,
        y_top = 0,
        width = 20 * 65536,
        height = 40 * 65536,
        font_size = 20 * 65536,
        num_cells = 2
    }
    
    -- Mock the actual node creation since we are in texlua
    -- The real function uses node.new("glyph", ...)
    -- Our test_utils already mocks node.new
    
    local head = render_pos.create_vertical_text(text, params)
    test_utils.assert_eq(type(head), "table", "Should return a node (mocked as table)")
    
    -- In our mock, create_vertical_text returns a single node.
    -- In the real implementation, it returns a chain.
    -- Since we mocked create_vertical_text in test_utils.lua for banxin tests,
    -- but here we are using the REAL render_pos.lua (loaded via require),
    -- it will use the node.new mock from test_utils.
    
    -- Let's verify if nodes were created
    test_utils.assert_eq(head.id, 1, "Mocked node id mismatch")
end)

print("\nAll vertical-render tests passed!")
