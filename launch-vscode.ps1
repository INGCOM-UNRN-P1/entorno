# launch-vscode.ps1 - Lanzador de VS Code con entorno portable

$ErrorActionPreference = "Stop"

$portableRoot = $PSScriptRoot

# Lógica compartida con launch.ps1 (advertencia de ruta, .env, sesión)
Import-Module (Join-Path $portableRoot "env.common.psm1") -Force

# Advertencia temprana ante espacios, caracteres no ASCII o carpetas sincronizadas
$infoRuta = Test-ConflictivePath -Path $portableRoot
if ($infoRuta.IsConflictive) {
    Show-PathWarning -Path $portableRoot
}

# Cargar configuración de directorio HOME e inyectar la sesión portable común
$homeDirName = Get-PortableHomeName -PortableRoot $portableRoot
$null = Set-PortableSession -PortableRoot $portableRoot -HomeDirName $homeDirName

$vscodeDir = Join-Path $portableRoot "vscode"
$codeExe = Join-Path $vscodeDir "Code.exe"

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
