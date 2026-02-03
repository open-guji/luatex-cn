[English Version](EN:Development) | 中文版

# 开发文档

本文档详细介绍 `luatex-cn` 排版引擎的核心架构、源文件结构、组件关系以及开发流程。

---

## 1. 源文件结构

### 1.1 目录总览

```
tex/
├── ltc-guji.cls              # 古籍文档类（用户入口）
├── ltc-book.cls              # 通用书籍文档类
├── luatex-cn.sty             # 顶层宏包（兼容性入口）
├── luatex-cn-core.sty        # 核心功能聚合包
│
├── core/                     # 核心渲染引擎（最关键）
│   ├── luatex-cn-core-main.lua          # 主流程协调器
│   ├── luatex-cn-core-flatten-nodes.lua # 节点展平
│   ├── luatex-cn-layout-grid.lua        # 网格布局计算
│   ├── luatex-cn-core-render-page.lua   # 页面渲染
│   ├── luatex-cn-core-content.sty/.lua  # 正文环境
│   ├── luatex-cn-core-page.sty/.lua     # 页面设置
│   ├── luatex-cn-core-page-split.lua    # 筒子页分割
│   ├── luatex-cn-core-sidenote.sty/.lua # 侧批系统
│   ├── luatex-cn-core-textbox.sty/.lua  # 文本框/悬浮框
│   ├── luatex-cn-core-textflow.sty/.lua # 夹注分列
│   ├── luatex-cn-core-paragraph.sty     # 段落缩进
│   ├── luatex-cn-core-metadata.sty/.lua # 元数据（书名、章节）
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
│   └── luatex-cn-guji-danye.sty/.lua    # 单页模式
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
│   └── luatex-cn-decorate.lua           # 装饰实现
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
    ├── luatex-cn-guji-default.cfg       # 默认配置
    ├── luatex-cn-guji-SiKuQuanShu-colored.cfg  # 四库全书彩色
    └── luatex-cn-guji-HongLouMengJiaXuBen.cfg  # 红楼梦甲戌本
```

### 1.2 组件关系图

```
                    ┌─────────────────┐
                    │  ltc-guji.cls   │  ← 用户文档类入口
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
            -- 递归展平
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
        -- 插入定位 kern 和 PDF 指令
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
| `ltc-book.cls` | 通用书籍 | `luatex-cn-core` |

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
| `luatex-cn-core-sidenote.sty` | 侧批 | `\SideNote{}` |
| `luatex-cn-core-textbox.sty` | 文本框 | `\TextBox{}` |
| `luatex-cn-core-paragraph.sty` | 段落 | `\begin{段落}` |

### 3.3 古籍功能 (guji/)

| 文件 | 功能 | 关键命令 |
|------|------|----------|
| `luatex-cn-guji-judou.sty` | 句读 | `\。\、` |
| `luatex-cn-guji-jiazhu.sty` | 夹注 | `\JiaZhu{}` |
| `luatex-cn-guji-pizhu.sty` | 批注 | `\PiZhu{}` |
| `luatex-cn-guji-meipi.sty` | 眉批 | `\MeiPi{}` |
| `luatex-cn-guji-yinzhang.sty` | 印章 | `\YinZhang{}` |

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
-- 注册样式，返回唯一 ID
local style_id = style_registry.register({
    color = {1, 0, 0},
    font_size = 19,
    grid_height = 20
})

-- 将 ID 附加到节点
D.set_attribute(node, ATTR_STYLE_REG_ID, style_id)

-- Layout 阶段自动保存到 layout_map
-- Render 阶段自动应用样式
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
    -- 初始化：设置默认参数
    initialize = function(params, engine_ctx)
        return processed_params
    end,

    -- 布局：计算位置
    layout = function(list, layout_map, engine_ctx, context)
        -- 填充 layout_map
    end,

    -- 渲染：生成 PDF
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

## 6. 参与开发

### 6.1 环境准备

1. **Fork 仓库**：点击 GitHub 右上角的 Fork
2. **Clone**：`git clone git@github.com:YOUR_NAME/luatex-cn.git`
3. **安装依赖**：
   - LuaTeX（TeX Live 2024+）
   - Python 3.8+（用于回归测试）
   - ImageMagick（用于图像比较）

### 6.2 测试

```bash
# 回归测试（推荐）
python3 test/regression_test.py check

# 测试单个文件
python3 test/regression_test.py check test/regression_test/tex/shiji.tex

# 更新基线（确认改动正确后）
python3 test/regression_test.py save test/regression_test/tex/shiji.tex
```

### 6.3 代码规范

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

### 6.4 提交规范

```
类型: 简短描述

详细说明（可选）

Fixes #issue_number
```

类型：`fix`, `feat`, `refactor`, `docs`, `test`

---

## 7. 关键技术细节

### 7.1 竖排流向 (RTT)

```latex
\pardir RTT \textdir RTT
```

- 文本从上到下流动
- 行从右到左堆叠
- `\hsize` 定义列高度

### 7.2 属性管理

```lua
-- 设置属性
D.set_attribute(node, ATTR_JIAZHU, 1)

-- 读取属性
local val = D.get_attribute(node, ATTR_JIAZHU)
```

> ⚠️ `\selectfont` 会清除所有属性，务必在设置字体后重新设置属性。

### 7.3 节点所有权

```lua
-- 交给 TeX（转移所有权）
tex.box[box_num] = node_list

-- 需要重用时必须复制
tex.box[box_num] = node.copy_list(original)
```

### 7.4 PDF 绘制顺序

PDF 遵循画家模型（后画覆盖先画）：

1. 背景色（最先）
2. 边框
3. 版心
4. 文字内容
5. 调试框架（最后）

---

## 8. 开发经验总结

详细经验请参阅项目中的 `ai_must_read/LEARNING.md`。

### 常见陷阱

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| 颜色不生效 | 使用颜色名称 | 使用归一化 RGB：`0 0 0 rg` |
| 跨页颜色丢失 | 颜色堆栈断开 | 通过 layout_map 传递颜色 |
| `\directlua` 失效 | `--` 注释被线性化 | 使用 `--[[ ]]--` 或独立 lua 文件 |
| expl3 空格丢失 | `ExplSyntaxOn` 忽略空格 | 使用 `~` 代替空格 |

---

👉 返回：[[功能详解 | Features]] | [[调试模式 | Debug]] | [[首页 | Home]]
