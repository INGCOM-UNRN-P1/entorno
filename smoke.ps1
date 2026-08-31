# smoke.ps1 - Ejecuta la suite de aceptacion automatizada (bin/smoke.sh) en el bash portable.
$ErrorActionPreference = "Stop"
$portableRoot = $PSScriptRoot
if ([string]::IsNullOrEmpty($portableRoot)) { $portableRoot = (Get-Location).Path }
$bashPath = Join-Path $portableRoot "msys64\usr\bin\bash.exe"
if (-not (Test-Path $bashPath)) {
    Write-Error "No se encontro MSYS2. Ejecuta setup.ps1 primero."
    exit 1
}

$envModule = Join-Path $portableRoot "env.common.psm1"
if (Test-Path $envModule) {
    Import-Module $envModule -Force
    $null = Set-PortableSession -PortableRoot $portableRoot
} else {
    $env:PORTABLE_ROOT = $portableRoot
    $env:HOME = Join-Path $portableRoot "home"
    $env:MSYSTEM = "UCRT64"
    $env:CHERE_INVOKING = "1"
    $binPath = Join-Path $portableRoot "bin"
    $gccPath = Join-Path $portableRoot "msys64\ucrt64\bin"
    $usrPath = Join-Path $portableRoot "msys64\usr\bin"
    $env:PATH = "$binPath;$gccPath;$usrPath;$env:PATH"
}

& $bashPath --login -c "smoke.sh"
exit $LASTEXITCODE
