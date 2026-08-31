# desinstalar.ps1 - Elimina por completo los componentes generados del entorno portable,
# dejando unicamente los archivos del repositorio. Util al finalizar la cursada o para
# liberar espacio en computadoras compartidas.
#
# NO requiere permisos de administrador: solo borra dentro de esta carpeta.

$ErrorActionPreference = "Stop"

$portableRoot = $PSScriptRoot
if ([string]::IsNullOrEmpty($portableRoot)) {
    $portableRoot = (Get-Location).Path
}

# Resolver el nombre del directorio HOME portable desde .env
$homeDirName = "home"
$envFile = Join-Path $portableRoot ".env"
if (Test-Path $envFile) {
    $envContent = Get-Content $envFile -Raw
    if ($envContent -match 'HOME_DIR_NAME=(.*)') {
        $candidate = $Matches[1].Replace('"', '').Trim()
        if ($candidate -match '^[a-zA-Z0-9_][a-zA-Z0-9_-]*$') {
            $homeDirName = $candidate
        }
    }
}

# Componentes generados por setup.ps1 y el uso del entorno (nunca toca los scripts del repo)
$targets = @(
    @{ Path = Join-Path $portableRoot "msys64";  Desc = "Compiladores y userland MSYS2 (~2 GB)" },
    @{ Path = Join-Path $portableRoot "vscode";  Desc = "VS Code Portable y extensiones" },
    @{ Path = Join-Path $portableRoot "wezterm"; Desc = "Terminal WezTerm" },
    @{ Path = Join-Path $portableRoot "descargas"; Desc = "Cache de descargas e instaladores" },
    @{ Path = Join-Path $portableRoot "downloads"; Desc = "Cache de descargas (nombre historico)" },
    @{ Path = Join-Path $portableRoot "local";   Desc = "Librerias instaladas con install-lib.sh" },
    @{ Path = Join-Path $portableRoot $homeDirName; Desc = "HOME portable ($homeDirName/): configuraciones y datos de usuario" },
    @{ Path = Join-Path $portableRoot "vscode_data_backup"; Desc = "Respaldos antiguos de VS Code" },
    @{ Path = Join-Path $portableRoot "gh_temp"; Desc = "Temporales de GitHub CLI" },
    @{ Path = Join-Path $portableRoot "wezterm.lua"; Desc = "Configuracion local de WezTerm" },
    @{ Path = Join-Path $portableRoot ".env"; Desc = "Configuracion local del entorno" },
    @{ Path = Join-Path $portableRoot ".install_complete"; Desc = "Marcador de instalacion" },
    @{ Path = Join-Path $portableRoot ".msys_complete"; Desc = "Marcador de instalacion" },
    @{ Path = Join-Path $portableRoot ".vscode_complete"; Desc = "Marcador de instalacion" },
    @{ Path = Join-Path $portableRoot ".gh_complete"; Desc = "Marcador de instalacion" },
    @{ Path = Join-Path $portableRoot ".wezterm_complete"; Desc = "Marcador de instalacion" }
)

Write-Host "==========================================================================" -ForegroundColor Red
Write-Host "            DESINSTALACION DEL ENTORNO PORTABLE                            " -ForegroundColor Red
Write-Host "==========================================================================" -ForegroundColor Red
Write-Host "Se eliminaran permanentemente los siguientes componentes:"
Write-Host ""
foreach ($t in $targets) {
    if (Test-Path $t.Path) {
        Write-Host ("  * {0}" -f $t.Path.Replace($portableRoot, ".")) -ForegroundColor Yellow
        Write-Host ("      ({0})" -f $t.Desc) -ForegroundColor DarkGray
    }
}
Write-Host ""
Write-Host "Los scripts del repositorio y tu carpeta Git (.git) NO se modifican." -ForegroundColor Green
Write-Host ""

$choice = Read-Host "Esta accion es IRREVERSIBLE. Deseas desinstalar? (s/n)"
if ($choice -notmatch "^[sS]$") {
    Write-Host "Operacion cancelada. No se modifico nada." -ForegroundColor Green
    exit 0
}

foreach ($t in $targets) {
    if (Test-Path $t.Path) {
        Write-Host "* Eliminando $($t.Path.Replace($portableRoot, '.'))..." -ForegroundColor Cyan
        Remove-Item -Path $t.Path -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "`n=== DESINSTALACION COMPLETADA ===" -ForegroundColor Green
Write-Host "El repositorio quedo limpio; podes volver a inicializar el entorno en cualquier"
Write-Host "momento ejecutando setup.ps1 (Windows) o usando la variante linux/." -ForegroundColor Green
