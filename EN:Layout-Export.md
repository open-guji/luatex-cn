English | [中文版](Layout-Export)

# Layout Export

`luatex-cn` can export layout information to a JSON file after typesetting, including precise coordinates for every character, page info, column info, interlinear notes (jiazhu), and side notes. This feature is useful for regression testing, quality assurance, or integration with external systems.

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
| `is_banxin` | boolean | Whether this is a banxin (center fold) column |
| `characters` | array | Array of characters in this column |

### characters Array

Each character contains:

| Field | Type | Description |
|-------|------|-------------|
| `char` | string | The character itself |
| `unicode` | number | Unicode code point |
| `row_index` | number | Row index (1-indexed, top to bottom) |
| `absolute_x_pt` | number | Absolute X coordinate (pt, from page left) |
| `absolute_y_pt` | number | Absolute Y coordinate (pt, from page top) |
| `relative_y_pt` | number | Relative Y within column (pt, from column top) |
| `cell_height_pt` | number | Cell height (pt) |
| `is_jiazhu` | boolean | Whether this is an interlinear note character |
| `sub_col` | number | Jiazhu sub-column (1=right, 2=left), only present for jiazhu characters |
| `font_size_pt` | number | Font size (pt), only present when different from default |
| `font_color` | string | Font color, only present when different from default |

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
- **Row order**: `row_index=1` is the first character in a column (topmost)
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
          "is_banxin": false,
          "characters": [
            {
              "char": "史",
              "unicode": 21490,
              "row_index": 1,
              "absolute_x_pt": 811.19,
              "absolute_y_pt": 12.40,
              "relative_y_pt": 0,
              "cell_height_pt": 28.00,
              "is_jiazhu": false
            }
          ]
        }
      ],
      "sidenotes": []
    }
  ]
}
```

## Use Cases

- **Regression Testing**: Compare JSON output to detect unexpected layout changes
- **Quality Assurance**: Verify character grid alignment and jiazhu column balancing
- **Data Extraction**: Export typeset results as structured data for full-text search or digital humanities research
- **External Integration**: Provide precise character coordinates for OCR verification, layout analysis, etc.

---

Next: [[Features | EN:Features]] | [[Debug Mode | EN:Debug]] | [[Command Reference | Command-Reference]]
