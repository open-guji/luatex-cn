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

% 3. Page Geometry - Will be applied dynamically via template
% Default values stored in key-value system below

% 4. Key-Value Configuration System (expl3)
\ExplSyntaxOn

\keys_define:nn { guji }
  {
    % Page geometry settings (can be overridden by templates)
    paper-width .tl_set:N = \l_guji_paper_width_tl,
    paper-width .initial:n = 1136pt,

    paper-height .tl_set:N = \l_guji_paper_height_tl,
    paper-height .initial:n = 894.6pt,

    margin-top .tl_set:N = \l_guji_margin_top_tl,
    margin-top .initial:n = 148pt,

    margin-bottom .tl_set:N = \l_guji_margin_bottom_tl,
    margin-bottom .initial:n = 114pt,

    margin-left .tl_set:N = \l_guji_margin_left_tl,
    margin-left .initial:n = 106pt,

    margin-right .tl_set:N = \l_guji_margin_right_tl,
    margin-right .initial:n = 106pt,

    % Grid and font settings
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
    \fi
  }

% Initialize with defaults at end of preamble hook or immediately?
% Geometry package should be loaded.
% Let's apply defaults immediately so they are active.
\geometry{
    paperwidth=1136pt,
    paperheight=894.6pt,
    top=148pt,    
    bottom=114pt, 
    left=106pt,
    right=106pt,
    footskip=15mm
}

\NewDocumentCommand{\gujiSetup}{ +m }
  {
    \tl_set:Nn \l_tmpa_tl { #1 }
    \tl_replace_all:Nnn \l_tmpa_tl { \par } { }
    \keys_set:nV { guji } \l_tmpa_tl
    % Apply geometry updates
    \__guji_apply_geometry:
  }

% Command to define templates
\NewDocumentCommand{\defineGujiTemplate}{ m +m }
  {
    \keys_define:nn { guji / templates }
      {
        #1 .code:n = { \keys_set:nn { guji } { #2 } }
      }
  }

% 6. Load Common Templates (if any)
\InputIfFileExists{guji_common.def}{}{}

% 7. Font Configuration
\setmainfont{TW-Kai}[
    RawFeature={+vert,+vrt2},
    CharacterWidth=Full
]

% 8. High-level Interface
\NewEnviron{guji-content}[1][]{%
    \clearpage
    \group_begin:
    \keys_set:nn { guji } { #1 }
    \fontsize{\l_guji_font_size_tl}{\l_guji_line_spacing_tl}\selectfont
    \bool_if:NTF \l_guji_border_bool { \keys_set:nn { cn_vertical } { border=true } } { \keys_set:nn { cn_vertical } { border=false } }
    \bool_if:NTF \l_guji_debug_bool { \keys_set:nn { cn_vertical } { debug=true } } { \keys_set:nn { cn_vertical } { debug=false } }
    
    % Update geometry for this environment
    \__guji_apply_geometry:

    \keys_set:nn { cn_vertical }
      {
        height = \l_guji_height_tl,
        grid-width = \l_guji_grid_width_tl,
        grid-height = \l_guji_grid_height_tl
      }
    \__cn_vertical_process_grid:n { \BODY }
    \group_end:
    \clearpage
    % Restore geometry if needed? \restoregeometry resets to preamble settings.
    \restoregeometry
}

\ExplSyntaxOff

% 8. Remove page numbers by default
\pagestyle{empty}

\endinput
