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

$homeDir = Join-Path $portableRoot "home"
$msysDir = Join-Path $portableRoot "msys64"
$bashPath = Join-Path $msysDir "usr\bin\bash.exe"

# Asegurar existencia del HOME portable
if (-not (Test-Path $homeDir)) {
    New-Item -ItemType Directory -Path $homeDir | Out-Null
}

# Inyectar variables de entorno de sesión
$env:HOME = $homeDir
$env:MSYSTEM = "CLANG64"
$env:CHERE_INVOKING = "1"

# Validar existencia de MSYS2
if (-not (Test-Path $bashPath)) {
    Write-Error "No se encuentra MSYS2 en '$msysDir'. Corré 'powershell -File setup.ps1' para instalarlo."
    return
}

# Lanzar bash interactivo
& $bashPath --login -i
