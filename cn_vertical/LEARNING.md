# LEARNING.md - 开发经验与教训总结

本文档记录了在开发 `cn_vertical` 项目过程中遇到的重要问题、错误原因及解决方案，帮助未来避免类似错误。

---

## 目录

1. [Lua 模块加载问题](#1-lua-模块加载问题)
2. [LuaTeX dir 属性理解](#2-luatex-dir-属性理解)
3. [字体动态缩放问题](#3-字体动态缩放问题)
4. [PDF 渲染问题](#4-pdf-渲染问题)
5. [节点管理陷阱](#5-节点管理陷阱)
6. [模块重构经验](#6-模块重构经验)

---

## 1. Lua 模块加载问题

### 问题描述
在 `cn_vertical.sty` 中使用 `\directlua` 加载 Lua 模块时，模块无法正常加载，导致后续代码失败。

### 错误原因

#### 原因 1：大型 `\directlua` 块静默失败
- **问题**：将复杂的模块加载逻辑（包含 `pcall`、`kpse.find_file` 等）放在一个大的 `\directlua` 块中
- **现象**：某处错误导致整个块失败，但错误被 `pcall()` 捕获后没有正确抛出
- **教训**：`tex.error()` 在 `\directlua` 中不会真正停止执行，只会打印警告

#### 原因 2：只设置 `package.loaded` 但未设置全局变量
```lua
-- ❌ 错误做法：只设置了 package.loaded
package.loaded['base_constants'] = result

-- ✅ 正确做法：同时设置全局变量
cn_vertical_constants = result
package.loaded['base_constants'] = result
```

#### 原因 3：`dofile` vs `require` 的选择失误
- **错误**：使用 `dofile("constants.lua")` 而不是 `require('base_constants')`
- **问题**：
  - `dofile` 需要完整文件路径，不使用 Lua 的搜索路径机制
  - `dofile` 每次都重新执行文件，无法利用 `package.loaded` 缓存
  - 模块之间的依赖关系无法正确解析

### 解决方案

**最佳实践**：
1. **使用 `require()` 而非 `dofile()`**
2. **采用统一的模块命名规范**（如 `base_constants`、`render_page` 等）
3. **在每个模块末尾注册到 `package.loaded`**：
   ```lua
   package.loaded['module_name'] = module_table
   return module_table
   ```
4. **分离模块加载块**：每个模块用独立的 `\directlua` 块加载，便于定位错误
5. **在加载前清空缓存**：
   ```latex
   \directlua{
     package.loaded["base_constants"] = nil
     package.loaded["base_utils"] = nil
     % ... 其他模块
   }
   ```

---

## 2. LuaTeX dir 属性理解

### 之前的错误观点

| 错误认知 | 正确认识 |
|---------|---------|
| ❌ "dir 无法改变字符排列方式，只能改变流动方向" | ✅ `RTT` 模式同时改变了文字流向（上下）和行流向（右左） |
| ❌ "需要复杂的节点回调来处理竖排" | ✅ 对于基本的汉字竖排，原生 `dir` 属性已足够，无需手动操作节点 |
| ❌ "vbox 简单堆叠即最好" | ✅ 简单的 vbox 堆叠无法自动处理**从右到左的换列**，`dir RTT` 原生支持多列布局 |

### 核心理解

**LuaTeX 的 `dir` 属性（特别是 `RTT` 模式）是实现中文竖排的最佳原生方案。**

关键要素：
1. **`\pardir RTT \textdir RTT`**：设置文本流向为"从上到下"，行堆叠方向为"从右到左"
2. **`\vbox dir RTT`**：创建 RTT 方向的垂直盒子
3. **显式设置 `\hsize`**：在竖排模式下，`\hsize` 定义列的高度
4. **右对齐封装**：用 `\hbox to \hsize{\hfill ...}` 包裹，确保文字在页面右侧

### 教训
不要过早假设"需要从底层重写一切"。先充分理解和利用 LuaTeX 提供的原生机制，只在必要时才进行底层节点操作。

---

## 3. 字体动态缩放问题

### 问题现象
使用 `font_scale` 参数缩放字体时，字形的水平对齐（如 `h_align="right"`）出现严重偏移，文字超出预期边界。

### 根本原因
**在 LuaTeX 中，`font.define()` 动态定义新字体后，`font.getfont(new_font_id)` 返回 `nil`。**

- `font.define()` 返回新字体 ID，但该字体的元数据未被 LuaTeX 内部缓存
- 后续尝试通过 `font.getfont(scaled_font_id)` 获取字形尺寸时失败
- 导致宽度计算返回 0 或错误值，对齐逻辑失效

### 解决方案

**在调用 `font.define()` 之前保存原始字体数据的引用**：

```lua
-- ✅ 正确做法：缩放前保存原始字体数据
local base_font_data = font.getfont(font_id)  
local font_scale_factor = params.font_scale or 1.0

-- 定义缩放字体
local scaled_font_id = font.define(...)

-- 后续获取字形尺寸时使用原始数据 × 缩放因子
if base_font_data and base_font_data.characters[cp] then
    local gw = base_font_data.characters[cp].width * font_scale_factor
    local gh = base_font_data.characters[cp].height * font_scale_factor
end
```

### 教训
- LuaTeX 的字体 API 并非所有操作都会更新全局缓存
- 动态生成的资源可能需要手动维护引用
- 关键数据应在操作前保存，而不是假设之后能重新获取

---

## 4. PDF 渲染问题

### 问题 1：文字消失（颜色指令错误）

**现象**：整页内容消失，或从某个点开始所有内容消失

**原因**：插入了非法的 PDF 语法
- ❌ 错误：`"black rg"` (PDF 不认识颜色名称)
- ✅ 正确：`"0 0 0 rg"` (必须是归一化的 RGB 数值)

**对策**：
- 所有颜色必须通过 `base_utils.normalize_rgb()` 处理
- 检查 `pdf_literal` 中的 `q` (save) 和 `Q` (restore) 是否成对

### 问题 2：背景色遮挡文字（层级问题）

**现象**：背景色正常显示，但文字被覆盖

**原因**：PDF 的"画家模型"，后绘制的内容覆盖先绘制的内容

**对策**：
- 背景必须最先绘制：使用 `insert_before(p_head, p_head, bg_node)`
- 文字在中间层
- 调试框架最后绘制（如果有）

**正确的绘制顺序**（在代码中是反向插入）：
```lua
-- 1. 最底层：背景色
p_head = background.draw_background(p_head, ...)

-- 2. 中间层：字体颜色设置
p_head = background.set_font_color(p_head, ...)

-- 3. 上层：边框、版心
p_head = border.draw_outer_border(p_head, ...)

-- 4. 最上层：应用节点坐标（文字）
-- (在主循环中处理)

-- 5. 顶层（可选）：调试框架
if draw_debug then
    p_head = utils.draw_debug_rect(...)
end
```

### 教训
- PDF 渲染是有绘制顺序的，必须严格控制
- 使用 `insert_before(head, head, node)` 在链表头部插入 = 最先绘制 = 最底层

---

## 5. 节点管理陷阱

### 问题：节点双重释放 (Double Free)

**现象**：运行时崩溃，错误信息 "node memory in use, expected value X"

**原因**：
1. 节点从链表中分离后，又被 `node.free()` 释放
2. 或者节点被两次插入不同链表，导致引用混乱

**对策**：
```lua
-- ❌ 错误做法
local n = head
head = D.getnext(head)
node.free(D.tonode(n))  -- 危险！如果 n 还在其他链表中

-- ✅ 正确做法
local n = head
D.setnext(D.getprev(n), D.getnext(n))  -- 先断链
-- 确保 n 不再被其他地方引用后再释放
```

### 问题：Textbox 属性污染

**现象**：主文档的包裹盒子被识别为 textbox，导致布局错乱

**原因**：忘记重置 textbox 相关属性

**对策**：
```lua
-- 在 core_main.lua 中创建主文档包裹盒时
node.set_attribute(new_box, constants.ATTR_TEXTBOX_WIDTH, 0)
node.set_attribute(new_box, constants.ATTR_TEXTBOX_HEIGHT, 0)
```

### 教训
- **节点的生命周期管理是 LuaTeX 编程的核心难点**
- 分离、插入、释放节点时要格外小心
- 属性在盒子生成后应该立即设置或重置

---

## 6. 模块重构经验

### 成功经验：文件命名规范

在模块化重构时，采用了**前缀命名法**：
- `base_` - 基础层
- `core_` - 协调层
- `flatten_` - 展平层
- `layout_` - 布局层
- `render_` - 渲染层

**好处**：
1. 文件列表排序时自动分组
2. 一眼就能看出模块职责
3. 避免命名冲突（如 `render.lua` vs `render_page.lua`）
4. 便于新人理解项目结构

### 重构教训：向后兼容性

**问题**：重命名模块后，旧的 `require('constants')` 调用全部失效

**对策**：
1. 统一更新所有 `require()` 调用
2. 更新 `.sty` 文件中的 `package.loaded` 清理列表
3. 更新 `dofile()` 为 `require()`

**教训**：
- 模块重命名是"全局操作"，必须一次性彻底更新所有引用
- 保持 `package.loaded` 的键名与 `require()` 的参数一致
- 重构后立即测试编译，确保没有遗漏

---

## 7. 参数传递链路管理

### 问题：新参数未能传递到底层模块

**案例**：添加 `lower-yuwei` 参数时，需要修改多个文件

**完整传递链路**：
```
cn_vertical.sty (定义参数)
    ↓ 传递给 Lua
core_main.lua (接收并转发)
    ↓ 传递给渲染层
render_page.lua (转发给子模块)
    ↓ 传递给具体模块
render_banxin.lua (使用参数)
    ↓ 传递给绘制函数
draw_banxin() (实际应用)
```

同时，如果使用 `guji.cls`，还需要：
```
guji.cls (定义 key-value)
    ↓ 传递给 cn_vertical
cn_vertical.sty
    ↓ ... 后续链路同上
```

### 教训
- **添加新参数必须完整走一遍传递链路**
- 不要遗漏中间任何一层
- 使用调试日志验证参数是否正确传递
- 文档中应该记录参数传递路径

---

## 8. 开发工作流建议

### 推荐的开发循环

1. **小步迭代**：每次只改一个功能，立即测试
2. **保留测试文件**：为每个功能创建独立的测试文件（如 `test_lower_yuwei.tex`）
3. **使用版本控制**：重构前创建分支
4. **文档同步更新**：修改代码后立即更新注释和文档

### Debug 技巧

1. **开启调试模式**：`\GujiDebugOn` 或 `debug=true`
2. **查看 PDF 日志**：使用 PDF 阅读器的开发者工具检查 PDF 结构
3. **使用 `utils.debug_log()`**：在关键位置打印变量值
4. **分步测试**：注释掉部分代码，逐步定位问题

---

## 总结：核心教训

1. **理解工具的原生能力**：不要过早自己造轮子
2. **严格的模块化和命名规范**：长远来看会节省大量时间
3. **完整的参数传递链路**：新功能必须贯穿所有层级
4. **谨慎的节点生命周期管理**：内存问题难以调试
5. **PDF 绘制顺序很重要**：层级错误会导致视觉问题
6. **保存关键数据的引用**：不要假设可以随时重新获取
7. **小步迭代，频繁测试**：问题越早发现越容易解决

---

## 9. LaTeX expl3 boolean 键的传递问题

### 问题描述
在 `guji.cls` 中将参数传递给 `cn_vertical.sty` 时，报错：
`! LaTeX Error: Key 'cn_vertical/lower-yuwei' accepts boolean values only.`

### 错误原因
在 `\keys_set:nn` 中，如果给 `.bool_set:N` 类型的键传递一个命令（如 `\bool_if:NTF ...`），它不会自动扩展该命令，而是直接检查 token 是否为 `true` 或 `false`。由于接收到的是命令 token 而非字面值，导致报错。

### 解决方案
在调用 `\keys_set:nn` 之前，先用 `\bool_if:NTF` 进行判断，然后传递字面值：

```latex
% ❌ 错误做法
\keys_set:nn { cn_vertical } {
    lower-yuwei = \bool_if:NTF \l_guji_lower_yuwei_bool { true } { false }
}

% ✅ 正确做法
\bool_if:NTF \l_guji_lower_yuwei_bool 
  { \keys_set:nn { cn_vertical } { lower-yuwei = true } }
  { \keys_set:nn { cn_vertical } { lower-yuwei = false } }
```

### 教训
- `expl3` 的 `keys_set:nn` 对布尔值校验非常严格。
- 在构建参数列表时，如果涉及布尔逻辑，应在外部处理好逻辑后再传递字面值，或者使用 `\keys_set:nx`（需谨慎处理其他参数的扩展）。
- 保持接口的一致性比底层实现的"简洁"更重要。尽管这看起来多写了几行代码，但它保证了 `\gujiSetup` 接口的统一和稳定。
