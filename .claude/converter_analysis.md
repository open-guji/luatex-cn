# Converter 验证分析报告

> 日期：2026-02-23
> 测试文件：欽定四庫全書簡明目錄冊一.tex

## 执行摘要

通过比较 guji.cls 格式和 converter 生成的 guji-digital 格式的 layout JSON 输出，发现了**显著差异**：

- **页数差异**：Digital 输出 52 页，Original 输出 48 页（多 4 页）
- **完全相同的页面**：仅 3 页（Page 1-3，即封面和空白页）
- **结构差异页面**：45 页（93.75%）

## 主要问题

### 1. 换页逻辑错误 ⚠️ **高优先级**

**症状**：
- Page 12-13 (digital) 几乎为空（每页只有 1 个空格字符）
- 目录内容从 Page 12 (original) 后移到 Page 14 (digital)

**根因**：
```tex
% digital TeX (错误)
\end{数字化内容}
\newpage          ← converter 插入
\chapter{目錄}    ← \chapter 可能也会触发换页
\begin{数字化内容}

% original TeX (正确)
\newpage
\chapter{目錄}
```

**影响**：导致额外的空白页，累积后造成 +4 页的偏移

**建议修复**：
- 在 converter 的 Stage 3 (Generator) 中，检测 `\chapter` 前的 `\newpage` 是否重复
- 或在 Stage 2 (Layouter) 中，将 `chapter` 类型的语义块标记为隐含换页，不额外输出 `\newpage`

---

### 2. 夹注分栏差异 ⚠️ **中优先级**

**症状**：
- 字符数在多页中不匹配（例如 Page 4: 81 vs 48 字符）
- 列数一致但字符数大幅偏移

**可能根因**：
1. **Layouter 的小列填充算法** 与 LuaTeX 引擎的 `layout_grid.lua` 不完全一致
2. **标点处理**：converter 去掉了标点，但 original 包含标点并参与排版计算
3. **抬头/缩进计算**：`\國朝`、`\单抬`、`\平抬` 的 indent 可能不精确

**建议修复**：
- 逐页对比字符序列，找出第一个分歧点
- 检查 Layouter 的 `fill_jiazhu_columns()` 逻辑
- 考虑在 converter 中保留标点（或至少在计算时考虑标点占位）

---

### 3. 版心列处理

**观察**：
- Page 0 的列数差异极端：1 列 (original) vs 13 列 (digital)
- 可能与版心列的跳过逻辑有关

**建议调查**：
- 检查 `siku_mulu.py` 插件中是否正确处理了版心相关的语义块
- 对比 Page 0 的 column 内容，确认是否有版心列被错误包含

---

## 数据统计

### 页面状态分布

| 状态 | 页数 | 占比 |
|------|------|------|
| ✓ identical | 3 | 6.25% |
| ⚠️ structure_diff | 45 | 93.75% |
| ➕ extra_in_digital | 4 | 8.33% |

### 字符数差异最大的页面

| Page | Original | Digital | 差异 |
|------|----------|---------|------|
| 46 | 1 | 348 | +347 |
| 47 | 1 | 318 | +317 |
| 12 | 309 | 1 | -308 |
| 13 | 302 | 1 | -301 |
| 36 | 434 | 331 | -103 |

---

## 下一步行动计划

### 立即修复（今天）

1. **修复换页逻辑**
   - [ ] 在 converter.py 的 `TexGenerator` 中添加 `\chapter` 前的 `\newpage` 去重
   - [ ] 或在 `Layouter` 中将 `chapter` 语义块标记为 `implicit_newpage=True`

2. **验证修复效果**
   - [ ] 重新运行 converter
   - [ ] 编译并比较，确认页数差异消除

### 后续优化（本周）

3. **修复夹注分栏**
   - [ ] 逐页比较字符序列，定位第一个分歧点（Page 4 开始）
   - [ ] 对比 Layouter 和 layout_grid.lua 的算法差异
   - [ ] 调整 Layouter 的小列填充逻辑

4. **版心列处理**
   - [ ] 分析 Page 0 的列数差异
   - [ ] 确认 siku_mulu.py 是否正确跳过版心列

5. **完整验证**
   - [ ] 重复运行 compare_layouts.py
   - [ ] 目标：所有页面 `status=identical`

---

## 工具链验证

✅ **Export 模块可用**
- JSON 格式正确，包含 page/col/row/char/type/jiazhu 信息
- Original: 48 页，13224 字符（2413 正文 + 10811 夹注）

✅ **Converter 可用**
- 成功解析 477 个语义块
- 成功生成 703 列
- 输出的 digital TeX 可编译

✅ **比较脚本可用**
- `compare_layouts.py` 正确识别差异
- 输出详细的页面状态和差异统计

---

## 参考

- 原始 TeX：`全书复刻/欽定四庫全書簡明目錄/tex/欽定四庫全書簡明目錄冊一.tex`
- Digital TeX：`全书复刻/欽定四庫全書簡明目錄/tex/欽定四庫全書簡明目錄冊一-digital.tex`
- Converter：`scripts/digitalize/converter.py`
- 插件：`scripts/digitalize/plugins/siku_mulu.py`
- 比较工具：`scripts/digitalize/compare_layouts.py`
