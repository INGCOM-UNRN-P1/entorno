# package-env.ps1 - Empaqueta el entorno portable inicializado en un archivo ZIP para distribución offline.
# Parámetros:
#   -Compact: poda documentación y locales de MSYS2 en la copia a empaquetar para reducir tamaño.

param(
    [switch]$Compact
)

$ErrorActionPreference = "Stop"

$portableRoot = $PSScriptRoot
$msysDir = Join-Path $portableRoot "msys64"
$vscodeDir = Join-Path $portableRoot "vscode"
$outputZip = Join-Path $portableRoot "portable-env-offline.zip"

Write-Host "=== Empaquetador de Entorno Portable (Offline) ===" -ForegroundColor Cyan
Write-Host "Directorio raíz: $portableRoot"

# 1. Validar que el entorno esté inicializado y completo
$isMsysReady = Test-Path (Join-Path $msysDir "usr\bin\bash.exe")
$isVscodeReady = Test-Path (Join-Path $vscodeDir "Code.exe")

if (-not $isMsysReady -or -not $isVscodeReady) {
    Write-Error "El entorno no está inicializado completamente. Ejecutá primero 'powershell -File setup.ps1' para aprovisionar las herramientas."
    return
}

# 2. Limpieza previa del entorno para reducir el tamaño del paquete
Write-Host "`nLimpiando archivos innecesarios para optimizar el tamaño..." -ForegroundColor Cyan
$bashPath = Join-Path $msysDir "usr\bin\bash.exe"

# Limpiar caché de pacman (.pkg.tar.zst descargados)
Write-Host "* Limpiando caché de paquetes de pacman..."
& $bashPath --login -c "pacman -Scc --noconfirm"

# 3. Preparación del directorio temporal de empaquetado
$tempPackBase = Join-Path $portableRoot "temp_package"
$tempPackDir = Join-Path $tempPackBase "entorno"
if (Test-Path $tempPackBase) {
    Remove-Item -Path $tempPackBase -Recurse -Force
}
New-Item -ItemType Directory -Path $tempPackDir -Force | Out-Null

# 4. Copiar los archivos excluyendo metadatos de Git, temporales y copias de seguridad
Write-Host "`nCopiando estructura del entorno..." -ForegroundColor Cyan
$excludeList = @(
    ".git",
    "downloads",
    "descargas",
    "temp_package",
    "portable-env-offline.zip",
    "vscode_data_backup",
    "gh_temp",
    ".gitignore",
    ".gitattributes"
)

Get-ChildItem -Path $portableRoot | Where-Object { ($_.Name -notin $excludeList) -and ($_.Name -notlike "*.log") } | ForEach-Object {
    $dest = Join-Path $tempPackDir $_.Name
    Write-Host "  -> Copiando: $($_.Name)..."
    Copy-Item -Path $_.FullName -Destination $dest -Recurse -Force
}

# 4.5 Limpiar datos personales de la copia a empaquetar
Write-Host "`nLimpiando datos personales e historial del paquete..." -ForegroundColor Cyan
# El HOME se entrega vacío: cualquier resto de usuario (historial, caches, tokens,
# banners personalizados, .ssh, etc.) queda fuera del paquete por completo.
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
$packHome = Join-Path $tempPackDir $homeDirName
if (-not (Test-Path $packHome)) {
    New-Item -ItemType Directory -Path $packHome -Force | Out-Null
} else {
    Get-ChildItem -Path $packHome -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}

$packVscodeUser = Join-Path $tempPackDir "vscode\data\user-data\User"
if (Test-Path $packVscodeUser) {
    Remove-Item (Join-Path $packVscodeUser "History") -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $packVscodeUser "workspaceStorage") -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $packVscodeUser "globalStorage") -Recurse -Force -ErrorAction SilentlyContinue
}

# 4.7 Poda opcional de contenido no esencial (modo -Compact)
if ($Compact) {
    Write-Host "`nModo Compacto: podando documentación y locales no esenciales..." -ForegroundColor Cyan
    $pruneDirs = @(
        "msys64\usr\share\doc",
        "msys64\usr\share\man",
        "msys64\usr\share\locale",
        "msys64\ucrt64\share\doc",
        "msys64\ucrt64\share\man"
    )
    foreach ($rel in $pruneDirs) {
        $prunePath = Join-Path $tempPackDir $rel
        if (Test-Path $prunePath) {
            Remove-Item -Path $prunePath -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "  -> Podado: $rel"
        }
    }
}

# 5. Comprimir el directorio temporal en un único archivo ZIP
if (Test-Path $outputZip) {
    Write-Host "`nEliminando archivo ZIP existente..." -ForegroundColor Yellow
    Remove-Item -Path $outputZip -Force
}

Write-Host "`nComprimiendo todo el entorno en $outputZip..." -ForegroundColor Cyan
Write-Host "[NOTA] Esto puede tardar varios minutos debido a la cantidad de binarios en MSYS2 y VS Code." -ForegroundColor Yellow

# Usar el cmdlet nativo Compress-Archive empaquetando la carpeta raíz "entorno"
Compress-Archive -Path $tempPackDir -DestinationPath $outputZip -Force

# 6. Limpieza del directorio temporal
Write-Host "`nLimpiando directorio temporal de empaquetado..." -ForegroundColor Cyan
Remove-Item -Path $tempPackBase -Recurse -Force

Write-Host "`n=== PROCESO DE EMPAQUETADO COMPLETADO ===" -ForegroundColor Green
Write-Host "Archivo generado listo para distribución offline:" -ForegroundColor Green
Write-Host "-> $outputZip" -ForegroundColor Green
Write-Host "`nPara instalarlo offline en otra máquina:" -ForegroundColor Cyan
Write-Host "1. Copiá el archivo ZIP en la máquina de destino (o pendrive)." -ForegroundColor Cyan
Write-Host "2. Extraé el contenido del archivo ZIP en cualquier carpeta." -ForegroundColor Cyan
Write-Host "3. Iniciá a programar directamente ejecutando 'launch.bat' o 'launch-vscode.bat'." -ForegroundColor Cyan
