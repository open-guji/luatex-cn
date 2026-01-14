# Referencing Files in Other Folders

When working with this project, you often have your document in a subdirectory (like `example/史记目录第一二页/`) while the core library files (`.cls`, `.sty`, and `.lua`) are in another (like `cn_vertical/`).

## 1. LaTeX Files (.cls, .sty)

LaTeX uses the `TEXINPUTS` environment variable to look for class and package files.

In **PowerShell** (Windows), you can set this variable for the current session and run `lualatex`:

```powershell
$env:TEXINPUTS = ".;../../cn_vertical//;"
lualatex your_file.tex
```

> [!NOTE]
> The `//` at the end of a path tells LaTeX to search recursively in that directory. The `;` is the separator on Windows (use `:` on Linux/macOS). The `.` represents the current directory.

## 2. Lua Files (.lua)

Since we use `require()` in our `.sty` and `.lua` files, Lua needs to know where to find these modules. Lua uses `package.path` (or the `LUA_PATH` environment variable).

However, in LuaTeX, it's often easier to set the `LUAINPUTS` environment variable similarly to `TEXINPUTS`:

```powershell
$env:LUAINPUTS = ".;../../cn_vertical//;"
lualatex your_file.tex
```

## 3. Recommended Command for this Project

To compile `example/史记目录第一二页/shiji_index.tex` from its own directory:

```powershell
# Navigate to the directory
cd "example/史记目录第一二页/"

# Set both paths and run (Windows PowerShell)
$env:TEXINPUTS = ".;../../cn_vertical//;"
$env:LUAINPUTS = ".;../../cn_vertical//;"
lualatex shiji_index.tex
```

### Automation Tip
You can combine these into a single line:
```powershell
$env:TEXINPUTS=".;../../cn_vertical//;"; $env:LUAINPUTS=".;../../cn_vertical//;"; lualatex shiji_index.tex
```

## 4. Why is this necessary?

- `\documentclass{guji}` looks for `guji.cls`.
- `\usepackage{cn_vertical}` looks for `cn_vertical.sty`.
- `require('core_main')` in Lua looks for `core_main.lua`.

By setting these environment variables, you avoid moving files around and keep the project structure clean.
