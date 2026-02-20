-- tag_version.lua
-- Cross-platform version tagging for luatex-cn
-- Use: texlua scripts/tag_version.lua [version] [date]

local version = arg[1]
local date = arg[2] or os.date("%Y/%m/%d")

-- If version is not provided, read from VERSION file
if not version or version == "" then
    local f = io.open("VERSION", "r")
    if f then
        version = f:read("*l"):gsub("^%s*(.-)%s*$", "%1")
        f:close()
        print("Read version from VERSION file: " .. version)
    else
        print("Error: No version provided and VERSION file not found.")
        os.exit(1)
    end
else
    -- Update VERSION file if version was provided as argument
    local vf = io.open("VERSION", "w")
    if vf then
        vf:write(version .. "\n")
        vf:close()
        print("Updated: VERSION -> " .. version)
    end
end

print("--- Starting version update ---")
print("Target version: v" .. version)
print("Target date:    " .. date)

local function update_file(filepath)
    local f = io.open(filepath, "r")
    if not f then return end
    local content = f:read("*a")
    f:close()

    local changed = false

    -- Pattern A: \ProvidesPackage{...}[YYYY/MM/DD vX.X.X ...]
    local patternA = "(\\Provides[PackageClass]+{[^}]+}%[)%d%d%d%d/%d%d/%d%d%s+v[%d%.]+"
    local replacementA = "%1" .. date .. " v" .. version
    local new_content, countA = content:gsub(patternA, replacementA)
    if countA > 0 then changed = true end

    -- Pattern B: \newcommand{\luatexcnversion}{X.X.X}
    local patternB = "(\\newcommand{?\\luatexcnversion}?)%s*{(.-)}"
    local replacementB = "%1{" .. version .. "}"
    new_content, countB = new_content:gsub(patternB, replacementB)
    if countB > 0 then changed = true end

    if changed then
        local wf = io.open(filepath, "w")
        wf:write(new_content)
        wf:close()
        print("Updated: " .. filepath)
    end
end

-- Scan src/ directory
local function scan(dir)
    local cmd
    if os.getenv("WINDIR") then
        cmd = 'dir /b /s "' .. dir .. '"'
    else
        cmd = 'find "' .. dir .. '" -type f'
    end
    
    local handle = io.popen(cmd)
    if not handle then return end
    for line in handle:lines() do
        if line:match("%.sty$") or line:match("%.cls$") then
            update_file(line)
        end
    end
    handle:close()
end

scan("src")

print("--- Update complete ---")
