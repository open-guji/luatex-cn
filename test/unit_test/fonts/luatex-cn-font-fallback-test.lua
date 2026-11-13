---@diagnostic disable: duplicate-set-field
-- Unit tests for fonts.luatex-cn-font-fallback（issue #197：按需加载的回退链）
local test_utils = require('test.test_utils')
local fb = require('tex.fonts.luatex-cn-font-fallback')

-- ----------------------------------------------------------------------------
-- 模拟 luaotfload 字体环境：
--   主字体 id 1（10pt）、2（12pt）挂链 "chain"；id 3 不挂链
--   回退字体 A 只有 U+20000，B 有 U+20000 与 U+30000
-- ----------------------------------------------------------------------------
local function setup()
    fb._internal.reset()
    local env = { loads = {}, next_id = 100 }
    local ids = {
        [1] = { size = 10, characters = { [0x5929] = {} }, luatexcn_fallback = "chain" },
        [2] = { size = 12, characters = { [0x5929] = {} }, shared = { features = { luatexcnfallback = "CHAIN" } } },
        [3] = { size = 10, characters = { [0x5929] = {} } },
    }
    local covers = {
        A = { [0x20000] = {} },
        B = { [0x20000] = {}, [0x30000] = {} },
    }
    env.ids = ids
    env.covers = covers
    fb._internal.get_fontdata = function(fid) return ids[fid] end
    fb._internal.load_font = function(spec, size)
        table.insert(env.loads, spec .. "@" .. size)
        if spec == "Missing" then return nil end
        env.next_id = env.next_id + 1
        ids[env.next_id] = { size = size, characters = covers[spec] }
        return env.next_id, covers[spec]
    end
    fb.register("chain", { "A", "B" })
    return env
end

test_utils.run_test("fallback: no fallback font is loaded while main font covers text", function()
    local env = setup()
    local m = fb._internal.map_for(1)
    test_utils.assert_eq(m[0x5929], false)
    test_utils.assert_eq(#env.loads, 0)
end)

test_utils.run_test("fallback: missing char loads only the first covering font", function()
    local env = setup()
    local m = fb._internal.map_for(1)
    local fid = m[0x20000]
    test_utils.assert_eq(env.ids[fid].characters, env.covers.A)
    -- 只载了 A；B 没有被碰
    test_utils.assert_eq(#env.loads, 1)
    test_utils.assert_eq(env.loads[1], "A@10")
end)

test_utils.run_test("fallback: walks chain to later font", function()
    local env = setup()
    local m = fb._internal.map_for(1)
    local fid = m[0x30000]
    test_utils.assert_eq(env.ids[fid].size, 10)
    test_utils.assert_eq(env.loads[1], "A@10")
    test_utils.assert_eq(env.loads[2], "B@10")
    -- 再查一次走缓存
    test_utils.assert_eq(m[0x30000], fid)
    test_utils.assert_eq(#env.loads, 2)
end)

test_utils.run_test("fallback: new size reloads only the font actually needed", function()
    local env = setup()
    local _ = fb._internal.map_for(1)[0x30000]   -- A@10, B@10（学到 A 不含 U+30000）
    local fid = fb._internal.map_for(2)[0x30000]
    test_utils.assert_eq(env.ids[fid].size, 12)
    -- 12pt 下只载 B：A 的覆盖范围已知，不需要再按 12pt 载一遍
    test_utils.assert_eq(#env.loads, 3)
    test_utils.assert_eq(env.loads[3], "B@12")
end)

test_utils.run_test("fallback: unmapped char in no font stays on main font", function()
    local env = setup()
    test_utils.assert_eq(fb._internal.map_for(1)[0x40000], false)
    test_utils.assert_eq(#env.loads, 2)
end)

test_utils.run_test("fallback: font without chain is ignored", function()
    local env = setup()
    test_utils.assert_eq(fb._internal.map_for(3), false)
    test_utils.assert_eq(#env.loads, 0)
end)

test_utils.run_test("fallback: unloadable font is skipped", function()
    local env = setup()
    fb.register("chain", { "Missing", "B" })
    local fid = fb._internal.map_for(1)[0x20000]
    test_utils.assert_eq(env.ids[fid].characters, env.covers.B)
    test_utils.assert_eq(env.loads[1], "Missing@10")
    -- 失败的那支不会每次重试
    local _ = fb._internal.map_for(1)[0x30000]
    local n = 0
    for _, l in ipairs(env.loads) do if l == "Missing@10" then n = n + 1 end end
    test_utils.assert_eq(n, 1)
end)

test_utils.run_test("fallback: process re-fonts glyphs missing from main font", function()
    local env = setup()
    local glyphs = {
        { char = 0x5929, font = 1 },
        { char = 0x20000, font = 1 },
        { char = 0x20000, font = 3 },
    }
    local org_direct = node.direct
    node.direct = {
        todirect = function(n) return n end,
        setfont = function(n, f) n.font = f end,
        traverse_char = function(list)
            local i = 0
            return function()
                i = i + 1
                local g = list[i]
                if g then return g, g.char, g.font end
            end
        end,
    }
    local ok, err = pcall(function()
        test_utils.assert_eq(fb.process(glyphs), true)
    end)
    node.direct = org_direct
    if not ok then error(err, 0) end
    test_utils.assert_eq(glyphs[1].font, 1)
    test_utils.assert_eq(env.ids[glyphs[2].font].characters, env.covers.A)
    test_utils.assert_eq(glyphs[3].font, 3)
end)

print("\nAll font-fallback tests passed!")
