@echo off
setlocal
:: Determinar el directorio raiz portable
set "PORTABLE_ROOT=%~dp0"

:: Delegar la inicializacion y el lanzamiento al script de PowerShell para evitar errores sintacticos de CMD y mantener el entorno unificado
powershell -NoProfile -ExecutionPolicy Bypass -File "%PORTABLE_ROOT%launch-vscode.ps1" %*
