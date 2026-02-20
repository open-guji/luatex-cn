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

% guji.cls - A LaTeX document class for ancient Chinese book typesetting.

\RequirePackage{expl3}
\RequirePackage{l3keys2e}
\RequirePackage{core/luatex-cn-core-template}
\ProvidesExplClass {guji} {2026/02/18} {0.2.9} {Ancient Chinese Book Class}

% ============================================================================
% Variables (must be defined before use)
% ============================================================================

\tl_new:N \l_luatexcn_guji_initial_template_tl
\prop_new:N \g_luatexcn_guji_template_map_prop
\bool_new:N \g__luatexcn_guji_debug_pending_bool

% Template name mappings (Chinese -> Internal)
\prop_gset_from_keyval:Nn \g_luatexcn_guji_template_map_prop
  {
    四库全书彩色 = SiKuQuanShu-colored,
    四庫全書彩色 = SiKuQuanShu-colored,
    四库全书 = default,
    四庫全書 = default,
    红楼梦甲戌本 = HongLouMengJiaXuBen,
    紅樓夢甲戌本 = HongLouMengJiaXuBen,
    四库全书文渊阁简明目录 = 四库全书文渊阁简明目录,
    四庫全書文淵閣簡明目錄 = 四库全书文渊阁简明目录
  }

% ============================================================================
% Class Options
% ============================================================================

\keys_define:nn { luatexcn / guji / options }
  {
    unknown .code:n =
      {
        \tl_set_eq:NN \l_tmpa_tl \l_keys_key_tl
        \prop_get:NVNT \g_luatexcn_guji_template_map_prop \l_tmpa_tl \l_tmpb_tl
          { \tl_set_eq:NN \l_tmpa_tl \l_tmpb_tl }
        % First try template files, if not found pass to article
        \luatexcn_if_template_exist:VnTF \l_tmpa_tl { luatex-cn-guji- }
          { \tl_set_eq:NN \l_luatexcn_guji_initial_template_tl \l_tmpa_tl }
          { \PassOptionsToClass { \l_tmpa_tl } { article } }
      }
  }

\ProcessKeysOptions { luatexcn / guji / options }
\LoadClass{article}

% ============================================================================
% Dependencies
% ============================================================================

\RequirePackage{geometry}
\RequirePackage{xcolor}
\RequirePackage{fontspec}
\RequirePackage{environ}
\RequirePackage{xparse}
\RequirePackage{tikz}
\RequirePackage{luatex-cn-core}
\RequirePackage{debug/luatex-cn-debug}
\RequirePackage{guji/luatex-cn-guji}

% Apply debug setting (after debug package is loaded)
\bool_if:NT \g__luatexcn_guji_debug_pending_bool { \LtcDebugOn }

% Enable banxin by default
\banxinSetup{ banxin = true }

% ============================================================================
% Key-Value Configuration
% ============================================================================

\keys_define:nn { luatexcn / guji }
  {
    template .code:n = {
      \luatexcn_if_template_exist:nnTF { #1 } { luatex-cn-guji- }
        { \luatexcn_load_template:nn { #1 } { luatex-cn-guji- } }
        { \keys_set:nn { luatexcn / guji / templates } { #1 } }
    },
  }

\NewDocumentCommand{\gujiSetup}{ +m }
  {
    \tl_set:Nn \l_tmpa_tl { #1 }
    \tl_replace_all:Nnn \l_tmpa_tl { \par } { }
    \keys_set:nV { luatexcn / guji } \l_tmpa_tl
  }

\NewDocumentCommand{\defineGujiTemplate}{ m +m }
  {
    \keys_define:nn { luatexcn / guji / templates }
      { #1 .code:n = { \keys_set:nn { luatexcn / guji } { #2 } } }
  }

% ============================================================================
% Initialization
% ============================================================================

% Load default config
\InputIfFileExists{configs/luatex-cn-guji-default.cfg}{}{
  \PackageWarning{guji}{Config~file~configs/luatex-cn-guji-default.cfg~not~found}
}

% Apply initial template from class options
\tl_if_empty:NF \l_luatexcn_guji_initial_template_tl
  {
    \keys_set:nx { luatexcn / guji } { template = \exp_not:V \l_luatexcn_guji_initial_template_tl }
  }

% Apply font at end of class loading
\AtEndOfClass{
  \tl_if_empty:NTF \l__luatexcn_content_font_name_tl
    { \ApplyAutoFont }
    {
      \tl_if_empty:NTF \l__luatexcn_content_font_features_tl
        { \exp_args:NV \setmainfont \l__luatexcn_content_font_name_tl [RawFeature={+vert,+vrt2}] }
        { \exp_args:NV \setmainfont \l__luatexcn_content_font_name_tl [\l__luatexcn_content_font_features_tl] }
    }
}

% ============================================================================
% CJK Aliases (中文别名)
% ============================================================================
% Simplified Chinese / 简体
\NewCommandCopy{\古籍设置}{\gujiSetup}
\NewCommandCopy{\定义古籍模板}{\defineGujiTemplate}
% Traditional Chinese / 繁体
\NewCommandCopy{\古籍設置}{\gujiSetup}
\NewCommandCopy{\定義古籍模板}{\defineGujiTemplate}

\ExplSyntaxOff
\pagestyle{empty}
\endinput
