#!/usr/bin/env bash
# download-baseline.sh - Descarga el baseline de paquetes de pacman a la caché local portable
# Diseñado para ejecutarse dentro del entorno MSYS2 (UCRT64)

set -e

# Asegurar que PORTABLE_ROOT esté definido, de lo contrario inferir desde la ubicación del script
if [ -z "$PORTABLE_ROOT" ]; then
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    PORTABLE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

CACHE_DIR="${PORTABLE_ROOT}/descargas/pacman_cache"
mkdir -p "$CACHE_DIR"

echo "========================================================"
echo " Descarga de Baseline de Paquetes MSYS2 (UCRT64) "
echo "========================================================"
echo "Directorio de caché: $CACHE_DIR"
echo "Sincronizando base de datos de paquetes..."
pacman -Sy

echo -e "\nDescargando paquetes del baseline y sus dependencias..."
packages=(
    "mingw-w64-ucrt-x86_64-toolchain"
    "mingw-w64-ucrt-x86_64-cmake"
    "mingw-w64-ucrt-x86_64-ninja"
    "mingw-w64-ucrt-x86_64-python"
    "mingw-w64-ucrt-x86_64-python-pip"
    "mingw-w64-ucrt-x86_64-uv"
    "mingw-w64-ucrt-x86_64-cppcheck"
    "mingw-w64-ucrt-x86_64-zlib"
    "mingw-w64-ucrt-x86_64-openssl"
    "mingw-w64-ucrt-x86_64-sqlite3"
    "mingw-w64-ucrt-x86_64-curl"
    "mingw-w64-ucrt-x86_64-doxygen"
    "mingw-w64-ucrt-x86_64-clang-tools-extra"
    "git"
)

pkg_string="${packages[*]}"

# Descargar paquetes a la caché local sin instalarlos (-Sw)
pacman -Sw --cachedir "$CACHE_DIR" --noconfirm --needed $pkg_string

echo -e "\n========================================================"
echo " Descarga completada con éxito "
echo " Los paquetes se guardaron en: $CACHE_DIR"
echo "========================================================"
