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
end

-- Standardize version: remove leading 'v' if present for internal logic,
-- but the script outputs it where needed.
local clean_version = (version or ""):gsub("^v", "")

-- Update VERSION file
local vf = io.open("VERSION", "wb")
if vf then
    vf:write(clean_version .. "\n")
    vf:close()
    print("Updated: VERSION -> " .. clean_version)
end

print("--- Starting version update ---")
print("Target version: " .. clean_version)
print("Target date:    " .. date)

local function update_file(filepath)
    local f = io.open(filepath, "rb")
    if not f then return end
    local content = f:read("*a")
    f:close()

    local changed = false

    -- Pattern A: \ProvidesPackage{...}[YYYY/MM/DD vX.X.X ...]
    local patternA = "(\\Provides[PackageClass]+{[^}]+}%[)%d%d%d%d/%d%d/%d%d%s+v?[%d%.]+"
    local replacementA = "%1" .. date .. " " .. clean_version
    local new_content, countA = content:gsub(patternA, replacementA)
    if countA > 0 then changed = true end

    -- Pattern A2: \ProvidesExplPackage {name} {date} {vversion}
    local patternA2 = "(\\ProvidesExpl[PackageClass]+%s*{[^}]+}%s*){%d%d%d%d/%d%d/%d%d}%s*{v?[%b.0-9a-zA-Z%-]+}"
    local replacementA2 = "%1{" .. date .. "} {" .. clean_version .. "}"
    local countA2
    new_content, countA2 = new_content:gsub(patternA2, replacementA2)
    if countA2 > 0 then changed = true end

    -- Pattern B: \newcommand{\luatexcnversion}{X.X.X}
    local patternB = "(\\newcommand{?\\luatexcnversion}?)%s*{(.-)}"
    local replacementB = "%1{" .. clean_version .. "}"
    local countB
    new_content, countB = new_content:gsub(patternB, replacementB)
    if countB > 0 then changed = true end

    -- Pattern C: \tl_const:Nn \c_luatexcn_version_tl {X.X.X}
    local patternC = "(\\tl_const:Nn%s+\\c_luatexcn_version_tl%s*){.-}"
    local replacementC = "%1{" .. clean_version .. "}"
    local countC
    new_content, countC = new_content:gsub(patternC, replacementC)
    if countC > 0 then changed = true end

    if changed then
        -- Use binary mode to preserve LF line endings
        local wf = io.open(filepath, "wb")
        if wf then
            wf:write(new_content)
            wf:close()
            print("Updated: " .. filepath)
        else
            print("Error: Could not open file for writing: " .. filepath)
        end
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

scan("tex")

print("--- Update complete ---")
