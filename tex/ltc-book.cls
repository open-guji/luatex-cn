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

% ltc-book.cls
% Chinese Vertical Book - A document class for modern vertical Chinese typesetting
% Developed for LuaTeX

\RequirePackage{expl3}
\RequirePackage{l3keys2e}
\ProvidesExplClass {ltc-book} {2026/01/21} {v0.1.2} {Chinese Vertical Book Class}

\tl_new:N \l_ltc_book_initial_template_tl

\keys_define:nn { ltc-book }
  {
    unknown .code:n =
      {
        \tl_set_eq:NN \l_tmpa_tl \l_keys_key_tl
        % Look for config file: configs/<name>.ltc_book.cfg
        \file_if_exist:nTF { configs/ \l_tmpa_tl .ltc_book.cfg }
          {
            \tl_set_eq:NN \l_ltc_book_initial_template_tl \l_tmpa_tl
          }
          {
            \PassOptionsToClass { \l_tmpa_tl } { article }
          }
      }
  }

\ProcessKeysOptions { ltc-book }

\LoadClass{article}

% 2. Core Dependencies
\RequirePackage{geometry}
\RequirePackage{xcolor}
% fontspec is optional - users can load it in their document if needed
% But we load it here to enable font auto-detection
\RequirePackage{fontspec}
\RequirePackage{environ}
\RequirePackage{expl3}
\RequirePackage{xparse}
\RequirePackage{luatex-cn}
\RequirePackage{vertical/luatex-cn-vertical}

% Load font auto-detection module
\RequirePackage{fonts/luatex-cn-font-autodetect}

% 3. Key-Value Configuration System
\ExplSyntaxOn

\keys_define:nn { ltc_book }
  {
    % Page geometry - modern book defaults (A5-ish)
    paper-width .tl_set:N = \l_ltc_book_paper_width_tl,
    paper-width .initial:n = 148mm,

    paper-height .tl_set:N = \l_ltc_book_paper_height_tl,
    paper-height .initial:n = 210mm,

    margin-top .tl_set:N = \l_ltc_book_margin_top_tl,
    margin-top .initial:n = 15mm,

    margin-bottom .tl_set:N = \l_ltc_book_margin_bottom_tl,
    margin-bottom .initial:n = 30mm,

    margin-left .tl_set:N = \l_ltc_book_margin_left_tl,
    margin-left .initial:n = 15mm,

    margin-right .tl_set:N = \l_ltc_book_margin_right_tl,
    margin-right .initial:n = 25mm,

    % Grid and font settings
    font-size .tl_set:N = \l_ltc_book_font_size_tl,
    font-size .initial:n = 12pt,
    
    line-spacing .tl_set:N = \l_ltc_book_line_spacing_tl,
    line-spacing .initial:n = 14pt,

    grid-width .tl_set:N = \l_ltc_book_grid_width_tl,
    grid-width .initial:n = 14pt,

    grid-height .tl_set:N = \l_ltc_book_grid_height_tl,
    grid-height .initial:n = 14pt,

    chapter-title-grid-height .tl_set:N = \l_ltc_book_chapter_title_grid_height_tl,
    chapter-title-grid-height .initial:n = {},

    book-name-align .tl_set:N = \l_ltc_book_book_name_align_tl,
    book-name-align .initial:n = {center},

    upper-yuwei .bool_set:N = \l_ltc_book_upper_yuwei_bool,
    upper-yuwei .initial:n = true,

    banxin-divider .bool_set:N = \l_ltc_book_banxin_divider_bool,
    banxin-divider .initial:n = true,

    page-number-align .tl_set:N = \l_ltc_book_page_number_align_tl,
    page-number-align .initial:n = {right-bottom},

    font-name .tl_set:N = \l_ltc_book_font_name_tl,
    font-name .initial:n = {},

    font-features .tl_set:N = \l_ltc_book_font_features_tl,
    font-features .initial:n = {},

    height .tl_set:N = \l_ltc_book_height_tl,
    height .initial:n = ,

    % No border by default for modern books
    border .bool_set:N = \l_ltc_book_border_bool,
    border .initial:n = false,

    border-thickness .tl_set:N = \l_ltc_book_border_thickness_tl,
    border-thickness .initial:n = 0.4pt,

    vertical-align .tl_set:N = \l_ltc_book_valign_tl,
    vertical-align .initial:n = center,

    n-column .int_set:N = \l_ltc_book_n_column_int,
    n-column .initial:n = 0,

    debug .bool_gset:N = \g_cnv_debug_bool,
    debug .initial:n = false,

    template .code:n = {
      \InputIfFileExists{configs/#1.ltc_book.cfg}{}{
        \keys_set:nn { ltc_book / templates } { #1 }
      }
    },
  }

% 4. Geometry setup
\cs_new:Npn \__ltc_book_apply_geometry:
  {
    \geometry{
      paperwidth=\l_ltc_book_paper_width_tl,
      paperheight=\l_ltc_book_paper_height_tl,
      top=\l_ltc_book_margin_top_tl,
      bottom=\l_ltc_book_margin_bottom_tl,
      left=\l_ltc_book_margin_left_tl,
      right=\l_ltc_book_margin_right_tl
    }
  }

% Apply defaults
\geometry{
  paperwidth=148mm,
  paperheight=210mm,
  top=20mm,
  bottom=20mm,
  left=15mm,
  right=15mm
}

\NewDocumentCommand{\ltc_bookSetup}{ +m }
  {
    \keys_set:nn { ltc_book } { #1 }
    \__ltc_book_apply_geometry:
  }

% 5. Main content environment
\NewEnviron{ltc-book-content}[1][]{%
    \clearpage
    \group_begin:
    \keys_set:nn { ltc_book } { #1 }

    % Font selection logic
    \tl_if_empty:NF \l_ltc_book_font_name_tl
      {
        \tl_if_empty:NTF \l_ltc_book_font_features_tl
          {
            % No features specified, use default for CJK vertical
            \exp_args:NV \setmainfont \l_ltc_book_font_name_tl [RawFeature={+vert,+vrt2}, CharacterWidth=Full]
          }
          {
            \exp_args:NV \setmainfont \l_ltc_book_font_name_tl [\l_ltc_book_font_features_tl]
          }
      }

    \fontsize{\l_ltc_book_font_size_tl}{\l_ltc_book_line_spacing_tl}\selectfont
    
    % Configure vertical module
    \bool_if:NTF \l_ltc_book_border_bool 
      { \keys_set:nn { vertical } { border=true } } 
      { \keys_set:nn { vertical } { border=false } }
    
    \dim_zero:N \topskip
    \dim_zero:N \parskip
    \dim_zero:N \parindent

    \tl_if_empty:NT \l_ltc_book_height_tl
      {
        \tl_set:Nx \l_ltc_book_height_tl { \dim_eval:n { \l_ltc_book_paper_height_tl - \l_ltc_book_margin_top_tl - \l_ltc_book_margin_bottom_tl } }
      }

    \keys_set:nx { vertical }
      {
        height = \l_ltc_book_height_tl,
        grid-width = \l_ltc_book_grid_width_tl,
        grid-height = \l_ltc_book_grid_height_tl,
        vertical-align = \l_ltc_book_valign_tl,
        border-thickness = \l_ltc_book_border_thickness_tl,
        n-column = \int_use:N \l_ltc_book_n_column_int,
        paper-width = \l_ltc_book_paper_width_tl,
        paper-height = \l_ltc_book_paper_height_tl,
        margin-top = \l_ltc_book_margin_top_tl,
        margin-bottom = \l_ltc_book_margin_bottom_tl,
        margin-left = \l_ltc_book_margin_left_tl,
        margin-right = \l_ltc_book_margin_right_tl,
        chapter-title-grid-height = \l_ltc_book_chapter_title_grid_height_tl,
        book-name-align = \l_ltc_book_book_name_align_tl,
        upper-yuwei = \bool_if:NTF \l_ltc_book_upper_yuwei_bool {true} {false},
        banxin-divider = \bool_if:NTF \l_ltc_book_banxin_divider_bool {true} {false},
        page-number-align = \l_ltc_book_page_number_align_tl,
        debug = \bool_if:NTF \g_cnv_debug_bool {true} {false}
      }
    \nointerlineskip
    \__cn_vertical_process_grid:n { \BODY }
    \group_end:
    \clearpage
}

% 6. Apply initial template if specified
\tl_if_empty:NF \l_ltc_book_initial_template_tl
  {
    \keys_set:nx { ltc_book } { template = \l_ltc_book_initial_template_tl }
  }


\pagestyle{plain}

% Environment Aliases (CJK support)
\NewEnvironmentCopy{正文}{ltc-book-content}

% Apply auto-detected font if no font-name is set
\AtEndOfClass{
  \tl_if_empty:NT \l_ltc_book_font_name_tl
    {
      \ApplyAutoFont
    }
}
\ExplSyntaxOff

\endinput
