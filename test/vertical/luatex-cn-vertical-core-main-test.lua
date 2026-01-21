-- luatex-cn-vertical-core-main-test.lua - Unit tests for vertical core main
local test_utils = require('test.test_utils')
local constants = require('tex.vertical.luatex-cn-vertical-base-constants')

-- Mock submodules that main requires
package.loaded['luatex-cn-vertical-flatten-nodes'] = {
    flatten_nodes = function(head, params) return head, {} end
}
package.loaded['luatex-cn-vertical-layout-grid'] = {
    calculate_grid_positions = function(head, params) return head, { [1] = { page = 1, col = 0, row = 0 } }, 1 end
}
package.loaded['luatex-cn-vertical-render-page'] = {
    apply_positions = function(head, map, params) return { { head = head, cols = 1 } } end
}

local main = require('tex.vertical.luatex-cn-vertical-core-main')

test_utils.run_test("core-main - prepare_grid", function()
    -- Setup mock box
    local head = node.new("glyph")
    tex.box[255] = { list = head }

    local params = {
        grid_width = "20pt",
        grid_height = "20pt",
        n_column = 8
    }

    local page_count = main.prepare_grid(255, params)
    test_utils.assert_eq(page_count, 1, "Should generate 1 page")
    test_utils.assert_eq(#_G.vertical_pending_pages, 1, "Should have 1 pending page")
end)

print("\nAll core-main tests passed!")
