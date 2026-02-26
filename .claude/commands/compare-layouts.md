---
description: 比较 Original (ltc-guji.cls) 和 Digital (ltc-guji-digital.cls) TeX 文件的 layout 输出
---

# Guji Layout Compare

比较原始和数字化 TeX 文件的排版一致性。

## 使用方法

### Python 脚本（推荐）

```bash
# 基本用法：自动检测编译、比较、生成报告
python3 scripts/digitalize/compare_guji_layouts.py original.tex digital.tex

# 强制重新编译
python3 scripts/digitalize/compare_guji_layouts.py original.tex digital.tex --force

# 指定报告输出路径
python3 scripts/digitalize/compare_guji_layouts.py original.tex digital.tex -o report.md

# 只比较已有的 JSON（跳过编译）
python3 scripts/digitalize/compare_guji_layouts.py original.tex digital.tex --no-compile
```

### 功能特性

1. **智能编译检测**
   - 自动检查 layout JSON 是否存在
   - 验证 JSON 中的 `source_mtime` 字段与 TeX 文件修改时间
   - **仅在需要时编译**,避免重复编译浪费时间

2. **page_summary 比较**
   - 优先使用简化的 `page_summary` 字段（无坐标，仅文字内容）
   - 支持夹注双列（`[右小列|左小列]` 格式显示）
   - 自动统计总字数
   - 兼容旧版 JSON（fallback 到 `pages` 字段逐字符比较）

3. **详细 Markdown 报告**
   - 概要统计（页数、字数、匹配率）
   - 差异总结表格
   - 第一处差异的详细逐列对比
   - PDF 页面截图对比（需要 `pdftoppm`）

### 输出示例

```
## 步骤三：比较排版
  原始 48 页 / 数字化 41 页
  匹配页数：14
  总字数：13224（一致）
  前 10 页完全一致
  第一处差异在 PDF第11页（对开第5页·右）

## 步骤四：生成报告
  详细报告已保存至：排版一致性比较报告.md
```

## 手动分步操作

如果需要手动控制编译流程：

### 步骤 1: 导出 Layout JSON

```bash
cd path/to/tex && ENABLE_EXPORT=1 lualatex yourfile.tex
# → yourfile-layout.json

ENABLE_EXPORT=1 lualatex yourfile-digital.tex
# → yourfile-digital-layout.json
```

### 步骤 2: 只比较（跳过编译）

```bash
python3 scripts/compare_guji_layouts.py yourfile.tex yourfile-digital.tex --no-compile
```

## Layout JSON 结构

从 v0.2.9 开始,导出的 layout JSON 包含:

```json
{
  "version": "1.0",
  "generator": "luatex-cn",
  "source_file": "yourfile.tex",
  "source_mtime": 1771885547,
  "document": { ... },
  "page_summary": [
    {"page": 0, "type": "spread_right", "cols": ["欽定四庫全書", "", ...]},
    ...
  ],
  "pages": [ ... ]
}
```

- `page_summary`: 每页每列的简化文字内容（用于快速比较）
- `pages`: 完整的字符位置/坐标信息（用于精确分析）

## 相关文件

- **比较脚本**: `scripts/digitalize/compare_guji_layouts.py`
- **Export 模块**: `tex/core/luatex-cn-core-export.lua`
- **转换工具**:
  - `scripts/digitalize/semantic_to_digital.py` — 语义→数字化转换
  - `scripts/digitalize/digital_to_semantic.py` — 数字化→语义逆向转换
  - `scripts/digitalize/plugins/` — 转换插件（如四库全书简明目录）
