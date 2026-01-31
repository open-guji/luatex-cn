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

\RequirePackage{expl3}
\RequirePackage{l3keys2e}
\ProvidesExplClass {ltc-guji} {2026/01/31} {0.2.1} {Ancient Chinese Book Class (Template Support)}

\tl_new:N \l_luatexcn_guji_initial_template_tl
\prop_new:N \g_luatexcn_guji_template_map_prop

% Define Template Mappings (Chinese -> English/Internal name)
\prop_gset_from_keyval:Nn \g_luatexcn_guji_template_map_prop
  {
    四库全书彩色 = SiKuQuanShu-colored,
    四庫全書彩色 = SiKuQuanShu-colored,
    四库全书 = default,
    四庫全書 = default,
    红楼梦甲戌本 = HongLouMengJiaXuBen,
    紅樓夢甲戌本 = HongLouMengJiaXuBen
  }

\keys_define:nn { luatexcn / guji / options }
  {
    unknown .code:n =
      {
        \tl_set_eq:NN \l_tmpa_tl \l_keys_key_tl
        
        % Try to map the option name
        \prop_get:NVNT \g_luatexcn_guji_template_map_prop \l_tmpa_tl \l_tmpb_tl
          { \tl_set_eq:NN \l_tmpa_tl \l_tmpb_tl }
        
        % Look for config file: configs/luatex-cn-guji-<name>.cfg
        \file_if_exist:nTF { configs/luatex-cn-guji- \l_tmpa_tl .cfg }
          {
            \tl_set_eq:NN \l_luatexcn_guji_initial_template_tl \l_tmpa_tl
          }
          {
            \PassOptionsToClass { \l_tmpa_tl } { article }
          }
      }
  }

\ProcessKeysOptions { luatexcn / guji / options }

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
\RequirePackage{tikz}
\RequirePackage{luatex-cn-core}
\RequirePackage{splitpage/luatex-cn-splitpage}

% Load banxin for 版心/鱼尾 features
\RequirePackage{banxin/luatex-cn-banxin}
% Enable banxin by default for guji class
\banxinSetup{ banxin = true }

% 3. Page Geometry - Will be applied dynamically via tsemplate
% Default values stored in key-value system below

% Storage for Book Name (formerly Banxin text)
\tl_new:N \l_luatexcn_guji_book_name_tl
\tl_set:Nn \l_luatexcn_guji_book_name_tl {}

% Dimension for calculated grid-height
\dim_new:N \l_luatexcn_guji_grid_height_dim

% Error messages
\msg_new:nnn { guji } { missing-grid-param }
  { Either~n-char~or~grid-height~must~be~specified. }

% Storage for Chapter Title (章节标题)
\tl_new:N \l_luatexcn_guji_chapter_title_tl
\tl_set:Nn \l_luatexcn_guji_chapter_title_tl {}

\bool_new:N \l_luatexcn_guji_banxin_bool
\bool_set_true:N \l_luatexcn_guji_banxin_bool

% Variables for computed layout values (auto-layout computes grid-width, grid-height, height)




\keys_define:nn { luatexcn / guji }
  {
    % Grid and font settings - forward to content namespace




    % Guji-specific settings


    banxin .code:n = { \keys_set:nn { luatexcn / banxin } { banxin = {#1} } },

    font-name .code:n = { \keys_set:nn { luatexcn / content } { font-name = #1 } },

    debug .bool_set:N = \g_luatexcn_debug_enabled_bool,
    debug .initial:n = false,

    font-features .code:n = { \keys_set:nn { luatexcn / content } { font-features = #1 } },

    % Split page (筒子页) configuration
    split-page .bool_set:N = \l_luatexcn_guji_split_page_bool,
    split-page .initial:n = true,

    split-page-right-first .bool_set:N = \l_luatexcn_guji_split_right_first_bool,
    split-page-right-first .initial:n = true,


    template .code:n = {
      % Ensure standard catcodes for config files (preserve spaces)
      \ExplSyntaxOff
      \InputIfFileExists{configs/luatex-cn-guji-#1.cfg}{}{
        \ExplSyntaxOn
        % Fallback to defined templates in luatexcn / guji / templates namespace
        \keys_set:nn { luatexcn / guji / templates } { #1 }
        \ExplSyntaxOff
      }
      \ExplSyntaxOn 
    },

    unknown .code:n = { \keys_set:nx { luatexcn / content } { \l_keys_key_tl = { #1 } } },
  }

% 5. Logic to apply geometry


% 5b. Split page setup
\cs_new:Npn \__luatexcn_guji_apply_split_page:
  {
    \bool_if:NT \l_luatexcn_guji_split_page_bool
      {
        \exp_args:Nx \splitpageSetup{
          source-width = \l__luatexcn_page_paper_width_tl,
          source-height = \l__luatexcn_page_paper_height_tl,
          right-first = \bool_if:NTF \l_luatexcn_guji_split_right_first_bool {true} {false}
        }
        \enableSplitPage
      }
  }

\NewDocumentCommand{\gujiSetup}{ +m }
  {
    \tl_set:Nn \l_tmpa_tl { #1 }
    \tl_replace_all:Nnn \l_tmpa_tl { \par } { }
    \keys_set:nV { luatexcn / page } \l_tmpa_tl
    \keys_set:nV { luatexcn / guji } \l_tmpa_tl
    % Apply geometry updates
    \luatexcn_apply_geometry:
    % Apply split page if enabled
    \__luatexcn_guji_apply_split_page:
  }

% Load default config (after gujiSetup is defined)
\InputIfFileExists{configs/luatex-cn-guji-default.cfg}{}{
  \PackageWarning{luatex-cn-guji}{Config file~configs/luatex-cn-guji-default.cfg~not~found}
}

% Define \title and \chapter metadata commands
% These forward to the banxin namespace
\RenewDocumentCommand{\title}{ m }
  {
    \keys_set:nn { luatexcn / banxin } { book-name = {#1} }
    \gdef\@title{#1}
  }

\NewDocumentCommand{\publisher}{ m }
  {
    \keys_set:nn { luatexcn / banxin } { publisher = {#1} }
  }
\NewCommandCopy{\出版商}{\publisher}

% Command to reset page number to 1
\NewDocumentCommand{\ResetPageNumber}{ }
  {
    \lua_now:e { core.reset_page_number(); }
  }

% Command to set page number to arbitrary value
\NewDocumentCommand{\SetPageNumber}{ m }
  {
    \lua_now:e { core.set_page_number(#1); }
  }
\NewCommandCopy{\设置页码}{\SetPageNumber}

\DeclareDocumentCommand{\chapter}{ m }
  {
    \keys_set:nn { luatexcn / banxin } { chapter-title = {#1} }
    \ResetPageNumber
  }

% Command to define templates
\NewDocumentCommand{\defineGujiTemplate}{ m +m }
  {
    \keys_define:nn { luatexcn / guji / templates }
      {
        #1 .code:n = { \keys_set:nn { luatexcn / guji } { #2 } }
      }
  }

% ============================================================================
% YinZhang (印章) Command - Add seal/stamp overlay on specified page
% ============================================================================

% Declare global variables for YinZhang
% Declare global variables for YinZhang
\int_new:N \g_luatexcn_guji_yinzhang_target_page_int
\tl_new:N \g_luatexcn_guji_yinzhang_image_path_tl
\tl_new:N \g_luatexcn_guji_yinzhang_opacity_tl
\tl_new:N \g_luatexcn_guji_yinzhang_xshift_tl
\tl_new:N \g_luatexcn_guji_yinzhang_yshift_tl
\tl_new:N \g_luatexcn_guji_yinzhang_width_tl
\tl_new:N \g_luatexcn_guji_yinzhang_color_tl

\keys_define:nn { luatexcn / guji / yinzhang }
  {
    opacity .tl_set:N = \l_luatexcn_guji_yinzhang_opacity_tl,
    opacity .initial:n = {0.7},
    
    xshift .tl_set:N = \l_luatexcn_guji_yinzhang_xshift_tl,
    xshift .initial:n = {-5.3cm},
    
    yshift .tl_set:N = \l_luatexcn_guji_yinzhang_yshift_tl,
    yshift .initial:n = {-6.4cm},
    
    width .tl_set:N = \l_luatexcn_guji_yinzhang_width_tl,
    width .initial:n = {12.9cm},
    
    page .int_set:N = \l_luatexcn_guji_yinzhang_page_int,
    page .initial:n = {1},
    
    color .tl_set:N = \l_luatexcn_guji_yinzhang_color_tl,
    color .initial:n = {},
  }

\NewDocumentCommand{\YinZhang}{ O{} m }
  {
    % Set default values for each call (avoid parameter leakage)
    \int_set:Nn \l_luatexcn_guji_yinzhang_page_int { 1 }
    \tl_set:Nn \l_luatexcn_guji_yinzhang_opacity_tl { 1 }
    \tl_set:Nn \l_luatexcn_guji_yinzhang_xshift_tl { 0cm }
    \tl_set:Nn \l_luatexcn_guji_yinzhang_yshift_tl { 0cm }
    \tl_set:Nn \l_luatexcn_guji_yinzhang_width_tl { 10cm }
    \tl_set:Nn \l_luatexcn_guji_yinzhang_color_tl { }
    
    % Parse options
    \keys_set:nn { luatexcn / guji / yinzhang } { #1 }
    
    % Store parameters globally for hook access
    \int_gset_eq:NN \g_luatexcn_guji_yinzhang_target_page_int \l_luatexcn_guji_yinzhang_page_int
    \tl_gset:Nn \g_luatexcn_guji_yinzhang_image_path_tl { #2 }
    \tl_gset_eq:NN \g_luatexcn_guji_yinzhang_opacity_tl \l_luatexcn_guji_yinzhang_opacity_tl
    \tl_gset_eq:NN \g_luatexcn_guji_yinzhang_xshift_tl \l_luatexcn_guji_yinzhang_xshift_tl
    \tl_gset_eq:NN \g_luatexcn_guji_yinzhang_yshift_tl \l_luatexcn_guji_yinzhang_yshift_tl
    \tl_gset_eq:NN \g_luatexcn_guji_yinzhang_width_tl \l_luatexcn_guji_yinzhang_width_tl
    \tl_gset_eq:NN \g_luatexcn_guji_yinzhang_color_tl \l_luatexcn_guji_yinzhang_color_tl
    
    \AddToHook{shipout/background}{
      \int_compare:nNnT { \value{page} } = { \g_luatexcn_guji_yinzhang_target_page_int }
        {
          \begin{tikzpicture}[overlay]
            \node[
              anchor=north~east,
              opacity=\g_luatexcn_guji_yinzhang_opacity_tl,
              inner~sep=0pt,
              xshift=-\g_luatexcn_guji_yinzhang_xshift_tl,
              yshift=-\g_luatexcn_guji_yinzhang_yshift_tl
            ]~at~(\paperwidth,~0)~{
              \includegraphics[width=\g_luatexcn_guji_yinzhang_width_tl]{\g_luatexcn_guji_yinzhang_image_path_tl}
            };
          \end{tikzpicture}
        }
    }
  }

% 6. Load Common Templates (if any)
\InputIfFileExists{guji_common.def}{}{}


% 8. High-level Interface
\NewEnviron{guji-content}[1][]{%
    \group_begin:
    \keys_set:nn { luatexcn / guji } { #1 }
    % Note: book-name is set directly by \title command
    % No fallback from \@title to avoid LaTeX's default error-throwing definition
    % Font selection logic:
    % 1. If user specified font-name in the environment options, use it
    % 2. Otherwise, rely on the font set at class load or in preamble
    \tl_if_empty:NF \l__luatexcn_content_font_name_tl
      {
        \tl_if_empty:NTF \l__luatexcn_content_font_features_tl
          {
            % No features specified, use default for CJK vertical
            \exp_args:NV \setmainfont \l__luatexcn_content_font_name_tl [RawFeature={+vert,+vrt2}]
          }
          {
            \exp_args:NV \setmainfont \l__luatexcn_content_font_name_tl [\l__luatexcn_content_font_features_tl]
          }
      }
    \fontsize{\l__luatexcn_content_font_size_tl}{\l__luatexcn_content_line_spacing_tl}\selectfont
    
    % global debug flag \g_luatexcn_debug_enabled_bool is already set by keys_set:nn { luatexcn / guji } { #1 } above
    % Zero out vertical skips for exact grid layout
    \dim_zero:N \topskip
    \dim_zero:N \parskip
    \dim_zero:N \partopsep
    
    % --- Auto-Layout Logic ---
    % Either n-char OR grid-height must be specified (mutually exclusive)
    %
    % Mode A: n-char specified (grid-height auto-calculated)
    %   grid-height = available-height / n-char
    %   height = available-height
    %
    % Mode B: grid-height specified (n-char auto-calculated, may truncate)
    %   n-char = floor(available-height / grid-height)
    %   height = n-char * grid-height

    % I. Width Logic (Auto-calculated from n-column)
    % 1. Calculate raw content area width
    \dim_set:Nn \l_tmpa_dim { \l__luatexcn_page_paper_width_tl }
    \dim_sub:Nn \l_tmpa_dim { \l__luatexcn_page_margin_left_tl }
    \dim_sub:Nn \l_tmpa_dim { \l__luatexcn_page_margin_right_tl }
    % \l_tmpa_dim = content-width

    % 2. Calculate border overhead (width) - using content variables
    \dim_set:Nn \l_tmpb_dim { 0pt }
    \bool_if:NT \l__luatexcn_content_outer_border_bool {
      \dim_add:Nn \l_tmpb_dim { (\l__luatexcn_content_outer_border_sep_tl + \l__luatexcn_content_outer_border_thickness_tl) * 2 }
    }
    \bool_if:NT \l__luatexcn_content_border_bool {
      \dim_add:Nn \l_tmpb_dim { \l__luatexcn_content_border_thickness_tl }
    }
    % \l_tmpb_dim = border-overhead-width

    % 3. Calculate grid-width
    % total-cols = 2 * n-column + 1
    \int_set:Nn \l_tmpa_int { 2 * \l__luatexcn_content_n_column_int + 1 }
    
    % grid-width = (content-width - border-overhead) / total-cols
    \dim_sub:Nn \l_tmpa_dim { \l_tmpb_dim }
    % available-for-grids / total-cols
    \int_set:Nn \l_tmpb_int { \dim_to_decimal_in_sp:n { \l_tmpa_dim } / \l_tmpa_int }
    \tl_set:Nx \l__luatexcn_content_grid_width_tl { \dim_eval:n { \l_tmpb_int sp } }

    \bool_if:NT \g_luatexcn_debug_enabled_bool { \iow_term:x { Guji~Layout~Width:~total-cols=\int_use:N~\l_tmpa_int~,~grid-width=\l__luatexcn_content_grid_width_tl } }

    % II. Height Logic
    % 1. Calculate raw content area height
    \dim_set:Nn \l_tmpa_dim { \l__luatexcn_page_paper_height_tl }
    \dim_sub:Nn \l_tmpa_dim { \l__luatexcn_page_margin_top_tl }
    \dim_sub:Nn \l_tmpa_dim { \l__luatexcn_page_margin_bottom_tl }
    % \l_tmpa_dim = content-height

    % 2. Calculate border overhead - using content variables
    \dim_set:Nn \l_tmpb_dim { 0pt }
    \bool_if:NT \l__luatexcn_content_outer_border_bool {
      \dim_add:Nn \l_tmpb_dim { (\l__luatexcn_content_outer_border_sep_tl + \l__luatexcn_content_outer_border_thickness_tl) * 2 }
    }
    \bool_if:NT \l__luatexcn_content_border_bool {
      \dim_add:Nn \l_tmpb_dim { \l__luatexcn_content_border_padding_top_tl + \l__luatexcn_content_border_padding_bottom_tl + \l__luatexcn_content_border_thickness_tl }
    }
    % \l_tmpb_dim = border-overhead

    % 3. Calculate available height for text
    \dim_sub:Nn \l_tmpa_dim { \l_tmpb_dim }
    % \l_tmpa_dim = available-height

    % 4. Determine mode and calculate grid dimensions
    \int_compare:nNnTF { \l__luatexcn_content_n_char_per_col_int } > { 0 }
      {
        % Mode A: n-char-per-col specified, calculate grid-height (floor to avoid overflow)
        % grid-height = floor(available-height / n-char-per-col)
        \int_set:Nn \l_tmpa_int { \dim_to_decimal_in_sp:n { \l_tmpa_dim } / \l__luatexcn_content_n_char_per_col_int }
        \dim_set:Nn \l_luatexcn_guji_grid_height_dim { \l_tmpa_int sp }
        \tl_set:Nx \l__luatexcn_content_grid_height_tl { \dim_use:N \l_luatexcn_guji_grid_height_dim }
        % height = grid-height * n-char-per-col (may be slightly less than available)
        \dim_set:Nn \l_tmpa_dim { \l_luatexcn_guji_grid_height_dim * \l__luatexcn_content_n_char_per_col_int }
        \tl_set:Nx \l__luatexcn_content_height_tl { \dim_use:N \l_tmpa_dim }
        \bool_if:NT \g_luatexcn_debug_enabled_bool { \iow_term:x { Guji~Mode~A:~n-char-per-col=\int_use:N~\l__luatexcn_content_n_char_per_col_int~,~grid-height=\l__luatexcn_content_grid_height_tl~,~height=\l__luatexcn_content_height_tl } }
      }
      {
        % Mode B: grid-height specified, calculate fitting rows
        \tl_if_empty:NTF \l__luatexcn_content_grid_height_tl
          {
            \msg_error:nn { guji } { missing-grid-param }
          }
          {
            % Calculate max rows: floor(available-height / grid-height)
            \int_set:Nn \l_tmpa_int { \dim_ratio:nn { \l_tmpa_dim } { \l__luatexcn_content_grid_height_tl } }
            % height = rows * grid-height
            \dim_set:Nn \l_tmpa_dim { \l__luatexcn_content_grid_height_tl * \l_tmpa_int }
            \tl_set:Nx \l__luatexcn_content_height_tl { \dim_use:N \l_tmpa_dim }
            \bool_if:NT \g_luatexcn_debug_enabled_bool { \iow_term:x { Guji~Mode~B:~grid-height=\l__luatexcn_content_grid_height_tl~,~rows=\int_use:N~\l_tmpa_int~,~height=\l__luatexcn_content_height_tl } }
          }
      }

    % 5. Calculate total box height (content + border overhead + safety)
    \dim_set:Nn \l_tmpb_dim { \l_tmpa_dim + \l_tmpb_dim + 2pt }

    % 6. Adjust top margin to preserve bottom margin
    \tl_set:Nx \l__luatexcn_page_margin_top_tl {
      \dim_eval:n { \l__luatexcn_page_paper_height_tl - \l__luatexcn_page_margin_bottom_tl - \l_tmpb_dim }
    }

    % Log final layout
    \bool_if:NT \g_luatexcn_debug_enabled_bool { \iow_term:x { Guji~Layout:~TextHeight=\dim_use:N~\l_tmpb_dim~,~TopMargin=\l__luatexcn_page_margin_top_tl } }

    % Update geometry for this environment
    \luatexcn_apply_geometry:
    
    % Apply background color if specified
    \tl_if_empty:NF \l__luatexcn_page_background_color_tl
      {
        \tl_if_in:NnTF \l__luatexcn_page_background_color_tl { , }
          { \pagecolor [RGB] { \l__luatexcn_page_background_color_tl } }
          { \pagecolor { \l__luatexcn_page_background_color_tl } }
      }
    
    % Zap all vertical spacing
    \dim_zero:N \topskip
    \dim_zero:N \parskip
    \dim_zero:N \partopsep
    \dim_zero:N \topsep
    \dim_zero:N \itemsep
    \dim_zero:N \parsep
    \dim_zero:N \baselineskip
    \dim_zero:N \lineskip
    \dim_zero:N \lineskiplimit
    \dim_zero:N \parindent

    \keys_set:nx { luatexcn / vertical }
      {
        height = \l__luatexcn_content_height_tl,
        grid-width = \l__luatexcn_content_grid_width_tl,
        grid-height = \l__luatexcn_content_grid_height_tl,
        vertical-align = \l__luatexcn_content_valign_tl,
        n-column = \int_use:N \l__luatexcn_content_n_column_int,
        background-color = { \l__luatexcn_page_background_color_tl },
        font-color = { \l__luatexcn_content_font_color_tl },
        paper-width = \l__luatexcn_page_paper_width_tl,
        paper-height = \l__luatexcn_page_paper_height_tl,
        margin-top = \l__luatexcn_page_margin_top_tl,
        margin-bottom = \l__luatexcn_page_margin_bottom_tl,
        margin-left = \l__luatexcn_page_margin_left_tl,
        margin-right = \l__luatexcn_page_margin_right_tl,
        font-size = \l__luatexcn_content_font_size_tl,
      }
    \RenewDocumentCommand{\newpage}{}{\penalty-10003 }
    \RenewDocumentCommand{\clearpage}{}{\penalty-10003 }
    \cs_set:Npn \chapter ##1 {
      \directlua { core.insert_chapter_marker( "\luaescapestring{ \tl_to_str:n { ##1 } }" ) }
      \box0\relax
    }
    \nointerlineskip
    \__luatexcn_content_process_grid:n { \BODY }
    \group_end:
    \clearpage
    % Restore geometry if needed? \restoregeometry resets to preamble settings.
    \restoregeometry
}


% 9. Apply Initial Template if specified in class options
\tl_if_empty:NF \l_luatexcn_guji_initial_template_tl
  {
    \keys_set:nx { luatexcn / guji } { template = \exp_not:V \l_luatexcn_guji_initial_template_tl }
  }

% Apply auto-detected font if no font-name is set and user hasn't set one
% This is moved from \AtBeginDocument to here (class load) as requested.
\AtEndOfClass{
  \tl_if_empty:NTF \l__luatexcn_content_font_name_tl 
    { 
       \ApplyAutoFont 
    }
    {
       % If font-name was specified in class options or template, apply it now
       \tl_if_empty:NTF \l__luatexcn_content_font_features_tl
         { \exp_args:NV \setmainfont \l__luatexcn_content_font_name_tl [RawFeature={+vert,+vrt2}] }
         { \exp_args:NV \setmainfont \l__luatexcn_content_font_name_tl [\l__luatexcn_content_font_features_tl] }
    }
    \luatexcn_apply_geometry:
    \__luatexcn_guji_apply_split_page:
}
\ExplSyntaxOff
%
% Command Aliases (CJK support)
\NewCommandCopy{\印章}{\YinZhang}%
%
% Environment Aliases (CJK support)
\NewEnvironmentCopy{正文}{guji-content}%
%
% 8. Remove page numbers by default
\pagestyle{empty}%
%
\endinput
