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

% cn-vbook.cls - A document class for modern vertical Chinese typesetting.
% Default: Modern vertical layout.

\RequirePackage{expl3}
\RequirePackage{l3keys2e}
\RequirePackage{core/luatex-cn-core-template}
\ProvidesExplClass {cn-vbook} {2026/02/18} {0.2.9} {Chinese Vertical Book Class}

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

% Load default config
\InputIfFileExists{configs/luatex-cn-vbook-default.cfg}{}{
  \PackageWarning{cn-vbook}{Config~file~configs/luatex-cn-vbook-default.cfg~not~found}
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
% Page Number via eso-pic (shipout hook)
% ============================================================================
% Adds vertical page number to each page when page-number-style != none.
% Position: lower-left corner (3mm from left, 8mm from bottom).
% Users can override by redefining \cnVbookPageNumberHook.

\tl_new:N \l_cn_vbook_page_number_x_tl
\tl_new:N \l_cn_vbook_page_number_y_tl

\keys_define:nn { cn-vbook / page }
  {
    page-number-x .tl_set:N = \l_cn_vbook_page_number_x_tl,
    page-number-x .initial:n = {3mm},

    page-number-y .tl_set:N = \l_cn_vbook_page_number_y_tl,
    page-number-y .initial:n = {8mm},
  }

% Sync page number position to plain TeX dimensions for shipout hook use
\newdimen\cnVbookPageNumX
\newdimen\cnVbookPageNumY
\newdimen\cnVbookPageNumFontSize

\cnVbookPageNumX=\l_cn_vbook_page_number_x_tl\relax
\cnVbookPageNumY=\l_cn_vbook_page_number_y_tl\relax
\cnVbookPageNumFontSize=\l__luatexcn_page_number_font_size_tl\relax

% Re-sync when pageSetup is called (hook into key setting)
\cs_new_protected:Npn \__cn_vbook_sync_page_num_dims:
  {
    \dim_set:Nn \cnVbookPageNumX { \l_cn_vbook_page_number_x_tl }
    \dim_set:Nn \cnVbookPageNumY { \l_cn_vbook_page_number_y_tl }
    \dim_set:Nn \cnVbookPageNumFontSize { \l__luatexcn_page_number_font_size_tl }
  }

% Hook into pageSetup to sync dimensions
\hook_gput_code:nnn { begindocument } { cn-vbook }
  { \__cn_vbook_sync_page_num_dims: }

\ExplSyntaxOff

% Default page number hook (can be overridden by users)
% Uses Lua to check style and conditionally output TeX commands
\newcommand{\cnVbookPageNumberHook}{%
  \directlua{
    local style = _G.page and _G.page.number_style or "none"
    if style ~= "none" and style ~= "" then
      tex.sprint("\\AtPageLowerLeft{\\put(\\LenToUnit{\\cnVbookPageNumX},\\LenToUnit{\\cnVbookPageNumY}){\\parbox[b]{2em}{\\centering\\fontsize{\\cnVbookPageNumFontSize}{13pt}\\selectfont\\DrawVerticalPageNumber}}}")
    end
  }%
}

% Register shipout hook
\AddToShipoutPictureFG{%
  \cnVbookPageNumberHook
}

\pagestyle{empty}
\endinput
