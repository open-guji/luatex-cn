[English Version](EN:Punctuation) | 中文版

# 标点系统 (v0.2.7+)

`luatex-cn` 提供了完整的现代标点处理系统，支持标点挤压、禁则处理、竖排引号替换，以及大陆/台湾两种标点风格。

## 标点系统 vs 句读系统

`luatex-cn` 有两套标点处理机制，**互斥**运行：

| 系统 | 适用场景 | punct-mode | 说明 |
|------|---------|------------|------|
| **标点系统** (本页) | 现代书籍排版 | `normal` (默认) | 处理挤压、禁则、引号替换 |
| **[[句读系统 \| Judou]]** | 古籍排版 | `judou` 或 `none` | 将标点转为圆圈/点或移除 |

当 `punct-mode=normal` 时，标点系统启用；当 `punct-mode=judou` 或 `none` 时，句读系统启用、标点系统自动禁用。

## 标点风格

### 台湾风格 (默认)

所有标点居中显示在网格单元内，这是默认设置。

```latex
\punctSetup{punct-style=taiwan}
% 或
\台湾标点风格
```

### 大陆风格

句号（。）、逗号（，、）等偏向网格单元的右上角，更符合大陆出版物的排版习惯。

```latex
\punctSetup{punct-style=mainland}
% 或
\大陆标点风格
```

## 配置参数

通过 `\punctSetup` 配置标点行为：

```latex
\punctSetup{
    punct-style = taiwan,    % 标点风格：taiwan 或 mainland
    punct-squeeze = true,    % 标点挤压：将标点压缩为半格
    kinsoku = true,          % 禁则处理：防止标点出现在不当位置
    punct-hanging = false,   % 标点悬挂（开发中）
}
```

| 参数 | 说明 | 默认值 | 可选值 |
|------|------|--------|--------|
| `punct-style` | 标点风格 | `taiwan` | `taiwan`, `mainland` |
| `punct-squeeze` | 标点挤压 | `true` | `true`, `false` |
| `kinsoku` | 禁则处理 | `true` | `true`, `false` |
| `punct-hanging` | 标点悬挂 | `false` | `true`, `false` |

## 标点挤压 (punct-squeeze)

启用后，句号、逗号等标点会被压缩为半个网格单元的高度，使排版更加紧凑美观。

```latex
% 启用标点挤压（默认）
\punctSetup{punct-squeeze=true}

% 禁用标点挤压
\punctSetup{punct-squeeze=false}
```

## 禁则处理 (kinsoku)

遵循中文排版规范 (CLREQ)，防止标点出现在不当位置：

- **行首禁则**：闭括号 `」』）〉》】〕`、句号 `。．`、逗号 `，、`、中间标点 `：；！？` 不允许出现在列首
- **行末禁则**：开括号 `「『（〈《【〔` 不允许出现在列末

```latex
% 启用禁则处理（默认）
\punctSetup{kinsoku=true}

% 禁用禁则处理
\punctSetup{kinsoku=false}
```

## 竖排引号替换

标点系统会自动将水平形式的括号和引号替换为 Unicode 竖排形式：

| 水平形式 | 竖排形式 |
|---------|---------|
| 「 | ﹁ |
| 」 | ﹂ |
| 『 | ﹃ |
| 』 | ﹄ |
| （ | ︵ |
| ） | ︶ |
| 《 | ︽ |
| 》 | ︾ |
| — | ︱ |
| … | ︙ |

## 在 cn-vbook / tw-vbook 中使用

`ltc-cn-vbook` / `ltc-tw-vbook` 文档类默认启用标点系统。通过模板选择不同风格：

```latex
% 默认模板：台湾风格
\documentclass{ltc-cn-vbook}

% 中华书局模板：大陆风格
\documentclass[中华书局]{cn-vbook}
```

也可以在文档中随时切换：

```latex
\documentclass{ltc-cn-vbook}
\punctSetup{punct-style=mainland}  % 覆盖默认的台湾风格

\begin{document}
\begin{正文}
天地玄黄，宇宙洪荒。日月盈昃，辰宿列张。
\end{正文}
\end{document}
```

## 在 guji 中使用

`ltc-guji` 文档类也支持标点系统。当 `punct-mode=normal` 时，标点系统自动生效：

```latex
\documentclass[四库全书]{guji}
\正常标点模式  % 使用现代标点（而非句读）
\punctSetup{punct-style=mainland}

\begin{document}
\begin{正文}
天地玄黄，宇宙洪荒。
\end{正文}
\end{document}
```

## 与句读模式的切换

可以在文档中动态切换标点系统和句读系统：

```latex
% 使用现代标点
\正常标点模式
天地玄黄，宇宙洪荒。  % 现代标点显示

% 切换到句读模式
\句读模式
天地玄黄，宇宙洪荒。  % 逗号变为小点，句号变为小圈

% 切换到白文模式（无标点）
\无标点模式
天地玄黄宇宙洪荒      % 所有标点被移除
```

## 技术细节

标点处理在 Lua 层通过 `luatex-cn-core-punct.lua` 模块实现，分三个阶段：

1. **Flatten 阶段**：分类标点字符（开括号、闭括号、句号、逗号、中间标点、不可断），替换竖排形式
2. **Layout 阶段**：执行标点挤压和禁则处理
3. **Render 阶段**：应用大陆/台湾风格的位置偏移

---

下一步：查看 [[句读 | Judou]] | [[现代竖排 | ltc-book]] | [[功能详解 | Features]]
