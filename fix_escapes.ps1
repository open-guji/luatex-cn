# Fix escaped backslashes in Lua files
$verticalDir = "c:\Users\lisdp\workspace\luatex-cn\src\vertical"
$luaFiles = Get-ChildItem -Path $verticalDir -Filter "*.lua"

Write-Host "Fixing escaped backslashes in $($luaFiles.Count) Lua files..."

foreach ($file in $luaFiles) {
    $content = Get-Content $file.FullName -Raw -Encoding UTF8
    $originalContent = $content
    
    # Fix escaped brackets and parentheses
    $content = $content -replace '\\\.', '.'
    $content = $content -replace "\\\[", "["
    $content = $content -replace "\\\]", "]"
    $content = $content -replace "\\\(", "("
    $content = $content -replace "\\\)", ")"
    $content = $content -replace "\\\\'", "'"
    
    if ($content -ne $originalContent) {
        Set-Content -Path $file.FullName -Value $content -Encoding UTF8 -NoNewline
        Write-Host "Fixed $($file.Name)"
    }
    else {
        Write-Host "No changes needed for $($file.Name)"
    }
}

Write-Host "Done!"
