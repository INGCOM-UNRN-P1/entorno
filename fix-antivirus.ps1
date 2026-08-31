# fix-antivirus.ps1 - Agrega una exclusion en Windows Defender para el entorno portable.
# Esto soluciona errores como 'Mingw-w64 runtime failure: VirtualProtect failed with code 0x5af'
# al compilar con Clang, el cual es causado por restricciones agresivas de memoria del antivirus.

$ErrorActionPreference = "Stop"

# Obtener la ruta de este script
$portableRoot = $PSScriptRoot
if ([string]::IsNullOrEmpty($portableRoot)) {
    $portableRoot = (Get-Location).Path
}

# Funcion para verificar privilegios de administrador
function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdmin)) {
    Write-Host "==========================================================================" -ForegroundColor Yellow
    Write-Host "Se requieren permisos de Administrador para ajustar el Antivirus." -ForegroundColor Yellow
    Write-Host "Intentando reiniciar este script con privilegios elevados..." -ForegroundColor Yellow
    Write-Host "Por favor, acepta la ventana de confirmacion (UAC)." -ForegroundColor Yellow
    Write-Host "==========================================================================" -ForegroundColor Yellow
    
    Start-Sleep -Seconds 2
    
    try {
        Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
        exit
    } catch {
        Write-Error "No se pudo elevar los privilegios automaticamente. Por favor, abri PowerShell como Administrador y ejecuta este script manualmente."
        exit
    }
}

Write-Host "=== Configuracion de Excepciones de Windows Defender ===" -ForegroundColor Cyan
Write-Host "Ruta del entorno: $portableRoot" -ForegroundColor Cyan
# Exclusion granular: solo los directorios con binarios que ejecutan compilaciones,
# en lugar de la carpeta raiz completa (menor superficie expuesta).
$exclusionTargets = @(
    @{ Path = Join-Path $portableRoot "msys64";  Desc = "compiladores y toolchain" },
    @{ Path = Join-Path $portableRoot "vscode";  Desc = "editor y extensiones" },
    @{ Path = Join-Path $portableRoot "wezterm"; Desc = "terminal GPU" }
)

try {
    # Verificar si el servicio de Defender esta disponible
    $defenderPrefs = Get-MpPreference -ErrorAction Stop
    $exclusions = $defenderPrefs.ExclusionPath

    foreach ($target in $exclusionTargets) {
        if ($exclusions -and $exclusions -contains $target.Path) {
            Write-Host "`n[OK] Ya excluido: $($target.Path) ($($target.Desc))." -ForegroundColor Green
        } elseif (Test-Path $target.Path) {
            Write-Host "`nAgregando exclusion para $($target.Desc): $($target.Path)"
            Add-MpPreference -ExclusionPath $target.Path
            Write-Host "[EXITO] Exclusion agregada correctamente." -ForegroundColor Green
        } else {
            Write-Host "`n[INFO] $($target.Path) no existe aun (falta inicializar el entorno?); se omite." -ForegroundColor DarkGray
        }
    }
} catch {
    Write-Host "`n[ERROR] Ocurrio un error al intentar modificar Windows Defender." -ForegroundColor Red
    Write-Host "Motivos comunes:" -ForegroundColor Yellow
    Write-Host "1. Estas usando otro Antivirus principal (Avast, McAfee, Norton, etc.) que desactiva Defender." -ForegroundColor Yellow
    Write-Host "2. Las politicas de grupo (GPO) de Windows restringen estas modificaciones." -ForegroundColor Yellow
    Write-Host "`nSi usas otro Antivirus, por favor agrega la carpeta del entorno a sus exclusiones manualmente." -ForegroundColor Yellow
}

# Detectar antivirus de terceros registrados en el Centro de Seguridad de Windows
try {
    $thirdPartyAv = Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct -ErrorAction Stop |
        Where-Object { $_.displayName -notmatch 'Defender|Microsoft' }
    if ($thirdPartyAv) {
        Write-Host "`n[AVISO] Se detectaron otros antivirus registrados en el sistema:" -ForegroundColor Yellow
        foreach ($av in $thirdPartyAv) {
            Write-Host "  * $($av.displayName)" -ForegroundColor Yellow
        }
        Write-Host "La exclusion de Defender no los cubre: agrega manualmente la carpeta del entorno" -ForegroundColor Yellow
        Write-Host "a las exclusiones de cada uno de esos productos para evitar bloqueos al compilar." -ForegroundColor Yellow
    }
} catch {
    # El namespace SecurityCenter2 puede no estar disponible en algunos sistemas; ignorar silenciosamente.
}

Write-Host "`nPresiona cualquier tecla para salir..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
