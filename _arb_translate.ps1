$arbPath = "D:\NativeTavern\lib\l10n\app_zh.arb"
$transPath = "D:\NativeTavern\_translated.txt"

# 读翻译清单
$translations = @{}
foreach ($line in (Get-Content $transPath -Encoding utf8)) {
    $idx = $line.IndexOf(' ||| ')
    if ($idx -gt 0) {
        $k = $line.Substring(0, $idx).Trim()
        $v = $line.Substring($idx + 5).Trim()
        $translations[$k] = $v
    }
}
Write-Host "读取翻译条目: $($translations.Count) 个"

# 逐行处理 ARB
$lines = Get-Content $arbPath -Encoding utf8
$updated = 0
$out = foreach ($line in $lines) {
    $trimmed = $line.TrimStart()
    $matched = $false
    foreach ($key in $translations.Keys) {
        if ($trimmed.StartsWith('"' + $key + '":')) {
            $indent = $line.Substring(0, $line.Length - $trimmed.Length)
            $comma = ''
            if ($line.TrimEnd().EndsWith(',')) { $comma = ',' }
            $indent + '"' + $key + '": "' + $translations[$key] + '"' + $comma
            $updated++
            $matched = $true
            break
        }
    }
    if (-not $matched) { $line }
}

# 写回 UTF-8 无 BOM
[System.IO.File]::WriteAllLines($arbPath, $out, [System.Text.UTF8Encoding]::new($false))
Write-Host "已更新词条: $updated 条"

# 验证
$verify = Get-Content $arbPath -Raw -Encoding utf8 | ConvertFrom-Json
$remaining = ($verify.PSObject.Properties | Where-Object {
    $_.Name -notmatch '^@' -and $_.Value -is [string] -and
    $_.Value -match '^[\x00-\x7F]+$' -and $_.Value -match '[a-zA-Z]{3}'
}).Count
Write-Host "验证完成,剩余英文值: $remaining 个 (预期约30个品牌/术语,属正常)"