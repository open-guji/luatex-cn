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

    -- Linux fonts (Fandol 开源字体)
    fandol = {
        name = "fandol",
        fonts = {
            main = { { "FandolSong-Regular" }, { "FandolSong" } },
            sans = { { "FandolHei-Regular" }, { "FandolHei" } },
            kai = { { "FandolKai-Regular" }, { "FandolKai" } },
            fangsong = { { "FandolFang-Regular" }, { "FandolFang" } }
        },
        features = "RawFeature={+vert,+vrt2}"
    },

    -- Ubuntu fonts (文泉驿/Noto)
    ubuntu = {
        name = "ubuntu",
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
                { "AR PL UKai CN", "AR PL UKai TW" },
                { "WenQuanYi Zen Hei", "文泉驿正黑", "文泉驛正黑" }
            },
            fangsong = {
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
    local os_type = os.type or "unix"

    -- Check if Windows
    if os_type == "windows" or package.config:sub(1, 1) == '\\' then
        return "windows"
    end

    -- Check if macOS (Darwin)
    local handle = io.popen("uname -s 2>/dev/null")
    if handle then
        local result = handle:read("*a")
        handle:close()
        if result and result:match("Darwin") then
            return "mac"
        end
    end

    -- Assume Linux/Unix
    return "linux"
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
            -- Entry is a single font name (backward compatibility)
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
        scheme = fontdetect.schemes.fandol
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
                -- Entry is a single font name (backward compatibility)
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

-- 注册模块到 package.loaded
package.loaded['fonts.luatex-cn-font-autodetect'] = fontdetect

return fontdetect
