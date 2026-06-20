$str = "MSYSTEM = `"CLANG64`","
$str2 = $str -replace 'MSYSTEM\s*=\s*"CLANG64",', "`$0`r`n  MSYS2_PATH_TYPE = `"inherit`","
Write-Host "Result: $str2"
