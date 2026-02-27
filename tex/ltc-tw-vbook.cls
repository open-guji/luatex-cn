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
\ProvidesExplClass {ltc-tw-vbook} {2026/02/26} {0.3.1} {Chinese Vertical Book Class (Taiwan)}

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

% ============================================================================
% Running Header + Page Number via eso-pic (shipout hook)
% ============================================================================
% Displays running header and page number on each page.
% Both on inner margin (binding side): header at top, page number at bottom.
%
% Layout:
%   Odd pages (right page):  left side — chapter title (top) + page number (bottom)
%   Even pages (left page):  right side — book name (top) + page number (bottom)
%
% Users can override by redefining \cnVbookPageNumberHook.

\tl_new:N \l_cn_vbook_page_number_x_tl
\tl_new:N \l_cn_vbook_page_number_y_tl
\tl_new:N \l_cn_vbook_header_y_tl

\keys_define:nn { cn-vbook / page }
  {
    page-number-x .tl_set:N = \l_cn_vbook_page_number_x_tl,
    page-number-x .initial:n = {3mm},

    page-number-y .tl_set:N = \l_cn_vbook_page_number_y_tl,
    page-number-y .initial:n = {8mm},

    header-y .tl_set:N = \l_cn_vbook_header_y_tl,
    header-y .initial:n = {25mm},
  }

% Sync positions to plain TeX dimensions for shipout hook use
\newdimen\cnVbookPageNumX
\newdimen\cnVbookPageNumY
\newdimen\cnVbookPageNumFontSize
\newdimen\cnVbookHeaderY
\newdimen\cnVbookHeaderFontSize

\cnVbookPageNumX=\l_cn_vbook_page_number_x_tl\relax
\cnVbookPageNumY=\l_cn_vbook_page_number_y_tl\relax
\cnVbookPageNumFontSize=\l__luatexcn_page_number_font_size_tl\relax
\cnVbookHeaderY=\l_cn_vbook_header_y_tl\relax
\cnVbookHeaderFontSize=\l__luatexcn_page_header_font_size_tl\relax

% Re-sync when pageSetup is called
\cs_new_protected:Npn \__cn_vbook_sync_page_num_dims:
  {
    \dim_set:Nn \cnVbookPageNumX { \l_cn_vbook_page_number_x_tl }
    \dim_set:Nn \cnVbookPageNumY { \l_cn_vbook_page_number_y_tl }
    \dim_set:Nn \cnVbookPageNumFontSize { \l__luatexcn_page_number_font_size_tl }
    \dim_set:Nn \cnVbookHeaderY { \l_cn_vbook_header_y_tl }
    \dim_set:Nn \cnVbookHeaderFontSize { \l__luatexcn_page_header_font_size_tl }
  }

% Hook into pageSetup to sync dimensions
\hook_gput_code:nnn { begindocument } { cn-vbook }
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
% Uses Lua to determine odd/even page and conditionally output TeX commands
\newcommand{\cnVbookPageNumberHook}{%
  \directlua{
    local pg = tex.count[0]
    local style = _G.page and _G.page.number_style or "none"
    local header_on = _G.page and _G.page.header_enabled or false
    local skip = _G.vbook_skip_header_page or false
    local show_number = (style ~= "none" and style ~= "")
    local show_header = header_on and not skip

    _G.vbook_skip_header_page = false

    if not show_number and not show_header then return end

    local is_odd = (math.fmod(pg, 2) == 1)

    local header_text = ""
    if show_header then
      local book = _G.metadata and _G.metadata.book_name or ""
      local chapter = _G.metadata and _G.metadata.chapter_title or ""
      header_text = is_odd and chapter or book
      if header_text == "" then show_header = false end
    end

    local pw_cmd = "\\paperwidth-\\cnVbookPageNumX-2em"
    if is_odd then
      if show_header then
        tex.sprint("\\AtPageUpperLeft{\\put(\\LenToUnit{\\cnVbookPageNumX},-\\LenToUnit{\\cnVbookHeaderY}){\\parbox[t]{2em}{\\centering\\fontsize{\\cnVbookHeaderFontSize}{13pt}\\selectfont\\DrawVerticalText{" .. header_text .. "}}}}")
      end
      if show_number then
        tex.sprint("\\AtPageLowerLeft{\\put(\\LenToUnit{\\cnVbookPageNumX},\\LenToUnit{\\cnVbookPageNumY}){\\parbox[b]{2em}{\\centering\\fontsize{\\cnVbookPageNumFontSize}{13pt}\\selectfont\\DrawVerticalPageNumber}}}")
      end
    else
      if show_header then
        tex.sprint("\\AtPageUpperLeft{\\put(\\LenToUnit{" .. pw_cmd .. "},-\\LenToUnit{\\cnVbookHeaderY}){\\parbox[t]{2em}{\\centering\\fontsize{\\cnVbookHeaderFontSize}{13pt}\\selectfont\\DrawVerticalText{" .. header_text .. "}}}}")
      end
      if show_number then
        tex.sprint("\\AtPageLowerLeft{\\put(\\LenToUnit{" .. pw_cmd .. "},\\LenToUnit{\\cnVbookPageNumY}){\\parbox[b]{2em}{\\centering\\fontsize{\\cnVbookPageNumFontSize}{13pt}\\selectfont\\DrawVerticalPageNumber}}}")
      end
    end
  }%
}

% Register shipout hook
\AddToShipoutPictureFG{%
  \cnVbookPageNumberHook
}

\pagestyle{empty}
\endinput
