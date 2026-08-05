[English Version](EN:Punctuation) | 中文版

# 标点系统 (v0.2.7+)

`luatex-cn` 提供了完整的现代标点处理系统，支持标点挤压、禁则处理、竖排引号替换，以及中国大陆/台湾两种标点风格。

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

### 中国大陆风格

句号（。）、逗号（，、）等偏向网格单元的右上角，更符合中国大陆出版物的排版习惯。

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
    punct-hanging = false,   % 行尾点号悬挂（默认关）
}
```

| 参数 | 说明 | 默认值 | 可选值 |
|------|------|--------|--------|
| `punct-style` | 标点风格 | `taiwan` | `taiwan`, `mainland` |
| `punct-squeeze` | 标点挤压 | `true` | `true`, `false` |
| `kinsoku` | 禁则处理 | `true` | `true`, `false` |
| `punct-hanging` | 行尾点号悬挂（详见下文） | `false` | `true`, `false` |

### clreq 预设键（与横排同名同值）

> ⚠️ 本节参数尚未进入发行版（最新发行版 v0.3.8），请从 main 分支获取。

除上表的原有参数外，`\punctSetup`（中文别名 `\标点设置`）还提供一组与[[横排管道 | Horizontal]] **键名与取值完全一致**的 clreq 预设，方便同一份文稿在竖排与横排之间保持体例：

| 参数 | 中文别名 | 说明 | 默认值 | 可选值 |
|------|---------|------|--------|--------|
| `style` | `标点风格` / `风格预设` | 整体风格预设；`none` = clreq「不调整」，既不挤压也不偏靠 | 随文档类 | `mainland`, `taiwan`, `none` |
| `squeeze-mode` | `宽度调整` | 标点宽度调整的判定方式：`legacy` 无条件挤压（`ltc-guji` 默认，版面零变化）；`context` 上下文相关，仅相邻标点／列首列末触发（`ltc-cn-vbook` / `ltc-tw-vbook` 默认） | `legacy` | `legacy`, `context` |
| `adjacent-punct` | `连续标点` | 连续标点缩减量（字幅） | `1.5` | `1.5`, `1`, `natural` |
| `line-start-bracket` | — | 列首的开始夹注符号缩减始侧半字 | `trim` | `trim`, `natural` |
| `line-end-punct` | — | 列末点号缩减末侧半字 | `compress` | `compress`, `natural` |
| `western-space` | `中西间距` | 汉字与西文字母/数字间自动加 1/4em 间距（详见下文「中西混排」） | `true` | `true`, `false` |

> **上下文相关的宽度调整**（clreq）：夹在汉字之间的单个标点占满一字幅，只有相邻标点连排时才缩减（夹注符号参与时 2 → 1.5 字幅，`adjacent-punct=1` 可收到 1 字幅）。挤压方向按 clreq「空白在哪一侧就往哪边让」。

> **字面分布**按字形墨迹度量锚定，不依赖字体自身的字面设计：中国大陆式直排偏靠右上，台湾式横竖一律居中。因此用台湾字体排中国大陆式、或用中国大陆字体排台湾式，落点都与规范一致。

## 行尾点号悬挂 (punct-hanging)

> ⚠️ 尚未进入发行版（最新发行版 v0.3.8），请从 main 分支获取。

clreq 的行尾点号悬挂：落在**列末**的点号（句号、逗号等）整个字幅移出列内，挂在版口之外，列内正文不再因它被压缩。clreq 注明悬挂适用于直排（横排港台式因点号居中不宜悬挂）。

```latex
\punctSetup{punct-hanging=true}   % 中文别名：标点悬挂
```

默认关闭——悬挂会改变既有文档的版面，是否启用属于本书体例的选择。仅在 `squeeze-mode=context` 挡位（`ltc-cn-vbook` / `ltc-tw-vbook` 默认）生效。

## 中西混排 (clreq)

> ⚠️ 尚未进入发行版（最新发行版 v0.3.8），请从 main 分支获取。

### 中西间距

按 clreq，汉字与西文字母/数字之间自动加 **1/4 汉字宽**的间距，参与行内调整（可挤压至 1/8、拉伸至 1/2）。三类例外不加间距：中文点号前后、开始夹注符号之后、结束夹注符号之前。

- 规则与横排宏包同源（`tex/shared/luatex-cn-cjk-western.lua`），两种模式体例一致。
- 数字串仍是不可拆的整体（符号分离禁则）：串内保持基准字距，两端照常有中西间距。
- 仅在 `squeeze-mode=context` 挡位生效；`western-space=false`（中文别名 `中西间距`）可关闭。

### 西文横置 `\横置`

clreq 直排中西混排的三种配置中，「顺时针旋转 90°」由 `\横置`（别名 `\橫置` / `\Sideways`）实现——适合较长的西文词句；单个字母或缩略语通常直立逐字入格即可（引擎默认行为）：

```latex
引用\横置{LuaTeX}之名继续排版。
年份\横置{2026}与长词\横置{Typography}混排。
```

横置串的字母连排成词（内部无字距、不被均排撑散），共用一条竖直基线，横向居中于列，与前后汉字照常有 1/4em 中西间距。

### 标点扩类

连接号（～ - –）、间隔号（· ・ ‧）、分隔号（/ ／）已并入分类体系：三类均受行首禁则约束；**中国大陆式间隔号 `·` 固定占半个字宽**（clreq 附录 A GB 式，如人名「爱新觉罗·玄烨」），台湾式占一字宽。

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

% 中华书局模板：中国大陆风格
\documentclass[中华书局]{ltc-cn-vbook}
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
\documentclass[四库全书]{ltc-guji}
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
3. **Render 阶段**：应用中国大陆/台湾风格的位置偏移

---

下一步：查看 [[句读 | Judou]] | [[现代竖排 | ltc-book]] | [[功能详解 | Features]]
