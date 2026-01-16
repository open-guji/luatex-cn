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

% guji.cls - Backward compatibility wrapper
% This file provides backward compatibility for the old class name.
% It simply loads the new luatex-cn-guji.cls with proper naming.

\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{guji}[2026/01/16 v0.3.0 Backward compatibility wrapper for luatex-cn-guji]

% Notify user about the deprecated name
\ClassWarningNoLine{guji}{%
  The class name 'guji' is deprecated.\MessageBreak
  Please use 'luatex-cn-guji' instead.\MessageBreak
  Support for 'guji' will be maintained for compatibility
}

% Pass all options to the real class
\DeclareOption*{\PassOptionsToClass{\CurrentOption}{luatex-cn-guji}}
\ProcessOptions\relax

% Load the actual class
\LoadClass{luatex-cn-guji}

\endinput
