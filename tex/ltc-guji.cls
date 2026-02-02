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
\ProvidesExplClass {ltc-guji} {2026/02/01} {0.2.3} {Ancient Chinese Book Class (Template Support)}

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

% Store debug option for later processing (after debug package is loaded)
\bool_new:N \g__luatexcn_guji_debug_pending_bool

\keys_define:nn { luatexcn / guji / options }
  {
    debug .code:n =
      {
        \str_if_eq:nnT { #1 } { true }
          { \bool_gset_true:N \g__luatexcn_guji_debug_pending_bool }
      },
    debug .default:n = true,

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
\RequirePackage{debug/luatex-cn-debug}
% Apply debug setting from class options (after debug package is loaded)
\bool_if:NT \g__luatexcn_guji_debug_pending_bool { \LtcDebugOn }
\RequirePackage{splitpage/luatex-cn-splitpage}

% Load banxin for 版心/鱼尾 features
\RequirePackage{banxin/luatex-cn-banxin}
% Enable banxin by default for guji class
\banxinSetup{ banxin = true }

% Load yinzhang (印章/seal stamp) module
\RequirePackage{guji/luatex-cn-guji-yinzhang}

% Load meipi (眉批/headnote) module
\RequirePackage{guji/luatex-cn-guji-meipi}

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
    debug .code:n = {
      \str_if_eq:nnTF { #1 } { true }
        { \LtcDebugOn }
        { \LtcDebugOff }
    },
    debug .default:n = true,

    font-features .code:n = { \keys_set:nn { luatexcn / content } { font-features = #1 } },

    % Split page (筒子页) configuration - forward to splitpage namespace
    split-page .code:n = { \keys_set:nn { luatexcn / splitpage } { enabled = #1 } },
    split-page .default:n = true,

    split-page-right-first .code:n = { \keys_set:nn { luatexcn / splitpage } { right-first = #1 } },
    split-page-right-first .default:n = true,

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
    \bool_if:NT \l__luatexcn_sp_enabled_bool
      {
        \exp_args:Nx \splitpageSetup{
          source-width = \l__luatexcn_page_paper_width_tl,
          source-height = \l__luatexcn_page_paper_height_tl,
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

% Note: \title and \publisher are defined in core/luatex-cn-core-metadata.sty
% They forward to banxin namespace automatically

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
    % Also set global metadata for layout phase (fixes issue #45 - chapter not showing on first page)
    \metadataSetup{ chapter-title = {#1} }
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

% 6. Load Common Templates (if any)
\InputIfFileExists{guji_common.def}{}{}


% 8. High-level Interface
\NewEnviron{guji-content}[1][]{%
    \group_begin:
    \keys_set:nn { luatexcn / guji } { #1 }
    % Note: book-name is set directly by \title command
    % No fallback from \@title to avoid LaTeX's default error-throwing definition
    % Setup font using shared helper
    \__luatexcn_content_setup_font:

    % --- Auto-Layout Logic (TeX calculation for exact precision) ---
    % I. Width Logic (Auto-calculated from n-column)
    \dim_set:Nn \l_tmpa_dim { \l__luatexcn_page_paper_width_tl }
    \dim_sub:Nn \l_tmpa_dim { \l__luatexcn_page_margin_left_tl }
    \dim_sub:Nn \l_tmpa_dim { \l__luatexcn_page_margin_right_tl }
    \dim_set:Nn \l_tmpb_dim { 0pt }
    \bool_if:NT \l__luatexcn_content_outer_border_bool {
      \dim_add:Nn \l_tmpb_dim { (\l__luatexcn_content_outer_border_sep_tl + \l__luatexcn_content_outer_border_thickness_tl) * 2 }
    }
    \bool_if:NT \l__luatexcn_content_border_bool {
      \dim_add:Nn \l_tmpb_dim { \l__luatexcn_content_border_thickness_tl }
    }
    \int_set:Nn \l_tmpa_int { 2 * \l__luatexcn_content_n_column_int + 1 }
    \dim_sub:Nn \l_tmpa_dim { \l_tmpb_dim }
    \int_set:Nn \l_tmpb_int { \dim_to_decimal_in_sp:n { \l_tmpa_dim } / \l_tmpa_int }
    \tl_set:Nx \l__luatexcn_content_grid_width_tl { \dim_eval:n { \l_tmpb_int sp } }

    % II. Height Logic
    \dim_set:Nn \l_tmpa_dim { \l__luatexcn_page_paper_height_tl }
    \dim_sub:Nn \l_tmpa_dim { \l__luatexcn_page_margin_top_tl }
    \dim_sub:Nn \l_tmpa_dim { \l__luatexcn_page_margin_bottom_tl }
    \dim_set:Nn \l_tmpb_dim { 0pt }
    \bool_if:NT \l__luatexcn_content_outer_border_bool {
      \dim_add:Nn \l_tmpb_dim { (\l__luatexcn_content_outer_border_sep_tl + \l__luatexcn_content_outer_border_thickness_tl) * 2 }
    }
    \bool_if:NT \l__luatexcn_content_border_bool {
      \dim_add:Nn \l_tmpb_dim { \l__luatexcn_content_border_padding_top_tl + \l__luatexcn_content_border_padding_bottom_tl + \l__luatexcn_content_border_thickness_tl }
    }
    \dim_sub:Nn \l_tmpa_dim { \l_tmpb_dim }

    % Calculate grid-height and content-height
    \int_compare:nNnTF { \l__luatexcn_content_n_char_per_col_int } > { 0 }
      {
        \int_set:Nn \l_tmpa_int { \dim_to_decimal_in_sp:n { \l_tmpa_dim } / \l__luatexcn_content_n_char_per_col_int }
        \dim_set:Nn \l_luatexcn_guji_grid_height_dim { \l_tmpa_int sp }
        \tl_set:Nx \l__luatexcn_content_grid_height_tl { \dim_use:N \l_luatexcn_guji_grid_height_dim }
        \dim_set:Nn \l_tmpa_dim { \l_luatexcn_guji_grid_height_dim * \l__luatexcn_content_n_char_per_col_int }
        \tl_set:Nx \l__luatexcn_content_height_tl { \dim_use:N \l_tmpa_dim }
      }
      {
        \tl_if_empty:NTF \l__luatexcn_content_grid_height_tl
          { \msg_error:nn { guji } { missing-grid-param } }
          {
            \int_set:Nn \l_tmpa_int { \dim_ratio:nn { \l_tmpa_dim } { \l__luatexcn_content_grid_height_tl } }
            \dim_set:Nn \l_tmpa_dim { \l__luatexcn_content_grid_height_tl * \l_tmpa_int }
            \tl_set:Nx \l__luatexcn_content_height_tl { \dim_use:N \l_tmpa_dim }
          }
      }

    % Calculate total box height and adjust top margin
    \dim_set:Nn \l_tmpb_dim { \l_tmpa_dim + \l_tmpb_dim + 2pt }
    \tl_set:Nx \l__luatexcn_page_margin_top_tl {
      \dim_eval:n { \l__luatexcn_page_paper_height_tl - \l__luatexcn_page_margin_bottom_tl - \l_tmpb_dim }
    }

    \LtcIfDebugT { \iow_term:x { Guji~Layout:~grid-width=\l__luatexcn_content_grid_width_tl~,~grid-height=\l__luatexcn_content_grid_height_tl~,~height=\l__luatexcn_content_height_tl } }

    % Update geometry for this environment
    \luatexcn_apply_geometry:
    
    % Apply background color using shared helper
    \__luatexcn_content_apply_background:

    % Zero all vertical skips using shared helper
    \__luatexcn_content_zero_skips:

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
% Environment Aliases (CJK support)
\NewEnvironmentCopy{正文}{guji-content}%
%
% 8. Remove page numbers by default
\pagestyle{empty}%
%
\endinput
