# 页码映射与筒子页处理

## 背景

在古籍排版中，存在两种页面类型：

1. **单页** (single) - 独立的页面，对应 1 个 PDF 页
2. **筒子页** (spread) - 对开页（未裁剪），对应 2 个 PDF 页

### 核心概念

- **Layout JSON**: 记录的是**未裁剪**的页面（0-indexed）
- **PDF 输出**: 裁剪后的页面（1-indexed）
- **映射规则**:
  - `single` 类型 = 1 个 PDF 页
  - `spread` 类型 = 2 个 PDF 页

### 示例

```
Layout Page 0 (single)  → PDF Page 1
Layout Page 1 (single)  → PDF Page 2
Layout Page 2 (spread)  → PDF Pages 3-4（筒子页）
Layout Page 3 (spread)  → PDF Pages 5-6（筒子页）
Layout Page 4 (single)  → PDF Page 7
```

## 页码计算公式

```python
pdf_offset = sum(
    1 if type == 'single' else 2
    for page in summary[:layout_page_idx]
)
pdf_start = pdf_offset + 1

if current_type == 'single':
    pdf_end = pdf_start
else:  # spread
    pdf_end = pdf_start + 1
```

## API 参考

### `calculate_pdf_page(summary, layout_page_idx)`

计算 Layout 页对应的 PDF 页码范围。

**参数**:
- `summary`: page_summary 列表
- `layout_page_idx`: Layout 页索引（0-indexed）

**返回**: `tuple[int, int]`
- `(pdf_start, pdf_end)`: PDF 页码范围（1-indexed）
- 单页: `(N, N)` - 只对应第 N 页
- 筒子页: `(N, N+1)` - 对应第 N 和 N+1 页

**示例**:
```python
# Layout JSON 有 41 页，PDF 有 78 页
calculate_pdf_page(summary, 0)  # → (1, 1) - single
calculate_pdf_page(summary, 1)  # → (2, 2) - single
calculate_pdf_page(summary, 2)  # → (3, 4) - spread
calculate_pdf_page(summary, 3)  # → (5, 6) - spread
```

### `build_page_label_map_from_summary(summary)`

从 `page_summary` 构建页码标签映射。

**参数**:
- `summary`: page_summary 列表

**返回**: `dict[int, str]`

**示例**:
```python
{
    0: "PDF第1页",
    1: "PDF第2页",
    2: "PDF第3-4页（筒子页）",
    3: "PDF第5-6页（筒子页）",
}
```

### `build_page_label_map_from_pages(pages, summary=None)`

从 `pages` 结构构建页码标签映射。

**参数**:
- `pages`: pages 列表
- `summary`: page_summary 列表（可选，用于精确计算 PDF 页码）

**返回**: `dict[int, str]`

### `is_spread_page(summary, page_idx)`

检测是否为筒子页。

**参数**:
- `summary`: page_summary 列表
- `page_idx`: 页索引

**返回**: `bool`

## PDF 截图对比

### 单页对比（1x2 布局）

```
+------------------+------------------+
| 原始版本         | 数字化版本       |
| [PDF Page N]     | [PDF Page N]     |
+------------------+------------------+
```

### 筒子页对比（2x2 布局）

```
+------------------+------------------+
| 原始·第N页       | 数字化·第N页     |
+------------------+------------------+
| 原始·第N+1页     | 数字化·第N+1页   |
+------------------+------------------+
```

## split_info 字段

在 `pages` 结构中，`split_info` 提供筒子页的元数据：

```json
{
  "page_index": 2,
  "split_info": {
    "leaf": "right",
    "physical_page": 0
  }
}
```

- `leaf`: "right" 或 "left" - 裁剪后的位置（元数据）
- `physical_page`: 物理页码（0-indexed）

**注意**: 这只是元数据，不影响 PDF 页码计算。PDF 页码完全由 `page_summary.type` 决定。

## 实际数据示例

**四库全书简明目录·冊一**:
- Layout JSON: 41 页
- PDF 输出: 78 页
- 页面类型统计:
  - single: 4 页
  - spread: 37 页
- PDF 页数验证: 4×1 + 37×2 = 78 ✓

## 测试

```bash
# 编译并导出 layout JSON
cd 全书复刻/欽定四庫全書簡明目錄/tex
ENABLE_EXPORT=1 lualatex 欽定四庫全書簡明目錄冊一.tex

# 检查页码映射
python3 -c "
import json
with open('欽定四庫全書簡明目錄冊一-layout.json') as f:
    data = json.load(f)
    summary = data['page_summary']
    for i in range(min(5, len(summary))):
        print(f'Layout {i}: {summary[i][\"type\"]}')
"
```

## Changelog

- **2026-02-24**: 简化页码映射逻辑
  - 移除复杂的左右页区分逻辑
  - spread 类型统一对应 2 个 PDF 页
  - 标签格式: "PDF第N-M页（筒子页）"
