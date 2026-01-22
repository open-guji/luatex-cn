计划已完成。总结一下关键设计决策：

Mode 1（段末注）采用纯 TeX 流式方案：

\脚注{内容} 存储到 expl3 序列 + 写入行内标记 〔一〕
\输出脚注 将所有脚注内容直接写回文档流，自然参与网格排版
不需要复杂的 Lua 插件处理，Lua 层只提供插件骨架（Mode 2 预留）
新增 3 个文件，修改 4 个现有文件，改动量最小化。

Claude's Plan
脚注/校勘记系统 — 实现计划
Context
需求：用户需要为竖排古籍文本添加脚注/校勘记功能，类似中华书局版《史記》中的 〔一二〕、〔一三〕 标注。

两种模式：

Mode 1（段末注）：脚注在一段文字结束后输出，编号在段末重置。优先实现。
Mode 2（页下注）：脚注在页面最左侧，竖线隔开，编号每页重置。后续实现。
两种编号风格：

lujiao（六角括号）：〔一〕、〔二〕、〔三〕…（中华书局风格）
circled（圈码）：①、②、③…（现代学术风格）
架构设计
Mode 1 核心思路：纯 TeX 流式输出
Mode 1 不需要复杂的 Lua 插件处理。脚注内容存储在 expl3 序列中，\输出脚注 时直接将内容写回 TeX 文档流，自然参与网格排版。


\脚注{内容}  → 存储内容 + 写入行内标记 〔一〕
\输出脚注     → 输出所有脚注：〔一〕内容一 〔二〕内容二 ...
              → 重置计数器
预留 Mode 2 插件架构
创建 Lua 插件骨架（initialize/flatten/layout/render），Mode 1 时为空操作，Mode 2 将使用完整的 WHATSIT + 布局 + 渲染流水线。

新增/修改文件
新增文件
文件	职责
tex/guji/luatex-cn-guji-footnote.sty	TeX 接口：expl3 key-value、\脚注/\输出脚注 命令
tex/guji/luatex-cn-guji-footnote.lua	Lua 插件骨架 + 编号格式化辅助函数
test/regression_test/tex/footnote.tex	回归测试文件
修改文件
文件	改动
tex/guji/luatex-cn-guji.sty:44	添加 \RequirePackage{guji/luatex-cn-guji-footnote}
tex/core/luatex-cn-core-main.lua:131	注册 footnote 插件（在 sidenote 之后）
tex/core/luatex-cn-constants.lua:91	添加 FOOTNOTE_USER_ID = 202607
tex/util/luatex-cn-utils.lua:304	添加 to_circled_numeral() 函数
详细设计
1. luatex-cn-guji-footnote.sty — TeX 接口

% Key-value 配置
\keys_define:nn { luatexcn / footnote }
{
  mode          .tl_set:N,  .initial:n = {endnote},    % endnote | footnote
  number-style  .tl_set:N,  .initial:n = {lujiao},     % lujiao | circled
  note-font-size .tl_set:N, .initial:n = {},            % 空=与正文同
  separator     .tl_set:N,  .initial:n = {blank},       % blank | rule | none
}

% 全局存储
\seq_new:N  \g__luatexcn_footnote_content_seq   % 脚注内容序列
\int_new:N  \g__luatexcn_footnote_counter_int   % 当前编号

% \脚注{内容} — 插入标记 + 存储内容
\NewDocumentCommand{\Footnote}{ O{} +m }{
  \group_begin:
    \int_gincr:N \g__luatexcn_footnote_counter_int
    \seq_gput_right:Nn \g__luatexcn_footnote_content_seq { #2 }
    % 写入行内标记（如 〔一〕）
    \__luatexcn_footnote_write_marker:n
      { \int_use:N \g__luatexcn_footnote_counter_int }
  \group_end:
}

% \输出脚注 — 输出所有脚注并重置
\NewDocumentCommand{\FlushFootnote}{}{
  \int_compare:nNnT
    { \seq_count:N \g__luatexcn_footnote_content_seq } > { 0 }
    {
      % 分隔符（空行或横线）
      \__luatexcn_footnote_separator:
      % 逐条输出
      \int_step_inline:nn
        { \seq_count:N \g__luatexcn_footnote_content_seq }
        {
          \__luatexcn_footnote_write_marker:n { ##1 }
          \seq_item:Nn \g__luatexcn_footnote_content_seq { ##1 }
        }
      % 重置
      \seq_gclear:N \g__luatexcn_footnote_content_seq
      \int_gzero:N  \g__luatexcn_footnote_counter_int
    }
}

% CJK 别名
\NewCommandCopy{\脚注}{\Footnote}
\NewCommandCopy{\输出脚注}{\FlushFootnote}
\NewCommandCopy{\脚注设置}{\footnoteSetup}
标记格式化内部函数

% 根据 number-style 写入标记
\cs_new:Nn \__luatexcn_footnote_write_marker:n
{
  \str_case:VnF \l__luatexcn_footnote_number_style_tl
  {
    {lujiao}  { 〔\lua_now:e{ vertical_utils.to_chinese_numeral(#1) }〕 }
    {circled}  { \lua_now:e{ vertical_utils.to_circled_numeral(#1) } }
  }
  { 〔\lua_now:e{ vertical_utils.to_chinese_numeral(#1) }〕 }  % 默认
}

% 分隔符
\cs_new:Nn \__luatexcn_footnote_separator:
{
  \str_case:VnF \l__luatexcn_footnote_separator_tl
  {
    {blank} { \hspace{1\l__luatexcn_footnote_grid_height_dim} }  % 空一格
    {none}  { }
  }
  { \hspace{1\l__luatexcn_footnote_grid_height_dim} }
}
2. luatex-cn-guji-footnote.lua — Lua 插件

local footnote = {}

function footnote.initialize(params, engine_ctx)
    local mode = _G.footnote and _G.footnote.mode or "endnote"
    return { mode = mode }
end

function footnote.flatten(head, params, ctx)
    if not ctx then return head end
    -- Mode 1: no-op (TeX handles everything)
    -- Mode 2: will detect WHATSIT anchors
    return head
end

function footnote.layout(list, layout_map, engine_ctx, ctx)
    if not ctx then return end
    -- Mode 1: no-op
    -- Mode 2: will calculate per-page footnote positions
end

function footnote.render(head, layout_map, render_ctx, ctx, engine_ctx, page_idx, p_total_cols)
    if not ctx then return head end
    -- Mode 1: no-op
    -- Mode 2: will render separator line + footnote content
    return head
end

return footnote
3. to_circled_numeral() — 添加到 utils.lua

-- Unicode circled numbers: ① U+2460 through ⑳ U+2473, then ㉑ U+3251 through ㊿ U+32BF
local function to_circled_numeral(n)
    if not n or n <= 0 then return "" end
    if n <= 20 then
        return utf8.char(0x2460 + n - 1)  -- ① = U+2460
    elseif n <= 50 then
        return utf8.char(0x3251 + n - 21)  -- ㉑ = U+3251
    else
        return "(" .. tostring(n) .. ")"  -- fallback
    end
end
4. 集成点
luatex-cn-guji.sty — 第 44 行附近添加：


% 脚注/校勘记 (Footnote) - Footnotes and critical apparatus
\RequirePackage{guji/luatex-cn-guji-footnote}
core-main.lua — 第 131 行附近添加：


local footnote = package.loaded['guji.luatex-cn-guji-footnote'] or
    require('guji.luatex-cn-guji-footnote')
-- 注册顺序：punct → judou → sidenote → textbox → footnote
register_plugin("footnote", footnote)
constants.lua — 第 91 行添加：


constants.FOOTNOTE_USER_ID = 202607
5. 配置同步到 _G
在 footnote.sty 中，\footnoteSetup 设置 key-value 后同步到 _G.footnote：


\NewDocumentCommand{\footnoteSetup}{ m }
{
  \keys_set:nn { luatexcn / footnote } { #1 }
  \lua_now:e {
    _G.footnote = _G.footnote or {}
    _G.footnote.mode = "\l__luatexcn_footnote_mode_tl"
    _G.footnote.number_style = "\l__luatexcn_footnote_number_style_tl"
  }
}
测试文件

% test/regression_test/tex/footnote.tex
\documentclass{ltc-book}
\setmainfont{TW-Kai}

\begin{document}
\begin{正文}

天地玄黃\脚注{「玄」，本作「元」，避清聖祖諱改。}，宇宙洪荒\脚注{「洪荒」，謂天地初開之際。}。
日月盈昃，辰宿列張。

\输出脚注

寒來暑往，秋收冬藏。閏餘成歲\脚注{「閏餘」，指閏月。}，律呂調陽。

\输出脚注

\end{正文}
\end{document}
实现阶段
Stage 1（本次实现）：Mode 1 段末注基础功能
创建 footnote.sty — 完整 TeX 接口
创建 footnote.lua — 插件骨架（Mode 1 下 flatten/layout/render 为空操作）
在 utils.lua 添加 to_circled_numeral()
在 constants.lua 添加 FOOTNOTE_USER_ID
在 guji.sty 和 core-main.lua 注册
创建测试文件，编译验证
运行全量回归测试确保不影响现有功能
Stage 2（后续）：Mode 2 页下注
Lua 插件完整实现：WHATSIT 锚点 + per-page 收集 + 分隔线渲染
需要在 layout 阶段计算每页脚注空间
需要在 render 阶段绘制竖线分隔符
Stage 3（后续）：完善
脚注内容字号配置
跨页脚注处理
与夹注/批注的交互
脚注嵌套
关键复用
已有功能	位置	用途
to_chinese_numeral()	tex/util/luatex-cn-utils.lua:273	〔一〕编号
插件注册模式	tex/core/luatex-cn-core-main.lua:109-132	register_plugin
sidenote registry	tex/core/luatex-cn-core-sidenote.lua:461	Mode 2 参考
WHATSIT user_defined	tex/core/luatex-cn-constants.lua:86-91	Mode 2 锚点
_G 配置同步	各 .sty 文件	key-value → Lua 全局表
验证步骤

# 1. 编译测试文件
cd test/regression_test/tex && lualatex footnote.tex

# 2. 检查 PDF 输出：确认脚注标记和内容正确显示

# 3. 运行全量回归测试（确保不影响现有测试）
python3 test/regression_test.py check

# 4. 保存新基线
python3 test/regression_test.py save test/regression_test/tex/footnote.tex