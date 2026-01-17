-- Build script for LuaTeX-CN
module = "luatex-cn"

-- Read version from VERSION file
local version_file = io.open("VERSION", "r")
if version_file then
  pkgversion = version_file:read("*l"):gsub("^%s*(.-)%s*$", "%1")
  version_file:close()
else
  pkgversion = "1.0.0"
end

-- Location for development files
sourcefiledir = "src"
docfiledir    = "."

-- Names for directories in the ZIP package
sourcepkgdir = "src"
docpkgdir    = "doc"

-- Source files (included in the ZIP)
sourcefiles  = {"**/*"}

-- Documentation and example files
docfiles = {
  "README.md", "README-EN.md", "LICENSE", "VERSION", "INSTALL.md",
  "doc/**/*.pdf", "doc/**/*.tex",
  "example-en/**/*.pdf", "example-en/**/*.tex"
}

-- Disable automatic root installation
installfiles = {}

-- Skip tests/typesetting
checkfiles = {}
testfiles = {}
typesetfiles = {}

-- Custom tagging function
function tag_hook(tagname, tagdate)
  local formatted_date = tagdate:gsub("-", "/")
  local cmd = "texlua scripts/tag_version.lua " .. tagname .. " " .. formatted_date
  print("Running version update: " .. cmd)
  os.execute(cmd)
  return 0
end

-- Custom CTAN hook to fix structure and remove duplication
function ctan_hook(path)
  local staging = path:gsub("/", "\\")
  print("Finalizing CTAN staging area at: " .. staging)

  -- 1. Aggressively remove EVERY .sty, .cls, .lua, .cfg, .png from the ZIP root
  -- These are duplicated because l3build flattens them by default
  local extensions = {"*.sty", "*.cls", "*.lua", "*.cfg", "*.png"}
  for _, pat in ipairs(extensions) do
    os.execute("del /Q \"" .. staging .. "\\" .. pat .. "\" 2>nul")
  end

  -- Also remove the folders l3build might have put in the root
  os.execute("rmdir /S /Q \"" .. staging .. "\\vertical\" 2>nul")
  os.execute("rmdir /S /Q \"" .. staging .. "\\banxin\" 2>nul")
  os.execute("rmdir /S /Q \"" .. staging .. "\\configs\" 2>nul")

  -- 2. Ensure example-en is a root peer (move it out of doc/)
  local ex_src = staging .. "\\doc\\example-en"
  local ex_dest = staging .. "\\example-en"
  if io.open(path .. "/doc/example-en", "r") then
    print("Moving example-en to root...")
    os.execute("mkdir \"" .. ex_dest .. "\" 2>nul")
    os.execute("xcopy /S /E /Y /I \"" .. ex_src .. "\" \"" .. ex_dest .. "\" >nul 2>nul")
    os.execute("rmdir /S /Q \"" .. ex_src .. "\" 2>nul")
  end

  -- 3. Fix doc/doc flattening
  local doc_inner = staging .. "\\doc\\doc"
  if io.open(path .. "/doc/doc", "r") then
    os.execute("xcopy /S /E /Y /I \"" .. doc_inner .. "\" \"" .. staging .. "\\doc\" >nul 2>nul")
    os.execute("rmdir /S /Q \"" .. doc_inner .. "\" 2>nul")
  end

  -- 4. Move root items back from doc/ to ZIP root
  local root_files = {"README.md", "README-EN.md", "LICENSE", "VERSION", "INSTALL.md"}
  for _, f in ipairs(root_files) do
    if io.open(path .. "/doc/" .. f, "r") then
      os.execute("move /Y \"" .. staging .. "\\doc\\" .. f .. "\" \"" .. staging .. "\" >nul 2>nul")
    end
  end

  -- 5. Cleanup unwanted files from examples
  os.execute("del /S /H /Q \"" .. ex_dest .. "\\*.aux\" 2>nul")
  os.execute("del /S /H /Q \"" .. ex_dest .. "\\*.log\" 2>nul")

  return 0
end

-- Typesetting configuration
typesetexe = "lualatex"

-- Clean up configuration
cleanfiles = {"*.pdf", "*.zip", "*.aux", "*.log", "*.toc", "*.synctex.gz", "*.fls", "*.fdb_latexmk"}

-- CTAN metadata
uploadconfig = {
  pkg     = module,
  author  = "Sheldon Li",
  license = "apache-2.0",
  summary = "Sophisticated traditional Chinese vertical typesetting and ancient book layout.",
  topic   = {"chinese", "vertical-typesetting", "ancient-books"},
}

