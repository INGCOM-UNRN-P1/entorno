# launch-vscode.ps1 - Lanzador de VS Code con entorno portable

$ErrorActionPreference = "Stop"

$portableRoot = $PSScriptRoot

# Validar espacios o caracteres no ASCII en la ruta de instalación
$hasSpaces = $portableRoot -match " "
$hasNonAscii = $portableRoot -match "[^\u0000-\u007F]"

if ($hasSpaces -or $hasNonAscii) {
    Write-Host "==========================================================================" -ForegroundColor Yellow
    Write-Host "[ADVERTENCIA] La ruta de instalación contiene caracteres conflictivos:" -ForegroundColor Yellow
    if ($hasSpaces) {
        Write-Host "* Espacios en blanco." -ForegroundColor Yellow
    }
    if ($hasNonAscii) {
        Write-Host "* Caracteres no ASCII (acentos, eñes, etc.)." -ForegroundColor Yellow
    }
    Write-Host "Ruta: '$portableRoot'"
    Write-Host "Esto puede romper herramientas de compilación de C (Make, CMake, etc.)."
    Write-Host "Se recomienda mover el entorno a una ruta simple (Ej: C:\dev\entorno)."
    Write-Host "==========================================================================" -ForegroundColor Yellow
    Write-Host ""
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
$vscodeDir = Join-Path $portableRoot "vscode"
$codeExe = Join-Path $vscodeDir "Code.exe"

# Asegurar existencia de HOME portable
if (-not (Test-Path $homeDir)) {
    New-Item -ItemType Directory -Path $homeDir | Out-Null
}

# Inyectar variables de entorno de sesión
$env:PORTABLE_ROOT = $portableRoot
$env:HOME = $homeDir
$env:MSYSTEM = "UCRT64"
$env:CHERE_INVOKING = "1"
$env:LANG = "es_AR.UTF-8"

# Prepend de paths de MSYS2, GCC y bin local a la sesión de VS Code
$binPath = Join-Path $portableRoot "bin"
$gccPath = Join-Path $portableRoot "msys64\ucrt64\bin"
$usrPath = Join-Path $portableRoot "msys64\usr\bin"
$env:PATH = "$binPath;$gccPath;$usrPath;$env:PATH"

# Variables específicas del Toolchain de C/C++
$env:CC  = "gcc"
$env:CXX = "g++"
$env:AR  = "ar"
$env:AS  = "as"
$env:LD  = "ld"
$env:CPP = "cpp"
$env:CFLAGS  = "-O2 -Wall"
$env:LDFLAGS = ""
$env:PKG_CONFIG_PATH   = "$(Join-Path $portableRoot 'msys64\ucrt64\lib\pkgconfig');$(Join-Path $portableRoot 'msys64\usr\lib\pkgconfig');$env:PKG_CONFIG_PATH"
$env:CMAKE_PREFIX_PATH = "$(Join-Path $portableRoot 'msys64\ucrt64');$(Join-Path $portableRoot 'msys64\usr');$env:CMAKE_PREFIX_PATH"

# Variables de entorno para integración
$env:VSCODE_ROOT  = Join-Path $portableRoot "vscode"
$env:WEZTERM_ROOT = Join-Path $portableRoot "wezterm"

# Validar existencia de VS Code
if (-not (Test-Path $codeExe)) {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show("No se encuentra la instalación de VS Code en la ruta:`n$vscodeDir`n`nPor favor, ejecutá setup.ps1 primero para instalar el entorno completo.", "Error - Lanzador Portable", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    return
}

# Configurar la ruta del compilador en settings.json de VS Code para asegurar que IntelliSense lo ubique sin importar la ruta del host
$settingsUserDir = Join-Path $vscodeDir "data\user-data\User"
$settingsJsonPath = Join-Path $settingsUserDir "settings.json"

if (Test-Path $vscodeDir) {
    if (-not (Test-Path $settingsUserDir)) {
        New-Item -ItemType Directory -Path $settingsUserDir -Force | Out-Null
    }

    # Formatear la ruta de gcc con barras inclinadas hacia adelante
    $gccExeUrl = (Join-Path $portableRoot "msys64\ucrt64\bin\gcc.exe").Replace("\", "/")

    # Parcheo quirúrgico: modificar únicamente las claves C_Cpp.default.* preservando
    # el resto del archivo tal cual (comentarios, orden y formato definidos por el usuario).
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
        # Guardar con codificación UTF-8 con BOM
        $utf8WithBom = New-Object System.Text.UTF8Encoding($true)
        [System.IO.File]::WriteAllText($settingsJsonPath, $content, $utf8WithBom)
    }
}

# Lanzar VS Code heredando el ambiente
if ($args) {
    Start-Process -FilePath $codeExe -ArgumentList $args
} else {
    Start-Process -FilePath $codeExe
}
