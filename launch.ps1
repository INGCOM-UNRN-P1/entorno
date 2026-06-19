# launch.ps1 - Lanzador del entorno portable en PowerShell

$ErrorActionPreference = "Stop"

$portableRoot = $PSScriptRoot
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
