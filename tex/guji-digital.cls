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

% guji-digital.cls - A LaTeX document class for digitizing ancient Chinese books.
% Unlike guji.cls (semantic), this class focuses on layout-faithful digitization:
% each TeX newline = one column, explicit page breaks, explicit banxin content.

\RequirePackage{expl3}
\RequirePackage{l3keys2e}
\RequirePackage{core/luatex-cn-core-template}
\ProvidesExplClass {guji-digital} {2026/02/18} {0.2.9}
  {Ancient Chinese Book Digitization Class}

% ============================================================================
% Variables
% ============================================================================

\tl_new:N \l_luatexcn_digital_initial_template_tl
\prop_new:N \g_luatexcn_digital_template_map_prop

% Template name mappings (Chinese -> Internal)
\prop_gset_from_keyval:Nn \g_luatexcn_digital_template_map_prop
  {
    四库全书彩色 = SiKuQuanShu-colored,
    四庫全書彩色 = SiKuQuanShu-colored,
    红楼梦甲戌本 = HongLouMengJiaXuBen,
    紅樓夢甲戌本 = HongLouMengJiaXuBen,
    四库全书文渊阁简明目录 = SikuWenyuanMulu,
    四庫全書文淵閣簡明目錄 = SikuWenyuanMulu
  }

% ============================================================================
% Class Options
% ============================================================================

\keys_define:nn { luatexcn / digital / options }
  {
    unknown .code:n =
      {
        \tl_set_eq:NN \l_tmpa_tl \l_keys_key_tl
        % Check if it's a Chinese template name, map to internal name
        \prop_get:NVNT \g_luatexcn_digital_template_map_prop \l_tmpa_tl \l_tmpb_tl
          { \tl_set_eq:NN \l_tmpa_tl \l_tmpb_tl }
        % Try template files, if not found pass to article
        \luatexcn_if_template_exist:VnTF \l_tmpa_tl { luatex-cn-digital- }
          { \tl_set_eq:NN \l_luatexcn_digital_initial_template_tl \l_tmpa_tl }
          { \PassOptionsToClass { \l_tmpa_tl } { article } }
      }
  }

\ProcessKeysOptions { luatexcn / digital / options }
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
\RequirePackage{digital/luatex-cn-digital}

% Guji features - load all subpackages same as guji.cls for full compatibility
\RequirePackage{guji/luatex-cn-guji-judou}     % 句读 - Classical punctuation
\RequirePackage{guji/luatex-cn-guji-jiazhu}    % 夹注 - Interlinear notes
\RequirePackage{guji/luatex-cn-guji-pizhu}     % 批注 - Marginal notes
\RequirePackage{guji/luatex-cn-guji-meipi}     % 眉批 - Head annotations
\RequirePackage{guji/luatex-cn-guji-yinzhang}  % 印章 - Seal stamps
\RequirePackage{guji/luatex-cn-guji-danye}     % 单页 - Single page mode
\RequirePackage{guji/luatex-cn-guji-mulu}      % 目录 - Catalog entries
\RequirePackage{core/luatex-cn-footnote}       % 脚注 - Footnotes
\RequirePackage{guji/luatex-cn-guji-titlepage} % 书名页 - Title page
\RequirePackage{guji/luatex-cn-guji-cover}     % 封面 - Cover page

% Enable banxin by default
\banxinSetup{ banxin = true }

% Enable digital mode: BodyText/正文 uses obeylines (newline = column break)
\contentSetup{ digital-mode = true }

% ============================================================================
% Key-Value Configuration
% ============================================================================

\keys_define:nn { luatexcn / digital }
  {
    template .code:n = {
      \luatexcn_if_template_exist:nnTF { #1 } { luatex-cn-digital- }
        { \luatexcn_load_template:nn { #1 } { luatex-cn-digital- } }
        { \msg_warning:nnn { luatexcn } { template-not-found } { #1 } }
    },
  }

\NewDocumentCommand{\digitalSetup}{ +m }
  {
    \tl_set:Nn \l_tmpa_tl { #1 }
    \tl_replace_all:Nnn \l_tmpa_tl { \par } { }
    \keys_set:nV { luatexcn / digital } \l_tmpa_tl
  }

% ============================================================================
% Initialization
% ============================================================================

% Load default config
\InputIfFileExists{configs/luatex-cn-digital-default.cfg}{}{
  \PackageWarning{guji-digital}{Config~file~configs/luatex-cn-digital-default.cfg~not~found}
}

% Apply initial template from class options
\tl_if_empty:NF \l_luatexcn_digital_initial_template_tl
  {
    \keys_set:nx { luatexcn / digital } { template = \exp_not:V \l_luatexcn_digital_initial_template_tl }
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
% CJK Aliases
% ============================================================================
\NewCommandCopy{\数字化设置}{\digitalSetup}
\NewCommandCopy{\數字化設置}{\digitalSetup}

% Guji command aliases (same as guji.cls)
\NewCommandCopy{\圈点}{\EmphasisMark}

\ExplSyntaxOff
\pagestyle{empty}
\endinput
