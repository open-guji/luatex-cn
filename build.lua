---@diagnostic disable: lowercase-global
-- Build script for LuaTeX-CN
module = "luatex-cn"

-- Read version from VERSION file
local version_file = io.open("VERSION", "r")
if version_file then
  version_file:close()
end

-- Location for development files
sourcefiledir         = "tex"
docfiledir            = "."

-- Names for directories in the ZIP package
sourcepkgdir          = "tex"
docpkgdir             = "doc"

-- Source files (included in the ZIP)
sourcefiles           = { "**/*.sty", "**/*.cls", "**/*.lua", "**/*.cfg" }

-- Documentation and example files (Chinese folders copied in ctan_hook)
docfiles              = {
  "README.md", "README-EN.md", "LICENSE", "VERSION", "INSTALL.md"
}

-- Exclude build and output directories
excludefiles          = { "build/**/*", "out/**/*" }

-- Disable automatic root installation
installfiles          = {}

-- Skip tests/typesetting
checkfiles            = {}
testfiles             = { "*.lvt" }
testfilesdir          = "testfiles"
stdengine             = "luatex"
checkengines          = { "luatex" }
typesetfiles          = {}

--------------------------------------------------------------------------------
-- Helper functions (pure Lua, no Python dependency)
--------------------------------------------------------------------------------

-- File name translation map for CTAN (Chinese -> ASCII)
local translation_map = {
  ["文档"] = "doc",
  ["示例"] = "example",
  ["史记五帝本纪"] = "shiji-wudibenji",
  ["史记目录"] = "shiji-mulu",
  ["现代竖排书"] = "modern-vertical",
  ["红楼梦甲戌本"] = "hongloumeng-jiaxuben",
  ["史记.tex"] = "shiji.tex",
  ["史记.pdf"] = "shiji.pdf",
  ["文渊阁宝印.png"] = "wenyuange-seal.png",
  ["史记目录.tex"] = "shiji-mulu.tex",
  ["史记目录.pdf"] = "shiji-mulu.pdf",
  ["史记-黑白.tex"] = "shiji-bw.tex",
  ["史记-黑白.pdf"] = "shiji-bw.pdf",
  ["测试.tex"] = "test.tex",
  ["测试.pdf"] = "test.pdf",
  ["石头记.tex"] = "shitouji.tex",
  ["石头记.pdf"] = "shitouji.pdf",
  ["首页展示"] = "homepage-showcase",
  ["史记卷六·现代"] = "shiji-juan6-modern",
  ["卷十六.tex"] = "juan16.tex",
  ["卷十六.pdf"] = "juan16.pdf",
  ["四库全书简明目录"] = "siku-jianming-mulu",
  ["目录.tex"] = "mulu.tex",
  ["目录.pdf"] = "mulu.pdf",
}

-- Check if string contains Chinese characters
local function has_chinese(str)
  for _, code in utf8.codes(str) do
    if code >= 0x4e00 and code <= 0x9fff then
      return true
    end
  end
  return false
end

-- Get directory separator
local function get_sep()
  return package.config:sub(1, 1)
end

-- Join path components
local function join_path(...)
  local sep = get_sep()
  local parts = { ... }
  return table.concat(parts, sep)
end

-- Check if path exists
local function path_exists(path)
  local f = io.open(path, "r")
  if f then
    f:close()
    return true
  end
  return false
end

-- Check if path is a directory
local function is_dir(path)
  local sep = get_sep()
  local cmd
  if sep == "\\" then
    cmd = 'if exist "' .. path .. '\\*" (exit 0) else (exit 1)'
    return os.execute(cmd) == 0
  else
    return os.execute('test -d "' .. path .. '"') == 0
  end
end

-- List directory contents (with Unicode support on Windows)
local function list_dir(path)
  local sep = get_sep()
  local entries = {}

  if sep == "\\" then
    -- Windows: use PowerShell with temp file for proper UTF-8 support
    local tmp_file = os.tmpname()
    local cmd = 'powershell -Command "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8; Get-ChildItem -Name \'' ..
        path:gsub("\\", "\\\\") .. '\'" > "' .. tmp_file .. '" 2>nul'
    os.execute(cmd)

    local f = io.open(tmp_file, "rb")
    if f then
      local content = f:read("*a")
      f:close()
      os.remove(tmp_file)

      -- Skip BOM if present
      if content:sub(1, 3) == "\xef\xbb\xbf" then
        content = content:sub(4)
      end

      for entry in content:gmatch("[^\r\n]+") do
        if entry and entry ~= "" then
          table.insert(entries, entry)
        end
      end
    end
  else
    -- Unix: use ls command
    local handle = io.popen('ls -1 "' .. path .. '" 2>/dev/null')
    if handle then
      for entry in handle:lines() do
        if entry and entry ~= "" then
          table.insert(entries, entry)
        end
      end
      handle:close()
    end
  end

  return entries
end

-- Remove file or directory recursively
local function remove_path(path)
  local sep = get_sep()
  if sep == "\\" then
    if is_dir(path) then
      os.execute('rmdir /s /q "' .. path .. '" 2>nul')
    else
      os.execute('del /f /q "' .. path .. '" 2>nul')
    end
  else
    os.execute('rm -rf "' .. path .. '"')
  end
end

-- Copy file or directory recursively
local function copy_path(src, dest)
  local sep = get_sep()
  if sep == "\\" then
    if is_dir(src) then
      os.execute('xcopy /e /i /q /y "' .. src .. '" "' .. dest .. '" >nul 2>&1')
    else
      os.execute('copy /y "' .. src .. '" "' .. dest .. '" >nul 2>&1')
    end
  else
    if is_dir(src) then
      os.execute('cp -r "' .. src .. '" "' .. dest .. '"')
    else
      os.execute('cp "' .. src .. '" "' .. dest .. '"')
    end
  end
end

-- Rename/move file or directory
local function rename_path(old_path, new_path)
  local sep = get_sep()
  if sep == "\\" then
    os.execute('move /y "' .. old_path .. '" "' .. new_path .. '" >nul 2>&1')
  else
    os.execute('mv "' .. old_path .. '" "' .. new_path .. '"')
  end
end

-- Read file contents
local function read_file(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local content = f:read("*a")
  f:close()
  return content
end

-- Write file contents
local function write_file(path, content)
  local f = io.open(path, "wb")
  if not f then return false end
  f:write(content)
  f:close()
  return true
end

-- Sanitize files: remove BOM and convert CRLF to LF
local function sanitize_file(filepath)
  local content = read_file(filepath)
  if not content then return end

  local changed = false
  local new_content = content

  -- Remove BOM
  if new_content:sub(1, 3) == "\xef\xbb\xbf" then
    new_content = new_content:sub(4)
    changed = true
    print("  Removed BOM: " .. filepath)
  end

  -- Convert CRLF to LF
  if new_content:find("\r\n") then
    new_content = new_content:gsub("\r\n", "\n")
    changed = true
    print("  Fixed CRLF: " .. filepath)
  end

  if changed then
    write_file(filepath, new_content)
  end
end

-- Recursively walk directory and apply function to files
local function walk_dir(path, fn, extensions)
  local entries = list_dir(path)
  for _, entry in ipairs(entries) do
    local full_path = join_path(path, entry)
    if is_dir(full_path) then
      -- Skip certain directories
      if entry ~= ".git" and entry ~= "build" and entry ~= "__pycache__" and entry ~= ".vscode" then
        walk_dir(full_path, fn, extensions)
      end
    else
      -- Check extension
      local should_process = false
      if extensions then
        for _, ext in ipairs(extensions) do
          if entry:match(ext .. "$") then
            should_process = true
            break
          end
        end
      else
        should_process = true
      end
      if should_process then
        fn(full_path, entry)
      end
    end
  end
end

-- Sanitize all project files
local function sanitize_project_files()
  print("--- Checking file encoding and line endings ---")
  local extensions = { "%.sty", "%.cls", "%.lua", "%.tex", "%.md", "%.py", "%.txt" }
  walk_dir(".", sanitize_file, extensions)
  print("--- Check complete ---")
end

-- Update references in .tex files when renaming
local function update_tex_references(build_dir, old_name, new_name)
  walk_dir(build_dir, function(filepath, filename)
    if filename:match("%.tex$") then
      local content = read_file(filepath)
      if content and content:find(old_name, 1, true) then
        print("  Updating reference in " .. filepath .. ": " .. old_name .. " -> " .. new_name)
        local new_content = content:gsub(old_name:gsub("([%.%-%+])", "%%%1"), new_name)
        write_file(filepath, new_content)
      end
    end
  end)
end

-- Recursively rename Chinese filenames to ASCII (bottom-up)
local function translate_names(path, is_root)
  local entries = list_dir(path)

  -- First, recurse into subdirectories
  for _, entry in ipairs(entries) do
    local full_path = join_path(path, entry)
    if is_dir(full_path) then
      translate_names(full_path, false)
    end
  end

  -- Then, process files and directories at this level
  entries = list_dir(path) -- Re-read after recursion
  for _, entry in ipairs(entries) do
    local full_path = join_path(path, entry)

    -- Remove auxiliary files
    if entry:match("%.aux$") or entry:match("%.log$") then
      print("  Removing auxiliary file: " .. full_path)
      remove_path(full_path)
    elseif translation_map[entry] then
      local new_name = translation_map[entry]
      local new_path = join_path(path, new_name)

      print("  Renaming: " .. entry .. " -> " .. new_name)

      -- Update references in .tex files if it's a non-.tex file
      if not entry:match("%.tex$") and not is_dir(full_path) then
        update_tex_references(is_root and path or path:match("^(.+)[/\\]") or path, entry, new_name)
      end

      -- Remove destination if exists
      if path_exists(new_path) or is_dir(new_path) then
        remove_path(new_path)
      end

      rename_path(full_path, new_path)
    elseif has_chinese(entry) then
      print("CRITICAL ERROR: Chinese characters found in filename '" .. entry .. "' at " .. full_path)
      print("Please add this filename to the translation_map in build.lua")
      os.exit(1)
    end
  end
end

--------------------------------------------------------------------------------
-- l3build hooks and custom targets
--------------------------------------------------------------------------------

-- Custom tagging function
function tag_hook(tagname, tagdate)
  local formatted_date = tagdate:gsub("-", "/")
  local cmd = "texlua scripts/build/tag_version.lua " .. tagname .. " " .. formatted_date
  print("Running version update: " .. cmd)
  os.execute(cmd)
  return 0
end

-- Pre-build hook: sanitize files, tag version, and run unit tests
function checkinit_hook()
  sanitize_project_files()

  -- Run Lua unit tests before l3build regression tests
  print("\n>>> Running Lua unit tests...")
  local result = os.execute("texlua test/run_all.lua")
  if not result then
    print("\n[FAIL] Lua unit tests failed! Aborting l3build check.")
    os.exit(1)
  end
  print("")

  return 0
end

-- Post-process the CTAN staging area
local function post_process_ctan(staging_path)
  print("\n=== Post-processing CTAN staging area ===")
  print("Path: " .. staging_path)

  -- 1. Preserve tex directory structure (copy from source, not from flattened)
  print("\n>>> Preserving tex structure...")
  local tex_dest = join_path(staging_path, "tex")
  if is_dir("tex") then
    if is_dir(tex_dest) then
      remove_path(tex_dest)
    end
    copy_path("tex", tex_dest)

    -- Remove flattened source files at root
    print(">>> Cleaning flattened source files from root...")
    local entries = list_dir(staging_path)
    for _, entry in ipairs(entries) do
      if entry:match("%.sty$") or entry:match("%.cls$") or entry:match("%.lua$") or entry:match("%.cfg$") then
        local file_path = join_path(staging_path, entry)
        if not is_dir(file_path) then
          print("  Removing: " .. entry)
          remove_path(file_path)
        end
      end
    end
  end

  -- 2. Copy Chinese documentation folders
  print("\n>>> Copying documentation folders...")
  for _, folder in ipairs({ "文档", "示例" }) do
    if is_dir(folder) then
      local dest = join_path(staging_path, folder)
      if is_dir(dest) then
        remove_path(dest)
      end
      print("  Copying " .. folder .. " -> " .. dest)
      copy_path(folder, dest)
    end
  end

  -- 3. Translate Chinese filenames to ASCII
  print("\n>>> Translating Chinese filenames...")
  translate_names(staging_path, true)

  print("\n=== Post-processing complete ===\n")
end

-- Read version from VERSION file
local function read_version()
  local f = io.open("VERSION", "r")
  if not f then return "unknown" end
  local version = f:read("*a"):gsub("^%s+", ""):gsub("%s+$", "")
  f:close()
  return version
end

-- Custom CTAN build function (call via: texlua build.lua ctan)
local function ctan_custom()
  print("\n========================================")
  print("  LuaTeX-CN Custom CTAN Build")
  print("========================================\n")

  -- Read version
  local version = read_version()
  print("Version: " .. version .. "\n")

  -- Step 1: Sanitize files
  sanitize_project_files()

  -- Step 2: Tag version
  print("\n>>> Tagging version...")
  os.execute("texlua scripts/build/tag_version.lua")

  -- Step 3: Generate documentation PDFs from Markdown
  print("\n>>> Generating documentation PDFs...")
  local sep = get_sep()
  local python_cmd = sep == "\\" and "python" or "python3"
  os.execute(python_cmd .. " scripts/build/generate_docs_pdf.py")

  -- Step 4: Run standard l3build unpack
  print("\n>>> Running l3build unpack...")
  os.execute("l3build unpack")

  -- Step 5: Create staging directory
  local ctan_dir = join_path("build", "distrib", "ctan")
  local staging_path = join_path(ctan_dir, module)

  print("\n>>> Creating staging directory: " .. staging_path)
  -- Create parent directories
  if sep == "\\" then
    os.execute('mkdir "' .. ctan_dir .. '" 2>nul')
  else
    os.execute('mkdir -p "' .. ctan_dir .. '"')
  end

  if is_dir(staging_path) then
    remove_path(staging_path)
  end
  if sep == "\\" then
    os.execute('mkdir "' .. staging_path .. '"')
  else
    os.execute('mkdir -p "' .. staging_path .. '"')
  end

  -- Step 5: Copy doc files
  print("\n>>> Copying documentation files...")
  for _, doc in ipairs(docfiles) do
    if path_exists(doc) then
      print("  Copying: " .. doc)
      copy_path(doc, join_path(staging_path, doc))
    end
  end

  -- Step 6: Post-process (copy tex folder, Chinese folders, translate names)
  post_process_ctan(staging_path)

  -- Step 7: Create final zip
  print("\n>>> Creating CTAN archive...")
  local zip_name = module .. "-ctan-v" .. version .. ".zip"
  local zip_path = join_path(ctan_dir, zip_name)

  -- Remove old zip if exists
  if path_exists(zip_path) then
    remove_path(zip_path)
  end

  -- Create zip (platform-specific)
  if sep == "\\" then
    -- Windows: use PowerShell
    local ps_cmd = 'powershell -Command "Compress-Archive -Path \'' ..
        staging_path .. '\' -DestinationPath \'' .. zip_path .. '\' -Force"'
    os.execute(ps_cmd)
  else
    -- Unix: use zip command
    os.execute('cd "' .. ctan_dir .. '" && zip -r "' .. zip_name .. '" "' .. module .. '"')
  end

  -- Also copy to project root for convenience (with version in name)
  local root_zip = module .. "-ctan-v" .. version .. ".zip"
  if path_exists(root_zip) then
    remove_path(root_zip)
  end
  copy_path(zip_path, root_zip)

  -- Also keep a symlink/copy with the generic name for backwards compatibility
  local generic_zip = module .. "-ctan.zip"
  if path_exists(generic_zip) then
    remove_path(generic_zip)
  end
  copy_path(zip_path, generic_zip)

  print("\n========================================")
  print("  CTAN Package Build Complete!")
  print("========================================")
  print("Staging area: " .. staging_path)
  print("Archive: " .. root_zip)
  print("Generic name: " .. generic_zip)
  print("")

  return 0
end

-- Custom test function to run Lua unit tests
local function run_unit_tests()
  print("\n========================================")
  print("  Running Lua Unit Tests")
  print("========================================\n")

  local result = os.execute("texlua test/run_all.lua")
  if result then
    print("\n[OK] All Lua unit tests passed!")
    return 0
  else
    print("\n[FAIL] Some Lua unit tests failed!")
    return 1
  end
end

-- If called directly with "ctan" argument, run our custom build
if arg and arg[1] == "ctan" then
  os.exit(ctan_custom())
end

-- If called with "test" argument, run unit tests only
if arg and arg[1] == "test" then
  os.exit(run_unit_tests())
end

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------

-- Typesetting configuration
typesetexe = "lualatex"

-- Clean up configuration
cleanfiles = { "*.pdf", "*.zip", "*.aux", "*.log", "*.toc", "*.synctex.gz", "*.fls", "*.fdb_latexmk" }

-- CTAN metadata
uploadconfig = {
  pkg     = module,
  author  = "Sheldon Li",
  license = "apache-2.0",
  summary = "A LuaTeX based package to handle Chinese text typesetting.",
  topic   = { "chinese", "vertical-typesetting", "ancient-books" },
}
