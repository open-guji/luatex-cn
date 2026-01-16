-- Build script for LuaTeX-CN

module = "luatex-cn"

-- Files to be included in the package
sourcefiles  = {"src/**"}
installfiles = {"*.sty", "*.cls", "*.lua", ".cfg"}
docfiles     = {"doc/**", "README.md", "INSTALL.md", "QUICKSTART.md", "LICENSE"}
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
  license = "lppl1.3c",
  summary = "Sophisticated traditional Chinese vertical typesetting and ancient book layout.",
  topic   = {"chinese", "vertical-typesetting", "ancient-books"},
}
