# setup.ps1 - Script de inicialización y actualización del entorno portable
# Configura MSYS2, el compilador Clang y la distribución de Python.

$ErrorActionPreference = "Stop"

# Directorio base del script
$portableRoot = $PSScriptRoot
$msysDir = Join-Path $portableRoot "msys64"
$tempDir = Join-Path $portableRoot "downloads"
$homeDir = Join-Path $portableRoot "home"

Write-Host "=== Entorno Portable de Desarrollo C + Python ===" -ForegroundColor Cyan
Write-Host "Directorio de instalación: $portableRoot`n"

# Asegurar que existan los directorios
if (-not (Test-Path $homeDir)) {
    New-Item -ItemType Directory -Path $homeDir | Out-Null
    Write-Host "Creado directorio HOME portable: $homeDir" -ForegroundColor Green
}

# 1. Comprobar si MSYS2 ya existe
$isInstalled = Test-Path (Join-Path $msysDir "usr\bin\bash.exe")

if (-not $isInstalled) {
    Write-Host "[Instalación] MSYS2 no detectado. Iniciando descarga..." -ForegroundColor Yellow
    
    # Crear carpeta temporal
    if (-not (Test-Path $tempDir)) {
        New-Item -ItemType Directory -Path $tempDir | Out-Null
    }

    # Intentar obtener la URL de descarga dinámica desde la API de GitHub
    $releaseUrl = "https://api.github.com/repos/msys2/msys2-installer/releases/latest"
    $downloadUrl = $null
    $fileName = $null

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Write-Host "Consultando API de GitHub por la última versión..."
        $release = Invoke-RestMethod -Uri $releaseUrl -UseBasicParsing -TimeoutSec 10
        $asset = $release.assets | Where-Object { $_.name -like "msys2-base-x86_64-*.sfx.exe" }
        if ($asset) {
            $downloadUrl = $asset.browser_download_url
            $fileName = $asset.name
            Write-Host "Última versión detectada: $fileName" -ForegroundColor Green
        }
    } catch {
        Write-Warning "Fallo al consultar la API de GitHub (posible límite de peticiones). Usando fallback fijo."
    }

    # Fallback si falla la consulta de API
    if (-not $downloadUrl) {
        $downloadUrl = "https://github.com/msys2/msys2-installer/releases/download/2025-02-21/msys2-base-x86_64-20250221.sfx.exe"
        $fileName = "msys2-base-x86_64-20250221.sfx.exe"
        Write-Host "Fallback URL: $downloadUrl" -ForegroundColor Yellow
    }

    $exePath = Join-Path $tempDir $fileName
    $shaPath = "$exePath.sha256"

    # Descarga del SFX.exe
    Write-Host "Descargando $fileName..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $downloadUrl -OutFile $exePath -UseBasicParsing

    # Verificación opcional de SHA256
    try {
        $shaUrl = "$downloadUrl.sha256"
        Write-Host "Descargando verificación SHA256..."
        Invoke-WebRequest -Uri $shaUrl -OutFile $shaPath -UseBasicParsing -ErrorAction SilentlyContinue
        
        $expectedHash = (Get-Content $shaPath -Raw).Split(" ")[0].Trim()
        $actualHash = (Get-FileHash -Path $exePath -Algorithm SHA256).Hash.ToLower()

        if ($actualHash -eq $expectedHash.ToLower()) {
            Write-Host "Firma SHA256 verificada con éxito." -ForegroundColor Green
        } else {
            throw "Integridad corrupta. El hash no coincide."
        }
    } catch {
        Write-Warning "No se pudo validar el Hash SHA256 de forma automatizada. Se asume correcto."
    }

    # Extracción
    Write-Host "Extrayendo entorno base MSYS2 en: $portableRoot" -ForegroundColor Cyan
    $process = Start-Process -FilePath $exePath -ArgumentList "-y", "-o`"$portableRoot`"" -Wait -NoNewWindow -PassThru
    if ($process.ExitCode -ne 0) {
        throw "Error durante la extracción de MSYS2 (código de salida: $($process.ExitCode))"
    }

    # Limpieza de archivos descargados
    Write-Host "Limpiando archivos temporales..."
    Remove-Item -Path $tempDir -Recurse -Force
    Write-Host "Instalación base completada con éxito.`n" -ForegroundColor Green
} else {
    Write-Host "[Actualización] MSYS2 ya instalado. Procediendo a actualizar paquetes..." -ForegroundColor Yellow
}

# 2. Inicializar el entorno e importar perfil de usuario
Write-Host "Inicializando entorno de consola..." -ForegroundColor Cyan
$bashPath = Join-Path $msysDir "usr\bin\bash.exe"
# Ejecutar bash vacío para generar archivos por defecto en /etc/skel y configurar directorios iniciales
& $bashPath --login -c "exit"

# 3. Actualizar la base de datos de paquetes y dependencias del sistema
Write-Host "Sincronizando base de datos de pacman y actualizando paquetes del sistema..." -ForegroundColor Cyan
& $bashPath --login -c "pacman -Syu --noconfirm"

# Si pacman notificó reinicio de runtime, volvemos a correr actualización para dependencias restantes
Write-Host "Consolidando actualizaciones del entorno..." -ForegroundColor Cyan
& $bashPath --login -c "pacman -Su --noconfirm"

# 4. Instalación del Toolchain Clang y Python en el entorno CLANG64
# Seleccionamos CLANG64 por utilizar UCRT como runtime moderno de Windows, y ser autocontenido y nativo.
$packages = @(
    "mingw-w64-clang-x86_64-clang",
    "mingw-w64-clang-x86_64-lld",
    "mingw-w64-clang-x86_64-llvm",
    "mingw-w64-clang-x86_64-make",
    "mingw-w64-clang-x86_64-cmake",
    "mingw-w64-clang-x86_64-ninja",
    "mingw-w64-clang-x86_64-gdb",
    "mingw-w64-clang-x86_64-python",
    "mingw-w64-clang-x86_64-python-pip",
    "mingw-w64-clang-x86_64-zlib",
    "mingw-w64-clang-x86_64-openssl",
    "mingw-w64-clang-x86_64-sqlite3",
    "mingw-w64-clang-x86_64-curl",
    "git"
)

$pkgString = $packages -join " "
Write-Host "Instalando compiladores, herramientas de compilación, Python y librerías comunes..." -ForegroundColor Cyan
& $bashPath --login -c "pacman -S --needed --noconfirm $pkgString"

# 5. Escribir configuración personalizada en el HOME portable
$bashrcPath = Join-Path $homeDir ".bashrc"
if (-not (Test-Path $bashrcPath)) {
    # Si por alguna razón no se copió del skeleton, forzar inicio bash para que se cree
    & $bashPath -env "HOME=$homeDir" --login -c "exit"
}

# Agregar alias útiles si no existen
if (Test-Path $bashrcPath) {
    $customAliases = @(
        "",
        "# === Portable Dev Environment Aliases ===",
        "alias python='python3'",
        "alias pip='pip3'",
        "alias make='mingw32-make'",
        "alias ll='ls -alF --color=auto'",
        "export PS1='\[\e[32m\]\u@portable \[\e[33m\]\w\[\e[0m\]\n$ '"
    )
    
    $content = Get-Content $bashrcPath -Raw
    foreach ($alias in $customAliases) {
        if (-not $content.Contains($alias)) {
            Add-Content -Path $bashrcPath -Value $alias
        }
    }
    Write-Host "Configuración personalizada agregada a $bashrcPath" -ForegroundColor Green
}

Write-Host "`n=== ENTORNO PORTABLE CONFIGURADO Y LISTO ===" -ForegroundColor Green
Write-Host "Ejecutá 'launch.bat' para iniciar la consola." -ForegroundColor Green
