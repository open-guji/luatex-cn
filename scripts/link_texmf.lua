#!/usr/bin/env texlua

-- link_texmf.lua
-- Easily turn on/off the junction link from TEXMFHOME to this folder's src

local function get_texmf_home()
    local handle = io.popen("kpsewhich -var-value=TEXMFHOME")
    local result = handle:read("*a")
    handle:close()
    return result:gsub("%s+", "")
end

local function is_windows()
    return package.config:sub(1, 1) == "\\"
end

local function execute(cmd)
    print("Executing: " .. cmd)
    return os.execute(cmd)
end

local texmf_home = get_texmf_home()
if texmf_home == "" or texmf_home == "nil" then
    print("Error: Could not find TEXMFHOME.")
    os.exit(1)
end

-- Normalize path for Windows if needed
if is_windows() then
    texmf_home = texmf_home:gsub("/", "\\")
end

local target_dir = texmf_home .. (is_windows() and "\\tex\\latex\\luatex-cn" or "/tex/latex/luatex-cn")
local parent_dir = texmf_home .. (is_windows() and "\\tex\\latex" or "/tex/latex")

local function get_abs_path(path)
    if is_windows() then
        local handle = io.popen('pushd "' .. path .. '" && cd && popd')
        local abs = handle:read("*a"):gsub("%s+$", "")
        handle:close()
        return abs
    else
        local handle = io.popen('cd "' .. path .. '" && pwd')
        local abs = handle:read("*a"):gsub("%s+$", "")
        handle:close()
        return abs
    end
end

local script_dir = debug.getinfo(1).source:match("@?(.*[/\\])") or "./"
local source_dir = get_abs_path(script_dir .. (is_windows() and "..\\tex" or "../tex"))

print("TEXMFHOME: " .. texmf_home)
print("Target:    " .. target_dir)
print("Source:    " .. source_dir)

local action = arg[1]

if action == "--on" then
    -- Check if target exists
    if is_windows() then
        local handle = io.popen('if exist "' .. target_dir .. '" echo exists')
        local exists = handle:read("*a"):match("exists")
        handle:close()
        if exists then
            print("Target already exists: " .. target_dir)
            print("Please run with --off first if you want to recreate it.")
            os.exit(1)
        end
    else
        local f = io.open(target_dir, "r")
        if f then
            f:close()
            print("Target already exists: " .. target_dir)
            print("Please run with --off first if you want to recreate it.")
            os.exit(1)
        end
    end

    -- Ensure parent exists
    if is_windows() then
        execute('if not exist "' .. parent_dir .. '" mkdir "' .. parent_dir .. '"')
        execute('mklink /J "' .. target_dir .. '" "' .. source_dir .. '"')
    else
        execute('mkdir -p "' .. parent_dir .. '"')
        execute('ln -s "' .. source_dir .. '" "' .. target_dir .. '"')
    end
    print("Link created: " .. target_dir .. " -> " .. source_dir)
elseif action == "--off" then
    if is_windows() then
        -- Check if it exists
        local handle = io.popen('if exist "' .. target_dir .. '" echo exists')
        local exists = handle:read("*a"):match("exists")
        handle:close()

        if exists then
            -- On Windows, rmdir is used to remove a junction
            execute('rmdir "' .. target_dir .. '"')
            print("Link removed: " .. target_dir)
        else
            print("Link does not exist: " .. target_dir)
        end
    else
        execute('rm -f "' .. target_dir .. '"')
        print("Link removed: " .. target_dir)
    end
else
    print("Usage: texlua scripts/link_texmf.lua [--on|--off]")
    print("  --on:  Create junction from TEXMFHOME to src")
    print("  --off: Remove the junction")
end
