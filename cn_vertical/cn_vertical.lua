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
    
    local vertical_height = (height and height ~= "") and height or "300pt"
    local c_spacing = tonumber(char_spacing) or 0
    
    tex.print("\\par")
    -- Align to right
    tex.print("\\hbox to \\hsize{\\hfill")
    -- Use a vbox with RTT direction
    tex.print("\\vbox dir RTT {")
    tex.print("\\hsize=" .. vertical_height) 
    
    -- Apply column spacing if provided
    if col_spacing and col_spacing ~= "" then
        tex.print("\\baselineskip=" .. col_spacing)
    end
    
    -- Apply character spacing if provided
    if c_spacing > 0 then
        tex.print("\\addfontfeature{LetterSpace=" .. c_spacing .. "}")
    end
    
    tex.print("\\pardir RTT \\textdir RTT")
    tex.print("\\noindent " .. text)
    tex.print("}") -- end vbox
    tex.print("}") -- end hbox
    tex.print("\\par")
end

-- Return module
return cn_vertical
