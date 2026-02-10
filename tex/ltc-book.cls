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

% ltc-book.cls - A document class for modern vertical Chinese typesetting.

\RequirePackage{expl3}
\RequirePackage{l3keys2e}
\ProvidesExplClass {ltc-book} {2026/02/09} {0.2.7} {Chinese Vertical Book Class}

% ============================================================================
% Variables
% ============================================================================

\tl_new:N \l_luatexcn_book_initial_template_tl
\prop_new:N \g_luatexcn_book_template_map_prop

% Template name mappings (Chinese -> Internal config name)
\prop_gset_from_keyval:Nn \g_luatexcn_book_template_map_prop
  {
    中华书局 = zhonghuashuju,
    中華書局 = zhonghuashuju,
  }

% ============================================================================
% Class Options
% ============================================================================

\keys_define:nn { luatexcn / book / options }
  {
    unknown .code:n =
      {
        \tl_set_eq:NN \l_tmpa_tl \l_keys_key_tl
        % Look up Chinese name mapping
        \prop_get:NVNT \g_luatexcn_book_template_map_prop \l_tmpa_tl \l_tmpb_tl
          { \tl_set_eq:NN \l_tmpa_tl \l_tmpb_tl }
        \file_if_exist:nTF { configs/luatex-cn-book- \l_tmpa_tl .cfg }
          { \tl_set_eq:NN \l_luatexcn_book_initial_template_tl \l_tmpa_tl }
          { \PassOptionsToClass { \l_tmpa_tl } { article } }
      }
  }

\ProcessKeysOptions { luatexcn / book / options }
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

% Load config: use template-specific config if specified, otherwise use default
\tl_if_empty:NTF \l_luatexcn_book_initial_template_tl
  {
    \InputIfFileExists{configs/luatex-cn-book-default.cfg}{}{
      \PackageWarning{luatex-cn-book}{Config~file~configs/luatex-cn-book-default.cfg~not~found}
    }
  }
  {
    \InputIfFileExists { configs/luatex-cn-book- \l_luatexcn_book_initial_template_tl .cfg } {} {}
  }

% Apply font at end of class loading
\AtEndOfClass{
  \tl_if_empty:NT \l__luatexcn_content_font_name_tl
    { \ApplyAutoFont }
}

% ============================================================================
% Page Number via eso-pic (shipout hook)
% ============================================================================
% Adds vertical page number to each page when page-number-style != none.
% Position: lower-left corner (3mm from left, 8mm from bottom).
% Users can override by redefining \ltcBookPageNumberHook.

\tl_new:N \l__luatexcn_book_page_number_x_tl
\tl_new:N \l__luatexcn_book_page_number_y_tl

\keys_define:nn { luatexcn / page }
  {
    page-number-x .tl_set:N = \l__luatexcn_book_page_number_x_tl,
    page-number-x .initial:n = {3mm},

    page-number-y .tl_set:N = \l__luatexcn_book_page_number_y_tl,
    page-number-y .initial:n = {8mm},
  }

% Sync page number position to plain TeX dimensions for shipout hook use
\newdimen\ltcPageNumX
\newdimen\ltcPageNumY
\newdimen\ltcPageNumFontSize

\ltcPageNumX=\l__luatexcn_book_page_number_x_tl\relax
\ltcPageNumY=\l__luatexcn_book_page_number_y_tl\relax
\ltcPageNumFontSize=\l__luatexcn_page_number_font_size_tl\relax

% Re-sync when pageSetup is called (hook into key setting)
\cs_new_protected:Npn \__luatexcn_book_sync_page_num_dims:
  {
    \dim_set:Nn \ltcPageNumX { \l__luatexcn_book_page_number_x_tl }
    \dim_set:Nn \ltcPageNumY { \l__luatexcn_book_page_number_y_tl }
    \dim_set:Nn \ltcPageNumFontSize { \l__luatexcn_page_number_font_size_tl }
  }

% Hook into pageSetup to sync dimensions
\hook_gput_code:nnn { begindocument } { luatexcn-book }
  { \__luatexcn_book_sync_page_num_dims: }

\ExplSyntaxOff

% Default page number hook (can be overridden by users)
% Uses Lua to check style and conditionally output TeX commands
\newcommand{\ltcBookPageNumberHook}{%
  \directlua{
    local style = _G.page and _G.page.number_style or "none"
    if style ~= "none" and style ~= "" then
      tex.sprint("\\AtPageLowerLeft{\\put(\\LenToUnit{\\ltcPageNumX},\\LenToUnit{\\ltcPageNumY}){\\parbox[b]{2em}{\\centering\\fontsize{\\ltcPageNumFontSize}{13pt}\\selectfont\\DrawVerticalPageNumber}}}")
    end
  }%
}

% Register shipout hook
\AddToShipoutPictureFG{%
  \ltcBookPageNumberHook
}

\pagestyle{empty}
\endinput
