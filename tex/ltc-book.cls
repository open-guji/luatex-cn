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
\ProvidesExplClass {ltc-book} {2026/01/31} {0.2.1} {Chinese Vertical Book Class}

\tl_new:N \l_luatexcn_book_initial_template_tl

\keys_define:nn { luatexcn / book / options }
  {
    unknown .code:n =
      {
        \tl_set_eq:NN \l_tmpa_tl \l_keys_key_tl
        % Look for config file: configs/luatex-cn-book-<name>.cfg
        \file_if_exist:nTF { configs/luatex-cn-book- \l_tmpa_tl .cfg }
          {
            \tl_set_eq:NN \l_luatexcn_book_initial_template_tl \l_tmpa_tl
          }
          {
            \PassOptionsToClass { \l_tmpa_tl } { article }
          }
      }
  }

\ProcessKeysOptions { luatexcn / book / options }

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
\RequirePackage{luatex-cn-core}

% 3. Key-Value Configuration System
\ExplSyntaxOn

\keys_define:nn { luatexcn / book }
  {
    % Page geometry - modern book defaults (A5-ish)






    % No border by default for modern books




    unknown .code:n = { \keys_set:nx { luatexcn / content } { \l_keys_key_tl = { #1 } } },
  }

% 4. Geometry setup



\NewDocumentCommand{\bookSetup}{ +m }
  {
    \keys_set:nn { luatexcn / page } { #1 }
    \keys_set:nn { luatexcn / book } { #1 }
    \luatexcn_apply_geometry:
  }

% Load default configuration
\InputIfFileExists{configs/luatex-cn-book-default.cfg}{}{
  \PackageWarning{luatex-cn-book}{Default config not found}
}



% 5. Main content environment
\NewEnviron{ltc-book-content}[1][]{%
    \clearpage
    \group_begin:
    \keys_set:nn { luatexcn / book } { #1 }

    % Font selection logic
    \tl_if_empty:NF \l__luatexcn_content_font_name_tl
      {
        \tl_if_empty:NTF \l__luatexcn_content_font_features_tl
          {
            % No features specified, use default for CJK vertical
            \exp_args:NV \setmainfont \l__luatexcn_content_font_name_tl [RawFeature={+vert,+vrt2}, CharacterWidth=Full]
          }
          {
            \exp_args:NV \setmainfont \l__luatexcn_content_font_name_tl [\l__luatexcn_content_font_features_tl]
          }
      }

    \fontsize{\l__luatexcn_content_font_size_tl}{\l__luatexcn_content_line_spacing_tl}\selectfont
    
    % Configure vertical module
    \bool_if:NTF \l__luatexcn_content_border_bool 
      { \keys_set:nn { luatexcn / vertical } { border=true } } 
      { \keys_set:nn { luatexcn / vertical } { border=false } }
    
    \dim_zero:N \topskip
    \dim_zero:N \parskip
    \dim_zero:N \parindent

    \tl_if_empty:NT \l__luatexcn_content_height_tl
      {
        \tl_set:Nx \l__luatexcn_content_height_tl { \dim_eval:n { \l__luatexcn_page_paper_height_tl - \l__luatexcn_page_margin_top_tl - \l__luatexcn_page_margin_bottom_tl } }
      }


    \luatexcn_apply_geometry:
    \nointerlineskip
    \__luatexcn_content_process_grid:n { \BODY }
    \group_end:
    \clearpage
}

% 6. Apply initial template if specified
\tl_if_empty:NF \l_luatexcn_book_initial_template_tl
  {
    \keys_set:nx { luatexcn / book } { template = \l_luatexcn_book_initial_template_tl }
  }


\pagestyle{plain}

% Environment Aliases (CJK support)
\NewEnvironmentCopy{正文}{ltc-book-content}

% Apply auto-detected font if no font-name is set
\AtEndOfClass{
  \tl_if_empty:NT \l__luatexcn_content_font_name_tl
    {
      \ApplyAutoFont
    }
}
\ExplSyntaxOff%
%
\endinput%
