@echo off
setlocal
:: Determinar el directorio raíz portable
set "PORTABLE_ROOT=%~dp0"

:: Validar si la ruta contiene espacios en blanco
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

:: Inyectar variables para MSYS2
set "MSYSTEM=CLANG64"
set "CHERE_INVOKING=1"

:: Agregar compilador y userland Unix al PATH temporal de la sesión
set "PATH=%PORTABLE_ROOT%msys64\clang64\bin;%PORTABLE_ROOT%msys64\usr\bin;%PATH%"

:: Verificar que exista VS Code
if not exist "%PORTABLE_ROOT%vscode\Code.exe" (
    echo [ERROR] No se encuentra VS Code en: %PORTABLE_ROOT%vscode
    echo Por favor, ejecuta 'powershell -File setup.ps1' para instalar el entorno completo.
    echo.
    pause
    exit /b 1
)

:: Lanzar VS Code heredando las variables de entorno
start "" "%PORTABLE_ROOT%vscode\Code.exe" %*
