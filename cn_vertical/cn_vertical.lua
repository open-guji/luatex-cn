-- cn_vertical.lua
-- Chinese vertical typesetting module for LuaTeX
-- Simplified version using TeX-layer vbox layout

-- Create module namespace
cn_vertical = cn_vertical or {}

-- Function to split text into vertical layout
-- Each character is wrapped in an \hbox and stacked vertically in a \vbox
function cn_vertical.split_to_vbox(text)
    tex.print("\\vbox{")
    for i = 1, utf8.len(text) do
        local offset_start = utf8.offset(text, i)
        local offset_end = utf8.offset(text, i+1)
        if offset_start and offset_end then
            local char = text:sub(offset_start, offset_end - 1)
            -- Skip spaces and newlines
            local byte = string.byte(char)
            if byte ~= 32 and byte ~= 10 and byte ~= 13 then
                tex.print("\\hbox{" .. char .. "}")
            end
        end
    end
    tex.print("}")
end

-- Return module
return cn_vertical
