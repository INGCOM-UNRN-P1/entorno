# test_install_offline.ps1 - Pruebas de install-offline.ps1 en modo no interactivo.
# Regresion: sin consola, la pausa final (ReadKey) bloqueaba el job e2e-windows
# hasta agotar el limite de 2h30. Cada ejecucion corre en un proceso hijo con
# tiempo limite, asi un bloqueo se detecta como falla en segundos.
#
# Uso:  pwsh -NoProfile -File tests/test_install_offline.ps1

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Script = Join-Path $RepoRoot "install-offline.ps1"
$Pwsh = (Get-Process -Id $PID).Path

$Fail = 0
function Assert-True {
    param([string]$Desc, [bool]$Condition)
    if ($Condition) { Write-Host "OK: $Desc" }
    else { Write-Host "FALLA: $Desc"; $script:Fail++ }
}

# Ejecuta install-offline.ps1 con la entrada redirigida y sin la variable CI,
# para ejercitar la deteccion de consola no interactiva. Devuelve el codigo de
# salida, o $null si no termino dentro del limite (bloqueado esperando al usuario).
function Invoke-InstallOffline {
    param([string[]]$Argumentos, [int]$LimiteSeg = 60)
    $psi = [System.Diagnostics.ProcessStartInfo]::new($Pwsh)
    foreach ($a in @("-NoProfile", "-NonInteractive", "-File", $Script) + $Argumentos) { $psi.ArgumentList.Add($a) }
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    [void]$psi.Environment.Remove("CI")
    $p = [System.Diagnostics.Process]::Start($psi)
    $p.StandardInput.Close()
    $salida = $p.StandardOutput.ReadToEndAsync()
    $errores = $p.StandardError.ReadToEndAsync()
    if (-not $p.WaitForExit($LimiteSeg * 1000)) {
        $p.Kill($true)
        Write-Host "  (proceso bloqueado; se cancelo tras $LimiteSeg s)"
        return $null
    }
    $script:UltimaSalida = $salida.Result + $errores.Result
    return $p.ExitCode
}

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("offline-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path (Join-Path $tmp "paquete") | Out-Null
try {
    Set-Content -Path (Join-Path $tmp "paquete/launch.bat") -Value "@echo off"
    $zip = Join-Path $tmp "portable-env-offline.zip"
    Compress-Archive -Path (Join-Path $tmp "paquete/*") -DestinationPath $zip

    # 1. Destino nuevo, sin -Yes y sin consola: debe terminar sin esperar una tecla
    $destino = Join-Path $tmp "destino"
    $rc = Invoke-InstallOffline @("-RutaZip", $zip, "-Destino", $destino)
    Assert-True "sin consola termina sin quedar bloqueado en la pausa final" ($null -ne $rc)
    Assert-True "sin consola la instalacion termina con exito" ($rc -eq 0)
    Assert-True "el paquete se extrae en el destino" (Test-Path (Join-Path $destino "launch.bat"))

    # 2. Destino existente, sin -Yes y sin consola: falla rapido en vez de preguntar
    $rc = Invoke-InstallOffline @("-RutaZip", $zip, "-Destino", $destino)
    Assert-True "destino existente sin consola no queda bloqueado en la confirmacion" ($null -ne $rc)
    Assert-True "destino existente sin consola ni -Yes termina con error" ($rc -eq 1)
    Assert-True "el error sugiere usar -Yes" ($script:UltimaSalida -match "-Yes")

    # 3. Destino existente con -Yes (modo del job e2e-windows): extrae encima
    Remove-Item (Join-Path $destino "launch.bat") -ErrorAction SilentlyContinue
    $rc = Invoke-InstallOffline @("-RutaZip", $zip, "-Destino", $destino, "-Yes")
    Assert-True "-Yes extrae encima de un destino existente" (($rc -eq 0) -and (Test-Path (Join-Path $destino "launch.bat")))

    # 4. Paquete inexistente: error inmediato
    $rc = Invoke-InstallOffline @("-RutaZip", (Join-Path $tmp "no-existe.zip"), "-Destino", $destino, "-Yes")
    Assert-True "un paquete inexistente termina con error" (($null -ne $rc) -and ($rc -ne 0))
} finally {
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}

if ($Fail -eq 0) {
    Write-Host ""
    Write-Host "OK: todas las pruebas de install-offline.ps1 superadas."
    exit 0
}
Write-Host ""
Write-Host "FALLOS: $Fail verificacion(es) fallida(s)."
exit 1
