# Antigravity AI Instructions for luatex-cn

## Project Overview
LuaTeX package for Chinese character and vertical typesetting support.

## Critical Development Requirement

### expl3 Programming Standard
**ALL package development MUST use expl3 (LaTeX3 programming layer)**

This is a **MANDATORY** requirement for all LaTeX code in this project.

#### Key Requirements:
1. **Always use expl3 syntax** for LaTeX macros and functions
2. Use `\ExplSyntaxOn` / `\ExplSyntaxOff` blocks
3. Use expl3 naming conventions: `\luatexcn_<module>_<action>:<signature>`
4. Use expl3 data types:
   - `\tl_` for token lists
   - `\seq_` for sequences
   - `\prop_` for property lists
   - `\bool_` for booleans
   - `\int_` for integers
   - `\fp_` for floating point numbers
5. Use expl3 functions instead of plain LaTeX2e commands where possible

#### Example Pattern:
```latex
\ExplSyntaxOn
\bool_new:N \g_luatexcn_vertical_bool
\cs_new_protected:Npn \luatexcn_vertical_text:n #1
  {
    \begin{tate} #1 \end{tate}
  }
\ExplSyntaxOff
```

## Code Style Guidelines

1. **LaTeX Code**: Always use expl3
   - Package options: Use `\keys_define:nn` and `\ProcessKeysOptions`
   - Variables: Use expl3 variable types
   - Functions: Use `\cs_new_protected:Npn` or `\cs_new:Npn`
   - Conditionals: Use `\bool_if:NT`, `\bool_if:NF`, etc.

2. **Lua Code**: Keep in separate .lua files
   - Use `luatexcn` namespace
   - Document functions clearly

3. **Package Structure**:
   - Main package: `luatex-cn.sty` (using expl3)
   - Lua modules: `luatex-cn-*.lua`
   - Documentation: `luatex-cn.dtx`

## Language
- 说中文 (Speak Chinese)
- 根据progress/下的md文件确定进度。完成一个任务要更新相应的文件。

## References
- expl3 documentation: https://ctan.org/pkg/l3kernel
- expl3 interface3.pdf: Comprehensive function reference
- LuaTeX documentation: https://www.luatex.org/
