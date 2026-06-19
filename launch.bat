@echo off
setlocal
:: Determinar el directorio raíz portable
set "PORTABLE_ROOT=%~dp0"

:: Validar si la ruta contiene espacios en blanco (rompe Make y herramientas tradicionales de C)
if not "%PORTABLE_ROOT%"=="%PORTABLE_ROOT: =%" (
    echo ==========================================================================
    echo [ADVERTENCIA] La ruta de instalacion contiene espacios en blanco:
    echo "%PORTABLE_ROOT%"
    echo Esto puede romper herramientas de compilacion de C (Make, CMake, etc.).
    echo Se recomienda mover el entorno a una ruta simple (Ej: C:\dev\entorno).
    echo ==========================================================================
    echo.
)

:: Configurar el directorio HOME portable (cargando configuración si existe)
set "HOME_DIR_NAME=home"
if exist "%PORTABLE_ROOT%.env" call "%PORTABLE_ROOT%.env"
set "HOME=%PORTABLE_ROOT%%HOME_DIR_NAME%"
if not exist "%HOME%" mkdir "%HOME%"

:: Configurar entorno MSYS2 (Clang64 enlazado contra UCRT)
set "MSYSTEM=CLANG64"
set "CHERE_INVOKING=1"
set "LANG=es_AR.UTF-8"

:: Agregar scripts internos, compilador y userland Unix al PATH de sesión
set "PATH=%PORTABLE_ROOT%bin;%PORTABLE_ROOT%msys64\clang64\bin;%PORTABLE_ROOT%msys64\usr\bin;%PATH%"

:: Configuración de WezTerm
set "WEZTERM_CONFIG_FILE=%PORTABLE_ROOT%wezterm.lua"

:: Asegurar que wezterm.lua no tenga BOM (evita error de codificación UTF-8 en WezTerm)
if exist "%WEZTERM_CONFIG_FILE%" powershell -NoProfile -Command "$p='%WEZTERM_CONFIG_FILE%'; if(Test-Path $p){$b=[System.IO.File]::ReadAllBytes($p); if($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF){$c=[System.IO.File]::ReadAllText($p); [System.IO.File]::WriteAllText($p,$c,(New-Object System.Text.UTF8Encoding($false)))}}" >nul 2>&1

:: Si no existe en la raíz pero WezTerm está en alguna subcarpeta, aplanarlo
if not exist "%PORTABLE_ROOT%wezterm\wezterm.exe" (
    if exist "%PORTABLE_ROOT%wezterm" (
        for /f "delims=" %%f in ('dir /b /s "%PORTABLE_ROOT%wezterm\wezterm.exe" 2^>nul') do (
            if exist "%%f" (
                echo [INFO] Corrigiendo estructura de carpetas de WezTerm...
                pushd "%%~dpf"
                move * "%PORTABLE_ROOT%wezterm\" >nul 2>&1
                popd
                rmdir /s /q "%%~dpf" >nul 2>&1
            )
        )
    )
)

:: Si existe WezTerm, lanzarlo. De lo contrario, caer de vuelta a Bash estándar en CMD.
if exist "%PORTABLE_ROOT%wezterm\wezterm.exe" (
    start "" "%PORTABLE_ROOT%wezterm\wezterm.exe"
) else (
    echo [INFO] WezTerm no detectado en %PORTABLE_ROOT%wezterm.
    echo Lanzando Bash en consola estandar...
    echo.
    if not exist "%PORTABLE_ROOT%msys64\usr\bin\bash.exe" (
        echo [ERROR] No se encuentra MSYS2 en: %PORTABLE_ROOT%msys64
        echo Por favor, ejecuta 'powershell -File setup.ps1' para instalarlo primero.
        echo.
        pause
        exit /b 1
    )
    "%PORTABLE_ROOT%msys64\usr\bin\bash.exe" --login -i
)
