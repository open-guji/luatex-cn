# 筒子页语义修正

## 背景

在古籍排版中，**筒子页（对开页）**是指未裁剪的完整页面，裁剪后会分为左右两页。

### 之前的错误设计

**问题**：`page_summary` 中使用 `"spread_right"` / `"spread_left"` 表示页面类型

```json
{
  "page": 2,
  "type": "spread_right",  // ❌ 误导！暗示这是"裁剪后的右页"
  "cols": [...]
}
```

**为什么错误**：
1. Layout JSON 记录的是**未裁剪**的页面
2. 每个 layout page 对应 PDF 中的 **1 页**（不是 2 页）
3. `"spread_right"` 暗示"这是裁剪后的右页"，但实际上是"未裁剪的筒子页"

**实际数据**（以四库全书简明目录冊一为例）：
- Layout JSON: 41 页
- PDF 输出: 78 页（裁剪后）
- `split.enabled = false`（PDF 未自动裁剪，手动裁剪）

## 新的正确设计

### 1. 统一的页面类型

```json
{
  "page": 2,
  "type": "spread",  // ✅ 正确：这是一个筒子页（未裁剪）
  "cols": [...]
}
```

**页面类型语义**：
- `"single"`: 单页（非筒子页）
- `"spread"`: 筒子页（对开页，未裁剪）

### 2. 裁剪信息在 split_info 中

左右页信息存储在 `split_info` 元数据中：

```json
{
  "page_index": 2,
  "split_info": {
    "leaf": "right",        // 如果裁剪，这会是右页
    "physical_page": 0      // 物理页码（0-indexed）
  }
}
```

**split_info 语义**：
- 这是**元数据**，标记"如果裁剪的话会是什么样"
- 不代表 PDF 实际已经裁剪
- `leaf: "right"/"left"` - 裁剪后的位置
- `physical_page` - 筒子页的物理编号

## 数据流图

```
TeX 源码
  ↓
定义页面类型（单页 / 筒子页）
  ↓
Layout 阶段
  ├─ 记录 page_summary.type = "single" | "spread"
  └─ 记录 split_info (如果是筒子页)
  ↓
Render 阶段
  ↓
PDF 输出
  ├─ split.enabled = true  → 自动裁剪成左右两页
  └─ split.enabled = false → 不裁剪（手动处理）
```

## API 变化

### Export 模块 (luatex-cn-core-export.lua)

**Before**:
```lua
if si.leaf == "right" then
    page_type = "spread_right"
elseif si.leaf == "left" then
    page_type = "spread_left"
end
```

**After**:
```lua
if si then
    -- 有 split_info 表示这是筒子页（对开页）
    page_type = "spread"
end
```

### 比较工具 (compare_guji_layouts.py)

**Before**:
```python
if ptype == 'spread_right' and next == 'spread_left':
    # 完整对开页对（2x2 布局）
    ...
```

**After**:
```python
if ptype == 'spread':
    # 筒子页（1x2 布局）
    label = f"PDF第{page}页（筒子页）"
```

**向后兼容**：
```python
elif ptype in ('spread_right', 'spread_left'):
    # 旧版 JSON 兼容
    label = f"PDF第{page}页（筒子页）"
```

## 测试结果

```bash
$ ENABLE_EXPORT=1 lualatex 欽定四庫全書簡明目錄冊一-digital.tex
```

**输出**:
```json
{
  "page_summary": [
    {"page": 0, "type": "single", "cols": [...]},
    {"page": 1, "type": "single", "cols": [...]},
    {"page": 2, "type": "spread", "cols": [...]},  // ✅ 正确
    {"page": 3, "type": "spread", "cols": [...]},
    ...
  ]
}
```

**统计**:
```
Page types distribution:
  single: 4
  spread: 37
```

## 向后兼容性

| 场景 | 兼容性 | 说明 |
|------|--------|------|
| **旧版 JSON** (`"spread_right"`) | ✅ 完全兼容 | 比较工具自动识别并处理 |
| **新版 JSON** (`"spread"`) | ✅ 推荐使用 | 语义清晰，避免误解 |
| **混合版本** | ✅ 兼容 | 可同时比较新旧版本 JSON |

## 相关文件

- **Export 模块**: `tex/core/luatex-cn-core-export.lua`
- **比较工具**: `scripts/digitalize/compare_guji_layouts.py`
- **Commit**: c94a6889

## 未来改进

- [ ] 添加 JSON schema 验证
- [ ] 在文档中明确说明 layout page vs PDF page 的区别
- [ ] 考虑在 `document` 中添加 `actual_split` 标志，表示 PDF 是否真的裁剪了
