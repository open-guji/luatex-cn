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

% ltc-guji.cls
% A LaTeX document class for ancient Chinese book typesetting.
% Developed for LuaTeX

\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{ltc-guji}[2026/01/10 v0.3.0 Ancient Chinese Book Class (Template Support)]

% 1. Options Handling
\RequirePackage{l3keys2e}
\ExplSyntaxOn
\tl_new:N \l_guji_initial_template_tl
\prop_new:N \g_guji_template_map_prop

% Define Template Mappings (Chinese -> English/Internal name)
\prop_gset_from_keyval:Nn \g_guji_template_map_prop
  {
    四库全书 = SiKuQuanShu,
    四庫全書 = SiKuQuanShu
  }

\DeclareOption*{
  \tl_set:Nx \l_tmpa_tl { \CurrentOption }
  
  % Try to map the option name
  \prop_get:NVNT \g_guji_template_map_prop \l_tmpa_tl \l_tmpb_tl
    { \tl_set_eq:NN \l_tmpa_tl \l_tmpb_tl }
  
  % Look for config file: configs/luatex-cn-guji-<name>.cfg
  \file_if_exist:nTF { configs/luatex-cn-guji- \l_tmpa_tl .cfg }
    {
      \tl_set_eq:NN \l_guji_initial_template_tl \l_tmpa_tl
    }
    {
      \PassOptionsToClass{\l_tmpa_tl}{article}
    }
}
\ExplSyntaxOff
\ProcessOptions\relax
\LoadClass{article}

% 2. Core Dependencies
\RequirePackage{geometry}
\RequirePackage{xcolor}
\RequirePackage{fontspec}
\RequirePackage{environ}
\RequirePackage{expl3}
\RequirePackage{xparse}
\RequirePackage{tikz}
\RequirePackage{luatex-cn}

% Load banxin for 版心/鱼尾 features (registers hooks with vertical)
 \cnvLua{
    local status, err = pcall(function()
        require('banxin.luatex-cn-banxin-main')
    end)
    if not status then
        tex.error("Failed to load banxin: " .. tostring(err))
    end
 }

% 3. Page Geometry - Will be applied dynamically via template
% Default values stored in key-value system below

% 4. Key-Value Configuration System (expl3)
\ExplSyntaxOn

% Storage for Book Name (formerly Banxin text)
\tl_new:N \l_guji_book_name_tl
\tl_set:Nn \l_guji_book_name_tl {}

% Storage for Chapter Title (章节标题)
\tl_new:N \l_guji_chapter_title_tl
\tl_set:Nn \l_guji_chapter_title_tl {}

\bool_new:N \l_guji_banxin_bool
\bool_set_true:N \l_guji_banxin_bool

\keys_define:nn { guji }
  {
    % Page geometry settings (set by config files)
    paper-width .tl_set:N = \l_guji_paper_width_tl,
    paper-width .initial:n = {},

    paper-height .tl_set:N = \l_guji_paper_height_tl,
    paper-height .initial:n = {},

    margin-top .tl_set:N = \l_guji_margin_top_tl,
    margin-top .initial:n = {},

    margin-bottom .tl_set:N = \l_guji_margin_bottom_tl,
    margin-bottom .initial:n = {},

    margin-left .tl_set:N = \l_guji_margin_left_tl,
    margin-left .initial:n = {},

    margin-right .tl_set:N = \l_guji_margin_right_tl,
    margin-right .initial:n = {},

    % Grid and font settings
    font-size .tl_set:N = \l_guji_font_size_tl,
    font-size .initial:n = {},
    
    line-spacing .tl_set:N = \l_guji_line_spacing_tl,
    line-spacing .initial:n = {},

    grid-width .tl_set:N = \l_guji_grid_width_tl,
    grid-width .initial:n = {},

    grid-height .tl_set:N = \l_guji_grid_height_tl,
    grid-height .initial:n = {},

    height .tl_set:N = \l_guji_height_tl,
    height .initial:n = {},

    jiazhu-font-size .tl_set:N = \l_guji_jiazhu_font_size_tl,
    jiazhu-font-size .initial:n = {},

    % Jiazhu alignment: "outward" (default, left col left-align, right col right-align)
    %                   "inward" (left col right-align, right col left-align)
    %                   "center" (both columns center-aligned)
    %                   "left" (both columns left-aligned)
    %                   "right" (both columns right-aligned)
    jiazhu-align .tl_set:N = \l_guji_jiazhu_align_tl,
    jiazhu-align .initial:n = {outward},

    border .bool_set:N = \l_guji_border_bool,
    border .initial:n = false,

    outer-border .bool_set:N = \l_guji_outer_border_bool,
    outer-border .initial:n = false,

    banxin .bool_set:N = \l_guji_banxin_bool,
    banxin .initial:n = true,

    outer-border-thickness .tl_set:N = \l_guji_outer_border_thickness_tl,
    outer-border-thickness .initial:n = {},

    outer-border-sep .tl_set:N = \l_guji_outer_border_sep_tl,
    outer-border-sep .initial:n = {},

    debug .bool_gset:N = \g_cnv_debug_bool,

    vertical-align .tl_set:N = \l_guji_valign_tl,
    vertical-align .initial:n = {},

    border-padding-top .tl_set:N = \l_guji_border_padding_top_tl,
    border-padding-top .initial:n = {},

    border-padding-bottom .tl_set:N = \l_guji_border_padding_bottom_tl,
    border-padding-bottom .initial:n = {},

    border-thickness .tl_set:N = \l_guji_border_thickness_tl,
    border-thickness .initial:n = {},

    n-column .int_set:N = \l_guji_n_column_int,
    n-column .initial:n = 0,

    border-color .tl_set:N = \l_guji_border_color_tl,
    border-color .initial:n = {},

    background-color .tl_set:N = \l_guji_background_color_tl,
    background-color .initial:n = {},

    font-color .tl_set:N = \l_guji_font_color_tl,
    font-color .initial:n = {},

    font-name .tl_set:N = \l_guji_font_name_tl,
    font-name .initial:n = {SimSun},

    font-features .tl_set:N = \l_guji_font_features_tl,
    font-features .initial:n = {RawFeature={+vert,+vrt2}, CharacterWidth=Full},

    % Banxin (版心) section ratios
    banxin-upper-ratio .tl_set:N = \l_guji_banxin_upper_tl,
    banxin-upper-ratio .initial:n = {},

    banxin-middle-ratio .tl_set:N = \l_guji_banxin_middle_tl,
    banxin-middle-ratio .initial:n = {},

    banxin-lower-ratio .tl_set:N = \l_guji_banxin_lower_tl,
    banxin-lower-ratio .initial:n = {},

    book-name .tl_set:N = \l_guji_book_name_tl,
    book-name .initial:n = {},

    % Chapter title (章节标题) - displayed in section 2 of banxin
    chapter-title .code:n = {
      \tl_set:Nn \l_guji_chapter_title_tl { #1 }
      \ResetPageNumber
    },

    chapter-title-top-margin .tl_set:N = \l_guji_chapter_title_top_margin_tl,
    chapter-title-top-margin .initial:n = {},

    chapter-title-cols .int_set:N = \l_guji_chapter_title_cols_int,
    chapter-title-cols .initial:n = 1,

    chapter-title-font-size .tl_set:N = \l_guji_chapter_title_font_size_tl,
    chapter-title-font-size .initial:n = {},

    chapter-title-grid-height .tl_set:N = \l_guji_chapter_title_grid_height_tl,
    chapter-title-grid-height .initial:n = {},

    % Lower Yuwei (下鱼尾) - optional decoration
    lower-yuwei .bool_set:N = \l_guji_lower_yuwei_bool,
    lower-yuwei .initial:n = false,

    template .code:n = {
      % Load config file: configs/luatex-cn-guji-<name>.cfg
      \InputIfFileExists{configs/luatex-cn-guji-#1.cfg}{}{
        % Fallback to defined templates in guji / templates namespace
        \keys_set:nn { guji / templates } { #1 }
      }
    },
    
    debug .code:n = {
      \str_if_eq:nnTF { #1 } { true }
        { \bool_gset_true:N \g_cnv_debug_bool }
        { \bool_gset_false:N \g_cnv_debug_bool }
    },
    debug .initial:n = false
  }

% 5. Logic to apply geometry
\cs_new:Npn \__guji_apply_geometry:
  {
    % If in preamble, use \geometry
    \if_meaning:w \@onlypreamble \@notprerr
      % In document body
      \newgeometry{
        top=\l_guji_margin_top_tl,
        bottom=\l_guji_margin_bottom_tl,
        left=\l_guji_margin_left_tl,
        right=\l_guji_margin_right_tl
      }
      % Manual paper size adjustment for LuaTeX if changed in body
      \pagewidth=\l_guji_paper_width_tl
      \pageheight=\l_guji_paper_height_tl
    \else
      % In preamble
      \geometry{
        paperwidth=\l_guji_paper_width_tl,
        paperheight=\l_guji_paper_height_tl,
        top=\l_guji_margin_top_tl,
        bottom=\l_guji_margin_bottom_tl,
        left=\l_guji_margin_left_tl,
        right=\l_guji_margin_right_tl,
        footskip=15mm
      }
      \setlength{\topskip}{0pt}
    \fi
  }

\NewDocumentCommand{\gujiSetup}{ +m }
  {
    \tl_set:Nn \l_tmpa_tl { #1 }
    \tl_replace_all:Nnn \l_tmpa_tl { \par } { }
    \keys_set:nV { guji } \l_tmpa_tl
    % Apply geometry updates
    \__guji_apply_geometry:
  }

% Load default config (after gujiSetup is defined)
\InputIfFileExists{configs/luatex-cn-guji-default.cfg}{}{
  \PackageWarning{luatex-cn-guji}{Config file configs/luatex-cn-guji-default.cfg not found}
}

% Define \title and \chapter metadata commands
% These will be wrapped by banxin.sty if loaded
\RenewDocumentCommand{\title}{ m }
  {
    \tl_set:Nn \l_guji_book_name_tl { #1 }
    \gdef\@title{#1}
  }

% Command to reset page number to 1
\NewDocumentCommand{\ResetPageNumber}{ }
  {
    \directlua{vertical.reset_page_number()}
  }

\NewDocumentCommand{\chapter}{ m }
  {
    \tl_set:Nn \l_guji_chapter_title_tl { #1 }
    \ResetPageNumber
  }

% Command to define templates
\NewDocumentCommand{\defineGujiTemplate}{ m +m }
  {
    \keys_define:nn { guji / templates }
      {
        #1 .code:n = { \keys_set:nn { guji } { #2 } }
      }
  }

% ============================================================================
% YinZhang (印章) Command - Add seal/stamp overlay on specified page
% ============================================================================

% Declare global variables for YinZhang
\int_new:N \g_yinzhang_target_page_int
\tl_new:N \g_yinzhang_image_path_tl
\tl_new:N \g_yinzhang_opacity_tl
\tl_new:N \g_yinzhang_xshift_tl
\tl_new:N \g_yinzhang_yshift_tl
\tl_new:N \g_yinzhang_width_tl

\keys_define:nn { yinzhang }
  {
    opacity .tl_set:N = \l_yinzhang_opacity_tl,
    opacity .initial:n = {0.7},
    
    xshift .tl_set:N = \l_yinzhang_xshift_tl,
    xshift .initial:n = {-5.3cm},
    
    yshift .tl_set:N = \l_yinzhang_yshift_tl,
    yshift .initial:n = {-6.4cm},
    
    width .tl_set:N = \l_yinzhang_width_tl,
    width .initial:n = {12.9cm},
    
    page .int_set:N = \l_yinzhang_page_int,
    page .initial:n = {1},
  }

\NewDocumentCommand{\YinZhang}{ O{} m }
  {
    % Set default values for each call (avoid parameter leakage)
    \int_set:Nn \l_yinzhang_page_int { 1 }
    \tl_set:Nn \l_yinzhang_opacity_tl { 0.7 }
    \tl_set:Nn \l_yinzhang_xshift_tl { -5.3cm }
    \tl_set:Nn \l_yinzhang_yshift_tl { -6.4cm }
    \tl_set:Nn \l_yinzhang_width_tl { 12.9cm }
    
    % Parse options
    \keys_set:nn { yinzhang } { #1 }
    
    % Store parameters globally for hook access
    \int_gset_eq:NN \g_yinzhang_target_page_int \l_yinzhang_page_int
    \tl_gset:Nn \g_yinzhang_image_path_tl { #2 }
    \tl_gset_eq:NN \g_yinzhang_opacity_tl \l_yinzhang_opacity_tl
    \tl_gset_eq:NN \g_yinzhang_xshift_tl \l_yinzhang_xshift_tl
    \tl_gset_eq:NN \g_yinzhang_yshift_tl \l_yinzhang_yshift_tl
    \tl_gset_eq:NN \g_yinzhang_width_tl \l_yinzhang_width_tl
    
    % Add hook to shipout background for specified page
    \AddToHook{shipout/background}{
      \ExplSyntaxOn
      \int_compare:nNnT { \value{page} } = { \g_yinzhang_target_page_int }
        {
          \ExplSyntaxOff
          \begin{tikzpicture}[overlay]
            \node[
              anchor=north~east,
              opacity=\g_yinzhang_opacity_tl,
              inner~sep=0pt,
              xshift=\g_yinzhang_xshift_tl,
              yshift=\g_yinzhang_yshift_tl
            ] at (\paperwidth, 0) {
              \includegraphics[width=\g_yinzhang_width_tl]{\g_yinzhang_image_path_tl}
            };
          \end{tikzpicture}
          \ExplSyntaxOn
        }
      \ExplSyntaxOff
    }
  }

% 6. Load Common Templates (if any)
\InputIfFileExists{guji_common.def}{}{}


% 8. High-level Interface
\NewEnviron{guji-content}[1][]{%
    \clearpage
    \group_begin:
    \keys_set:nn { guji } { #1 }
    % Fallback: if book-name is empty but \@title is set, use \@title
    \tl_if_empty:NT \l_guji_book_name_tl
      {
        \if_meaning:w \@title \@empty \else:
          \tl_set:Nn \l_guji_book_name_tl { \@title }
        \fi:
      }
    \exp_args:NV \setmainfont \l_guji_font_name_tl [\l_guji_font_features_tl]
    \fontsize{\l_guji_font_size_tl}{\l_guji_line_spacing_tl}\selectfont
    
    % global debug flag \g_cnv_debug_bool is already set by keys_set:nn { guji } { #1 } above
    % Zero out vertical skips for exact grid layout
    \setlength{\topskip}{0pt}
    \setlength{\parskip}{0pt}
    \setlength{\partopsep}{0pt}
    
    % --- Auto-Correction Logic ---
    % Calculate exact fit for grid to avoid blank pages and overflow
    % 1. Get available space from defined margins
    \dim_set:Nn \l_tmpa_dim { \l_guji_paper_height_tl }
    \dim_sub:Nn \l_tmpa_dim { \l_guji_margin_top_tl }
    \dim_sub:Nn \l_tmpa_dim { \l_guji_margin_bottom_tl }
    % \l_tmpa_dim is now Available Height

    % 2. Calculate border overhead if border is enabled
    % We now have top and bottom padding. Default is 0.1em each.
    \dim_set:Nn \l_tmpb_dim { 0pt }
    \bool_if:NT \l_guji_border_bool {
      % Standard column border overhead = top padding + bottom padding + thickness + safety
      \dim_set:Nn \l_tmpb_dim { \l_guji_border_padding_top_tl + \l_guji_border_padding_bottom_tl + \l_guji_border_thickness_tl + 0.4pt }
    }
    % --- NEW: Add extra overhead for outer-border ---
    \bool_if:NT \l_guji_outer_border_bool {
      % We added internal padding (sep) + thickness.
      % The overhead is (sep + thickness) * 2.
      \dim_add:Nn \l_tmpb_dim { (\l_guji_outer_border_sep_tl + \l_guji_outer_border_thickness_tl) * 2 }
    }
    \dim_sub:Nn \l_tmpa_dim { \l_tmpb_dim }
    % \l_tmpa_dim is now Available Height minus border overhead

    % 3. Calculate max rows fitting in this space using FLOOR
    \int_set:Nn \l_tmpa_int { \dim_to_decimal_in_sp:n { \l_tmpa_dim } }
    \int_set:Nn \l_tmpb_int { \dim_to_decimal_in_sp:n { \l_guji_grid_height_tl } }
    \int_set:Nn \l_tmpa_int { \l_tmpa_int / \l_tmpb_int }

    % 4. Calculate heights
    % UsedHeight = Rows * GridHeight (This is the height passed to cn_vertical)
    % We use \l_tmpa_dim to store the result
    \dim_set:Nn \l_tmpa_dim { \l_guji_grid_height_tl * \l_tmpa_int }
    \tl_set:Nx \l_guji_height_tl { \dim_use:N \l_tmpa_dim } 
    
    % TotalHeight = UsedHeight + BorderOverhead + Safety (This is the \textheight)
    % We use \l_tmpb_dim to store the result
    \dim_set:Nn \l_tmpb_dim { \l_tmpa_dim + \l_tmpb_dim + 2pt }

    % 5. Adjust Margins
    % We adjust top margin to preserve the bottom margin
    \tl_set:Nx \l_guji_margin_top_tl {
      \dim_eval:n { \l_guji_paper_height_tl - \l_guji_margin_bottom_tl - \l_tmpb_dim }
    }

    % Log for debugging
    \iow_term:x { Guji~Auto-Layout:~Rows=\int_use:N \l_tmpa_int,~TextHeight=\dim_use:N \l_tmpb_dim,~TopMargin=\l_guji_margin_top_tl }

    % Update geometry for this environment
    \__guji_apply_geometry:
    
    % Apply background color if specified
    \tl_if_empty:NF \l_guji_background_color_tl
      {
        \tl_if_in:NnTF \l_guji_background_color_tl { , }
          { \pagecolor [RGB] { \l_guji_background_color_tl } }
          { \pagecolor { \l_guji_background_color_tl } }
      }
    
    % Zap all vertical spacing
    \setlength{\topskip}{0pt}
    \setlength{\parskip}{0pt}
    \setlength{\partopsep}{0pt}
    \setlength{\topsep}{0pt}
    \setlength{\itemsep}{0pt}
    \setlength{\parsep}{0pt}
    \setlength{\baselineskip}{0pt}
    \setlength{\lineskip}{0pt}
    \setlength{\lineskiplimit}{0pt}
    \parindent=0pt

    \keys_set:nx { vertical }
      {
        height = \l_guji_height_tl,
        grid-width = \l_guji_grid_width_tl,
        grid-height = \l_guji_grid_height_tl,
        vertical-align = \l_guji_valign_tl,
        border-thickness = \l_guji_border_thickness_tl,
        border-padding-top = \l_guji_border_padding_top_tl,
        border-padding-bottom = \l_guji_border_padding_bottom_tl,
        outer-border-thickness = \l_guji_outer_border_thickness_tl,
        outer-border-sep = \l_guji_outer_border_sep_tl,
        n-column = \int_use:N \l_guji_n_column_int,
        border-color = { \l_guji_border_color_tl },
        background-color = { \l_guji_background_color_tl },
        font-color = { \l_guji_font_color_tl },
        paper-width = \l_guji_paper_width_tl,
        paper-height = \l_guji_paper_height_tl,
        margin-top = \l_guji_margin_top_tl,
        margin-bottom = \l_guji_margin_bottom_tl,
        margin-left = \l_guji_margin_left_tl,
        margin-right = \l_guji_margin_right_tl,
        banxin-upper-ratio = \l_guji_banxin_upper_tl,
        banxin-middle-ratio = \l_guji_banxin_middle_tl,
        banxin-lower-ratio = \l_guji_banxin_lower_tl,
        book-name = \l_guji_book_name_tl,
        chapter-title = \l_guji_chapter_title_tl,
        chapter-title-top-margin = \l_guji_chapter_title_top_margin_tl,
        chapter-title-cols = \int_use:N \l_guji_chapter_title_cols_int,
        chapter-title-font-size = \l_guji_chapter_title_font_size_tl,
        chapter-title-grid-height = \l_guji_chapter_title_grid_height_tl,
        jiazhu-font-size = \l_guji_jiazhu_font_size_tl,
        jiazhu-align = \l_guji_jiazhu_align_tl,
        font-size = \l_guji_font_size_tl,
        border = \bool_if:NTF \l_guji_border_bool {true} {false},
        outer-border = \bool_if:NTF \l_guji_outer_border_bool {true} {false},
        banxin = \bool_if:NTF \l_guji_banxin_bool {true} {false},
        lower-yuwei = \bool_if:NTF \l_guji_lower_yuwei_bool {true} {false},
        debug = \bool_if:NTF \g_cnv_debug_bool {true} {false}
      }
    \nointerlineskip
    \__cn_vertical_process_grid:n { \BODY }
    \group_end:
    \clearpage
    % Restore geometry if needed? \restoregeometry resets to preamble settings.
    \restoregeometry
}

% 9. Apply Initial Template if specified in class options
\tl_if_empty:NF \l_guji_initial_template_tl
  {
    \keys_set:nx { guji } { template = \l_guji_initial_template_tl }
  }

\ExplSyntaxOff

% Command Aliases (CJK support)
\NewCommandCopy{\JiaZhu}{\TextFlow}
\NewCommandCopy{\夹注}{\TextFlow}
\NewCommandCopy{\印章}{\YinZhang}

% Environment Aliases (CJK support)
\NewEnvironmentCopy{正文}{guji-content}
\NewEnvironmentCopy{列表}{itemize}

% 8. Remove page numbers by default
\pagestyle{empty}

\endinput
