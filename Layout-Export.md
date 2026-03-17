[English Version](EN:Layout-Export) | 中文版

# 排版坐标导出

`luatex-cn` 支持将排版后的布局信息导出为 JSON 文件，包含每个字符的精确坐标、页面信息、列信息、夹注和侧批数据。此功能可用于排版质量检测、自动化测试、或与外部系统集成。

输出格式与 `guji-platform` 的 `PageLayout` 数据结构对齐，下游可直接解析，无需额外转换。

## 启用导出

导出功能默认关闭，有两种启用方式：

### 方式 1：环境变量（推荐用于测试和验证）

无需修改 `.tex` 文件，直接在编译命令前设置环境变量：

```bash
ENABLE_EXPORT=1 lualatex yourfile.tex
```

编译完成后自动生成 `yourfile-layout.json`。

**优点**：
- 无需修改源文件
- 适合批量验证和自动化测试
- 可临时开启/关闭导出

### 方式 2：文档内命令

在文档 preamble 中添加：

```latex
\开启排版导出
```

或使用英文命令：

```latex
\enableLayoutExport
```

#### 自定义文件名

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
| `columns_count` | number | 每页总列数 |
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
| `position` | object | 列位置 `{left_x, right_x}`（pt） |
| `characters` | array | 该列的字符数组 |

### characters 数组

每个字符包含：

| 字段 | 类型 | 说明 |
|------|------|------|
| `char` | string | 字符本身 |
| `unicode` | number | Unicode 码点 |
| `row_index` | number | 行索引（0-indexed，从上往下） |
| `position` | object | 字符位置 `{x, y_top, y_bottom}`（pt） |
| `type` | string | 字符类型：`"normal"` 或 `"jiazhu"` |
| `confidence` | number | 置信度（TeX 固定为 1.0） |
| `jiazhu` | object | 夹注信息 `{sub_col: 1或2}`，仅 `type="jiazhu"` 时出现 |
| `style` | object | 样式信息 `{font_size_pt, font_color}`，仅当与默认不同时出现 |

#### position 对象

```json
{
  "x": 811.19,
  "y_top": 12.40,
  "y_bottom": 40.40
}
```

- `x`: 列中心 X 坐标（pt）
- `y_top`: 字符上边界 Y 坐标（pt）
- `y_bottom`: 字符下边界 Y 坐标（pt）

#### jiazhu 对象

```json
{
  "sub_col": 1
}
```

- `sub_col`: 1=右子列，2=左子列

#### style 对象

```json
{
  "font_size_pt": 8.0,
  "font_color": "0.8 0 0"
}
```

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
- **行序**：`row_index=0` 为列内第一个字（最上方）
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
            },
            {
              "char": "記",
              "unicode": 35352,
              "row_index": 1,
              "position": { "x": 811.19, "y_top": 40.40, "y_bottom": 68.40 },
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

## 与 guji-platform 集成

输出格式与 `guji-platform` 的 `PageLayout` 数据结构对齐：

| 导出字段 | PageLayout 对应 | 说明 |
|---------|---------------|------|
| `row_index` | `Character.row_index` | 均为 0-indexed |
| `position.x/y_top/y_bottom` | `CharPosition` | 直接映射 |
| `type` | `Character.type` | `"normal"` / `"jiazhu"` |
| `confidence` | `Character.confidence` | TeX 固定 1.0 |
| `jiazhu.sub_col` | `JiazhuInfo.sub_col` | 直接映射 |
| `style` | `CharStyle` | 直接映射 |

下游 `from_tex_layout()` 可直接读取，无需额外转换。

## 与数字化工作流集成

排版导出功能是 [[数字化排版 | Digitalization]] 工作流的关键环节。

1. **布局验证**：在通过 `converter.py` 将语义稿转换为数字化稿后，通过对比两者的 JSON 导出数据，可以自动化验证转换过程是否保持了像素级的一致性。
2. **下游处理**：数字化后的排版结果可以通过 JSON 格式提供给 OCR 校对、全文检索或数字展示平台，实现“所排即所得”的数据流转。

## 使用场景

- **回归测试**：对比排版结果的 JSON 输出，检测布局是否发生意外变化
- **排版质量检测**：验证字符是否对齐到网格、夹注是否正确分栏
- **数据提取**：将古籍排版结果导出为结构化数据，用于全文检索或数字人文研究
- **与外部系统集成**：为 OCR 校对、版面分析等系统提供精确的字符坐标

---

下一步：查看 [[功能详解 | Features]] | [[调试模式 | Debug]] | [[命令索引 | Command-Reference]]
