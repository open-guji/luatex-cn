# 两侧边距（Twoside Margins）功能文档

## 概述

`twoside`（两侧模式）是 luatex-cn 中用于实现镜像边距（mirror margins）的功能。在启用此模式时，奇数页和偶数页会使用相反的左右边距配置，这在需要打印和装订的书籍排版中非常常见。

## 使用场景

### 何时使用 Twoside 模式

- **打印书籍**：需要在装订线附近预留更多空间
- **对开排版**：左右对页需要形成镜像视觉效果
- **专业出版**：符合国际排版规范
- **现代竖排书**：如诗集、文化著作等

### 与单侧边距的区别

| 特性 | 单侧模式 | Twoside 模式 |
|------|---------|------------|
| **边距应用** | 所有页相同 | 奇偶页交替 |
| **装订空间** | 固定位置 | 始终在内侧 |
| **使用案例** | 屏幕阅读 | 印刷装订 |

## 配置方法

### 基本语法

```latex
\pageSetup{
    paper-width = 170mm,
    paper-height = 240mm,
    margin-top = 25mm,
    margin-bottom = 15mm,
    % 启用 twoside 模式
    twoside = true,
    margin-inner = 18mm,    % 内侧边距（靠近装订线）
    margin-outer = 22mm,    % 外侧边距
}
```

### 参数说明

- `twoside = true|false`：是否启用两侧模式（默认：false）
- `margin-inner`：内侧边距，应用到每页靠近装订线的一侧
- `margin-outer`：外侧边距，应用到每页远离装订线的一侧

### 页码与边距的对应关系

**启用 twoside 时：**

- **奇数页**（1, 3, 5, ...）
  - 左边距 = margin-inner（内侧）
  - 右边距 = margin-outer（外侧）

- **偶数页**（2, 4, 6, ...）
  - 左边距 = margin-outer（外侧）
  - 右边距 = margin-inner（内侧）

### 回退行为

如果 `twoside = false`，系统将使用传统的 `margin-left` 和 `margin-right` 参数。

```latex
\pageSetup{
    twoside = false,        % 禁用 twoside
    margin-left = 22mm,
    margin-right = 18mm,
}
```

## 实际应用示例

### 现代竖排书（vbook）

参考文件：`test/regression_test/modern/tex/vbook-twoside.tex`

```latex
\documentclass{ltc-cn-vbook}

\pageSetup{
    paper-width = 170mm,
    paper-height = 240mm,
    margin-top = 25mm,
    margin-bottom = 15mm,
    twoside = true,
    margin-inner = 18mm,
    margin-outer = 22mm,
}

\begin{document}
\begin{正文}
内容会自动根据页码应用正确的左右边距...
\end{正文}
\end{document}
```

## 内部实现

### 架构设计

Twoside 功能在三层架构中实现：

```
Layer 1: Page Setup (.sty)
  ↓
Layer 2: Lua Configuration (.lua)
  ↓
Layer 3: Content Width Calculation (calc_content_area_width)
```

### 关键代码位置

1. **LaTeX 配置层** (`luatex-cn-core-page.sty`)
   - 定义 `twoside`, `margin-inner`, `margin-outer` 配置键
   - 将参数传递给 Lua

2. **Lua 页面层** (`luatex-cn-core-page.lua`)
   - 存储 twoside 状态和内外边距值
   - 支持 save/restore 操作

3. **Lua 内容层** (`luatex-cn-core-content.lua`)
   - `calc_content_area_width()` 函数根据页码选择正确的边距
   - `calc_auto_layout()` 函数同样支持 twoside 模式

### 页码检测逻辑

```lua
local page_num = _G.page.current_page_number or 1
if page_num % 2 == 1 then
    -- 奇数页：inner 在左，outer 在右
    m_left = margin_inner
    m_right = margin_outer
else
    -- 偶数页：outer 在左，inner 在右
    m_left = margin_outer
    m_right = margin_inner
end
```

## 单元测试

Twoside 功能由 8 个单元测试覆盖，验证了：

- ✅ Twoside 禁用时的对称边距
- ✅ 奇数页的内外边距正确应用
- ✅ 偶数页的内外边距正确应用
- ✅ 奇偶页内容宽度一致性
- ✅ 页码奇偶性检测（1-6）
- ✅ 非对称内外边距的处理
- ✅ Page.setup() 参数存储
- ✅ 边距参数回退逻辑

运行测试：
```bash
texlua test/run_all.lua
```

## 回归测试

演示文件：`test/regression_test/basic/baseline/vbook-twoside-*.png`

可视化验证了：
- 页 1（奇数）：左小右大
- 页 2（偶数）：左大右小
- 页 3（奇数）：左小右大（再次）

## 常见问题

### Q: 如何在文档中途切换 twoside 模式？

当前版本不支持文档中途动态切换。如需不同部分使用不同配置，建议使用多个子文档并在主文档中用 `\input` 或 `\include` 合并。

### Q: 内侧和外侧分别指什么？

- **内侧（inner）**：靠近装订线的一侧（从页面中间向外数）
- **外侧（outer）**：远离装订线的一侧（页面的外边缘）

在对开排版中，内侧始终预留空间用于装订。

### Q: Twoside 模式影响内容宽度吗？

**不会**。虽然左右边距互换，但内容总宽度保持不变：
```
内容宽度 = 纸张宽度 - 内侧边距 - 外侧边距
```

### Q: 如何与古籍排版的 banxin（版心）结合使用？

Twoside 和 banxin 独立工作。Twoside 控制整体页边距，banxin 控制版心列的位置。可以同时使用两种功能。

## 后续开发

- [ ] 动态页码感知（在文档中途自动检测页码）
- [ ] 单页/奇偶页边距微调
- [ ] 绑定方式配置（左装订 vs 右装订）

## 参考资源

- LaTeX `geometry` 宏包：https://ctan.org/pkg/geometry
- 传统印刷术语：https://en.wikipedia.org/wiki/Book_design
