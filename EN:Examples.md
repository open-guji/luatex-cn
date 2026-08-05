English | [中文版](Examples)

# Examples

This directory contains multiple usage examples for the `luatex-cn` package, demonstrating everything from traditional ancient book typesetting to modern vertical and horizontal layouts.

## Example List

### 1. Records of the Grand Historian - Basic Annals of the Five Emperors

**Features**: Demonstrates highly complex ancient book typesetting.

**Capabilities**:
- Absolutely positioned red seals (overlaying text)
- Customized page center text with single fishtail
- Complex interlinear note typesetting
- Traditional black silk frame and indentation

![Shiji B&W](https://raw.githubusercontent.com/open-guji/luatex-cn/main/示例/首页展示/shiji-bw.png)

📂 [View Source](https://github.com/open-guji/luatex-cn/tree/main/示例/史记五帝本纪)

---

### 2. Annotated Catalogue of the Siku Quanshu - Table of Contents

**Features**: The Wenyuan Pavilion edition, in Qing Dynasty "Siku Quanshu" style.

![Siku Catalogue](https://raw.githubusercontent.com/open-guji/luatex-cn/main/示例/首页展示/mulu-color.png)

**Capabilities**:
- Standard ancient book table of contents layout (`\条目[level]{...}`)
- "Eight lines, twenty-one characters" format restriction
- White mouth, double borders on all sides, single fishtail format
- Double-line small annotations (`\注{...}`) and an overlaid imperial seal (`\印章[page=1, opacity=0.7]{...}`)

📂 [View Source](https://github.com/open-guji/luatex-cn/tree/main/示例/四库全书简明目录) ｜ 📄 [View PDF](https://github.com/open-guji/luatex-cn/blob/main/示例/四库全书简明目录/目录.pdf)

> A full multi-volume reproduction lives in [全书复刻/欽定四庫全書簡明目錄](https://github.com/open-guji/luatex-cn/tree/main/全书复刻/欽定四庫全書簡明目錄).

---

### 3. Dream of the Red Chamber - Jiaxu Manuscript

**Features**: Simulates manuscript/annotated copy style.

**Capabilities**:
- **Side notes** (`\侧批{...}`): red interlinear commentary
- **Floating annotations** (`\批注{...}`)
- **Double-column small text** (`\夹注{...}`): double-line small annotations in main text
- **Judou mode** (`\开启句读模式`)
- No fishtail page center, bottom page numbers

> Marginal notes (`\眉批{...}`) are not in this example — see the Jiaxu manuscript under [Full-Book Reproductions](#full-book-reproductions).

| Page 2 (Punctuation) | Page 1 (Marginal Notes) |
| :---: | :---: |
| ![Honglou P2](https://raw.githubusercontent.com/open-guji/luatex-cn/main/示例/首页展示/honglou-p2.png) | ![Honglou P1](https://raw.githubusercontent.com/open-guji/luatex-cn/main/示例/首页展示/honglou-p1.png) |

📂 [View Source](https://github.com/open-guji/luatex-cn/tree/main/示例/红楼梦甲戌本)

---

### 4. Records of the Grand Historian, Vol. 16 - Modern Vertical

**Class**: `ltc-cn-vbook` | **Template**: `中华书局` (Zhonghua Shuju)

**Capabilities**:
- Modern punctuation squeeze (`\punctSetup{punct-squeeze=true}`)
- Kinsoku line-breaking rules (`\punctSetup{kinsoku=true}`)
- Footnotes (`\脚注{...}`) with lujiao numbering
- Paragraph indentation (`\begin{段落}[indent=2]`)
- Mainland punctuation style

| Page 1 | Page 2 |
| :---: | :---: |
| ![Juan16 P1](https://raw.githubusercontent.com/open-guji/luatex-cn/main/示例/首页展示/juan16-p1.png) | ![Juan16 P2](https://raw.githubusercontent.com/open-guji/luatex-cn/main/示例/首页展示/juan16-p2.png) |

📂 [View Source](https://github.com/open-guji/luatex-cn/tree/main/示例/史记卷十六·现代) ｜ 📄 [View PDF](https://github.com/open-guji/luatex-cn/blob/main/示例/史记卷十六·现代/卷十六.pdf)

---

### 5. 論辯的魂靈 by Lu Xun — Modern Horizontal (clreq)

**Setup**: `article` + `\usepackage{luatex-cn}` (not yet in a release — main branch).

The same essay set twice for comparison: the traditional-character part uses `style=taiwan` (centered punctuation), the simplified part uses `style=mainland` + `quote-style=curly` (corner quotes converted to curly, double outside and single inside).

**Capabilities**:
- CJK–Western spacing and basic-level kinsoku
- Consecutive-punctuation reduction (2 em → 1.5 em) and line-start/line-end compression
- Orphan-character avoidance at paragraph end
- `\horiSetup{last-line=right}` for the closing colophon
- Traditional size numbers via `\字号{二号}`

📂 [View Source](https://github.com/open-guji/luatex-cn/tree/main/示例/论辩的魂灵) ｜ 📄 [View PDF](https://github.com/open-guji/luatex-cn/blob/main/示例/论辩的魂灵/论辩的魂灵.pdf) ｜ 📖 [[Horizontal | EN:Horizontal]]

---

### 6. Gongche Notation — Kunqu Scores

**Class**: `ltc-guji` | **Templates**: default (printed edition) and `红楼梦甲戌本` (manuscript)

Two reproductions, one per source form:

| Printed: 鵲橋仙·聖世呈符 | Manuscript: 西厢記·佳期·臨鏡序 |
| :---: | :---: |
| ![Shengshi Chengfu](https://raw.githubusercontent.com/open-guji/luatex-cn/main/示例/工尺谱/圣世呈符-预览.png) | ![Xixiangji Jiaqi](https://raw.githubusercontent.com/open-guji/luatex-cn/main/示例/工尺谱/西厢记佳期-预览.png) |

**Capabilities**:
- Lyric character with its notation (`\工尺{影}{\音[板]{尺}\音[眼]{工}}`) — beat/eye marks as red dots
- Mode and tune-name annotations (`\宫调{仙吕調}`, `\调名注{一名廣寒秋}`)
- Judou characters (`\句读字`) phrasing the lyrics
- Tightened line format (`\contentSetup{n-char-per-col=12, n-column=8}`) to match the printed edition's density

📂 [View Source](https://github.com/open-guji/luatex-cn/tree/main/示例/工尺谱) ｜ 📄 [Printed PDF](https://github.com/open-guji/luatex-cn/blob/main/示例/工尺谱/圣世呈符.pdf) ｜ [Manuscript PDF](https://github.com/open-guji/luatex-cn/blob/main/示例/工尺谱/西厢记佳期.pdf)

---

### 7. Yang Clan Genealogy — European-Style Genealogical Table

**Class**: `ltc-guji` | **Template**: `欧式族谱`

![Genealogy](https://raw.githubusercontent.com/open-guji/luatex-cn/main/示例/欧式族谱/p1.png)

Reproduces the opening spread of 《陽氏宗譜》 vol. 1: generations divided into horizontal bands, each cell carrying the given name on the right and the spouse's clan plus burial notes on the left.

**Capabilities**:
- **The table system** (the only table example): `\begin{表格}[分栏=6, 栏高度=43.2pt, 行填充=页]`, `\栏格式`, `\单元格`, `\换栏`
- Reversed octagonal ink frames (`\八角墨围反白[高度=3, 填充]{第一世}`) as generation labels
- Style overrides (`\样式[格高=28pt, 字号=28pt]{...}`)
- Install-free font families (`\设置字体族{Jigmo}`)
- Debug toggle (`\开启调试`, left commented in the source)

📂 [View Source](https://github.com/open-guji/luatex-cn/tree/main/示例/欧式族谱) ｜ 📄 [View PDF](https://github.com/open-guji/luatex-cn/blob/main/示例/欧式族谱/族谱.pdf)

---

## Full-Book Reproductions

`示例/` holds one- to few-page feature demos; [`全书复刻/`](https://github.com/open-guji/luatex-cn/tree/main/全书复刻) holds complete volume-length reproductions — many pages, slow to compile.

| Project | Class | Progress | Unique to it |
|---------|-------|----------|--------------|
| [欽定四庫全書簡明目錄](https://github.com/open-guji/luatex-cn/tree/main/全书复刻/欽定四庫全書簡明目錄) | `ltc-guji` + `ltc-guji-digital` | Volume 1 of 10 (20 juan) | **Digitization mode** (`\双列{\右小列{…}\左小列{…}}`, `\缩进`, `\换页`), the full elevation system (`\单抬`/`\平抬`/`\挪抬`/`\相对抬头`), `\文本框`, `\校对页` |
| [紅樓夢 · Jiaxu manuscript](https://github.com/open-guji/luatex-cn/tree/main/全书复刻/紅樓夢/甲戌本) | `ltc-guji` | Fanli + chapter 1 | **Marginal notes** (`\眉批{...}`, 35 of them), **character corrections** (`\改{...}`) |

The same book exists in both a semantic edition (`tex/`) and a digitization edition (`ditigal_tex/`, `*-digital.tex`), so the two input styles can be compared side by side.

---

## Feature Coverage

| Feature | Where to see it |
|---------|-----------------|
| Banxin and fishtail | Shiji Five Emperors, Siku Catalogue (varies by template) |
| Interlinear notes `\夹注` | Shiji Five Emperors, Siku Catalogue, Honglou, Genealogy |
| Side notes `\侧批` | Honglou (Jiaxu) |
| Floating annotations `\批注` | Honglou (Jiaxu) |
| Marginal notes `\眉批` | Full-book Honglou only |
| Seals `\印章` | Shiji Five Emperors, Siku Catalogue |
| Judou | Honglou (Jiaxu), Gongche |
| TOC entries `\条目` | Siku Catalogue |
| Elevation (single/flat/shifted/relative) | Siku Catalogue, full-book reproductions |
| Text boxes `\填充文本框` / `\文本框` | Shiji Five Emperors, full-book reproductions |
| Tables | Genealogy |
| Gongche notation | Gongche (both) |
| Ink frames / reversed octagon | Shiji vol. 16, Genealogy |
| Styles `\样式` | Genealogy, full-book reproductions |
| Character correction `\改` | Full-book Honglou only |
| Modern punctuation and kinsoku | Shiji vol. 16 |
| Footnotes `\脚注` | Shiji vol. 16 |
| Digitization double columns | Full-book Siku Catalogue only |
| Horizontal clreq | 論辯的魂靈 |

> **Not covered by any example**: the `ltc-tw-vbook` class, line marks (`\线标`/`\专名号`/`\书名号`), decorations and tone circles (`\装饰`/`\圈点`/`\发圈`), missing-character marks, sidenotes via `\旁注`, colophons and floating text boxes, illustration pages and half-page breaks, [[Layout Export | EN:Layout-Export]], and the horizontal package's interlinear marks / ruby / even spread / paragraph styles (the example only uses `\字号` and `\horiSetup`). These currently have test documents under `test/regression_test/` but no showcase example.

---

*Note: All ancient book examples are digital reconstructions based on historical document scans, intended to demonstrate `luatex-cn`'s adaptability to various complex typesetting scenarios.*
