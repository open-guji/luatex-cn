# luatex-cn 项目上下文

> Claude Code 会自动读取此文件。这是项目的核心知识库入口。

## 项目概述

**luatex-cn** 是一个用于排版中国古籍的 LuaTeX 包，支持竖排、句读、夹注、批注、眉批、版心等传统古籍排版功能。

- **GitHub**: https://github.com/open-guji/luatex-cn
- **许可证**: Apache 2.0
- **当前版本**: 0.3.4

## 核心指令

1. **说中文** - 与用户交流使用中文
2. **先读文档** - 开始前通读 `ai_must_read/` 文件夹
3. **使用 Context7 MCP** - 需要 API 文档时自动使用

## 必读文档

每次对话开始时，先浏览这些文档：

| 文档 | 内容 | 何时读取 |
|------|------|----------|
| `ai_must_read/LEARNING.md` | 开发经验与教训（Lua/TeX 陷阱、渲染问题） | **必读** - 避免重复踩坑 |
| `ai_must_read/design.md` | 架构设计文档 | 实现新功能前 |
| `ai_must_read/ONGOING.md` | 正在进行的工作 | 了解当前开发状态 |
| `ai_must_read/expl3_note.md` | expl3 语法详解（参数展开、xparse陷阱） | **遇到 expl3 问题时必读** |

## expl3 问题速查

遇到以下问题时，**必须先阅读** `ai_must_read/expl3_note.md`：

- 参数展开问题（`\exp_args:N...`、`:n`/`:V`/`:x` 区别）
- xparse 可选参数 `[...]` 传递变量
- Token list 与整数展开差异
- `\lua_now:e` 中的空格处理
- Key-Value 布尔值传递

## 项目结构

```
tex/
├── core/           # 核心渲染引擎
│   ├── luatex-cn-core-render-page.lua   # 主渲染逻辑
│   ├── luatex-cn-core-layout-grid.lua   # 网格布局
│   ├── luatex-cn-core-page.sty          # 页面设置
│   └── luatex-cn-core-sidenote.lua      # 侧批处理
├── guji/           # 古籍功能
│   ├── luatex-cn-guji-judou.sty         # 句读
│   ├── luatex-cn-guji-jiazhu.sty        # 夹注
│   ├── luatex-cn-guji-pizhu.sty         # 批注
│   └── luatex-cn-guji-yinzhang.sty      # 印章
├── banxin/         # 版心相关
├── decorate/       # 装饰元素
├── configs/        # 模板配置文件
└── debug/          # 调试工具

test/
├── unit_test/        # 单元测试（24 个文件，texlua 运行）
│   ├── util/         # 工具函数测试
│   ├── core/         # 核心渲染引擎测试
│   ├── guji/         # 古籍功能测试
│   ├── decorate/     # 装饰元素测试
│   ├── banxin/       # 版心测试
│   ├── fonts/        # 字体检测测试
│   └── debug/        # 调试模块测试
├── run_all.lua       # 运行全部 unit test
├── test_utils.lua    # 测试框架（mock + assert）
├── regression_test/  # 视觉回归测试
│   ├── tex/          # 测试用 .tex 文件
│   ├── baseline/     # 基准图像
│   └── current/      # 当前输出
└── regression_test.py

.claude/
├── CLAUDE.md         # 项目指令（本文件）
├── commands/         # 可用技能 (skills)
└── settings.json     # 权限配置
```

## 常用命令

### 单元测试（Unit Test）
```bash
# 运行全部 unit test（必须先通过再跑 regression test）
texlua test/run_all.lua

# 运行单个测试文件
texlua test/unit_test/core/layout-grid-test.lua
```

### 回归测试（Regression Test）
```bash
# 运行所有测试
python3 test/regression_test.py check

# 测试单个文件
python3 test/regression_test.py check test/regression_test/tex/shiji.tex

# 更新基线（确认改动正确后）
python3 test/regression_test.py save test/regression_test/tex/shiji.tex
```

### 编译测试
```bash
# 在 test/regression_test/tex 目录下编译
cd test/regression_test/tex && lualatex shiji.tex

# 带调试输出
lualatex -interaction=nonstopmode shiji.tex 2>&1 | grep -E "\[DEBUG\]|\[ERROR\]"

# 导出 layout JSON（用于 converter 验证）
ENABLE_EXPORT=1 lualatex yourfile.tex
# 生成 yourfile-layout.json
```

### Git 操作
```bash
# 查看最近提交
git log --oneline -10

# 查找引入 bug 的提交
git bisect start
git bisect bad HEAD
git bisect good <known-good-commit>
```

### GitHub CLI
```bash
# 查看当前 issues
gh issue list

# 查看 issue 详情
gh issue view <issue-number>

# 创建 PR
gh pr create --title "标题" --body "描述"
```

## 渲染流程（三阶段）

```
Stage 1: Flatten      → 展平节点（处理 HLIST/VLIST）
Stage 2: Layout Grid  → 计算位置（填充 layout_map）
Stage 3: Render Page  → 应用坐标、绘制 PDF
```

## 技能列表

| 技能 | 用途 |
|------|------|
| `/startup` | 每次对话开始时读取上下文 |
| `/fix-github-issue` | 修复 GitHub Issue 的完整流程 |
| `/regression-test` | 运行回归测试 |
| `/summarize-experience` | 总结经验到 LEARNING.md |
| `/update_changelog` | 更新 CHANGELOG |
| `/release_process` | 发布新版本流程 |

## 开发标准

### expl3 编程规范
- 所有 LaTeX 代码必须使用 expl3 (LaTeX3 编程层)
- 使用 `\ExplSyntaxOn` / `\ExplSyntaxOff` 块
- 变量名中不能有数字
- 命名约定: `\luatexcn_<module>_<action>:<signature>`
- 数据类型: `\tl_`, `\seq_`, `\prop_`, `\bool_`, `\int_` 等

### Lua 代码规范
- 复杂逻辑放在独立 `.lua` 文件
- `\directlua` 只负责 `require()` 和简单调用
- 避免在 `\directlua` 中使用 `--` 行注释

## 重要提醒

1. **说中文** - 与用户交流使用中文
2. **先读文档** - 开始前通读 `ai_must_read/` 文件夹
3. **测试工作流（必须遵守）**：
   - **先 unit test** → `texlua test/run_all.lua`，确保全部通过
   - **再 regression test** → `python3 test/regression_test.py check`
   - 如果代码改动会导致 unit test 结果变化，**必须同时更新对应的 unit test**
   - 不允许跳过 unit test 直接运行 regression test
4. **记录经验** - 非平凡问题解决后使用 `/summarize-experience`
5. **小步提交** - 每次只修一个问题
6. **expl3 标准** - 所有 TeX 代码使用 expl3

## 当前开发状态

查看 `ai_must_read/ONGOING.md` 了解：
- 正在进行的功能开发
- 待修复的 bug
- 近期计划

---

# 项目记忆
---

## Unit Test 工作流 (Critical)

- **测试顺序**: 先 `texlua test/run_all.lua` → 再 `python3 test/regression_test.py check`
- **改动源码时必须同步更新 unit test**（如果会影响测试结果）
- 24 个测试文件覆盖 util/core/guji/decorate/banxin/fonts/debug 层
- Mock 基础设施在 `test/test_utils.lua`，包含 node/tex/font/texio/luatexbase/token/utf8 的 mock
- `_internal` 表用于白盒测试（layout-grid, flatten-nodes, render-page, render-position 等模块已导出）
- **常见坑**: `new_attribute` mock 必须返回不同 ID（用递增计数器），否则属性碰撞导致测试失败
- **0-indexed pages**: `group_nodes_by_page` 使用 0-indexed 页码
- **`node.direct` vs `node` API**: mock 中 `D.setfield(n, "list", child)` 和 `n.head = child` 是不同的 key

---

## ltc-guji-digital Class

### 什么是 ltc-guji-digital

`ltc-guji-digital` 是一个面向古籍**数字化录入**的 document class，与 `ltc-guji`（语义排版）是对应关系。

- `ltc-guji`（ltc-guji.cls）：**语义模式** — 使用 `\夹注{...}`、`\段落`、`\列表` 等高级语义命令，引擎自动计算夹注分栏
- `ltc-guji-digital`：**布局模式** — 每行源码 = 一个竖排列，用 `\双列` 手动指定每列的左右小列内容，精确复刻原书版面

### 核心机制

- **obeylines**: `\begin{数字化内容}` 内每个 `^^M`（换行符）= 一个新列
- **不自动换列**: 字满了不会自动换到下一列（`auto_column_wrap = false`）
- **`\换页`**: 等效于 `\newpage`，当已经在新页开头时会自动跳过（防止对开模式空白页）

### 可用命令

#### 环境
| 命令 | 用途 |
|------|------|
| `\begin{数字化内容}` / `\begin{DigitalContent}` | 主内容环境（obeylines 模式） |
| `\begin{版心}` / `\begin{Banxin}` | 版心定义 |
| `\begin{版心中部}` / `\begin{BanxinMiddle}` | 版心中间区域 |

#### 布局命令（digital 专有）
| 命令 | 用途 | 示例 |
|------|------|------|
| `\双列{\右小列{...}\左小列{...}}` | 手动指定双列（夹注） | `\双列{\右小列{集解裴駰曰}\左小列{索隠紀者記}}` |
| `\缩进[N]` | 设置当前列缩进 | `\缩进[1] 史記卷一` |
| `\换页` | 强制换页 | 单独一行使用 |

#### 通用命令（guji/digital 共用）
| 命令 | 用途 |
|------|------|
| `\印章[opts]{file}` | 印章叠加 |
| `\填充文本框[N]{text}` | 固定宽度文本框 |
| `\空格` | 一个全角空格 |
| `\title{...}` / `\chapter{...}` | 书名/章节（preamble） |
| `\版心上部` / `\版心下部` / `\版心章节` / `\版心页码` | 版心子元素 |
| `\上鱼尾` / `\下鱼尾` | 鱼尾标记 |

#### 不可用命令（ltc-guji.cls 专有，ltc-guji-digital 中不存在）
| 命令 | 替代方案 |
|------|----------|
| `\夹注{...}` | 用 `\双列{\右小列{...}\左小列{...}}` 手动分栏 |
| `\段落` / `\begin{段落}` | 用 `\缩进[N]` + 换行控制 |
| `\列表` / `\begin{列表}` | 用 `\缩进[N]` 模拟层级 |
| `\正文` / `\begin{正文}` | 用 `\begin{数字化内容}` 替代 |

### 双列分栏规则

每列总字数 = 21（默认），正文与夹注共享一列时：
- 每小列可用字数 = 21 - N正文字数
- 纯夹注行：每小列 21 字
- 当正文尾部夹注不足一行时，可以和下一段正文的开头夹注合并到同一行

### 关键注意事项

1. **不要在 `数字化内容` 中使用 `%` 注释行** — obeylines 模式下 `%` 会吃掉换行符，导致相邻行合并为一列
2. **`\印章` 后加 `%`** — 防止印章命令后的换行产生空列：`\印章[...]{file}%`
3. **`\换页` 单独一行** — 前后不要有其他内容
4. **正文直接写，不需要 `\par` 或空行** — 换行符自动分列

### 完整示例

参考文件：`test/digital_test/史记五帝-layout.tex`（完美复刻 `示例/史记五帝本纪/史记.tex`）

---

## Phase 2 Auto Column Width (Free Mode) - 经验总结

**Infrastructure complete**: Layout records `col_widths_sp[page][col]`, render applies via `_var` functions.

**TitlePage still uses legacy `col_widths`** — `sync_page_columns_from_col_widths()` timing issue blocks migration to `n_column=0`. Fixing requires redesigning `calc_page_columns()` timing (columns register *during* BodyText but page_columns computed *before*).

**Key commits**: `77cf034`→`f7a017e`→`96af315`→`ab70194`

### 核心问题: TitlePage vs Free Mode 的架构冲突

| 维度 | TitlePage (旧) | Free Mode (Phase 2 尝试) |
|------|---------------|------------------------|
| **触发条件** | `init_col_widths()` 初始化 | `n_column=0` |
| **page_columns** | 先用 col_widths.length,后用 sync 设置 | 直接设为 nil |
| **col_widths 语义** | 输入 (用户通过 `\行[width=5cm]` 预设) | 输出 (layout 阶段自动计算) |

### 关键教训

1. **架构冲突必须先解决,不能 workaround** — 添加 `is_titlepage` 标志绕过冲突是错误做法
2. **语义重载是技术债的根源** — `col_widths` 既是输入又是输出 → 混乱
3. **渐进式实施 > 一次性大重构** — Phase 2 应拆成 4 个小步骤,每步独立测试
4. **测试驱动开发** — 每次修改后立即运行全量测试
5. **类型安全在动态语言中更重要** — 显式检查 `type(grid_width) == "number"`

---

## Key Patterns

- **先 unit test 再 regression test**: `texlua test/run_all.lua` → `python3 test/regression_test.py check`
- Debug PDF content with Python: decompress streams, search for `cm` commands
- `font.getfont(fid).characters[charcode]` to check if font has a glyph
- `ATTR_DECORATE_ID` check in flatten to skip decoration overlay characters
- texmf dir is symlinked to source — changes are picked up automatically
- **Incremental commits**: Break large features into small testable steps (not "big bang" rewrites)
- **Type safety in Lua**: Always check `type(var) == "number"` before numeric comparison

---

## 参考文档

- expl3: https://ctan.org/pkg/l3kernel
- LuaTeX: https://www.luatex.org/
- 项目文档: `ai_must_read/` 目录
