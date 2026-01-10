% guji.cls
% A LaTeX document class for ancient Chinese book typesetting.
% Developed for LuaTeX

\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{guji}[2026/01/10 v0.3.0 Ancient Chinese Book Class (Template Support)]

% 1. Options Handling
\DeclareOption*{\PassOptionsToClass{\CurrentOption}{article}}
\ProcessOptions\relax
\LoadClass{article}

% 2. Core Dependencies
\RequirePackage{geometry}
\RequirePackage{fontspec}
\RequirePackage{environ}
\RequirePackage{cn_vertical}
\RequirePackage{expl3}
\RequirePackage{xparse}

% 3. Default Page Layout (Traditional Ancient Book Two-Page Spread)
\geometry{
    paperwidth=360mm,
    paperheight=260mm,
    top=20mm,    % Heaven Margin (天头)
    bottom=20mm, % Earth Margin (地脚)
    left=30mm,
    right=30mm,
    footskip=15mm
}

% 4. Key-Value Configuration System (expl3)
\ExplSyntaxOn

\keys_define:nn { guji }
  {
    font-size .tl_set:N = \l_guji_font_size_tl,
    font-size .initial:n = 36pt,
    
    line-spacing .tl_set:N = \l_guji_line_spacing_tl,
    line-spacing .initial:n = 36pt,

    grid-width .tl_set:N = \l_guji_grid_width_tl,
    grid-width .initial:n = 52pt,

    grid-height .tl_set:N = \l_guji_grid_height_tl,
    grid-height .initial:n = 45pt,

    height .tl_set:N = \l_guji_height_tl,
    height .initial:n = 600pt,

    border .bool_set:N = \l_guji_border_bool,
    border .initial:n = true,

    debug .bool_set:N = \l_guji_debug_bool,
    debug .initial:n = false,

    template .code:n = {
      \InputIfFileExists{#1.guji}{}{
        % Fallback to checking defined templates in guji / templates namespace
        \keys_set:nn { guji / templates } { #1 }
      }
    }
  }

% Command to set guji options
\NewDocumentCommand{\gujiSetup}{ m }
  {
    \keys_set:nn { guji } { #1 }
  }

% Command to define templates
\NewDocumentCommand{\defineGujiTemplate}{ m m }
  {
    \keys_define:nn { guji / templates }
      {
        #1 .code:n = { \keys_set:nn { guji } { #2 } }
      }
  }

% 5. Load Common Templates (if any)
\InputIfFileExists{guji_common.def}{}{}

% 6. Font Configuration
\setmainfont{TW-Kai}[
    RawFeature={+vert,+vrt2},
    CharacterWidth=Full
]

% 7. High-level Interface
\NewEnviron{guji-content}[1][]{%
    \clearpage
    \group_begin:
    \keys_set:nn { guji } { #1 }
    \fontsize{\l_guji_font_size_tl}{\l_guji_line_spacing_tl}\selectfont
    \bool_if:NTF \l_guji_border_bool { \keys_set:nn { cn_vertical } { border=true } } { \keys_set:nn { cn_vertical } { border=false } }
    \bool_if:NTF \l_guji_debug_bool { \keys_set:nn { cn_vertical } { debug=true } } { \keys_set:nn { cn_vertical } { debug=false } }
    \keys_set:nn { cn_vertical }
      {
        height = \l_guji_height_tl,
        grid-width = \l_guji_grid_width_tl,
        grid-height = \l_guji_grid_height_tl
      }
    \__cn_vertical_process_grid:n { \BODY }
    \group_end:
    \clearpage
}

\ExplSyntaxOff

% 8. Remove page numbers by default
\pagestyle{empty}

\endinput
