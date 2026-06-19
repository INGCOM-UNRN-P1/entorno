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

:: Configurar el directorio HOME portable para no afectar el host
set "HOME=%PORTABLE_ROOT%home"
if not exist "%HOME%" mkdir "%HOME%"

:: Configurar entorno MSYS2 (Clang64 enlazado contra UCRT)
set "MSYSTEM=CLANG64"
set "CHERE_INVOKING=1"

:: Agregar compilador y userland Unix al PATH de sesión
set "PATH=%PORTABLE_ROOT%msys64\clang64\bin;%PORTABLE_ROOT%msys64\usr\bin;%PATH%"

:: Configuración de WezTerm
set "WEZTERM_CONFIG_FILE=%PORTABLE_ROOT%wezterm.lua"

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
