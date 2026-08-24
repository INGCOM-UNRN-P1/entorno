# smoke.ps1 - Ejecuta la suite de aceptación automatizada (bin/smoke.sh) en el bash portable.
$ErrorActionPreference = "Stop"
$portableRoot = $PSScriptRoot
if ([string]::IsNullOrEmpty($portableRoot)) { $portableRoot = (Get-Location).Path }
$bashPath = Join-Path $portableRoot "msys64\usr\bin\bash.exe"
if (-not (Test-Path $bashPath)) {
    Write-Error "No se encontró MSYS2. Ejecutá setup.ps1 primero."
    exit 1
}
$env:PORTABLE_ROOT = $portableRoot
$env:HOME = Join-Path $portableRoot "home"
$env:MSYSTEM = "UCRT64"
$env:CHERE_INVOKING = "1"
& $bashPath --login -c "smoke.sh"
exit $LASTEXITCODE
