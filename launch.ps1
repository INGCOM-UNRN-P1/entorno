# launch.ps1 - Lanzador del entorno portable en PowerShell

$ErrorActionPreference = "Stop"

$portableRoot = $PSScriptRoot

# Validar espacios, caracteres no ASCII o carpetas sincronizadas en la ruta de instalación
$hasSpaces = $portableRoot -match " "
$hasNonAscii = $portableRoot -match "[^\u0000-\u007F]"
$hasSyncFolder = $portableRoot -match "(?i)onedrive|dropbox|google\s+drive|icloud"

if ($hasSpaces -or $hasNonAscii -or $hasSyncFolder) {
    Write-Host "==========================================================================" -ForegroundColor Yellow
    Write-Host "[ADVERTENCIA] La ruta de instalación contiene caracteres conflictivos:" -ForegroundColor Yellow
    if ($hasSpaces) { 
        Write-Host "* Espacios en blanco." -ForegroundColor Yellow 
    }
    if ($hasNonAscii) {
        Write-Host "* Caracteres no ASCII (acentos, eñes, etc.)." -ForegroundColor Yellow 
    }
    if ($hasSyncFolder) {
        Write-Host "* Carpeta sincronizada (OneDrive/Dropbox/etc.), puede corromper compilaciones." -ForegroundColor Yellow 
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
        if (-not ($homeDirName -match "^[a-zA-Z0-9_][a-zA-Z0-9_-]*$")) {
            $homeDirName = "home"
        }
    }
}

$homeDir = Join-Path $portableRoot $homeDirName
$msysDir = Join-Path $portableRoot "msys64"
$wezDir  = Join-Path $portableRoot "wezterm"
$wezExe  = Join-Path $wezDir "wezterm-gui.exe"
if (-not (Test-Path $wezExe)) {
    $wezExe  = Join-Path $wezDir "wezterm.exe"
}
$bashPath = Join-Path $msysDir "usr\bin\bash.exe"

# Asegurar existencia del HOME portable y sus archivos de inicio (skel)
if (-not (Test-Path $homeDir)) {
    New-Item -ItemType Directory -Path $homeDir | Out-Null
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

$bashProfilePath = Join-Path $homeDir ".bash_profile"
if (-not (Test-Path $bashProfilePath)) {
    $bashProfileContent = @'
if [ -f "${HOME}/.bashrc" ] ; then
  source "${HOME}/.bashrc"
fi
'@
    [System.IO.File]::WriteAllText($bashProfilePath, $bashProfileContent, $utf8NoBom)
}

$bashrcPath = Join-Path $homeDir ".bashrc"
if (-not (Test-Path $bashrcPath)) {
    $bashrcContent = @'
# .bashrc
# Aquí podés agregar tus alias y funciones personalizadas.

# Agregar bin portable al PATH en formato Unix (sin duplicar en shells anidados)
if [ -n "$PORTABLE_ROOT" ]; then
    UNIX_ROOT=$(cygpath -u "$PORTABLE_ROOT")
    case ":$PATH:" in
        *":${UNIX_ROOT}bin:"*) : ;;
        *) export PATH="${UNIX_ROOT}bin:${UNIX_ROOT}msys64/ucrt64/bin:${UNIX_ROOT}msys64/usr/bin:${PATH}" ;;
    esac
fi
'@
    [System.IO.File]::WriteAllText($bashrcPath, $bashrcContent, $utf8NoBom)
}

# Inyectar variables de entorno de sesión
$env:PORTABLE_ROOT = $portableRoot
$env:HOME = $homeDir
$env:MSYSTEM = "UCRT64"
$env:CHERE_INVOKING = "1"
$env:LANG = "es_AR.UTF-8"
$wezConfigPath = Join-Path $portableRoot "wezterm.lua"
$env:WEZTERM_CONFIG_FILE = $wezConfigPath

# Asegurar que wezterm.lua exista, generandolo desde la plantilla canonica unica
if (-not (Test-Path $wezConfigPath)) {
    $wezTemplateFile = Join-Path $portableRoot "wezterm.lua.template"
    if (Test-Path $wezTemplateFile) {
        $wezConfigContent = Get-Content $wezTemplateFile -Raw
        $wezConfigContent = $wezConfigContent.Replace('@HOME_DIR_NAME@', $homeDirName)
        [System.IO.File]::WriteAllText($wezConfigPath, $wezConfigContent, $utf8NoBom)
        Write-Host "[INFO] wezterm.lua generado desde la plantilla canonica." -ForegroundColor Cyan
    } else {
        Write-Warning "Falta wezterm.lua.template: no se pudo generar la configuracion de WezTerm."
    }
} else {
    # Correccion minima para instalaciones historicas con MSYSTEM o rutas erroneas
    $content = [System.IO.File]::ReadAllText($wezConfigPath, [System.Text.Encoding]::UTF8)
    $fixed = $content -replace 'MSYSTEM\s*=\s*"(CLANG|MINGW)64"', 'MSYSTEM = "UCRT64"'
    $fixed = $fixed -replace 'msys64/(clang|mingw)64/', 'msys64/ucrt64/'
    if ($fixed -ne $content) {
        [System.IO.File]::WriteAllText($wezConfigPath, $fixed, $utf8NoBom)
        Write-Host "[INFO] wezterm.lua normalizado a UCRT64." -ForegroundColor DarkGray
    }
}

# Agregar scripts internos, compilador y userland de MSYS2 al Path
$binPath   = Join-Path $portableRoot "bin"
$gccPath   = Join-Path $portableRoot "msys64\ucrt64\bin"
$usrPath   = Join-Path $portableRoot "msys64\usr\bin"
$env:PATH  = "$binPath;$gccPath;$usrPath;$env:PATH"

# Variables específicas del Toolchain de C/C++
# (No se definen GCC_EXEC_PREFIX, LIBRARY_PATH, ni INCLUDE_PATH manualmente
# porque GCC en MSYS2 resuelve automáticamente sus directorios internos 
# relativos a la ubicación de gcc.exe en ucrt64)

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
$env:WEZTERM_ROOT = $wezDir

# Autocorrección estructural para WezTerm (aplanado de directorios)
if (-not (Test-Path $wezExe) -and (Test-Path $wezDir)) {
    $subDirExe = Get-ChildItem -Path $wezDir -Filter "wezterm.exe" -Recurse | Select-Object -First 1
    if ($subDirExe) {
        $subDir = $subDirExe.Directory
        Write-Host "[INFO] Corrigiendo estructura de carpetas de WezTerm..." -ForegroundColor Cyan
        Get-ChildItem -Path $subDir.FullName | Move-Item -Destination $wezDir -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $subDir.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Lanzar WezTerm o fallar de vuelta a Bash estándar
if (Test-Path $wezExe) {
    $si = New-Object System.Diagnostics.ProcessStartInfo
    $si.FileName = $wezExe
    $si.UseShellExecute = $true
    [System.Diagnostics.Process]::Start($si) | Out-Null
} else {
    Write-Host "[INFO] WezTerm no encontrado. Lanzando Bash en consola estándar..." -ForegroundColor Yellow
    if (-not (Test-Path $bashPath)) {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show("No se encuentra la instalación de MSYS2 en la ruta:`n$msysDir`n`nPor favor, ejecutá setup.ps1 primero para instalar el entorno completo.", "Error - Lanzador Portable", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }
    & $bashPath --login -i
}
