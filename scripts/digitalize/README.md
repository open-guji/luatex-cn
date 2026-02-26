# luatex-cn 数字化工具集

本目录包含古籍数字化转换和验证的完整工具链。

## 📁 目录结构

```
scripts/digitalize/
├── README.md                    # 本文档
├── README_REVERSE.md            # Digital→Semantic 转换详细文档
├── compare_guji_layouts.py      # 🔍 Layout 比较工具（主力）
├── semantic_to_digital.py       # ➡️ 语义→数字化转换
├── digital_to_semantic.py       # ⬅️ 数字化→语义逆向转换
└── plugins/                     # 转换插件
    └── siku_mulu_to_semantic.py # 四库全书简明目录插件
```

## 🛠️ 工具说明

### 1. compare_guji_layouts.py - Layout 一致性验证

**用途**: 验证 semantic→digital 转换的排版一致性

**功能**:
- ✅ 自动编译检测（避免重复编译）
- ✅ page_summary 快速比较（无坐标，仅文字）
- ✅ 生成详细 Markdown 报告
- ✅ PDF 页面截图对比（需要 `pdftoppm`）
- ✅ 智能时间戳验证（基于 `source_mtime`）

**使用示例**:
```bash
# 基本用法：自动检测、编译、比较
python3 scripts/digitalize/compare_guji_layouts.py original.tex digital.tex

# 强制重新编译
python3 scripts/digitalize/compare_guji_layouts.py original.tex digital.tex --force

# 只比较已有 JSON（跳过编译）
python3 scripts/digitalize/compare_guji_layouts.py original.tex digital.tex --no-compile

# 指定报告输出路径
python3 scripts/digitalize/compare_guji_layouts.py original.tex digital.tex -o report.md
```

**Claude Code 技能**: `/compare-layouts`

---

### 2. semantic_to_digital.py - 语义→数字化转换

**用途**: 将 `ltc-guji.cls`（语义模式）文件转换为 `ltc-guji-digital.cls`（布局模式）

**典型工作流**:
```
第 1 册手工排版 (semantic) → converter → digital 版本 → 验证一致性
```

**使用示例**:
```bash
python3 scripts/digitalize/semantic_to_digital.py \
  --input 原文件.tex \
  --output 原文件-digital.tex \
  --plugin scripts/digitalize/plugins/siku_mulu.py
```

**Claude Code 技能**: `/convert-to-digital`

---

### 3. digital_to_semantic.py - 数字化→语义逆向转换

**用途**: 将 `ltc-guji-digital.cls` 文件转换回 `ltc-guji.cls`（语义模式）

**典型工作流**:
```
OCR 扫描 → digital TeX (布局模式) → reverse converter → semantic TeX (语义模式)
```

**应用场景**:
- **第 2-10 册**: OCR 生成 digital TeX → 转换为 semantic TeX 用于后续编辑
- **批量校对**: 手工调整 digital 版本后转回 semantic

**使用示例**:
```bash
python3 scripts/digitalize/digital_to_semantic.py \
  --input 冊一-digital.tex \
  --output 冊一.tex \
  --plugin scripts/digitalize/plugins/siku_mulu_to_semantic.py
```

**转换规则**:
| Digital | Semantic |
|---------|----------|
| `\双列{\右小列{...}\左小列{...}}` | `\夹注{...}` |
| `\缩进[N]` + 多行 | `\begin{段落}[indent=N]...\end{段落}` |
| `　` 全角空格缩进 | `\条目[level]{...}` |
| `\换页` | `\newpage` |

详细文档: [README_REVERSE.md](README_REVERSE.md)

---

### 4. plugins/ - 转换插件

**用途**: 处理模板特有的命令（如四库全书的 `\國朝`、`\注`、`\按` 等）

**已有插件**:
- `siku_mulu_to_semantic.py` — 四库全书简明目录专用

**插件接口**:
```python
class DigitalToSemanticPlugin:
    def preprocess_line(self, line: str) -> Optional[str]:
        """预处理单行（可选）"""
        return None

    def recognize_pattern(self, lines: List[str], index: int) -> Optional[Tuple[str, int]]:
        """识别模板特有的模式，返回 (转换后的内容, 消耗的行数)"""
        return None

    def postprocess_content(self, content: str) -> str:
        """后处理转换后的内容（可选）"""
        return content
```

---

## 📊 完整工作流示例

### 示例 1: 验证第 1 册转换质量

```bash
# 步骤 1: 转换 semantic → digital
python3 scripts/digitalize/semantic_to_digital.py \
  --input 全书复刻/欽定四庫全書簡明目錄/tex/欽定四庫全書簡明目錄冊一.tex \
  --output 全书复刻/欽定四庫全書簡明目錄/tex/欽定四庫全書簡明目錄冊一-digital.tex \
  --plugin scripts/digitalize/plugins/siku_mulu.py

# 步骤 2: 验证排版一致性
cd 全书复刻/欽定四庫全書簡明目錄/tex && \
python3 ../../../scripts/digitalize/compare_guji_layouts.py \
  欽定四庫全書簡明目錄冊一.tex \
  欽定四庫全書簡明目錄冊一-digital.tex

# 查看报告
cat 排版一致性比较报告.md
```

### 示例 2: OCR 后生成语义版本

```bash
# 步骤 1: OCR 生成 digital TeX（假设已完成）

# 步骤 2: 转换 digital → semantic
python3 scripts/digitalize/digital_to_semantic.py \
  --input 冊二-digital.tex \
  --output 冊二.tex \
  --plugin scripts/digitalize/plugins/siku_mulu_to_semantic.py

# 步骤 3: 手工校对 semantic 版本
vim 冊二.tex

# 步骤 4: 编译验证
lualatex 冊二.tex
```

---

## 🧪 测试与验证

### 单元测试
```bash
# 测试 layout export 功能
ENABLE_EXPORT=1 lualatex yourfile.tex
# → 生成 yourfile-layout.json

# 验证 JSON 结构
python3 -c "import json; print(json.load(open('yourfile-layout.json'))['page_summary'][0])"
```

### 回归测试
```bash
# 对比原始与数字化版本
python3 scripts/digitalize/compare_guji_layouts.py original.tex digital.tex --force

# 查看差异统计
grep "匹配页数" 排版一致性比较报告.md
```

---

## 📚 相关文档

- **核心文档**: `ai_must_read/LEARNING.md` — 开发经验与陷阱
- **技能**: `.claude/commands/compare-layouts.md` — Claude Code 集成
- **Export 模块**: `tex/core/luatex-cn-core-export.lua` — Layout JSON 导出
- **四库全书工作流**: `全书复刻/欽定四庫全書簡明目錄/README.md`

---

## 🔧 依赖

- **Python 3.8+**
- **LuaTeX** (texlive 2020+)
- **pdftoppm** (可选，用于 PDF 截图比较)
  ```bash
  sudo apt install poppler-utils  # Debian/Ubuntu
  brew install poppler            # macOS
  ```

---

## 📝 更新日志

| 日期 | 更改 |
|------|------|
| 2026-02-24 | 整合所有比较脚本到 `compare_guji_layouts.py` |
| 2026-02-23 | 添加 `page_summary` 字段支持 |
| 2026-02-22 | 引入 `ENABLE_EXPORT` 环境变量 |
| 2026-02-20 | 添加 digital→semantic 逆向转换器 |

---

**维护者**: @lishaodong
**License**: Apache 2.0
