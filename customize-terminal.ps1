﻿﻿﻿# customize-terminal.ps1 - Facilita la personalización estética de la consola portable (WezTerm y Bash)
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
Write-Host "Este script te permite personalizar la estética de la consola (WezTerm)"
Write-Host "y el banner de bienvenida del terminal Bash de forma sencilla.`n"

# Asegurar existencia del HOME portable
if (-not (Test-Path $homeDir)) {
    Execute-WithRetry -Action {
        New-Item -ItemType Directory -Path $homeDir | Out-Null
    } -ErrorMessage "No se pudo crear el directorio HOME portable en: $homeDir"
}

# ---------------------------------------------------------
# Parte 1: Personalización del Banner de Bienvenida (Bash)
# ---------------------------------------------------------
$configureBanner = $null
while ($configureBanner -notmatch "^[sSnN]$") {
    $configureBanner = Read-Host "¿Querés configurar o modificar el mensaje de bienvenida de la consola? (s/n)"
}

if ($configureBanner -match "^[sS]$") {
    Write-Host "`nElegí el tipo de banner de bienvenida:" -ForegroundColor Cyan
    Write-Host "1) Mensaje limpio estándar (con información del entorno)"
    Write-Host "2) Mensaje de texto personalizado"
    Write-Host "3) Desactivar banner (consola limpia)"
    
    $bannerChoice = ""
    while ($bannerChoice -notmatch "^[123]$") {
        $bannerChoice = Read-Host "Seleccioná una opción (1-3)"
    }
    
    $bannerLines = @()
    $enableWelcomeMessage = "s"
    
    if ($bannerChoice -eq "1") {
        $bannerLines = @(
            "  ENTORNO PORTABLE C + PYTHON (CLANG64)",
            "  Consola interactiva inicializada con éxito.",
            "  Herramientas de C: clang, make, cmake, ninja, cppcheck",
            "  Entorno Python: python, pip, uv",
            "  Editor de código: VS Code Portable",
            "  ",
            "  Escribí 'exit' para cerrar la consola."
        )
    } elseif ($bannerChoice -eq "2") {
        Write-Host "`nEscribí tu mensaje de bienvenida línea por línea."
        Write-Host "Cuando termines, escribí 'FIN' en una línea vacía y presioná Enter:" -ForegroundColor Yellow
        $customLine = ""
        while ($true) {
            $customLine = Read-Host "Línea"
            if ($customLine.Trim().ToUpper() -eq "FIN") {
                break
            }
            $bannerLines += $customLine
        }
    } else {
        $enableWelcomeMessage = "n"
    }
    
    $bashColorCode = "36" # Celeste predeterminado
    if ($enableWelcomeMessage -eq "s") {
        Write-Host "`nElegí el color del banner:" -ForegroundColor Cyan
        Write-Host "1) Celeste (Cyan)"
        Write-Host "2) Verde (Green)"
        Write-Host "3) Amarillo (Yellow)"
        Write-Host "4) Violeta (Purple)"
        Write-Host "5) Blanco (White)"
        
        $colorChoice = ""
        while ($colorChoice -notmatch "^[12345]$") {
            $colorChoice = Read-Host "Seleccioná una opción de color (1-5)"
        }
        
        $colorMap = @{
            "1" = "36"
            "2" = "32"
            "3" = "33"
            "4" = "35"
            "5" = "37"
        }
        $bashColorCode = $colorMap[$colorChoice]
    }
    
    # Procesar actualización en el archivo .bashrc
    $bashrcPath = Join-Path $homeDir ".bashrc"
    
    $bashrcContent = ""
    if (Test-Path $bashrcPath) {
        $bashrcContent = Get-Content $bashrcPath -Raw
    }
    
    $startInstMarker = "# === START INSTITUTIONAL BANNER ==="
    $endInstMarker = "# === END INSTITUTIONAL BANNER ==="
    
    # Asegurar la existencia del banner institucional (va antes del banner del estudiante)
    if (-not $bashrcContent.Contains($startInstMarker)) {
        $instBanner = @(
            $startInstMarker,
            "clear",
            'echo -e "\e[35m"', # Violeta
            'echo "======================================================================"',
            'echo "  UNRN Andina - Programación 1"',
            'echo "======================================================================"',
            'echo -e "\e[0m"',
            $endInstMarker
        ) -join "`r`n"
        if ($bashrcContent.Trim().Length -gt 0) {
            $bashrcContent = $instBanner + "`r`n`r`n" + $bashrcContent
        } else {
            $bashrcContent = $instBanner
        }
    }
    
    $startMarker = "# === START WELCOME BANNER ==="
    $endMarker = "# === END WELCOME BANNER ==="
    
    # Generar el bloque nuevo para la personalización del estudiante
    $newBannerBlock = "$startMarker`r`n"
    if ($enableWelcomeMessage -eq "s") {
        # Se remueve el clear para no borrar el banner institucional previo
        $newBannerBlock += "echo -e ""\e[${bashColorCode}m""`r`n"
        $newBannerBlock += "echo ""======================================================================""`r`n"
        foreach ($line in $bannerLines) {
            $escapedLine = $line.Replace('"', '\"')
            $newBannerBlock += "echo ""$escapedLine""`r`n"
        }
        $newBannerBlock += "echo ""======================================================================""`r`n"
        $newBannerBlock += "echo -e ""\e[0m""`r`n"
    }
    $newBannerBlock += "$endMarker"
    
    if ($bashrcContent -match "(?s)$startMarker.*?$endMarker") {
        $bashrcContent = $bashrcContent -replace "(?s)$startMarker.*?$endMarker", $newBannerBlock
    } else {
        # Agregar una nueva línea al final de .bashrc
        if ($bashrcContent.Trim().Length -gt 0) {
            $bashrcContent += "`r`n`r`n$newBannerBlock"
        } else {
            $bashrcContent = $newBannerBlock
        }
    }
    
    Write-Host "`nEscribiendo cambios en .bashrc..." -ForegroundColor Cyan
    Execute-WithRetry -Action {
        Set-Content -Path $bashrcPath -Value $bashrcContent -Force
    } -ErrorMessage "Fallo al escribir en el archivo .bashrc de la consola."
    Write-Host "Mensaje de bienvenida guardado correctamente." -ForegroundColor Green
}

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
            if ([double]::TryParse($opacityNormalized, [System.Globalization.NumberStyles]::Any, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$val) -and $val -ge 0.5 -and $val -le 1.0) {
                $selectedOpacity = $opacityNormalized
                $validOpacity = $true
            } else {
                Write-Host "Por favor, ingresá un número decimal válido entre 0.50 y 1.00." -ForegroundColor Yellow
            }
        }
    }
    
    # Generar contenido final de wezterm.lua
    $wezConfigContent = @"
local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- Configurar directorio raíz portable
local portable_root = os.getenv("PORTABLE_ROOT")
if portable_root then
  portable_root = portable_root:gsub("\\\\", "/")
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

-- Estética Premium (Personalizada via customize-terminal.ps1)
config.color_scheme = '$selectedScheme'
config.font = wezterm.font 'JetBrains Mono'
config.font_size = $selectedFontSize
config.window_background_opacity = $selectedOpacity
config.enable_tab_bar = false

return config
"@
    
    Write-Host "`nEscribiendo cambios en wezterm.lua..." -ForegroundColor Cyan
    Execute-WithRetry -Action {
        Set-Content -Path $wezConfigPath -Value $wezConfigContent -Force
    } -ErrorMessage "Fallo al escribir en el archivo wezterm.lua."
    Write-Host "Configuración de apariencia de WezTerm actualizada correctamente." -ForegroundColor Green
}

Write-Host "`n=== PERSONALIZACIÓN COMPLETADA ===" -ForegroundColor Green
Write-Host "Los cambios se aplicarán de inmediato al abrir una nueva terminal." -ForegroundColor Green
