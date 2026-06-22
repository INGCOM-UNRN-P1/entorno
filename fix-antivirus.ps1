# fix-antivirus.ps1 - Agrega una exclusión en Windows Defender para el entorno portable.
# Esto soluciona errores como 'Mingw-w64 runtime failure: VirtualProtect failed with code 0x5af'
# al compilar con Clang, el cual es causado por restricciones agresivas de memoria del antivirus.

$ErrorActionPreference = "Stop"

# Obtener la ruta de este script
$portableRoot = $PSScriptRoot
if ([string]::IsNullOrEmpty($portableRoot)) {
    $portableRoot = (Get-Location).Path
}

# Función para verificar privilegios de administrador
function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdmin)) {
    Write-Host "==========================================================================" -ForegroundColor Yellow
    Write-Host "Se requieren permisos de Administrador para ajustar el Antivirus." -ForegroundColor Yellow
    Write-Host "Intentando reiniciar este script con privilegios elevados..." -ForegroundColor Yellow
    Write-Host "Por favor, aceptá la ventana de confirmación (UAC)." -ForegroundColor Yellow
    Write-Host "==========================================================================" -ForegroundColor Yellow
    
    Start-Sleep -Seconds 2
    
    try {
        Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
        exit
    } catch {
        Write-Error "No se pudo elevar los privilegios automáticamente. Por favor, abrí PowerShell como Administrador y ejecutá este script manualmente."
        exit
    }
}

Write-Host "=== Configuración de Excepciones de Windows Defender ===" -ForegroundColor Cyan
Write-Host "Ruta del entorno: $portableRoot" -ForegroundColor Cyan

try {
    # Verificar si el servicio de Defender está disponible
    $defenderPrefs = Get-MpPreference -ErrorAction Stop
    $exclusions = $defenderPrefs.ExclusionPath

    if ($exclusions -and $exclusions -contains $portableRoot) {
        Write-Host "`n[OK] La ruta ya se encuentra excluida en Windows Defender." -ForegroundColor Green
    } else {
        Write-Host "`nAgregando exclusión en Windows Defender para evitar falsos positivos y bloqueos de memoria..."
        Add-MpPreference -ExclusionPath $portableRoot
        Write-Host "[ÉXITO] Exclusión agregada correctamente." -ForegroundColor Green
    }
} catch {
    Write-Host "`n[ERROR] Ocurrió un error al intentar modificar Windows Defender." -ForegroundColor Red
    Write-Host "Motivos comunes:" -ForegroundColor Yellow
    Write-Host "1. Estás usando otro Antivirus principal (Avast, McAfee, Norton, etc.) que desactiva Defender." -ForegroundColor Yellow
    Write-Host "2. Las políticas de grupo (GPO) de Windows restringen estas modificaciones." -ForegroundColor Yellow
    Write-Host "`nSi usás otro Antivirus, por favor agregá la carpeta del entorno a sus exclusiones manualmente." -ForegroundColor Yellow
}

Write-Host "`nPresioná cualquier tecla para salir..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
