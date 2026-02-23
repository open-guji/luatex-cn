[English Version](EN:Layout-Export) | 中文版

# 排版坐标导出

`luatex-cn` 支持将排版后的布局信息导出为 JSON 文件，包含每个字符的精确坐标、页面信息、列信息、夹注和侧批数据。此功能可用于排版质量检测、自动化测试、或与外部系统集成。

## 启用导出

在文档 preamble 中添加：

```latex
\启用排版导出
```

或使用英文命令：

```latex
\enableLayoutExport
```

默认情况下，导出功能处于关闭状态。启用后，编译完成时会自动在当前目录生成 `<jobname>-layout.json` 文件。

### 自定义文件名

```latex
\enableLayoutExport[filename=my-output.json]
```

## 输出文件

编译完成后，在 `.tex` 文件所在目录生成 `<jobname>-layout.json`。

## JSON 格式说明

### 顶层结构

```json
{
  "version": "1.0",
  "generator": "luatex-cn",
  "document": { ... },
  "pages": [ ... ]
}
```

### document 对象

包含文档全局信息：

| 字段 | 类型 | 说明 |
|------|------|------|
| `total_pages` | number | 总页数 |
| `page_width_pt` | number | 页面宽度（pt） |
| `page_height_pt` | number | 页面高度（pt） |
| `grid_width_pt` | number | 网格列宽（pt） |
| `grid_height_pt` | number | 网格行高（pt） |
| `line_limit` | number | 每列最大字数 |
| `split_page.enabled` | boolean | 是否启用筒子页 |

### pages 数组

每个页面包含：

| 字段 | 类型 | 说明 |
|------|------|------|
| `page_index` | number | 页码（0-indexed） |
| `columns_count` | number | 该页总列数 |
| `margins` | object | 页面边距 |
| `columns` | array | 有内容的列数组 |
| `sidenotes` | array | 侧批数组 |

#### margins 对象

```json
{
  "top_pt": 190.5,
  "bottom_pt": 91.6,
  "left_pt": 133.2,
  "right_pt": 133.2
}
```

所有数值单位为 pt。

### columns 数组

每个列包含：

| 字段 | 类型 | 说明 |
|------|------|------|
| `col_index` | number | 列索引（0-indexed，从右往左） |
| `is_banxin` | boolean | 是否为版心列 |
| `characters` | array | 该列的字符数组 |

### characters 数组

每个字符包含：

| 字段 | 类型 | 说明 |
|------|------|------|
| `char` | string | 字符本身 |
| `unicode` | number | Unicode 码点 |
| `row_index` | number | 行索引（1-indexed，从上往下） |
| `absolute_x_pt` | number | 绝对 X 坐标（pt，页面左边起算） |
| `absolute_y_pt` | number | 绝对 Y 坐标（pt，页面顶部起算） |
| `relative_y_pt` | number | 列内相对 Y 坐标（pt，列顶部起算） |
| `cell_height_pt` | number | 格高（pt） |
| `is_jiazhu` | boolean | 是否为夹注字符 |
| `sub_col` | number | 夹注子列（1=右小列，2=左小列），仅夹注字符有此字段 |
| `font_size_pt` | number | 字号（pt），仅当与默认不同时出现 |
| `font_color` | string | 字体颜色，仅当与默认不同时出现 |

### sidenotes 数组

每条侧批包含：

| 字段 | 类型 | 说明 |
|------|------|------|
| `sidenote_id` | number | 侧批 ID |
| `anchor_col` | number | 锚定列索引 |
| `anchor_y_pt` | number | 锚定 Y 坐标（pt） |
| `font_size_pt` | number | 字号（pt） |
| `spans_columns` | boolean | 是否跨列 |
| `characters` | array | 侧批字符数组 |

侧批字符包含 `char`、`unicode`、`page`、`col`、`y_pt`、`cell_height_pt` 字段。

## 坐标系

- **原点**：页面左上角
- **X 轴**：向右为正
- **Y 轴**：向下为正
- **列序**：`col_index=0` 为最右列，向左递增
- **行序**：`row_index=1` 为列内第一个字（最上方）
- **单位**：所有坐标和尺寸均为 pt（1pt = 1/72.27 inch）

## 完整示例

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
            },
            {
              "char": "記",
              "unicode": 35352,
              "row_index": 2,
              "absolute_x_pt": 811.19,
              "absolute_y_pt": 40.40,
              "relative_y_pt": 28.00,
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

## 使用场景

- **回归测试**：对比排版结果的 JSON 输出，检测布局是否发生意外变化
- **排版质量检测**：验证字符是否对齐到网格、夹注是否正确分栏
- **数据提取**：将古籍排版结果导出为结构化数据，用于全文检索或数字人文研究
- **与外部系统集成**：为 OCR 校对、版面分析等系统提供精确的字符坐标

---

下一步：查看 [[功能详解 | Features]] | [[调试模式 | Debug]] | [[命令索引 | Command-Reference]]
