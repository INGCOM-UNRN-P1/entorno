# launch.ps1 - Lanzador del entorno portable en PowerShell

$ErrorActionPreference = "Stop"

$portableRoot = $PSScriptRoot

# Validar espacios o caracteres no ASCII en la ruta de instalación
$hasSpaces = $portableRoot -match " "
$hasNonAscii = $portableRoot -match "[^\u0000-\u007F]"

if ($hasSpaces -or $hasNonAscii) {
    Write-Host "==========================================================================" -ForegroundColor Yellow
    Write-Host "[ADVERTENCIA] La ruta de instalación contiene caracteres conflictivos:" -ForegroundColor Yellow
    if ($hasSpaces) {
        Write-Host "* Espacios en blanco." -ForegroundColor Yellow
    }
    if ($hasNonAscii) {
        Write-Host "* Caracteres no ASCII (acentos, eñes, etc.)." -ForegroundColor Yellow
    }
    Write-Host "Ruta: '$portableRoot'"
    Write-Host "Esto puede romper herramientas de compilación de C (Make, CMake, etc.)."
    Write-Host "Se recomienda mover el entorno a una ruta simple (Ej: C:\dev\entorno)."
    Write-Host "==========================================================================" -ForegroundColor Yellow
    Write-Host ""
}

# Cargar configuración de directorio HOME
$homeDirName = "home"
$envFile = Join-Path $portableRoot ".env"
if (Test-Path $envFile) {
    $envContent = Get-Content $envFile -Raw
    if ($envContent -match 'HOME_DIR_NAME=(.*)') {
        $homeDirName = $Matches[1].Replace('"', '').Trim()
    }
}

$homeDir = Join-Path $portableRoot $homeDirName
$msysDir = Join-Path $portableRoot "msys64"
$wezDir = Join-Path $portableRoot "wezterm"
$wezExe = Join-Path $wezDir "wezterm.exe"
$bashPath = Join-Path $msysDir "usr\bin\bash.exe"

# Asegurar existencia del HOME portable
if (-not (Test-Path $homeDir)) {
    New-Item -ItemType Directory -Path $homeDir | Out-Null
}

# Inyectar variables de entorno de sesión
$env:PORTABLE_ROOT = $portableRoot
$env:HOME = $homeDir
$env:MSYSTEM = "CLANG64"
$env:CHERE_INVOKING = "1"
$env:LANG = "es_AR.UTF-8"
$wezConfigPath = Join-Path $portableRoot "wezterm.lua"
$env:WEZTERM_CONFIG_FILE = $wezConfigPath

# Asegurar que wezterm.lua esté siempre en UTF-8 sin BOM (evita error de codificación UTF-8 en WezTerm)
if (Test-Path $wezConfigPath) {
    # Leer el archivo con codificación UTF8 explícita para evitar double-encoding en PowerShell 5.1
    $content = [System.IO.File]::ReadAllText($wezConfigPath, [System.Text.Encoding]::UTF8)
    
    # Sanitizar de forma proactiva secuencias corruptas resultantes de conversiones fallidas previas
    $content = $content -replace "raÃ\xad z|raÃ\xad|ra\xc3\xad z|raíz", "raiz"
    $content = $content -replace "EstÃ©tica|Est\xc3\xa9tica|Estética", "Estetica"
    $content = $content -replace "PrÃ©mium|Pr\xc3\xa9mium|Premium", "Premium"
    $content = $content -replace "apariencia|apariencia", "apariencia"
    
    # Corregir la falta de barra diagonal al final de PORTABLE_ROOT en el wezterm.lua del disco del usuario
    if ($content -notmatch 'portable_root:match') {
        $replacement = 'portable_root = portable_root:gsub("\\", "/")' + "`r`n  if not portable_root:match('/$$') then`r`n    portable_root = portable_root .. '/'`r`n  end"
        $content = $content -replace 'portable_root = portable_root:gsub\("[\\]+", "/"\)', $replacement
    }
    
    # Actualizar configuración de wezterm para independizarse de daemons previos y fijar HOME local
    $content = $content -replace 'os\.getenv\("PORTABLE_ROOT"\)', 'wezterm.config_dir'
    $content = $content -replace 'os\.getenv\("HOME"\)', ("portable_root .. `"" + $homeDirName + "`"")
    
    # Configurar default_cwd y custom PATH si no están presentes
    if ($content -notmatch 'config\.default_cwd\s*=') {
        $content = $content -replace '(local home_dir = [^\r\n]+)', "`$1`r`nconfig.default_cwd = home_dir"
    }
    if ($content -notmatch 'local custom_path\s*=') {
        $pathRepl = "if path_env then path_env = path_env:gsub(`"\\\\`", `"/`") else path_env = `"`" end`r`n`r`nlocal custom_path = portable_root .. `"bin;`" .. portable_root .. `"msys64/clang64/bin;`" .. portable_root .. `"msys64/usr/bin;`" .. path_env"
        $content = $content -replace 'if path_env then path_env = path_env:gsub\("\\\\", "/"\) end', $pathRepl
        $content = $content -replace 'PATH = path_env', 'PATH = custom_path'
    }
    
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($wezConfigPath, $content, $utf8NoBom)
}

# Agregar scripts internos, compilador y userland de MSYS2 al Path
$binPath = Join-Path $portableRoot "bin"
$clangPath = Join-Path $portableRoot "msys64\clang64\bin"
$usrPath = Join-Path $portableRoot "msys64\usr\bin"
$env:PATH = "$binPath;$clangPath;$usrPath;$env:PATH"

# Intentar autocorregir estructura si WezTerm quedó en una subcarpeta
if (-not (Test-Path $wezExe) -and (Test-Path $wezDir)) {
    $subDirExe = Get-ChildItem -Path $wezDir -Filter "wezterm.exe" -Recurse | Select-Object -First 1
    if ($subDirExe) {
        $subDir = $subDirExe.Directory
        Write-Host "[INFO] Corrigiendo estructura de carpetas de WezTerm..." -ForegroundColor Cyan
        Get-ChildItem -Path $subDir.FullName | Move-Item -Destination $wezDir -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $subDir.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Lanzar WezTerm o fallar de vuelta a Bash estándar
if (Test-Path $wezExe) {
    Start-Process -FilePath $wezExe -NoNewWindow
} else {
    Write-Host "[INFO] WezTerm no encontrado. Lanzando Bash en consola estándar..." -ForegroundColor Yellow
    if (-not (Test-Path $bashPath)) {
        Write-Error "No se encuentra MSYS2 en '$msysDir'. Corré 'powershell -File setup.ps1' para instalarlo."
        return
    }
    & $bashPath --login -i
}
