# test_env_common.ps1 - Pruebas del módulo compartido de los lanzadores
# (env.common.psm1). Se ejecutan en cualquier plataforma con PowerShell 7.
#
# Uso:  pwsh -NoProfile -File tests/test_env_common.ps1

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $RepoRoot "env.common.psm1") -Force

$Fail = 0
function Assert-True {
    param([string]$Desc, [bool]$Condition)
    if ($Condition) { Write-Host "OK: $Desc" }
    else { Write-Host "FALLA: $Desc"; $script:Fail++ }
}

# ============================================================
# 1. Test-ConflictivePath
# ============================================================
$r = Test-ConflictivePath -Path "C:\dev\entorno"
Assert-True "ruta limpia no es conflictiva" (-not $r.IsConflictive)

$r = Test-ConflictivePath -Path "C:\Users\juan perez\entorno"
Assert-True "espacios detectados" ($r.HasSpaces -and $r.IsConflictive)

$r = Test-ConflictivePath -Path "C:\users\josé\entorno"
Assert-True "caracteres no ASCII detectados" ($r.HasNonAscii -and $r.IsConflictive)

foreach ($sincronizada in @("C:\Users\x\OneDrive\entorno", "D:\Dropbox\p1", "E:\Google Drive\p1", "F:\iCloud\p1")) {
    $r = Test-ConflictivePath -Path $sincronizada
    Assert-True "carpeta sincronizada detectada: $sincronizada" ($r.HasSyncFolder -and $r.IsConflictive)
}

# ============================================================
# 2. Get-PortableHomeName
# ============================================================
$root = Join-Path ([System.IO.Path]::GetTempPath()) ("envcommon-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $root | Out-Null

try {
    Assert-True "sin .env usa 'home'" ((Get-PortableHomeName -PortableRoot $root) -eq "home")

    Set-Content (Join-Path $root ".env") -Value 'set "HOME_DIR_NAME=alumno2026"'
    Assert-True 'formato canónico set "..." se respeta' ((Get-PortableHomeName -PortableRoot $root) -eq "alumno2026")

    Set-Content (Join-Path $root ".env") -Value 'HOME_DIR_NAME="mi_home"'
    Assert-True "forma plana con comillas se respeta" ((Get-PortableHomeName -PortableRoot $root) -eq "mi_home")

    Set-Content (Join-Path $root ".env") -Value 'HOME_DIR_NAME=../intruso'
    Assert-True "valor invalido cae a 'home'" ((Get-PortableHomeName -PortableRoot $root) -eq "home")
} finally {
    Remove-Item -Recurse -Force $root -ErrorAction SilentlyContinue
}

# ============================================================
# 3. Set-PortableSession (inyección real sobre el proceso actual)
# ============================================================
$fixture = Join-Path ([System.IO.Path]::GetTempPath()) ("envsession-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $fixture | Out-Null

# Guardar el entorno para restaurarlo al final
$prev = @{}
foreach ($k in @("PORTABLE_ROOT","HOME","MSYSTEM","CHERE_INVOKING","LANG","CC","CXX","AR","AS","LD","CPP","CFLAGS","LDFLAGS","PKG_CONFIG_PATH","CMAKE_PREFIX_PATH","VSCODE_ROOT","WEZTERM_ROOT")) {
    $prev[$k] = [System.Environment]::GetEnvironmentVariable($k)
}
$prevPath = $env:PATH

try {
    Set-Content (Join-Path $fixture ".env") -Value 'set "HOME_DIR_NAME=curso"'
    $homeDevuelto = Set-PortableSession -PortableRoot $fixture -HomeDirName (Get-PortableHomeName -PortableRoot $fixture)

    Assert-True "devuelve la ruta del HOME portable creado" ($homeDevuelto -eq (Join-Path $fixture "curso"))
    Assert-True "el directorio HOME portable se crea si falta" (Test-Path (Join-Path $fixture "curso"))

    Assert-True "PORTABLE_ROOT apunta a la raíz" ($env:PORTABLE_ROOT -eq $fixture)
    Assert-True "HOME redirigido al subdirectorio del .env" ($env:HOME -eq (Join-Path $fixture "curso"))
    Assert-True "MSYSTEM es UCRT64" ($env:MSYSTEM -eq "UCRT64")
    Assert-True "CHERE_INVOKING activo" ($env:CHERE_INVOKING -eq "1")

    $expectedPrefix = "$(Join-Path $fixture 'bin');$(Join-Path $fixture 'msys64\ucrt64\bin');$(Join-Path $fixture 'msys64\usr\bin');"
    Assert-True "PATH con los tres prefijos en orden" ($env:PATH.StartsWith($expectedPrefix))
    Assert-True "PATH conserva el contenido previo" ($env:PATH.Length -gt $expectedPrefix.Length -and $env:PATH.EndsWith($prevPath))

    Assert-True "toolchain C configurado" ($env:CC -eq "gcc" -and $env:CXX -eq "g++" -and $env:CFLAGS -eq "-O2 -Wall")

    $pkgEsperado = "$(Join-Path $fixture 'msys64\ucrt64\lib\pkgconfig');$(Join-Path $fixture 'msys64\usr\lib\pkgconfig');"
    Assert-True "PKG_CONFIG_PATH con ambos prefijos" ($env:PKG_CONFIG_PATH.StartsWith($pkgEsperado))

    $cmakeEsperado = "$(Join-Path $fixture 'msys64\ucrt64');$(Join-Path $fixture 'msys64\usr');"
    Assert-True "CMAKE_PREFIX_PATH con ambos prefijos" ($env:CMAKE_PREFIX_PATH.StartsWith($cmakeEsperado))

    Assert-True "integraciones VSCODE_ROOT/WEZTERM_ROOT" (
        $env:VSCODE_ROOT -eq (Join-Path $fixture "vscode") -and $env:WEZTERM_ROOT -eq (Join-Path $fixture "wezterm"))
} finally {
    # Restaurar el entorno del proceso para no contaminar otras pruebas
    foreach ($k in $prev.Keys) {
        [System.Environment]::SetEnvironmentVariable($k, $prev[$k])
    }
    $env:PATH = $prevPath
    Remove-Item -Recurse -Force $fixture -ErrorAction SilentlyContinue
}

# ============================================================
# Resumen
# ============================================================
if ($Fail -eq 0) {
    Write-Host ""
    Write-Host "OK: todas las pruebas de env.common.psm1 superadas."
    exit 0
}
Write-Host ""
Write-Host "FALLOS: $Fail verificación(es) fallida(s)."
exit 1
