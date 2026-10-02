% Copyright 2026 Open-Guji (https://github.com/open-guji)
%
% Licensed under the Apache License, Version 2.0 (the "License");
% you may not use this file except in compliance with the License.
% You may obtain a copy of the License at
%
%     http://www.apache.org/licenses/LICENSE-2.0
%
% Unless required by applicable law or agreed to in writing, software
% distributed under the License is distributed on an "AS IS" BASIS,
% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
% See the License for the specific language governing permissions and
% limitations under the License.

% ltc-tw-vbook.cls - A document class for modern vertical Chinese typesetting.
% Same as ltc-cn-vbook but with Taiwan-style punctuation by default.

\RequirePackage{expl3}
\RequirePackage{l3keys2e}
\RequirePackage{core/luatex-cn-core-template}
\ProvidesExplClass {ltc-tw-vbook} {2026/10/28} {0.4.3} {Chinese Vertical Book Class (Taiwan)}

% ============================================================================
% Variables
% ============================================================================

\tl_new:N \l_cn_vbook_initial_template_tl
\prop_new:N \g_cn_vbook_template_map_prop

% Template name mappings (Chinese -> Internal config name)
\prop_gset_from_keyval:Nn \g_cn_vbook_template_map_prop
  {
    % Reserved for future mappings, currently just matches filename suffix
  }

% ============================================================================
% Class Options
% ============================================================================

\keys_define:nn { cn-vbook / options }
  {
    unknown .code:n =
      {
        \tl_set_eq:NN \l_tmpa_tl \l_keys_key_tl
        % Look up Chinese name mapping
        \prop_get:NVNT \g_cn_vbook_template_map_prop \l_tmpa_tl \l_tmpb_tl
          { \tl_set_eq:NN \l_tmpa_tl \l_tmpb_tl }
        % First try template files, if not found pass to article
        \luatexcn_if_template_exist:VnTF \l_tmpa_tl { luatex-cn-vbook- }
          { \tl_set_eq:NN \l_cn_vbook_initial_template_tl \l_tmpa_tl }
          { \PassOptionsToClass { \l_tmpa_tl } { article } }
      }
  }

\ProcessKeysOptions { cn-vbook / options }
\LoadClass{article}

% ============================================================================
% Dependencies
% ============================================================================

\RequirePackage{geometry}
\RequirePackage{xcolor}
\RequirePackage{fontspec}
\RequirePackage{environ}
\RequirePackage{xparse}
\RequirePackage{eso-pic}
\RequirePackage{luatex-cn-core}
\RequirePackage{core/luatex-cn-footnote}

% ============================================================================
% Initialization
% ============================================================================

% Load default config (for Taiwan variant)
\InputIfFileExists{configs/luatex-cn-tw-vbook-default.cfg}{}{
  \PackageWarning{ltc-tw-vbook}{Config~file~configs/luatex-cn-tw-vbook-default.cfg~not~found}
}

% Apply initial template from class options
\tl_if_empty:NF \l_cn_vbook_initial_template_tl
  {
    \luatexcn_load_template:Vn \l_cn_vbook_initial_template_tl { luatex-cn-vbook- }
  }

% Apply font at end of class loading
\AtEndOfClass{
  \tl_if_empty:NT \l__luatexcn_content_font_name_tl
    { \ApplyAutoFont }
}

% Set natural layout mode as default for modern vertical books
\ExplSyntaxOff
\AtBeginDocument{
  \directlua{
    _G.content = _G.content or {}
    if not _G.content.layout_mode then
      _G.content.layout_mode = "natural"
      _G.content.inter_cell_gap = 2 * 65536
    end
  }
}
\ExplSyntaxOn

% ============================================================================
% Running Header + Page Number via eso-pic (shipout hook)
% ============================================================================
% Displays running header and page number on each page.
% Both on inner margin (binding side): header at top, page number at bottom.
%
% Layout (twoside=true; with twoside=false every page uses the odd-page layout):
%   Odd pages (right page):  left side — chapter title (top) + page number (bottom)
%   Even pages (left page):  right side — book name (top) + page number (bottom)
%
% Users can override by redefining \cnVbookPageNumberHook.

% Position registers read by the shipout hook. The keys below live in the
% luatexcn/page module so that \pageSetup{page-number-x=...} reaches them
% (a separate cn-vbook/page module was never passed to \keys_set and the
% unknown handler of \pageSetup swallowed these keys silently).
\newdimen\cnVbookPageNumX
\newdimen\cnVbookPageNumY
\newdimen\cnVbookPageNumFontSize
\newdimen\cnVbookHeaderY
\newdimen\cnVbookHeaderFontSize
\cnVbookPageNumX=3mm\relax
\cnVbookPageNumY=52mm\relax
\cnVbookHeaderY=52mm\relax

% page-number-position (#193):
%   inner  - binding side (default; left on odd pages, right on even pages)
%   outer  - fore-edge side (mirror of inner)
%   center - horizontally centred at the foot of the page, as in many
%            traditional books where the folio sits mid-page
% The running header stays on the inner side regardless.
\tl_new:N \l_cn_vbook_page_number_position_tl
\tl_set:Nn \l_cn_vbook_page_number_position_tl { inner }

\keys_define:nn { luatexcn / page }
  {
    page-number-x .code:n = { \dim_set:Nn \cnVbookPageNumX { #1 } },
    page-number-y .code:n = { \dim_set:Nn \cnVbookPageNumY { #1 } },
    header-y      .code:n = { \dim_set:Nn \cnVbookHeaderY { #1 } },

    page-number-position .choices:nn = { inner, outer, center }
      { \tl_set_eq:NN \l_cn_vbook_page_number_position_tl \l_keys_choice_tl },
    page-number-position / centre .code:n =
      { \tl_set:Nn \l_cn_vbook_page_number_position_tl { center } },
    page-number-position / 内侧 .code:n =
      { \tl_set:Nn \l_cn_vbook_page_number_position_tl { inner } },
    page-number-position / 內側 .code:n =
      { \tl_set:Nn \l_cn_vbook_page_number_position_tl { inner } },
    page-number-position / 外侧 .code:n =
      { \tl_set:Nn \l_cn_vbook_page_number_position_tl { outer } },
    page-number-position / 外側 .code:n =
      { \tl_set:Nn \l_cn_vbook_page_number_position_tl { outer } },
    page-number-position / 居中 .code:n =
      { \tl_set:Nn \l_cn_vbook_page_number_position_tl { center } },

    % 中文键名
    页码横移 .meta:n = { page-number-x = #1 },
    页码纵移 .meta:n = { page-number-y = #1 },
    页眉纵移 .meta:n = { header-y = #1 },
    页码位置 .meta:n = { page-number-position = #1 },
    頁碼橫移 .meta:n = { page-number-x = #1 },
    頁碼縱移 .meta:n = { page-number-y = #1 },
    頁眉縱移 .meta:n = { header-y = #1 },
    頁碼位置 .meta:n = { page-number-position = #1 },
  }

% Font sizes come from the core page keys; sync them at begindocument and
% after every \pageSetup.
\cs_new_protected:Npn \__cn_vbook_sync_page_num_dims:
  {
    \dim_set:Nn \cnVbookPageNumFontSize { \l__luatexcn_page_number_font_size_tl }
    \dim_set:Nn \cnVbookHeaderFontSize { \l__luatexcn_page_header_font_size_tl }
    \lua_now:e { _G.vbook_page_number_position = "\l_cn_vbook_page_number_position_tl" }
  }
\__cn_vbook_sync_page_num_dims:

\hook_gput_code:nnn { begindocument } { cn-vbook }
  { \__cn_vbook_sync_page_num_dims: }
\hook_gput_code:nnn { cmd / pageSetup / after } { cn-vbook }
  { \__cn_vbook_sync_page_num_dims: }

% \skipHeader — mark current page to suppress header display (e.g. title page)
\NewDocumentCommand{\skipHeader}{}
  {
    \lua_now:n { _G.vbook_skip_header_page = true }
  }

% 中文别名
\NewCommandCopy{\跳过页眉}{\skipHeader}

\ExplSyntaxOff

% Default shipout hook: running header + page number
% (a 补页样式=空白 blank page, issue #176, gets neither)
% Uses Lua to determine odd/even page and conditionally output TeX commands
\newcommand{\cnVbookPageNumberHook}{%
  \directlua{
    if require('core.luatex-cn-core-page').is_plain_blank_page(tex.box[\the\ShipoutBox]) then
      _G.vbook_skip_header_page = false
      return
    end
    local pg = tex.count[0]
    local style = _G.page and _G.page.number_style or "none"
    local header_on = _G.page and _G.page.header_enabled or false
    local skip = _G.vbook_skip_header_page or false
    local show_number = (style ~= "none" and style ~= "")
    local show_header = header_on and not skip

    _G.vbook_skip_header_page = false

    if not show_number and not show_header then return end

    local twoside = _G.page and _G.page.twoside or false
    local is_odd = (not twoside) or (math.fmod(pg, 2) == 1)

    local header_text = ""
    if show_header then
      local book = _G.metadata and _G.metadata.book_name or ""
      local chapter = _G.metadata and _G.metadata.chapter_title or ""
      header_text = is_odd and chapter or book
      if header_text == "" then show_header = false end
    end

    local pw_cmd = "\\paperwidth-\\cnVbookPageNumX-2em"
    local header_x = is_odd and "\\cnVbookPageNumX" or pw_cmd
    local pos = _G.vbook_page_number_position or "inner"
    local number_x
    if pos == "center" then
      number_x = "0.5\\paperwidth-1em"
    elseif pos == "outer" then
      number_x = is_odd and pw_cmd or "\\cnVbookPageNumX"
    else
      number_x = header_x
    end
    if show_header then
      tex.sprint("\\AtPageUpperLeft{\\put(\\LenToUnit{" .. header_x .. "},-\\LenToUnit{\\cnVbookHeaderY}){\\parbox[t]{2em}{\\centering\\fontsize{\\cnVbookHeaderFontSize}{13pt}\\selectfont\\DrawVerticalText{" .. header_text .. "}}}}")
    end
    if show_number then
      tex.sprint("\\AtPageLowerLeft{\\put(\\LenToUnit{" .. number_x .. "},\\LenToUnit{\\cnVbookPageNumY}){\\parbox[b]{2em}{\\centering\\fontsize{\\cnVbookPageNumFontSize}{13pt}\\selectfont\\DrawVerticalPageNumber}}}")
    end
  }%
}

% Register shipout hook
\AddToShipoutPictureFG{%
  \cnVbookPageNumberHook
}

\pagestyle{empty}
\endinput
