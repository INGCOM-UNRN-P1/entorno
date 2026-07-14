#!/usr/bin/env bash
# build-launcher.sh - Descarga (si no existe localmente) y compila el lanzador del repositorio.
# Diseñado para ejecutarse dentro del terminal del entorno portable.

set -e

# Obtener la ruta raíz del entorno portable (padre de bin/)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PORTABLE_ROOT="$( dirname "$SCRIPT_DIR" )"

echo -e "\e[36m=== Compilación del Lanzador Portable ===\e[0m"
echo "Directorio raíz: $PORTABLE_ROOT"

# Asegurar la existencia del directorio launcher/
LAUNCHER_DIR="$PORTABLE_ROOT/launcher"
mkdir -p "$LAUNCHER_DIR"

# Descargar archivos si no existen localmente (caso de instalación standalone sin Git)
REPO_OWNER="INGCOM-UNRN-P1"
REPO_NAME="entorno"
BRANCH="main"
RAW_URL="https://raw.githubusercontent.com/$REPO_OWNER/$REPO_NAME/$BRANCH"

if [ ! -f "$LAUNCHER_DIR/launcher.c" ]; then
    echo -e "\e[33m-> launcher.c no encontrado. Descargando desde GitHub...\e[0m"
    curl -sS -o "$LAUNCHER_DIR/launcher.c" "$RAW_URL/launcher/launcher.c"
fi

if [ ! -f "$LAUNCHER_DIR/Makefile" ]; then
    echo -e "\e[33m-> Makefile no encontrado. Descargando desde GitHub...\e[0m"
    curl -sS -o "$LAUNCHER_DIR/Makefile" "$RAW_URL/launcher/Makefile"
fi

# Compilar los lanzadores
cd "$LAUNCHER_DIR"

# Determinar el compilador prioritario según UCRT64 (con fallback a gcc genérico)
CC="gcc"
if [ -x "/ucrt64/bin/gcc" ]; then
    CC="/ucrt64/bin/gcc"
    echo "Usando compilador prioritario UCRT64 GCC: $CC"
fi

echo -e "\e[32m-> Compilando ejecutables del lanzador...\e[0m"

# Si make o mingw32-make están disponibles, los usamos pasando el CC correspondiente
if command -v make >/dev/null 2>&1; then
    make CC="$CC"
elif command -v mingw32-make >/dev/null 2>&1; then
    mingw32-make CC="$CC"
else
    echo -e "\e[33m-> make o mingw32-make no está instalado. Compilando manualmente con $CC...\e[0m"
    CFLAGS="-O2 -Wall -mwindows"
    $CC $CFLAGS -o ../launch-vscode.exe launcher.c
    $CC $CFLAGS -o ../launch-wezterm.exe launcher.c
fi

# Eliminar ejecutables antiguos con guion bajo si existen para evitar confusiones
rm -f ../launch_vscode.exe ../launch_wezterm.exe

echo -e "\e[32m=== Compilación completada con éxito. Ejecutables generados en la raíz del entorno ===\e[0m"
