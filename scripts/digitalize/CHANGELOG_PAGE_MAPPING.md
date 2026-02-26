# 页码映射逻辑演进历史

## 2026-02-24: 简化版本 (当前)

### 核心思想

**一个 Layout page 对应固定数量的 PDF pages，只看类型不看内容**

```python
if page_type == 'single':
    pdf_pages = 1
elif page_type in ('spread', 'spread_right', 'spread_left'):
    pdf_pages = 2
```

### 优点

1. **逻辑简单**：无需分析列数或内容
2. **性能高效**：O(n) 线性扫描，无额外计算
3. **语义清晰**：`spread` = 筒子页 = 2 个 PDF 页
4. **易于维护**：代码只有 20 行

### 实现

```python
def calculate_pdf_page(summary, layout_page_idx):
    pdf_offset = sum(
        1 if p['type'] == 'single' else 2
        for p in summary[:layout_page_idx]
    )
    pdf_start = pdf_offset + 1

    if summary[layout_page_idx]['type'] == 'single':
        return (pdf_start, pdf_start)
    else:
        return (pdf_start, pdf_start + 1)
```

### 页码标签格式

- 单页: `"PDF第N页"`
- 筒子页: `"PDF第N-M页（筒子页）"`

### 验证数据

**四库全书简明目录·冊一**:
```
Layout pages: 41 (4 single + 37 spread)
PDF pages: 78 (4×1 + 37×2 = 78 ✓)

Layout 0: single → PDF 1
Layout 1: single → PDF 2
Layout 2: spread → PDF 3-4
Layout 3: spread → PDF 5-6
...
Layout 40: spread → PDF 77-78
```

---

## 2026-02-24: 复杂版本（已废弃）

### 核心思想

**尝试通过列数判断左右页，动态计算 PDF 页码**

### 问题

1. **逻辑复杂**：需要检查 `split_info.leaf`，区分左右页
2. **语义混乱**：
   - `spread_right` 是 Layout page 还是 PDF page？
   - 为什么一个 `spread_right` 对应 2 个 PDF 页？
3. **维护困难**：100+ 行代码，多重条件判断
4. **与数据不符**：
   - Original JSON: 48 layout pages = 48 个 `spread_right/left` 条目
   - 但 PDF 只有 92 页，不是 96 页

### 根本原因

**错误假设**: `spread_right` 和 `spread_left` 是裁剪后的左右页

**实际情况**: 它们是**未裁剪**的筒子页，只是内部有 `split_info` 元数据

---

## 关键教训

### 1. 先理解语义，再写代码

- `spread_right/left` 的命名很误导
- 应该先查看实际 JSON 数据，再设计算法
- **Commit c94a6889**: 将 `spread_right/left` 统一为 `spread`

### 2. 简单 > 复杂

- 第一版尝试用列数区分左右页 → 100+ 行代码
- 简化后直接用类型 → 20 行代码
- 功能完全一样，但维护性提升 5 倍

### 3. 用实际数据验证

```bash
# 编译并导出 layout JSON
ENABLE_EXPORT=1 lualatex file.tex

# 检查页面类型分布
jq '.page_summary | group_by(.type) | map({type: .[0].type, count: length})' \
   file-layout.json

# 验证总页数
python3 -c "
import json
with open('file-layout.json') as f:
    data = json.load(f)
    summary = data['page_summary']
    total = sum(1 if p['type']=='single' else 2 for p in summary)
    print(f'Total PDF pages: {total}')
"
```

### 4. 文档要同步更新

- 修改代码后立即更新 `PAGE_MAPPING.md`
- 删除过时的 API 文档
- 添加验证示例

---

## 相关文件

| 文件 | 说明 |
|------|------|
| `compare_guji_layouts.py` | 主比较脚本 |
| `PAGE_MAPPING.md` | 页码映射 API 文档 |
| `SPREAD_PAGE_SEMANTICS.md` | spread 类型语义说明 |
| `tex/core/luatex-cn-core-export.lua` | Layout export 模块 |

---

## Commits

- **2b21a214**: refactor(compare): simplify PDF page mapping logic
- **c94a6889**: fix(export): correct spread page type semantics
- **17778c08**: feat(compare): enhance page numbering with spread page support
