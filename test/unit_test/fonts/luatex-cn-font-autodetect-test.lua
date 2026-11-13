---@diagnostic disable: duplicate-set-field
-- Unit tests for fonts.luatex-cn-font-autodetect
local test_utils = require('test.test_utils')

-- Adjust require path: module lives in tex/fonts/ but package path uses tex/ prefix
local fontdetect = require('tex.fonts.luatex-cn-font-autodetect')

-- Save originals
local org_os_name = os.name
local org_pkg_config = package.config
local org_io_popen = io.popen

-- ============================================================================
-- detect_os
-- ============================================================================

test_utils.run_test("detect_os: Windows via os.name", function()
    os.name = "windows"
    test_utils.assert_eq(fontdetect.detect_os(), "windows")
    os.name = org_os_name
end)

test_utils.run_test("detect_os: Mac via os.name", function()
    os.name = "macosx"
    test_utils.assert_eq(fontdetect.detect_os(), "mac")
    os.name = org_os_name
end)

test_utils.run_test("detect_os: linux via os.name", function()
    os.name = "linux"
    test_utils.assert_eq(fontdetect.detect_os(), "linux")
    os.name = org_os_name
end)

test_utils.run_test("detect_os: unknown", function()
    os.name = "0xdeadbeaf"
    test_utils.assert_eq(fontdetect.detect_os(), "common")
    os.name = org_os_name
end)

test_utils.run_test("detect_os: nil", function()
    os.name = nil
    test_utils.assert_eq(fontdetect.detect_os(), "common")
    os.name = org_os_name
end)

-- ============================================================================
-- auto_select_scheme
-- ============================================================================

test_utils.run_test("auto_select_scheme: returns table with name", function()
    local org_detect = fontdetect.detect_os
    fontdetect.detect_os = function() return "windows" end

    local scheme = fontdetect.auto_select_scheme()
    test_utils.assert_type(scheme, "table")
    test_utils.assert_eq(scheme.name, "windows")
    test_utils.assert_type(scheme.fonts, "table")
    test_utils.assert_type(scheme.fonts.main, "table")

    fontdetect.detect_os = org_detect
end)

test_utils.run_test("auto_select_scheme: mac scheme", function()
    local org_detect = fontdetect.detect_os
    fontdetect.detect_os = function() return "mac" end

    local scheme = fontdetect.auto_select_scheme()
    test_utils.assert_eq(scheme.name, "mac")

    fontdetect.detect_os = org_detect
end)

test_utils.run_test("auto_select_scheme: linux uses open-license linux scheme", function()
    local org_detect = fontdetect.detect_os
    fontdetect.detect_os = function() return "linux" end

    local scheme = fontdetect.auto_select_scheme()
    test_utils.assert_eq(scheme.name, "linux")

    fontdetect.detect_os = org_detect
end)

-- ============================================================================
-- get_font_setup
-- ============================================================================

test_utils.run_test("get_font_setup: returns resolved table", function()
    local org_detect = fontdetect.detect_os
    fontdetect.detect_os = function() return "windows" end

    local setup = fontdetect.get_font_setup()
    test_utils.assert_type(setup, "table")
    test_utils.assert_eq(setup.scheme, "windows")
    test_utils.assert_type(setup.main, "string")
    test_utils.assert_type(setup.sans, "string")
    test_utils.assert_type(setup.features, "string")
    -- main should contain comma-separated primary font names
    test_utils.assert_match(setup.main, "SimSun")
    test_utils.assert_match(setup.features, "vrt2")

    fontdetect.detect_os = org_detect
end)

-- ============================================================================
-- schemes data
-- ============================================================================

test_utils.run_test("schemes: all platforms have required font categories", function()
    for name, scheme in pairs(fontdetect.schemes) do
        test_utils.assert_type(scheme.fonts.main, "table", name .. " missing main")
        test_utils.assert_type(scheme.fonts.sans, "table", name .. " missing sans")
        test_utils.assert_type(scheme.fonts.kai, "table", name .. " missing kai")
        test_utils.assert_type(scheme.fonts.fangsong, "table", name .. " missing fangsong")
        test_utils.assert_type(scheme.features, "string", name .. " missing features")
    end
end)

-- ============================================================================
-- add_family_fallback（\设置字体族 的回退链）
-- ============================================================================

test_utils.run_test("add_family_fallback: skips first font, registers rest", function()
    local captured = {}
    _G.luaotfload = _G.luaotfload or {}
    local org = luaotfload.add_fallback
    luaotfload.add_fallback = function(id, entries)
        captured.id, captured.entries = id, entries
    end

    local entries = fontdetect.add_family_fallback(
        "famfbtest", "Source Han Serif SC, TW-Kai , TW-Kai-Ext-B")
    test_utils.assert_eq(#entries, 2)
    test_utils.assert_eq(entries[1], "name:TW-Kai:mode=node;")
    test_utils.assert_eq(entries[2], "name:TW-Kai-Ext-B:mode=node;")
    test_utils.assert_eq(captured.id, "famfbtest")

    luaotfload.add_fallback = org
end)

test_utils.run_test("add_family_fallback: single font registers nothing", function()
    local called = false
    _G.luaotfload = _G.luaotfload or {}
    local org = luaotfload.add_fallback
    luaotfload.add_fallback = function() called = true end
    local entries = fontdetect.add_family_fallback("famfbsingle", "Source Han Serif SC")
    test_utils.assert_eq(#entries, 0)
    test_utils.assert_eq(called, false)
    luaotfload.add_fallback = org
end)

-- ============================================================================
-- registry / find_font_file / prepare_family（字体族别名与免安装字体解析）
-- ============================================================================

test_utils.run_test("registry: consistent with font-manifest.json aliases", function()
    local f = assert(io.open("scripts/font-manifest.json", "rb"))
    local manifest = f:read("*a")
    f:close()
    local block = manifest:match('"aliases"%s*:%s*(%b{})')
    test_utils.assert_type(block, "string", "manifest missing aliases block")

    local manifest_files = 0
    for _ in block:gmatch('%.tt[fc]"') do manifest_files = manifest_files + 1 end
    local registry_files = 0
    for alias, def in pairs(fontdetect.registry) do
        assert(block:find('"' .. alias .. '"', 1, true),
            "manifest aliases 缺少别名 " .. alias)
        for _, m in ipairs(def.members) do
            registry_files = registry_files + 1
            assert(block:find('"' .. m.file .. '"', 1, true),
                "manifest aliases 缺少文件 " .. m.file)
        end
    end
    test_utils.assert_eq(manifest_files, registry_files,
        "manifest 与 registry 的成员文件数不一致")
end)

test_utils.run_test("find_font_file: checks ./fonts/ then ./", function()
    local org = fontdetect._internal.file_exists
    fontdetect._internal.file_exists = function(p) return p == "./fonts/Jigmo2.ttf" end
    test_utils.assert_eq(fontdetect.find_font_file("Jigmo2.ttf"), "./fonts/Jigmo2.ttf")

    fontdetect._internal.file_exists = function(p) return p == "./Jigmo2.ttf" end
    test_utils.assert_eq(fontdetect.find_font_file("Jigmo2.ttf"), "./Jigmo2.ttf")

    fontdetect._internal.file_exists = function() return false end
    test_utils.assert_eq(fontdetect.find_font_file("Jigmo2.ttf"), nil)
    fontdetect._internal.file_exists = org
end)

local function with_family_mocks(opts, body)
    -- 统一装拆 prepare_family 依赖的 mock，返回捕获的 macros / fallback entries
    local org_name_lookup = fontdetect._internal.name_lookup
    local org_exists = fontdetect._internal.file_exists
    _G.luaotfload = _G.luaotfload or {}
    local org_fb = luaotfload.add_fallback
    local org_set_macro = token.set_macro
    local org_lazy = fontdetect._internal.lazy_fallback
    local captured = { macros = {}, fb = nil, lazy = nil }
    -- 默认模拟「按需回退不可用」，走 luaotfload 原生 fallback；opts.lazy=true 时模拟可用
    fontdetect._internal.lazy_fallback = function()
        return {
            FEATURE = "luatexcnfallback",
            available = function() return opts.lazy == true end,
            register = function(id, entries)
                captured.lazy = { id = id, entries = entries }
                return id
            end,
        }
    end
    fontdetect._internal.name_lookup = opts.name_lookup or function() return false end
    fontdetect._internal.file_exists = opts.file_exists or function() return false end
    luaotfload.add_fallback = function(id, entries)
        captured.fb = { id = id, entries = entries }
    end
    token.set_macro = function(name, value) captured.macros[name] = value end

    local ok, err = pcall(body, captured)

    fontdetect._internal.name_lookup = org_name_lookup
    fontdetect._internal.file_exists = org_exists
    luaotfload.add_fallback = org_fb
    token.set_macro = org_set_macro
    fontdetect._internal.lazy_fallback = org_lazy
    if not ok then error(err, 0) end
end

test_utils.run_test("prepare_family: alias mixes system name and local file", function()
    with_family_mocks({
        name_lookup = function(n) return n == "Jigmo" end,
        file_exists = function(p) return p == "./fonts/Jigmo2.ttf" end,
    }, function(captured)
        local resolved = fontdetect.prepare_family("famchain", "Jigmo")
        test_utils.assert_eq(#resolved, 2)
        test_utils.assert_eq(resolved[1].kind, "name")
        test_utils.assert_eq(resolved[1].value, "Jigmo")
        test_utils.assert_eq(resolved[2].kind, "path")
        test_utils.assert_eq(resolved[2].value, "./fonts/Jigmo2.ttf")
        -- 路径条目必须用 [路径] 方括号语法（file: 带路径会解析失败）
        test_utils.assert_eq(captured.fb.entries[1], "[./fonts/Jigmo2.ttf]:mode=node;")
        test_utils.assert_eq(captured.macros.l__luatexcn_family_main_tl, "Jigmo")
        test_utils.assert_eq(captured.macros.l__luatexcn_family_dir_tl, "")
        test_utils.assert_eq(captured.macros.l__luatexcn_family_fallback_tl, "famchain")
        test_utils.assert_eq(captured.macros.l__luatexcn_family_fallback_key_tl, "fallback")
    end)
end)

test_utils.run_test("prepare_family: uses on-demand fallback when available (#197)", function()
    with_family_mocks({
        lazy = true,
        name_lookup = function(n) return n == "Jigmo" end,
        file_exists = function(p) return p == "./fonts/Jigmo2.ttf" end,
    }, function(captured)
        fontdetect.prepare_family("famchain", "Jigmo")
        -- 不再注册 luaotfload 原生 fallback（它每个字号都把整条链载一遍）
        test_utils.assert_eq(captured.fb, nil)
        test_utils.assert_eq(captured.lazy.id, "famchain")
        test_utils.assert_eq(captured.lazy.entries[1], "[./fonts/Jigmo2.ttf]:mode=node;")
        test_utils.assert_eq(captured.macros.l__luatexcn_family_fallback_tl, "famchain")
        test_utils.assert_eq(captured.macros.l__luatexcn_family_fallback_key_tl, "luatexcnfallback")
    end)
end)

test_utils.run_test("prepare_family: alias member missing raises with download hint", function()
    with_family_mocks({}, function()
        local ok, err = pcall(fontdetect.prepare_family, "famchain", "Jigmo")
        test_utils.assert_eq(ok, false)
        test_utils.assert_match(tostring(err), "download_fonts%.py")
        test_utils.assert_match(tostring(err), "Jigmo2%.ttf")
    end)
end)

test_utils.run_test("prepare_family: file main gets Path dir, name fallback", function()
    with_family_mocks({
        file_exists = function(p) return p == "fonts/My.ttf" end,
    }, function(captured)
        local resolved = fontdetect.prepare_family("famchain", "fonts/My.ttf, TW-Kai")
        test_utils.assert_eq(#resolved, 2)
        test_utils.assert_eq(captured.macros.l__luatexcn_family_main_tl, "My.ttf")
        test_utils.assert_eq(captured.macros.l__luatexcn_family_dir_tl, "fonts/")
        test_utils.assert_eq(captured.fb.entries[1], "name:TW-Kai:mode=node;")
    end)
end)

test_utils.run_test("prepare_family: single name registers no fallback", function()
    with_family_mocks({}, function(captured)
        local resolved = fontdetect.prepare_family("famchain", "Source Han Serif SC")
        test_utils.assert_eq(#resolved, 1)
        test_utils.assert_eq(captured.fb, nil)
        test_utils.assert_eq(captured.macros.l__luatexcn_family_main_tl, "Source Han Serif SC")
        test_utils.assert_eq(captured.macros.l__luatexcn_family_fallback_tl, "")
        test_utils.assert_eq(captured.macros.l__luatexcn_family_fallback_key_tl, "")
    end)
end)

test_utils.run_test("prepare_family: bare filename resolved via find_font_file", function()
    with_family_mocks({
        file_exists = function(p) return p == "./fonts/Jigmo2.ttf" end,
    }, function(captured)
        local resolved = fontdetect.prepare_family("famchain", "TW-Kai, Jigmo2.ttf")
        test_utils.assert_eq(resolved[2].kind, "path")
        test_utils.assert_eq(captured.fb.entries[1], "[./fonts/Jigmo2.ttf]:mode=node;")
    end)
end)

print("\nAll font-autodetect tests passed!")
