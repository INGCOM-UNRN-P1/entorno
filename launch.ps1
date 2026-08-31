# launch.ps1 - Lanzador del entorno portable en PowerShell

$ErrorActionPreference = "Stop"

$portableRoot = $PSScriptRoot

# Logica compartida con launch-vscode.ps1 (advertencia de ruta, .env, sesion)
Import-Module (Join-Path $portableRoot "env.common.psm1") -Force

# Advertencia temprana ante espacios, caracteres no ASCII o carpetas sincronizadas
$infoRuta = Test-ConflictivePath -Path $portableRoot
if ($infoRuta.IsConflictive) {
    Show-PathWarning -Path $portableRoot
}

# Cargar configuracion de directorio HOME
$homeDirName = Get-PortableHomeName -PortableRoot $portableRoot

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
# Aqui podes agregar tus alias y funciones personalizadas.

# Agregar bin portable al PATH en formato Unix (sin duplicar en shells anidados)
if [ -n "$PORTABLE_ROOT" ]; then
    UNIX_ROOT=$(cygpath -u "$PORTABLE_ROOT")
    case ":$PATH:" in
        *":${UNIX_ROOT}/bin:"*) : ;;
        *) export PATH="${UNIX_ROOT}/bin:${UNIX_ROOT}/msys64/ucrt64/bin:${UNIX_ROOT}/msys64/usr/bin:${PATH}" ;;
    esac
fi
'@
    [System.IO.File]::WriteAllText($bashrcPath, $bashrcContent, $utf8NoBom)
}

# Inyectar la sesion portable comun (HOME, PATH del toolchain, variables de C/C++)
Set-PortableSession -PortableRoot $portableRoot -HomeDirName $homeDirName | Out-Null

# Configuracion de WezTerm para esta sesion
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

# Autocorreccion estructural para WezTerm (aplanado de directorios)
if (-not (Test-Path $wezExe) -and (Test-Path $wezDir)) {
    $subDirExe = Get-ChildItem -Path $wezDir -Filter "wezterm.exe" -Recurse | Select-Object -First 1
    if ($subDirExe) {
        $subDir = $subDirExe.Directory
        Write-Host "[INFO] Corrigiendo estructura de carpetas de WezTerm..." -ForegroundColor Cyan
        Get-ChildItem -Path $subDir.FullName | Move-Item -Destination $wezDir -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $subDir.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Lanzar WezTerm o fallar de vuelta a Bash estandar
if (Test-Path $wezExe) {
    $si = New-Object System.Diagnostics.ProcessStartInfo
    $si.FileName = $wezExe
    $si.UseShellExecute = $true
    [System.Diagnostics.Process]::Start($si) | Out-Null
} else {
    Write-Host "[INFO] WezTerm no encontrado. Lanzando Bash en consola estandar..." -ForegroundColor Yellow
    if (-not (Test-Path $bashPath)) {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show("No se encuentra la instalacion de MSYS2 en la ruta:`n$msysDir`n`nPor favor, ejecuta setup.ps1 primero para instalar el entorno completo.", "Error - Lanzador Portable", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }
    & $bashPath --login -i
}
