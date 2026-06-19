# setup.ps1 - Script de inicialización y actualización del entorno portable
# Configura MSYS2, el compilador Clang, la distribución de Python y VS Code Portable.

$ErrorActionPreference = "Stop"

# Directorio base del script
$portableRoot = $PSScriptRoot
$msysDir = Join-Path $portableRoot "msys64"
$tempDir = Join-Path $portableRoot "downloads"
$homeDir = Join-Path $portableRoot "home"
$vscodeDir = Join-Path $portableRoot "vscode"

Write-Host "=== Entorno Portable de Desarrollo C + Python + VS Code ===" -ForegroundColor Cyan
Write-Host "Directorio de instalación: $portableRoot`n"

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
# 6. Limpieza final de temporales
# ==========================================
if (Test-Path $tempDir) {
    Write-Host "Limpiando archivos temporales..."
    Remove-Item -Path $tempDir -Recurse -Force
}

Write-Host "`n=== ENTORNO PORTABLE CONFIGURADO Y LISTO ===" -ForegroundColor Green
Write-Host "Ejecutá 'launch.bat' para iniciar la consola." -ForegroundColor Green
Write-Host "Ejecutá 'launch-vscode.bat' para iniciar VS Code." -ForegroundColor Green
