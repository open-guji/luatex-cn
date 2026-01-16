# PowerShell script to update all require() paths in vertical/*.lua files
# Maps old module names to new prefixed names

$mappings = @{
    'base_constants'    = 'luatex-cn-vertical-base-constants'
    'base_utils'        = 'luatex-cn-vertical-base-utils'
    'base_hooks'        = 'luatex-cn-vertical-base-hooks'
    'base_text_utils'   = 'luatex-cn-vertical-base-text-utils'
    'core_main'         = 'luatex-cn-vertical-core-main'
    'core_textbox'      = 'luatex-cn-vertical-core-textbox'
    'core_textflow'     = 'luatex-cn-vertical-core-textflow'
    'flatten_nodes'     = 'luatex-cn-vertical-flatten-nodes'
    'layout_grid'       = 'luatex-cn-vertical-layout-grid'
    'render_background' = 'luatex-cn-vertical-render-background'
    'render_border'     = 'luatex-cn-vertical-render-border'
    'render_page'       = 'luatex-cn-vertical-render-page'
    'render_position'   = 'luatex-cn-vertical-render-position'
}

$verticalDir = "c:\Users\lisdp\workspace\luatex-cn\src\vertical"
$luaFiles = Get-ChildItem -Path $verticalDir -Filter "*.lua"

Write-Host "Updating require() paths in $($luaFiles.Count) Lua files..."

foreach ($file in $luaFiles) {
    Write-Host "Processing $($file.Name)..."
    $content = Get-Content $file.FullName -Raw -Encoding UTF8
    $originalContent = $content
    $changed = $false
    
    foreach ($oldName in $mappings.Keys) {
        $newName = $mappings[$oldName]
        
        # Update package.loaded['...'] and require('...')
        $patterns = @(
            "package\.loaded\['$oldName'\]",
            "require\('$oldName'\)"
        )
        
        foreach ($pattern in $patterns) {
            $replacement = $pattern -replace [regex]::Escape($oldName), $newName
            if ($content -match $pattern) {
                $content = $content -replace $pattern, $replacement
                $changed = $true
                Write-Host "  Updated: $oldName -> $newName"
            }
        }
    }
    
    if ($changed) {
        Set-Content -Path $file.FullName -Value $content -Encoding UTF8 -NoNewline
        Write-Host "  Saved changes to $($file.Name)"
    }
    else {
        Write-Host "  No changes needed"
    }
}

Write-Host "Done! All require() paths have been updated."
