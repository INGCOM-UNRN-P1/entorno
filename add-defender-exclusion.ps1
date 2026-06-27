# add-defender-exclusion.ps1 - Agrega el entorno portable a las exclusiones de Windows Defender

$ErrorActionPreference = "Stop"

# Comprobar si tenemos permisos de administrador
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "[INFO] Solicitando permisos de administrador..." -ForegroundColor Cyan
    try {
        Start-Process PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
        exit
    } catch {
        Write-Host "[ERROR] Se requieren permisos de administrador para modificar las exclusiones de Windows Defender." -ForegroundColor Red
        Write-Host "Por favor, ejecutá este script como Administrador manualmente."
        Pause
        exit 1
    }
}

$portableRoot = $PSScriptRoot

Write-Host "======================================================================"
Write-Host "EXCLUSION DE WINDOWS DEFENDER"
Write-Host "======================================================================"
Write-Host "Ruta a excluir: $portableRoot"

try {
    # Agregar la carpeta a la exclusión
    Add-MpPreference -ExclusionPath $portableRoot
    Write-Host "[EXITO] Se ha agregado exitosamente '$portableRoot' a las exclusiones de Defender." -ForegroundColor Green
    Write-Host "Esto mejorará los tiempos de compilación (Make/CMake) e impedirá falsos positivos." -ForegroundColor Green
} catch {
    Write-Host "[ERROR] No se pudo agregar la exclusión. Detalle del error:" -ForegroundColor Red
    Write-Host $_.Exception.Message
}

Write-Host ""
Write-Host "Presioná cualquier tecla para salir..."
$host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
