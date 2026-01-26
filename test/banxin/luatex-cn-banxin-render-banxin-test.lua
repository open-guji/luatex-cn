-- luatex-cn-banxin-render-banxin.lua - Unit tests for banxin rendering
local test_utils = require('test.test_utils')
local banxin = require('banxin.luatex-cn-banxin-render-banxin')
local render_pos = require('vertical.luatex-cn-vertical-render-position')

-- Mock create_vertical_text to return exactly 1 node for testing node counts
render_pos.create_vertical_text = function(text, params)
    return node.new(1, 1) -- Single node
end

test_utils.run_test("draw_banxin - Ratio Calculations", function()
    local params = {
        total_height = 100 * 65536,
        upper_ratio = 0.3,
        middle_ratio = 0.5,
        color_str = "0 1 0"
    }
    local result = banxin.draw_banxin(params)

    -- upper_height should be 30pt (30 * 65536)
    test_utils.assert_eq(result.upper_height, 30 * 65536, "Upper height mismatch")

    -- literals count
    -- 2 dividers + 1 upper_yuwei (default) + 1 lower_yuwei (default) = 4
    test_utils.assert_eq(#result.literals, 4, "Literals count mismatch")

    -- Check divider Y coordinates
    -- total_height = 100
    -- div1_y = y - 30 = -30
    -- div2_y = -30 - 50 = -80
    local div1_found = false
    local div2_found = false
    for _, lit in ipairs(result.literals) do
        if string.find(lit, "%-29%.%d+ m") then div1_found = true end
        if string.find(lit, "%-79%.%d+ m") then div2_found = true end
    end
    test_utils.assert_eq(div1_found, true, "Divider 1 not found or wrong Y")
    test_utils.assert_eq(div2_found, true, "Divider 2 not found or wrong Y")
end)

test_utils.run_test("draw_banxin_column - Node Insertion", function()
    local p_head = { id = 1, next = nil }
    local params = {
        x = 0,
        y = 0,
        width = 20 * 65536,
        height = 100 * 65536,
        draw_border = true,
        border_thickness = 1 / 2 * 65536,
        book_name = "TestBook"
    }

    local new_head = banxin.draw_banxin_column(p_head, params)

    -- Count nodes inserted before p_head
    -- 1 border + 2 dividers + 2 yuwei + 1 book_name (mocked as 1 node) = 6
    local count = 0
    local curr = new_head
    while curr and curr ~= p_head do
        count = count + 1
        curr = curr.next
    end

    test_utils.assert_eq(count, 6, "Inserted nodes count mismatch")
end)

test_utils.run_test("draw_banxin_column - Alignment Options", function()
    local p_head = { id = 1, next = nil }
    local params = {
        x = 0,
        y = 0,
        width = 20 * 65536,
        height = 100 * 65536,
        border_thickness = 0.4 * 65536,
        book_name = "AlignTest",
        book_name_align = "top"
    }

    -- Just verify it runs without error with alignment params
    local ok, err = pcall(function()
        banxin.draw_banxin_column(p_head, params)
    end)
    test_utils.assert_eq(ok, true, "Should handle book_name_align='top': " .. tostring(err))
end)

print("\nAll render-banxin tests passed!")
