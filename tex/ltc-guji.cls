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

% ltc-guji.cls - Legacy wrapper. Use guji.cls instead.

\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{ltc-guji}[2026/02/18 0.2.9 Legacy wrapper for guji.cls]

% Forward all options to guji.cls
\DeclareOption*{\PassOptionsToClass{\CurrentOption}{guji}}
\ProcessOptions\relax
\LoadClass{guji}
\endinput
