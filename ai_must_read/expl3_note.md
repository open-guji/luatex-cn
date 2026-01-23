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



针对你目前正在开发的 luatex_cn 宏包和 open-guji 项目，我为你整理了一个**「混合开发架构」**的推荐方案。这个方案结合了 expl3 的严谨界面和 Lua 的强大处理能力，是目前开发 LuaTeX 宏包的最优解。expl3 + Lua 混合宏包标准架构你可以将你的 .sty 文件按照以下结构组织：1. 宏包声明与开启语法Code snippet\NeedsTeXFormat{LaTeX2e}
\RequirePackage{expl3, l3keys2e}
\ProvidesExplPackage {luatex_cn} {2026/01/22} {0.1.2} {古籍数字化排版工具集}

% 开启 ExplSyntax (ProvidesExplPackage 会自动开启，但显式写出有助于理清逻辑)
2. 定义用户选项 (l3keys)这是 expl3 最强大的部分，替代了旧的 keyval。Code snippet\keys_define:nn { guji }
  {
    font .tl_set:N = \l_guji_font_tl,
    font .initial:n = { Venyuange },
    punct .choices:nn = { auto, manual } 
      { \str_set:Nn \l_guji_punct_mode_str { \l_keys_choice_tl } },
    punct .initial:n = { auto },
  }
% 处理用户在 \usepackage[...]{luatex_cn} 中传入的参数
\ProcessKeysOptions { guji }
3. 载入核心 Lua 逻辑不要把复杂的 Lua 代码直接写在 .sty 里，建立一个同名的 .lua 文件。Code snippet\lua_now:n { require("luatex_cn") }
4. 包装用户接口使用 expl3 定义命令，但在内部调用 Lua 进行“重活”。Code snippet% 生成唯一 ID 的接口
\cs_new_protected:Npn \GujiGenerateID #1
  {
    % 将参数传递给 Lua 端的 guji.generate_id 函数
    \lua_now:n { guji.generate_id("#1") }
  }
为什么这个架构对你最有利？极高的可维护性：如果你要在古籍中实现“自动标点”，在 expl3 里写正则表达式或字符串处理会让你抓狂；但在 Lua 里，这只是几行代码的事情。符合 CTAN 趋势：现在的顶级宏包（如 fontspec）都是这样做的。expl3 负责处理 $\LaTeX$ 的各种环境、参数和错误检查，Lua 负责算法。配合 l3build 完美自动化：l3build 可以同时管理你的 .sty、.dtx 和 .lua。当你运行 l3build install 时，它会把这些文件全部正确地部署到你的本地 TeX 目录。总结建议你应该使用 expl3。虽然学习曲线稍微陡峭一点（特别是那些冒号 : 和下划线 _），但它带来的命名空间隔离和参数处理能力是传统 $\LaTeX$ 命令无法比拟的。