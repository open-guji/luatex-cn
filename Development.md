[English Version](EN:Development) | 中文版

# 开发文档

本文档总结了 `luatex-cn` 排版引擎的核心设计理念与模块化架构。

## 1. 核心架构：三层设计

`luatex-cn` 采用三层架构以解耦布局逻辑与渲染表示：

1. **LaTeX 接口层 (`.sty`, `.cls`)**：定义用户命令，通过 `luatexbase` 设置属性及参数。
2. **协作层 (`core_*.lua`)**：协调逻辑流，如 `core_main` 负责主流程，`core_textflow` 负责夹注分列。
3. **处理层 (`layout_*.lua`, `render_*.lua`)**：
   - **展平 (`flatten`)**：将 TeX 节点链表转换为线性的 Lua 表。
   - **布局 (`layout`)**：计算每个字符及其附属元素的网格坐标。
   - **渲染 (`render`)**：根据坐标将内容重新组装并输出 PDF 指令。

## 2. 关键技术细节

### 竖排流向 (RTT)
利用 LuaTeX 的 `dir RTT` 属性。在 RTT 模式下，文本从上到下流动，行从右到左堆叠。

### 属性管理
使用 LuaTeX 属性（Attributes）来跨语言传递元数据（如“这是一个夹注字符”）。
> [!WARNING]
> \selectfont 会清除所有已设置的属性。请务必在设置字体大小后重新设置属性。

### 节点所有权
在 Lua 中通过 `tex.box[n] = node` 将节点交给 TeX。如果需要重用节点，必须调用 `node.copy_list()`。

## 3. 开发经验 (LEARNING)
- **颜色指令**：必须使用归一化 RGB（如 `0 0 0 rg`），不能用名称。
- **绘制顺序**：PDF 遵循画家模型，后画的覆盖先画的。背景背景颜色应在最底层插入。
- **模块加载**：统一使用 `require()` 并通过 `package.loaded` 缓存。

---

👉 更多细节请参考源码中的 `ai_must_read/LEARNING.md`。
