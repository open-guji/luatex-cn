# 纯英文版，避免编码乱码导致语法错误
$extensions = "*.dart", "*.yaml", "*.tex", "*.html", "*.txt", "*.md", "*.json"

Get-ChildItem -Recurse -File | ForEach-Object {
    Write-Host "Checking: $($_.Name)" -ForegroundColor Gray # 打印正在检查的文件
    $filePath = $_.FullName
    $bytes = Get-Content $filePath -Encoding Byte -TotalCount 3
    
    if ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        Write-Host "Found and removing BOM from: $filePath" -ForegroundColor Cyan
        $content = [System.IO.File]::ReadAllText($filePath)
        $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($filePath, $content, $Utf8NoBom)
    }
}
Write-Host "Task Completed!" -ForegroundColor Green
