@echo off
setlocal
:: Cambiar al directorio del script
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0customize-terminal.ps1"
pause
