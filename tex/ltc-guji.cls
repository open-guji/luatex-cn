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
\ProvidesExplClass {ltc-guji} {2026/02/03} {0.2.4} {Ancient Chinese Book Class (Template Support)}

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

% Load all guji-specific features (句读, 夹注, 批注, 眉批, 印章, 单页)
\RequirePackage{guji/luatex-cn-guji}

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
    debug .code:n = {
      \str_if_eq:nnTF { #1 } { true }
        { \LtcDebugOn }
        { \LtcDebugOff }
    },
    debug .default:n = true,

    font-features .code:n = { \keys_set:nn { luatexcn / content } { font-features = #1 } },

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


\NewDocumentCommand{\gujiSetup}{ +m }
  {
    \tl_set:Nn \l_tmpa_tl { #1 }
    \tl_replace_all:Nnn \l_tmpa_tl { \par } { }
    \keys_set:nV { luatexcn / guji } \l_tmpa_tl
    \luatexcn_apply_geometry:
    \__luatexcn_page_apply_split:
  }

% Load default config (after gujiSetup is defined)
\InputIfFileExists{configs/luatex-cn-guji-default.cfg}{}{
  \PackageWarning{luatex-cn-guji}{Config file~configs/luatex-cn-guji-default.cfg~not~found}
}

% Note: \title, \publisher, and \chapter are defined in core/luatex-cn-core-metadata.sty
% They forward to banxin namespace automatically

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

% ============================================================================
% Guji-specific Helper Commands (extracted from guji-content environment)
% ============================================================================

% 8. High-level Interface
\NewEnviron{guji-content}[1][]{%
    \group_begin:
    \keys_set:nn { luatexcn / guji } { #1 }
    \__luatexcn_content_setup_font:
    \__luatexcn_content_auto_layout:
    \luatexcn_apply_geometry:
    \__luatexcn_content_apply_background:
    \__luatexcn_content_zero_skips:
    \__luatexcn_page_override_pagebreak:
    \nointerlineskip
    \__luatexcn_content_process_grid:n { \BODY }
    \group_end:
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
    \__luatexcn_page_apply_split:
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
