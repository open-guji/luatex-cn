---@diagnostic disable: duplicate-set-field
-- luatex-cn-font-autodetect-test.lua - Unit tests for font autodetetection
local test_utils = require('test.test_utils')
local fontdetect = require('tex.fonts.luatex-cn-font-autodetect')

-- Save original functions/values
local org_os_type = os.type
local org_pkg_config = package.config
local org_io_popen = io.popen

test_utils.run_test("detect_os - Windows Detection", function()
    -- Mock Windows environment
    os.type = "windows"

    test_utils.assert_eq(fontdetect.detect_os(), "windows", "Should detect windows via os.type")

    -- Mock via package.config
    os.type = "unix"
    package.config = "\\\n;\n?\n!\n-"
    test_utils.assert_eq(fontdetect.detect_os(), "windows", "Should detect windows via package.config")

    -- Restore
    os.type = org_os_type
    package.config = org_pkg_config
end)

test_utils.run_test("detect_os - Mac Detection", function()
    os.type = "unix"
    package.config = "/\n;\n?\n!\n-"

    -- Mock io.popen to return Darwin
    io.popen = function(cmd)
        return {
            read = function() return "Darwin" end,
            close = function() end
        }
    end

    test_utils.assert_eq(fontdetect.detect_os(), "mac", "Should detect mac via uname")

    io.popen = org_io_popen
end)

test_utils.run_test("auto_select_scheme - Windows", function()
    -- Force detect_os to return windows
    local org_detect = fontdetect.detect_os
    fontdetect.detect_os = function() return "windows" end

    local scheme = fontdetect.auto_select_scheme()
    test_utils.assert_eq(scheme and scheme.name, "windows", "Should select windows scheme")
    test_utils.assert_eq(scheme and scheme.fonts and scheme.fonts.main, "SimSun", "Should select SimSun for windows")

    fontdetect.detect_os = org_detect
end)

test_utils.run_test("auto_select_scheme - Mac", function()
    local org_detect = fontdetect.detect_os
    fontdetect.detect_os = function() return "mac" end

    local scheme = fontdetect.auto_select_scheme()
    test_utils.assert_eq(scheme and scheme.name, "mac", "Should select mac scheme")
    test_utils.assert_eq(scheme and scheme.fonts and scheme.fonts.main, "Songti SC", "Should select Songti SC for mac")

    fontdetect.detect_os = org_detect
end)

test_utils.run_test("auto_select_scheme - Fallback", function()
    local org_detect = fontdetect.detect_os
    local org_exists = fontdetect.font_exists

    fontdetect.detect_os = function() return "linux" end
    -- Mock Fandol and Noto missing (all candidates)
    fontdetect.font_exists = function(name)
        -- Fandol candidates
        if name:match("Fandol") then return false end
        -- Ubuntu candidates
        if name:match("Noto") or name:match("Source Han") or name:match("AR PL") then return false end
        return true -- Common fonts exist
    end

    local scheme = fontdetect.auto_select_scheme()
    test_utils.assert_eq(scheme and scheme.name, "common", "Should fallback to common scheme")

    fontdetect.detect_os = org_detect
    fontdetect.font_exists = org_exists
end)

test_utils.run_test("auto_select_scheme - Windows Fallback", function()
    local org_detect = fontdetect.detect_os
    local org_exists = fontdetect.font_exists

    fontdetect.detect_os = function() return "windows" end
    -- Mock SimSun missing, but Microsoft YaHei exists
    fontdetect.font_exists = function(name)
        if name == "SimSun" or name == "NSimSun" then
            return false
        end
        return true
    end

    local scheme = fontdetect.auto_select_scheme()
    test_utils.assert_eq(scheme and scheme.name, "windows", "Should still be windows scheme")
    test_utils.assert_eq(scheme and scheme.fonts.main, "Microsoft YaHei", "Should fallback to Microsoft YaHei")

    fontdetect.detect_os = org_detect
    fontdetect.font_exists = org_exists
end)

test_utils.run_test("get_font_setup", function()
    local org_detect = fontdetect.detect_os
    fontdetect.detect_os = function() return "windows" end

    local setup = fontdetect.get_font_setup()
    test_utils.assert_eq(setup and setup.name, "SimSun", "setup.name mismatch")
    test_utils.assert_eq(setup and setup.scheme, "windows", "setup.scheme mismatch")
    test_utils.assert_match(setup and setup.features or "", "+vrt2", "setup.features missing vrt2")

    fontdetect.detect_os = org_detect
end)

print("\nAll font-autodetect tests passed!")
