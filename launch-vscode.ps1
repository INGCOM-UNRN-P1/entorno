# launch-vscode.ps1 - Lanzador de VS Code con entorno portable

$ErrorActionPreference = "Stop"

$portableRoot = $PSScriptRoot
$homeDir = Join-Path $portableRoot "home"
$vscodeDir = Join-Path $portableRoot "vscode"
$codeExe = Join-Path $vscodeDir "Code.exe"

# Asegurar existencia de HOME portable
if (-not (Test-Path $homeDir)) {
    New-Item -ItemType Directory -Path $homeDir | Out-Null
}

# Inyectar variables de entorno de sesión
$env:HOME = $homeDir
$env:MSYSTEM = "CLANG64"
$env:CHERE_INVOKING = "1"

# Prepend de paths de MSYS2 y Clang a la sesión de VS Code
$clangPath = Join-Path $portableRoot "msys64\clang64\bin"
$usrPath = Join-Path $portableRoot "msys64\usr\bin"
$env:PATH = "$clangPath;$usrPath;$env:PATH"

# Validar existencia de VS Code
if (-not (Test-Path $codeExe)) {
    Write-Error "No se encuentra VS Code. Corré 'powershell -File setup.ps1' para instalarlo."
    return
}

# Lanzar VS Code heredando el ambiente
Start-Process -FilePath $codeExe -ArgumentList $args -NoNewWindow
