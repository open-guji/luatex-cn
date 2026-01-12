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

    vertical-align .tl_set:N = \l_guji_valign_tl,
    vertical-align .initial:n = center,

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
    % Border adds: border_padding at bottom
    % Also reserve small space for border line width (approximately 0.4bp ≈ 0.56pt)
    \dim_set:Nn \l_tmpb_dim { 0pt }
    \bool_if:NT \l_guji_border_bool {
      % Get border-padding from cn_vertical defaults (0.2em typically)
      % For safety, reserve approximately 1pt extra for border overhead
      \dim_set:Nn \l_tmpb_dim { 1pt }
    }
    \dim_sub:Nn \l_tmpa_dim { \l_tmpb_dim }
    % \l_tmpa_dim is now Available Height minus border overhead

    % 3. Calculate max rows fitting in this space using FLOOR (向下取整)
    % Use integer division for floor operation instead of dim_ratio (which rounds)
    % Convert dimensions to sp (scaled points) for integer division
    \int_set:Nn \l_tmpa_int { \dim_to_decimal_in_sp:n { \l_tmpa_dim } }
    \int_set:Nn \l_tmpb_int { \dim_to_decimal_in_sp:n { \l_guji_grid_height_tl } }
    % Floor division: rows = floor(available_height / grid_height)
    \int_set:Nn \l_tmpa_int { \l_tmpa_int / \l_tmpb_int }

    % 4. Calculate Used Height = Rows * GridHeight
    % Store in l_guji_height_tl directly (as a dimension expression)
    \tl_set:Nx \l_guji_height_tl { \dim_eval:n { \l_guji_grid_height_tl * \l_tmpa_int } }

    % 5. Calculate Remainder = Available - Used
    % Apply Remainder and BorderOverhead to Top Margin (Push grid down slightly)
    \tl_set:Nx \l_guji_margin_top_tl {
      \dim_eval:n { \l_guji_margin_top_tl + \l_tmpa_dim - \l_guji_height_tl + \l_tmpb_dim }
    }

    % Log for debugging
    \iow_term:x { Guji~Auto-Layout:~Rows=\int_use:N \l_tmpa_int,~UsedHeight=\l_guji_height_tl,~BorderOverhead=\dim_use:N \l_tmpb_dim }

    % Update geometry for this environment
    \__guji_apply_geometry:

    \keys_set:nn { cn_vertical }
      {
        height = \l_guji_height_tl,
        grid-width = \l_guji_grid_width_tl,
        grid-height = \l_guji_grid_height_tl,
        vertical-align = \l_guji_valign_tl
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
