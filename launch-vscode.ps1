# launch-vscode.ps1 - Lanzador de VS Code con entorno portable

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
$vscodeDir = Join-Path $portableRoot "vscode"
$codeExe = Join-Path $vscodeDir "Code.exe"

# Asegurar existencia de HOME portable
if (-not (Test-Path $homeDir)) {
    New-Item -ItemType Directory -Path $homeDir | Out-Null
}

# Inyectar variables de entorno de sesión
$env:HOME = $homeDir
$env:MSYSTEM = "UCRT64"
$env:CHERE_INVOKING = "1"

# Prepend de paths de MSYS2 y GCC a la sesión de VS Code
$gccPath = Join-Path $portableRoot "msys64\ucrt64\bin"
$usrPath = Join-Path $portableRoot "msys64\usr\bin"
$env:PATH = "$gccPath;$usrPath;$env:PATH"

# Validar existencia de VS Code
if (-not (Test-Path $codeExe)) {
    Write-Error "No se encuentra VS Code. Corré 'powershell -File setup.ps1' para instalarlo."
    return
}

# Lanzar VS Code heredando el ambiente
Start-Process -FilePath $codeExe -ArgumentList $args -NoNewWindow
