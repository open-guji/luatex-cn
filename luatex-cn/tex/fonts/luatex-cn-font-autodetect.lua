-- luatex-cn-font-autodetect.lua
-- Automatic font detection for Chinese typesetting
-- Similar to ctex's fontset mechanism

local fontdetect = {}

-- Font schemes for different platforms
-- Each font entry is a list of aliases (English and Chinese names) for the same font
-- This allows detection to work regardless of how the font is registered in the system
fontdetect.schemes = {
    -- Windows fonts (中易字体 / 微软雅黑)
    -- Include English, Simplified Chinese, and Traditional Chinese names (fix #35)
    windows = {
        name = "windows",
        fonts = {
            main = {
                { "SimSun", "宋体", "宋體" },
                { "NSimSun", "新宋体", "新宋體" },
                { "Microsoft YaHei", "微软雅黑", "微軟雅黑" },
                { "SimHei", "黑体", "黑體" }
            },
            sans = {
                { "Microsoft YaHei", "微软雅黑", "微軟雅黑" },
                { "SimHei", "黑体", "黑體" }
            },
            kai = {
                { "KaiTi", "楷体", "楷體" },
                { "STKaiti", "华文楷体", "華文楷體" },
                { "SimKai", "楷体_GB2312", "楷體_GB2312" }
            },
            fangsong = {
                { "FangSong", "仿宋", "仿宋" },
                { "STFangsong", "华文仿宋", "華文仿宋" },
                { "SimFang", "仿宋_GB2312" }
            }
        },
        features = "RawFeature={+vert,+vrt2}"
    },

    -- macOS fonts (苹方/华文系列)
    -- Include SC (Simplified) and TC (Traditional) variants
    mac = {
        name = "mac",
        fonts = {
            main = {
                { "Songti SC", "宋体-简", "宋體-簡", "Songti TC", "宋體-繁" },
                { "STSong", "华文宋体", "華文宋體" },
                { "PingFang SC", "苹方-简", "蘋方-簡", "PingFang TC", "蘋方-繁" }
            },
            sans = {
                { "PingFang SC", "苹方-简", "蘋方-簡", "PingFang TC", "蘋方-繁" },
                { "Heiti SC", "黑体-简", "黑體-簡", "Heiti TC", "黑體-繁" },
                { "STHeiti", "华文黑体", "華文黑體" }
            },
            kai = {
                { "Kaiti SC", "楷体-简", "楷體-簡", "Kaiti TC", "楷體-繁" },
                { "STKaiti", "华文楷体", "華文楷體" }
            },
            fangsong = {
                { "STFangsong", "华文仿宋", "華文仿宋" },
                { "FangSong", "仿宋" }
            }
        },
        features = "RawFeature={+vert,+vrt2}"
    },

    -- Linux fonts（Noto/思源 + 霞鹜文楷 + 朱雀仿宋，均为可确认的开放授权）
    linux = {
        name = "linux",
        fonts = {
            main = {
                { "Noto Serif CJK SC", "Noto Serif CJK TC" },
                { "Source Han Serif SC", "思源宋体", "思源宋體", "Source Han Serif TC" }
            },
            sans = {
                { "Noto Sans CJK SC", "Noto Sans CJK TC" },
                { "Source Han Sans SC", "思源黑体", "思源黑體", "Source Han Sans TC" }
            },
            kai = {
                { "AR PL UKai CN", "AR PL UKai TW", "AR PL KaitiM GB", "AR PL KaitiM Big5" },
                { "LXGW WenKai GB", "霞鹜文楷 GB", "LXGW WenKai", "霞鹜文楷" },
                { "WenQuanYi Zen Hei", "文泉驿正黑", "文泉驛正黑" }
            },
            fangsong = {
                { "Zhuque Fangsong", "Zhuque Fangsong (technical preview)", "朱雀仿宋" },
                { "Noto Serif CJK SC", "Noto Serif CJK TC" },
                { "Source Han Serif SC", "思源宋体", "思源宋體", "Source Han Serif TC" }
            }
        },
        features = "RawFeature={+vert,+vrt2}"
    },

    -- Common alternative fonts (备用方案)
    common = {
        name = "common",
        fonts = {
            main = {
                { "TW-Kai" },
                { "Source Han Serif SC", "思源宋体", "思源宋體", "Source Han Serif TC" },
                { "Noto Serif CJK SC", "Noto Serif CJK TC" }
            },
            sans = {
                { "Source Han Sans SC", "思源黑体", "思源黑體", "Source Han Sans TC" },
                { "Noto Sans CJK SC", "Noto Sans CJK TC" }
            },
            kai = {
                { "TW-Kai" },
                { "AR PL UKai CN", "AR PL UKai TW" }
            },
            fangsong = {
                { "TW-Kai" },
                { "Noto Serif CJK SC", "Noto Serif CJK TC" }
            }
        },
        features = "RawFeature={+vert,+vrt2}"
    }
}



-- Detect operating system
function fontdetect.detect_os()
    -- see [https://texluacats.github.io/LuaTeX/globals/os/#osname] for details.
    local os_name = os.name

    if os_name == "windows" then return "windows" end
    if os_name == "linux" then return "linux" end
    if os_name == "macosx" then return "mac" end
    
    -- undetermined operating system
    return "common"
end

-- Check if a single font name is available
function fontdetect.font_exists(fontname)
    if not fontname or fontname == "" then return false end
    local ok, res = pcall(require, "luaotfload")
    local lotf = (type(res) == "table" and res) or _G.luaotfload
    if ok and type(lotf) == "table" and type(lotf.find_file) == "function" then
        return lotf.find_file(fontname) ~= nil
    end
    -- If we can't check, we return true to let TeX/fontspec handle it later
    return true
end

-- Find font from a list of aliases (English and Chinese names)
-- Returns the first found name, or nil if none found (fix #35)
-- @param font_aliases (table|string) A list of alternative names for the same font
-- @return (string|nil) The first found font name, or nil
function fontdetect.find_any_font(font_aliases)
    if type(font_aliases) == "string" then
        font_aliases = { font_aliases }
    end

    local ok, res = pcall(require, "luaotfload")
    local lotf = (type(res) == "table" and res) or _G.luaotfload

    if not (ok and type(lotf) == "table" and type(lotf.find_file) == "function") then
        -- Can't check, return first name as fallback
        return font_aliases[1]
    end

    for _, name in ipairs(font_aliases) do
        if name and name ~= "" and lotf.find_file(name) then
            return name
        end
    end

    return nil
end

-- Find the first available font from a list of font groups
-- Each group is a table of aliases (English/Chinese names for the same font)
-- @param font_list (table) A list of font groups, e.g. { {"SimSun", "宋体"}, {"NSimSun", "新宋体"} }
-- @return (string|nil) The first found font name
function fontdetect.resolve_font(font_list)
    if type(font_list) == "string" then
        if fontdetect.font_exists(font_list) then return font_list end
        return nil
    end

    for _, entry in ipairs(font_list) do
        local found
        if type(entry) == "table" then
            -- Entry is a list of aliases for one font
            found = fontdetect.find_any_font(entry)
        else
            -- Entry is a single font name
            if fontdetect.font_exists(entry) then
                found = entry
            end
        end
        if found then return found end
    end
    return nil
end

-- Select best available font scheme (now returns the raw scheme with candidate lists)
function fontdetect.auto_select_scheme()
    local os_name = fontdetect.detect_os()
    local scheme = nil

    texio.write_nl("term and log", "[Font Auto-Detect] Operating system detected: " .. os_name)

    if os_name == "windows" then
        scheme = fontdetect.schemes.windows
    elseif os_name == "mac" then
        scheme = fontdetect.schemes.mac
    else
        scheme = fontdetect.schemes.linux
    end

    if scheme then
        texio.write_nl("term and log", "[Font Auto-Detect] Selected candidate scheme: " .. scheme.name)
    end

    return scheme
end

-- Get font setup information (returns lists as strings)
-- The font list now contains alias groups; we extract the first (primary) name from each
function fontdetect.get_font_setup()
    local scheme = fontdetect.auto_select_scheme()

    if not scheme then return nil end

    -- Extract primary font names from alias groups and join with commas
    local function join_fonts(list)
        if type(list) == "string" then return list end
        local names = {}
        for _, entry in ipairs(list) do
            if type(entry) == "table" then
                -- Entry is an alias group; use the first (English) name
                if entry[1] then
                    table.insert(names, entry[1])
                end
            else
                -- Entry is a single font name
                table.insert(names, entry)
            end
        end
        return table.concat(names, ",")
    end

    return {
        main = join_fonts(scheme.fonts.main),
        sans = join_fonts(scheme.fonts.sans),
        kai = join_fonts(scheme.fonts.kai),
        fangsong = join_fonts(scheme.fonts.fangsong),
        features = scheme.features,
        scheme = scheme.name
    }
end

-- ============================================================================
-- 字体族别名注册表与免安装字体解析
-- ============================================================================
-- 别名 → 成员列表。names 供系统/luaotfload 名字查找，file 供本地文件查找。
-- 成员文件名须与 scripts/font-manifest.json 的 aliases 一致（unit test 校验）。
fontdetect.registry = {
    Jigmo = {
        members = {
            { names = { "Jigmo" },  file = "Jigmo.ttf" },
            { names = { "Jigmo2" }, file = "Jigmo2.ttf" },
        },
    },
}

fontdetect._internal = fontdetect._internal or {}

function fontdetect._internal.file_exists(path)
    local f = io.open(path, "rb")
    if f then f:close() return true end
    return false
end

--- 严格的字体名查找：查 luaotfload 名字索引。
-- @return true/false 可判定结果；nil 表示当前环境无法判定
-- 注意 luaotfload.find_file 是早年 API，现行版本已无此函数；
-- 现行稳定入口是 luaotfload.aux.resolve_fontname（查不到返回 false，不触发重扫）。
function fontdetect._internal.name_lookup(fontname)
    if not fontname or fontname == "" then return false end
    local lotf = _G.luaotfload
    if lotf and lotf.aux and type(lotf.aux.resolve_fontname) == "function" then
        return lotf.aux.resolve_fontname(fontname) and true or false
    end
    if lotf and type(lotf.find_file) == "function" then
        return lotf.find_file(fontname) ~= nil
    end
    return nil
end

--- 从别名列表中找系统已装字体；无法判定时视为未装（宁走文件回退，不盲报有）
local function find_installed_font(names)
    for _, n in ipairs(names) do
        if fontdetect._internal.name_lookup(n) then return n end
    end
    return nil
end

--- 在免安装位置查找字体文件：文档目录 ./fonts/、文档目录本身、
-- 以及 kpse（覆盖 TEXMFHOME/fonts/truetype/luatex-cn/ 与 OSFONTDIR）。
-- @param filename (string) 字体文件名，如 "Jigmo2.ttf"
-- @return (string|nil) 可用路径
function fontdetect.find_font_file(filename)
    for _, dir in ipairs({ "./fonts/", "./" }) do
        local p = dir .. filename
        if fontdetect._internal.file_exists(p) then return p end
    end
    if kpse and kpse.find_file then
        -- pcall：texlua 环境下 kpse 需先 set_program_name，直接调用会抛错
        local ok, found = pcall(function()
            return kpse.find_file(filename, "truetype fonts")
                or kpse.find_file(filename, "opentype fonts")
        end)
        if ok then return found end
    end
    return nil
end

local function trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function is_font_filename(s)
    local lower = s:lower()
    return lower:match("%.ttf$") or lower:match("%.otf$") or lower:match("%.ttc$")
end

--- 生成一条 luaotfload fallback 链条目。
-- 名字用 name: 前缀；文件路径必须用 [路径] 方括号语法——
-- file: 前缀带路径（相对或绝对）会解析失败，只有裸文件名可用。
local function fallback_entry(kind, value)
    if kind == "path" then
        return "[" .. value .. "]:mode=node;"
    end
    return "name:" .. value .. ":mode=node;"
end

--- 解析单个字体规格：带 .ttf/.otf/.ttc 后缀按文件处理，否则按名字。
-- @return kind ("name"|"path"|nil), value
local function resolve_spec(spec)
    if is_font_filename(spec) then
        if spec:match("[/\\]") then
            if fontdetect._internal.file_exists(spec) then return "path", spec end
            return nil
        end
        local p = fontdetect.find_font_file(spec)
        if p then return "path", p end
        return nil
    end
    -- 名字规格不预检存在性：luaotfload 索引可能滞后，交给 fontspec 处理更友好
    return "name", spec
end

local function report_missing(family, missing)
    local msg = string.format(
        '[luatex-cn] 字体族 "%s" 缺少字体文件: %s\n'
        .. "获取方式（任选其一）:\n"
        .. "  1. python3 scripts/download_fonts.py --all --user   (安装到 TEXMFHOME)\n"
        .. "  2. python3 scripts/download_fonts.py --all --dest ./fonts   (放入文档目录)\n"
        .. "  3. 手动下载后放入文档目录 ./fonts/ 或 TEXMFHOME/fonts/truetype/luatex-cn/",
        family, table.concat(missing, ", "))
    if tex and tex.error then
        tex.error(msg)
    else
        error(msg)
    end
end

--- \设置字体族 的统一入口：解析字体族并注册回退链。
-- namelist 为单个注册表别名（如 "Jigmo"）时展开为成员列表，逐成员解析：
-- 系统装了就按名字用系统的，否则找本地文件，都没有则报错并提示下载脚本。
-- 普通逗号列表按原样解析，其中带字体后缀的条目按文件查找。
-- 解析结果经 token.set_macro 回填三个 tl 供 .sty 侧调用 \setmainfont：
--   l__luatexcn_family_main_tl     主字体名或文件名
--   l__luatexcn_family_dir_tl      主字体所在目录（fontspec Path=，名字方式为空）
--   l__luatexcn_family_fallback_tl 回退链 id（无回退时为空）
-- @return (table) 解析结果 {kind=..., value=...} 列表（供测试断言）
function fontdetect.prepare_family(id, namelist)
    namelist = trim(namelist)
    local resolved, missing = {}, {}
    local alias = fontdetect.registry[namelist]
    if alias then
        for _, m in ipairs(alias.members) do
            local name = find_installed_font(m.names)
            if name then
                table.insert(resolved, { kind = "name", value = name })
            else
                local p = fontdetect.find_font_file(m.file)
                if p then
                    table.insert(resolved, { kind = "path", value = p })
                else
                    table.insert(missing, m.file)
                end
            end
        end
    else
        for spec in string.gmatch(namelist, "[^,]+") do
            spec = trim(spec)
            if spec ~= "" then
                local kind, value = resolve_spec(spec)
                if kind then
                    table.insert(resolved, { kind = kind, value = value })
                else
                    table.insert(missing, spec)
                end
            end
        end
    end

    if #missing > 0 then
        report_missing(namelist, missing)
    end
    if #resolved == 0 then return resolved end

    local main = resolved[1]
    local main_name, main_dir = main.value, ""
    if main.kind == "path" then
        main_dir, main_name = main.value:match("^(.*[/\\])([^/\\]+)$")
        if not main_name then
            main_dir, main_name = "./", main.value
        end
    end

    local entries = {}
    for i = 2, #resolved do
        table.insert(entries, fallback_entry(resolved[i].kind, resolved[i].value))
    end
    local fallback_id = ""
    if #entries > 0 and luaotfload and luaotfload.add_fallback then
        luaotfload.add_fallback(id, entries)
        fallback_id = id
    end

    if token and token.set_macro then
        token.set_macro("l__luatexcn_family_main_tl", main_name)
        token.set_macro("l__luatexcn_family_dir_tl", main_dir)
        token.set_macro("l__luatexcn_family_fallback_tl", fallback_id)
    end
    return resolved
end

--- 注册字体族回退链（\设置字体族 / \setfontfamily 的多字体支持）
-- 把列表第 2..n 项注册为 luaotfload fallback，使首字体缺字时逐级回退。
-- @param id (string) fallback 链的唯一名称
-- @param namelist (string) 逗号分隔的完整字体名列表（含首字体，首项会被跳过）
function fontdetect.add_family_fallback(id, namelist)
    local entries = {}
    local first = true
    for name in string.gmatch(namelist, "[^,]+") do
        name = name:gsub("^%s+", ""):gsub("%s+$", "")
        if name ~= "" then
            if first then
                first = false
            else
                table.insert(entries, "name:" .. name .. ":mode=node;")
            end
        end
    end
    if #entries > 0 and luaotfload and luaotfload.add_fallback then
        luaotfload.add_fallback(id, entries)
    end
    return entries
end

-- 注册模块到 package.loaded
package.loaded['fonts.luatex-cn-font-autodetect'] = fontdetect

return fontdetect
