[English Version](EN:Side-Note) | 中文版

# 夹注与侧批

`luatex-cn` 提供了完善的注释系统，包括正文内的夹注和位于行间的侧批。

## 夹注 (Interlinear Notes)

夹注是古籍中常见的双行小字注释，位于正文汉字之间。

### 使用方法
```latex
这是正文\\夹注{这是夹注内容，如果内容很长，它会自动分成两列并平衡长度。}继续正文。
```

### 核心特性
- **自动平衡算法**：系统会自动计算当前列的剩余空间，并将夹注内容平分为左右两列。
- **跨列/跨页流动**：当夹注在一列内排不下时，会自动流向下一列或下一页。
- **对齐控制**：默认外侧对齐，支持 `left`, `right`, `center`, `inward`, `outward` 模式。

---

## 侧批 (Side Notes / SideNode)

侧批是位于两列正文之间或页面边缘的小字批注。

### 使用方法
```latex
正文内容\\侧批[yoffset=10pt, color=red]{这是侧向批注的内容}继续正文。
```

### 参数说明
- `yoffset`: 垂直偏移量，用于精调批注位置。
- `color`: 批注颜色（默认红色）。
- `font-size`: 批注字体大小。
- `grid-height`: 自定义网格高度。
- `border-padding-top`: 边框上边距。
- `border-padding-bottom`: 边框下边距。

### 全局配置
```latex
\sidenoteSetup{
  color = red,
  font-size = 19pt,
  grid-height = 20pt,
  yoffset = 0em,
  border-padding-top = 0.5em,
  border-padding-bottom = 0.5em
}
```

### 颜色跨页保持（v0.2.1+）
v0.2.1 引入了样式注册表机制，侧批的颜色设置现在可以正确跨页保持。即使侧批内容跨越多页，颜色也会始终一致。

---

## 技术实现 (仅供开发者)
- **夹注**：利用 LuaTeX 属性标记节点。在布局阶段，系统检测到特定属性后挂起正常排版，调用 `core_textflow.lua` 进行分列计算，然后重新映射到网格。v0.2.1 起夹注已迁移至样式栈架构。
- **侧批**：通过 `core_sidenote.lua` 管理。它将内容捕获为独立的盒子，并根据当前基准字符的位置计算偏移地址。v0.2.1 起支持 Phase 2 样式注册表进行颜色保持。
- **样式注册表**：`luatex-cn-style-registry.lua` 提供多属性样式存储，支持 color、font_size、grid_height 等属性的去重和跨页保持。

---

👉 下一步：查看 [[批注 | Annotation]] 或 [[句读 | Judou]]。
