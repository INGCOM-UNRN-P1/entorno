﻿﻿﻿﻿﻿﻿﻿# clean-shared-host.ps1 - Limpia datos personales, credenciales e historial del entorno portable.
# Diseñado para usarse antes de desconectarse o cerrar sesión en computadoras compartidas.

$ErrorActionPreference = "Stop"

$portableRoot = $PSScriptRoot

# Cargar configuración de directorio HOME
$homeDirName = "home"
$envFile = Join-Path $portableRoot ".env"
if (Test-Path $envFile) {
    $envContent = Get-Content $envFile -Raw
    if ($envContent -match 'HOME_DIR_NAME=(.*)') {
        $homeDirName = $Matches[1].Replace('"', '').Trim()
    }
}

$homeDir = Join-Path $portableRoot $homeDirName
$vscodeDataDir = Join-Path $portableRoot "vscode\data"
$tempDir = Join-Path $portableRoot "downloads"
$msysTemp = Join-Path $portableRoot "msys64\tmp"

Write-Host "==========================================================================" -ForegroundColor Red
Write-Host "            LIMPIEZA DE DATOS PERSONALES Y CREDENCIALES                   " -ForegroundColor Red
Write-Host "==========================================================================" -ForegroundColor Red
Write-Host "Este script removerá de forma permanente todo rastro de tu identidad,"
Write-Host "credenciales y configuraciones guardadas en este entorno portable."
Write-Host ""
Write-Host "EFECTOS DE LA EJECUCIÓN:" -ForegroundColor Yellow
Write-Host "1. ELIMINACIÓN DE CLAVES Y CONFIGURACIONES DE USUARIO:"
Write-Host "   Se borrará la carpeta '$homeDirName/' completa. Esto incluye:"
Write-Host "   - Credenciales guardadas e inicios de sesión en GitHub (.git-credentials)."
Write-Host "   - Configuración de identidad y firma de Git (.gitconfig)."
Write-Host "   - Claves de acceso SSH (.ssh/)."
Write-Host "   - Historial de comandos ejecutados en el terminal (.bash_history)."
Write-Host "   - Configuraciones y cachés de Python locales (.config/, .local/)."
Write-Host ""
Write-Host "2. ELIMINACIÓN DE DATOS DE VS CODE PORTABLE:"
Write-Host "   Se borrará la carpeta 'vscode/data/' completa. Esto incluye:"
Write-Host "   - Configuraciones del editor y caché de visualización."
Write-Host "   - Extensiones instaladas de forma personalizada."
Write-Host "   - Historial de archivos abiertos y estados de proyectos."
Write-Host ""
Write-Host "3. LIMPIEZA DE TEMPORALES:"
Write-Host "   Se vaciarán las carpetas de descargas y temporales ('downloads/' y 'msys64/tmp/')."
Write-Host "==========================================================================" -ForegroundColor Red
Write-Host ""

$choice = Read-Host "Esta acción es IRREVERSIBLE. ¿Deseás continuar? (s/n)"
if ($choice -notmatch "^[sS]$") {
    Write-Host "Operación cancelada. Tus datos no han sido modificados." -ForegroundColor Green
    exit 0
}

Write-Host "`nIniciando limpieza profunda..." -ForegroundColor Cyan

# 1. Eliminar home/
if (Test-Path $homeDir) {
    Write-Host "* Eliminando directorio portable '$homeDirName'..."
    Remove-Item -Path $homeDir -Recurse -Force
}

# Recrear home/ vacío para que los lanzadores funcionen
New-Item -ItemType Directory -Path $homeDir | Out-Null

$bashPath = Join-Path $portableRoot "msys64\usr\bin\bash.exe"
if (Test-Path $bashPath) {
    # Inicializar bash para que cree el .bashrc base
    & $bashPath -env "HOME=$homeDir" --login -c "exit"
    
    $bashrcPath = Join-Path $homeDir ".bashrc"
    if (Test-Path $bashrcPath) {
        $customAliases = @(
            "",
            "# === Portable Dev Environment Aliases ===",
            "alias python='python3'",
            "alias pip='pip3'",
            "alias make='mingw32-make'",
            "alias ll='ls -alF --color=auto'",
            "export PS1='\[\e[32m\]\u@portable \[\e[33m\]\w\[\e[0m\]\n$ '"
        )
        Add-Content -Path $bashrcPath -Value ($customAliases -join "`r`n")
        
        $startInstMarker = "# === START INSTITUTIONAL BANNER ==="
        $endInstMarker = "# === END INSTITUTIONAL BANNER ==="
        $instBanner = @(
            "",
            $startInstMarker,
            "clear",
            'echo -e "\e[35m"', # Violeta
            'echo "======================================================================"',
            'echo "  UNRN Andina - Programación 1"',
            'echo "======================================================================"',
            'echo -e "\e[0m"',
            $endInstMarker
        ) -join "`r`n"
        Add-Content -Path $bashrcPath -Value $instBanner
    }
}
Write-Host "  -> Directorio portable '$homeDirName' restablecido con alias y banner institucional." -ForegroundColor Green

# 2. Eliminar vscode/data
if (Test-Path $vscodeDataDir) {
    Write-Host "* Eliminando directorio de datos de VS Code..."
    Remove-Item -Path $vscodeDataDir -Recurse -Force
}

# Recrear estructura inicial básica de VS Code para que quede listo para el siguiente inicio
$userSettingsDir = Join-Path $vscodeDataDir "user-data\User"
New-Item -ItemType Directory -Path $userSettingsDir | Out-Null

$settingsJsonPath = Join-Path $userSettingsDir "settings.json"
$defaultSettings = @{
    "telemetry.telemetryLevel" = "off"
    "update.mode" = "none"
    "extensions.autoUpdate" = $false
    "chat.disableAIFeatures" = $true
    "github.copilot.enable" = @{
        "*" = $false
    }
    "terminal.integrated.profiles.windows" = @{
        "Clang64 Bash" = @{
            "path" = "bash.exe"
            "args" = @("--login", "-i")
        }
    }
    "terminal.integrated.defaultProfile.windows" = "Clang64 Bash"
} | ConvertTo-Json -Depth 10

Set-Content -Path $settingsJsonPath -Value $defaultSettings
Write-Host "  -> Datos de VS Code restablecidos a la configuración inicial." -ForegroundColor Green

# 3. Eliminar downloads/
if (Test-Path $tempDir) {
    Write-Host "* Vaciando descargas temporales..."
    Remove-Item -Path $tempDir -Recurse -Force
}

# 4. Limpiar msys64/tmp/
if (Test-Path $msysTemp) {
    Write-Host "* Vaciando temporales de MSYS2..."
    Get-ChildItem -Path $msysTemp | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}

# 5. Eliminar archivos de estado de instalación
$completeMarkers = @(".install_complete", ".vscode_complete")
foreach ($marker in $completeMarkers) {
    $markerPath = Join-Path $portableRoot $marker
    if (Test-Path $markerPath) {
        Write-Host "* Eliminando indicador de estado: $marker"
        Remove-Item -Path $markerPath -Force
    }
}

Write-Host "`n=== LIMPIEZA COMPLETADA CON ÉXITO ===" -ForegroundColor Green
Write-Host "El entorno portable se encuentra libre de credenciales y datos personales." -ForegroundColor Green
