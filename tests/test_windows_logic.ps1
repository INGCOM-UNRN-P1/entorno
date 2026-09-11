# test_windows_logic.ps1 - Pruebas de la logica interna de setup.ps1 ejecutables
# en cualquier plataforma con PowerShell 7 (CI incluido). Extrae las funciones por
# AST para probar el texto real que se distribuye, sin ejecutar la instalacion.
#
# Uso:  pwsh -NoProfile -File tests/test_windows_logic.ps1

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$SetupPath = Join-Path $RepoRoot "setup.ps1"
$Fail = 0

function Get-FunctionFromScript {
    param([string]$Path, [string]$Name)
    $errs = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$errs)
    if ($errs) { throw "Errores de parseo en $Path" }
    $fn = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $Name }, $true) |
        Select-Object -First 1
    if (-not $fn) { throw "Funcion '$Name' no encontrada en $Path" }
    return $fn.Extent.Text
}

function Assert-True {
    param([string]$Desc, [bool]$Condition)
    if ($Condition) { Write-Host "OK: $Desc" }
    else { Write-Host "FALLA: $Desc"; $script:Fail++ }
}

# ============================================================
# 1. Invoke-DownloadWithRetry: reintentos uniformes de descargas
# ============================================================
. ([scriptblock]::Create((Get-FunctionFromScript -Path $SetupPath -Name "Invoke-DownloadWithRetry")))

$work = Join-Path ([System.IO.Path]::GetTempPath()) ("dlretry-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $work | Out-Null

try {
    # Caso A: falla dos veces y al tercer intento descarga
    $script:calls = 0
    function Invoke-WebRequest { param([string]$Uri, [string]$OutFile, [switch]$UseBasicParsing, [int]$TimeoutSec)
        $script:calls++
        if ($script:calls -lt 3) { throw "red inestable simulada" }
        Set-Content -Path $OutFile -Value "contenido"
    }
    $target = Join-Path $work "a.bin"
    Invoke-DownloadWithRetry -Url "https://ejemplo/a" -OutFile $target -DelaySeconds 0
    Assert-True "descarga con 2 fallos previos termina OK tras 3 intentos" ((Test-Path $target) -and $script:calls -eq 3)

    # Caso B: falla siempre -> propaga el error agotando MaxAttempts
    $script:calls = 0
    function Invoke-WebRequest { param([string]$Uri, [string]$OutFile, [switch]$UseBasicParsing, [int]$TimeoutSec)
        $script:calls++
        throw "sin red simulada"
    }
    $propagated = $false
    try { Invoke-DownloadWithRetry -Url "https://ejemplo/b" -OutFile (Join-Path $work "b.bin") -MaxAttempts 4 -DelaySeconds 0 } catch { $propagated = $true }
    Assert-True "error propagado tras agotar los intentos configurados" ($propagated -and $script:calls -eq 4)

    # Caso C: exito al primer intento no reintenta
    $script:calls = 0
    function Invoke-WebRequest { param([string]$Uri, [string]$OutFile, [switch]$UseBasicParsing, [int]$TimeoutSec)
        $script:calls++
        Set-Content -Path $OutFile -Value "ok"
    }
    Invoke-DownloadWithRetry -Url "https://ejemplo/c" -OutFile (Join-Path $work "c.bin")
    Assert-True "exito inmediato consume un unico intento" ($script:calls -eq 1)
} finally {
    Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}

# ============================================================
# 2. Get-GitHubApiCached: cache de respuestas de la API de GitHub
# ============================================================
$envRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("apicache-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $envRoot | Out-Null
$descargasDir = Join-Path $envRoot "descargas"
. ([scriptblock]::Create((Get-FunctionFromScript -Path $SetupPath -Name "Get-GitHubApiCached")))

try {
    $script:apiCalls = 0
    function Invoke-RestMethod { param([string]$Uri, [switch]$UseBasicParsing, [int]$TimeoutSec)
        if ($env:API_DOWN -eq "1") { throw "(red caida simulada)" }
        $script:apiCalls++
        [pscustomobject]@{ url = $Uri; tag_name = "v-simulada"; assets = @([pscustomobject]@{ name = "x.zip"; browser_download_url = "https://ejemplo/x.zip" }) }
    }

    $r1 = Get-GitHubApiCached -Url "https://api.github.com/repos/demo/demo/releases/latest"
    Assert-True "primera consulta va a la API" ($script:apiCalls -eq 1)

    $null = Get-GitHubApiCached -Url "https://api.github.com/repos/demo/demo/releases/latest"
    Assert-True "segunda consulta se sirve desde cache sin red" ($script:apiCalls -eq 1)

    # Cache vencida + API caida -> sirve copia local
    $stamp = Get-ChildItem (Join-Path $descargasDir "api_cache") -Filter *.stamp | Select-Object -First 1
    Set-Content $stamp.FullName -Value ([datetimeoffset]::UtcNow.AddHours(-48).ToString("o"))
    $env:API_DOWN = "1"
    $r3 = Get-GitHubApiCached -Url "https://api.github.com/repos/demo/demo/releases/latest"
    Assert-True "con API caida sirve la cache aunque este vencida" ($null -ne $r3 -and $r3.tag_name -eq "v-simulada")

    # Sin cache + API caida -> propaga
    $propagated = $false
    try { Get-GitHubApiCached -Url "https://api.github.com/repos/otro/otro/releases/latest" } catch { $propagated = $true }
    Assert-True "sin cache disponible propaga el error original" $propagated

    # Round-trip JSON preserva estructuras anidadas
    $env:API_DOWN = "0"
    $assetUrl = ($r1.assets | Select-Object -First 1).browser_download_url
    Assert-True "el round-trip JSON conserva assets anidados" ($assetUrl -eq "https://ejemplo/x.zip")
} finally {
    $env:API_DOWN = $null
    Remove-Item -Recurse -Force $envRoot -ErrorAction SilentlyContinue
}

# ============================================================
# 3. Select-PacmanMirrorByLatency: espejo regional por latencia
# ============================================================
. ([scriptblock]::Create((Get-FunctionFromScript -Path $SetupPath -Name "Select-PacmanMirrorByLatency")))

$msysFake = Join-Path ([System.IO.Path]::GetTempPath()) ("mirror-" + [guid]::NewGuid().ToString("N"))
$pacmand = Join-Path $msysFake "etc\pacman.d"
New-Item -ItemType Directory -Force -Path $pacmand | Out-Null
foreach ($f in @("mirrorlist.msys","mirrorlist.ucrt64","mirrorlist.mingw64","mirrorlist.clang64")) {
    Set-Content (Join-Path $pacmand $f) -Value @(
        "##",
        "## Official mirrors",
        "##",
        "Server = https://repo.msys2.org/mingw/ucrt64/"
    )
}

try {
    # Modo normal: ufro.caido gana utexas; el servidor elegido queda primero con subruta correcta
    $script:down = @("https://mirror.ufro.cl/msys2")
    function Invoke-WebRequest { param([string]$Uri, [string]$Method, [switch]$UseBasicParsing, [int]$TimeoutSec)
        foreach ($d in $script:down) { if ($Uri.StartsWith($d)) { throw "timeout simulado" } }
        return $null
    }
    $chosen = Select-PacmanMirrorByLatency -MsysDir $msysFake
    $mlUcrt = Get-Content (Join-Path $pacmand "mirrorlist.ucrt64") -Raw
    Assert-True "elige el espejo mas rapido que responde" ($chosen -eq "https://mirrors.utexas.edu/msys2")
    Assert-True "configura la subruta mingw/ucrt64 en su mirrorlist" ($mlUcrt -match [regex]::Escape("Server = https://mirrors.utexas.edu/msys2/mingw/ucrt64/"))

    # Segunda corrida con ganador distinto: sin marcadores duplicados, anterior como respaldo
    $script:down = @()
    $chosen2 = Select-PacmanMirrorByLatency -MsysDir $msysFake
    $lines = Get-Content (Join-Path $pacmand "mirrorlist.ucrt64")
    $markers = @($lines | Where-Object { $_ -match "Espejo seleccionado automaticamente" }).Count
    Assert-True "corridas repetidas no duplican el marcador" ($markers -eq 1)
    Assert-True "la segunda corrida reemplaza al ganador" ($chosen2 -eq "https://mirror.ufro.cl/msys2")
    Assert-True "el espejo anterior queda como respaldo" ([bool]($lines | Where-Object { $_ -match "utexas" }))

    # Todos caidos: devuelve $null y no modifica archivos
    $before = Get-Content (Join-Path $pacmand "mirrorlist.msys") -Raw
    $script:down = @("https://mirror.ufro.cl/msys2", "https://repo.msys2.org", "https://mirrors.utexas.edu/msys2", "https://mirrors.ocf.berkeley.edu/msys2")
    $none = Select-PacmanMirrorByLatency -MsysDir $msysFake
    $after = Get-Content (Join-Path $pacmand "mirrorlist.msys") -Raw
    Assert-True "con todos los espejos caidos devuelve null" ($null -eq $none)
    Assert-True "con todos los espejos caidos no toca las mirrorlists" ($before -eq $after)
} finally {
    Remove-Item -Recurse -Force $msysFake -ErrorAction SilentlyContinue
}

# ============================================================
# 4. Get-Pinned: resolucion del manifiesto versions.json
# ============================================================
. ([scriptblock]::Create((Get-FunctionFromScript -Path $SetupPath -Name "Get-Pinned")))

$script:pinnedVersions = [pscustomobject]@{
    canal   = "2026-c1"
    vscode  = "  https://ejemplo/vscode.zip  "
    gh      = $null
}
Assert-True "pin de cadena se devuelve recortado" ((Get-Pinned 'vscode') -eq "https://ejemplo/vscode.zip")
Assert-True "pin en null devuelve null" ($null -eq (Get-Pinned 'gh'))
Assert-True "clave inexistente devuelve null" ($null -eq (Get-Pinned 'wezterm'))

$script:pinnedVersions = $null
Assert-True "sin manifiesto todo devuelve null" ($null -eq (Get-Pinned 'msys2'))

$script:pinnedVersions = $null

# ============================================================
# 5. Get-FileNameFromUrl: nombre de archivo desde URL
# ============================================================
. ([scriptblock]::Create((Get-FunctionFromScript -Path $SetupPath -Name "Get-FileNameFromUrl")))

Assert-True "toma el ultimo segmento con extension valida" `
    ((Get-FileNameFromUrl -Url "https://ejemplo/descargas/msys2-base.sfx.exe" -DefaultName "x") -eq "msys2-base.sfx.exe")
Assert-True "descarta query string" `
    ((Get-FileNameFromUrl -Url "https://ejemplo/code.zip?ts=123" -DefaultName "x") -eq "code.zip")
Assert-True "extension desconocida usa el default" `
    ((Get-FileNameFromUrl -Url "https://ejemplo/download" -DefaultName "fallback.zip") -eq "fallback.zip")
Assert-True "URL vacia usa el default" `
    ((Get-FileNameFromUrl -Url "" -DefaultName "vacio.tar.gz") -eq "vacio.tar.gz")

# ============================================================
# 6. Test-IsDirectHomePath: prevenir instalacion directa en HOME
# ============================================================
. ([scriptblock]::Create((Get-FunctionFromScript -Path $SetupPath -Name "Test-IsDirectHomePath")))

$prevHome = $HOME
$prevProfile = $env:USERPROFILE
$fakeHome = Join-Path ([System.IO.Path]::GetTempPath()) ("fakehome-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $fakeHome | Out-Null
try {
    $HOME = $fakeHome
    $env:USERPROFILE = $fakeHome

    Assert-True "detecta instalacion directa en HOME exacto" (Test-IsDirectHomePath -Path $fakeHome)
    Assert-True "detecta instalacion con separador final" (Test-IsDirectHomePath -Path ($fakeHome + [System.IO.Path]::DirectorySeparatorChar))
    Assert-True "detecta tilde (~)" (Test-IsDirectHomePath -Path "~")
    Assert-True "permite instalacion en subcarpeta de HOME" (-not (Test-IsDirectHomePath -Path (Join-Path $fakeHome "entorno")))
    Assert-True "permite instalacion en ruta externa" (-not (Test-IsDirectHomePath -Path ([System.IO.Path]::GetTempPath())))
    Assert-True "ruta vacia devuelve false" (-not (Test-IsDirectHomePath -Path ""))
} finally {
    $HOME = $prevHome
    $env:USERPROFILE = $prevProfile
    Remove-Item -Recurse -Force $fakeHome -ErrorAction SilentlyContinue
}

# ============================================================
# Resumen
# ============================================================
if ($Fail -eq 0) {
    Write-Host ""
    Write-Host "OK: todas las pruebas de logica de setup.ps1 superadas."
    exit 0
}
Write-Host ""
Write-Host "FALLOS: $Fail verificacion(es) fallida(s)."
exit 1
