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
7. [参数传递链路管理](#7-参数传递链路管理)
8. [开发工作流建议](#8-开发工作流建议)
9. [LaTeX expl3 boolean 键的传递问题](#9-latex-expl3-boolean-键的传递问题)
10. [\\selectfont 清除 LuaTeX 属性](#10-selectfont-清除-luatex-属性)
11. [LaTeX3 \\fontsize 与正则表达式匹配问题](#11-latex3-fontsize-与正则表达式匹配问题)
12. [LaTeX3 Keys 传递空值导致 \\tl_if_empty:NTF 失败](#12-latex3-keys-传递空值导致-tl_if_emptyntf-失败)
13. [TikZ WHATSIT 节点与 cn_vertical 引擎的兼容性](#13-tikz-whatsit-节点与-cn_vertical-引擎的兼容性)
14. [\directlua 中的 Lua 注释与 LaTeX 线性化陷阱](#14-directlua-中的-lua-注释与-latex-线性化陷阱)
15. [Lua 模块阴影与参数传递链路管理](#15-lua-模块阴影与参数传递链路管理)
16. [筒子页自动裁剪实现 (Split Page)](#16-筒子页自动裁剪实现-split-page)

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

## 16. 筒子页自动裁剪实现 (Split Page)

### 问题描述
实现中国古籍的筒子页装订形式：一张横向大纸（如 297mm × 210mm）自动裁剪为两张竖向小纸（148.5mm × 210mm），右半页先输出，左半页后输出。

### 技术难点

#### 难点 1：`\AtBeginShipout` 无法使用 `\newpage`
最初尝试使用 `atbegshi` 包在 shipout 时进行裁剪：
```latex
% ❌ 错误做法：会导致无限递归
\AtBeginShipout{
    % 输出右半页
    \shipout\box\AtBeginShipoutBox
    % 输出左半页
    \newpage  % 错误！newpage 会触发新的 shipout，造成无限循环
}
```
**原因**：`\AtBeginShipout` 钩子在 shipout 过程中执行，此时调用 `\newpage` 会触发新的 shipout，形成递归。

#### 难点 2：LuaTeX 的 `\pdfliteral` 语法
LuaTeX 不支持 pdfTeX 的 `\pdfliteral` 命令：
```latex
% ❌ pdfTeX 语法（LuaTeX 不支持）
\pdfliteral{q 0 0 100 200 re W n}

% ✅ LuaTeX 语法
\pdfextension literal{q 0 0 100 200 re W n}
```

#### 难点 3：`tex.box` 赋值与 `\copy` 的节点所有权
当 Lua 通过 `tex.box[n] = node_list` 设置盒子后，该节点列表的所有权转移给 TeX。如果在同一页需要多次使用该盒子（分别输出左右半页），必须使用 `node.copy_list()` 复制节点：

```lua
-- ❌ 错误做法：节点被第一次输出消耗后，第二次 \copy 获取的是空盒
function vertical.load_page(box_num, index)
    tex.box[box_num] = _G.vertical_pending_pages[index + 1]
end

-- ✅ 正确做法：复制节点列表
function vertical.load_page(box_num, index, copy)
    local box = _G.vertical_pending_pages[index + 1]
    if box then
        if copy then
            tex.box[box_num] = node.copy_list(box)  -- 保留原件
        else
            tex.box[box_num] = box
        end
    end
end
```

### 最终解决方案

**在 `vertical.process_from_tex()` 中实现分页输出**：

```lua
if split_enabled then
    for i = 0, total_pages - 1 do
        -- 加载页面（使用 copy=true 保留原件供第二半页使用）
        tex.print(string.format("\\directlua{vertical.load_page(%d, %d, true)}", box_num, i))

        -- 设置输出页面为半宽
        tex.print(string.format("\\global\\pagewidth=%.5fpt", target_w_pt))
        tex.print(string.format("\\global\\pageheight=%.5fpt", target_h_pt))

        -- 输出右半页：将内容左移，使右半部分对齐到页面左边缘
        tex.print(string.format("\\noindent\\kern-%.5fpt\\copy%d", target_w_pt, box_num))

        -- 换页，输出左半页（不需要偏移）
        tex.print("\\newpage")
        tex.print(string.format("\\noindent\\copy%d", box_num))
    end
end
```

### 架构设计

```
ltc-guji.cls
    ├── 定义 split-page / split-page-right-first 键
    ├── 调用 \splitpageSetup 配置 Lua 模块
    └── 调用 \enableSplitPage 启用功能
           ↓
luatex-cn-splitpage.sty
    ├── 定义 LaTeX 接口 (\splitpageSetup, \enableSplitPage)
    └── 调用 Lua 模块 splitpage.configure() / splitpage.enable()
           ↓
luatex-cn-splitpage.lua
    ├── 存储配置 (source_width, source_height, right_first)
    └── 提供查询函数 (is_enabled(), get_target_width(), ...)
           ↓
luatex-cn-vertical-core-main.lua
    └── process_from_tex() 检查 splitpage.is_enabled()
        ├── true: 每页输出两次（右半+左半），设置半宽页面
        └── false: 正常输出
```

### 教训

1. **理解 TeX 的 shipout 机制**：
   - `\AtBeginShipout` 在 shipout 过程中执行，不能触发新的 shipout
   - 要在 shipout 之前完成所有页面分割逻辑

2. **LuaTeX 特有语法**：
   - `\pdfextension literal` 替代 `\pdfliteral`
   - `\pdfextension` 系列命令是 LuaTeX 的标准 PDF 操作方式

3. **节点所有权管理**：
   - `tex.box[n] = node` 将节点所有权转移给 TeX
   - 需要重用节点时必须使用 `node.copy_list()`
   - 原始节点列表保存在 `_G.vertical_pending_pages` 中可供多次复制

4. **PDF 裁剪的替代方案**：
   - 不使用 PDF clipping path (`q ... re W n ... Q`)
   - 直接依赖 `\pagewidth` / `\pageheight` 设置页面边界
   - 内容超出边界会被 PDF 查看器自动裁剪

5. **调试技巧**：
   - 检查 "node memory still in use" 数值变化判断节点是否正确保留
   - 使用 `pdfinfo` 验证输出页面尺寸
   - 在 Lua 中添加 `texio.write_nl()` 输出调试信息

### 相关代码位置
- 配置模块：`src/splitpage/luatex-cn-splitpage.lua`
- LaTeX 接口：`src/splitpage/luatex-cn-splitpage.sty`
- 类文件集成：`src/ltc-guji.cls`（第 222-228, 268-281 行）
- 核心输出逻辑：`src/vertical/luatex-cn-vertical-core-main.lua`（`process_from_tex` 函数）

---

## 总结：核心教训

1. **理解工具的原生能力**：不要过早自己造轮子
2. **严格的模块化和命名规范**：长远来看会节省大量时间
3. **完整的参数传递链路**：新功能必须贯穿所有层级
4. **谨慎的节点生命周期管理**：内存问题难以调试
5. **PDF 绘制顺序很重要**：层级错误会导致视觉问题
6. **保存关键数据的引用**：不要假设可以随时重新获取
7. **小步迭代，频繁测试**：问题越早发现越容易解决
8. **理解 TeX/LuaTeX 的特有机制**：如 shipout 钩子限制、`\pdfextension` 语法、节点所有权等

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

---

## 10. \selectfont 清除 LuaTeX 属性

### 问题描述
夹注（jiazhu）文字完全消失，虽然 `\jiazhu` 命令被调用（能看到 debug 输出），但渲染时检测不到 jiazhu 属性。

### 根本原因
**`\selectfont` 命令会清除当前活动的所有 LuaTeX 属性！**

在 commit acf4b5d 中，`\setluatexattribute` 被错误地移到了 `\selectfont` **之前**：

```latex
% ❌ 错误做法（导致属性丢失）
\NewDocumentCommand{\jiazhu}{ +m }
  {
    \group_begin:
    \setluatexattribute\cnverticaljiazhu{1}  % ← 属性设置
    \fontsize{...}{...}\selectfont          % ← selectfont 清除了属性！
    #1  % ← 此时属性已经丢失
    \group_end:
  }
```

### 调试过程
1. **现象**：PDF 中夹注文字不显示
2. **初步排查**：以为是属性保留问题，在 `flatten_nodes.lua` 中添加了属性复制代码
3. **深入调试**：添加 debug 日志，发现 `[flatten] Found JIAZHU` 根本没有输出
4. **关键发现**：属性在 TeX 层就已经丢失，根本没有到达 Lua
5. **对比历史**：检查 commit cc9cee4（工作版本）vs acf4b5d（损坏版本），发现 `\setluatexattribute` 的位置被改变了

### 解决方案
**属性必须在字体选择之后设置**：

```latex
% ✅ 正确做法
\NewDocumentCommand{\jiazhu}{ +m }
  {
    \group_begin:
    
    % 1. 先进行字体缩放
    \fontsize{...}{...}\selectfont
    
    % 2. CRITICAL: 在 selectfont 之后设置属性
    \setluatexattribute\cnverticaljiazhu{1}
    
    % 3. 现在渲染内容，属性有效
    #1
    \group_end:
  }
```

### 教训
1. **`\selectfont` 是一个"破坏性"操作**，会重置字体相关的许多状态，包括 LuaTeX 属性
2. **属性设置的时机至关重要**：
   - ✅ 在 `\selectfont` **之后**设置 = 属性生效
   - ❌ 在 `\selectfont` **之前**设置 = 属性丢失
3. **调试属性问题的方法**：
   - 在 Lua 的 flatten 阶段加 debug：`D.get_attribute(node, ATTR_XXX)`
   - 在 layout 阶段加 debug：检查属性是否存在
   - 从底层往上查，确定属性在哪一层丢失
4. **Git 比对的重要性**：
   - 当功能突然损坏时，对比上一个工作版本
   - 查找细微的改动（如本次的代码顺序调整）
5. **文档化边界条件**：像 `\selectfont` 这种会清除属性的命令应该在代码注释中明确标注

### 相关代码位置
- 修复位置：`cn_vertical.sty` 第 530 行
- 影响模块：所有依赖 `\jiazhu` 命令的功能
- 提交记录：acf4b5d 引入bug，本次修复

---

## 11. LaTeX3 `\fontsize` 与正则表达式匹配问题

### 问题描述
夹注（jiazhu）字符在 PDF 中不显示，虽然节点存在于布局映射中，调试日志显示字符被正确定位，但字体大小只有 0.70pt（应该是 19.6pt）。

### 调试过程
1. **现象**：夹注区域空白，普通字符正常显示
2. **初步排查**：检查节点复制、布局计算，均正常
3. **关键发现**：在 render 阶段输出字形尺寸：
   ```
   [render] GLYPH char=40643 [c:0, r:0] w=28.00 h=21.00 fsize=28.00  # 正常字符
   [render] GLYPH char=23569 [c:0, r:3] w=0.70 h=0.50 fsize=0.70     # 夹注字符！
   ```
4. **定位问题**：字体大小是 0.70pt 而不是 19.6pt（28 × 0.7）

### 根本原因

**LaTeX3 的 `\regex_match:nnTF` 对于简单数值字符串的匹配有问题。**

原代码试图用正则表达式检测 jiazhu-size 参数是否是纯数字（缩放因子）：

```latex
% ❌ 问题代码
\regex_match:nnTF { ^[0-9\.]+$ } { \l_tmpa_tl }  % "0.7" 却不匹配！
  {
    % 缩放因子逻辑（从未执行）
    \fontsize{\fp_eval:n { 0.7 * 28 } pt}...
  }
  {
    % 直接使用值（错误地执行了这个分支）
    \fontsize{0.7}{0.7}\selectfont  % 创建了 0.7pt 的字体！
  }
```

正则表达式 `^[0-9\.]+$` 在 LaTeX3 中可能因为 catcode 或其他原因无法匹配 "0.7" 这样的字符串。

### 解决方案

**简化设计：移除缩放因子支持，要求显式指定字体大小（带单位）**：

```latex
% ✅ 正确做法：默认计算，用户可覆盖
\tl_if_empty:NTF \l__cn_vertical_jiazhu_size_tl
  {
    % 默认：当前字体的 70%
    \tl_set:Nx \l_tmpa_tl { \fp_eval:n { 0.7 * \f@size } pt }
  }
  {
    % 用户指定（必须带单位如 "14pt"）
    \tl_set_eq:NN \l_tmpa_tl \l__cn_vertical_jiazhu_size_tl
  }
\fontsize{\l_tmpa_tl}{\l_tmpa_tl}\selectfont
```

**设计决策**：
- 不再支持缩放因子（如 "0.7"），必须使用完整的尺寸值（如 "14pt"）
- 默认值在代码中计算（0.7 × 当前字体），而非在参数声明中
- 参数名从 `jiazhu-size` 改为 `jiazhu-font-size`，更明确

### 教训
1. **简单设计优于灵活设计**：
   - 支持两种格式（缩放因子和绝对尺寸）增加了复杂性
   - 用户使用时也更容易混淆
   - 强制使用带单位的值更加明确
2. **调试字体问题时检查尺寸**：
   - 在 Lua 层打印 `font.getfont(id).size`
   - 比较正常字符和问题字符的字体 ID 和尺寸
3. **默认值的位置**：
   - 复杂的默认值（需要计算）应该在使用处计算
   - 简单的默认值才应该在参数声明中设置
4. **参数命名要明确**：
   - `jiazhu-font-size` 比 `jiazhu-size` 更清晰
   - 用户一眼就知道需要提供字体大小值

### 相关代码位置
- 修复位置：`cn_vertical.sty` 第 515-525 行
- 参数名：`jiazhu-font-size`（从 `jiazhu-size` 重命名）
- 影响功能：夹注（jiazhu）字体大小设置

---

## 12. LaTeX3 Keys 传递空值导致 `\tl_if_empty:NTF` 失败

### 问题描述
在修复 #11 后，夹注字符再次消失。调试发现 `\l__cn_vertical_jiazhu_size_tl` 被 `\tl_if_empty:NTF` 判定为"非空"，即使它看起来是空的。

### 原因分析
问题出现在 `guji.cls` 向 `cn_vertical.sty` 传递参数的方式：

```latex
% guji.cls
\cnvSetup{
    jiazhu-font-size = \l_guji_jiazhu_font_size_tl  % 传递空 tl
}
```

当 `\l_guji_jiazhu_font_size_tl` 为空时，expl3 keys 系统仍然会"设置"目标变量，但可能会留下不可见的内容（如空的分组 `{}`）。`\tl_if_empty:NTF` 检查的是 token 级别的空，而不是"看起来空"。

### 解决方案
先展开变量再检查：

```latex
% 错误 - 直接检查可能失败
\tl_if_empty:NTF \l__cn_vertical_jiazhu_size_tl { default } { use }

% 正确 - 先展开再检查
\tl_set:Nx \l_tmpb_tl { \l__cn_vertical_jiazhu_size_tl }
\tl_if_empty:NTF \l_tmpb_tl { default } { use }
```

### 教训
1. **LaTeX3 的 `\tl_if_empty:NTF` 是严格的 token 检查**：
   - 空分组 `{}` 不等于真正的空
   - keys 系统传递空值时可能留下不可见 token
2. **调试时打印带分隔符的内容**：
   - `\iow_term:x { value: |\the_var| }` 可以看到边界
3. **跨模块传递可选参数时要小心**：
   - 从一个 cls/sty 传递到另一个时，空值处理需要特别注意
   - 考虑在接收方做展开检查

---

## 13. TikZ WHATSIT 节点与 cn_vertical 引擎的兼容性

### 问题描述
尝试将 TikZ 的 `tikzpicture` 环境（带 `remember picture, overlay`）直接放入 `guji-content` 环境中，期望引擎能正确处理并渲染图片叠加层。结果是图片完全不显示。

### 调试过程
1. **现象**：TikZ 图片在 PDF 中不可见，即使 `\includegraphics` 单独使用时正常
2. **初步排查**：添加 WHATSIT 节点处理代码到 `flatten_nodes.lua`、`layout_grid.lua`、`render_page.lua`
3. **深入调试**：添加详细的 `print()` 日志跟踪节点流经整个管道
4. **关键发现**：
   - `flatten_nodes.lua` **能看到** WHATSIT 节点（ID=8，S=29）
   - `layout_grid.lua` **看不到** 任何 ID=8 节点
   - `render_page.lua` **能看到** WHATSIT 节点（ID=8，S=16），但标记为 `[NOT POSITIONED]`

### 根本原因
**TikZ 的 `remember picture, overlay` 机制设计为在 `\shipout` 时处理，而非在文本流中处理。**

深层技术原因：
1. **节点复制问题**：`flatten_nodes.lua` 使用 `D.copy(t)` 创建节点副本，`layout_map` 使用副本指针作为键
2. **嵌套结构**：TikZ 创建的 WHATSIT 节点深嵌在 HLIST 中，无法完整地通过展平-布局-渲染管道
3. **子类型不匹配**：不同阶段看到不同子类型（S=29 vs S=16），表明节点在传递中被分裂
4. **指针失效**：`render_page.lua` 看到的 WHATSIT 节点与 `layout_grid.lua` 定位的不是同一批节点

### 解决方案

**使用 `\AddToHook{shipout/foreground}` 或 `\AddToHook{shipout/background}` 钩子**：

```latex
% ✅ 正确做法：使用 shipout 钩子
\AddToHook{shipout/foreground}{%
  \ifnum\value{page}=1
    \begin{tikzpicture}[remember picture, overlay]
      \node[anchor=north east, opacity=0.7, ...] at (current page.north east) {
        \includegraphics[width=12.9cm]{image.png}
      };
    \end{tikzpicture}
  \fi
}

% ❌ 错误做法：直接放入 guji-content
\begin{guji-content}
  \begin{tikzpicture}[remember picture, overlay]
    ...  % 图片不会显示
  \end{tikzpicture}
\end{guji-content}
```

### 保留的 WHATSIT 处理代码
虽然 TikZ overlay 不适用，但为其他可能的 WHATSIT 用例保留了处理代码：

- **`flatten_nodes.lua`**（第 168-172 行）：
  ```lua
  elseif tid == constants.GLUE or tid == constants.WHATSIT then
      if tid == constants.WHATSIT or subtype == 0 or ... then
         keep = true
         if tid == constants.WHATSIT then has_content = true end
      end
  ```

- **`layout_grid.lua`**（第 181-191 行）：
  ```lua
  if id == constants.WHATSIT then
      layout_map[t] = { page = cur_page, col = cur_col, row = cur_row }
      t = D.getnext(t)
      goto start_of_loop
  end
  ```

- **`render_page.lua`**（第 243-245 行）：
  ```lua
  elseif id == constants.WHATSIT then
      -- Keep WHATSIT nodes in the list for TikZ/other special content
      -- Note: For TikZ overlay, use shipout hooks instead
  ```

### 教训
1. **理解工具的设计用途**：
   - TikZ 的 `remember picture, overlay` 是专为页面级叠加设计的
   - 它依赖 `\shipout` 回调来定位绝对坐标
   - 不要强行将其嵌入不兼容的排版流程

2. **节点指针是敏感的**：
   - `D.copy()` 创建的副本有不同的指针地址
   - `layout_map` 使用指针作为键，副本和原件无法匹配
   - 复杂的节点结构在多阶段处理中容易丢失引用

3. **调试 WHATSIT 节点的方法**：
   - 使用 `print()` 而非 `utils.debug_log()`（后者依赖 debug 标志）
   - 打印节点地址、ID 和 subtype：`print(string.format("[...] Node=%s ID=%d S=%d", tostring(t), id, subtype))`
   - 在每个阶段（flatten/layout/render）都添加跟踪

4. **正确的图片叠加方案**：
   | 场景 | 推荐方案 |
   |------|---------|
   | 页面背景/水印 | `\AddToHook{shipout/background}` |
   | 页面前景/印章 | `\AddToHook{shipout/foreground}` |
   | 仅特定页面 | 在钩子中加 `\ifnum\value{page}=N` |
   | 文字流中的图片 | 不使用 TikZ，直接用 `\includegraphics` 或自定义 Textbox |

### 相关代码位置
- 修复位置：`shiji.tex` 第 7-16 行
- 受影响模块：`flatten_nodes.lua`、`layout_grid.lua`、`render_page.lua`（已添加 WHATSIT 处理，但对 TikZ overlay 无效）

---

## 14. \directlua 中的 Lua 注释与 LaTeX 线性化陷阱

### 问题描述
在 `cn_vertical.sty` 或 `guji.cls` 的 `\directlua` 块中添加 Lua 注释（`--`）后，注释行之后的代码全部失效，且没有任何明显的报错信息，导致功能（如钩子注册）静默失败。

### 根本原因
**LaTeX 在处理 `\directlua{...}` 时，会将多行内容"线性化"（Linearize）合并为一行再交给 Lua 引擎。**

- **线性化效应**：
  在 LaTeX 中：
  ```latex
  \directlua{
    local x = 1
    -- 这是一个注释
    local y = 2
  }
  ```
  传给 Lua 的实际字符串可能变成：
  `local x = 1 -- 这是一个注释 local y = 2`
  由于 Lua 的 `--` 注释会一直持续到行尾，因此整个块中 `--` 之后的内容全部变成了注释的一部分。

- **特殊字符冲突**：
  - `%` 在 LaTeX 中是注释符。在 Lua 中是取模运算符。
  - 在 `\directlua` 中使用时，必须使用 `\%`，否则 LaTeX 会直接截断该行。

### 调试过程
1. **现象**：修改了钩子逻辑但没有任何变化。
2. **初步怀疑**：路径不对或缓存没清理。
3. **深入调试**：通过打印 `tostring(hook_function)` 发现地址一直是默认实现的，说明注册代码从未执行。
4. **关键定位**：在注册代码前添加 `print("[A]")` 能输出，在注册代码后添加 `print("[B]")` 不输出。
5. **发现元凶**：在 `[A]` 和 `[B]` 之间存在 `--` 开头的 Lua 注释。

### 解决方案

**最佳实践**：
1. **避免在 `\directlua` 中使用 Lua 行注释 (`--`)**：
   - 如果必须注释，使用 Lua 多行注释：`--[[ 注释内容 ]]--`。
   - 更好的做法是彻底移除这些注释。
2. **转义关键字符**：
   - 始终使用 `\%` 进行取模运算。
3. **保持 Lua 逻辑精简**：
   - 复杂的逻辑应放在独立的 `.lua` 文件中。
   - `\directlua` 只负责 `require()` 和简单的配置。
4. **包装宏必须定义为 "Long"**：
   - 如果使用 `\NewDocumentCommand` 定义包装宏（如 `\cnvLua`），必须使用 `+m` 而非 `m`，否则 Lua 代码块中的空行会导致 `Runaway argument` 错误。
   ```latex
   \NewDocumentCommand{\cnvLua}{ +m }{ \directlua{... #1 ...} }
   ```
5. **添加"身份验证"打印**：
   - 在加载前后打印唯一标记，确认代码块完整执行。

### 教训
1. **静默失败是最难调试的**：如果代码没有报错但不按预期运行，优先检查它是否被"注掉"了。
2. **环境边界意识**：始终记住 Lua 代码是包裹在 LaTeX 宏中的，它遵循 LaTeX 的读取规则。
3. **使用 pcall 捕获加载错误**：
   ```latex
   \directlua{
     local status, err = pcall(function() require('module') end)
     if not status then print("ERROR: " .. err) end
   }
   ```
   *注意：如果语法错误发生在线性化阶段，pcall 也可能无法挽救，因此保持代码块简洁是第一优先。*

### 相关代码位置
- 修复位置：`cn_vertical.sty` 和 `guji.cls`
- 影响模块：所有通过 LaTeX 包加载的 Lua 逻辑
- 提交记录：2026-01-15 解决版心加载问题

---

## 15. Lua 模块阴影与参数传递链路管理

### 问题描述
在重构项目结构后，版心的书名垂直居中失效，且鱼尾颜色始终为黑色（即使配置中已将其设为红色）。

### 根本原因
1. **Lua 模块阴影 (Shadowing)**：由于重构不彻底，`src/banxin` 目录下残留了旧的 `banxin_main.lua`。LuaTeX 优先加载了此旧模块，覆盖了新架构中的钩子注册，导致所有渲染逻辑改动失效。
2. **显式参数传递缺失**：在从 LaTeX 到 Lua 底层渲染函数的长链条中，`font_size` 等关键参数在中间层（如 `render_page.lua`）被遗漏，导致底层渲染模块无法获取正确上下文进行居中计算。

### 解决方案
1. **彻底清理冗余目录**：删除 `src/banxin` 和 `texmf` 中的残留目录，确保代码唯一性，消除加载冲突。
2. **完善显式传递链**：在渲染流程的每一级函数调用和钩子分发中，确保手动转发 `params.font_size` 和 `color_str` 等关键绘图参数。
3. **块居中算法优化**：在 `render_banxin.lua` 中实现"块居中"（Block Centering）计算。先算出字符总高度，再作为整体计算偏移，并添加字号自动缩减（Cap）机制防止文本超出边框。

### 教训
- 项目重构时，彻底清理残留代码（尤其是那些在全局命名空间注册钩子的代码）比编写新代码更重要。
- 在复杂的 LaTeX-Lua 链式调用中，**显式传递优于隐式状态或默认值**。参数应随调用链层层下传。
- `debug.getinfo` 在脚本环境中可能受限，通过 `print()` 打印加载路径是解决模块定位冲突的最有效手段。

---

## 17. 竖排段落换列与内容丢失陷阱

### 问题描述
在实现段落环境（Paragraph）自动换列功能后，出现两个严重问题：
1. **内容消失**：段落内的所有内容（如夹注）在编译后完全不可见。
2. **多余空列**：文档中出现了预料之外的完全空白的物理列，尤其是在标题和列表之前。

### 根本原因

#### 原因 1：Glue 预读逻辑吞噬视觉内容
在排版引擎处理胶水（Glue，对应 LaTeX 中的 `\parskip` 或 `\Space`）时，为了正确处理相互抵消的正负间距，会进行预读（Lookahead）累加：
- **错误**：预读循环没有设置中断条件，导致它会"吞噬"后面紧跟的视觉节点。
- **后果**：如果胶水后面紧跟文字（Glyph），累积逻辑会一直预读并跳过这些节点。由于这些节点被"预览"过但在主循环中被跳过，它们最终没有被赋予任何坐标位置，从而在渲染阶段被丢弃。

#### 原因 2：冗余的换列触发与空列
- **原因**：当多个 `\par` 或 `penalty` 节点（段落分隔符）连续出现时，引擎如果对每个节点都执行换列逻辑，就会产生多个换列请求。
- **具体表现**：在古籍排版中，标题、列表项往往带有特定的缩进。如果引擎在还没有放置任何实际内容时（即 `cur_row <= cur_column_indent`），就收到 `penalty` 信号而强制换列，就会产生一个多余的空白列。

### 解决方案

#### 1. 修正预读终结条件 (Lookahead Termination)
在 `layout_grid.lua` 的胶水累加循环中，必须明确指定何时停止预读：
- ✅ **停止于视觉节点**：遇到 `GLYPH`、`HLIST`、`VLIST`、`RULE` 等必须立即停止累加。
- ✅ **停止于强制换列符**：遇到 `penalty <= -10000` 时停止。
- ✅ **跳过非视觉节点**：可以跳过 `WHATSIT`、`MARK`、`KERN`（除非将其计入间距）等。

#### 2. 引入首行间距压制 (Leading Spacing Suppression)
模拟 TeX 抛弃页首胶水的行为：
- **逻辑**：如果当前位置处于列首或缩进区内（`cur_row <= cur_column_indent`），则忽略后续的胶水间距累加。
- **换列保护**：只有当前列已经放置过内容（`cur_row > cur_column_indent`）时，`penalty` 节点才能触发物理换列逻辑。

### 教训
1. **预读必须有界**：任何涉及 `while lookahead` 的逻辑都必须有严密的退出条件，否则会造成内容丢失。
2. **状态与位置的区分**：排版引擎必须能区分"由于缩进产生的位移"和"由于内容产生的位移"。只有后者才具备触发换列的资格。
3. **节点类型的敏感性**：在自定义布局引擎中，对每一类节点的作用范围必须有精确的定义，不能简单跳过或默认处理。

---

## 18. 分页裁剪（筒子页）模式下的坐标参考系陷阱

### 问题描述
在启用分页裁剪（筒子页）模式后，通过 `shipout/foreground` 钩子添加的印章（Seal）消失。即使印章被定义在第一页，在生成的 PDF 前两页（对应原始第一页的左右两半）中也完全看不见。

### 根本原因
1. **纸张尺寸与页面尺寸的差异**：
   - 在古籍排版引擎中，原始页面（Spread）是非常宽的（如 40cm）。
   - 分页逻辑在 `shipout` 时动态修改了 `\pagewidth` 为半宽（如 20cm），以此实现裁剪。
   - 此时 `\paperwidth` 可能仍然保留原始的全宽值。
2. **TikZ 定位参考点失效**：
   - 之前的代码使用 `at (\paperwidth, 0)` 作为右上角参考点。
   - 在裁剪后的半宽页面上，这个坐标落在了可见的 `\pagewidth` 范围之外，导致印章被"逻辑裁剪"掉。
3. **钩子触发频率不足**：
   - 原始的一页内容被拆分为两个物理页输出，但基于 `\value{page}` 的钩子通常只在第一个物理页（右半页）触发。如果是跨页的大印章，左半部分会丢失。

### 解决方案

#### 1. 使用 `\pagewidth` 代替 `\paperwidth`
在 `shipout` 钩子中，`\pagewidth` 代表当前正在输出的物理页面的真实宽度。使用 `(\pagewidth, 0)` 始终能对齐到当前物理页的右上角。

#### 2. 双页钩子注册逻辑 (Spread-to-Physical Mapping)
如果检测到处于分页裁剪模式，必须为两个连续的物理页注册印章：
- **物理页 2N-1 (通常是右半页)**：
  - 锚点：`(\pagewidth, 0)`
  - 偏移：`xshift = -\g_yinzhang_xshift_tl` (正常向左偏移)
- **物理页 2N (通常是左半页)**：
  - 锚点：`(\pagewidth, 0)`
  - 偏移：`xshift = \pagewidth - \g_yinzhang_xshift_tl`
  - *原理*：由于左半页本质上是原始 spread 的左半部分，其相对于原始右上角的偏移量需要加上一个物理页宽，从而将其"拉回"到可见区域。

### 教训
1. **动态改宽环境下避免使用 \paperwidth**：在涉及页面裁剪或拼接的底层开发中，`\pagewidth` 是比 `\paperwidth` 更可靠的视图边界参考。
2. **物理页 vs 逻辑页**：当一个逻辑页面对应多个物理输出时，所有基于页面钩子的视觉元素（印章、水印、页码）都必须重新映射其坐标和触发频率。
3. ** foreground 钩子是最后的防线**：确保印章在最终渲染阶段处于最顶层，且不随文字流滚动或裁剪。

### 相关代码位置
- 修复位置：`ltc-guji.cls` 中的 `\YinZhang` 命令实现。
- 影响场景：所有启用 `split-page=true` 且带有前景叠加图案的古籍文档。
