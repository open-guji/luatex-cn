---
description: 将 ltc-guji.cls 文件转换为 ltc-guji-digital 格式
---

# ltc-guji.cls → ltc-guji-digital 转换工作流

将使用 `ltc-guji`（语义模式）编写的古籍排版文件转换为 `ltc-guji-digital`（布局模式）格式。

## 前置知识

先阅读 memory 中的 `guji_digital.md` 了解 ltc-guji-digital 的命令体系。

参考完整示例：
- 原始 ltc-guji.cls 文件：`示例/史记五帝本纪/史记.tex`
- 转换后 digital 文件：`test/digital_test/史记五帝-layout.tex`

## 转换步骤

### 1. 文件头替换

```tex
% ltc-guji.cls:
\documentclass[四库全书彩色]{ltc-guji}

% ltc-guji-digital:
\documentclass[SiKuQuanShu-colored]{ltc-guji-digital}
```

模板名称映射：`四库全书彩色` → `SiKuQuanShu-colored`

### 2. 内容环境替换

```tex
% ltc-guji.cls:
\begin{正文} ... \end{正文}

% ltc-guji-digital:
\begin{数字化内容} ... \end{数字化内容}
```

### 3. 列表结构 → 缩进

ltc-guji.cls 的 `\列表` 嵌套转换为 `\缩进[N]`：
- 第一层列表项 → `\缩进[1]`
- 第二层列表项 → `\缩进[2]`
- 以此类推

```tex
% ltc-guji.cls:
\begin{列表}
    \item 史記卷一
    \item
    \begin{列表}
        \item \填充文本框[12]{漢太史令}司馬遷\空格 撰
    \end{列表}
    \item 五帝本紀第一
\end{列表}

% ltc-guji-digital:
\缩进[1] 史記卷一
\缩进[2] \填充文本框[12]{漢太史令}司馬遷\空格 撰
\缩进[1] 五帝本紀第一
```

### 4. 夹注转换（核心难点）

这是转换中最复杂的部分。ltc-guji.cls 的 `\夹注{全部注释文字}` 需要手动分栏为 `\双列{\右小列{...}\左小列{...}}`。

#### 4.1 确定每列字数

默认每列 21 字。当正文和夹注共享一列时：
- 每小列可用字数 = 21 - N正文字数
- 例如：`黄帝者`（3字）→ 每小列 18 字，一行 36 字

#### 4.2 分栏算法

用 Python 脚本辅助计算：

```python
def split_annotation(text, chars_per_subcol=21):
    """将注释文字按每小列 chars_per_subcol 字分栏"""
    pos = 0
    lines = []
    while pos < len(text):
        right = text[pos:pos+chars_per_subcol]
        left = text[pos+chars_per_subcol:pos+2*chars_per_subcol]
        lines.append((right, left))
        pos += 2 * chars_per_subcol
    return lines
```

#### 4.3 正文+夹注混合行

当正文字符和夹注在同一行：

```tex
% 正文"黄帝者"(3字) + 夹注，每小列 21-3=18 字：
黄帝者\双列{\右小列{集解徐廣曰號有熊索隠按有土徳之瑞土色}\左小列{黄故稱黄帝猶神農火徳王而稱炎帝然也此}}
```

#### 4.4 多段正文拼接

当上一段夹注尾部字数不足一整行，可以和下一段正文+夹注拼在同一列：

```tex
% 上段夹注尾(11+11) + 正文"生而神靈弱而能言"(8字) + 下段夹注头(3+3) = 21+21
\双列{\右小列{為名又以為號是本姓公}\左小列{孫長居姬水因改姓姬}}生而神靈弱而能言\双列{\右小列{索隠弱}\左小列{謂幼弱}}
```

计算规则：同一行所有元素（上段夹注尾 + 正文 + 下段夹注头）的总字符 = 21+21 = 42

### 5. 段落处理

```tex
% ltc-guji.cls:
\begin{段落}[indent=3]
\夹注{...长文本...}
\end{段落}

% ltc-guji-digital:
\缩进[3]\双列{\右小列{...}\左小列{...}}
\缩进[3]\双列{\右小列{...}\左小列{...}}
... (逐行，每行 21+21 字)
```

注意：`\缩进[N]` 只影响当前列，所以段落中的每一行都需要加 `\缩进[3]`。

### 6. 印章命令

```tex
% ltc-guji.cls（可以有详细位置参数）:
\印章[page=1, opacity=0.7, color=black, xshift=5.3cm, yshift=6.7cm, width=12.9cm]{文渊阁宝印.png}

% ltc-guji-digital（简化，位置由模板决定；末尾加 % 防止空列）:
\印章[page=1,opacity=0.7,color=black]{文渊阁宝印.png}%
```

**关键**：印章命令后必须加 `%`，否则换行符会产生空列。

### 7. 换页

ltc-guji.cls 中的内容自然流动不需要手动换页。ltc-guji-digital 中如果需要在特定位置换页：

```tex
\换页
```

单独占一行，前后不要有其他内容。

## 关键注意事项

1. **不要在 `数字化内容` 中使用 `%` 注释** — 会吃掉换行符导致两行合并
2. **不要使用 ltc-guji.cls 专有命令** — `\夹注`、`\段落`、`\列表`、`\正文` 在 digital 中不存在
3. **空行 = 空列** — 源码中的空行会在输出中产生一个空白列
4. **每行一列** — 这是 digital 模式的核心：源码的物理行 = 输出的竖排列
5. **验证方法** — 转换后编译，与原文件的 PDF 逐页对比，应该像素级一致

## 验证

```bash
# 编译转换后的文件
cd test/digital_test && lualatex 史记五帝-layout.tex

# 与原文件对比页数和外观
cd 示例/史记五帝本纪 && lualatex 史记.tex

# 两个 PDF 应该页数相同、内容一致
```
