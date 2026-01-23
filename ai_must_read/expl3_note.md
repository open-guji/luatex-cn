在编写 luatex-cn 或任何基于 LaTeX3 (L3) 的宏包时，开启 ExplSyntax（通过 \ExplSyntaxOn）会进入一个完全不同的编程范式。

为了避免你在处理古籍排版逻辑时遇到难以调试的错误，以下是编写 expl3 代码时最重要的注意事项：

1. 空格与换行符会被完全忽略
这是初学者最容易踩的坑。在 ExplSyntax 模式下，所有的空格和换行符（ASCII 32, 9, 10, 13）都会被忽略。

后果：你写 \cs_set:Npn \my_func:n #1 { ... } 里的空格只是为了代码美观，编译器看不见它们。

如何输入真空格：如果你需要在输出中显式插入一个空格，必须使用 ~（波浪号）。

如何输入真换行：在 expl3 中，通常建议使用控制序列（如 \iow_newline:）或在退出 ExplSyntax 环境后处理。

2. 严格的命名约定 (Naming Convention)
expl3 强制要求使用一种类似于“命名空间”的结构，这对于你管理 open-guji 项目下的多个子模块（如 ID 生成、标点处理）非常有帮助。

一个标准的名称格式为：\<scope>_<module>_<description>:<signature>

Scope (作用域)：

g: 全局 (Global)

l: 局部 (Local)

c: 常量 (Constant)

Module (模块名)：你应该统一使用 guji 或 luatexcn。

Signature (签名)：描述参数类型，非常重要。

n: 普通参数（包裹在 { } 中）。

N: 单个标记（不带 { } 的控制序列）。

c: 动态生成的控制序列名（从字符串转为命令名）。

V: 传递变量的值 (Value)。

3. 变体 (Variants) 的威力与陷阱
在古籍处理中，你经常需要把一个变量的值传给函数。

错误写法：\my_func:n { \l_tmpa_str }（这会把命令本身传进去，而不是内容）。

正确写法：

先定义变体：\cs_generate_variant:Nn \my_func:n { V }

调用变体：\my_func:V \l_tmpa_str

4. 冒号 : 和下划线 _ 的特殊地位
在 ExplSyntaxOn 开启后，: 和 _ 的 Category Code (catcode) 会变为 11（letter），这意味着它们可以像普通字母一样组成命令名。

风险：如果你在代码里使用了传统的宏（比如一些旧的宏包定义中包含 _），可能会产生冲突。

环境隔离：永远记得在代码块结束时使用 \ExplSyntaxOff。

5. 变量声明
在传统的 LaTeX 中，你可以随时用 \def 创建宏。但在 expl3 中，必须先声明后使用，否则在严格检查模式下会报错。

Code snippet
\str_new:N \l_guji_book_name_str % 声明一个局部字符串变量
\str_set:Nn \l_guji_book_name_str { 史记 } % 赋值
6. 开发建议：针对你的项目
调试神器：在开发 luatex-cn 时，如果逻辑跑不通，可以在命令前加上 \iow_term:n { ... } 或使用 \prop_show:N 等“show”类命令，它们会将变量内容直接打印在终端输出里。

Lua 交互：由于你在用 Lua 處理古籍數據，记得 \lua_now:n 里的代码也是受 ExplSyntax 影响的。如果 Lua 代码里有下划线，可能会导致解析错误。

技巧：通常建议将复杂的 Lua 逻辑封装在独立的 .lua 文件中，然后在 .dtx 或 .sty 中仅通过一个简单的 \lua_now:n { require("guji").func() } 来调用