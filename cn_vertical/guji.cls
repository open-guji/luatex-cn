% guji.cls
% A LaTeX document class for ancient Chinese book typesetting.
% Developed for LuaTeX

\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{guji}[2026/01/10 v0.2.0 Ancient Chinese Book Class (Spread Layout)]

% 1. Options Handling
\DeclareOption*{\PassOptionsToClass{\CurrentOption}{article}}
\ProcessOptions\relax
\LoadClass{article}

% 2. Core Dependencies
\RequirePackage{geometry}
\RequirePackage{fontspec}
\RequirePackage{environ}
\RequirePackage{cn_vertical}

% 3. Default Page Layout (Traditional Ancient Book Two-Page Spread)
% 360mm (2x180mm) x 260mm
\geometry{
    paperwidth=360mm,
    paperheight=260mm,
    top=20mm,    % Heaven Margin (天头)
    bottom=20mm, % Earth Margin (地脚)
    left=30mm,
    right=30mm,
    footskip=15mm
}

% 4. Font Configuration
% Default to TW-Kai (Traditional Chinese Kai font) with vertical features
\setmainfont{TW-Kai}[
    RawFeature={+vert,+vrt2},
    CharacterWidth=Full
]

% 5. High-level Interface
% An environment that automatically applies vertical typesetting to its content
% Defaulting to a large font size (24pt) and appropriate grid for the spread.
\NewEnviron{guji-content}[1][]{%
    \clearpage
    \fontsize{36pt}{36pt}\selectfont
    \VerticalRTT[
        height=600pt, % Auto height
        grid-width=52pt, 
        grid-height=45pt, % Tighter than font size for a dense look
        border=true,
        #1
    ]{\BODY}
    \clearpage
}

% 6. Remove page numbers by default for a traditional look
\pagestyle{empty}

\endinput
