---
description: Get the number of lines of code for specific languages while excluding certain directories.
---
To get the number of lines of code for Lua, TeX, and Python, excluding `.git`, `tests`, and `build` directories, use the following command:

// turbo
cloc . --exclude-dir=.git,tests,build --include-lang=Lua,TeX,Python
