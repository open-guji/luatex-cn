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
  author  = "luatex-cn contributors",
  license = "apache-2.0",
  summary = "Sophisticated traditional Chinese vertical typesetting and ancient book layout.",
  topic   = {"chinese", "vertical-typesetting", "ancient-books"},
}
