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
\ProvidesExplClass {ltc-book} {2026/02/07} {0.2.6} {Chinese Vertical Book Class}

% ============================================================================
% Variables
% ============================================================================

\tl_new:N \l_luatexcn_book_initial_template_tl

% ============================================================================
% Class Options
% ============================================================================

\keys_define:nn { luatexcn / book / options }
  {
    unknown .code:n =
      {
        \tl_set_eq:NN \l_tmpa_tl \l_keys_key_tl
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
\RequirePackage{luatex-cn-core}

% ============================================================================
% Initialization
% ============================================================================

% Load default config
\InputIfFileExists{configs/luatex-cn-book-default.cfg}{}{
  \PackageWarning{luatex-cn-book}{Config~file~configs/luatex-cn-book-default.cfg~not~found}
}

% Apply initial template from class options
\tl_if_empty:NF \l_luatexcn_book_initial_template_tl
  {
    \keys_set:nx { luatexcn / book } { template = \l_luatexcn_book_initial_template_tl }
  }

% Apply font at end of class loading
\AtEndOfClass{
  \tl_if_empty:NT \l__luatexcn_content_font_name_tl
    { \ApplyAutoFont }
}

\ExplSyntaxOff
\pagestyle{plain}
\endinput
