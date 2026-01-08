# cn_vertical - 中文竖排包

这是一个用于 LuaTeX 的中文竖排包，专注于实现传统古籍竖排版式。

---

## 目录

- [快速开始](#快速开始)
- [实现原理](#实现原理)
- [当前功能](#当前功能)
- [技术细节](#技术细节)
- [未来规划](#未来规划)
- [安装方法](#安装方法)
- [参考资料](#参考资料)

---

## 快速开始

### 最简单的例子

```latex
\documentclass{article}
\usepackage{fontspec}
\setmainfont{SimSun}
\usepackage{cn_vertical}

\begin{document}

横排文字：一二三四五

\verticaltext{竖排文字：一二三四五}

横排文字继续

\end{document}
```

编译：
```bash
lualatex document.tex
```

---

## 实现原理

### 当前实现方案：TeX 层布局 + Lua 层字符分割

本包采用**简单直接**的方案，避免了复杂的节点回调处理：

#### 核心思路

1. **Lua 层**：负责将文本按 UTF-8 字符分割
2. **TeX 层**：使用 `\vbox` 和 `\hbox` 完成垂直布局
3. **字体特性**：启用 OpenType `vert` 特性处理标点符号

#### 关键代码

**Lua 模块** ([cn_vertical.lua](cn_vertical.lua))：

```lua
function cn_vertical.split_to_vbox(text)
    tex.print("\\vbox{")
    for i = 1, utf8.len(text) do
        local offset_start = utf8.offset(text, i)
        local offset_end = utf8.offset(text, i+1)
        if offset_start and offset_end then
            local char = text:sub(offset_start, offset_end - 1)
            -- 将每个字符包裹在 \hbox 中
            if char ~= " " then  -- 跳过空格
                tex.print("\\hbox{" .. char .. "}")
            end
        end
    end
    tex.print("}")
end
```

**LaTeX 命令** ([cn_vertical.sty](cn_vertical.sty))：

```latex
\newcommand{\verticaltext}[1]{%
  \par\noindent
  \addfontfeatures{RawFeature=+vert}%  % 启用竖排标点特性
  \directlua{cn_vertical.split_to_vbox([===[#1]===])}%
  \par
}
```

### 为什么这样实现？

#### ✅ 优点

1. **简单可靠**：利用 TeX 原生的盒子机制，不需要复杂的节点操作
2. **易于理解**：代码逻辑清晰，便于维护和扩展
3. **字符正确竖排**：每个字符独立成盒，从上到下自然堆叠
4. **汉字保持正立**：不需要旋转，符合传统竖排规范

#### ⚠️ 当前限制

1. **环境支持有限**：`\begin{vertical}...\end{vertical}` 环境暂时有问题（Lua 字符串中的 TeX 大括号冲突）
2. **西文字符未旋转**：英文字母和数字目前不会旋转 90 度
3. **标点位置简单**：仅依赖 OpenType `vert` 特性，未做精细调整
4. **单列竖排**：暂不支持多列从右到左的传统竖排布局

### LuaTeX-ja 的方案对比

LuaTeX-ja 使用更复杂但更强大的方法：

#### LuaTeX-ja 的架构

1. **核心机制**：`dir` 属性
   - 在节点级别设置方向属性（TTV = Top-to-Bottom Vertical）
   - 引擎自动处理字符堆叠方向

2. **字符分类处理**：
   - **汉字/假名**：不旋转，通过 OpenType `vmtx`（垂直度量）表获取尺寸
   - **西文/数字**：旋转 90°，使用虚拟字体或 PDF 变换
   - **标点符号**：查询 OpenType `vert`/`vrt2` 特性，替换为竖排字形

3. **回调函数**：
   - `pre_linebreak_filter`：在断行前处理节点
   - `hpack_filter`：在水平打包时介入
   - `post_linebreak_filter`：在断行后调整

#### 为什么我们暂时不用回调？

**现阶段的选择**：
- ✅ **简单场景优先**：当前的 `\vbox`/`\hbox` 方案已能满足基本竖排需求
- ✅ **避免复杂性**：节点回调需要深入理解 LuaTeX 内部机制，容易出错
- ✅ **快速迭代**：简单方案便于测试和调试

**未来的扩展**：
- ⏭️ **复杂标点处理**：引号、破折号等需要在回调中精确定位
- ⏭️ **西文字符旋转**：需要在节点级别包裹 PDF 旋转命令
- ⏭️ **格子系统**：固定字符宽度、界栏定位需要回调支持
- ⏭️ **禁则处理**：行首行尾标点规则需要在断行时介入

---

## 当前功能

### ✅ 已实现

1. **基础竖排**
   - `\verticaltext{文字}` 命令
   - 汉字从上到下垂直排列
   - 字符保持正立（不旋转）

2. **字体支持**
   - 自动启用 OpenType `vert` 特性
   - 支持标点符号竖排字形替换（如果字体包含）

3. **横竖混排**
   - 可在横排文档中插入竖排内容
   - 使用 `\par` 自动换段

4. **字符识别**
   - 支持 CJK 统一表意文字：U+4E00 - U+9FFF
   - 支持 CJK 扩展 A：U+3400 - U+4DBF
   - 支持兼容汉字：U+F900 - U+FAFF
   - 支持扩展 B+：U+20000 - U+2A6DF

### ⏳ 部分实现

1. **vertical 环境**
   - 已定义但有问题（Lua 字符串转义冲突）
   - 建议暂时使用 `\verticaltext` 命令

### ❌ 未实现

1. **西文字符旋转**：英文字母、数字不会旋转 90°
2. **多列竖排**：从右到左的多列布局
3. **格子系统**：固定字符宽度、界栏
4. **高级标点**：引号、破折号等的精确定位
5. **双行夹注**：小字双行注释
6. **禁则处理**：行首行尾标点规则

---

## 技术细节

### 文件结构

```
cn_vertical/
├── cn_vertical.sty    # LaTeX 包文件（1.5KB）
├── cn_vertical.lua    # Lua 模块（901 字节）
└── README.md          # 本文档
```

### 编译要求

- **TeX 引擎**：必须使用 LuaLaTeX
- **字体**：需要中文 TrueType/OpenType 字体（如 SimSun、宋体）
- **编码**：源文件使用 UTF-8 编码

### 命令与环境

#### `\verticaltext{text}`

将文本竖排显示。

**语法**：
```latex
\verticaltext{要竖排的文字}
```

**示例**：
```latex
横排：一二三四五

\verticaltext{竖排：一二三四五}

继续横排
```

**注意事项**：
- 自动在前后插入 `\par`（段落分隔）
- 会跳过空格字符
- 自动启用 OpenType `vert` 特性

#### `vertical` 环境（实验性）

```latex
\begin{vertical}
竖排文字
\end{vertical}
```

**当前状态**：有 bug，不推荐使用。请使用 `\verticaltext` 命令。

### 性能特点

- **轻量级**：无复杂回调，开销小
- **UTF-8 处理**：使用 Lua 5.3+ 原生 `utf8` 库
- **内存友好**：不复制节点，直接生成 TeX 命令

---

## 未来规划

### 第一阶段：完善基础功能

1. **修复 vertical 环境**
   - 解决 Lua 字符串转义问题
   - 支持环境内换行

2. **字符间距调整**
   - 添加可配置的字符间距选项
   - 支持紧凑/宽松模式

### 第二阶段：引入回调处理

当需要处理以下复杂场景时，将引入 LuaTeX 回调函数：

1. **西文字符旋转**
   - 在 `hpack_filter` 中检测非 CJK 字符
   - 使用 PDF literal 节点包裹旋转命令
   - 调整字符盒子的尺寸

2. **精确标点处理**
   - 在 `pre_linebreak_filter` 中识别标点类型
   - 查询字体的 `vert`/`vrt2` 特性
   - 调整标点位置（如引号、括号）

3. **格子系统**
   - 实现固定字符宽度
   - 计算行格和界栏位置
   - 支持"计字排版"

### 第三阶段：高级排版功能

1. **多列竖排**
   - 从右到左的多列布局
   - 自动分栏
   - 支持页面级排版

2. **双行夹注** (warichu)
   - 在 `pre_linebreak_filter` 中拆分节点
   - 缩小字号，双行排列
   - 嵌入主行

3. **禁则处理**
   - 行首禁则字符（如标点）
   - 行尾禁则字符
   - 自动调整断行

4. **避讳与抬头**
   - 检测特定词汇
   - 自动缺笔或换行
   - 支持传统古籍格式

### 架构演进计划

```
当前阶段：TeX 层布局
  ↓
  简单、可靠、易维护
  适合基本竖排需求

第二阶段：混合模式
  ├─ TeX 层：处理简单汉字竖排
  └─ Lua 回调：处理复杂情况（西文、标点、格子）

第三阶段：完整回调
  └─ 完全在 Lua 层控制布局，类似 LuaTeX-ja
```

---

## 安装方法

### 方式 1：使用 `\input@path`（推荐用于测试）

```latex
\documentclass{article}
\makeatletter
\def\input@path{{path/to/cn_vertical/}}
\makeatother
\usepackage{cn_vertical}
```

### 方式 2：安装到本地 TeX 树（推荐用于日常使用）

#### 查找本地 TeX 树位置

```bash
kpsewhich -var-value=TEXMFLOCAL
```

常见路径：
- **Windows (TeX Live)**: `C:\texlive\texmf-local`
- **macOS (MacTeX)**: `/usr/local/texlive/texmf-local`
- **Linux**: `/usr/local/texmf` 或 `~/texmf`

#### 安装文件

将文件复制到：
```
TEXMFLOCAL/tex/latex/cn_vertical/
├── cn_vertical.sty
└── cn_vertical.lua
```

#### 刷新文件名数据库

**Windows**（管理员权限）:
```cmd
mktexlsr
```

**macOS/Linux**:
```bash
sudo mktexlsr
```

#### 开发时使用符号链接

**Windows**（管理员权限，CMD）:
```cmd
mklink /D "C:\texlive\texmf-local\tex\latex\cn_vertical" "C:\path\to\luatex-cn\cn_vertical"
mktexlsr
```

**macOS/Linux**:
```bash
ln -s /path/to/luatex-cn/cn_vertical /usr/local/texlive/texmf-local/tex/latex/cn_vertical
sudo mktexlsr
```

这样修改源代码后会立即生效，无需重复复制。

### 方式 3：设置环境变量

**Linux/macOS**:
```bash
export TEXINPUTS=.:path/to/cn_vertical//:$TEXINPUTS
lualatex document.tex
```

**Windows PowerShell**:
```powershell
$env:TEXINPUTS="path/to/cn_vertical//;"
lualatex document.tex
```

---

## 参考资料

### LuaTeX-ja 架构

本包的设计参考了 LuaTeX-ja 的实现思路：

1. **回调函数机制**
   - `pre_linebreak_filter`：断行前处理
   - `hpack_filter`：水平打包时处理
   - `post_linebreak_filter`：断行后调整

2. **属性标记系统**
   - 使用 `\attribute` 标记竖排区域
   - 在回调中读取属性值
   - 条件性地应用处理

3. **节点操作**
   - 使用 `node.direct` API 提升性能
   - 复制、插入、删除节点
   - 创建新的盒子节点

### 竖排排版原理

1. **字符方向**
   - 汉字：保持正立（upright）
   - 西文：旋转 90° 顺时针
   - 标点：使用 OpenType `vert` 特性替换字形

2. **OpenType 特性**
   - `vert`：竖排字形替换
   - `vrt2`：更精确的竖排变体
   - `vmtx`：垂直字体度量

3. **坐标系统**
   - TeX 默认左下角为原点
   - 竖排时需要转换坐标：`y_phys = y_start - (count × grid_size)`

### 相关资源

- **LuaTeX 手册**：[luatex.org](http://luatex.org)
- **LuaTeX-ja 文档**：[osdn.net/projects/luatex-ja](https://osdn.net/projects/luatex-ja/)
- **OpenType 特性**：[Adobe OpenType Features](https://adobe-type-tools.github.io/font-tech-notes/pdfs/5176.CJK_Special_Forms.pdf)

---

## 许可证

[待定]

---

## 更新日志

### v0.2.0 (2025-01-08)

- ✅ 实现基于 `\vbox`/`\hbox` 的简单竖排方案
- ✅ 添加 `\verticaltext` 命令
- ✅ 支持 OpenType `vert` 特性
- ✅ UTF-8 字符正确分割
- ⚠️ `vertical` 环境有 bug（已知问题）

### v0.1.0

- 初始版本（已废弃，使用了复杂的节点回调方案）
