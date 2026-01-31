-- test/run_all.lua - Run all tests in the project

-- List of tests to run
local tests = {
    "test/unit_test/banxin/luatex-cn-banxin-render-yuwei-test.lua",
    "test/unit_test/banxin/luatex-cn-banxin-render-banxin-test.lua",
    "test/unit_test/banxin/luatex-cn-banxin-main-test.lua",
    "test/unit_test/fonts/luatex-cn-font-autodetect-test.lua",
    "test/unit_test/splitpage/luatex-cn-splitpage-test.lua",
    "test/unit_test/vertical/luatex-cn-vertical-base-constants-test.lua",
    "test/unit_test/vertical/luatex-cn-vertical-base-hooks-test.lua",
    "test/unit_test/vertical/luatex-cn-vertical-base-test.lua",
    "test/unit_test/vertical/luatex-cn-vertical-core-main-test.lua",
    "test/unit_test/vertical/luatex-cn-vertical-core-sidenote-test.lua",
    "test/unit_test/vertical/luatex-cn-vertical-core-textbox-test.lua",
    "test/unit_test/vertical/luatex-cn-vertical-core-textflow-test.lua",
    "test/unit_test/vertical/luatex-cn-vertical-flatten-nodes-test.lua",
    "test/unit_test/vertical/luatex-cn-vertical-layout-grid-test.lua",
    "test/unit_test/vertical/luatex-cn-vertical-render-background-test.lua",
    "test/unit_test/vertical/luatex-cn-vertical-render-border-test.lua",
    "test/unit_test/vertical/luatex-cn-vertical-render-page-test.lua",
    "test/unit_test/vertical/luatex-cn-vertical-render-position-test.lua",
    "test/unit_test/vertical/luatex-cn-vertical-render-test.lua",
    "test/unit_test/vertical/test_unified_parsing.lua",
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
