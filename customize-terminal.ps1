# customize-terminal.ps1 - Facilita la personalización estética de la consola portable (WezTerm y Bash)
# Idioma: Español rioplatense con voseo.

$ErrorActionPreference = "Stop"

# Directorio base del script
$portableRoot = $PSScriptRoot
if ([string]::IsNullOrEmpty($portableRoot)) {
    $portableRoot = (Get-Location).Path
}

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
$wezConfigPath = Join-Path $portableRoot "wezterm.lua"

# Función de ayuda para ejecutar operaciones críticas con reintentos automáticos ante fallos (ej: archivos bloqueados)
function Execute-WithRetry {
    param(
        [scriptblock]$Action,
        [string]$ErrorMessage = "Ocurrió un error al realizar la operación.",
        [int]$MaxRetries = 3,
        [int]$DelaySeconds = 2
    )
    $attempts = 0
    $success = $false
    while (-not $success -and $attempts -lt $MaxRetries) {
        $attempts++
        try {
            & $Action
            $success = $true
        } catch {
            Write-Host "[Intento $attempts de $MaxRetries] $ErrorMessage" -ForegroundColor Yellow
            Write-Host "Detalle del error: $_" -ForegroundColor Red
            if ($attempts -lt $MaxRetries) {
                Write-Host "Reintentando en $DelaySeconds segundos..." -ForegroundColor Gray
                Start-Sleep -Seconds $DelaySeconds
            } else {
                throw $_
            }
        }
    }
}

# Limpiar pantalla e inicio del asistente
Clear-Host
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "        Asistente de Personalización de Consola Portable" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "Este script te permite personalizar la estética de la consola WezTerm.`n"

# Asegurar existencia del HOME portable
if (-not (Test-Path $homeDir)) {
    Execute-WithRetry -Action {
        New-Item -ItemType Directory -Path $homeDir | Out-Null
    } -ErrorMessage "No se pudo crear el directorio HOME portable en: $homeDir"
}

# ---------------------------------------------------------
# Parte 1: Personalización de la Terminal (WezTerm)
# ---------------------------------------------------------
# (La personalización del banner de bienvenida y entorno Bash se maneja por medio de customize-bash.sh)

# ---------------------------------------------------------
# Parte 2: Personalización de la Terminal (WezTerm)
# ---------------------------------------------------------
$configureWez = $null
while ($configureWez -notmatch "^[sSnN]$") {
    $configureWez = Read-Host "`n¿Querés cambiar la apariencia de la terminal WezTerm? (s/n)"
}

if ($configureWez -match "^[sS]$") {
    # Cargar valores actuales si wezterm.lua existe
    $currentColorScheme = "Tokyo Night"
    $currentFontSize = "11.0"
    $currentOpacity = "0.95"
    
    if (Test-Path $wezConfigPath) {
        $wezContent = Get-Content $wezConfigPath -Raw
        if ($wezContent -match "config.color_scheme\s*=\s*'([^']+)'") {
            $currentColorScheme = $Matches[1]
        }
        if ($wezContent -match "config.font_size\s*=\s*([0-9.]+)") {
            $currentFontSize = $Matches[1]
        }
        if ($wezContent -match "config.window_background_opacity\s*=\s*([0-9.]+)") {
            $currentOpacity = $Matches[1]
        }
    }
    
    Write-Host "`nElegí un esquema de color para WezTerm:" -ForegroundColor Cyan
    Write-Host "1) Tokyo Night (Actual: $currentColorScheme)"
    Write-Host "2) Dracula"
    Write-Host "3) Gruvbox Dark (Retro)"
    Write-Host "4) Nord (Polar)"
    Write-Host "5) One Half Dark (Moderno)"
    Write-Host "6) Conservar valor actual / Personalizado"
    
    $themeChoice = ""
    while ($themeChoice -notmatch "^[123456]$") {
        $themeChoice = Read-Host "Seleccioná un tema (1-6)"
    }
    
    $selectedScheme = $currentColorScheme
    $themeMap = @{
        "1" = "Tokyo Night"
        "2" = "Dracula"
        "3" = "Gruvbox Dark"
        "4" = "Nord"
        "5" = "One Half Dark"
    }
    if ($themeChoice -ne "6") {
        $selectedScheme = $themeMap[$themeChoice]
    }
    
    # Tamaño de fuente
    $validFontSize = $false
    $selectedFontSize = $currentFontSize
    while (-not $validFontSize) {
        $fontInput = Read-Host "Ingresá el tamaño de fuente (8-24, actual: $currentFontSize) [Presioná Enter para mantener]"
        if ([string]::IsNullOrEmpty($fontInput)) {
            $validFontSize = $true
        } else {
            $val = 0.0
            if ([double]::TryParse($fontInput, [ref]$val) -and $val -ge 8 -and $val -le 24) {
                $selectedFontSize = $fontInput
                $validFontSize = $true
            } else {
                Write-Host "Por favor, ingresá un número válido entre 8 y 24." -ForegroundColor Yellow
            }
        }
    }
    
    # Opacidad
    $validOpacity = $false
    $selectedOpacity = $currentOpacity
    while (-not $validOpacity) {
        $opacityInput = Read-Host "Ingresá la opacidad del fondo (0.50 a 1.00, actual: $currentOpacity) [Presioná Enter para mantener]"
        if ([string]::IsNullOrEmpty($opacityInput)) {
            $validOpacity = $true
        } else {
            # Reemplazar comas por puntos en la entrada si el locale de Windows usa comas decimales
            $opacityNormalized = $opacityInput.Replace(',', '.')
            $val = 0.0
            if ([double]::TryParse($opacityNormalized, [System.Globalization.NumberStyles]::Any, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$val) -and $val -ge 0.5 -and $val -le 1.0) {
                $selectedOpacity = $opacityNormalized
                $validOpacity = $true
            } else {
                Write-Host "Por favor, ingresá un número decimal válido entre 0.50 y 1.00." -ForegroundColor Yellow
            }
        }
    }

    # Barra de pestañas (Tabs)
    $enableTabBar = $null
    while ($enableTabBar -notmatch "^[sSnN]$") {
        $enableTabBar = Read-Host "¿Querés habilitar la barra de pestañas (múltiples tabs) en la terminal? (s/n)"
    }
    $selectedTabBar = "false"
    if ($enableTabBar -match "^[sS]$") {
        $selectedTabBar = "true"
    }
    
    # Generar contenido final de wezterm.lua
    $wezConfigContent = @"
local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- Configurar directorio raiz portable
local portable_root = os.getenv("PORTABLE_ROOT")
if portable_root then
  portable_root = portable_root:gsub("\\\\", "/")
  if not portable_root:match("/$") then
    portable_root = portable_root .. "/"
  end
else
  portable_root = "./"
end

local bash_path = portable_root .. "msys64/usr/bin/bash.exe"
config.default_prog = { bash_path, "--login", "-i" }

-- Configurar entorno heredado
local home_dir = os.getenv("HOME")
if home_dir then home_dir = home_dir:gsub("\\\\", "/") end

local path_env = os.getenv("PATH")
if path_env then path_env = path_env:gsub("\\\\", "/") end

config.set_environment_variables = {
  MSYSTEM = "CLANG64",
  CHERE_INVOKING = "1",
  HOME = home_dir,
  PATH = path_env,
}

-- Estetica Premium (Personalizada via customize-terminal.ps1)
config.color_scheme = '$selectedScheme'
config.font = wezterm.font 'JetBrains Mono'
config.font_size = $selectedFontSize
config.window_background_opacity = $selectedOpacity
config.enable_tab_bar = $selectedTabBar

return config
"@
    
    Write-Host "`nEscribiendo cambios en wezterm.lua..." -ForegroundColor Cyan
    Execute-WithRetry -Action {
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($wezConfigPath, $wezConfigContent, $utf8NoBom)
    } -ErrorMessage "Fallo al escribir en el archivo wezterm.lua."
    Write-Host "Configuración de apariencia de WezTerm actualizada correctamente." -ForegroundColor Green
}

Write-Host "`n=== PERSONALIZACIÓN COMPLETADA ===" -ForegroundColor Green
Write-Host "Los cambios se aplicarán de inmediato al abrir una nueva terminal." -ForegroundColor Green
