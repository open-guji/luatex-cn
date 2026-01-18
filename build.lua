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
sourcefiles  = {"**/*.sty", "**/*.cls", "**/*.lua", "**/*.cfg"}

-- Documentation and example files
-- Documentation and example files
docfiles = {
  "README.md", "README-EN.md", "LICENSE", "VERSION", "INSTALL.md",
  "文档/*.pdf", "文档/*.tex",
  "示例/**/*.pdf", "示例/**/*.tex", "示例/**/*.png", "示例/**/*.jpg"
}

-- Exclude build and output directories
excludefiles = {"build/**/*", "out/**/*"}

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

-- Custom CTAN hook to fix structure and translate paths
function ctan_hook(path)
  print("Finalizing CTAN staging area at: " .. path)

  -- We use python for robust file operations (Unicode support and recursion)
  local cmd = "python -c \"import shutil, os, glob; " ..
              "p = '" .. path:gsub("\\", "/") .. "'; " ..
              "print('>>> Preserving src structure...'); " ..
              "src_dest = os.path.join(p, 'src'); " ..
              "if os.path.exists('src'): " ..
              "  if os.path.exists(src_dest): shutil.rmtree(src_dest); " ..
              "  shutil.copytree('src', src_dest); " ..
              "  for ext in ['*.sty', '*.cls', '*.lua', '*.cfg']: " ..
              "    for f in glob.glob(os.path.join(p, ext)): " ..
              "      try: os.remove(f); " ..
              "      except: pass; " ..
              "for folder in ['文档', '示例']: " ..
              "  if os.path.exists(folder): " ..
              "    d = os.path.join(p, folder); " ..
              "    if os.path.exists(d): shutil.rmtree(d); " ..
              "    shutil.copytree(folder, d)\""
  
  os.execute(cmd)

  -- 1. Call the translation script
  local cmd = "python scripts/ctan_post_process.py " .. path
  print("Running path translation: " .. cmd)
  os.execute(cmd)

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

