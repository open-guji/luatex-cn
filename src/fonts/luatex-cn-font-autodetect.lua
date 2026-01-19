-- luatex-cn-font-autodetect.lua
-- Automatic font detection for Chinese typesetting
-- Similar to ctex's fontset mechanism

local fontdetect = {}

-- Font schemes for different platforms
fontdetect.schemes = {
    -- Windows fonts (中易字体)
    windows = {
        name = "windows",
        fonts = {
            main = "SimSun",           -- 宋体
            sans = "SimHei",           -- 黑体
            kai = "KaiTi",             -- 楷体
            fangsong = "FangSong"      -- 仿宋
        },
        features = "RawFeature={+vert,+vrt2}, CharacterWidth=Full"
    },
    
    -- macOS fonts (苹方/华文系列)
    mac = {
        name = "mac",
        fonts = {
            main = "Songti SC",        -- 宋体-简
            sans = "PingFang SC",      -- 苹方-简
            kai = "Kaiti SC",          -- 楷体-简
            fangsong = "STFangsong"    -- 华文仿宋
        },
        features = "RawFeature={+vert,+vrt2}, CharacterWidth=Full"
    },
    
    -- Linux fonts (Fandol 开源字体)
    fandol = {
        name = "fandol",
        fonts = {
            main = "FandolSong",
            sans = "FandolHei",
            kai = "FandolKai",
            fangsong = "FandolFang"
        },
        features = "RawFeature={+vert,+vrt2}, CharacterWidth=Full"
    },
    
    -- Ubuntu fonts (文泉驿/Noto)
    ubuntu = {
        name = "ubuntu",
        fonts = {
            main = "Noto Serif CJK SC",
            sans = "Noto Sans CJK SC",
            kai = "AR PL UKai CN",           -- 文泉驿正黑
            fangsong = "Noto Serif CJK SC"
        },
        features = "RawFeature={+vert,+vrt2}, CharacterWidth=Full"
    },
    
    -- Common alternative fonts (备用方案)
    common = {
        name = "common",
        fonts = {
            main = "TW-Kai",           -- 全字庫正楷體
            sans = "Source Han Sans SC",
            kai = "TW-Kai",
            fangsong = "TW-Kai"
        },
        features = "RawFeature={+vert,+vrt2}, CharacterWidth=Full"
    }
}

-- Detect operating system
function fontdetect.detect_os()
    local os_type = os.type or "unix"
    
    -- Check if Windows
    if os_type == "windows" or package.config:sub(1,1) == '\\' then
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

-- Check if a font is available
-- Note: Font detection in LuaTeX is tricky. We use a simplified approach:
-- Just return true and let fontspec/luaotfload handle font loading.
-- If the font doesn't exist, fontspec will give a clear error message.
function fontdetect.font_exists(fontname)
    -- For now, skip font existence checking and trust the OS-based selection
    -- This ensures fonts like SimSun (which exist on Windows) are used
    return true
end

-- Select best available font scheme
function fontdetect.auto_select_scheme()
    local os_name = fontdetect.detect_os()
    local scheme = nil
    
    texio.write_nl("term and log", "[Font Auto-Detect] Operating system detected: " .. os_name)
    
    -- Try platform-specific scheme first
    if os_name == "windows" then
        scheme = fontdetect.schemes.windows
        texio.write_nl("term and log", "[Font Auto-Detect] Trying Windows fonts (SimSun, KaiTi, etc.)")
    elseif os_name == "mac" then
        scheme = fontdetect.schemes.mac
        texio.write_nl("term and log", "[Font Auto-Detect] Trying macOS fonts (Songti SC, PingFang SC, etc.)")
    elseif os_name == "linux" then
        -- Try Fandol first (open source)
        scheme = fontdetect.schemes.fandol
        texio.write_nl("term and log", "[Font Auto-Detect] Trying Fandol fonts (open source)")
        
        -- If Fandol not available, try Ubuntu/Noto fonts
        if not fontdetect.font_exists(scheme.fonts.main) then
            scheme = fontdetect.schemes.ubuntu
            texio.write_nl("term and log", "[Font Auto-Detect] Fandol not found, trying Noto CJK fonts")
        end
    end
    
    -- Verify the selected scheme's main font is available
    if scheme and not fontdetect.font_exists(scheme.fonts.main) then
        texio.write_nl("term and log", "[Font Auto-Detect] Platform font not found, trying common alternatives")
        scheme = fontdetect.schemes.common
    end
    
    -- Final verification
    if scheme and not fontdetect.font_exists(scheme.fonts.main) then
        texio.write_nl("term and log", "[Font Auto-Detect] WARNING: No suitable Chinese font found!")
        texio.write_nl("term and log", "[Font Auto-Detect] Please install fonts or manually specify using \\usepackage{fontspec} and \\setmainfont")
        return nil
    end
    
    if scheme then
        texio.write_nl("term and log", "[Font Auto-Detect] Selected scheme: " .. scheme.name)
        texio.write_nl("term and log", "[Font Auto-Detect] Main font: " .. scheme.fonts.main)
    end
    
    return scheme
end

-- Get font command for LaTeX
function fontdetect.get_font_setup()
    local scheme = fontdetect.auto_select_scheme()
    
    if not scheme then
        return nil
    end
    
    -- Return font setup information
    return {
        name = scheme.fonts.main,
        features = scheme.features,
        scheme = scheme.name
    }
end

return fontdetect
