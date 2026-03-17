[English Version](EN:Digitalization) | 中文版

# 数字化排版与转换

`luatex-cn` 提供了一套完整的数字化工作流，旨在将物理古籍或已完成的语义排版文件，转换为布局完全一致（Pixel-perfect）的数字化版本。

## 1. 核心概念：语义 vs 布局

在 `luatex-cn` 中，排版分为两种模式：

| 模式 | 文档类 | 特点 | 应用场景 |
| :--- | :--- | :--- | :--- |
| **语义模式** | `ltc-guji` | 自动分页、自动分栏、逻辑控制 | 新书创作、排版设计 |
| **布局模式** | `ltc-guji-digital` | 强制换列、显式缩进、布局固定 | 古籍数字化、排版还原 |

## 2. 数字化转换引擎 (`converter.py`)

`scripts/digitalize/converter.py` 是连接语义模式与布局模式的桥梁。它可以根据 `ltc-guji` 文件的内容，结合网格参数，生成对应的数字化 TeX 代码。

### 使用方法

```bash
python3 scripts/digitalize/converter.py --input source.tex --output target-digital.tex
```

### 插件机制
如果你的模板有自定义命令，可以编写插件进行扩展：
```bash
python3 converter.py --input in.tex --output out.tex --plugin plugins/my_plugin.py
```

## 3. 数字化专用命令

`ltc-guji-digital` 文档类通过加载 `luatex-cn-digital` 宏包，提供了一系列直接控制布局的命令。在数字化模式下，正文环境默认开启 `obeylines`，即 TeX 代码中的每个换行都对应排版中的一个新列。

### 缩进与抬头
- **`\缩进[N]`**：设置当前列的开启位置。
  - `N > 0`: 向下缩进 $N$ 个字（用于段落首行、条目等）。
  - `N < 0`: 向上抬头 $N$ 个字（用于抬头格式，进入版心区域）。

### 双列夹注
为了精确还原夹注的分栏，使用显式的双列控制：
```latex
\双列{
  \右小列{右侧子列文字}
  \左小列{左侧子列文字}
}
```

### 版心显式控制
在数字化过程中，往往需要手动指定每一页的页码或章节名：
```latex
\begin{版心}
  \版心章节{卷一}
  \版心页码{十五}
  \上鱼尾
\end{版心}
```

## 4. 数字化工作流建议

1. **准备语义稿**：首先使用 `ltc-guji` 编写文档，确保内容正确。
2. **运行转换器**：使用 `converter.py` 生成数字化初稿。
3. **精细调校**：在生成的 `-digital.tex` 文件中，根据实际版面微调 `\缩进` 参数或处理特殊的排版溢出。
4. **编译导出**：编译数字化版本，并可结合 [[排版坐标导出 | Layout-Export]] 功能生成 JSON 数据供下游系统使用。

---

下一步：查看 [[功能详解 | Features]] | [[排版坐标导出 | Layout-Export]] | [[命令索引 | Command-Reference]]
