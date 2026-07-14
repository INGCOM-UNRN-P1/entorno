#!/usr/bin/env bash
# update-env.sh - Actualiza los scripts y componentes del entorno portable.
# Diseñado para ejecutarse dentro del terminal de la consola portable.

set -e

# Asegurar que se ejecuta dentro del entorno de la consola portable
if [ -z "$PORTABLE_ROOT" ]; then
    echo -e "\e[31m[ERROR] No estás dentro de la consola del entorno portable.\e[0m"
    exit 1
fi

echo -e "\e[36m======================================================================\e[0m"
echo -e "\e[36m          Actualización del Entorno Portable de Desarrollo\e[0m"
echo -e "\e[36m======================================================================\e[0m"

# 1. Actualizar los scripts locales
echo -e "\n\e[33m[1/2] Descargando y actualizando scripts del repositorio...\e[0m"

REPO_OWNER="INGCOM-UNRN-P1"
REPO_NAME="entorno"
BRANCH="main"
ZIP_URL="https://github.com/$REPO_OWNER/$REPO_NAME/archive/refs/heads/$BRANCH.zip"

TEMP_DIR=$(mktemp -d -t portable-update-XXXXXX)
ZIP_PATH="$TEMP_DIR/repo.zip"

# Descargar el zip del snapshot
curl -sSL -o "$ZIP_PATH" "$ZIP_URL"

# Descomprimir
unzip -q -o "$ZIP_PATH" -d "$TEMP_DIR"

EXTRACTED_DIR="$TEMP_DIR/$REPO_NAME-$BRANCH"

# Copiar scripts de la raíz (evitando pisar carpetas de configuración personal)
echo "Instalando nuevas versiones de los scripts locales..."
cp -rf "$EXTRACTED_DIR"/{setup.ps1,launch.bat,launch.ps1,launch-vscode.bat,launch-vscode.ps1,clean-shared-host.ps1,customize-terminal.ps1,customize-terminal.bat,package-env.ps1,README.md,plan.md,GEMINI.md} "$PORTABLE_ROOT/"

# Copiar scripts de bin/
mkdir -p "$PORTABLE_ROOT/bin"
cp -rf "$EXTRACTED_DIR"/bin/* "$PORTABLE_ROOT/bin/"

# Asegurar permisos de ejecución en bin
chmod +x "$PORTABLE_ROOT"/bin/*

# Limpiar temporales
rm -rf "$TEMP_DIR"

echo -e "\e[32m[ÉXITO] Scripts del entorno actualizados a la última versión.\e[0m"

# 2. Actualizar componentes nativos
echo -e "\n\e[33m[2/2] ¿Deseás ejecutar la actualización completa de herramientas nativas?\e[0m"
echo "(Esto verificará e instalará actualizaciones de MSYS2, VS Code y GitHub CLI)."
echo -n "¿Continuar? (s/n): "
read -r choice

if [[ "$choice" =~ ^[sS]$ ]]; then
    echo -e "\n\e[36mEjecutando setup.ps1 en segundo plano...\e[0m"
    # Convertir ruta unix a formato Windows para powershell.exe
    WIN_SETUP_PATH=$(cygpath -w "$PORTABLE_ROOT/setup.ps1")
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$WIN_SETUP_PATH" -SkipUpdate
else
    echo -e "\n\e[33mActualización de herramientas omitida. El entorno ya cuenta con los scripts más recientes.\e[0m"
fi
