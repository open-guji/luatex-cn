[Chinese Version](Digitalization) | English

# Digitalization Workflow and Conversion

`luatex-cn` provides a comprehensive digitalization workflow designed to convert physical ancient books or existing semantic TeX files into layout-faithful (pixel-perfect) digital versions.

## 1. Core Concept: Semantic vs. Layout

There are two primary typesetting modes in `luatex-cn`:

| Mode | Document Class | Characteristics | Use Cases |
| :--- | :--- | :--- | :--- |
| **Semantic Mode** | `ltc-guji` | Auto-paging, auto-column, logical control | Content creation, typesetting design |
| **Layout Mode** | `ltc-guji-digital` | Forced column breaks, explicit indent, fixed layout | Book digitalization, layout restoration |

## 2. Digital Converter Engine (`converter.py`)

The `scripts/digitalize/converter.py` serves as the bridge between Semantic Mode and Layout Mode. It parses the content of an `ltc-guji` file and generates corresponding digitalized TeX code based on the specified grid parameters.

### Usage

```bash
python3 scripts/digitalize/converter.py --input source.tex --output target-digital.tex
```

### Plugin System
If your template includes custom commands, you can extend the engine with plugins:
```bash
python3 converter.py --input in.tex --output out.tex --plugin plugins/my_plugin.py
```

## 3. Digital-Specific Commands

The `ltc-guji-digital` class loads the `luatex-cn-digital` package, providing commands for direct layout control. In digital mode, the body text environment uses `obeylines` by default, meaning every newline in the TeX source corresponds to a new column in the output.

### Indent and Taitou
- **`\缩进[N]`** (or `\Indent[N]`): Sets the starting position for the current column.
  - `N > 0`: Indent down by $N$ characters (used for paragraph starts, items, etc.).
  - `N < 0`: Extend up by $N$ characters ("Taitou", entering the header area).

### Dual-Column Note (Jiazhu)
To precisely restore the column split of notes:
```latex
\双列{
  \右小列{Right sub-column text}
  \左小列{Left sub-column text}
}
```

### Explicit Banxin Control
During digitalization, it is often necessary to manually specify page numbers or chapter titles for each page:
```latex
\begin{版心}
  \版心章节{Chapter One}
  \版心页码{15}
  \上鱼尾
\end{版心}
```

## 4. Suggested Digitalization Workflow

1. **Prepare Semantic Draft**: Start by writing your document using `ltc-guji` to ensure content accuracy.
2. **Run Converter**: Use `converter.py` to generate the initial digitalized TeX.
3. **Fine-Tuning**: In the generated `-digital.tex` file, fine-tune `\缩进` parameters or handle special layout overflows as needed.
4. **Compile and Export**: Compile the digital version and use the [[Layout Export | Layout-Export]] feature to generate JSON data for downstream systems.

---

Next Step: View [[Features | Features]] | [[Layout Export | Layout-Export]] | [[Command Reference | Command-Reference]]
