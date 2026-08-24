# launch-vscode.ps1 - Lanzador de VS Code con entorno portable

$ErrorActionPreference = "Stop"

$portableRoot = $PSScriptRoot

# Lógica compartida con launch.ps1 (advertencia de ruta, .env, sesión)
Import-Module (Join-Path $portableRoot "env.common.psm1") -Force

# Advertencia temprana ante espacios, caracteres no ASCII o carpetas sincronizadas
$infoRuta = Test-ConflictivePath -Path $portableRoot
if ($infoRuta.IsConflictive) {
    Show-PathWarning -Path $portableRoot
}

# Cargar configuración de directorio HOME e inyectar la sesión portable común
$homeDirName = Get-PortableHomeName -PortableRoot $portableRoot
$null = Set-PortableSession -PortableRoot $portableRoot -HomeDirName $homeDirName

$vscodeDir = Join-Path $portableRoot "vscode"
$codeExe = Join-Path $vscodeDir "Code.exe"

# Validar existencia de VS Code
if (-not (Test-Path $codeExe)) {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show("No se encuentra la instalación de VS Code en la ruta:`n$vscodeDir`n`nPor favor, ejecutá setup.ps1 primero para instalar el entorno completo.", "Error - Lanzador Portable", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    return
}

# Configurar la ruta del compilador en settings.json de VS Code (parcheo quirúrgico)
$null = Set-VsCodeCompilerSettings -PortableRoot $portableRoot -VscodeDir $vscodeDir

# Lanzar VS Code heredando el ambiente
if ($args) {
    Start-Process -FilePath $codeExe -ArgumentList $args
} else {
    Start-Process -FilePath $codeExe
}
