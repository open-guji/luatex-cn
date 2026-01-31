---@diagnostic disable: lowercase-global
-- test_utils.lua - Simple testing utilities for LuaTeX-CN tests

local test_utils = {}

-- Add src to package.path
-- We'll try to find the project root by looking for build.lua
local function get_project_root()
    -- Try current directory first
    local fh = io.open("build.lua", "r")
    if fh then
        fh:close()
        return "./"
    end
    -- Try parent directory
    fh = io.open("../build.lua", "r")
    if fh then
        fh:close()
        return "../"
    end
    -- Try grandparent directory (common for test/banxin/...)
    fh = io.open("../../build.lua", "r")
    if fh then
        fh:close()
        return "../../"
    end
    return ""
end

local root = get_project_root()
package.path = root .. "tex/?.lua;"
    .. root .. "tex/vertical/?.lua;"
    .. root .. "tex/banxin/?.lua;"
    .. root .. "tex/fonts/?.lua;"
    .. root .. "tex/splitpage/?.lua;"
    .. root .. "tex/core/?.lua;"
    .. root .. "tex/util/?.lua;"
    .. root .. "tex/?/init.lua;"
    .. package.path

-- Mock TeX/LuaTeX globals (Force override to avoid native object conflicts)
local node_id_map = {
    hlist = 0,
    vlist = 1,
    rule = 2,
    ins = 3,
    mark = 4,
    adjust = 5,
    boundary = 6,
    disc = 7,
    whatsit = 8,
    local_par = 9,
    dir = 10,
    glyph = 29,
    glue = 12,
    kern = 13,
    penalty = 14,
    unset = 15,
}

node = {
    id = function(name) return node_id_map[name] or 99 end,
    subtype = function(name) return 1 end,
    new = function(id, subtype)
        if type(id) == "string" then id = node_id_map[id] or 99 end
        if type(subtype) == "string" then subtype = 0 end
        return {
            id = id,
            subtype = subtype or 0,
            next = nil,
            width = 0,
            height = 0,
            depth = 0,
            xoffset = 0,
            yoffset = 0,
            char = 0,
            font = 0,
            kern = 0,
            attributes = {}
        }
    end,
    copy_list = function(n)
        if not n then return nil end
        -- Shallow copy is enough for mock logic
        local new_head = node.new(n.id, n.subtype)
        local curr = n.next
        local tail = new_head
        while curr do
            local next_n = node.new(curr.id, curr.subtype)
            tail.next = next_n
            tail = next_n
            curr = curr.next
        end
        return new_head
    end,
    flush_node = function(n) end,
    flush_list = function(n) end,
    write = function(n) end,
    set_attribute = function(n, id, val)
        if type(n) == "table" then
            if not n.attributes then n.attributes = {} end
            n.attributes[id] = val
        end
    end,
    get_attribute = function(n, id)
        if type(n) == "table" and n.attributes then return n.attributes[id] end
        return nil
    end,
    setfield = function(n, f, v) if type(n) == "table" then n[f] = v end end,
    getfield = function(n, f)
        if type(n) == "table" then return n[f] end
        return nil
    end,
    direct = {
        new = function(id, subtype)
            local n = { id = id, subtype = subtype, next = nil, attributes = {} }
            return n
        end,
        setfield = function(n, f, v) if type(n) == "table" then n[f] = v end end,
        getfield = function(n, f)
            if type(n) == "table" then return n[f] end
            return nil
        end,
        getid = function(n)
            if type(n) == "table" then return n.id end
            return nil
        end,
        get_attribute = function(n, id)
            if type(n) == "table" and n.attributes then return n.attributes[id] end
            return nil
        end,
        set_attribute = function(n, id, val)
            if type(n) == "table" then
                if not n.attributes then n.attributes = {} end
                n.attributes[id] = val
            end
        end,
        has_attribute = function(n, id)
            if type(n) == "table" and n.attributes then return n.attributes[id] ~= nil end
            return false
        end,
        getattr = function(n, id)
            if type(n) == "table" and n.attributes then return n.attributes[id] end
            return nil
        end,
        setattr = function(n, id, val)
            if type(n) == "table" then
                if not n.attributes then n.attributes = {} end
                n.attributes[id] = val
            end
        end,
        insert_before = function(head, anchor, n)
            if not n then return head end
            n.next = anchor
            return n
        end,
        insert_after = function(head, anchor, n)
            if not n then return head end
            if anchor then
                n.next = anchor.next
                anchor.next = n
            end
            return head
        end,
        remove = function(head, n)
            if head == n then return n.next end
            local curr = head
            while curr and curr.next ~= n do curr = curr.next end
            if curr then curr.next = n.next end
            return head
        end,
        copy = function(n)
            if not n then return nil end
            local new_n = {}
            for k, v in pairs(n) do
                if k == "attributes" then
                    new_n.attributes = {}
                    for ak, av in pairs(v) do new_n.attributes[ak] = av end
                elseif k ~= "next" and k ~= "prev" then
                    new_n[k] = v
                end
            end
            return new_n
        end,
        getsubtype = function(n)
            if type(n) == "table" then return n.subtype or 0 end
            return 0
        end,
        todirect = function(n) return n end,
        tonode = function(n) return n end,
        setlink = function(...)
            local arg = { ... }
            for i = 1, #arg - 1 do
                if type(arg[i]) == "table" then arg[i].next = arg[i + 1] end
                if type(arg[i + 1]) == "table" then arg[i + 1].prev = arg[i] end
            end
        end,
        getnext = function(n)
            if type(n) == "table" then return n.next end
            return nil
        end,
        setnext = function(n, next_node)
            if type(n) == "table" then n.next = next_node end
        end,
        getprev = function(n)
            if type(n) == "table" then return n.prev end
            return nil
        end,
        setprev = function(n, prev_node)
            if type(n) == "table" then n.prev = prev_node end
        end,
        getlink = function(n)
            if type(n) == "table" then return n.prev, n.next end
            return nil, nil
        end,
    }
}

texio = {
    write_nl = function(target, s)
        -- silence
    end
}

luatexbase = {
    attributes = {},
    new_attribute = function(name)
        return 100 -- dummy attribute id
    end
}

tex = {
    sp = function(s)
        if type(s) == "number" then return s end
        local num, unit = s:match("^([%d%.]+)(%a+)$")
        if not num then return 0 end
        num = tonumber(num)
        local factors = { pt = 65536, bp = 65781, mm = 186467, sp = 1, em = 655360 }
        return math.floor(num * (factors[unit] or 65536))
    end,
    current = function() return 0 end,
    box = {}
}

font = {
    current = function() return 0 end,
    getfont = function(id) return { size = 655360 } end,
    define = function(data) return 1 end
}

if not utf8 then
    utf8 = {
        codepoint = function(s)
            -- Simple UTF-8 to codepoint for common chars
            local b = string.byte(s, 1)
            if b < 128 then return b end
            -- Fallback
            return 65
        end,
        char = function(cp) return string.char(cp) end
    }
end

-- Simple assertion functions
function test_utils.assert_eq(actual, expected, message)
    if actual ~= expected then
        error(string.format("Assertion failed: expected '%s', got '%s'. %s",
            tostring(expected), tostring(actual), message or ""), 2)
    end
end

function test_utils.assert_match(actual, pattern, message)
    if not string.match(actual, pattern) then
        error(string.format("Assertion failed: '%s' does not match pattern '%s'. %s",
            tostring(actual), tostring(pattern), message or ""), 2)
    end
end

function test_utils.run_test(name, func)
    print(string.format("[TEST] Running: %s", name))
    local ok, err = pcall(func)
    if ok then
        print(string.format("[OK]   %s", name))
    else
        print(string.format("[FAIL] %s: %s", name, err))
        os.exit(1)
    end
end

return test_utils
