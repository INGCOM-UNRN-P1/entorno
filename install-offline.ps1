# install-offline.ps1 - Asiste la instalacion del paquete offline (portable-env-offline.zip).
# Extrae el ZIP en el destino elegido, valida la estructura y deja el entorno listo para
# ejecutar launch.bat. No requiere permisos de administrador ni conexion a internet.
#
# Uso:
#   .\install-offline.ps1                              # extrae en .\entorno usando el ZIP de la carpeta actual
#   .\install-offline.ps1 -Destino D:\catedra\entorno  # destino personalizado
#   .\install-offline.ps1 -RutaZip C:\paquetes\portable-env-offline.zip
#   .\install-offline.ps1 -Ejecutar                    # abre el terminal al terminar

param(
    [string]$Destino = "",
    [string]$RutaZip = "",
    [switch]$Ejecutar
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$baseDir = $PSScriptRoot
if ([string]::IsNullOrEmpty($baseDir)) { $baseDir = (Get-Location).Path }

if ([string]::IsNullOrEmpty($RutaZip)) { $RutaZip = Join-Path $baseDir "portable-env-offline.zip" }
if ([string]::IsNullOrEmpty($Destino)) { $Destino = Join-Path $baseDir "entorno" }

if (-not (Test-Path $RutaZip)) {
    Write-Error "No se encontro el paquete '$RutaZip'. Descargalo o indica su ruta con -RutaZip."
    exit 1
}

if (Test-Path $Destino) {
    Write-Host "El destino '$Destino' ya existe." -ForegroundColor Yellow
    $choice = Read-Host "Continuar extrayendo encima? (s/n)"
    if ($choice -notmatch "^[sS]$") {
        Write-Host "Operacion cancelada." -ForegroundColor Green
        exit 0
    }
} else {
    New-Item -ItemType Directory -Path $Destino -Force | Out-Null
}

Write-Host "=== Instalacion Offline del Entorno Portable ===" -ForegroundColor Cyan
Write-Host "Paquete : $RutaZip ($([math]::Round((Get-Item $RutaZip).Length / 1GB, 2)) GB)"
Write-Host "Destino : $Destino"
Write-Host ""

# Extraccion acelerada: tar.exe (bsdtar incluido desde Windows 10 1803) con fallback nativo
$tarExe = Join-Path $env:SystemRoot "System32\tar.exe"
if (Test-Path $tarExe) {
    Write-Host "[1/3] Extrayendo con tar.exe (rapido)..." -ForegroundColor Cyan
    & $tarExe -xf "$RutaZip" -C "$Destino"
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "tar.exe reporto codigo $LASTEXITCODE; reintentando con Expand-Archive..."
        Expand-Archive -Path $RutaZip -DestinationPath $Destino -Force
    }
} else {
    Write-Host "[1/3] Extrayendo con Expand-Archive (puede tardar varios minutos)..." -ForegroundColor Cyan
    Expand-Archive -Path $RutaZip -DestinationPath $Destino -Force
}

# Validacion estructural minima del paquete
Write-Host "[2/3] Validando estructura extraida..." -ForegroundColor Cyan
$launchBat = Get-ChildItem -Path $Destino -Filter "launch.bat" -Recurse | Select-Object -First 1
if (-not $launchBat) {
    Write-Error "El paquete no contiene launch.bat. Es un portable-env-offline.zip valido?"
    exit 1
}
$rootExtraido = Split-Path $launchBat.FullName -Parent

# Advertencia clasica de rutas conflictivas para compiladores
$hasConflict = ($rootExtraido -match ' ') -or ($rootExtraido -match '[^\u0000-\u007F]') -or ($rootExtraido -match '(?i)onedrive|dropbox')
if ($hasConflict) {
    Write-Warning "La ruta '$rootExtraido' contiene espacios, caracteres no ASCII o esta sincronizada; puede romper las herramientas de compilacion."
    Write-Warning "Se recomienda mover la carpeta a una ruta simple (ej: C:\dev\entorno)."
}

Write-Host "[3/3] Listo." -ForegroundColor Cyan
Write-Host ""
Write-Host "=== INSTALACION OFFLINE COMPLETADA ===" -ForegroundColor Green
Write-Host "Entorno disponible en: $rootExtraido" -ForegroundColor Green
Write-Host ""
Write-Host "Primeros pasos sugeridos:" -ForegroundColor Cyan
Write-Host "  1. Abri el entorno con launch.bat (desde esa carpeta)."
Write-Host "  2. Configura tu identidad: configure-git.sh"
Write-Host "  3. Verifica la salud: smoke.sh"

if ($Ejecutar) {
    Write-Host "`nIniciando el terminal..." -ForegroundColor Magenta
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "`"$($launchBat.FullName)`"" -WorkingDirectory $rootExtraido
} else {
    Write-Host "`nPresiona cualquier tecla para salir..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
