[English Version](EN:Horizontal) | 中文版

# 现代横排（luatex-cn-hori）

`luatex-cn-hori` 是按 W3C [《中文排版需求》(clreq)](https://www.w3.org/TR/clreq/) 实现的**横排**中文排版宏包。它不是文档类，而是一个可以加载到任何横排文档类（`article`、`book`、`report` 等）之上的宏包，负责在 `pre_linebreak_filter` / `post_linebreak_filter` 阶段插入禁则罚点与可调间距。

规则内核放在 `tex/shared/`（clreq 附录标点全表、一维优先级空间分配器、四级禁则模块），与竖排共用同一份数据源。

> ⚠️ **本页功能尚未进入发行版**（最新发行版为 v0.3.8）。请从 [main 分支](https://github.com/open-guji/luatex-cn) 获取。

> **前置条件**
> - 必须使用 **LuaTeX**（`lualatex`），其他引擎会直接报错。
> - 与 **luatexja 互斥**。`ctex` 在 LuaLaTeX 下会自动载入 luatexja，两者都在同一批回调里做 CJK 间距与禁则，同时启用会双重处理，宏包检测到会报错。请只用其中一个。
> - 中文字体请用 `fontspec` 显式指定，并写上 `Script=CJK` 与 `Language`。省略时 luaotfload 按 `latn/dflt` 起排，该语言系统的 `locl` 会把省略号替换成贴基线的西文字形，破折号也拿不到满格中文形。

---

## 最小示例

```latex
\documentclass[12pt]{article}
\usepackage[paperwidth=10cm, paperheight=16cm, margin=1.2cm]{geometry}
\usepackage{fontspec}
\setmainfont{Source Han Serif SC}[Script=CJK, Language={Chinese Simplified}]
\usepackage{luatex-cn-hori}
\begin{document}
中文与 Western text 混排时，中西之间会自动插入四分之一字宽的可调间距。
标点、禁则、段首缩排两字都按 clreq 自动处理。
\end{document}
```

台湾式（居中标点）：

```latex
\usepackage[style=taiwan]{luatex-cn-hori}
```

---

## 宏包选项

选项可在 `\usepackage[...]{luatex-cn-hori}` 时给出，也可以在正文中用 `\horiSetup{...}`（中文别名 `\横排设置{...}`）随时修改，改动对其后的段落生效。

### 标点与间距

| 键 | 取值 | 默认 | 说明 |
|----|------|------|------|
| `style` | `mainland` / `taiwan` / `none` | `mainland` | 标点风格预设。`mainland` 标点偏靠始端、空白留在末端；`taiwan` 字面居中；`none` 为 clreq「不调整」预设，既不挤压也不偏靠 |
| `cjk-latin-space` | 布尔 | `true` | 中西文之间插入 1/4 em 间距（可挤到 1/8、拉到 1/2；clreq 规定的三类例外不加） |
| `inter-cjk-stretch` | 字宽比例 | `0.05` | 汉字之间的兜底伸展量（最后手段） |
| `adjacent-punct` | `1.5` / `1` / `natural` | `1.5` | 连续标点缩减。clreq 规定夹注符号连排「无论何种风格」都应由 2 字宽缩到 1.5；`1` 进一步收到 1 字宽；`natural` 只按行紧度挤压 |
| `line-start-bracket` | `trim` / `natural` | `trim` | 行首的开始夹注符号缩减始侧半字（含段首缩进的首行） |
| `line-end-punct` | `compress` / `natural` | `compress` | 行末标点半字宽（clreq 挤压第 1 级）。`compress` 总是回收空白并重新分配给该行；`natural` 只按该行的紧度回收 |
| `hanging-punct` | 布尔 | `false` | 行尾点号悬挂：行末点号整字悬于版口之外。港台式点号居中不宜悬挂，故默认关闭 |
| `quote-style` | `keep` / `auto` / `curly` / `corner` | `keep` | 引号体例转换。默认 `keep` 不改动来稿用字；`auto` 按 `style` 选择；`curly`（简体横排先双后单）/ `corner`（台湾传统先单后双）显式指定，嵌套深度一一映射保持 |

### 换行与行内分配

| 键 | 取值 | 默认 | 说明 |
|----|------|------|------|
| `kinsoku-level` | `none` / `basic` / `gb` / `strict` | `basic` | 换行禁则等级，clreq 推荐 `basic` |
| `line-adjust` | 布尔 | `true` | 行内优先级二次分配（clreq 挤压 7 级 / 拉伸 2 级，末位兜底均分） |

### 段落与页面

| 键 | 取值 | 默认 | 说明 |
|----|------|------|------|
| `paragraph-indent` | 长度 / `keep` | `2em` | 段首缩排。clreq 规定以两个汉字的空间为准；在 `\begin{document}` 时按正文主字体解析，`keep` 表示不动 `\parindent` |
| `orphan-char` | 布尔 | `true` | 段末孤字避免：末行只剩一个汉字时向前行借字 |
| `last-line` | `left` / `center` / `right` / `justify` | `left` | 段末行对齐。clreq 规定正文末行不均排（即默认的 `left`）；名单、表格标题等求体例一致时可用 `justify` |
| `widow-penalty` | 整数 | `10000` | 页首孤行罚值（10000 = 禁止） |
| `club-penalty` | 整数 | `10000` | 页尾孤行罚值 |

### 行间注

| 键 | 取值 | 默认 | 说明 |
|----|------|------|------|
| `ruby-size` | 比例 | `0.5` | 注文相对基文的字号比 |
| `ruby-gap` | 字宽比例 | `0.1` | 注文与基文两行之间的间距 |

---

## 命令

### 设置

```latex
\horiSetup{last-line=right}      % 中文别名：\横排设置
```

### 行间标号（H3）

单面装体例，标号画在文字**下方**。

| 命令 | 别名 | 效果 |
|------|------|------|
| `\专名{...}` | — | 专名号（直线） |
| `\书名号甲{...}` | `\书名甲` | 书名号甲式（波浪线） |
| `\着重{...}` | — | 着重号（点，位置在线之下） |

```latex
太史公\专名{司马迁}著\书名号甲{史记}，其文\着重{究天人之际，通古今之变}。
```

- 相邻的两个专名各自分开画，不连成一条。
- 着重号不加在标点上。
- clreq 要求行间标注的行距（行的间空）≥ 0.5 em，不足时标注会贴到下一行字面。宏包检测到第一次违反时会给出一次 warning，可用 `\linespread{1.6}` 之类放大行距。

### 行间注 / 标音（H4）

```latex
\ruby{基文}{注文}          % 中文别名：\拼音、\对照
```

```latex
\拼音{中国}{zhōng guó}的\拼音{汉字}{hàn zì}历史悠久；
\对照{印刷}{printing}术的发明意义重大。
```

- 注文按**空格分词连写**：`{zhōng guó}` 是两个音节，与基文两个字按 clreq 词对齐。
- 较短的一行在整块宽度内均匀展开（两端各半个空位），较长的一行实排。
- 注文字号与行距由 `ruby-size` / `ruby-gap` 控制。

### 均排

字均匀分布于指定宽度，两端字紧贴边界；用于标题、表格单元格等。

```latex
\均排{目录}                 % 默认 \linewidth；别名 \EvenSpread
\均排[6em]{凡例}
```

> 行级的拉伸兜底均分由 `line-adjust` 的分配器完成，不需要手写 `\均排`。

### 段落排式（H5）

```latex
\begin{凸排}                % 可选参数为缩排量，默认 2em
首行顶格，第二行起固定缩排——词典释义、参考文献等。
\end{凸排}

\begin{段落缩排}            % 可选参数：左缩、右缩，默认 2em / 0pt
整段较版心缩进，常用于引文与按语。
\end{段落缩排}
```

### 号数字号

clreq「字号」一节的号数制，横竖排共享。

```latex
{\字号{三号} 三号标题\par}
{\字号{小四}[1.7] 行距为字号 1.7 倍的正文\par}
```

可选参数为行距倍数，省略时取共享层常量。可用号数：

| 号数 | pt | 号数 | pt | 号数 | pt |
|------|----|------|----|------|----|
| 初号 | 42 | 二号 | 22 | 五号 | 10.5 |
| 小初 | 36 | 小二 | 18 | 小五 | 9 |
| 一号 | 26 | 三号 | 16 | 六号 | 7.5 |
| 小一 | 24 | 小三 | 15 | 小六 | 6.5 |
| | | 四号 | 14 | 七号 | 5.5 |
| | | 小四 | 12 | 八号 | 5 |

---

## 与竖排的关系

横排与竖排共用 `tex/shared/` 下的 clreq 规则内核，因此标点分类、禁则等级、连续标点缩减的判定是同一份实现；`\标点设置` 的 `style` / `squeeze-mode` / `adjacent-punct` / `line-start-bracket` / `line-end-punct` 五个键，键名与取值也与本宏包一致。号数字号 `\字号` 横竖排通用。

## 规范符合性验证

`test/clreq_test.py` 解析横排 PDF 的内容流，按字形 x 坐标与 advance 对 clreq 条款逐条做度量断言（中西间距区间、点号旁与夹注号内侧无间距、行首行尾禁则、符号分离禁则、两字宽标点、行末标点半字宽、行间注词对齐等），每条断言注明所依据的 clreq 条款，并已并入 CI。

```bash
python3 test/clreq_test.py                 # 检查回归测试用的 hori.tex
python3 test/clreq_test.py yourfile.tex    # 检查你自己的横排文档
```

## 示例

**[论辩的魂灵（鲁迅）](https://github.com/open-guji/luatex-cn/tree/main/示例/论辩的魂灵)** — 同一篇文章的两种排法：繁体用 `style=taiwan`（居中标点）、简体用 `style=mainland` + `quote-style=curly`（直角引号自动转弯引号），演示连续标点缩减、行首行尾挤压、段末孤字避免与 `last-line=right` 落款。

---

👉 相关：[[标点系统 | Punctuation]] ｜ [[字体设置 | Fonts]] ｜ [[现代竖排 | ltc-book]]
