-- cn_vertical.lua
-- Chinese vertical typesetting module for LuaTeX
-- Uses native LuaTeX 'dir' primitives for RTT (Right-to-Left Top-to-Bottom) layout.

-- Create module namespace
cn_vertical = cn_vertical or {}

-- Function to typeset text in vertical mode with RTT direction
-- This supports line breaking and RTL column flow.
--
-- @param text The text content to typeset.
-- @param height (string) The vertical height (tex dimension), e.g. "300pt". Default "300pt".
-- @param col_spacing (string) The dimension for baselineskip (column spacing), e.g. "20pt". Default nil (use current).
-- @param char_spacing (number) The LetterSpace amount, e.g. 10. Default 0.
function cn_vertical.vertical_rtt(text, height, col_spacing, char_spacing)
    -- RTT:
    --   Text flow: Top-to-Bottom
    --   Line progression: Right-to-Left
    
    -- Default to calculating remaining page height if not specified
    -- \pagegoal is the target height of the current page.
    -- \pagetotal is the accumulated height of the current page.
    -- If \pagegoal is maxdimen (fresh page), use \textheight.
    -- Subtract 2\baselineskip as safety margin.
    local default_height = "\\dimexpr\\ifdim\\pagegoal=\\maxdimen\\textheight\\else\\pagegoal\\fi-\\pagetotal-2\\baselineskip\\relax"
    
    local vertical_height = (height and height ~= "") and height or default_height
    local c_spacing = tonumber(char_spacing) or 0
    
    -- Preprocess text:
    -- 2. Insert break points and spacing between characters
    -- Heuristic: Assume characters > 128 are CJK/multibyte.
    -- Interpret char_spacing (int) as percentage of em (classic tracking behavior).
    local spacing_skip = nil
    if c_spacing > 0 then
        -- e.g. 20 -> 0.2em
        spacing_skip = string.format("%.2fem", c_spacing / 100)
    end
    
    local processed_text = ""
    for p, c in utf8.codes(text) do
        local char = utf8.char(c)
        processed_text = processed_text .. char
        
        -- Apply spacing (kern) after each char (we can be loose about the last char)
        if spacing_skip then
            processed_text = processed_text .. "\\kern " .. spacing_skip .. " "
        end
        
        -- If codepoint is > 128 (non-ASCII), allow break after it
        if c > 128 then
            processed_text = processed_text .. "\\allowbreak "
        end
    end
    
    -- tex.print("\\par") -- Moved to sty file
    -- Align to right
    tex.print("\\hbox to \\hsize{\\hfill")
    -- Use a vbox with RTT direction
    tex.print("\\vbox dir RTT {")
    tex.print("\\hsize=" .. vertical_height) 
    
    -- Apply column spacing if provided
    if col_spacing and col_spacing ~= "" then
        tex.print("\\baselineskip=" .. col_spacing)
    end
    
    -- Note: Manual spacing injection replaces LetterSpace feature
    
    tex.print("\\pardir RTT \\textdir RTT")
    tex.print("\\noindent " .. processed_text)
    tex.print("}") -- end vbox
    tex.print("}") -- end hbox
    tex.print("\\par")
end

-- Return module
return cn_vertical
