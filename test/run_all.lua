-- test/run_all.lua - Run all unit tests in the project
-- Usage: texlua test/run_all.lua

-- List of tests to run (ordered by dependency: util → core → plugin/feature)
local tests = {
    -- Util layer (pure functions, no complex deps)
    "test/unit_test/util/utils-test.lua",
    "test/unit_test/util/text-utils-test.lua",
    "test/unit_test/util/style-registry-test.lua",
    "test/unit_test/util/drawing-test.lua",

    -- Constants & Debug
    "test/unit_test/core/constants-test.lua",
    "test/unit_test/debug/debug-test.lua",

    -- Core layer (pure function tests)
    "test/unit_test/core/core-punct-test.lua",
    "test/unit_test/core/core-metadata-test.lua",
    "test/unit_test/core/core-page-split-test.lua",
    "test/unit_test/core/render-position-test.lua",
    "test/unit_test/core/layout-grid-helpers-test.lua",
    "test/unit_test/core/flatten-nodes-test.lua",

    -- Core layer (complex modules, smoke tests)
    "test/unit_test/core/layout-grid-test.lua",
    "test/unit_test/core/render-page-test.lua",
    "test/unit_test/core/core-column-test.lua",

    -- Plugin/Feature layer: guji
    "test/unit_test/guji/judou-test.lua",
    "test/unit_test/guji/danye-test.lua",
    "test/unit_test/guji/meipi-test.lua",

    -- Plugin/Feature layer: decorate
    "test/unit_test/decorate/decorate-test.lua",
    "test/unit_test/decorate/linemark-test.lua",

    -- Plugin/Feature layer: banxin
    "test/unit_test/banxin/luatex-cn-banxin-main-test.lua",
    "test/unit_test/banxin/luatex-cn-banxin-render-banxin-test.lua",
    "test/unit_test/banxin/luatex-cn-banxin-render-yuwei-test.lua",

    -- Plugin/Feature layer: fonts
    "test/unit_test/fonts/luatex-cn-font-autodetect-test.lua",
}

print("=== Running All Project Tests ===")
local total = #tests
local passed = 0

local failed_files = {}

for _, test_file in ipairs(tests) do
    print("\n------------------------------------------------------------")
    print("Executing: " .. test_file)
    print("------------------------------------------------------------")
    local ok, reason, code = os.execute("texlua " .. test_file)

    -- In Lua 5.3+ (LuaTeX), os.execute returns (success, reason, code)
    -- success is true/nil
    if ok then
        passed = passed + 1
    else
        print("\n[!] FAILURE in " ..
            test_file .. " (Reason: " .. (reason or "unknown") .. ", Code: " .. (code or "-1") .. ")")
        table.insert(failed_files, test_file)
    end
end

print("\n" .. string.rep("=", 60))
print("FINAL TEST REPORT")
print(string.rep("-", 60))
print(string.format("Total:  %d", total))
print(string.format("Passed: %d", passed))
print(string.format("Failed: %d", #failed_files))

if #failed_files > 0 then
    print("\nFAILED FILES:")
    for _, f in ipairs(failed_files) do
        print("  - " .. f)
    end
    print(string.rep("=", 60))
    os.exit(1)
else
    print("\nALL TESTS PASSED SUCCESSFULLY!")
    print(string.rep("=", 60))
end
