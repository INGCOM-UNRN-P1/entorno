param(
    [string]$HomeDirName = "home",
    [switch]$ImportHostConfig,
    [switch]$SkipUpdate
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
$isUpdateMode = Test-Path (Join-Path $portableRoot ".install_complete")

# Iniciar log de instalación
$logPath = Join-Path $portableRoot "install.log"
$transcriptStarted = $false
try {
    Start-Transcript -Path $logPath -Force -ErrorAction Stop | Out-Null
    $transcriptStarted = $true
} catch {
    Write-Warning "No se pudo iniciar el log oficial de PowerShell. La instalación continuará sin registrar salida en archivo."
}

# Escribir información del entorno y fecha/hora de inicio en el log
Write-Host "======================================================================"
Write-Host "LOG DE INSTALACIÓN DETALLADO"
Write-Host "======================================================================"
Write-Host "Fecha/Hora de Inicio : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "Entorno de Ejecución : $($PSVersionTable.OS) / OS: $($env:OS)"
Write-Host "Nombre del Equipo    : $($env:COMPUTERNAME)"
Write-Host "Usuario Ejecutor     : $($env:USERNAME)"
Write-Host "Versión PowerShell   : $($PSVersionTable.PSVersion)"
Write-Host "Ruta de la Carpeta   : $portableRoot"
Write-Host "Parámetros Utilizados: -HomeDirName '$HomeDirName' -ImportHostConfig: $ImportHostConfig"
Write-Host "Modo de Ejecución    : $(if ($isUpdateMode) { 'Actualización' } else { 'Instalación/Finalización' })"
Write-Host "======================================================================`n"

try {
    # ==========================================
    # 0. Actualización automática de scripts
    # ==========================================
    if ($SkipUpdate) {
        Write-Host "=== Omitiendo actualización de scripts (-SkipUpdate) ===" -ForegroundColor DarkGray
    } else {
        Write-Host "=== Comprobando actualizaciones de los scripts del entorno ===" -ForegroundColor Cyan
        
        $didUpdate = $false
        $repoOwner = "INGCOM-UNRN-P1"
    $repoName = "entorno"
    $branch = "main"
    $rawBaseUrl = "https://raw.githubusercontent.com/$repoOwner/$repoName/$branch"
    $isGitRepo = Test-Path (Join-Path $portableRoot ".git")

    if ($isGitRepo) {
        Write-Host "Repositorio Git detectado. Intentando actualizar vía 'git pull'..." -ForegroundColor Cyan
        
        $gitExe = "git"
        $msysGit = Join-Path $portableRoot "msys64\usr\bin\git.exe"
        if (Test-Path $msysGit) {
            $gitExe = $msysGit
        }
        
        try {
            $process = Start-Process -FilePath $gitExe -ArgumentList "pull" -WorkingDirectory $portableRoot -Wait -NoNewWindow -PassThru -ErrorAction Stop
            if ($process.ExitCode -eq 0) {
                Write-Host "Scripts actualizados con éxito a través de Git.`n" -ForegroundColor Green
                $didUpdate = $true
            } else {
                Write-Warning "Fallo al realizar git pull (código de salida: $($process.ExitCode)). Se continuará con la ejecución local."
            }
        } catch {
            Write-Warning "No se pudo ejecutar git para la actualización automática: $_. Se continuará con la ejecución local."
        }
    } else {
        $hasExistingScripts = Test-Path (Join-Path $portableRoot "launch.bat")
        $shouldUpdate = $true
        
        if ($hasExistingScripts) {
            Write-Host "Se detectaron scripts de consola existentes en el directorio." -ForegroundColor Yellow
            $choice = Read-Host "¿Deseás actualizar todos los scripts del entorno a la última versión desde GitHub? (s/n)"
            if ($choice -notmatch "^[sS]$") {
                $shouldUpdate = $false
                Write-Host "Se omite la actualización de los scripts. Se utilizarán las versiones locales.`n" -ForegroundColor Yellow
            }
        }
        
        if ($shouldUpdate) {
            Write-Host "No se detectó un repositorio de Git (carpeta standalone). Descargando última versión de los scripts..." -ForegroundColor Cyan
            
            $filesToDownload = @(
                "setup.ps1",
                "launch.bat",
                "launch.ps1",
                "launch-vscode.bat",
                "launch-vscode.ps1",
                "clean-shared-host.ps1",
                "customize-terminal.ps1",
                "customize-terminal.bat",
                "package-env.ps1",
                "bin/install-lib.sh",
                "bin/configure-git.sh",
                "bin/update-packages.sh",
                "bin/diagnose-env.sh",
                "README.md",
                "plan.md",
                "GEMINI.md"
            )
            
            foreach ($file in $filesToDownload) {
                $fileUrl = "$rawBaseUrl/$file"
                $destinationPath = Join-Path $portableRoot $file
                
                # Asegurar la existencia del directorio padre (ej: bin/)
                $parentDir = Split-Path -Parent $destinationPath
                if (-not (Test-Path $parentDir)) {
                    New-Item -ItemType Directory -Path $parentDir | Out-Null
                }

                try {
                    Write-Host "Actualizando $file..." -ForegroundColor Gray
                    # Descarga con reintentos
                    $attempts = 0
                    $success = $false
                    while (-not $success -and $attempts -lt 3) {
                        $attempts++
                        try {
                            Invoke-WebRequest -Uri $fileUrl -OutFile $destinationPath -UseBasicParsing -ErrorAction Stop
                            $success = $true
                        } catch {
                            if ($attempts -lt 3) {
                                Start-Sleep -Seconds 1
                            } else {
                                throw $_
                            }
                        }
                    }
                } catch {
                    Write-Warning "No se pudo actualizar el archivo $($file): $_"
                }
            }
            Write-Host "Actualización de scripts completada.`n" -ForegroundColor Green
            $didUpdate = $true
        }
    }

    if ($didUpdate) {
        Write-Host "Relanzando setup.ps1 para aplicar la versión más reciente en memoria..." -ForegroundColor Magenta
        $newArgs = @("-SkipUpdate")
        if ($HomeDirName -ne "home") { 
            $newArgs += "-HomeDirName"
            $newArgs += $HomeDirName 
        }
        if ($ImportHostConfig) { $newArgs += "-ImportHostConfig" }
        
        $localSetup = Join-Path $portableRoot "setup.ps1"
        & $localSetup @newArgs
        exit $LASTEXITCODE
    }
}

# Escribir archivo de configuración .env local
    $envFilePath = Join-Path $portableRoot ".env"
    Set-Content -Path $envFilePath -Value ('set "HOME_DIR_NAME={0}"' -f $HomeDirName)

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
if ($isUpdateMode) {
    Write-Host ">>> MODO ACTUALIZACIÓN: Se detectó una instalación previa completa. <<<" -ForegroundColor Green
} else {
    Write-Host ">>> MODO INSTALACIÓN/FINALIZACIÓN: Completando o finalizando instalación... <<<" -ForegroundColor Yellow
}
Write-Host "Directorio de instalación: $portableRoot`n"

# Validar espacios o caracteres no ASCII en la ruta de instalación (causan errores graves con Make/compiladores)
$hasSpaces = $portableRoot -match ' '
$hasNonAscii = $portableRoot -match '[^\u0000-\u007F]'

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
        return
    }
    Write-Host "Continuando con la instalación bajo riesgo del usuario...`n" -ForegroundColor Yellow
}

# Asegurar que existan los directorios iniciales y sus archivos skel
if (-not (Test-Path $homeDir)) {
    New-Item -ItemType Directory -Path $homeDir | Out-Null
    Write-Host "Creado directorio HOME portable: $homeDir" -ForegroundColor Green
}

$bashProfilePath = Join-Path $homeDir ".bash_profile"
if (-not (Test-Path $bashProfilePath)) {
    $bashProfileContent = "if [ -f `"`${HOME}/.bashrc`" ] ; then`n  source `"`${HOME}/.bashrc`"`nfi"
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($bashProfilePath, $bashProfileContent, $utf8NoBom)
}

$bashrcPath = Join-Path $homeDir ".bashrc"
if (-not (Test-Path $bashrcPath)) {
    $bashrcContent = "# .bashrc`n# Aquí podés agregar tus alias y funciones personalizadas.`n"
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($bashrcPath, $bashrcContent, $utf8NoBom)
}

if (-not (Test-Path $tempDir)) {
    New-Item -ItemType Directory -Path $tempDir | Out-Null
}

# ==========================================
# 1. Gestión e Instalación de MSYS2
# ==========================================
$isMsysInstalled = Test-Path (Join-Path $msysDir "usr\bin\bash.exe")
$isMsysComplete = Test-Path (Join-Path $portableRoot ".msys_complete")

if (-not $isMsysInstalled -or -not $isMsysComplete) {
    if ($isMsysInstalled -and -not $isMsysComplete) {
        Write-Host "Se detectó una instalación previa incompleta de MSYS2. Limpiando para reinstalar base..." -ForegroundColor Yellow
        if (Test-Path $msysDir) {
            Remove-Item -Path $msysDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    Write-Host "[Instalación] MSYS2 no detectado o incompleto. Iniciando descarga..." -ForegroundColor Yellow

    $releasesUrl = "https://api.github.com/repos/msys2/msys2-installer/releases"
    $downloadUrl = $null
    $fileName = $null

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Write-Host "Consultando API de GitHub por la última versión estable de MSYS2..."
        $releases = Invoke-RestMethod -Uri $releasesUrl -UseBasicParsing -TimeoutSec 10
        # Buscar la primera versión que no sea un build 'nightly' y que contenga el archivo sfx.exe
        foreach ($release in $releases) {
            if ($release.tag_name -notlike "*nightly*") {
                $asset = $release.assets | Where-Object { $_.name -like "msys2-base-x86_64-*.sfx.exe" }
                if ($asset) {
                    $downloadUrl = $asset.browser_download_url
                    $fileName = $asset.name
                    Write-Host "Última versión estable detectada: $fileName (Tag: $($release.tag_name))" -ForegroundColor Green
                    break
                }
            }
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
    $shaUrl = "$downloadUrl.sha256"
    $isDownloadedAndValid = $false

    # Verificar si ya existe una descarga previa válida para evitar descargas duplicadas en reintentos
    if (Test-Path $exePath) {
        Write-Host "Se detectó un instalador de MSYS2 descargado previamente. Verificando firma..." -ForegroundColor Yellow
        try {
            if (-not (Test-Path $shaPath)) {
                Invoke-WebRequest -Uri $shaUrl -OutFile $shaPath -UseBasicParsing -ErrorAction Stop
            }
            $shaContent = (Get-Content $shaPath -Raw).Trim()
            if ($shaContent -match '<html' -or $shaContent -match '<!DOCTYPE') {
                throw "El archivo de firma contiene HTML (posible página de error del servidor)."
            }
            $expectedHash = $shaContent.Split(" ")[0].Trim().ToLower()
            if ($expectedHash -notmatch '^[0-9a-f]{64}$') {
                $truncatedHash = $expectedHash
                if ($truncatedHash.Length -gt 100) { $truncatedHash = $truncatedHash.Substring(0, 100) + "..." }
                throw "El hash esperado recuperado no tiene un formato SHA256 válido: '$truncatedHash'"
            }
            $actualHash = (Get-FileHash -Path $exePath -Algorithm SHA256).Hash.ToLower()
            if ($actualHash -eq $expectedHash) {
                $isDownloadedAndValid = $true
                Write-Host "El archivo existente es válido. Se omitirá la descarga." -ForegroundColor Green
            } else {
                Write-Host "La firma del archivo existente no coincide. Se procederá a descargar nuevamente." -ForegroundColor Yellow
                Remove-Item -Path $shaPath -Force -ErrorAction SilentlyContinue
                Remove-Item -Path $exePath -Force -ErrorAction SilentlyContinue
            }
        } catch {
            Write-Host "No se pudo verificar la firma del archivo existente. Se procederá a descargar nuevamente. Detalles: $_" -ForegroundColor Yellow
            Remove-Item -Path $shaPath -Force -ErrorAction SilentlyContinue
        }
    }

    if (-not $isDownloadedAndValid) {
        Write-Host "Descargando $fileName..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $downloadUrl -OutFile $exePath -UseBasicParsing

        Write-Host "Descargando verificación SHA256..." -ForegroundColor Cyan
        try {
            $attempts = 0
            $success = $false
            while (-not $success -and $attempts -lt 3) {
                $attempts++
                try {
                    Invoke-WebRequest -Uri $shaUrl -OutFile $shaPath -UseBasicParsing -ErrorAction Stop
                    $success = $true
                } catch {
                    if ($attempts -lt 3) {
                        Start-Sleep -Seconds 1
                    } else {
                        throw $_
                    }
                }
            }
        } catch {
            throw "Error fatal al descargar el archivo de firma SHA256 desde: $shaUrl. Detalles: $_"
        }

        try {
            $shaContent = (Get-Content $shaPath -Raw).Trim()
            if ($shaContent -match '<html' -or $shaContent -match '<!DOCTYPE') {
                throw "El archivo de firma contiene HTML (posible página de error del servidor o rate limit)."
            }
            $expectedHash = $shaContent.Split(" ")[0].Trim().ToLower()
            if ($expectedHash -notmatch '^[0-9a-f]{64}$') {
                $truncatedHash = $expectedHash
                if ($truncatedHash.Length -gt 100) { $truncatedHash = $truncatedHash.Substring(0, 100) + "..." }
                throw "El hash esperado recuperado no tiene un formato SHA256 válido: '$truncatedHash'"
            }
            $actualHash = (Get-FileHash -Path $exePath -Algorithm SHA256).Hash.ToLower()

            if ($actualHash -ne $expectedHash) {
                throw "El hash calculado ($actualHash) no coincide con el esperado ($expectedHash)."
            }
            Write-Host "Firma SHA256 verificada con éxito." -ForegroundColor Green
        } catch {
            Remove-Item -Path $shaPath -Force -ErrorAction SilentlyContinue
            throw "Falla crítica en la verificación de firma SHA256. La instalación se detiene. Detalles: $_"
        }
    }

    Write-Host "Extrayendo entorno base MSYS2 en: $portableRoot" -ForegroundColor Cyan
    $process = Start-Process -FilePath $exePath -ArgumentList "-y", "-o$portableRoot" -Wait -NoNewWindow -PassThru
    if ($process.ExitCode -ne 0) {
        throw "Error durante la extracción de MSYS2 (código de salida: $($process.ExitCode))"
    }
    Write-Host "Instalación base de MSYS2 completada con éxito.`n" -ForegroundColor Green
} else {
    Write-Host "[Actualización] MSYS2 base ya instalado y verificado." -ForegroundColor Green
}

if ($isUpdateMode -or -not $isMsysComplete) {
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

        # Agregar banner institucional (UNRN Andina - Programación 1)
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
        
        $content = Get-Content $bashrcPath -Raw
        if (-not $content.Contains($startInstMarker)) {
            Add-Content -Path $bashrcPath -Value $instBanner
        }
        
        Write-Host "Configuración de terminal personalizada guardada." -ForegroundColor Green
    }
    Set-Content -Path (Join-Path $portableRoot ".msys_complete") -Value "Complete"
} else {
    Write-Host "[Actualización] MSYS2 y herramientas de desarrollo ya configuradas. Se omite pacman para agilizar la ejecución." -ForegroundColor Green
}

# ==========================================
# 4. Gestión e Instalación de VS Code Portable
# ==========================================
$vscodeZipUrl = "https://code.visualstudio.com/sha/download?build=stable&os=win32-x64-archive"
$vscodeZipName = "vscode_archive.zip"
$vscodeZipPath = Join-Path $tempDir $vscodeZipName
$isCodeInstalled = Test-Path (Join-Path $vscodeDir "Code.exe")
$isCodeComplete = Test-Path (Join-Path $portableRoot ".vscode_complete")

# Resolver la URL de redirección final de VS Code
$resolvedVscodeUrl = $vscodeZipUrl
if ($isUpdateMode -or -not $isCodeComplete) {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $request = [System.Net.WebRequest]::Create($vscodeZipUrl)
        $request.Method = "HEAD"
        $request.AllowAutoRedirect = $true
        $request.Timeout = 10000
        $response = $request.GetResponse()
        $resolvedVscodeUrl = $response.ResponseUri.AbsoluteUri
        $response.Close()
    } catch {
        Write-Warning "No se pudo resolver la URL final de redirección de VS Code. Se usará la URL directa."
    }
}

if (-not $isUpdateMode -and $isCodeComplete -and $isCodeInstalled) {
    Write-Host "VS Code ya se encuentra instalado y configurado de una ejecución previa." -ForegroundColor Green
} else {
    $shouldInstallOrUpdateVscode = $false
    if ($isUpdateMode) {
        $installedVscodeVersionFile = Join-Path $vscodeDir ".version"
        $installedVscodeUrl = ""
        if (Test-Path $installedVscodeVersionFile) {
            $installedVscodeUrl = Get-Content $installedVscodeVersionFile -Raw
        }
        
        if ($resolvedVscodeUrl -ne $installedVscodeUrl) {
            Write-Host "Hay una nueva versión de VS Code disponible para actualizar." -ForegroundColor Yellow
            $shouldInstallOrUpdateVscode = $true
        } else {
            Write-Host "VS Code ya se encuentra en la versión más reciente ($resolvedVscodeUrl)." -ForegroundColor Green
        }
    } else {
        $shouldInstallOrUpdateVscode = $true
    }

    if ($shouldInstallOrUpdateVscode) {
        if (-not $isUpdateMode -and $isCodeInstalled) {
            Write-Host "Detectada instalación incompleta de VS Code. Reinstalando..." -ForegroundColor Yellow
            Remove-Item -Path $vscodeDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        $vscodeZipValid = $false
        if (Test-Path $vscodeZipPath) {
            Write-Host "Se detectó una descarga previa de VS Code. Verificando..." -ForegroundColor Yellow
            try {
                $fileSize = (Get-Item $vscodeZipPath).Length
                if ($fileSize -gt 50MB) {
                    $vscodeZipValid = $true
                    Write-Host "El archivo ZIP previo es válido. Se omitirá la descarga." -ForegroundColor Green
                } else {
                    Write-Host "El archivo ZIP previo está incompleto o dañado. Se volverá a descargar." -ForegroundColor Yellow
                }
            } catch {
                Write-Host "No se pudo verificar el archivo ZIP previo. Se volverá a descargar." -ForegroundColor Yellow
            }
        }
        
        if (-not $vscodeZipValid) {
            Write-Host "Descargando VS Code..." -ForegroundColor Cyan
            Invoke-WebRequest -Uri $resolvedVscodeUrl -OutFile $vscodeZipPath -UseBasicParsing
        }
        
        $backupDataDir = Join-Path $portableRoot "vscode_data_backup"
        $dataDir = Join-Path $vscodeDir "data"
        
        if ($isUpdateMode -and (Test-Path $dataDir)) {
            Write-Host "Respaldando carpeta data de VS Code..." -ForegroundColor Cyan
            if (Test-Path $backupDataDir) {
                Remove-Item -Path $backupDataDir -Recurse -Force -ErrorAction SilentlyContinue
            }
            Move-Item -Path $dataDir -Destination $backupDataDir -Force
        }
        
        if (Test-Path $vscodeDir) {
            Write-Host "Eliminando instalación anterior de VS Code..." -ForegroundColor Cyan
            Remove-Item -Path $vscodeDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        New-Item -ItemType Directory -Path $vscodeDir | Out-Null
        
        Write-Host "Extrayendo VS Code..." -ForegroundColor Cyan
        Expand-Archive -Path $vscodeZipPath -DestinationPath $vscodeDir -Force
        
        if ($isUpdateMode -and (Test-Path $backupDataDir)) {
            Write-Host "Restaurando carpeta data..." -ForegroundColor Cyan
            Move-Item -Path $backupDataDir -Destination $dataDir -Force
        } else {
            # Activar el Modo Portable creando la carpeta 'data'
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
        }
        
        Set-Content -Path (Join-Path $vscodeDir ".version") -Value $resolvedVscodeUrl
        Set-Content -Path (Join-Path $portableRoot ".vscode_complete") -Value "Complete"
        Write-Host "VS Code Portable configurado/actualizado con éxito." -ForegroundColor Green
    }
}

# ==========================================
# 5. Instalación de Extensiones de VS Code
# ==========================================
$codeCmd = Join-Path $vscodeDir "bin\code.cmd"
if (Test-Path $codeCmd) {
    if ($isUpdateMode -or -not $isCodeComplete) {
        Write-Host "Verificando e instalando extensiones de VS Code..." -ForegroundColor Cyan
        $extensions = @("ms-vscode.cpptools", "ms-vscode.cmake-tools", "ms-python.python")
        foreach ($ext in $extensions) {
            Write-Host "Instalando/verificando extensión: $ext..."
            $process = Start-Process -FilePath $codeCmd -ArgumentList "--install-extension", $ext, "--force" -Wait -NoNewWindow -PassThru
            if ($process.ExitCode -eq 0) {
                Write-Host "Extensión $ext instalada/verificada." -ForegroundColor Green
            } else {
                Write-Warning "No se pudo instalar/verificar la extensión $ext."
            }
        }
    }
}

# ==========================================
# 5.5. Gestión e Instalación de GitHub CLI (gh)
# ==========================================
$ghExe = Join-Path $portableRoot "bin\gh.exe"
$ghZipPath = Join-Path $tempDir "gh_archive.zip"
$isGhInstalled = Test-Path $ghExe
$isGhComplete = Test-Path (Join-Path $portableRoot ".gh_complete")

$ghDownloadUrl = ""
$shouldInstallOrUpdateGh = $false

if ($isUpdateMode -or -not $isGhComplete -or -not $isGhInstalled) {
    Write-Host "Obteniendo URL de descarga de GitHub CLI..." -ForegroundColor Cyan
    try {
        $ghReleaseUrl = "https://api.github.com/repos/cli/cli/releases/latest"
        $ghRelease = Invoke-RestMethod -Uri $ghReleaseUrl -UseBasicParsing -TimeoutSec 10
        $ghAsset = $ghRelease.assets | Where-Object { $_.name -like "*windows_amd64.zip" }
        if ($ghAsset) {
            $ghDownloadUrl = $ghAsset.browser_download_url
            Write-Host "Última versión detectada de GitHub CLI: $($ghAsset.name)" -ForegroundColor Green
        }
    } catch {
        Write-Warning "Fallo al consultar la API de GitHub para GitHub CLI. Usando fallback fijo."
    }

    if (-not $ghDownloadUrl) {
        $ghDownloadUrl = "https://github.com/cli/cli/releases/download/v2.49.0/gh_2.49.0_windows_amd64.zip"
        Write-Host "Fallback URL GitHub CLI: $ghDownloadUrl" -ForegroundColor Yellow
    }
}

if (-not $isUpdateMode -and $isGhComplete -and $isGhInstalled) {
    Write-Host "GitHub CLI ya está instalado y configurado de una ejecución previa." -ForegroundColor Green
} else {
    if ($isUpdateMode) {
        $installedGhVersionFile = Join-Path $portableRoot "bin\.gh_version"
        $installedGhUrl = ""
        if (Test-Path $installedGhVersionFile) {
            $installedGhUrl = Get-Content $installedGhVersionFile -Raw
        }
        if ($ghDownloadUrl -ne $installedGhUrl) {
            Write-Host "Hay una nueva versión de GitHub CLI disponible para actualizar." -ForegroundColor Yellow
            $shouldInstallOrUpdateGh = $true
        } else {
            Write-Host "GitHub CLI ya se encuentra en la versión más reciente ($ghDownloadUrl)." -ForegroundColor Green
        }
    } else {
        $shouldInstallOrUpdateGh = $true
    }

    if ($shouldInstallOrUpdateGh) {
        if (-not $isUpdateMode -and $isGhInstalled) {
            Write-Host "Detectada instalación incompleta de GitHub CLI. Reinstalando..." -ForegroundColor Yellow
            Remove-Item -Path $ghExe -Force -ErrorAction SilentlyContinue
        }

        Write-Host "Descargando GitHub CLI..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $ghDownloadUrl -OutFile $ghZipPath -UseBasicParsing

        $ghTempDir = Join-Path $portableRoot "gh_temp"
        if (Test-Path $ghTempDir) {
            Remove-Item -Path $ghTempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        New-Item -ItemType Directory -Path $ghTempDir | Out-Null
        
        Write-Host "Extrayendo GitHub CLI..." -ForegroundColor Cyan
        Expand-Archive -Path $ghZipPath -DestinationPath $ghTempDir -Force
        
        $extractedGhExe = Get-ChildItem -Path $ghTempDir -Filter "gh.exe" -Recurse | Select-Object -First 1
        if ($extractedGhExe) {
            $binDir = Join-Path $portableRoot "bin"
            if (-not (Test-Path $binDir)) {
                New-Item -ItemType Directory -Path $binDir | Out-Null
            }
            Move-Item -Path $extractedGhExe.FullName -Destination $ghExe -Force
            Write-Host "GitHub CLI copiado con éxito a $ghExe." -ForegroundColor Green
        } else {
            Write-Error "No se pudo encontrar gh.exe en el paquete extraído."
        }

        Remove-Item -Path $ghTempDir -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $ghZipPath -Force -ErrorAction SilentlyContinue

        Set-Content -Path (Join-Path $portableRoot "bin\.gh_version") -Value $ghDownloadUrl
        Set-Content -Path (Join-Path $portableRoot ".gh_complete") -Value "Complete"
        Write-Host "GitHub CLI instalado con éxito." -ForegroundColor Green
    }
}

# ==========================================
# 6. Gestión e Instalación de WezTerm Portable
# ==========================================
$wezDir = Join-Path $portableRoot "wezterm"
$wezZipName = "wezterm_archive.zip"
$wezZipPath = Join-Path $tempDir $wezZipName
$isWezInstalled = Test-Path (Join-Path $wezDir "wezterm.exe")
$isWezComplete = Test-Path (Join-Path $portableRoot ".wezterm_complete")

# Obtener URL de descarga más reciente de WezTerm
$wezReleaseUrl = "https://api.github.com/repos/wez/wezterm/releases/latest"
$wezDownloadUrl = $null

if ($isUpdateMode -or -not $isWezComplete) {
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
}

if (-not $isUpdateMode -and $isWezComplete -and $isWezInstalled) {
    Write-Host "WezTerm ya está instalado y configurado de una ejecución previa." -ForegroundColor Green
} else {
    $shouldInstallOrUpdateWez = $false
    if ($isUpdateMode) {
        $installedWezVersionFile = Join-Path $wezDir ".version"
        $installedWezUrl = ""
        if (Test-Path $installedWezVersionFile) {
            $installedWezUrl = Get-Content $installedWezVersionFile -Raw
        }
        
        if ($wezDownloadUrl -ne $installedWezUrl) {
            Write-Host "Hay una nueva versión de WezTerm disponible para actualizar." -ForegroundColor Yellow
            $shouldInstallOrUpdateWez = $true
        } else {
            Write-Host "WezTerm ya se encuentra en la versión más reciente ($wezDownloadUrl)." -ForegroundColor Green
        }
    } else {
        $shouldInstallOrUpdateWez = $true
    }

    if ($shouldInstallOrUpdateWez) {
        if (-not $isUpdateMode -and $isWezInstalled) {
            Write-Host "Detectada instalación incompleta de WezTerm. Reinstalando..." -ForegroundColor Yellow
            Remove-Item -Path $wezDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        $isWezZipValid = $false
        if (Test-Path $wezZipPath) {
            Write-Host "Se detectó un archivo ZIP de WezTerm descargado previamente. Verificando..." -ForegroundColor Yellow
            try {
                $fileSize = (Get-Item $wezZipPath).Length
                if ($fileSize -gt 10MB) {
                    $isWezZipValid = $true
                    Write-Host "El archivo ZIP previo de WezTerm es válido. Se omitirá la descarga." -ForegroundColor Green
                } else {
                    Write-Host "El archivo ZIP previo de WezTerm está incompleto. Se volverá a descargar." -ForegroundColor Yellow
                }
            } catch {
                Write-Host "No se pudo verificar el archivo ZIP previo de WezTerm. Se volverá a descargar." -ForegroundColor Yellow
            }
        }

        if (-not $isWezZipValid) {
            Write-Host "Descargando WezTerm..." -ForegroundColor Cyan
            Invoke-WebRequest -Uri $wezDownloadUrl -OutFile $wezZipPath -UseBasicParsing
        }

        if (Test-Path $wezDir) {
            Write-Host "Eliminando instalación anterior de WezTerm..." -ForegroundColor Cyan
            Remove-Item -Path $wezDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        New-Item -ItemType Directory -Path $wezDir | Out-Null

        Write-Host "Extrayendo WezTerm..." -ForegroundColor Cyan
        Expand-Archive -Path $wezZipPath -DestinationPath $wezDir -Force
        
        # Si la descompresión creó un subdirectorio (ej: WezTerm-windows-...), mover su contenido a la raíz de $wezDir
        $subDir = Get-ChildItem -Path $wezDir -Directory | Where-Object { Test-Path (Join-Path $_.FullName "wezterm.exe") }
        if ($subDir) {
            Write-Host "Aplanando estructura de carpetas de WezTerm..." -ForegroundColor Cyan
            Get-ChildItem -Path $subDir.FullName | Move-Item -Destination $wezDir -Force
            Remove-Item -Path $subDir.FullName -Recurse -Force
        }
        
        Set-Content -Path (Join-Path $wezDir ".version") -Value $wezDownloadUrl
        Set-Content -Path (Join-Path $portableRoot ".wezterm_complete") -Value "Complete"
        Write-Host "WezTerm Portable instalado con éxito." -ForegroundColor Green
    }
}

# Escribir configuración wezterm.lua
$wezConfigPath = Join-Path $portableRoot "wezterm.lua"
if (-not (Test-Path $wezConfigPath) -or $isUpdateMode -or $shouldInstallOrUpdateWez) {
    $wezConfigContent = @"
local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- Configurar directorio raiz portable de forma determinista
local portable_root = wezterm.config_dir:gsub("[\\]+", "/")
if not portable_root:match("/$") then
  portable_root = portable_root .. "/"
end

local bash_path = portable_root .. "msys64/usr/bin/bash.exe"
config.default_prog = { bash_path, "--login", "-i" }

-- Configurar entorno heredado forzando el HOME portable (aislado del sistema host)
local home_dir = portable_root .. "$HomeDirName"
config.default_cwd = home_dir

local path_env = os.getenv("PATH")
if path_env then path_env = path_env:gsub("[\\]+", "/") else path_env = "" end

local custom_path = portable_root .. "bin;" .. portable_root .. "msys64/clang64/bin;" .. portable_root .. "msys64/usr/bin;" .. path_env

config.set_environment_variables = {
  MSYSTEM = "CLANG64",
  MSYS2_PATH_TYPE = "inherit",
  PORTABLE_ROOT = portable_root,
  CHERE_INVOKING = "1",
  HOME = home_dir,
  PATH = custom_path,
  LANG = "es_AR.UTF-8",
}

-- Estetica Premium (Tokyo Night y JetBrains Mono)
config.color_scheme = 'Tokyo Night'
config.font = wezterm.font 'JetBrains Mono'
config.font_size = 11.0
config.window_background_opacity = 0.95
config.enable_tab_bar = false

return config
"@
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($wezConfigPath, $wezConfigContent, $utf8NoBom)
    Write-Host "Configuración wezterm.lua creada/actualizada." -ForegroundColor Green
}

# ==========================================
# 7. Importación de configuración del host (opcional)
# ==========================================
if ($ImportHostConfig) {
    Write-Host "Importando configuración desde el host..." -ForegroundColor Cyan
    
    # 1. SSH Config
    $hostSshDir = Join-Path $env:USERPROFILE ".ssh"
    $portableSshDir = Join-Path $homeDir ".ssh"
    if (Test-Path $hostSshDir) {
        Write-Host "Copiando llaves SSH desde $hostSshDir..." -ForegroundColor Cyan
        if (-not (Test-Path $portableSshDir)) {
            New-Item -ItemType Directory -Path $portableSshDir | Out-Null
        }
        Copy-Item -Path (Join-Path $hostSshDir "*") -Destination $portableSshDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Configuración de SSH copiada." -ForegroundColor Green
    } else {
        Write-Host "No se encontró la configuración de SSH en el host." -ForegroundColor Yellow
    }

    # 2. Git Config
    $hostGitConfig = Join-Path $env:USERPROFILE ".gitconfig"
    $portableGitConfig = Join-Path $homeDir ".gitconfig"
    if (Test-Path $hostGitConfig) {
        Write-Host "Copiando .gitconfig desde $hostGitConfig..." -ForegroundColor Cyan
        Copy-Item -Path $hostGitConfig -Destination $portableGitConfig -Force
        Write-Host "Configuración de Git copiada." -ForegroundColor Green
    } else {
        Write-Host "No se encontró el archivo .gitconfig en el host." -ForegroundColor Yellow
    }
    
    $hostGitCreds = Join-Path $env:USERPROFILE ".git-credentials"
    $portableGitCreds = Join-Path $homeDir ".git-credentials"
    if (Test-Path $hostGitCreds) {
        Write-Host "Copiando .git-credentials desde $hostGitCreds..." -ForegroundColor Cyan
        Copy-Item -Path $hostGitCreds -Destination $portableGitCreds -Force
        Write-Host "Credenciales de Git copiadas." -ForegroundColor Green
    }

    # 3. VS Code settings.json
    $hostVscodeSettings = Join-Path $env:APPDATA "Code\User\settings.json"
    $portableVscodeData = Join-Path $vscodeDir "data\user-data\User"
    $portableVscodeSettings = Join-Path $portableVscodeData "settings.json"
    
    if (Test-Path $hostVscodeSettings) {
        Write-Host "Importando y adaptando settings.json de VS Code..." -ForegroundColor Cyan
        if (-not (Test-Path $portableVscodeData)) {
            New-Item -ItemType Directory -Path $portableVscodeData | Out-Null
        }
        
        try {
            $hostSettingsContent = Get-Content $hostVscodeSettings -Raw
            $settingsObj = $hostSettingsContent | ConvertFrom-Json
            if (-not $settingsObj) {
                $settingsObj = @{}
            }
        } catch {
            Write-Warning "No se pudo leer o procesar el settings.json del host. Se va a usar una configuración limpia."
            $settingsObj = @{}
        }
        
        # Forzar/Asegurar parámetros de portabilidad e inhabilitar IA/Copilot
        $settingsObj | Add-Member -NotePropertyName "telemetry.telemetryLevel" -NotePropertyValue "off" -Force
        $settingsObj | Add-Member -NotePropertyName "update.mode" -NotePropertyValue "none" -Force
        $settingsObj | Add-Member -NotePropertyName "extensions.autoUpdate" -NotePropertyValue $false -Force
        $settingsObj | Add-Member -NotePropertyName "chat.disableAIFeatures" -NotePropertyValue $true -Force
        $settingsObj | Add-Member -NotePropertyName "github.copilot.enable" -NotePropertyValue @{ "*" = $false } -Force
        
        # Configurar el perfil de terminal Bash Clang64
        $terminalProfiles = @{
            "Clang64 Bash" = @{
                "path" = "bash.exe"
                "args" = @("--login", "-i")
            }
        }
        $settingsObj | Add-Member -NotePropertyName "terminal.integrated.profiles.windows" -NotePropertyValue $terminalProfiles -Force
        $settingsObj | Add-Member -NotePropertyName "terminal.integrated.defaultProfile.windows" -NotePropertyValue "Clang64 Bash" -Force
        
        # Guardar configuración fusionada
        $mergedSettingsJson = $settingsObj | ConvertTo-Json -Depth 10
        Set-Content -Path $portableVscodeSettings -Value $mergedSettingsJson
        Write-Host "Configuración de VS Code importada y adaptada para portabilidad." -ForegroundColor Green
    } else {
        Write-Host "No se encontró la configuración de VS Code en el host." -ForegroundColor Yellow
    }
} else {
    Write-Host "No se especificó -ImportHostConfig. Se deja de lado la configuración del host para empezar con un entorno limpio." -ForegroundColor Yellow
}

# ==========================================
# 8. Limpieza final de temporales
# ==========================================
if (Test-Path $tempDir) {
    Write-Host "Limpiando archivos temporales..."
    Remove-Item -Path $tempDir -Recurse -Force
}

    # Guardar el indicador final de instalación completa exitosa
    Set-Content -Path (Join-Path $portableRoot ".install_complete") -Value "Complete"

    Write-Host "`n=== ENTORNO PORTABLE CONFIGURADO Y LISTO ===" -ForegroundColor Green
    Write-Host "Ejecutá 'launch.bat' para iniciar la consola." -ForegroundColor Green
    Write-Host "Ejecutá 'launch-vscode.bat' para iniciar VS Code." -ForegroundColor Green
}
finally {
    if ($transcriptStarted) {
        Write-Host "`n======================================================================"
        Write-Host "FIN DE LA INSTALACIÓN: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        Write-Host "======================================================================"
        Stop-Transcript | Out-Null
    }
}
