# Cross-Platform Line Ending Setup Guide

## 项目已配置文件

1. **`.gitattributes`** - Git 自动处理换行符
2. **`.editorconfig`** - 编辑器自动设置
3. **`base_text_utils.lua`** - Lua 文本规范化工具

## 如何应用到现有文件

### 一次性规范化所有文件

在项目根目录执行：

```bash
# Windows (PowerShell)
git add --renormalize .
git commit -m "Normalize line endings to LF"

# 或者单独处理 cn_vertical 目录
cd cn_vertical
git add --renormalize .
git commit -m "Normalize cn_vertical line endings"
```

这会根据 `.gitattributes` 的配置，将所有文件重新规范化为 LF。

### 配置 Git（Windows 用户必做）

```bash
# 全局配置：检出时转为 CRLF，提交时转为 LF
git config --global core.autocrlf true

# 项目级配置（在项目根目录执行）
git config core.autocrlf true
```

## 在代码中使用文本规范化

### 在 Lua 模块中

```lua
-- 加载工具模块
local text_utils = require('base_text_utils')

-- 处理用户输入的文本
local user_input = "一些文本\r\n可能包含\r\nCRLF换行符"
local normalized = text_utils.normalize_for_typesetting(user_input)
-- 现在 normalized 只包含 LF (\n)

-- 完整的文本规范化（去除 BOM + 统一换行符）
local raw_text = get_file_content("some_file.txt")
local clean_text = text_utils.normalize_text(raw_text, {
    remove_bom = true,
    normalize_line_endings = true,
    normalize_whitespace = false
})
```

### 在 flatten_nodes.lua 中预处理（建议）

可以在 `flatten_vbox` 函数的入口处添加：

```lua
-- 在 flatten_nodes.lua 开头加载
local text_utils = require('base_text_utils')

-- 在处理文本内容时
local function process_text_content(text)
    -- 首先规范化换行符
    text = text_utils.normalize_line_endings(text)
    -- 然后进行其他处理...
    return text
end
```

## 验证配置

检查文件是否已规范化：

```bash
# 检查特定文件的换行符
file cn_vertical/cn_vertical.sty

# 或者用 Git 查看
git ls-files --eol cn_vertical/*.lua
```

## 注意事项

- **首次提交后**，团队所有成员 pull 代码时会自动应用规范
- **编辑器支持**：VS Code、IDX、Vim、IntelliJ 等都支持 `.editorconfig`
- **PDF 等二进制文件**：已在 `.gitattributes` 中标记，不会被转换