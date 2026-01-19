# LuaTeX-cn User Manual

`luatex-cn` is a macro package specifically designed for LuaTeX, with enhanced support for traditional Chinese vertical layout (Guji) and modern vertical typesetting.

---

## 1. Installation and Preparation

### System Requirements
- **Compiler**: Must use `LuaLaTeX` (version 1.10+). pdfLaTeX or XeLaTeX are not supported.
- **Distribution**: TeX Live 2024 or higher is recommended.

### Font Configuration
The package attempts to automatically detect Chinese fonts in your system by default:
- **Windows**: Prefers "SimSun", "Microsoft YaHei", or "NSimSun".
- **macOS**: Prefers "Songti SC", "Heiti SC".
- **Linux**: Prefers "Noto Serif CJK SC", "WenQuanYi Zen Hei".

For detailed manual font configuration, please refer to: [FONT-SETUP.md](./FONT-SETUP.md).

---

## 2. Quick Start

### Basic Ancient Book (Guji) Template
Create a `.tex` file with the following content:

```latex
\documentclass[四库全书]{ltc-guji}

\begin{document}
\gujiSetup{
    book-name = {Test Document},
    chapter-title = {Vol. 1},
    font-size = 14pt
}

This is the main content. You can directly input Chinese text, and the package will automatically handle vertical flow and column division.

\TextFlow{This is interlinear small text (Jiazhu), typically used to explain the main text.}

\end{document}
```

Compile with `lualatex` to obtain a Guji-style page with grid lines and a center column (Banxin).

---

## 3. Document Classes and Templates

The project provides two main document classes:

### `ltc-guji.cls` (Specialized for Guji)
Includes complex grids, fish-tails, and Banxin control, suitable for reproducing historical documents.
- **Built-in Templates**:
    - `四库全书` (SiKuQuanshu): Classic official style with green/red interfaces.
    - `红楼梦甲戌本` (HongLouMeng Jiaxu Edition): Simulates manuscript style, supporting side and top notes.

### `ltc-book.cls` (Modern Vertical Layout)
Suitable for modern novels or reports. It has no grid by default and offers a more flexible layout.
- **Usage**: Wrap your content in the `\begin{正文} ... \end{正文}` environment (or its alias `\begin{ltc-book-content} ... \end{ltc-book-content}`).

---

## 4. Feature and Command Reference

### 4.1 Core Typesetting Engine
- **`\竖排[params]{content}`** (Alias: `\VerticalRTT`): Arranges the specified content according to a vertical grid.
- **`\TextBox[params]{content}`**: Creates a gridded text box.
    - `height`: Number of lines occupied (grid height).
    - `n-cols`: Number of internal columns (e.g., typeset 3 columns of small text within one large grid line).
    - `box-align`: Content alignment (`top`, `center`, `bottom`, `fill`).
- **`\Space[length]`**: Inserts a grid placeholder.

### 4.2 Annotation System
- **`\TextFlow{content}`** (Alias: `\文本流`): Generates "Jiazhu" (double-column small text) common in ancient books.
- **`\SideNode[params]{content}`** (Alias: `\侧批`, `\CePi`): Adds annotations to the margins.
    - `yoffset`: Vertical offset.
    - `color`: Annotation color (often red in Guji).

### 4.3 Decoration and Positioning
- **`\YinZhang[params]{image_path}`**: Inserts an absolutely positioned seal/stamp on the current page.
    - `page`: Specifies the target page number.
    - `x`, `y`: Coordinate position (relative to the top-left corner of the page).
    - `width`: Seal width.

### 4.4 Paragraph Control
- **`\begin{Paragraph}[params]`**:
    - `indent`: Global indentation.
    - `first-indent`: First-line indentation (default is 1 or 2 characters).
    - `bottom-indent`: Bottom (right-side) padding.

### 4.5 Global Configuration (`\gujiSetup`)
- `book-name`: The book title displayed at the top of the Banxin.
- `chapter-title`: The chapter title displayed in the Banxin.
- `border`: Whether to display grid lines (`true`/`false`).
- `n-char`: Number of characters per line (a common constraint in Guji layout).

---

## 5. More Resources
For more in-depth examples, please check the [示例/](../示例/) (example) folder in the project root.
