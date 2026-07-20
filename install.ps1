# install.ps1 - Bootstrap para el Entorno Portable
# Este archivo está guardado en UTF-8 sin BOM para poder ejecutarse directamente desde internet:
# irm https://raw.githubusercontent.com/INGCOM-UNRN-P1/entorno/main/install.ps1 | iex

$ErrorActionPreference = "Stop"
$setupUrl = "https://raw.githubusercontent.com/INGCOM-UNRN-P1/entorno/main/setup.ps1"
$destPath = Join-Path (Get-Location).Path "setup.ps1"

Write-Host "Descargando script principal de instalación..." -ForegroundColor Cyan

try {
    # Descargar con soporte TLS 1.2
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $content = Invoke-RestMethod -Uri $setupUrl -UseBasicParsing
    
    if ([string]::IsNullOrEmpty($content)) {
        throw "El archivo descargado está vacío."
    }
    
    # Remover el BOM si viene en el texto remoto
    $content = $content.TrimStart([char]0xFEFF)
    
    # Escribir setup.ps1 local con UTF-8 con BOM
    $utf8WithBom = New-Object System.Text.UTF8Encoding($true)
    [System.IO.File]::WriteAllText($destPath, $content, $utf8WithBom)
    
    Write-Host "`n======================================================================" -ForegroundColor Green
    Write-Host " DESCARGA DE SETUP COMPLETADA. INICIANDO INSTALACIÓN..." -ForegroundColor Green
    Write-Host "======================================================================`n" -ForegroundColor Green
    
    # Ejecutar setup.ps1 pasando los mismos argumentos recibidos en este script
    & $destPath @args
    exit $LASTEXITCODE
} catch {
    Write-Error "Error fatal al descargar setup.ps1: $_"
}
