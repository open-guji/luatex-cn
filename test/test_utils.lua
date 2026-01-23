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
    .. root .. "tex/?/init.lua;"
    .. package.path

-- Mock TeX/LuaTeX globals (Force override to avoid native object conflicts)
node = {
    id = function(name) return 1 end,
    subtype = function(name) return 1 end,
    new = function(id, subtype)
        if type(id) == "string" then id = 1 end
        if type(subtype) == "string" then subtype = 1 end
        return {
            id = id,
            subtype = subtype,
            next = nil,
            width = 0,
            height = 0,
            depth = 0,
            xoffset = 0,
            yoffset = 0,
            char = 0,
            font = 0,
            kern = 0
        }
    end,
    setfield = function(n, f, v) if type(n) == "table" then n[f] = v end end,
    getfield = function(n, f)
        if type(n) == "table" then return n[f] end
        return nil
    end,
    direct = {
        new = function(id, subtype)
            return { id = id, subtype = subtype, next = nil }
        end,
        setfield = function(n, f, v) if type(n) == "table" then n[f] = v end end,
        getfield = function(n, f)
            if type(n) == "table" then return n[f] end
            return nil
        end,
        insert_before = function(head, anchor, n)
            if not n then return head end
            n.next = anchor
            return n
        end,
        todirect = function(n) return n end,
        setlink = function(n, next_node) if type(n) == "table" then n.next = next_node end end,
        getnext = function(n)
            if type(n) == "table" then return n.next end
            return nil
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
        local factors = { pt = 65536, bp = 65781, mm = 186467, sp = 1 }
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
