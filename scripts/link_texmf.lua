#!/usr/bin/env texlua

--[[
    link_texmf.lua - TEXMFHOME 符号链接管理工具

    功能说明:
    此脚本用于在 TEXMFHOME 目录下创建或删除指向本项目 tex 目录的符号链接。
    通过创建链接，可以让 TeX 系统直接使用本项目的宏包，无需手动复制文件，
    方便开发和测试。

    用法:
        texlua scripts/link_texmf.lua --on     创建符号链接
        texlua scripts/link_texmf.lua --off    删除符号链接

    工作原理:
    - 自动检测 TEXMFHOME 路径（通过 kpsewhich）
    - 在 TEXMFHOME/tex/latex/ 下创建 luatex-cn 链接
    - Windows 使用 junction（目录联接），Linux/macOS 使用软链接

    注意事项:
    - Windows 上创建 junction 可能需要管理员权限
    - 使用 --off 删除链接后，原始 tex 目录内容不受影响
--]]

local function is_windows()
    return package.config:sub(1, 1) == "\\"
end

local function get_texmf_home()
    local handle = io.popen("kpsewhich -var-value=TEXMFHOME")
    if not handle then return "" end
    local result = handle:read("*a")
    handle:close()
    if not result then return "" end
    result = result:gsub("%s+", "")

    -- Expand ~ to home directory on Linux/macOS
    if not is_windows() and result:sub(1, 1) == "~" then
        local home = os.getenv("HOME")
        if home then
            result = home .. result:sub(2)
        end
    end
    return result
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
        local handle = io.popen('pushd "' .. path .. '" >nul 2>&1 && cd && popd')
        if not handle then return path end
        local abs = handle:read("*a")
        handle:close()
        return abs and abs:gsub("%s+$", "") or path
    else
        local handle = io.popen('cd "' .. path .. '" >/dev/null 2>&1 && pwd')
        if not handle then return path end
        local abs = handle:read("*a")
        handle:close()
        return abs and abs:gsub("%s+$", "") or path
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
        local exists = nil
        if handle then
            exists = handle:read("*a")
            handle:close()
        end
        if exists and exists:match("exists") then
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
        local exists = nil
        if handle then
            exists = handle:read("*a")
            handle:close()
        end
        if exists and exists:match("exists") then
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
