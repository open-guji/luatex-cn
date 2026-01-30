# expl3 开发笔记与最佳实践 (Updated for luatex-cn)

在编写 `luatex-cn` 或任何基于 LaTeX3 (L3) 的宏包时，开启 ExplSyntax（通过 `\ExplSyntaxOn`）会进入一个完全不同的编程范式。
本文结合了 `luatex-cn` 项目重构过程中的实战经验，总结了编写高效、健壮的 `expl3` 代码的关键点。

## 一、 核心语法与陷阱

### 1. 空格与换行符会被完全忽略
这是初学者最容易踩的坑。在 ExplSyntax 模式下，所有的空格和换行符（ASCII 32, 9, 10, 13）都会被忽略。

-   **后果**：你写 `\cs_set:Npn \my_func:n #1 { ... }` 里的空格只是为了代码美观，编译器看不见它们。
-   **如何输入真空格**：如果你需要在输出中显式插入一个空格，必须使用 `~`（波浪号）。
-   **如何输入真换行**：建议使用 `\iow_newline:` 或在退出 `ExplSyntax` 环境后处理。

### 2. 冒号 `:` 和下划线 `_` 的特殊地位
在 `ExplSyntaxOn` 开启后，`:` 和 `_` 的 Category Code (catcode) 会变为 11（letter）。

-   **风险**：如果代码里使用了传统的宏（比如一些旧宏包定义中包含 `_`），可能会产生冲突。
-   **环境隔离**：永远记得在代码块结束时使用 `\ExplSyntaxOff`。

### 3. 变量声明
在 `expl3` 中，必须先声明后使用 (`\xxxx_new:N`)，否则在严格检查模式下会报错。

```tex
\str_new:N \l_guji_book_name_str % 声明一个局部字符串变量
\str_set:Nn \l_guji_book_name_str { 史记 } % 赋值
```

---

## 二、 严格的命名约定 (Naming Convention)

使用 `<scope>_<module>_<description>:<signature>` 格式。

-   **Scope (作用域)**：
    -   `g`: 全局 (Global)
    -   `l`: 局部 (Local)
    -   `c`: 常量 (Constant)
-   **Module (模块名)**：本项目统一使用 `luatexcn` 或 `guji`。
-   **Signature (签名)**：
    -   `n`: 普通参数（`{ ... }`）。
    -   `N`: 单个 token（控制序列）。
    -   `x`: 扩展一次参数内容 (expanded definition)。
    -   `e`: 彻底扩展示例 (expandable)。
    -   `V`: 传递变量的值 (Value)。

---

## 三、 实战经验总结 (Lessons Learned)

### 1. Lua 交互最佳实践 (`\lua_now:e` vs `\directlua`)

在 `expl3` 环境中，直接使用 `\directlua` 往往不够安全，推荐使用 `\lua_now:e`（等价于扩展后的 `\directlua`）。

**关键陷阱：Lua 代码中的空格**
由于 `ExplSyntaxOn` 忽略空格，直接写 Lua 代码会导致语法错误。
**错误写法**：
```tex
\lua_now:e { local x = 1 } % 解析为 localx=1 (Syntax Error)
```
**正确写法** (使用 `~` 代表空格，`;` 分隔语句)：
```tex
\lua_now:e { local~x~=~1;~tex.print(x) }
```
**推荐方案**：将复杂的 Lua 逻辑封装在 `.lua` 文件中，仅调用接口：
```tex
\lua_now:e { require("guji.core").process_page(\int_value:w \l_tmpa_int) }
```

### 2. 传统 TeX 原语的 expl3 替代

不要使用 `\dimen0`, `\box0`, `\setlength` 等 TeX 原语，它们在 `expl3` 中显得格格不入且容易造成寄存器冲突。

| 传统 TeX/LaTeX | expl3 替代方案 | 说明 |
| :--- | :--- | :--- |
| `\newdimen \mydim` | `\dim_new:N \l_mytask_dim` | 声明维度 |
| `\setlength{\mydim}{10pt}` | `\dim_set:Nn \l_mytask_dim { 10pt }` | 赋值 |
| `\setlength{\mydim}{0pt}` | `\dim_zero:N \l_mytask_dim` | 清零 |
| `\newbox \mybox` | `\box_new:N \l_mytask_box` | 声明盒子 |
| `\setbox\mybox=\vbox{...}` | `\vbox_set:Nn \l_mytask_box { ... }` | 盒子设置 |
| `\the\mydim` | `\dim_use:N \l_mytask_dim` | 输出带单位的值 |
| `\number\mydim` (sp) | `\dim_value:n \l_mytask_dim` | 输出纯数字 (sp) |

### 3. Key-Value 选项处理与布尔扩展

使用 `l3keys` 定义用户接口时，特别注意布尔值的传递。

**场景**：将一个布尔变量的值传给另一个模块的键。
**错误**：`\keys_set:nn { module } { option = \l_my_bool }` (传递的是 `\l_my_bool` 宏本身，而非 true/false)
**正确**：使用 `\keys_set:nx` 进行扩展：
```tex
\keys_set:nx { target_module } { option = \bool_if:NTF \l_my_bool { true } { false } }
```

### 4. 解决 IDE 警告

-   **"Need check nil"**: Lua 中 `io.popen` 可能失败返回 `nil`，必须显式检查：
    ```lua
    local handle = io.popen(cmd)
    if handle then ... end
    ```
-   **"Same file required with different names"**: 这是一个 VSCode/CommonJS 风格的警告，在 TeX/Lua 环境中通常是误报（由于 symlink 或 `kpsewhich` 路径解析），只要代码运行正常，可予以忽略。

---

## 四、 推荐的混合开发架构

针对 `luatex-cn` 项目，建议维持以下结构：

1.  **宏包声明 (`.sty`)**:
    ```tex
    \RequirePackage{expl3}
    \ProvidesExplPackage {luatex-cn} {2026/01/22} {0.1.0} {Description}
    \keys_define:nn { luatexcn } { ... }
    \ProcessKeysOptions { luatexcn }
    ```

2.  **Lua 加载**:
    ```tex
    \lua_now:e { require("luatex-cn-main") }
    ```

3.  **用户命令封装**:
    使用 `\NewDocumentCommand` (xparse) 定义用户接口，内部调用 `expl3` 函数，`expl3` 函数再调用 Lua。

    ```tex
    \NewDocumentCommand \MyUserCmd { m }
      {
        \luatexcn_internal_func:n { #1 }
      }
    
    \cs_new_protected:Npn \luatexcn_internal_func:n #1
      {
        \lua_now:e { guji.do_something("\tl_to_str:n{#1}") }
      }
    ```

---

## 五、 参数展开与传递详解 (Argument Expansion)

这是 `expl3` 最核心也最容易出错的部分。理解参数展开机制是写出正确代码的关键。

### 1. 参数类型说明符 (Argument Specifiers)

| 说明符 | 含义 | 展开行为 |
| :---: | :--- | :--- |
| `n` | Normal (普通参数) | 不展开，原样传递 `{...}` 中的内容 |
| `N` | single tokeN (单个 token) | 不展开，传递单个控制序列如 `\l_my_tl` |
| `V` | Value (变量的值) | 展开一次，获取变量内容 |
| `v` | value by name | 根据名称构造变量并获取其值 |
| `o` | Once expanded | 展开一次参数 |
| `x` | eXhaustive expansion | 完全展开（不可在展开上下文中使用） |
| `e` | Exhaustive expandable | 完全展开（可在展开上下文中使用） |
| `f` | Full expansion (first token) | 展开直到遇到不可展开的 token |
| `c` | Csname | 根据字符串构造控制序列 |

### 2. `\exp_args:N...` 的正确用法

`\exp_args:N...` 用于在调用函数前预先展开某些参数。

```tex
% 假设 \l_my_tl 包含 "hello"
\tl_new:N \l_my_tl
\tl_set:Nn \l_my_tl { hello }

% 错误：传递的是 \l_my_tl 这个控制序列本身
\some_func:nn { arg1 } { \l_my_tl }

% 正确：使用 V 展开，传递 "hello"
\exp_args:NnV \some_func:nn { arg1 } \l_my_tl
```

**重要规则**：`\exp_args:N...` 的参数说明符必须与后面的实际参数一一对应：
- 第一个字母必须是 `N`（表示函数本身不展开）
- 后续字母依次对应各个参数

```tex
% \exp_args:NnV \func {arg1} \var
%              N    n     V
%              ↓    ↓     ↓
%           \func {arg1} (value of \var)
```

### 3. 整数与 Token List 的展开差异

这是一个常见陷阱。整数寄存器在某些上下文中会自动展开为数值，但 token list 不会。

```tex
% 整数变量
\int_new:N \l_my_int
\int_set:Nn \l_my_int { 5 }

% Token list 变量
\tl_new:N \l_my_tl
\tl_set:Nn \l_my_tl { 5 }

% 在 keyval 传递时的差异：
\keys_set:nn { module } { height = \l_my_int }  % ✓ 整数自动展开为 5
\keys_set:nn { module } { height = \l_my_tl }   % ✗ 传递的是 \l_my_tl 控制序列

% Token list 需要显式展开：
\keys_set:nx { module } { height = \l_my_tl }   % ✓ x 展开后传递 5
```

### 4. xparse 可选参数的陷阱（重要！）

**问题场景**：当使用 `\NewDocumentCommand` 定义的命令带有可选参数 `O{}` 时，`\exp_args:N...` 无法正确处理方括号 `[...]`。

```tex
\NewDocumentCommand{\MyCmd}{ O{} m }{ ... }

% 错误写法：\exp_args 无法正确解析 xparse 的 [...] 语法
\tl_set:Nn \l_opts_tl { key=value }
\exp_args:NnV \MyCmd [\l_opts_tl] {content}  % ✗ 不工作！
```

**原因**：`\exp_args:N...` 按照 TeX 原生的参数规则工作（`{...}` 分组），而 xparse 的 `[...]` 是特殊的参数解析机制，不是标准的 TeX 参数。

**正确解决方案**：使用 `\use:x` 包装整个调用：

```tex
\tl_set:Nx \l_opts_tl { key=value, option=\l_some_var }
\use:x {
  \exp_not:N \MyCmd [\l_opts_tl] { \exp_not:n {content} }
}
```

**解释**：
- `\use:x { ... }` 先完全展开其参数，再执行
- `\exp_not:N \MyCmd` 保护 `\MyCmd` 不被展开
- `\l_opts_tl` 会被展开为其内容
- `\exp_not:n {content}` 保护内容不被展开

### 5. 实际案例：PiZhu 命令的修复

**原始问题代码**：
```tex
\NewDocumentCommand{\PiZhu}{ O{} +m }{%
  \group_begin:
    \keys_set:nn { luatexcn / pizhu } { #1 }
    % 直接传递 token list 变量 —— 错误！
    \TextBox[
      height=\l__luatexcn_v_pizhu_height_tl,  % 传递的是控制序列，不是值
      ...
    ]{#2}
  \group_end:
}
```

**错误尝试**：
```tex
% 尝试使用 \exp_args:NnV —— 仍然错误！
\exp_args:NnV \TextBox [\l_opts_tl]{#2}  % xparse 的 [...] 不能这样处理
```

**正确修复**：
```tex
\NewDocumentCommand{\PiZhu}{ O{} +m }{%
  \group_begin:
    \keys_set:nn { luatexcn / pizhu } { #1 }
    % 使用 \tl_set:Nx 构建选项字符串（x 展开所有变量）
    \tl_set:Nx \l_tmpa_tl {
      floating=true,
      height=\l__luatexcn_v_pizhu_height_tl,  % 会被展开为实际值
      ...
    }
    % 使用 \use:x 正确传递给 xparse 命令
    \use:x { \exp_not:N \TextBox [\l_tmpa_tl]{\exp_not:n{#2}} }
  \group_end:
}
```

### 6. 常用展开技巧速查表

| 场景 | 推荐方法 |
| :--- | :--- |
| 传递 tl 变量的值给普通函数 | `\exp_args:NnV \func {arg} \l_tl` |
| 传递多个变量值 | `\exp_args:NVV \func \l_tl_a \l_tl_b` |
| 构建完全展开的字符串 | `\tl_set:Nx \l_result_tl { ... \l_var ... }` |
| 传递给 xparse 可选参数 | `\use:x { \exp_not:N \Cmd [\l_opts]{\exp_not:n{#1}} }` |
| 保护内容不被展开 | `\exp_not:n { content }` 或 `\exp_not:N \cmd` |
| 条件展开 | `\bool_if:NTF \l_bool { true } { false }` |

### 7. 调试技巧

当不确定变量的展开结果时，可以使用以下方法调试：

```tex
% 打印 token list 的内容到终端
\tl_show:N \l_my_tl

% 打印展开后的结果
\tl_set:Nx \l_debug_tl { some=\l_var, other=\l_var2 }
\tl_show:N \l_debug_tl

% 在日志中记录
\iow_term:x { Debug:~height=\l_my_height_tl }
```

---

## 总结
使用 `expl3` 能带来极高的稳定性和命名空间隔离。虽然初期需要适应其繁琐的语法（尤其是 Lua 交互时的空格处理和参数展开机制），但对于大型项目（如古籍排版系统），这是目前最健壮的技术路线。

**核心要点**：
1. 整数自动展开，token list 需要显式展开
2. `\exp_args:N...` 只对标准 TeX 参数 `{...}` 有效
3. xparse 的 `[...]` 可选参数必须用 `\use:x` 配合 `\exp_not:N` 处理
4. 善用 `\tl_set:Nx` 预先构建展开后的内容