param(
    [string]$HomeDirName = "home",
    [switch]$ImportHostConfig,
    [switch]$SkipUpdate,
    [switch]$Yes,
    [switch]$Latest
)

$ErrorActionPreference = "Stop"

# Acelerar Invoke-WebRequest en Windows PowerShell 5.1 (la barra de progreso es hasta 10x más lenta)
$ProgressPreference = "SilentlyContinue"

# Compatibilidad PowerShell 7 (pwsh): el instalador se valida contra Windows PowerShell 5.1.
# Bajo pwsh funciona en modo informativo, pero diferencias de encoding y ConvertTo-Json
# pueden producir resultados distintos; ante dudas, ejecutar con 'powershell' clásico.
if ($PSVersionTable.PSVersion.Major -ge 6) {
    Write-Warning "Estás ejecutando setup.ps1 con PowerShell $($PSVersionTable.PSVersion) (pwsh)."
    Write-Warning "La validación completa de la cátedra es sobre Windows PowerShell 5.1 ('powershell')."
    Write-Warning "Si algo falla de forma extraña (encoding, JSON), probá primero con: powershell -ExecutionPolicy Bypass -File setup.ps1"
}

# Directorio base del script (con fallback al directorio actual si se ejecuta desde internet vía IEX)
$portableRoot = $PSScriptRoot
if ([string]::IsNullOrEmpty($portableRoot)) {
    $portableRoot = (Get-Location).Path
}

if (-not ($HomeDirName -match "^[a-zA-Z0-9_][a-zA-Z0-9_-]*$")) {
    $HomeDirName = "home"
}
$msysDir = Join-Path $portableRoot "msys64"
$descargasDir = Join-Path $portableRoot "descargas"
$homeDir = Join-Path $portableRoot $HomeDirName
$vscodeDir = Join-Path $portableRoot "vscode"
$isUpdateMode = Test-Path (Join-Path $portableRoot ".install_complete")

# Manifiesto de versiones por cuatrimestre (versions.json): valores null = última disponible.
# Por defecto se respetan los pines para reproducibilidad; -Latest los ignora.
$pinnedVersions = $null
$manifestFile = Join-Path $portableRoot "versions.json"
if ((Test-Path $manifestFile) -and (-not $Latest)) {
    try {
        $pinnedVersions = Get-Content $manifestFile -Raw | ConvertFrom-Json
        if ($pinnedVersions.canal) {
            Write-Host "Canal de versiones configurado: $($pinnedVersions.canal)" -ForegroundColor DarkGray
        }
    } catch {
        Write-Warning "versions.json inválido ($_). Se usarán las últimas versiones disponibles."
        $pinnedVersions = $null
    }
}
function Get-Pinned([string]$Key) {
    if ($null -eq $script:pinnedVersions) { return $null }
    $prop = $script:pinnedVersions.PSObject.Properties[$Key]
    if ($null -eq $prop) { return $null }
    if ($prop.Value -is [string] -and $prop.Value.Trim()) { return $prop.Value.Trim() }
    return $null
}

# Caché de respuestas de la API de GitHub: en aulas con NAT compartido el límite
# de 60 consultas por hora por IP se agota rápido. Guarda cada respuesta en
# descargas/api_cache con vencimiento (24 horas) y, si la API no responde o
# rechaza por límite de peticiones, reutiliza la última copia aunque esté vencida.
function Get-GitHubApiCached {
    param([string]$Url)
    $cacheDir = Join-Path $descargasDir "api_cache"
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hashBytes = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Url))
    } finally {
        $sha.Dispose()
    }
    $hash = [System.BitConverter]::ToString($hashBytes).Replace("-", "").Substring(0, 16).ToLower()
    $cacheFile = Join-Path $cacheDir "$hash.json"
    $stampFile = Join-Path $cacheDir "$hash.stamp"
    $ttlHours = 24

    $cachedJson = $null
    $cacheFresh = $false
    if (Test-Path $cacheFile) {
        $cachedJson = Get-Content $cacheFile -Raw
        if (Test-Path $stampFile) {
            try {
                $stampUtc = [datetimeoffset]::Parse((Get-Content $stampFile -Raw).Trim()).UtcDateTime
                if (((Get-Date).ToUniversalTime() - $stampUtc).TotalHours -lt $ttlHours) { $cacheFresh = $true }
            } catch { }
        }
        if ($cacheFresh) {
            Write-Host "Respuesta de la API de GitHub servida desde la caché local." -ForegroundColor DarkGray
            try { return ($cachedJson | ConvertFrom-Json) } catch { }
        }
    }

    try {
        $response = Invoke-RestMethod -Uri $Url -UseBasicParsing -TimeoutSec 10
        New-Item -ItemType Directory -Force -Path $cacheDir | Out-Null
        Set-Content -Path $cacheFile -Value ($response | ConvertTo-Json -Depth 20)
        Set-Content -Path $stampFile -Value (Get-Date).ToUniversalTime().ToString("o")
        return $response
    } catch {
        if (-not [string]::IsNullOrEmpty($cachedJson)) {
            Write-Warning "Consulta a la API de GitHub fallida; se usa la caché local (aunque vencida)."
            try { return ($cachedJson | ConvertFrom-Json) } catch { }
        }
        throw
    }
}

# Descarga uniforme con reintentos para archivos grandes (MSYS2, VS Code, gh, WezTerm).
# Un único punto para ajustar cantidad de intentos y espera entre intentos.
function Invoke-DownloadWithRetry {
    param(
        [string]$Url,
        [string]$OutFile,
        [int]$MaxAttempts = 3,
        [int]$DelaySeconds = 2
    )
    $attempts = 0
    while ($true) {
        $attempts++
        try {
            Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing -ErrorAction Stop
            return
        } catch {
            if ($attempts -ge $MaxAttempts) { throw }
            Start-Sleep -Seconds $DelaySeconds
        }
    }
}

# Espejo regional de pacman: mide latencia contra candidatos (prioridad sudamericana
# para Red UNRN) y configura el más rápido como primera opción de cada mirrorlist.
# Devuelve el espejo elegido o $null si ninguno respondió (no toca archivos en ese caso).
function Select-PacmanMirrorByLatency {
    param(
        [string]$MsysDir,
        [int]$TimeoutSec = 4
    )
    $mirrorCandidates = @(
        "https://mirror.ufro.cl/msys2",
        "https://repo.msys2.org",
        "https://mirrors.utexas.edu/msys2",
        "https://mirrors.ocf.berkeley.edu/msys2"
    )
    try {
        Write-Host "Midiendo latencia de espejos de pacman..." -ForegroundColor Cyan
        $bestMirror = $null
        $bestMs = [double]::MaxValue
        foreach ($candidate in $mirrorCandidates) {
            try {
                $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                Invoke-WebRequest -Uri "$candidate/distrib/" -Method Head -UseBasicParsing -TimeoutSec $TimeoutSec | Out-Null
                $stopwatch.Stop()
                Write-Host ("  {0} -> {1} ms" -f $candidate, $stopwatch.ElapsedMilliseconds) -ForegroundColor DarkGray
                if ($stopwatch.ElapsedMilliseconds -lt $bestMs) {
                    $bestMs = $stopwatch.ElapsedMilliseconds
                    $bestMirror = $candidate
                }
            } catch {
                Write-Host "  $candidate -> sin respuesta" -ForegroundColor DarkGray
            }
        }
        if (-not $bestMirror) {
            Write-Warning "Ningún espejo de pacman respondió; se conservan los servidores por defecto."
            return $null
        }
        Write-Host "Espejo pacman seleccionado: $bestMirror (${bestMs} ms)" -ForegroundColor Green
        $markerLine = "# Espejo seleccionado automaticamente por setup.ps1 (latencia)"
        $repoSubPaths = @{
            "mirrorlist.msys"    = "/msys/x86_64/"
            "mirrorlist.ucrt64"  = "/mingw/ucrt64/"
            "mirrorlist.mingw64" = "/mingw/mingw64/"
            "mirrorlist.clang64" = "/mingw/clang64/"
        }
        foreach ($mirrorListName in $repoSubPaths.Keys) {
            $mirrorListFile = Join-Path (Join-Path $MsysDir "etc\pacman.d") $mirrorListName
            if (-not (Test-Path $mirrorListFile)) { continue }
            $existingLines = @(Get-Content $mirrorListFile)
            $serverLine = "Server = $($bestMirror)$($repoSubPaths[$mirrorListName])"
            $kept = @($existingLines | Where-Object { $_ -ne $serverLine -and $_ -notmatch 'Espejo seleccionado automaticamente' })
            Set-Content -Path $mirrorListFile -Value (@($markerLine, $serverLine) + $kept)
        }
        return $bestMirror
    } catch {
        Write-Warning "Fallo la selección de espejo de pacman; se conservan los servidores por defecto."
        return $null
    }
}

# Configurar codificaciones UTF-8 globales (con y sin BOM)
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$utf8WithBom = New-Object System.Text.UTF8Encoding($true)

# Función para extraer el nombre de archivo de una URL o usar un fallback
function Get-FileNameFromUrl {
    param(
        [string]$Url,
        [string]$DefaultName
    )
    if ([string]::IsNullOrEmpty($Url)) { return $DefaultName }
    $leaf = $Url.Split('/')[-1]
    if ($leaf -match "\?") {
        $leaf = $leaf.Split('?')[0]
    }
    if ($leaf -match "\.(zip|exe|tar|gz|sfx)$") {
        return $leaf
    }
    return $DefaultName
}

# Función para ejecutar comandos de pacman con reintentos
function Invoke-PacmanWithRetry {
    param(
        [string]$BashPath,
        [string]$Arguments,
        [int]$MaxAttempts = 3,
        [int]$DelaySeconds = 5
    )
    
    $attempts = 0
    $success = $false
    
    while (-not $success -and $attempts -lt $MaxAttempts) {
        $attempts++
        if ($attempts -gt 1) {
            Write-Host "Reintentando comando pacman (Intento $attempts de $MaxAttempts) en $DelaySeconds segundos..." -ForegroundColor Yellow
            Start-Sleep -Seconds $DelaySeconds
        }
        
        # Ejecutar pacman con los argumentos correspondientes
        & $BashPath --login -c "pacman $Arguments"
        
        if ($LASTEXITCODE -eq 0) {
            $success = $true
        } else {
            Write-Warning "El comando 'pacman $Arguments' falló con código de salida: $LASTEXITCODE"
        }
    }
    
    if (-not $success) {
        throw "No se pudo completar la instalación o actualización de paquetes con pacman tras $MaxAttempts intentos."
    }
}

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
$versionFile = Join-Path $portableRoot "VERSION"
$entornoVersion = "?"
if (Test-Path $versionFile) { $entornoVersion = (Get-Content $versionFile -Raw).Trim() }
Write-Host "Versión del Entorno  : $entornoVersion"
if ($PSVersionTable.PSVersion.Major -ge 6) {
    Write-Host "Aviso de Compatibilidad: estás ejecutando PowerShell $($PSVersionTable.PSVersion); el instalador está validado principalmente sobre Windows PowerShell 5.1." -ForegroundColor Yellow
}
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
    # Canal de actualización configurable vía .env (ej: CHANNEL=estable-2026c1).
    # Solo aplica a instalaciones standalone; en repos Git rige la rama local.
    $branch = "main"
    $envFileEarly = Join-Path $portableRoot ".env"
    if (Test-Path $envFileEarly) {
        $envRawEarly = Get-Content $envFileEarly -Raw
        if ($envRawEarly -match '(?m)^CHANNEL=([^\s#]+)') {
            $branch = $Matches[1].Trim()
            Write-Host "Canal de scripts configurado: $branch" -ForegroundColor DarkGray
        }
    }
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
            if ($Yes) {
                Write-Host "(--Yes) Actualizando scripts automáticamente..." -ForegroundColor DarkGray
            } elseif ((Read-Host "¿Deseás actualizar todos los scripts del entorno a la última versión desde GitHub? (s/n)") -notmatch "^[sS]$") {
                $shouldUpdate = $false
                Write-Host "Se omite la actualización de los scripts. Se utilizarán las versiones locales.`n" -ForegroundColor Yellow
            }
        }
        
        if ($shouldUpdate) {
            Write-Host "No se detectó un repositorio de Git (carpeta standalone). Descargando snapshot del repositorio..." -ForegroundColor Cyan
            
            if (-not (Test-Path $descargasDir)) {
                New-Item -ItemType Directory -Path $descargasDir | Out-Null
            }
            
            $zipUrl = "https://github.com/$repoOwner/$repoName/archive/refs/heads/$branch.zip"
            $zipPath = Join-Path $descargasDir "repo_temp.zip"
            $extractTempDir = Join-Path $descargasDir "repo_extracted"
            
            # Limpiar directorio de extracción si ya existía
            if (Test-Path $extractTempDir) {
                Remove-Item -Path $extractTempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
            
            try {
                Write-Host "Descargando snapshot del repositorio desde GitHub..." -ForegroundColor Gray
                # Descarga con reintentos
                $attempts = 0
                $success = $false
                while (-not $success -and $attempts -lt 3) {
                    $attempts++
                    try {
                        Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing -ErrorAction Stop
                        $success = $true
                    } catch {
                        if ($attempts -lt 3) {
                            Start-Sleep -Seconds 1
                        } else {
                            throw $_
                        }
                    }
                }
                
                Write-Host "Extrayendo archivos del snapshot..." -ForegroundColor Gray
                Expand-Archive -Path $zipPath -DestinationPath $extractTempDir -Force
                
                $extractedRepoDir = Join-Path $extractTempDir "$repoName-$branch"
                if (-not (Test-Path $extractedRepoDir)) {
                    throw "No se pudo encontrar la carpeta extraída '$repoName-$branch' en el archivo zip."
                }
                
                $filesToCopy = @(
                    "setup.ps1",
                    "launch.bat",
                    "launch.ps1",
                    "env.common.psm1",
                    "launch-vscode.bat",
                    "launch-vscode.ps1",
                    "clean-shared-host.ps1",
                    "customize-terminal.ps1",
                    "customize-terminal.bat",
                    "package-env.ps1",
                    "bin/ayuda",
                    "bin/install-lib.sh",
                    "bin/build-launcher.sh",
                    "bin/customize-bash.sh",
                    "bin/update-env.sh",
                    "bin/configure-git.sh",
                    "bin/download-baseline.sh",
                    "bin/diagnose-env.sh",
                    "bin/uninstall-lib.sh",
                    "bin/update-packages.sh",
                    "bin/smoke.sh",
                    "smoke.ps1",
                    "install-offline.ps1",
                    "bin/nuevo-proyecto",
                    "bin/backup",
                    "bin/restaurar",
                    "bin/entregar",
                    "bin/doctor",
                    "README.md",
                    "plan.md",
                    "GEMINI.md",
                    "docs/entorno.md",
                    "docs/casos-de-uso.md",
                    "docs/scripts.md",
                    "docs/compilacion-gcc.md",
                    "docs/images/arquitectura_entorno.svg",
                    "docs/images/flujo_compilacion.svg",
                    "linux/activate.sh",
                    "linux/bootstrap.sh",
                    "linux/bin/ayuda",
                    "linux/bin/configure-git.sh",
                    "linux/bin/customize-terminal.sh",
                    "linux/bin/install-lib.sh",
                    "linux/bin/uninstall-lib.sh",
                    "packages-baseline.txt",
                    "VERSION",
                    "versions.json",
                    "wezterm.lua.template"
                )
                
                foreach ($file in $filesToCopy) {
                    $srcPath = Join-Path $extractedRepoDir $file
                    $destPath = Join-Path $portableRoot $file
                    if (Test-Path $srcPath) {
                        # Asegurar directorio destino
                        $parentDir = Split-Path -Parent $destPath
                        if (-not (Test-Path $parentDir)) {
                            New-Item -ItemType Directory -Path $parentDir | Out-Null
                        }
                        # Copiar archivo
                        Copy-Item -Path $srcPath -Destination $destPath -Force
                        # Guardar con UTF-8 BOM si es un script PS
                        if ($file -like "*.ps1") {
                            $content = [System.IO.File]::ReadAllText($destPath, [System.Text.Encoding]::UTF8)
                            [System.IO.File]::WriteAllText($destPath, $content, $utf8WithBom)
                        }
                    }
                }
                
                Write-Host "Actualización de scripts completada con éxito.`n" -ForegroundColor Green
                $didUpdate = $true
            } catch {
                Write-Warning "Fallo al descargar o extraer la actualización de los scripts: $_"
            } finally {
                # Limpieza final de temporales
                if (Test-Path $extractTempDir) {
                    Remove-Item -Path $extractTempDir -Recurse -Force -ErrorAction SilentlyContinue
                }
                if (Test-Path $zipPath) {
                    Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }

    if ($didUpdate) {
        Write-Host "Relanzando setup.ps1 para aplicar la versión más reciente en memoria..." -ForegroundColor Magenta
        $newArgs = @{
            SkipUpdate = $true
        }
        if ($HomeDirName -ne "home") { 
            $newArgs["HomeDirName"] = $HomeDirName 
        }
        if ($ImportHostConfig) { 
            $newArgs["ImportHostConfig"] = $true 
        }
        
        $localSetup = Join-Path $portableRoot "setup.ps1"
        & $localSetup @newArgs
        exit $LASTEXITCODE
    }
}

# Escribir archivo de configuración .env local
    $envFilePath = Join-Path $portableRoot ".env"
    Set-Content -Path $envFilePath -Value ('set "HOME_DIR_NAME={0}"' -f $HomeDirName)

# Asegurar que el archivo .env, el directorio personalizado y la carpeta descargas estén excluidos en .gitignore
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
    if (-not $gitignoreContent.Contains("descargas/")) {
        Add-Content -Path $gitignorePath -Value "`n# Persistent downloads cache`ndescargas/"
    }
}

Write-Host "=== Entorno Portable de Desarrollo C + Python + VS Code ===" -ForegroundColor Cyan
if ($isUpdateMode) {
    Write-Host ">>> MODO ACTUALIZACIÓN: Se detectó una instalación previa completa. <<<" -ForegroundColor Green
} else {
    Write-Host ">>> MODO INSTALACIÓN/FINALIZACIÓN: Completando o finalizando instalación... <<<" -ForegroundColor Yellow
}
Write-Host "Directorio de instalación: $portableRoot`n"

# Validar espacios, caracteres no ASCII o carpetas sincronizadas en la ruta (causan errores con Make/compiladores)
$hasSpaces = $portableRoot -match ' '
$hasNonAscii = $portableRoot -match '[^\u0000-\u007F]'
$hasSyncFolder = $portableRoot -match '(?i)onedrive|dropbox|google\s+drive|icloud'

if ($hasSpaces -or $hasNonAscii -or $hasSyncFolder) {
    Write-Host "==========================================================================" -ForegroundColor Yellow
    Write-Host "ADVERTENCIA: RUTA CON POSIBLES CONFLICTOS DETECTADA" -ForegroundColor Yellow
    Write-Host "==========================================================================" -ForegroundColor Yellow
    if ($hasSpaces) {
        Write-Host "* La ruta de instalación contiene espacios en blanco." -ForegroundColor Yellow
    }
    if ($hasNonAscii) {
        Write-Host "* La ruta de instalación contiene caracteres no ASCII (acentos, eñes, etc.)." -ForegroundColor Yellow
    }
    if ($hasSyncFolder) {
        Write-Host "* La ruta está dentro de una carpeta sincronizada (OneDrive/Dropbox/etc.)," -ForegroundColor Yellow
        Write-Host "  conocida por corromper instalaciones y compilaciones." -ForegroundColor Yellow
    }
    Write-Host "--------------------------------------------------------------------------"
    Write-Host "Muchas herramientas de compilación de C (como Make, CMake y compiladores)"
    Write-Host "fallan o tienen comportamientos erráticos con este tipo de rutas."
    Write-Host "Se recomienda mover la carpeta a una ruta simple (Ej: C:\dev\entorno)."
    Write-Host "--------------------------------------------------------------------------"

    if ($Yes) {
        Write-Host "(--Yes) Continuando con la instalación bajo riesgo del usuario...`n" -ForegroundColor Yellow
    } else {
        $choice = Read-Host "¿Deseás continuar con la instalación de todas formas? (s/n)"
        if ($choice -notmatch "^[sS]$") {
            Write-Host "Instalación cancelada." -ForegroundColor Red
            return
        }
        Write-Host "Continuando con la instalación bajo riesgo del usuario...`n" -ForegroundColor Yellow
    }
}

# Asegurar que existan los directorios iniciales y sus archivos skel
if (-not (Test-Path $homeDir)) {
    New-Item -ItemType Directory -Path $homeDir | Out-Null
    Write-Host "Creado directorio HOME portable: $homeDir" -ForegroundColor Green
}

# ==========================================
# 0.5 Preflight de recursos
# ==========================================
# Espacio en disco: la instalación completa requiere ~4 GB libres.
try {
    $driveName = ($portableRoot.Substring(0, 2)).TrimEnd('\')
    $drive = Get-PSDrive -Name $driveName[0] -ErrorAction Stop
    if ($drive.Free -lt 4GB) {
        $freeGb = [math]::Round($drive.Free / 1GB, 2)
        throw "Espacio insuficiente en ${driveName}: hay ${freeGb} GB libres y se necesitan al menos 4 GB."
    }
    Write-Host "[OK] Espacio en disco suficiente ($([math]::Round($drive.Free / 1GB, 1)) GB libres)." -ForegroundColor DarkGray
} catch [System.Management.Automation.PSInvalidOperationException] {
    Write-Warning "No se pudo verificar el espacio en disco para '$portableRoot'. Continuando..."
} 
# Rutas largas: msys64 agrega profundidad significativa; el límite clásico es 260 caracteres.
if ($portableRoot.Length -gt 100) {
    Write-Warning ("La ruta de instalación tiene {0} caracteres y puede exceder el límite clásico de 260 al extraer MSYS2." -f $portableRoot.Length)
    Write-Warning "Si la extracción falla con 'path too long', mové el entorno a una ruta más corta (ej: C:\dev\entorno)."
}

$bashProfilePath = Join-Path $homeDir ".bash_profile"
if (-not (Test-Path $bashProfilePath)) {
    $bashProfileContent = "if [ -f `"`${HOME}/.bashrc`" ] ; then`n  source `"`${HOME}/.bashrc`"`nfi"
    [System.IO.File]::WriteAllText($bashProfilePath, $bashProfileContent, $utf8NoBom)
}

$bashrcPath = Join-Path $homeDir ".bashrc"
if (-not (Test-Path $bashrcPath)) {
    $bashrcContent = "# .bashrc`n# Aquí podés agregar tus alias y funciones personalizadas.`n`n# Agregar bin portable al PATH en formato Unix (sin duplicar en shells anidados)`nif [ -n `"`$PORTABLE_ROOT`" ]; then`n    UNIX_ROOT=`$`(cygpath -u `"`$PORTABLE_ROOT`"`)`n    case `":`$PATH:`" in`n        *`":`${UNIX_ROOT}bin:`"*) : ;;`n        *) export PATH=`"`${UNIX_ROOT}bin:`${UNIX_ROOT}msys64/ucrt64/bin:`${UNIX_ROOT}msys64/usr/bin:`$PATH`" ;;`n    esac`nfi`n"
    [System.IO.File]::WriteAllText($bashrcPath, $bashrcContent, $utf8NoBom)
}

if (-not (Test-Path $descargasDir)) {
    New-Item -ItemType Directory -Path $descargasDir | Out-Null
}

# ==========================================
# 1. Gestión e Instalación de MSYS2
# ==========================================
$isMsysInstalled = Test-Path (Join-Path $msysDir "usr\bin\bash.exe")
$isMsysComplete = Test-Path (Join-Path $portableRoot ".msys_complete")

if (-not $isMsysInstalled -or -not $isMsysComplete) {
    if (-not $isMsysInstalled) {
        Write-Host "[Instalación] MSYS2 no detectado. Iniciando descarga..." -ForegroundColor Yellow

        # MSYS2 puede estar fijado en versions.json (canal reproducible)
        $downloadUrl = Get-Pinned 'msys2'
        if ($downloadUrl) {
            $fileName = Split-Path $downloadUrl -Leaf
            Write-Host "MSYS2 fijado por el manifiesto de versiones: $fileName" -ForegroundColor DarkGray
        }

        if (-not $downloadUrl) {
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            $releasesUrl = "https://api.github.com/repos/msys2/msys2-installer/releases"
            Write-Host "Consultando API de GitHub por la última versión de MSYS2..."
            $releases = Get-GitHubApiCached -Url $releasesUrl
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
        } # fin if (-not $downloadUrl)

        if (-not $downloadUrl) {
            $downloadUrl = if ($pinF = Get-Pinned 'msys2_fallback') { $pinF } else { "https://github.com/msys2/msys2-installer/releases/download/2025-02-21/msys2-base-x86_64-20250221.sfx.exe" }
            $fileName = Split-Path $downloadUrl -Leaf
            Write-Host "Fallback URL: $downloadUrl" -ForegroundColor Yellow
        }

        $exePath = Join-Path $descargasDir $fileName
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
            Invoke-DownloadWithRetry -Url $downloadUrl -OutFile $exePath

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
        Write-Host "Se detectó una instalación previa incompleta de MSYS2. Intentando continuar con la instalación existente..." -ForegroundColor Yellow
    }
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

    # Acelerar la instalación inicial habilitando descargas paralelas en pacman
    & $bashPath --login -c "sed -i -E 's/^#?[[:space:]]*ParallelDownloads.*/ParallelDownloads = 5/' /etc/pacman.conf"

    # Espejo regional de pacman: medir latencia contra candidatos (con prioridad
    # sudamericana para Red UNRN) y configurar el más rápido como primera opción.
    $null = Select-PacmanMirrorByLatency -MsysDir $msysDir

    # Resolver la ruta de caché local y pasarla a pacman utilizando el ejecutable cygpath nativo
    $cygpathExe = Join-Path $msysDir "usr\bin\cygpath.exe"
    $unixCacheDir = & $cygpathExe -u "$descargasDir/pacman_cache"
    $unixCacheDir = $unixCacheDir.Trim()

    Write-Host "Sincronizando base de datos de pacman y actualizando paquetes del sistema..." -ForegroundColor Cyan
    try {
        Invoke-PacmanWithRetry -BashPath $bashPath -Arguments "-Syu --noconfirm --cachedir '$unixCacheDir'"
    } catch {
        Write-Warning "No se pudo sincronizar o actualizar pacman (posiblemente sin internet). Intentando instalar paquetes locales..."
    }

    Write-Host "Consolidando actualizaciones del entorno..." -ForegroundColor Cyan
    try {
        Invoke-PacmanWithRetry -BashPath $bashPath -Arguments "-Su --noconfirm --cachedir '$unixCacheDir'"
    } catch {
        Write-Warning "Fallo al consolidar actualizaciones (posiblemente sin internet)."
    }

    # ==========================================
    # 3. Instalación de Clang y Python
    # ==========================================
    # Lista única de paquetes mantenida en packages-baseline.txt
    # (compartida con bin/download-baseline.sh; admite comentarios con #)
    $pkgFile = Join-Path $portableRoot "packages-baseline.txt"
    if (-not (Test-Path $pkgFile)) {
        throw "No se encontró packages-baseline.txt en la raíz del entorno."
    }
    $packages = @(Get-Content -Path $pkgFile | ForEach-Object { ($_ -split '#')[0].Trim() } | Where-Object { $_ })

    $pkgString = $packages -join " "
    Write-Host "Instalando compiladores, herramientas de compilación, Python y librerías comunes..." -ForegroundColor Cyan
    Invoke-PacmanWithRetry -BashPath $bashPath -Arguments "-S --needed --noconfirm --cachedir '$unixCacheDir' $pkgString"

    # Configurar alias en el HOME portable
    $bashrcPath = Join-Path $homeDir ".bashrc"
    if (-not (Test-Path $bashrcPath)) {
        & $bashPath -env "HOME=$homeDir" --login -c "exit"
    }

    if (Test-Path $bashrcPath) {
        $aliasesFile = Join-Path $homeDir ".bash_aliases"
        $customAliases = @(
            "# === Portable Dev Environment Aliases ===",
            "alias python='python3'",
            "alias pip='pip3'",
            "alias make='mingw32-make'",
            "alias ll='ls -alF --color=auto'",
            "export PS1='\[\e[32m\]\u@portable \[\e[33m\]\w\[\e[0m\]\n$ '"
        )
        [System.IO.File]::WriteAllText($aliasesFile, ($customAliases -join "`n") + "`n", $utf8NoBom)
        
        $sourceLine = "if [ -f ~/.bash_aliases ]; then source ~/.bash_aliases; fi"
        $content = [System.IO.File]::ReadAllText($bashrcPath, $utf8NoBom)
        
        $isModified = $false
        if (-not $content.Contains("source ~/.bash_aliases")) {
            $content += "`r`n$sourceLine"
            $isModified = $true
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
            'ayuda',
            $endInstMarker
        ) -join "`r`n"
        
        if (-not $content.Contains($startInstMarker)) {
            $content += "`r`n$instBanner"
            $isModified = $true
        }
        
        if ($isModified) {
            [System.IO.File]::WriteAllText($bashrcPath, $content, $utf8NoBom)
            Write-Host "Configuración de terminal personalizada guardada." -ForegroundColor Green
        }
    }
    Set-Content -Path (Join-Path $portableRoot ".msys_complete") -Value "Complete"
} else {
    Write-Host "[Actualización] MSYS2 y herramientas de desarrollo ya configuradas. Se omite pacman para agilizar la ejecución." -ForegroundColor Green
}

# ==========================================
# 4. Gestión e Instalación de VS Code Portable
# ==========================================
$vscodeZipUrl = "https://code.visualstudio.com/sha/download?build=stable&os=win32-x64-archive"
$isCodeInstalled = Test-Path (Join-Path $vscodeDir "Code.exe")
$isCodeComplete = Test-Path (Join-Path $portableRoot ".vscode_complete")

# Resolver la URL de redirección final de VS Code
$resolvedVscodeUrl = $vscodeZipUrl
$vscodePinned = Get-Pinned 'vscode'
if ($vscodePinned) {
    $resolvedVscodeUrl = $vscodePinned
    Write-Host "VS Code fijado por el manifiesto de versiones." -ForegroundColor DarkGray
}
if ($isUpdateMode -or -not $isCodeComplete) {
    if (-not $vscodePinned) {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $request = [System.Net.WebRequest]::Create($vscodeZipUrl)
        $request.Method = "HEAD"
        $request.AllowAutoRedirect = $false
        $request.Timeout = 10000
        $response = $request.GetResponse()
        $resolvedVscodeUrl = $response.Headers["Location"]
        $response.Close()
        if ([string]::IsNullOrEmpty($resolvedVscodeUrl)) {
            $resolvedVscodeUrl = $vscodeZipUrl
        }
    } catch {
        try {
            $request = [System.Net.WebRequest]::Create($vscodeZipUrl)
            $request.Method = "GET"
            $request.AllowAutoRedirect = $false
            $request.Timeout = 10000
            $response = $request.GetResponse()
            $resolvedVscodeUrl = $response.Headers["Location"]
            $response.Close()
            if ([string]::IsNullOrEmpty($resolvedVscodeUrl)) {
                $resolvedVscodeUrl = $vscodeZipUrl
            }
        } catch {
            Write-Warning "No se pudo resolver la URL final de redirección de VS Code. Se usará la URL directa."
        }
    }
    } # fin if (-not $vscodePinned)
}

if (-not $isUpdateMode -and $isCodeComplete -and $isCodeInstalled) {
    Write-Host "VS Code ya se encuentra instalado y configurado de una ejecución previa." -ForegroundColor Green
} else {
    $shouldInstallOrUpdateVscode = $false
    if ($isUpdateMode) {
        $installedVscodeVersionFile = Join-Path $vscodeDir ".version"
        $installedVscodeUrl = ""
        if (Test-Path $installedVscodeVersionFile) {
            $installedVscodeUrl = (Get-Content $installedVscodeVersionFile -Raw).Trim()
        }
        
        if ($resolvedVscodeUrl -ne $installedVscodeUrl) {
            Write-Host "Hay una nueva versión de VS Code disponible para actualizar (o no pudo verificarse la versión local)." -ForegroundColor Yellow
            if ($Yes -or ((Read-Host "¿Deseás descargar e instalar la actualización de VS Code? (s/n)") -match "^[sS]$")) {
                $shouldInstallOrUpdateVscode = $true
                if ($Yes) { Write-Host "(--Yes) Actualizando VS Code automáticamente..." -ForegroundColor DarkGray }
            } else {
                Write-Host "Omitiendo actualización de VS Code." -ForegroundColor DarkGray
            }
        } else {
            Write-Host "VS Code ya se encuentra en la versión más reciente ($resolvedVscodeUrl)." -ForegroundColor Green
        }
    } else {
        $shouldInstallOrUpdateVscode = $true
    }

    if ($shouldInstallOrUpdateVscode) {
        if (-not $isUpdateMode -and $isCodeInstalled) {
            Write-Host "Se detectó una instalación previa incompleta de VS Code. Se intentará continuar con la configuración..." -ForegroundColor Yellow
            $dataDir = Join-Path $vscodeDir "data"
            $userSettingsDir = Join-Path $dataDir "user-data\User"
            $settingsJsonPath = Join-Path $userSettingsDir "settings.json"
            if (-not (Test-Path $settingsJsonPath)) {
                if (-not (Test-Path $userSettingsDir)) {
                    New-Item -ItemType Directory -Path $userSettingsDir -Force | Out-Null
                }
                $defaultSettings = @{
                    "telemetry.telemetryLevel" = "off"
                    "update.mode" = "none"
                    "extensions.autoUpdate" = $false
                    "chat.disableAIFeatures" = $true
                    "github.copilot.enable" = @{
                        "*" = $false
                    }
                    "terminal.integrated.profiles.windows" = @{
                        "UCRT64 Bash" = @{
                            "path" = "bash.exe"
                            "args" = @("--login", "-i")
                        }
                    }
                    "terminal.integrated.defaultProfile.windows" = "UCRT64 Bash"
                } | ConvertTo-Json -Depth 10
                Set-Content -Path $settingsJsonPath -Value $defaultSettings
            }
        } else {
            # Resolver nombre de archivo de forma dinámica e identificar versión
            $vscodeZipName = Get-FileNameFromUrl -Url $resolvedVscodeUrl -DefaultName "vscode_archive.zip"
            $vscodeZipPath = Join-Path $descargasDir $vscodeZipName

            $vscodeZipValid = $false
            if (Test-Path $vscodeZipPath) {
                Write-Host "Se detectó una descarga previa de VS Code ($vscodeZipName). Verificando..." -ForegroundColor Yellow
                try {
                    $fileSize = (Get-Item $vscodeZipPath).Length
                    if ($fileSize -gt 50MB) {
                        # Verificación activa: si existe el hash registrado de una descarga previa, compararlo
                        $sidecar = "$vscodeZipPath.sha256"
                        if (Test-Path $sidecar) {
                            $expectedHash = (Get-Content $sidecar -Raw).Trim()
                            $actualHash = (Get-FileHash -Path $vscodeZipPath -Algorithm SHA256).Hash
                            if ($actualHash -ne $expectedHash) {
                                Write-Host "El ZIP previo de VS Code está corrupto (SHA256 no coincide). Se volverá a descargar." -ForegroundColor Yellow
                            } else {
                                $vscodeZipValid = $true
                                Write-Host "El archivo ZIP previo es válido (SHA256 verificado)." -ForegroundColor Green
                            }
                        } else {
                            $vscodeZipValid = $true
                            Write-Host "El archivo ZIP previo es válido (sin hash previo registrado)." -ForegroundColor Green
                        }
                    } else {
                        Write-Host "El archivo ZIP previo está incompleto o dañado. Se volverá a descargar." -ForegroundColor Yellow
                    }
                } catch {
                    Write-Host "No se pudo verificar el archivo ZIP previo. Se volverá a descargar." -ForegroundColor Yellow
                }
            }
            
            if (-not $vscodeZipValid) {
                Write-Host "Descargando VS Code desde $resolvedVscodeUrl..." -ForegroundColor Cyan
                Invoke-DownloadWithRetry -Url $resolvedVscodeUrl -OutFile $vscodeZipPath
                (Get-FileHash -Path $vscodeZipPath -Algorithm SHA256).Hash | Set-Content -Path "$vscodeZipPath.sha256"
            }
            
            $backupDataDir = Join-Path $portableRoot "vscode_data_backup"
            $dataDir = Join-Path $vscodeDir "data"
            $extractTemp = Join-Path $descargasDir "vscode_extract"

            # Actualización atómica: se extrae y valida en un directorio temporal
            # antes de tocar la instalación vigente; ante cualquier fallo se restaura el respaldo.
            try {
                if (Test-Path $extractTemp) {
                    Remove-Item -Path $extractTemp -Recurse -Force -ErrorAction SilentlyContinue
                }
                New-Item -ItemType Directory -Path $extractTemp | Out-Null

                Write-Host "Extrayendo VS Code a directorio temporal..." -ForegroundColor Cyan
                Expand-Archive -Path $vscodeZipPath -DestinationPath $extractTemp -Force
                if (-not (Test-Path (Join-Path $extractTemp "Code.exe"))) {
                    throw "El ZIP extraído no contiene Code.exe; se cancela el reemplazo de la instalación vigente."
                }

                if ((Test-Path $dataDir)) {
                    Write-Host "Respaldando carpeta data de VS Code..." -ForegroundColor Cyan
                    if (Test-Path $backupDataDir) {
                        Remove-Item -Path $backupDataDir -Recurse -Force -ErrorAction SilentlyContinue
                    }
                    Move-Item -Path $dataDir -Destination $backupDataDir -Force
                }

                if (Test-Path $vscodeDir) {
                    Write-Host "Reemplazando instalación anterior de VS Code..." -ForegroundColor Cyan
                    Remove-Item -Path $vscodeDir -Recurse -Force -ErrorAction SilentlyContinue
                }
                Move-Item -Path $extractTemp -Destination $vscodeDir

                if (Test-Path $backupDataDir) {
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
                        "UCRT64 Bash" = @{
                            "path" = "bash.exe"
                            "args" = @("--login", "-i")
                        }
                    }
                    "terminal.integrated.defaultProfile.windows" = "UCRT64 Bash"
                } | ConvertTo-Json -Depth 10
                
                Set-Content -Path $settingsJsonPath -Value $defaultSettings
                }
            } catch {
                Write-Warning "Fallo durante la actualización de VS Code: $_"
                # Rollback: si el respaldo existe y la data no fue restaurada, reconstruir
                if ((Test-Path $backupDataDir) -and (-not (Test-Path $dataDir))) {
                    Write-Host "Restaurando respaldo de datos de VS Code tras el fallo..." -ForegroundColor Yellow
                    if (-not (Test-Path $vscodeDir)) {
                        New-Item -ItemType Directory -Path $vscodeDir -Force | Out-Null
                    }
                    Move-Item -Path $backupDataDir -Destination $dataDir -Force
                }
                throw
            } finally {
                if (Test-Path $extractTemp) {
                    Remove-Item -Path $extractTemp -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
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
        # Versiones pineadas en versions.json (campo "extensiones": id -> versión o null)
        $extensions = @(
            "ms-vscode.cpptools",
            "ms-vscode.cpptools-extension-pack",
            "ms-vscode.cmake-tools",
            "ms-vscode.makefile-tools",
            "ms-python.python",
            "GitHub.vscode-pull-request-github",
            "bierner.github-markdown-preview"
        )
        if ($null -ne $pinnedVersions) {
            $extProp = $pinnedVersions.PSObject.Properties['extensiones']
            if ($extProp) {
                $pinnedExts = @($extProp.Value.PSObject.Properties | ForEach-Object {
                    if ($_.Value -is [string] -and $_.Value.Trim()) { "$($_.Name)@$($_.Value.Trim())" } else { $_.Name }
                })
                if ($pinnedExts.Count -gt 0) { $extensions = $pinnedExts }
            }
        }
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
$isGhInstalled = Test-Path $ghExe
$isGhComplete = Test-Path (Join-Path $portableRoot ".gh_complete")

$ghDownloadUrl = ""
$shouldInstallOrUpdateGh = $false

if ($isUpdateMode -or -not $isGhComplete -or -not $isGhInstalled) {
    Write-Host "Obteniendo URL de descarga de GitHub CLI..." -ForegroundColor Cyan
    # Pin del manifiesto tiene prioridad; si no hay, se consulta la API
    $ghDownloadUrl = Get-Pinned 'gh'
    $ghFallbackUrl = if ($pinF = Get-Pinned 'gh_fallback') { $pinF } else { "https://github.com/cli/cli/releases/download/v2.49.0/gh_2.49.0_windows_amd64.zip" }
    if ($ghDownloadUrl) {
        Write-Host "GitHub CLI fijado por el manifiesto de versiones." -ForegroundColor DarkGray
    } else {
    try {
        $ghReleaseUrl = "https://api.github.com/repos/cli/cli/releases/latest"
        $ghRelease = Get-GitHubApiCached -Url $ghReleaseUrl
        $ghAsset = $ghRelease.assets | Where-Object { $_.name -like "*windows_amd64.zip" }
        if ($ghAsset) {
            $ghDownloadUrl = $ghAsset.browser_download_url
            Write-Host "Última versión detectada de GitHub CLI: $($ghAsset.name)" -ForegroundColor Green
        }
    } catch {
        Write-Warning "Fallo al consultar la API de GitHub para GitHub CLI. Usando fallback fijo."
    }

    if (-not $ghDownloadUrl) {
        $ghDownloadUrl = $ghFallbackUrl
        Write-Host "Fallback URL GitHub CLI: $ghDownloadUrl" -ForegroundColor Yellow
    }
    }
}

if (-not $isUpdateMode -and $isGhComplete -and $isGhInstalled) {
    Write-Host "GitHub CLI ya está instalado y configurado de una ejecución previa." -ForegroundColor Green
} else {
    if ($isUpdateMode) {
        $installedGhVersionFile = Join-Path $portableRoot "bin\.gh_version"
        $installedGhUrl = ""
        if (Test-Path $installedGhVersionFile) {
            $installedGhUrl = (Get-Content $installedGhVersionFile -Raw).Trim()
        }
        if ($ghDownloadUrl -ne $installedGhUrl) {
            # Si se usó la URL de fallback porque falló la API y ya hay una versión instalada,
            # asumimos que la instalada es válida para no sugerir un downgrade o alertar innecesariamente.
            $isFallback = ($ghDownloadUrl -eq $ghFallbackUrl)
            if ($isFallback -and $installedGhUrl) {
                Write-Host "Omitiendo comprobación de actualización de GitHub CLI (la API de GitHub no está disponible)." -ForegroundColor Green
            } else {
                Write-Host "Hay una nueva versión de GitHub CLI disponible para actualizar (o no pudo verificarse la versión local)." -ForegroundColor Yellow
                if ($Yes -or ((Read-Host "¿Deseás descargar e instalar la actualización de GitHub CLI? (s/n)") -match "^[sS]$")) {
                    $shouldInstallOrUpdateGh = $true
                    if ($Yes) { Write-Host "(--Yes) Actualizando GitHub CLI automáticamente..." -ForegroundColor DarkGray }
                } else {
                    Write-Host "Omitiendo actualización de GitHub CLI." -ForegroundColor DarkGray
                }
            }
        } else {
            Write-Host "GitHub CLI ya se encuentra en la versión más reciente ($ghDownloadUrl)." -ForegroundColor Green
        }
    } else {
        $shouldInstallOrUpdateGh = $true
    }

    if ($shouldInstallOrUpdateGh) {
        if (-not $isUpdateMode -and $isGhInstalled) {
            Write-Host "Se detectó una instalación previa incompleta de GitHub CLI. Se continuará con la instalación existente..." -ForegroundColor Yellow
        } else {
            # Resolver nombre de archivo de forma dinámica
            $ghZipName = Get-FileNameFromUrl -Url $ghDownloadUrl -DefaultName "gh_archive.zip"
            $ghZipPath = Join-Path $descargasDir $ghZipName

            $isGhZipValid = $false
            if (Test-Path $ghZipPath) {
                Write-Host "Se detectó un archivo ZIP de GitHub CLI descargado previamente ($ghZipName). Verificando..." -ForegroundColor Yellow
                try {
                    $fileSize = (Get-Item $ghZipPath).Length
                    if ($fileSize -gt 5MB) {
                        $sidecar = "$ghZipPath.sha256"
                        if (Test-Path $sidecar) {
                            $expectedHash = (Get-Content $sidecar -Raw).Trim()
                            $actualHash = (Get-FileHash -Path $ghZipPath -Algorithm SHA256).Hash
                            if ($actualHash -ne $expectedHash) {
                                Write-Host "El ZIP previo de GitHub CLI está corrupto (SHA256 no coincide). Se volverá a descargar." -ForegroundColor Yellow
                            } else {
                                $isGhZipValid = $true
                                Write-Host "El ZIP previo de GitHub CLI es válido (SHA256 verificado)." -ForegroundColor Green
                            }
                        } else {
                            $isGhZipValid = $true
                            Write-Host "El archivo ZIP previo de GitHub CLI es válido (sin hash previo registrado)." -ForegroundColor Green
                        }
                    } else {
                        Write-Host "El archivo ZIP previo de GitHub CLI está incompleto. Se volverá a descargar." -ForegroundColor Yellow
                    }
                } catch {
                    Write-Host "No se pudo verificar el archivo ZIP previo de GitHub CLI. Se volverá a descargar." -ForegroundColor Yellow
                }
            }

            if (-not $isGhZipValid) {
                Write-Host "Descargando GitHub CLI desde $ghDownloadUrl..." -ForegroundColor Cyan
                Invoke-DownloadWithRetry -Url $ghDownloadUrl -OutFile $ghZipPath
                (Get-FileHash -Path $ghZipPath -Algorithm SHA256).Hash | Set-Content -Path "$ghZipPath.sha256"
            }

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
            # No removemos el archivo zip para mantener la caché de descargas
        }

        Set-Content -Path (Join-Path $portableRoot "bin\.gh_version") -Value $ghDownloadUrl
        Set-Content -Path (Join-Path $portableRoot ".gh_complete") -Value "Complete"
        Write-Host "GitHub CLI instalado con éxito." -ForegroundColor Green
    }
}

# ==========================================
# 6. Gestión e Instalación de WezTerm Portable
# ==========================================
$wezDir = Join-Path $portableRoot "wezterm"
$isWezInstalled = Test-Path (Join-Path $wezDir "wezterm.exe")
$isWezComplete = Test-Path (Join-Path $portableRoot ".wezterm_complete")

# Obtener URL de descarga de WezTerm (pin del manifiesto tiene prioridad)
$wezDownloadUrl = Get-Pinned 'wezterm'
$wezFallbackUrl = if ($pinF = Get-Pinned 'wezterm_fallback') { $pinF } else { "https://github.com/wez/wezterm/releases/download/20240203-110809-5046fc22/WezTerm-windows-20240203-110809-5046fc22.zip" }

if ($isUpdateMode -or -not $isWezComplete) {
    if ($wezDownloadUrl) {
        Write-Host "WezTerm fijado por el manifiesto de versiones." -ForegroundColor DarkGray
    } else {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $wezReleaseUrl = "https://api.github.com/repos/wez/wezterm/releases/latest"
        Write-Host "Consultando API de GitHub por la última versión de WezTerm..."
        $wezRelease = Get-GitHubApiCached -Url $wezReleaseUrl
        $wezAsset = $wezRelease.assets | Where-Object { $_.name -like "WezTerm-windows-*.zip" -and $_.name -notlike "*setup*" }
        if ($wezAsset) {
            $wezDownloadUrl = $wezAsset.browser_download_url
            Write-Host "Última versión detectada de WezTerm: $($wezAsset.name)" -ForegroundColor Green
        }
    } catch {
        Write-Warning "Fallo al consultar la API de GitHub para WezTerm. Usando fallback fijo."
    }

    if (-not $wezDownloadUrl) {
        $wezDownloadUrl = $wezFallbackUrl
        Write-Host "Fallback URL WezTerm: $wezDownloadUrl" -ForegroundColor Yellow
    }
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
            $installedWezUrl = (Get-Content $installedWezVersionFile -Raw).Trim()
        }
        
        if ($wezDownloadUrl -ne $installedWezUrl) {
            # Si se usó la URL de fallback porque falló la API y ya hay una versión instalada,
            # asumimos que la instalada es válida para no sugerir un downgrade o alertar innecesariamente.
            $isFallback = ($wezDownloadUrl -eq $wezFallbackUrl)
            if ($isFallback -and $installedWezUrl) {
                Write-Host "Omitiendo comprobación de actualización de WezTerm (la API de GitHub no está disponible)." -ForegroundColor Green
            } else {
                Write-Host "Hay una nueva versión de WezTerm disponible para actualizar (o no pudo verificarse la versión local)." -ForegroundColor Yellow
                if ($Yes -or ((Read-Host "¿Deseás descargar e instalar la actualización de WezTerm? (s/n)") -match "^[sS]$")) {
                    $shouldInstallOrUpdateWez = $true
                    if ($Yes) { Write-Host "(--Yes) Actualizando WezTerm automáticamente..." -ForegroundColor DarkGray }
                } else {
                    Write-Host "Omitiendo actualización de WezTerm." -ForegroundColor DarkGray
                }
            }
        } else {
            Write-Host "WezTerm ya se encuentra en la versión más reciente ($wezDownloadUrl)." -ForegroundColor Green
        }
    } else {
        $shouldInstallOrUpdateWez = $true
    }

    if ($shouldInstallOrUpdateWez) {
        if (-not $isUpdateMode -and $isWezInstalled) {
            Write-Host "Se detectó una instalación previa incompleta de WezTerm. Se continuará con la instalación existente..." -ForegroundColor Yellow
        } else {
            # Resolver nombre de archivo de forma dinámica
            $wezZipName = Get-FileNameFromUrl -Url $wezDownloadUrl -DefaultName "wezterm_archive.zip"
            $wezZipPath = Join-Path $descargasDir $wezZipName

            $isWezZipValid = $false
            if (Test-Path $wezZipPath) {
                Write-Host "Se detectó un archivo ZIP de WezTerm descargado previamente ($wezZipName). Verificando..." -ForegroundColor Yellow
                try {
                    $fileSize = (Get-Item $wezZipPath).Length
                    if ($fileSize -gt 10MB) {
                        $sidecar = "$wezZipPath.sha256"
                        if (Test-Path $sidecar) {
                            $expectedHash = (Get-Content $sidecar -Raw).Trim()
                            $actualHash = (Get-FileHash -Path $wezZipPath -Algorithm SHA256).Hash
                            if ($actualHash -ne $expectedHash) {
                                Write-Host "El ZIP previo de WezTerm está corrupto (SHA256 no coincide). Se volverá a descargar." -ForegroundColor Yellow
                            } else {
                                $isWezZipValid = $true
                                Write-Host "El ZIP previo de WezTerm es válido (SHA256 verificado)." -ForegroundColor Green
                            }
                        } else {
                            $isWezZipValid = $true
                            Write-Host "El archivo ZIP previo de WezTerm es válido (sin hash previo registrado)." -ForegroundColor Green
                        }
                    } else {
                        Write-Host "El archivo ZIP previo de WezTerm está incompleto. Se volverá a descargar." -ForegroundColor Yellow
                    }
                } catch {
                    Write-Host "No se pudo verificar el archivo ZIP previo de WezTerm. Se volverá a descargar." -ForegroundColor Yellow
                }
            }

            if (-not $isWezZipValid) {
                Write-Host "Descargando WezTerm desde $wezDownloadUrl..." -ForegroundColor Cyan
                Invoke-DownloadWithRetry -Url $wezDownloadUrl -OutFile $wezZipPath
                (Get-FileHash -Path $wezZipPath -Algorithm SHA256).Hash | Set-Content -Path "$wezZipPath.sha256"
            }

            # Actualización atómica: extraer y aplanar en un directorio temporal,
            # validar wezterm.exe y recién entonces reemplazar la instalación vigente.
            $wezExtractTemp = Join-Path $descargasDir "wezterm_extract"
            try {
                if (Test-Path $wezExtractTemp) {
                    Remove-Item -Path $wezExtractTemp -Recurse -Force -ErrorAction SilentlyContinue
                }
                New-Item -ItemType Directory -Path $wezExtractTemp | Out-Null

                Write-Host "Extrayendo WezTerm a directorio temporal..." -ForegroundColor Cyan
                Expand-Archive -Path $wezZipPath -DestinationPath $wezExtractTemp -Force

                # Si la descompresión creó un subdirectorio (ej: WezTerm-windows-...), aplanar dentro del temporal
                $subExe = Get-ChildItem -Path $wezExtractTemp -Filter "wezterm.exe" -Recurse | Select-Object -First 1
                if (-not $subExe) {
                    throw "El ZIP extraído no contiene wezterm.exe; se cancela el reemplazo de la instalación vigente."
                }
                if ($subExe.DirectoryName -ne $wezExtractTemp) {
                    Write-Host "Aplanando estructura de carpetas de WezTerm..." -ForegroundColor Cyan
                    Get-ChildItem -Path $subExe.DirectoryName | Move-Item -Destination $wezExtractTemp -Force
                    Remove-Item -Path $subExe.DirectoryName -Recurse -Force
                }

                if (Test-Path $wezDir) {
                    Write-Host "Reemplazando instalación anterior de WezTerm..." -ForegroundColor Cyan
                    Remove-Item -Path $wezDir -Recurse -Force -ErrorAction SilentlyContinue
                }
                Move-Item -Path $wezExtractTemp -Destination $wezDir
            } catch {
                Write-Warning "Fallo durante la actualización de WezTerm: $_"
                throw
            } finally {
                if (Test-Path $wezExtractTemp) {
                    Remove-Item -Path $wezExtractTemp -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }
        
        Set-Content -Path (Join-Path $wezDir ".version") -Value $wezDownloadUrl
        Set-Content -Path (Join-Path $portableRoot ".wezterm_complete") -Value "Complete"
        Write-Host "WezTerm Portable instalado con éxito." -ForegroundColor Green
    }
}

# Escribir configuración wezterm.lua a partir de la plantilla canónica única
$wezConfigPath = Join-Path $portableRoot "wezterm.lua"
$wezTemplateFile = Join-Path $portableRoot "wezterm.lua.template"
if (-not (Test-Path $wezConfigPath) -or $isUpdateMode -or $shouldInstallOrUpdateWez) {
    if (-not (Test-Path $wezTemplateFile)) {
        throw "No se encontró wezterm.lua.template en la raíz del entorno."
    }
    $wezConfigContent = Get-Content $wezTemplateFile -Raw
    $wezConfigContent = $wezConfigContent.Replace('@HOME_DIR_NAME@', $HomeDirName)
    [System.IO.File]::WriteAllText($wezConfigPath, $wezConfigContent, $utf8NoBom)
    Write-Host "Configuración wezterm.lua creada/actualizada desde la plantilla." -ForegroundColor Green
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
        
        # Configurar el perfil de terminal Bash UCRT64
        $terminalProfiles = @{
            "UCRT64 Bash" = @{
                "path" = "bash.exe"
                "args" = @("--login", "-i")
            }
        }
        $settingsObj | Add-Member -NotePropertyName "terminal.integrated.profiles.windows" -NotePropertyValue $terminalProfiles -Force
        $settingsObj | Add-Member -NotePropertyName "terminal.integrated.defaultProfile.windows" -NotePropertyValue "UCRT64 Bash" -Force
        
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
# Se mantiene la carpeta 'descargas' de forma permanente como caché local para acelerar futuras instalaciones.

    # Guardar el indicador final de instalación completa exitosa
    Set-Content -Path (Join-Path $portableRoot ".install_complete") -Value "Complete"

    # Resumen de componentes para el usuario
    Write-Host "`n--- ESTADO DE COMPONENTES ---" -ForegroundColor Cyan
    $summaryComponents = @(
        @{ Name = "MSYS2 (GCC, make, cmake, python)"; Ok = (Test-Path (Join-Path $msysDir "usr\bin\bash.exe")) },
        @{ Name = "VS Code Portable";                 Ok = (Test-Path (Join-Path $vscodeDir "Code.exe")) },
        @{ Name = "WezTerm";                          Ok = (Test-Path (Join-Path $portableRoot "wezterm\wezterm.exe")) },
        @{ Name = "GitHub CLI";                       Ok = (Test-Path (Join-Path $portableRoot "bin\gh.exe")) }
    )
    foreach ($comp in $summaryComponents) {
        $state = if ($comp.Ok) { "[OK]   " } else { "[FALTA]" }
        $color = if ($comp.Ok) { "Green" } else { "Yellow" }
        Write-Host ("  {0} {1}" -f $state, $comp.Name) -ForegroundColor $color
    }

    Write-Host "`n=== ENTORNO PORTABLE CONFIGURADO Y LISTO ===" -ForegroundColor Green
    Write-Host "Ejecutá 'launch.bat' para iniciar la consola." -ForegroundColor Green
    Write-Host "Ejecutá 'launch-vscode.bat' para iniciar VS Code." -ForegroundColor Green
}
finally {
    if ($transcriptStarted) {
        Write-Host "`n======================================================================"
        Write-Host "FIN DE LA INSTALACIÓN: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        Write-Host "======================================================================"
        try {
            Stop-Transcript -ErrorAction SilentlyContinue | Out-Null
        } catch {
            # Ignorar si no está transcribiendo en este momento
        }
    }
}
