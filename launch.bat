@echo off
setlocal
:: Determinar el directorio raíz portable
set "PORTABLE_ROOT=%~dp0"

:: Delegar la inicialización y el lanzamiento al script de PowerShell para evitar errores sintácticos de CMD y mantener el entorno unificado
powershell -NoProfile -ExecutionPolicy Bypass -File "%PORTABLE_ROOT%launch.ps1" %*
