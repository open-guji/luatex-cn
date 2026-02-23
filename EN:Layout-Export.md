English | [中文版](Layout-Export)

# Layout Export

`luatex-cn` can export layout information to a JSON file after typesetting, including precise coordinates for every character, page info, column info, interlinear notes (jiazhu), and side notes. This feature is useful for regression testing, quality assurance, or integration with external systems.

The output format is aligned with `guji-platform`'s `PageLayout` data structure, enabling direct downstream parsing without additional conversion.

## Enabling Export

Add to your document preamble:

```latex
\enableLayoutExport
```

Or using the Chinese alias:

```latex
\启用排版导出
```

Export is disabled by default. When enabled, a `<jobname>-layout.json` file is generated automatically after compilation.

### Custom Filename

```latex
\enableLayoutExport[filename=my-output.json]
```

## Output File

After compilation, `<jobname>-layout.json` is generated in the same directory as the `.tex` file.

## JSON Format

### Top-Level Structure

```json
{
  "version": "1.0",
  "generator": "luatex-cn",
  "document": { ... },
  "pages": [ ... ]
}
```

### document Object

Global document information:

| Field | Type | Description |
|-------|------|-------------|
| `total_pages` | number | Total number of pages |
| `page_width_pt` | number | Page width (pt) |
| `page_height_pt` | number | Page height (pt) |
| `grid_width_pt` | number | Grid column width (pt) |
| `grid_height_pt` | number | Grid row height (pt) |
| `line_limit` | number | Maximum characters per column |
| `columns_count` | number | Total columns per page |
| `split_page.enabled` | boolean | Whether split page (tube page) is enabled |

### pages Array

Each page contains:

| Field | Type | Description |
|-------|------|-------------|
| `page_index` | number | Page number (0-indexed) |
| `columns_count` | number | Total columns on this page |
| `margins` | object | Page margins |
| `columns` | array | Array of columns with content |
| `sidenotes` | array | Array of side notes |

#### margins Object

```json
{
  "top_pt": 190.5,
  "bottom_pt": 91.6,
  "left_pt": 133.2,
  "right_pt": 133.2
}
```

All values in pt.

### columns Array

Each column contains:

| Field | Type | Description |
|-------|------|-------------|
| `col_index` | number | Column index (0-indexed, right to left) |
| `position` | object | Column position `{left_x, right_x}` (pt) |
| `characters` | array | Array of characters in this column |

### characters Array

Each character contains:

| Field | Type | Description |
|-------|------|-------------|
| `char` | string | The character itself |
| `unicode` | number | Unicode code point |
| `row_index` | number | Row index (0-indexed, top to bottom) |
| `position` | object | Character position `{x, y_top, y_bottom}` (pt) |
| `type` | string | Character type: `"normal"` or `"jiazhu"` |
| `confidence` | number | Confidence score (always 1.0 for TeX) |
| `jiazhu` | object | Jiazhu info `{sub_col: 1 or 2}`, only present when `type="jiazhu"` |
| `style` | object | Style info `{font_size_pt, font_color}`, only present when different from default |

#### position Object

```json
{
  "x": 811.19,
  "y_top": 12.40,
  "y_bottom": 40.40
}
```

- `x`: Column center X coordinate (pt)
- `y_top`: Character top boundary Y coordinate (pt)
- `y_bottom`: Character bottom boundary Y coordinate (pt)

#### jiazhu Object

```json
{
  "sub_col": 1
}
```

- `sub_col`: 1=right sub-column, 2=left sub-column

#### style Object

```json
{
  "font_size_pt": 8.0,
  "font_color": "0.8 0 0"
}
```

### sidenotes Array

Each side note contains:

| Field | Type | Description |
|-------|------|-------------|
| `sidenote_id` | number | Side note ID |
| `anchor_col` | number | Anchor column index |
| `anchor_y_pt` | number | Anchor Y coordinate (pt) |
| `font_size_pt` | number | Font size (pt) |
| `spans_columns` | boolean | Whether the note spans multiple columns |
| `characters` | array | Side note characters |

Side note characters contain `char`, `unicode`, `page`, `col`, `y_pt`, and `cell_height_pt` fields.

## Coordinate System

- **Origin**: Top-left corner of the page
- **X axis**: Positive to the right
- **Y axis**: Positive downward
- **Column order**: `col_index=0` is the rightmost column, increasing leftward
- **Row order**: `row_index=0` is the first character in a column (topmost)
- **Unit**: All coordinates and dimensions are in pt (1pt = 1/72.27 inch)

## Example Output

```json
{
  "version": "1.0",
  "generator": "luatex-cn",
  "document": {
    "total_pages": 1,
    "page_width_pt": 1136,
    "page_height_pt": 894.6,
    "grid_width_pt": 51.2096,
    "grid_height_pt": 28.0048,
    "line_limit": 21,
    "columns_count": 17,
    "split_page": { "enabled": false }
  },
  "pages": [
    {
      "page_index": 0,
      "columns_count": 17,
      "margins": {
        "top_pt": 190.5,
        "bottom_pt": 91.6,
        "left_pt": 133.2,
        "right_pt": 133.2
      },
      "columns": [
        {
          "col_index": 0,
          "position": { "left_x": 811.19, "right_x": 811.19 },
          "characters": [
            {
              "char": "史",
              "unicode": 21490,
              "row_index": 0,
              "position": { "x": 811.19, "y_top": 12.40, "y_bottom": 40.40 },
              "type": "normal",
              "confidence": 1.0
            }
          ]
        }
      ],
      "sidenotes": []
    }
  ]
}
```

## Integration with guji-platform

The output format is aligned with `guji-platform`'s `PageLayout` data structure:

| Export Field | PageLayout Mapping | Notes |
|-------------|-------------------|-------|
| `row_index` | `Character.row_index` | Both 0-indexed |
| `position.x/y_top/y_bottom` | `CharPosition` | Direct mapping |
| `type` | `Character.type` | `"normal"` / `"jiazhu"` |
| `confidence` | `Character.confidence` | Always 1.0 for TeX |
| `jiazhu.sub_col` | `JiazhuInfo.sub_col` | Direct mapping |
| `style` | `CharStyle` | Direct mapping |

Downstream `from_tex_layout()` can read the data directly without additional conversion.

## Use Cases

- **Regression Testing**: Compare JSON output to detect unexpected layout changes
- **Quality Assurance**: Verify character grid alignment and jiazhu column balancing
- **Data Extraction**: Export typeset results as structured data for full-text search or digital humanities research
- **External Integration**: Provide precise character coordinates for OCR verification, layout analysis, etc.

---

Next: [[Features | EN:Features]] | [[Debug Mode | EN:Debug]] | [[Command Reference | Command-Reference]]
