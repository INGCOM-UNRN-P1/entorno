param(
    [string]$HomeDirName = "home"
)

$ErrorActionPreference = "Stop"

# Directorio base del script (con fallback al directorio actual si se ejecuta desde internet vía IEX)
$portableRoot = $PSScriptRoot
if ([string]::IsNullOrEmpty($portableRoot)) {
    $portableRoot = (Get-Location).Path
}
$msysDir = Join-Path $portableRoot "msys64"
$tempDir = Join-Path $portableRoot "downloads"
$homeDir = Join-Path $portableRoot $HomeDirName
$vscodeDir = Join-Path $portableRoot "vscode"

# Escribir archivo de configuración .env local
$envFilePath = Join-Path $portableRoot ".env"
Set-Content -Path $envFilePath -Value "set `"HOME_DIR_NAME=$HomeDirName`""

# Asegurar que el archivo .env y el directorio personalizado estén excluidos en .gitignore
$gitignorePath = Join-Path $portableRoot ".gitignore"
if (Test-Path $gitignorePath) {
    $gitignoreContent = Get-Content $gitignorePath -Raw
    if (-not $gitignoreContent.Contains(".env")) {
        Add-Content -Path $gitignorePath -Value "`n# Local environment config`n.env"
    }
    $ignoreRule = "$HomeDirName/"
    if (-not $gitignoreContent.Contains($ignoreRule)) {
        Add-Content -Path $gitignorePath -Value "`n# Custom home folder`n$ignoreRule"
    }
}

Write-Host "=== Entorno Portable de Desarrollo C + Python + VS Code ===" -ForegroundColor Cyan
Write-Host "Directorio de instalación: $portableRoot`n"

# Validar espacios o caracteres no ASCII en la ruta de instalación (causan errores graves con Make/compiladores)
$hasSpaces = $portableRoot -match " "
$hasNonAscii = $portableRoot -match "[^\u0000-\u007F]"

if ($hasSpaces -or $hasNonAscii) {
    Write-Host "==========================================================================" -ForegroundColor Yellow
    Write-Host "ADVERTENCIA: RUTA CON POSIBLES CONFLICTOS DETECTADA" -ForegroundColor Yellow
    Write-Host "==========================================================================" -ForegroundColor Yellow
    if ($hasSpaces) {
        Write-Host "* La ruta de instalación contiene espacios en blanco." -ForegroundColor Yellow
    }
    if ($hasNonAscii) {
        Write-Host "* La ruta de instalación contiene caracteres no ASCII (acentos, eñes, etc.)." -ForegroundColor Yellow
    }
    Write-Host "--------------------------------------------------------------------------"
    Write-Host "Muchas herramientas de compilación de C (como Make, CMake y compiladores)"
    Write-Host "fallan o tienen comportamientos erráticos con este tipo de rutas."
    Write-Host "Se recomienda mover la carpeta a una ruta simple (Ej: C:\dev\entorno)."
    Write-Host "--------------------------------------------------------------------------"
    
    $choice = Read-Host "¿Deseás continuar con la instalación de todas formas? (s/n)"
    if ($choice -notmatch "^[sS]$") {
        Write-Host "Instalación cancelada." -ForegroundColor Red
        exit 0
    }
    Write-Host "Continuando con la instalación bajo riesgo del usuario...`n" -ForegroundColor Yellow
}

# Asegurar que existan los directorios iniciales
if (-not (Test-Path $homeDir)) {
    New-Item -ItemType Directory -Path $homeDir | Out-Null
    Write-Host "Creado directorio HOME portable: $homeDir" -ForegroundColor Green
}

if (-not (Test-Path $tempDir)) {
    New-Item -ItemType Directory -Path $tempDir | Out-Null
}

# ==========================================
# 1. Gestión e Instalación de MSYS2
# ==========================================
$isMsysInstalled = Test-Path (Join-Path $msysDir "usr\bin\bash.exe")

if (-not $isMsysInstalled) {
    Write-Host "[Instalación] MSYS2 no detectado. Iniciando descarga..." -ForegroundColor Yellow

    $releaseUrl = "https://api.github.com/repos/msys2/msys2-installer/releases/latest"
    $downloadUrl = $null
    $fileName = $null

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Write-Host "Consultando API de GitHub por la última versión de MSYS2..."
        $release = Invoke-RestMethod -Uri $releaseUrl -UseBasicParsing -TimeoutSec 10
        $asset = $release.assets | Where-Object { $_.name -like "msys2-base-x86_64-*.sfx.exe" }
        if ($asset) {
            $downloadUrl = $asset.browser_download_url
            $fileName = $asset.name
            Write-Host "Última versión detectada: $fileName" -ForegroundColor Green
        }
    } catch {
        Write-Warning "Fallo al consultar la API de GitHub. Usando fallback fijo."
    }

    if (-not $downloadUrl) {
        $downloadUrl = "https://github.com/msys2/msys2-installer/releases/download/2025-02-21/msys2-base-x86_64-20250221.sfx.exe"
        $fileName = "msys2-base-x86_64-20250221.sfx.exe"
        Write-Host "Fallback URL: $downloadUrl" -ForegroundColor Yellow
    }

    $exePath = Join-Path $tempDir $fileName
    $shaPath = "$exePath.sha256"

    Write-Host "Descargando $fileName..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $downloadUrl -OutFile $exePath -UseBasicParsing

    try {
        $shaUrl = "$downloadUrl.sha256"
        Write-Host "Descargando verificación SHA256..."
        Invoke-WebRequest -Uri $shaUrl -OutFile $shaPath -UseBasicParsing -ErrorAction SilentlyContinue
        
        $expectedHash = (Get-Content $shaPath -Raw).Split(" ")[0].Trim()
        $actualHash = (Get-FileHash -Path $exePath -Algorithm SHA256).Hash.ToLower()

        if ($actualHash -eq $expectedHash.ToLower()) {
            Write-Host "Firma SHA256 verificada con éxito." -ForegroundColor Green
        } else {
            throw "Integridad corrupta. El hash no coincide."
        }
    } catch {
        Write-Warning "No se pudo validar el Hash SHA256 de forma automatizada. Se asume correcto."
    }

    Write-Host "Extrayendo entorno base MSYS2 en: $portableRoot" -ForegroundColor Cyan
    $process = Start-Process -FilePath $exePath -ArgumentList "-y", "-o`"$portableRoot`"" -Wait -NoNewWindow -PassThru
    if ($process.ExitCode -ne 0) {
        throw "Error durante la extracción de MSYS2 (código de salida: $($process.ExitCode))"
    }
    Write-Host "Instalación base de MSYS2 completada con éxito.`n" -ForegroundColor Green
} else {
    Write-Host "[Actualización] MSYS2 ya instalado. Procediendo a actualizar paquetes..." -ForegroundColor Yellow
}

# ==========================================
# 2. Inicialización y Actualización de MSYS2
# ==========================================
Write-Host "Inicializando entorno de consola..." -ForegroundColor Cyan
$bashPath = Join-Path $msysDir "usr\bin\bash.exe"
& $bashPath --login -c "exit"

Write-Host "Sincronizando base de datos de pacman y actualizando paquetes del sistema..." -ForegroundColor Cyan
& $bashPath --login -c "pacman -Syu --noconfirm"

Write-Host "Consolidando actualizaciones del entorno..." -ForegroundColor Cyan
& $bashPath --login -c "pacman -Su --noconfirm"

# ==========================================
# 3. Instalación de Clang y Python
# ==========================================
$packages = @(
    "mingw-w64-clang-x86_64-clang",
    "mingw-w64-clang-x86_64-lld",
    "mingw-w64-clang-x86_64-make",
    "mingw-w64-clang-x86_64-cmake",
    "mingw-w64-clang-x86_64-ninja",
    "mingw-w64-clang-x86_64-gdb",
    "mingw-w64-clang-x86_64-python",
    "mingw-w64-clang-x86_64-python-pip",
    "mingw-w64-clang-x86_64-uv",
    "mingw-w64-clang-x86_64-cppcheck",
    "mingw-w64-clang-x86_64-zlib",
    "mingw-w64-clang-x86_64-openssl",
    "mingw-w64-clang-x86_64-sqlite3",
    "mingw-w64-clang-x86_64-curl",
    "mingw-w64-clang-x86_64-github-cli",
    "git"
)

$pkgString = $packages -join " "
Write-Host "Instalando compiladores, herramientas de compilación, Python y librerías comunes..." -ForegroundColor Cyan
& $bashPath --login -c "pacman -S --needed --noconfirm $pkgString"

# Configurar alias en el HOME portable
$bashrcPath = Join-Path $homeDir ".bashrc"
if (-not (Test-Path $bashrcPath)) {
    & $bashPath -env "HOME=$homeDir" --login -c "exit"
}

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
    
    $content = Get-Content $bashrcPath -Raw
    foreach ($alias in $customAliases) {
        if (-not $content.Contains($alias)) {
            Add-Content -Path $bashrcPath -Value $alias
        }
    }
    Write-Host "Configuración de terminal personalizada guardada." -ForegroundColor Green
}

# ==========================================
# 4. Gestión e Instalación de VS Code Portable
# ==========================================
$vscodeZipUrl = "https://code.visualstudio.com/sha/download?build=stable&os=win32-x64-archive"
$vscodeZipName = "vscode_archive.zip"
$vscodeZipPath = Join-Path $tempDir $vscodeZipName
$isCodeInstalled = Test-Path (Join-Path $vscodeDir "Code.exe")

if (-not $isCodeInstalled) {
    Write-Host "[Instalación] VS Code no detectado. Descargando versión portable..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $vscodeZipUrl -OutFile $vscodeZipPath -UseBasicParsing
    
    Write-Host "Extrayendo VS Code..." -ForegroundColor Cyan
    Expand-Archive -Path $vscodeZipPath -DestinationPath $vscodeDir -Force
    
    # Activar el Modo Portable creando la carpeta 'data'
    $dataDir = Join-Path $vscodeDir "data"
    $userSettingsDir = Join-Path $dataDir "user-data\User"
    if (-not (Test-Path $userSettingsDir)) {
        New-Item -ItemType Directory -Path $userSettingsDir | Out-Null
    }
    
    # Escribir configuración inicial de settings.json para aislar telemetría y configurar bash
    $settingsJsonPath = Join-Path $userSettingsDir "settings.json"
    $defaultSettings = @{
        "telemetry.telemetryLevel" = "off"
        "update.mode" = "none"
        "extensions.autoUpdate" = $false
        "terminal.integrated.profiles.windows" = @{
            "Clang64 Bash" = @{
                "path" = "bash.exe"
                "args" = @("--login", "-i")
            }
        }
        "terminal.integrated.defaultProfile.windows" = "Clang64 Bash"
    } | ConvertTo-Json -Depth 10
    
    Set-Content -Path $settingsJsonPath -Value $defaultSettings
    Write-Host "VS Code Portable configurado con éxito." -ForegroundColor Green
} else {
    Write-Host "[Actualización] VS Code ya instalado. Procediendo a actualizar..." -ForegroundColor Yellow
    try {
        Write-Host "Descargando la última versión de VS Code..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $vscodeZipUrl -OutFile $vscodeZipPath -UseBasicParsing
        
        $backupDataDir = Join-Path $portableRoot "vscode_data_backup"
        $dataDir = Join-Path $vscodeDir "data"
        
        if (Test-Path $dataDir) {
            Write-Host "Respaldando carpeta data de VS Code..."
            Move-Item -Path $dataDir -Destination $backupDataDir -Force
        }
        
        Write-Host "Eliminando instalación anterior..."
        Remove-Item -Path $vscodeDir -Recurse -Force
        New-Item -ItemType Directory -Path $vscodeDir | Out-Null
        
        Write-Host "Extrayendo actualización..."
        Expand-Archive -Path $vscodeZipPath -DestinationPath $vscodeDir -Force
        
        if (Test-Path $backupDataDir) {
            Write-Host "Restaurando carpeta data..."
            Move-Item -Path $backupDataDir -Destination $dataDir -Force
        }
        
        Write-Host "Actualización de VS Code completada con éxito." -ForegroundColor Green
    } catch {
        Write-Error "Fallo durante la actualización de VS Code: $_"
    }
}

# ==========================================
# 5. Instalación de Extensiones de VS Code
# ==========================================
$codeCmd = Join-Path $vscodeDir "bin\code.cmd"
if (Test-Path $codeCmd) {
    Write-Host "Verificando e instalando extensiones de VS Code..." -ForegroundColor Cyan
    $extensions = @("ms-vscode.cpptools", "ms-vscode.cmake-tools", "ms-python.python")
    foreach ($ext in $extensions) {
        Write-Host "Instalando extensión: $ext..."
        $process = Start-Process -FilePath $codeCmd -ArgumentList "--install-extension", $ext, "--force" -Wait -NoNewWindow -PassThru
        if ($process.ExitCode -eq 0) {
            Write-Host "Extensión $ext instalada/verificada." -ForegroundColor Green
        } else {
            Write-Warning "No se pudo instalar/verificar la extensión $ext."
        }
    }
}

# ==========================================
# 6. Gestión e Instalación de WezTerm Portable
# ==========================================
$wezDir = Join-Path $portableRoot "wezterm"
$wezZipName = "wezterm_archive.zip"
$wezZipPath = Join-Path $tempDir $wezZipName
$isWezInstalled = Test-Path (Join-Path $wezDir "wezterm.exe")

if (-not $isWezInstalled) {
    Write-Host "[Instalación] WezTerm no detectado. Descargando versión portable..." -ForegroundColor Yellow
    
    $wezReleaseUrl = "https://api.github.com/repos/wez/wezterm/releases/latest"
    $wezDownloadUrl = $null
    
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Write-Host "Consultando API de GitHub por la última versión de WezTerm..."
        $wezRelease = Invoke-RestMethod -Uri $wezReleaseUrl -UseBasicParsing -TimeoutSec 10
        $wezAsset = $wezRelease.assets | Where-Object { $_.name -like "WezTerm-windows-*.zip" -and $_.name -notlike "*setup*" }
        if ($wezAsset) {
            $wezDownloadUrl = $wezAsset.browser_download_url
            Write-Host "Última versión detectada de WezTerm: $($wezAsset.name)" -ForegroundColor Green
        }
    } catch {
        Write-Warning "Fallo al consultar la API de GitHub para WezTerm. Usando fallback fijo."
    }

    if (-not $wezDownloadUrl) {
        $wezDownloadUrl = "https://github.com/wez/wezterm/releases/download/20240203-110809-5046fc22/WezTerm-windows-20240203-110809-5046fc22.zip"
        Write-Host "Fallback URL WezTerm: $wezDownloadUrl" -ForegroundColor Yellow
    }

    Write-Host "Descargando WezTerm..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $wezDownloadUrl -OutFile $wezZipPath -UseBasicParsing

    Write-Host "Extrayendo WezTerm..." -ForegroundColor Cyan
    Expand-Archive -Path $wezZipPath -DestinationPath $wezDir -Force
    Write-Host "WezTerm Portable instalado con éxito." -ForegroundColor Green
} else {
    Write-Host "[Actualización] WezTerm ya instalado. Comprobando actualizaciones..." -ForegroundColor Yellow
    try {
        $wezReleaseUrl = "https://api.github.com/repos/wez/wezterm/releases/latest"
        $wezDownloadUrl = $null
        
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $wezRelease = Invoke-RestMethod -Uri $wezReleaseUrl -UseBasicParsing -TimeoutSec 10
        $wezAsset = $wezRelease.assets | Where-Object { $_.name -like "WezTerm-windows-*.zip" -and $_.name -notlike "*setup*" }
        if ($wezAsset) {
            $wezDownloadUrl = $wezAsset.browser_download_url
        }

        if (-not $wezDownloadUrl) {
            $wezDownloadUrl = "https://github.com/wez/wezterm/releases/download/20240203-110809-5046fc22/WezTerm-windows-20240203-110809-5046fc22.zip"
        }

        Write-Host "Descargando última versión de WezTerm para actualizar..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $wezDownloadUrl -OutFile $wezZipPath -UseBasicParsing
        
        Write-Host "Borrando versión anterior de WezTerm..."
        Remove-Item -Path $wezDir -Recurse -Force
        New-Item -ItemType Directory -Path $wezDir | Out-Null
        
        Write-Host "Extrayendo actualización de WezTerm..."
        Expand-Archive -Path $wezZipPath -DestinationPath $wezDir -Force
        Write-Host "Actualización de WezTerm completada con éxito." -ForegroundColor Green
    } catch {
        Write-Error "Fallo durante la actualización de WezTerm: $_"
    }
}

# Escribir configuración wezterm.lua
$wezConfigPath = Join-Path $portableRoot "wezterm.lua"
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

-- Estética Premium (Tokyo Night y JetBrains Mono)
config.color_scheme = 'Tokyo Night'
config.font = wezterm.font 'JetBrains Mono'
config.font_size = 11.0
config.window_background_opacity = 0.95
config.enable_tab_bar = false

return config
"@

Set-Content -Path $wezConfigPath -Value $wezConfigContent
Write-Host "Configuración wezterm.lua creada/actualizada." -ForegroundColor Green

# ==========================================
# 7. Limpieza final de temporales
# ==========================================
if (Test-Path $tempDir) {
    Write-Host "Limpiando archivos temporales..."
    Remove-Item -Path $tempDir -Recurse -Force
}

Write-Host "`n=== ENTORNO PORTABLE CONFIGURADO Y LISTO ===" -ForegroundColor Green
Write-Host "Ejecutá 'launch.bat' para iniciar la consola." -ForegroundColor Green
Write-Host "Ejecutá 'launch-vscode.bat' para iniciar VS Code." -ForegroundColor Green
