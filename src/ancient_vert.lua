-- ancient_vert.lua
local D = node.direct
local node_id = node.id
local GLYPH = node_id("glyph")

-- 定义一个命名空间
AncientBook = AncientBook or {}
AncientBook.line_limit = 10 -- 默认值

function AncientBook.layout(head)
    local curr = D.todirect(head)
    local char_size = 655360 * 1.4 -- 字号 + 行距
    
    local count = 0
    while curr do
        if D.getid(curr) == GLYPH then
            -- 从全局变量读取最新的行格高度
            local limit = AncientBook.line_limit
            
            local row = count % limit
            local col = math.floor(count / limit)
            
            D.setfield(curr, "xoffset", -col * char_size)
            D.setfield(curr, "yoffset", -row * char_size)
            D.setfield(curr, "width", 0)
            
            count = count + 1
        end
        curr = D.getnext(curr)
    end
    return D.tonode(head)
end

luatexbase.add_to_callback("pre_linebreak_filter", AncientBook.layout, "AncientVerticalV3")