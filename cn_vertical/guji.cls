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

    outer-border .bool_set:N = \l_guji_outer_border_bool,
    outer-border .initial:n = false,

    outer-border-thickness .tl_set:N = \l_guji_outer_border_thickness_tl,
    outer-border-thickness .initial:n = 3pt,

    outer-border-sep .tl_set:N = \l_guji_outer_border_sep_tl,
    outer-border-sep .initial:n = 2pt,

    debug .bool_set:N = \l_guji_debug_bool,
    debug .initial:n = false,

    vertical-align .tl_set:N = \l_guji_valign_tl,
    vertical-align .initial:n = center,

    border-padding-top .tl_set:N = \l_guji_border_padding_top_tl,
    border-padding-top .initial:n = 0.2em,

    border-padding-bottom .tl_set:N = \l_guji_border_padding_bottom_tl,
    border-padding-bottom .initial:n = 0.2em,

    border-thickness .tl_set:N = \l_guji_border_thickness_tl,
    border-thickness .initial:n = 0.5pt,

    n-column .int_set:N = \l_guji_n_column_int,
    n-column .initial:n = 8,

    border-color .tl_set:N = \l_guji_border_color_tl,
    border-color .initial:n = {black},

    background-color .tl_set:N = \l_guji_background_color_tl,
    background-color .initial:n = {},

    font-color .tl_set:N = \l_guji_font_color_tl,
    font-color .initial:n = {black},

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
      \setlength{\topskip}{0pt}
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
    \bool_if:NTF \l_guji_outer_border_bool { \keys_set:nn { cn_vertical } { outer-border=true } } { \keys_set:nn { cn_vertical } { outer-border=false } }
    \bool_if:NTF \l_guji_debug_bool { \keys_set:nn { cn_vertical } { debug=true } } { \keys_set:nn { cn_vertical } { debug=false } }
    % Zero out vertical skips for exact grid layout
    \setlength{\topskip}{0pt}
    \setlength{\parskip}{0pt}
    \setlength{\partopsep}{0pt}
    
    % --- Auto-Correction Logic ---
    % Calculate exact fit for grid to avoid blank pages and overflow
    % 1. Get available space from defined margins
    \dim_set:Nn \l_tmpa_dim { \l_guji_paper_height_tl }
    \dim_sub:Nn \l_tmpa_dim { \l_guji_margin_top_tl }
    \dim_sub:Nn \l_tmpa_dim { \l_guji_margin_bottom_tl }
    % \l_tmpa_dim is now Available Height

    % 2. Calculate border overhead if border is enabled
    % We now have top and bottom padding. Default is 0.1em each.
    \dim_set:Nn \l_tmpb_dim { 0pt }
    \bool_if:NT \l_guji_border_bool {
      % Standard column border overhead = top padding + bottom padding + thickness + safety
      \dim_set:Nn \l_tmpb_dim { \l_guji_border_padding_top_tl + \l_guji_border_padding_bottom_tl + \l_guji_border_thickness_tl + 0.4pt }
    }
    % --- NEW: Add extra overhead for outer-border ---
    \bool_if:NT \l_guji_outer_border_bool {
      % We added internal padding (sep) + thickness.
      % The overhead is (sep + thickness) * 2.
      \dim_add:Nn \l_tmpb_dim { (\l_guji_outer_border_sep_tl + \l_guji_outer_border_thickness_tl) * 2 }
    }
    \dim_sub:Nn \l_tmpa_dim { \l_tmpb_dim }
    % \l_tmpa_dim is now Available Height minus border overhead

    % 3. Calculate max rows fitting in this space using FLOOR
    \int_set:Nn \l_tmpa_int { \dim_to_decimal_in_sp:n { \l_tmpa_dim } }
    \int_set:Nn \l_tmpb_int { \dim_to_decimal_in_sp:n { \l_guji_grid_height_tl } }
    \int_set:Nn \l_tmpa_int { \l_tmpa_int / \l_tmpb_int }

    % 4. Calculate heights
    % UsedHeight = Rows * GridHeight (This is the height passed to cn_vertical)
    % We use \l_tmpa_dim to store the result
    \dim_set:Nn \l_tmpa_dim { \l_guji_grid_height_tl * \l_tmpa_int }
    \tl_set:Nx \l_guji_height_tl { \dim_use:N \l_tmpa_dim } 
    
    % TotalHeight = UsedHeight + BorderOverhead + Safety (This is the \textheight)
    % We use \l_tmpb_dim to store the result
    \dim_set:Nn \l_tmpb_dim { \l_tmpa_dim + \l_tmpb_dim + 2pt }

    % 5. Adjust Margins
    % We adjust top margin to preserve the bottom margin
    \tl_set:Nx \l_guji_margin_top_tl {
      \dim_eval:n { \l_guji_paper_height_tl - \l_guji_margin_bottom_tl - \l_tmpb_dim }
    }

    % Log for debugging
    \iow_term:x { Guji~Auto-Layout:~Rows=\int_use:N \l_tmpa_int,~TextHeight=\dim_use:N \l_tmpb_dim,~TopMargin=\l_guji_margin_top_tl }

    % Update geometry for this environment
    \__guji_apply_geometry:
    
    % Zap all vertical spacing
    \setlength{\topskip}{0pt}
    \setlength{\parskip}{0pt}
    \setlength{\partopsep}{0pt}
    \setlength{\topsep}{0pt}
    \setlength{\itemsep}{0pt}
    \setlength{\parsep}{0pt}
    \setlength{\baselineskip}{0pt}
    \setlength{\lineskip}{0pt}
    \setlength{\lineskiplimit}{0pt}
    \parindent=0pt

    \keys_set:nn { cn_vertical }
      {
        height = \l_guji_height_tl,
        grid-width = \l_guji_grid_width_tl,
        grid-height = \l_guji_grid_height_tl,
        vertical-align = \l_guji_valign_tl,
        border-thickness = \l_guji_border_thickness_tl,
        border-padding-top = \l_guji_border_padding_top_tl,
        border-padding-bottom = \l_guji_border_padding_bottom_tl,
        outer-border-thickness = \l_guji_outer_border_thickness_tl,
        outer-border-sep = \l_guji_outer_border_sep_tl,
        n-column = \int_use:N \l_guji_n_column_int,
        border-color = { \l_guji_border_color_tl },
        background-color = { \l_guji_background_color_tl },
        font-color = { \l_guji_font_color_tl },
        paper-width = \l_guji_paper_width_tl,
        paper-height = \l_guji_paper_height_tl,
        margin-top = \l_guji_margin_top_tl,
        margin-bottom = \l_guji_margin_bottom_tl,
        margin-left = \l_guji_margin_left_tl,
        margin-right = \l_guji_margin_right_tl
      }
    \nointerlineskip
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
