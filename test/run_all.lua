-- test/run_all.lua - Run all tests in the project
local test_utils = require('test.test_utils')

-- List of tests to run
local tests = {
    "test/banxin/luatex-cn-banxin-render-yuwei-test.lua",
    "test/banxin/luatex-cn-banxin-render-banxin-test.lua",
    "test/banxin/luatex-cn-banxin-main-test.lua",
    "test/fonts/luatex-cn-font-autodetect-test.lua",
    "test/splitpage/luatex-cn-splitpage-test.lua",
    "test/vertical/luatex-cn-vertical-base-test.lua",
    "test/vertical/luatex-cn-vertical-render-test.lua",
}

print("=== Running All Project Tests ===")
local total = #tests
local passed = 0

local failed_files = {}

for _, test_file in ipairs(tests) do
    print("\n------------------------------------------------------------")
    print("Executing: " .. test_file)
    print("------------------------------------------------------------")
    local ok = os.execute("texlua " .. test_file)
    if ok then
        passed = passed + 1
    else
        print("\n[!] FAILURE in " .. test_file)
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
