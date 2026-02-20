# LEARNING.md - 开发经验与教训总结

本文档记录了 `luatex-cn` 项目开发过程中的重要问题与解决方案。

---

## 目录

1. [Lua 与 LaTeX 交互](#一-lua-与-latex-交互)
2. [expl3 语法陷阱](#二-expl3-语法陷阱)
3. [LuaTeX 特有机制](#三-luatex-特有机制)
4. [PDF 渲染问题](#四-pdf-渲染问题)
5. [参数传递链路](#五-参数传递链路)
6. [特殊功能实现](#六-特殊功能实现)

---

## 一、 Lua 与 LaTeX 交互

### 1.1 `\directlua` 中的 Lua 注释陷阱

**问题**：在 `\directlua{...}` 中使用 `--` 注释会导致后续代码静默失败。

**原因**：LaTeX 将多行内容"线性化"为一行，`--` 之后的内容全部变成注释。

```latex
% ❌ 错误：整个块变成 "local x = 1 -- 注释 local y = 2"
\directlua{
  local x = 1
  -- 这是注释
  local y = 2
}

% ✅ 正确：使用多行注释或移除注释
\directlua{ local~x~=~1;~--[[注释]]--~local~y~=~2 }
```

**最佳实践**：
- 复杂 Lua 逻辑放在独立 `.lua` 文件中
- `\directlua` 只负责 `require()` 和简单调用
- 避免在 `\directlua` 中使用 `--` 行注释

### 1.2 Lua 模块加载

**问题**：模块加载失败但没有错误提示。

**解决方案**：
```lua
-- ✅ 使用 require + 全局变量
cn_vertical_constants = require('base_constants')
package.loaded['base_constants'] = cn_vertical_constants

-- ✅ 加载前清空缓存
package.loaded["module_name"] = nil
```

**命名规范**：
- `base_` - 基础层
- `core_` - 协调层
- `layout_` - 布局层
- `render_` - 渲染层

### 1.3 从 Lua 向 TeX 传递数据

```lua
-- ❌ 错误：\string 阻止命令执行
tex.print("\\string\\setmainfont{SimSun}")

-- ✅ 正确：使用 token.set_macro
token.set_macro("fontauto@fontname", "SimSun")
```

```latex
% TeX 中使用
\expandafter\setmainfont\expandafter{\fontauto@fontname}
```

---

## 二、 expl3 语法陷阱

### 2.1 空格与换行被忽略

**问题**：`ExplSyntaxOn` 模式下空格被忽略，影响配置文件加载和 Lua 代码。

```latex
% ❌ 错误：.cfg 中的 "1 0 0" 变成 "100"
\ExplSyntaxOn
\InputIfFileExists{config.cfg}{}{}

% ✅ 正确：加载配置前退出 ExplSyntax
\ExplSyntaxOff
\InputIfFileExists{config.cfg}{}{}
\ExplSyntaxOn
```

### 2.2 `\directlua` 与 expl3 不兼容

**问题**：多行 Lua 代码在 expl3 环境中被破坏。

**解决方案**：
1. 将 `\directlua` 命令定义放在 `\ExplSyntaxOff` 之后
2. 使用 `\lua_now:e` 时用 `~` 代替空格
3. 复杂逻辑放在独立 `.lua` 文件

### 2.3 布尔值传递

**问题**：`keys_set:nn` 不会自动展开布尔表达式。

```latex
% ❌ 错误：传递的是宏本身
\keys_set:nn { module } { option = \bool_if:NTF \l_bool {true}{false} }

% ✅ 正确：先判断再传递字面值
\bool_if:NTF \l_bool
  { \keys_set:nn { module } { option = true } }
  { \keys_set:nn { module } { option = false } }
```

### 2.4 Token List 空值检测

**问题**：通过 keys 系统传递的空值可能包含不可见 token。

```latex
% ❌ 可能失败
\tl_if_empty:NTF \l_var { default } { use }

% ✅ 先展开再检查
\tl_set:Nx \l_tmp_tl { \l_var }
\tl_if_empty:NTF \l_tmp_tl { default } { use }
```

### 2.5 xparse 可选参数与 `\exp_args` 不兼容

**问题**：`\exp_args:N...` 无法处理 xparse 的 `[...]` 可选参数。

```latex
% ❌ 错误
\exp_args:NnV \MyCmd [\l_opts_tl] {content}

% ✅ 正确：使用 \use:x
\tl_set:Nx \l_opts_tl { key=\l_var, ... }
\use:x { \exp_not:N \MyCmd [\l_opts_tl]{\exp_not:n{content}} }
```

### 2.6 Class/sty 文件尾部空格

**问题**：未注释的换行符导致空白页。

```latex
% ❌ 危险
\ExplSyntaxOff

\endinput

% ✅ 安全
\ExplSyntaxOff%
%
\endinput%
```

---

## 三、 LuaTeX 特有机制

### 3.1 `dir RTT` 竖排模式

**核心要素**：
- `\pardir RTT \textdir RTT`：文本从上到下，行从右到左
- `\hsize` 定义列高度（竖排模式）
- 不要过早自己造轮子，先利用原生机制

### 3.2 `\selectfont` 清除属性

**关键**：`\selectfont` 会清除所有 LuaTeX 属性！

```latex
% ❌ 错误：属性被清除
\setluatexattribute\myattr{1}
\fontsize{...}{...}\selectfont
#1  % 属性已丢失

% ✅ 正确：属性在 selectfont 之后设置
\fontsize{...}{...}\selectfont
\setluatexattribute\myattr{1}
#1  % 属性有效
```

### 3.3 节点管理

**避免双重释放**：
```lua
-- ❌ 危险：节点可能还在其他链表中
node.free(D.tonode(n))

-- ✅ 安全：先断链再释放
D.setnext(D.getprev(n), D.getnext(n))
-- 确保 n 不再被引用后再释放
```

**自定义 Whatsit 节点**：在 shipout 前必须删除，否则后端报错。

```lua
if uid == constants.MY_WHATSIT_ID then
    -- 处理完毕后删除
    p_head = D.remove(p_head, curr)
    node.flush_node(D.tonode(curr))
end
```

### 3.4 动态字体缩放

**问题**：`font.define()` 后 `font.getfont()` 返回 `nil`。

**解决**：在缩放前保存原始字体数据：
```lua
local base_font_data = font.getfont(font_id)  -- 先保存
local scaled_font_id = font.define(...)
-- 后续使用 base_font_data × scale_factor
```

### 3.5 节点所有权

`tex.box[n] = node_list` 转移所有权给 TeX。需要重用时必须复制：
```lua
tex.box[box_num] = node.copy_list(original_box)
```

---

## 四、 PDF 渲染问题

### 4.1 颜色指令

```lua
-- ❌ 错误：PDF 不认识颜色名称
"black rg"

-- ✅ 正确：归一化 RGB 数值
"0 0 0 rg"
```

### 4.2 绘制顺序（画家模型）

后绘制的覆盖先绘制的。正确顺序：
1. 背景色（最先）
2. 字体颜色
3. 边框、版心
4. 文字内容
5. 调试框架（最后）

使用 `insert_before(head, head, node)` 在最底层插入。

### 4.3 颜色堆栈泄漏

**问题**：`\color{red}` 在盒子中可能导致颜色泄漏。

**解决**：使用 `\textcolor{red}{text}`，确保 Push/Pop 成对。

### 4.4 悬浮框的位移补偿

悬浮框需要"负向补偿 Kern"实现真正的 overlay：
```lua
p_head = D.insert_before(p_head, p_head, Kern(rel_x))
D.insert_after(p_head, kern_node, box)
D.insert_after(p_head, box, Kern(-(rel_x + box_width)))  -- 补偿
```

---

## 五、 参数传递链路

### 5.1 完整链路示例

```
guji.cls (定义 key-value)
    ↓
cn_vertical.sty (接收并转发)
    ↓
core_main.lua (转发给渲染层)
    ↓
render_page.lua (转发给子模块)
    ↓
render_banxin.lua (实际使用)
```

**教训**：添加新参数必须走完整个链路，不要遗漏中间层。

### 5.2 显式传递优于隐式状态

在复杂的 LaTeX-Lua 链式调用中，参数应随调用链层层下传，避免依赖全局状态。

---

## 六、 特殊功能实现

### 6.1 筒子页 (Split Page)

**难点**：
- `\AtBeginShipout` 中不能用 `\newpage`（无限递归）
- LuaTeX 用 `\pdfextension literal` 替代 `\pdfliteral`
- 双倍宽度盒子放入单倍宽度页面会报 Overfull

**解决**：使用 `\hbox to 0pt{\smash{\copy N}\hss}` 隐藏盒子尺寸。

### 6.2 TikZ Overlay

**问题**：TikZ 的 `remember picture, overlay` 不能放在 `guji-content` 中。

**解决**：使用 shipout 钩子：
```latex
\AddToHook{shipout/foreground}{%
  \begin{tikzpicture}[remember picture, overlay]
    ...
  \end{tikzpicture}
}
```

### 6.3 动态章节标题

**方案**：基于属性的标记机制
1. Lua 维护全局注册表存储章节标题
2. `\chapter` 插入零宽标记节点，带属性 `ATTR_CHAPTER_REG_ID`
3. 布局引擎检测属性，更新当前章节
4. 按页缓存传递给渲染层

### 6.4 段落缩进泄漏

**问题**：`\end{段落}` 后的正文也被缩进。

**解决**：
1. 环境结束前重置属性
2. Lua 中只对 `indent > 0` 的节点应用列级跟踪

```lua
if indent > 0 then
    if cur_row < indent then cur_row = indent end
end
```

---

## 核心教训总结

| 类别 | 要点 |
|------|------|
| Lua 交互 | 复杂逻辑放 `.lua` 文件，`\directlua` 保持简单 |
| expl3 | 加载配置前 `\ExplSyntaxOff`，注意空格和展开 |
| 属性 | 在 `\selectfont` 之后设置，shipout 前清理自定义节点 |
| 渲染 | 注意绘制顺序，颜色用数值，悬浮框需补偿 |
| 参数 | 显式传递，完整走链路 |
| 调试 | 用 `texio.write_nl` 输出日志，Git 比对定位问题 |

---

## 调试技巧速查

```lua
-- Lua 调试输出
texio.write_nl("term and log", "[DEBUG] message")

-- 打印节点属性
print(string.format("Node ID=%d attr=%s", id,
    tostring(D.get_attribute(t, ATTR_XXX))))
```

```latex
% TeX 调试
\tl_show:N \l_my_tl
\iow_term:x { value: |\l_my_tl| }
```

```bash
# 查看特定输出
lualatex file.tex 2>&1 | grep "\[DEBUG\]"
```
