# env.common.psm1 - Lógica compartida por los lanzadores del entorno portable.
# Consumido por launch.ps1 y launch-vscode.ps1: advertencia de ruta conflictiva,
# resolución del HOME portable desde .env e inyección de la sesión de trabajo
# (PATH del toolchain y variables de C/C++) en el proceso que lanza la GUI.
# Compatible con Windows PowerShell 5.1 y PowerShell 7 (pwsh).

function Test-ConflictivePath {
    <#
    .SYNOPSIS
    Detecta condiciones de ruta que rompen herramientas de compilación.
    .OUTPUTS
    PSCustomObject con HasSpaces, HasNonAscii, HasSyncFolder e IsConflictive.
    #>
    param([string]$Path)

    $hasSpaces = $Path -match " "
    $hasNonAscii = $Path -match "[^\u0000-\u007F]"
    $hasSyncFolder = $Path -match "(?i)onedrive|dropbox|google\s+drive|icloud"

    return [pscustomobject]@{
        HasSpaces     = $hasSpaces
        HasNonAscii   = $hasNonAscii
        HasSyncFolder = $hasSyncFolder
        IsConflictive = ($hasSpaces -or $hasNonAscii -or $hasSyncFolder)
    }
}

function Show-PathWarning {
    <#
    .SYNOPSIS
    Imprime la advertencia detallada de ruta conflictiva en la consola.
    #>
    param([string]$Path)

    $info = Test-ConflictivePath -Path $Path
    Write-Host "==========================================================================" -ForegroundColor Yellow
    Write-Host "[ADVERTENCIA] La ruta de instalación contiene caracteres conflictivos:" -ForegroundColor Yellow
    if ($info.HasSpaces) {
        Write-Host "* Espacios en blanco." -ForegroundColor Yellow
    }
    if ($info.HasNonAscii) {
        Write-Host "* Caracteres no ASCII (acentos, eñes, etc.)." -ForegroundColor Yellow
    }
    if ($info.HasSyncFolder) {
        Write-Host "* Carpeta sincronizada (OneDrive/Dropbox/etc.), puede corromper compilaciones." -ForegroundColor Yellow
    }
    Write-Host "Ruta: '$Path'"
    Write-Host "Esto puede romper herramientas de compilación de C (Make, CMake, etc.)."
    Write-Host "Se recomienda mover el entorno a una ruta simple (Ej: C:\dev\entorno)."
    Write-Host "==========================================================================" -ForegroundColor Yellow
    Write-Host ""
}

function Get-PortableHomeName {
    <#
    .SYNOPSIS
    Resuelve el nombre del directorio HOME portable desde .env (clave
    HOME_DIR_NAME, con o sin comillas y con o sin 'set'). Devuelve "home"
    ante ausencia de archivo o valor inválido.
    #>
    param([string]$PortableRoot)

    $homeDirName = "home"
    $envFile = Join-Path $PortableRoot ".env"
    if (Test-Path $envFile) {
        $envContent = Get-Content $envFile -Raw
        if ($envContent -match 'HOME_DIR_NAME=(.*)') {
            $candidate = $Matches[1].Replace('"', '').Trim()
            if ($candidate -match "^[a-zA-Z0-9_][a-zA-Z0-9_-]*$") {
                $homeDirName = $candidate
            }
        }
    }
    return $homeDirName
}

function Set-PortableSession {
    <#
    .SYNOPSIS
    Inyecta la sesión portable completa en el proceso actual: crea el HOME
    portable si falta, antepone los PATH del entorno y exporta las variables
    del toolchain de C/C++ hacia MSYS2 UCRT64. Devuelve la ruta del HOME.
    #>
    param(
        [string]$PortableRoot,
        [string]$HomeDirName = "home"
    )

    $homeDir = Join-Path $PortableRoot $HomeDirName
    if (-not (Test-Path $homeDir)) {
        New-Item -ItemType Directory -Path $homeDir | Out-Null
    }

    # Variables base de la sesión portable
    $env:PORTABLE_ROOT = $PortableRoot
    $env:HOME = $homeDir
    $env:MSYSTEM = "UCRT64"
    $env:CHERE_INVOKING = "1"
    $env:LANG = "es_AR.UTF-8"

    # Scripts internos, compilador y userland de MSYS2 al frente del PATH
    $binPath = Join-Path $PortableRoot "bin"
    $gccPath = Join-Path $PortableRoot "msys64\ucrt64\bin"
    $usrPath = Join-Path $PortableRoot "msys64\usr\bin"
    $env:PATH = "$binPath;$gccPath;$usrPath;$env:PATH"

    # Variables específicas del Toolchain de C/C++
    # (GCC en MSYS2 resuelve sus directorios internos relativos a su ubicación;
    # no se definen GCC_EXEC_PREFIX ni LIBRARY_PATH manualmente)
    $env:CC  = "gcc"
    $env:CXX = "g++"
    $env:AR  = "ar"
    $env:AS  = "as"
    $env:LD  = "ld"
    $env:CPP = "cpp"
    $env:CFLAGS  = "-O2 -Wall"
    $env:LDFLAGS = ""
    $env:PKG_CONFIG_PATH   = "$(Join-Path $PortableRoot 'msys64\ucrt64\lib\pkgconfig');$(Join-Path $PortableRoot 'msys64\usr\lib\pkgconfig');$env:PKG_CONFIG_PATH"
    $env:CMAKE_PREFIX_PATH = "$(Join-Path $PortableRoot 'msys64\ucrt64');$(Join-Path $PortableRoot 'msys64\usr');$env:CMAKE_PREFIX_PATH"

    # Variables para integraciones (VS Code, WezTerm)
    $env:VSCODE_ROOT  = Join-Path $PortableRoot "vscode"
    $env:WEZTERM_ROOT = Join-Path $PortableRoot "wezterm"

    return $homeDir
}

function Set-VsCodeCompilerSettings {
    <#
    .SYNOPSIS
    Parcheo quirúrgico del settings.json de VS Code: actualiza únicamente las
    claves C_Cpp.default.* (ruta del compilador e IntelliSense) preservando el
    resto del archivo tal cual (comentarios, orden y formato del usuario).
    Escribe solo si hubo cambios, en UTF-8 con BOM. Devuelve $true si escribió.
    #>
    param(
        [string]$PortableRoot,
        [string]$VscodeDir
    )

    $settingsUserDir = Join-Path $VscodeDir "data\user-data\User"
    $settingsJsonPath = Join-Path $settingsUserDir "settings.json"
    if (-not (Test-Path $settingsUserDir)) {
        New-Item -ItemType Directory -Path $settingsUserDir -Force | Out-Null
    }

    # Ruta de gcc con barras inclinadas hacia adelante
    $gccExeUrl = (Join-Path $PortableRoot "msys64\ucrt64\bin\gcc.exe").Replace("\", "/")

    $content = ""
    if (Test-Path $settingsJsonPath) {
        $content = Get-Content $settingsJsonPath -Raw
    }
    if ([string]::IsNullOrWhiteSpace($content)) { $content = "{}" }

    $originalContent = $content
    foreach ($entry in @(
        @{ Key = "C_Cpp.default.compilerPath"; Value = $gccExeUrl },
        @{ Key = "C_Cpp.default.intelliSenseMode"; Value = "windows-gcc-x64" }
    )) {
        $key = $entry.Key
        $valueJson = '"' + $entry.Value + '"'
        $pattern = '"' + [regex]::Escape($key) + '"\s*:\s*"[^"]*"'
        if ($content -match $pattern) {
            $content = [regex]::Replace($content, $pattern, ('"' + $key + '": ' + $valueJson))
        } else {
            # La clave no existe: insertarla como primera entrada del objeto principal
            $trimmed = $content.TrimStart()
            if ($trimmed.StartsWith("{") -and -not [string]::IsNullOrWhiteSpace($trimmed.TrimStart("{").Trim())) {
                $rest = $trimmed.Substring(1)
                $content = "{`n    `"$key`": $valueJson,`n" + $rest
            } elseif ($trimmed.StartsWith("{")) {
                $content = "{ `"$key`": $valueJson }"
            } else {
                $content = "{ `"$key`": $valueJson }"
            }
        }
    }

    if ($content -ne $originalContent) {
        Write-Host "[INFO] Actualizando ruta del compilador en settings.json..." -ForegroundColor DarkGray
        $utf8WithBom = New-Object System.Text.UTF8Encoding($true)
        [System.IO.File]::WriteAllText($settingsJsonPath, $content, $utf8WithBom)
        return $true
    }
    return $false
}

Export-ModuleMember -Function Test-ConflictivePath, Show-PathWarning, Get-PortableHomeName, Set-PortableSession, Set-VsCodeCompilerSettings
