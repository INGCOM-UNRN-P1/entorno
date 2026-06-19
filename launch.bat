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


:: Configurar el directorio HOME portable para no afectar el host
set "HOME=%PORTABLE_ROOT%home"
if not exist "%HOME%" mkdir "%HOME%"

:: Configurar entorno MSYS2
:: CLANG64 utiliza UCRT y compilador Clang nativo de Windows
set "MSYSTEM=CLANG64"
set "CHERE_INVOKING=1"

:: Verificar si existe el ejecutable
if not exist "%PORTABLE_ROOT%msys64\usr\bin\bash.exe" (
    echo [ERROR] No se encuentra MSYS2 en: %PORTABLE_ROOT%msys64
    echo Por favor, ejecuta 'powershell -File setup.ps1' para instalarlo primero.
    echo.
    pause
    exit /b 1
)

:: Iniciar el shell bash interactivo
"%PORTABLE_ROOT%msys64\usr\bin\bash.exe" --login -i
