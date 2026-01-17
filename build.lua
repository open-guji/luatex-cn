-- Build script for LuaTeX-CN

module = "luatex-cn"

-- Read version from VERSION file (single source of truth)
local version_file = io.open("VERSION", "r")
if version_file then
  pkgversion = version_file:read("*l"):gsub("^%s*(.-)%s*$", "%1") -- trim whitespace
  version_file:close()
else
  pkgversion = "1.0.0" -- fallback
end

-- Set package date (format: YYYY-MM-DD)
pkgdate = os.date("%Y-%m-%d")

-- Files to be included in the package
sourcefiles  = {"src/**"}
installfiles = {"*.sty", "*.cls", "*.lua", ".cfg"}
docfiles     = {"doc/**", "README.md", "INSTALL.md", "QUICKSTART.md", "LICENSE", "VERSION"}
docfiledir   = "."

-- Custom tagging function (l3build tag)
-- This hook runs when 'l3build tag <version>' is called
function tag_hook(tagname, tagdate)
  -- Convert tagdate (YYYY-MM-DD or similar) to YYYY/MM/DD for the TeX files
  local formatted_date = tagdate:gsub("-", "/")
  local cmd = "texlua scripts/tag_version.lua " .. tagname .. " " .. formatted_date
  print("Running version update: " .. cmd)
  os.execute(cmd)
  return 0
end

-- Typesetting configuration
typesetexe = "lualatex"

-- TDS structure mapping
-- l3build handles the standard mappings automatically for .sty and .cls
-- For .lua files, they are typically placed alongside .sty files in tex/latex/
-- unless they are executable scripts.

-- Clean up configuration
cleanfiles = {"*.pdf", "*.zip"}

-- CTAN metadata
uploadconfig = {
  pkg     = module,
  author  = "Sheldon Li",
  license = "apache-2.0",
  summary = "Sophisticated traditional Chinese vertical typesetting and ancient book layout.",
  topic   = {"chinese", "vertical-typesetting", "ancient-books"},
}
