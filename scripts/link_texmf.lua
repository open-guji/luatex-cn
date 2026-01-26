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

-- Define targets relative to TEXMFHOME
local relative_targets = {
    "tex/latex/luatex-cn",
    "tex/lualatex/luatex-cn"
}

-- Normalize path for Windows if needed
if is_windows() then
    texmf_home = texmf_home:gsub("/", "\\")
end

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
print("Source:    " .. source_dir)

local action = arg[1]

if action == "--on" then
    for _, rel_target in ipairs(relative_targets) do
        local target_path
        local parent_path

        if is_windows() then
            local rel_win = rel_target:gsub("/", "\\")
            target_path = texmf_home .. "\\" .. rel_win
            parent_path = target_path:match("(.*)\\[^\\]+$")
        else
            target_path = texmf_home .. "/" .. rel_target
            parent_path = target_path:match("(.*)/[^/]+$")
        end

        print("Processing: " .. target_path)

        -- Check if target exists
        local exists = false
        if is_windows() then
            local handle = io.popen('if exist "' .. target_path .. '" echo exists')
            local res = handle:read("*a")
            handle:close()
            if res and res:match("exists") then exists = true end
        else
            local f = io.open(target_path, "r")
            if f then
                f:close()
                exists = true
            end
        end

        if exists then
            print("  Target already exists. Skipping.")
        else
            -- Ensure parent exists
            if is_windows() then
                execute('if not exist "' .. parent_path .. '" mkdir "' .. parent_path .. '"')
                execute('mklink /J "' .. target_path .. '" "' .. source_dir .. '"')
            else
                execute('mkdir -p "' .. parent_path .. '"')
                execute('ln -s "' .. source_dir .. '" "' .. target_path .. '"')
            end
            print("  Link created.")
        end
    end
elseif action == "--off" then
    for _, rel_target in ipairs(relative_targets) do
        local target_path
        if is_windows() then
            local rel_win = rel_target:gsub("/", "\\")
            target_path = texmf_home .. "\\" .. rel_win
        else
            target_path = texmf_home .. "/" .. rel_target
        end

        print("Processing: " .. target_path)

        -- Check if it exists
        local exists = false
        if is_windows() then
            local handle = io.popen('if exist "' .. target_path .. '" echo exists')
            local res = handle:read("*a")
            handle:close()
            if res and res:match("exists") then exists = true end
        else
            -- Check if symlink exists (even if broken) or dir exists
            -- 'ls' or 'test -e' is better than io.open for symlinks
            local code = os.execute('test -L "' .. target_path .. '" || test -e "' .. target_path .. '"')
            if code == 0 or code == true then exists = true end
        end

        if exists then
            if is_windows() then
                execute('rmdir "' .. target_path .. '"')
            else
                execute('rm -f "' .. target_path .. '"')
            end
            print("  Link removed.")
        else
            print("  Link does not exist.")
        end
    end
else
    print("Usage: texlua scripts/link_texmf.lua [--on|--off]")
    print("  --on:  Create junctions/symlinks from TEXMFHOME to src")
    print("  --off: Remove the junctions/symlinks")
end
