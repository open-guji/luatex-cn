% cvbook.cls
% Chinese Vertical Book - A document class for modern vertical Chinese typesetting
% Developed for LuaTeX

\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{cvbook}[2026/01/15 v1.0.0 Chinese Vertical Book Class]

% 1. Options Handling
\RequirePackage{l3keys2e}
\ExplSyntaxOn
\tl_new:N \l_cvbook_initial_template_tl

\DeclareOption*{
  \tl_set:Nx \l_tmpa_tl { \CurrentOption }
  % Look for config file: configs/<name>.cvbook.cfg
  \file_if_exist:nTF { configs/ \l_tmpa_tl .cvbook.cfg }
    {
      \tl_set_eq:NN \l_cvbook_initial_template_tl \l_tmpa_tl
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
\RequirePackage{vertical}

% 3. Key-Value Configuration System
\ExplSyntaxOn

\keys_define:nn { cvbook }
  {
    % Page geometry - modern book defaults (A5-ish)
    paper-width .tl_set:N = \l_cvbook_paper_width_tl,
    paper-width .initial:n = 148mm,

    paper-height .tl_set:N = \l_cvbook_paper_height_tl,
    paper-height .initial:n = 210mm,

    margin-top .tl_set:N = \l_cvbook_margin_top_tl,
    margin-top .initial:n = 15mm,

    margin-bottom .tl_set:N = \l_cvbook_margin_bottom_tl,
    margin-bottom .initial:n = 30mm,

    margin-left .tl_set:N = \l_cvbook_margin_left_tl,
    margin-left .initial:n = 15mm,

    margin-right .tl_set:N = \l_cvbook_margin_right_tl,
    margin-right .initial:n = 25mm,

    % Grid and font settings
    font-size .tl_set:N = \l_cvbook_font_size_tl,
    font-size .initial:n = 12pt,
    
    line-spacing .tl_set:N = \l_cvbook_line_spacing_tl,
    line-spacing .initial:n = 14pt,

    grid-width .tl_set:N = \l_cvbook_grid_width_tl,
    grid-width .initial:n = 14pt,

    grid-height .tl_set:N = \l_cvbook_grid_height_tl,
    grid-height .initial:n = 14pt,

    height .tl_set:N = \l_cvbook_height_tl,
    height .initial:n = ,

    % No border by default for modern books
    border .bool_set:N = \l_cvbook_border_bool,
    border .initial:n = false,

    border-thickness .tl_set:N = \l_cvbook_border_thickness_tl,
    border-thickness .initial:n = 0.4pt,

    vertical-align .tl_set:N = \l_cvbook_valign_tl,
    vertical-align .initial:n = center,

    n-column .int_set:N = \l_cvbook_n_column_int,
    n-column .initial:n = 0,

    debug .bool_gset:N = \g_cnv_debug_bool,
    debug .initial:n = false,

    template .code:n = {
      \InputIfFileExists{configs/#1.cvbook.cfg}{}{
        \keys_set:nn { cvbook / templates } { #1 }
      }
    },
  }

% 4. Geometry setup
\cs_new:Npn \__cvbook_apply_geometry:
  {
    \geometry{
      paperwidth=\l_cvbook_paper_width_tl,
      paperheight=\l_cvbook_paper_height_tl,
      top=\l_cvbook_margin_top_tl,
      bottom=\l_cvbook_margin_bottom_tl,
      left=\l_cvbook_margin_left_tl,
      right=\l_cvbook_margin_right_tl
    }
  }

% Apply defaults
\geometry{
  paperwidth=148mm,
  paperheight=210mm,
  top=20mm,
  bottom=20mm,
  left=15mm,
  right=15mm
}

\NewDocumentCommand{\cvbookSetup}{ +m }
  {
    \keys_set:nn { cvbook } { #1 }
    \__cvbook_apply_geometry:
  }

% 5. Main content environment
\NewEnviron{cvbook-content}[1][]{%
    \clearpage
    \group_begin:
    \keys_set:nn { cvbook } { #1 }
    \fontsize{\l_cvbook_font_size_tl}{\l_cvbook_line_spacing_tl}\selectfont
    
    % Configure vertical module
    \bool_if:NTF \l_cvbook_border_bool 
      { \keys_set:nn { vertical } { border=true } } 
      { \keys_set:nn { vertical } { border=false } }
    
    \setlength{\topskip}{0pt}
    \setlength{\parskip}{0pt}
    \parindent=0pt

    \tl_if_empty:NT \l_cvbook_height_tl
      {
        \tl_set:Nx \l_cvbook_height_tl { \dim_eval:n { \l_cvbook_paper_height_tl - \l_cvbook_margin_top_tl - \l_cvbook_margin_bottom_tl } }
      }

    \keys_set:nn { vertical }
      {
        height = \l_cvbook_height_tl,
        grid-width = \l_cvbook_grid_width_tl,
        grid-height = \l_cvbook_grid_height_tl,
        vertical-align = \l_cvbook_valign_tl,
        border-thickness = \l_cvbook_border_thickness_tl,
        n-column = \int_use:N \l_cvbook_n_column_int,
        paper-width = \l_cvbook_paper_width_tl,
        paper-height = \l_cvbook_paper_height_tl,
        margin-top = \l_cvbook_margin_top_tl,
        margin-bottom = \l_cvbook_margin_bottom_tl,
        margin-left = \l_cvbook_margin_left_tl,
        margin-right = \l_cvbook_margin_right_tl,
        debug = \bool_if:NTF \g_cnv_debug_bool {true} {false}
      }
    \nointerlineskip
    \__cn_vertical_process_grid:n { \BODY }
    \group_end:
    \clearpage
}

% 6. Apply initial template if specified
\tl_if_empty:NF \l_cvbook_initial_template_tl
  {
    \keys_set:nx { cvbook } { template = \l_cvbook_initial_template_tl }
  }

\ExplSyntaxOff

% 7. Font Configuration (use system default)
\setmainfont{TW-Kai}[
    RawFeature={+vert,+vrt2},
    CharacterWidth=Full
]

\pagestyle{plain}

\endinput
