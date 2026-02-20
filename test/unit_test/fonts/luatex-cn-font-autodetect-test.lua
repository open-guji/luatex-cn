---@diagnostic disable: duplicate-set-field
-- Unit tests for fonts.luatex-cn-font-autodetect
local test_utils = require('test.test_utils')

-- Adjust require path: module lives in tex/fonts/ but package path uses tex/ prefix
local fontdetect = require('tex.fonts.luatex-cn-font-autodetect')

-- Save originals
local org_os_type = os.type
local org_pkg_config = package.config
local org_io_popen = io.popen

-- ============================================================================
-- detect_os
-- ============================================================================

test_utils.run_test("detect_os: Windows via os.type", function()
    os.type = "windows"
    test_utils.assert_eq(fontdetect.detect_os(), "windows")
    os.type = org_os_type
end)

test_utils.run_test("detect_os: Windows via package.config", function()
    os.type = "unix"
    package.config = "\\\n;\n?\n!\n-"
    test_utils.assert_eq(fontdetect.detect_os(), "windows")
    os.type = org_os_type
    package.config = org_pkg_config
end)

test_utils.run_test("detect_os: Mac via uname", function()
    os.type = "unix"
    package.config = "/\n;\n?\n!\n-"
    io.popen = function()
        return {
            read = function() return "Darwin" end,
            close = function() end
        }
    end
    test_utils.assert_eq(fontdetect.detect_os(), "mac")
    os.type = org_os_type
    package.config = org_pkg_config
    io.popen = org_io_popen
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

test_utils.run_test("auto_select_scheme: linux uses fandol", function()
    local org_detect = fontdetect.detect_os
    fontdetect.detect_os = function() return "linux" end

    local scheme = fontdetect.auto_select_scheme()
    test_utils.assert_eq(scheme.name, "fandol")

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

print("\nAll font-autodetect tests passed!")
