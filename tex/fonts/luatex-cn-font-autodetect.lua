-- luatex-cn-font-autodetect.lua
-- Automatic font detection for Chinese typesetting
-- Similar to ctex's fontset mechanism

local fontdetect = {}

-- Font schemes for different platforms
fontdetect.schemes = {
    -- Windows fonts (中易字体 / 微软雅黑)
    windows = {
        name = "windows",
        fonts = {
            main = { "SimSun", "NSimSun", "Microsoft YaHei", "SimHei" }, -- 宋体, 新宋体, 微软雅黑, 黑体
            sans = { "Microsoft YaHei", "SimHei" },                      -- 微软雅黑, 黑体
            kai = { "KaiTi", "STKaiti", "SimKai" },                      -- 楷体, 华文楷体
            fangsong = { "FangSong", "STFangsong", "SimFang" }           -- 仿宋, 华文仿宋
        },
        features = "RawFeature={+vert,+vrt2}"
    },

    -- macOS fonts (苹方/华文系列)
    mac = {
        name = "mac",
        fonts = {
            main = { "Songti SC", "STSong", "PingFang SC" }, -- 宋体-简, 华文宋体, 苹方-简
            sans = { "PingFang SC", "Heiti SC", "STHeiti" }, -- 苹方-简, 黑体-简, 华文黑体
            kai = { "Kaiti SC", "STKaiti" },                 -- 楷体-简, 华文楷体
            fangsong = { "STFangsong", "FangSong" }          -- 华文仿宋, 仿宋
        },
        features = "RawFeature={+vert,+vrt2}"
    },

    -- Linux fonts (Fandol 开源字体)
    fandol = {
        name = "fandol",
        fonts = {
            main = { "FandolSong-Regular", "FandolSong" },
            sans = { "FandolHei-Regular", "FandolHei" },
            kai = { "FandolKai-Regular", "FandolKai" },
            fangsong = { "FandolFang-Regular", "FandolFang" }
        },
        features = "RawFeature={+vert,+vrt2}"
    },

    -- Ubuntu fonts (文泉驿/Noto)
    ubuntu = {
        name = "ubuntu",
        fonts = {
            main = { "Noto Serif CJK SC", "Source Han Serif SC" },
            sans = { "Noto Sans CJK SC", "Source Han Sans SC" },
            kai = { "AR PL UKai CN", "WenQuanYi Zen Hei" },
            fangsong = { "Noto Serif CJK SC", "Source Han Serif SC" }
        },
        features = "RawFeature={+vert,+vrt2}"
    },

    -- Common alternative fonts (备用方案)
    common = {
        name = "common",
        fonts = {
            main = { "TW-Kai", "Source Han Serif SC", "Noto Serif CJK SC" },
            sans = { "Source Han Sans SC", "Noto Sans CJK SC" },
            kai = { "TW-Kai", "AR PL UKai CN" },
            fangsong = { "TW-Kai", "Noto Serif CJK SC" }
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

-- Check if a font is available (fallback simplified version)
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

-- Find the first available font in a list
function fontdetect.resolve_font(font_list)
    if type(font_list) == "string" then
        if fontdetect.font_exists(font_list) then return font_list end
        return nil
    end

    for _, name in ipairs(font_list) do
        if fontdetect.font_exists(name) then return name end
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
function fontdetect.get_font_setup()
    local scheme = fontdetect.auto_select_scheme()

    if not scheme then return nil end

    local function join_fonts(list)
        if type(list) == "string" then return list end
        return table.concat(list, ",")
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
