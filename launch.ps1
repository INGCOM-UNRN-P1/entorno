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
        if (-not ($homeDirName -match "^[a-zA-Z0-9_][a-zA-Z0-9_-]*$")) {
            $homeDirName = "home"
        }
    }
}

$homeDir = Join-Path $portableRoot $homeDirName
$msysDir = Join-Path $portableRoot "msys64"
$wezDir  = Join-Path $portableRoot "wezterm"
$wezExe  = Join-Path $wezDir "wezterm.exe"
$bashPath = Join-Path $msysDir "usr\bin\bash.exe"

# Asegurar existencia del HOME portable y sus archivos de inicio (skel)
if (-not (Test-Path $homeDir)) {
    New-Item -ItemType Directory -Path $homeDir | Out-Null
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

$bashProfilePath = Join-Path $homeDir ".bash_profile"
if (-not (Test-Path $bashProfilePath)) {
    $bashProfileContent = @'
if [ -f "${HOME}/.bashrc" ] ; then
  source "${HOME}/.bashrc"
fi
'@
    [System.IO.File]::WriteAllText($bashProfilePath, $bashProfileContent, $utf8NoBom)
}

$bashrcPath = Join-Path $homeDir ".bashrc"
if (-not (Test-Path $bashrcPath)) {
    $bashrcContent = @'
# .bashrc
# Aquí podés agregar tus alias y funciones personalizadas.

# Agregar bin portable al PATH convirtiendo la ruta a formato Unix
if [ -n "$PORTABLE_ROOT" ]; then
    UNIX_ROOT=$(cygpath -u "$PORTABLE_ROOT")
    export PATH="${UNIX_ROOT}bin:${UNIX_ROOT}msys64/clang64/bin:${UNIX_ROOT}msys64/usr/bin:${PATH}"
fi
'@
    [System.IO.File]::WriteAllText($bashrcPath, $bashrcContent, $utf8NoBom)
}

# Inyectar variables de entorno de sesión
$env:PORTABLE_ROOT = $portableRoot
$env:HOME = $homeDir
$env:MSYSTEM = "CLANG64"
$env:CHERE_INVOKING = "1"
$env:LANG = "es_AR.UTF-8"
$wezConfigPath = Join-Path $portableRoot "wezterm.lua"
$env:WEZTERM_CONFIG_FILE = $wezConfigPath

# Sanitizar y ajustar wezterm.lua
if (Test-Path $wezConfigPath) {
    $content = [System.IO.File]::ReadAllText($wezConfigPath, [System.Text.Encoding]::UTF8)
    
    # Sanitizar secuencias de bytes corruptas (doble codificación)
    $content = $content -replace "raÃ\xad z|raÃ\xad|ra\xc3\xad z|raíz", "raiz"
    $content = $content -replace "EstÃ©tica|Est\xc3\xa9tica|Estética", "Estetica"
    $content = $content -replace "PrÃ©mium|Pr\xc3\xa9mium|Premium", "Premium"
    
    # Corregir sufijo de ruta PORTABLE_ROOT
    if ($content -notmatch 'portable_root:match') {
        $replacement = @'
local portable_root = wezterm.config_dir:gsub("[\\/]+", "/")
if not portable_root:match('/$') then
  portable_root = portable_root .. '/'
end
'@
        $content = $content -replace 'local portable_root = wezterm\.config_dir:gsub\([^)]+\)', $replacement
    }
    
    # Reemplazo de dependencias de entorno
    $content = $content -replace 'os\.getenv\("PORTABLE_ROOT"\)', 'wezterm.config_dir'
    $content = $content -replace 'os\.getenv\("HOME"\)', ("portable_root .. `"" + $homeDirName + "`"")
    
    # Inyectar default_cwd
    if ($content -notmatch 'config\.default_cwd\s*=') {
        $content = $content -replace '(local home_dir = [^\r\n]+)', "`$1`r`nconfig.default_cwd = home_dir"
    }

    # Inyectar PATH personalizado a WezTerm
    if ($content -notmatch 'local custom_path\s*=') {
        $pathRepl = @'
if path_env then path_env = path_env:gsub("[\\/]+", "/") else path_env = "" end

local custom_path = portable_root .. "bin;" .. portable_root .. "msys64/clang64/bin;" .. portable_root .. "msys64/usr/bin;" .. path_env
'@
        $content = $content -replace '(?s)if path_env then path_env = path_env:gsub\([^)]+\) end', $pathRepl
        $content = $content -replace 'PATH = path_env', 'PATH = custom_path'
    }
    
    # Inyectar herencia y raíz explícita a MSYS2
    if ($content -notmatch 'MSYS2_PATH_TYPE\s*=') {
        $content = $content -replace 'MSYSTEM\s*=\s*"CLANG64",', "`$0`r`n  MSYS2_PATH_TYPE = `"inherit`",`r`n  PORTABLE_ROOT = portable_root,"
    }
    
    [System.IO.File]::WriteAllText($wezConfigPath, $content, $utf8NoBom)
}

# Agregar scripts internos, compilador y userland de MSYS2 al Path
$binPath   = Join-Path $portableRoot "bin"
$clangPath = Join-Path $portableRoot "msys64\clang64\bin"
$gccPath   = Join-Path $portableRoot "msys64\mingw64\bin"
$usrPath   = Join-Path $portableRoot "msys64\usr\bin"
$env:PATH  = "$binPath;$clangPath;$gccPath;$usrPath;$env:PATH"

# Variables específicas del Toolchain de C/C++
$env:GCC_EXEC_PREFIX    = "$gccPath\"
$env:LIBRARY_PATH       = $gccPath
$env:C_INCLUDE_PATH     = Join-Path $gccPath "include"
$env:CPLUS_INCLUDE_PATH = Join-Path $gccPath "include\c++"

$env:CC  = "gcc"
$env:CXX = "g++"
$env:AR  = "ar"
$env:AS  = "as"
$env:LD  = "ld"
$env:CPP = "cpp"
$env:CFLAGS  = "-O2 -Wall"
$env:LDFLAGS = ""
$env:PKG_CONFIG_PATH   = "$(Join-Path $portableRoot 'msys64\clang64\lib\pkgconfig');$(Join-Path $portableRoot 'msys64\usr\lib\pkgconfig');$env:PKG_CONFIG_PATH"
$env:CMAKE_PREFIX_PATH = "$(Join-Path $portableRoot 'msys64\clang64');$(Join-Path $portableRoot 'msys64\usr');$env:CMAKE_PREFIX_PATH"

# Variables de entorno para integración
$env:VSCODE_ROOT  = Join-Path $portableRoot "vscode"
$env:WEZTERM_ROOT = $wezDir

# Autocorrección estructural para WezTerm (aplanado de directorios)
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
