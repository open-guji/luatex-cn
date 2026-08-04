[English Version](EN:Development) | 中文版

# 开发文档

本文档详细介绍 `luatex-cn` 排版引擎的核心架构、源文件结构、测试体系以及开发流程。

---

## 1. 源文件结构

### 1.1 目录总览

```
tex/
├── ltc-guji.cls                  # 古籍文档类（推荐入口）
├── ltc-ltc-guji.cls              # 古籍文档类（兼容别名）
├── ltc-cn-vbook.cls              # 中国大陆竖排书籍
├── ltc-tw-vbook.cls              # 台湾竖排书籍
├── luatex-cn.sty             # 顶层宏包（兼容性入口）
├── luatex-cn-core.sty        # 核心功能聚合包
│
├── core/                     # 核心渲染引擎（最关键）
│   ├── luatex-cn-core-main.lua          # 主流程协调器
│   ├── luatex-cn-core-flatten-nodes.lua # 节点展平 (Stage 1)
│   ├── luatex-cn-layout-grid.lua        # 网格布局计算 (Stage 2)
│   ├── luatex-cn-core-render-page.lua   # 页面渲染 (Stage 3)
│   ├── luatex-cn-core-content.sty/.lua  # 正文环境
│   ├── luatex-cn-core-page.sty/.lua     # 页面设置
│   ├── luatex-cn-core-page-split.lua    # 筒子页分割
│   ├── luatex-cn-core-column.sty/.lua   # 列控制
│   ├── luatex-cn-core-style.sty         # 样式命令 (v0.2.8+)
│   ├── luatex-cn-core-sidenote.sty/.lua # 侧批系统
│   ├── luatex-cn-core-textbox.sty/.lua  # 文本框/悬浮框
│   ├── luatex-cn-core-textflow.sty/.lua # 夹注分列
│   ├── luatex-cn-core-paragraph.sty     # 段落缩进/抬头
│   ├── luatex-cn-core-metadata.sty/.lua # 元数据（书名、章节）
│   ├── luatex-cn-core-punct.sty/.lua    # 标点挤压与禁则
│   ├── luatex-cn-footnote.sty/.lua      # 脚注系统
│   ├── luatex-cn-constants.lua          # 常量定义
│   └── luatex-cn-render-position.lua    # 位置计算
│
├── guji/                     # 古籍特有功能
│   ├── luatex-cn-guji.sty               # 古籍功能聚合
│   ├── luatex-cn-guji-judou.sty/.lua    # 句读
│   ├── luatex-cn-guji-jiazhu.sty        # 夹注（双行小注）
│   ├── luatex-cn-guji-pizhu.sty         # 批注（悬浮框）
│   ├── luatex-cn-guji-meipi.sty/.lua    # 眉批
│   ├── luatex-cn-guji-yinzhang.sty      # 印章
│   ├── luatex-cn-guji-danye.sty/.lua    # 单页模式
│   ├── luatex-cn-guji-cover.sty         # 封面 (v0.2.8+)
│   ├── luatex-cn-guji-titlepage.sty     # 书名页
│   └── luatex-cn-guji-mulu.sty          # 目录条目
│
├── banxin/                   # 版心系统
│   ├── luatex-cn-banxin.sty             # 版心配置
│   ├── luatex-cn-banxin-main.lua        # 版心主逻辑
│   ├── luatex-cn-banxin-layout.lua      # 版心布局
│   ├── luatex-cn-banxin-render-banxin.lua  # 版心渲染
│   └── luatex-cn-banxin-render-yuwei.lua   # 鱼尾渲染
│
├── decorate/                 # 文本装饰
│   ├── luatex-cn-decorate.sty           # 装饰接口
│   ├── luatex-cn-decorate.lua           # 装饰实现
│   ├── luatex-cn-linemark.sty           # 线标（专名号/书名号）
│   └── luatex-cn-linemark.lua           # 线标实现
│
├── fonts/                    # 字体系统
│   ├── luatex-cn-font-autodetect.sty    # 字体自动检测
│   └── luatex-cn-font-autodetect.lua
│
├── debug/                    # 调试工具
│   ├── luatex-cn-debug.sty              # 调试接口
│   └── luatex-cn-debug.lua              # 调试实现
│
├── util/                     # 工具模块
│   ├── luatex-cn-utils.lua              # 通用工具
│   ├── luatex-cn-text-utils.lua         # 文本工具
│   ├── luatex-cn-drawing.lua            # 绘图工具
│   └── luatex-cn-style-registry.lua     # 样式注册表
│
└── configs/                  # 预设配置
    ├── luatex-cn-guji-default.cfg
    ├── luatex-cn-guji-SiKuQuanShu.cfg
    ├── luatex-cn-guji-SiKuQuanShu-colored.cfg
    ├── luatex-cn-guji-HongLouMengJiaXuBen.cfg
    ├── luatex-cn-vbook-default.cfg
    └── luatex-cn-vbook-ZhongHuaShuJu.cfg
```

### 1.2 组件关系图

```
                    ┌─────────────────┐
                    │   ltc-guji.cls      │  ← 用户文档类入口
                    └────────┬────────┘
                             │ \RequirePackage
                             ▼
                    ┌─────────────────┐
                    │ luatex-cn-core  │  ← 核心功能聚合
                    └────────┬────────┘
                             │
        ┌────────────────────┼────────────────────┐
        ▼                    ▼                    ▼
┌───────────────┐   ┌───────────────┐   ┌───────────────┐
│  core/*.sty   │   │  guji/*.sty   │   │ banxin/*.sty  │
│  核心模块      │   │  古籍功能     │   │  版心系统      │
└───────┬───────┘   └───────┬───────┘   └───────┬───────┘
        │                   │                   │
        ▼                   ▼                   ▼
┌───────────────┐   ┌───────────────┐   ┌───────────────┐
│  core/*.lua   │   │  guji/*.lua   │   │ banxin/*.lua  │
│  Lua 实现     │   │  Lua 实现     │   │  Lua 实现      │
└───────────────┘   └───────────────┘   └───────────────┘
```

### 1.3 核心模块依赖

```
luatex-cn-core-main.lua (主协调器)
    │
    ├── luatex-cn-core-flatten-nodes.lua  (Stage 1: 展平)
    │
    ├── luatex-cn-layout-grid.lua         (Stage 2: 布局)
    │       │
    │       ├── luatex-cn-constants.lua
    │       └── luatex-cn-style-registry.lua
    │
    └── luatex-cn-core-render-page.lua    (Stage 3: 渲染)
            │
            ├── luatex-cn-render-position.lua
            ├── luatex-cn-utils.lua
            └── luatex-cn-drawing.lua
```

---

## 2. 核心架构：三阶段渲染

`luatex-cn` 采用三阶段流水线架构：

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  Stage 1    │ → │  Stage 2    │ → │  Stage 3    │
│  Flatten    │    │  Layout     │    │  Render     │
│  展平节点    │    │  网格布局    │    │  页面渲染    │
└─────────────┘    └─────────────┘    └─────────────┘
```

### Stage 1: Flatten (展平)

将 TeX 的嵌套节点链表转换为线性 Lua 表。

```lua
-- luatex-cn-core-flatten-nodes.lua
function flatten.process(head)
    local list = {}
    for node in node.traverse(head) do
        if node.id == GLYPH then
            table.insert(list, node)
        elseif node.id == HLIST then
            flatten_hlist(node, list)
        end
    end
    return list
end
```

### Stage 2: Layout (布局)

计算每个字符的网格坐标，填充 `layout_map`。

```lua
-- luatex-cn-layout-grid.lua
layout_map[node] = {
    page = 1,        -- 页码
    col = 5,         -- 列号
    row = 3,         -- 行号（字符位置）
    x_sp = 123456,   -- x 坐标 (sp 单位)
    y_sp = 789012,   -- y 坐标 (sp 单位)
    color = "1 0 0", -- 颜色（可选）
    style_id = 42    -- 样式 ID（可选）
}
```

### Stage 3: Render (渲染)

根据 `layout_map` 将节点重新组装并输出 PDF 指令。

```lua
-- luatex-cn-core-render-page.lua
function render.process(head, layout_map, params)
    for node, pos in pairs(layout_map) do
        local x, y = position.calculate(pos, params)
        insert_at_position(head, node, x, y)
    end
    return head
end
```

---

## 3. 组件详解

### 3.1 文档类 (`.cls`)

| 文件 | 用途 | 加载的包 |
|------|------|----------|
| `ltc-guji.cls` | 古籍排版 | `luatex-cn-core` + `guji/*.sty` |
| `ltc-cn-vbook.cls` | 中国大陆竖排书籍 | `luatex-cn-core` + 标点系统 |
| `ltc-tw-vbook.cls` | 台湾竖排书籍 | `luatex-cn-core` + 标点系统 |

**ltc-guji.cls 加载顺序**：
```latex
\LoadClass{article}
\RequirePackage{luatex-cn-core}       % 核心功能
\RequirePackage{guji/luatex-cn-guji}  % 古籍功能聚合
```

### 3.2 核心宏包 (`.sty`)

| 文件 | 功能 | 关键命令 |
|------|------|----------|
| `luatex-cn-core-content.sty` | 正文环境 | `\begin{正文}` |
| `luatex-cn-core-page.sty` | 页面设置 | `\pageSetup{}` |
| `luatex-cn-core-column.sty` | 列控制 | `\Column{}` / `\行{}` |
| `luatex-cn-core-style.sty` | 样式覆盖 | `\Style{}` / `\样式{}` |
| `luatex-cn-core-sidenote.sty` | 侧批 | `\SideNode{}` |
| `luatex-cn-core-textbox.sty` | 文本框 | `\TextBox{}` |
| `luatex-cn-core-paragraph.sty` | 段落/抬头 | `\begin{段落}` / `\抬头` |
| `luatex-cn-core-punct.sty` | 标点系统 | `\punctSetup{}` |
| `luatex-cn-footnote.sty` | 脚注 | `\Footnote{}` / `\脚注{}` |

### 3.3 古籍功能 (guji/)

| 文件 | 功能 | 关键命令 |
|------|------|----------|
| `luatex-cn-guji-judou.sty` | 句读 | `\JudouOn` / `\句读模式` |
| `luatex-cn-guji-jiazhu.sty` | 夹注 | `\JiaZhu{}` / `\夹注{}` |
| `luatex-cn-guji-pizhu.sty` | 批注 | `\PiZhu{}` / `\批注{}` |
| `luatex-cn-guji-meipi.sty` | 眉批 | `\MeiPi{}` / `\眉批{}` |
| `luatex-cn-guji-yinzhang.sty` | 印章 | `\YinZhang{}` / `\印章{}` |
| `luatex-cn-guji-cover.sty` | 封面 | `\begin{封面}` |
| `luatex-cn-guji-titlepage.sty` | 书名页 | `\begin{书名页}` |
| `luatex-cn-guji-mulu.sty` | 目录条目 | `\条目` |

---

## 4. 排版上下文系统

### 4.1 问题背景

在跨页渲染时（如侧批、夹注跨页），需要保持以下属性：

| 类别 | 属性示例 | 典型场景 |
|------|----------|----------|
| 字体 | family, size, features | 正文 → 夹注 → 正文 |
| 颜色 | text_color, bg_color | 正文 → 侧批 → 跨页 |
| 布局 | indent, align, spacing | 段落 → 文本框 → 段落 |
| 网格 | grid_height | 大字 → 小字 → 大字 |

### 4.2 样式注册表

`luatex-cn-style-registry.lua` 提供多属性样式存储：

```lua
local style_id = style_registry.register({
    color = {1, 0, 0},
    font_size = 19,
    grid_height = 20
})

D.set_attribute(node, ATTR_STYLE_REG_ID, style_id)
```

### 4.3 上下文继承

```
[全局上下文: 黑色, 20pt, indent=0]
  ↓ 进入段落
[段落上下文: 继承颜色和字体, indent=2]
    ↓ 进入夹注
  [夹注上下文: 继承 indent=2, 覆盖 color=red, size=14pt]
    ↓ 退出夹注
[段落上下文: 恢复到 黑色, 20pt, indent=2]  ← 自动恢复
```

---

## 5. 插件系统

v0.2.0 引入标准化插件 API：

```lua
plugin = {
    initialize = function(params, engine_ctx)
        return processed_params
    end,
    layout = function(list, layout_map, engine_ctx, context)
    end,
    render = function(head, layout_map, params, context, ...)
        return modified_head
    end
}
```

### 已实现的插件

| 插件 | 阶段 | 功能 |
|------|------|------|
| `judou` | layout + render | 句读符号 |
| `sidenote` | layout + render | 侧批 |
| `textflow` | layout | 夹注分列 |
| `decorate` | render | 文本装饰 |
| `banxin` | render | 版心绘制 |

---

## 6. 测试体系

luatex-cn 有两层测试：**单元测试**（Lua 逻辑）和**回归测试**（PDF 视觉对比）。

### 6.1 测试执行顺序

> **必须先跑单元测试，再跑回归测试。** 不允许跳过单元测试直接运行回归测试。

```bash
# 第一步：运行全部单元测试
texlua test/run_all.lua

# 第二步：运行回归测试
python3 test/regression_test.py check
```

### 6.2 单元测试

#### 概述

- **运行环境**：`texlua`（LuaTeX 内置的 Lua 解释器）
- **测试框架**：`test/test_utils.lua`（自定义轻量框架）
- **测试文件**：24 个，约 3850 行代码，418 个测试用例
- **入口**：`test/run_all.lua`

#### 目录结构

```
test/
├── run_all.lua           # 运行全部单元测试
├── test_utils.lua        # 测试框架（mock + assert）
└── unit_test/
    ├── util/             # 工具函数测试
    │   ├── utils-test.lua
    │   ├── text-utils-test.lua
    │   ├── constants-test.lua
    │   └── drawing-test.lua
    ├── core/             # 核心引擎测试
    │   ├── flatten-nodes-test.lua
    │   ├── layout-grid-test.lua
    │   ├── layout-grid-helpers-test.lua
    │   ├── render-page-test.lua
    │   ├── render-position-test.lua
    │   ├── style-registry-test.lua
    │   ├── core-column-test.lua
    │   ├── core-metadata-test.lua
    │   ├── core-page-split-test.lua
    │   └── core-punct-test.lua
    ├── guji/             # 古籍功能测试
    │   ├── judou-test.lua
    │   ├── meipi-test.lua
    │   └── danye-test.lua
    ├── decorate/         # 装饰元素测试
    │   ├── decorate-test.lua
    │   └── linemark-test.lua
    ├── banxin/           # 版心测试
    │   ├── luatex-cn-banxin-main-test.lua
    │   ├── luatex-cn-banxin-render-banxin-test.lua
    │   └── luatex-cn-banxin-render-yuwei-test.lua
    ├── fonts/            # 字体检测测试
    │   └── luatex-cn-font-autodetect-test.lua
    └── debug/            # 调试模块测试
        └── debug-test.lua
```

#### 测试框架 API

`test/test_utils.lua` 提供以下核心 API：

```lua
local test_utils = require("test.test_utils")

-- 运行一个测试用例
test_utils.run_test("测试名称", function()
    -- 断言函数
    test_utils.assert_eq(actual, expected)        -- 相等
    test_utils.assert_neq(actual, expected)       -- 不等
    test_utils.assert_true(condition)             -- 为真
    test_utils.assert_false(condition)            -- 为假
    test_utils.assert_nil(value)                  -- 为 nil
    test_utils.assert_not_nil(value)              -- 不为 nil
    test_utils.assert_type(value, "string")       -- 类型检查
    test_utils.assert_contains(str, substring)    -- 字符串包含
    test_utils.assert_error(function() ... end)   -- 期望抛出错误
    test_utils.assert_near(actual, expected, tol) -- 数值近似
end)
```

#### Mock 基础设施

单元测试运行在 `texlua` 环境，没有完整的 TeX 引擎。`test_utils.lua` 提供了以下模块的 Mock：

| Mock 模块 | 说明 |
|-----------|------|
| `node` / `node.direct` | 节点创建、遍历、属性操作 |
| `tex` | `tex.box`、`tex.count`、属性分配 |
| `font` | `font.getfont()`、字符信息 |
| `texio` | 日志输出 |
| `luatexbase` | `new_attribute()` 等 |
| `token` | Token 扫描器 |
| `utf8` | UTF-8 编码工具 |

#### 编写新测试

1. 在对应目录下创建 `xxx-test.lua` 文件
2. 引入测试框架和被测模块：

```lua
local test_utils = require("test.test_utils")
local my_module = require("path.to.module")

test_utils.run_test("功能描述", function()
    -- 准备
    local input = ...
    -- 执行
    local result = my_module.some_function(input)
    -- 断言
    test_utils.assert_eq(result, expected)
end)
```

3. 在 `test/run_all.lua` 中添加对应的 `require` 行
4. 运行 `texlua test/run_all.lua` 验证

#### 常见陷阱

| 陷阱 | 说明 |
|------|------|
| `new_attribute` ID 碰撞 | Mock 中必须用递增计数器，返回不同 ID |
| 0-indexed 页码 | `group_nodes_by_page` 使用 0-indexed 页码 |
| `node.direct` vs `node` | Mock 中两套 API 使用不同的内部 key |
| `_internal` 导出 | 模块通过 `_internal` 表导出内部函数用于白盒测试 |

### 6.3 回归测试

#### 概述

通过编译 `.tex` 文件生成 PDF，将 PDF 渲染为图像后与基线图像进行像素级比较。

- **脚本**：`test/regression_test.py`
- **依赖**：Python 3.8+、ImageMagick（`compare` 命令）、Poppler（`pdftoppm`）

#### 测试套件

```
test/regression_test/
├── basic/              # 基础功能测试
│   ├── tex/            # .tex 源文件
│   ├── baseline/       # 基准图像 (.png)
│   └── current/        # 当前输出 (运行时生成)
├── past_issue/         # 历史 Bug 回归测试
│   ├── tex/
│   ├── baseline/
│   └── current/
└── example/            # 示例文件测试
    ├── tex/
    ├── baseline/
    └── current/
```

#### 常用命令

```bash
# 检查所有套件
python3 test/regression_test.py check

# 检查特定套件
python3 test/regression_test.py check --suite basic

# 检查单个文件
python3 test/regression_test.py check test/regression_test/basic/tex/shiji.tex

# 保存新基线（确认输出正确后）
python3 test/regression_test.py save test/regression_test/basic/tex/shiji.tex
```

#### 添加回归测试

1. 创建 `.tex` 文件到对应套件的 `tex/` 目录
2. 运行 `python3 test/regression_test.py save <路径>` 生成基线
3. 验证基线图像是否正确
4. 提交 `.tex` 文件和基线图像

#### 为 Bug 修复添加回归测试

修复 GitHub Issue 后，在 `past_issue/tex/` 下添加最小复现文件：

```latex
% issue_description_issue42.tex - 回归测试: 问题简述 (issue #42)
\documentclass{ltc-guji}
\关闭分页

\begin{document}
\begin{正文}
% 最小复现代码
\end{正文}
\end{document}
```

---

## 7. 参与开发

### 7.1 环境准备

1. **Fork 仓库**：点击 GitHub 右上角的 Fork
2. **Clone**：`git clone git@github.com:YOUR_NAME/luatex-cn.git`
3. **安装依赖**：
   - LuaTeX（TeX Live 2024+）
   - Python 3.8+（用于回归测试）
   - ImageMagick（`apt install imagemagick` 或 `brew install imagemagick`）
   - Poppler（`apt install poppler-utils` 或 `brew install poppler`）
4. **链接源码**：
   ```bash
   ln -s $(pwd)/tex ~/texmf/tex/latex/luatex-cn
   texhash
   ```

### 7.2 开发工作流

```bash
# 1. 创建功能分支
git checkout -b feat/my-feature dev

# 2. 修改代码

# 3. 运行单元测试
texlua test/run_all.lua

# 4. 如果修改了 Lua 逻辑，更新对应的单元测试

# 5. 运行回归测试
python3 test/regression_test.py check

# 6. 如果输出有预期变化，更新基线
python3 test/regression_test.py save <路径>

# 7. 提交
git add -p
git commit -m "feat: 简短描述"
```

### 7.3 代码规范

**TeX 代码**：必须使用 expl3
```latex
\cs_new_protected:Npn \luatexcn_func:n #1
  {
    \tl_set:Nn \l_tmpa_tl { #1 }
    \lua_now:e { module.process("\tl_use:N \l_tmpa_tl") }
  }
```

**Lua 代码**：复杂逻辑放独立文件
```lua
-- luatex-cn-module.lua
local M = {}

function M.process(text)
    -- 实现
end

package.loaded['module.luatex-cn-module'] = M
return M
```

**命名规范**：
- 所有用户命令提供三套名称：英文、简体中文、繁体中文
- 英文命令使用 PascalCase（如 `\Column`、`\TextBox`）
- Key-value 参数使用 kebab-case（如 `font-size`、`grid-height`）

### 7.4 提交规范

```
类型: 简短描述

详细说明（可选）

Fixes #issue_number
```

类型：`fix`, `feat`, `refactor`, `docs`, `test`, `chore`

---

## 8. 关键技术细节

### 8.1 竖排流向 (RTT)

```latex
\pardir RTT \textdir RTT
```

- 文本从上到下流动
- 行从右到左堆叠
- `\hsize` 定义列高度

### 8.2 属性管理

```lua
D.set_attribute(node, ATTR_JIAZHU, 1)
local val = D.get_attribute(node, ATTR_JIAZHU)
```

> ⚠️ `\selectfont` 会清除所有属性，务必在设置字体后重新设置属性。

### 8.3 节点所有权

```lua
-- 交给 TeX（转移所有权）
tex.box[box_num] = node_list
-- 需要重用时必须复制
tex.box[box_num] = node.copy_list(original)
```

### 8.4 PDF 绘制顺序

PDF 遵循画家模型（后画覆盖先画）：

1. 背景色（最先）
2. 边框
3. 版心
4. 文字内容
5. 调试框架（最后）

---

## 9. 开发经验总结

详细经验请参阅项目中的 `ai_must_read/LEARNING.md`。

### 常见陷阱

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| 颜色不生效 | 使用颜色名称 | 使用归一化 RGB：`0 0 0 rg` |
| 跨页颜色丢失 | 颜色堆栈断开 | 通过 layout_map 传递颜色 |
| `\directlua` 失效 | `--` 注释被线性化 | 使用 `--[[ ]]--` 或独立 lua 文件 |
| expl3 空格丢失 | `ExplSyntaxOn` 忽略空格 | 使用 `~` 代替空格 |
| 类型错误 | Lua 弱类型 | 比较前检查 `type(var) == "number"` |
| 嵌套 `\NewEnviron` 死循环 | 内层重定义 `\BODY` | 先保存到独立 tl 变量 |

---

👉 返回：[[功能详解 | Features]] | [[调试模式 | Debug]] | [[首页 | Home]]
