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
# Fuente única de paquetes: packages-baseline.txt en la raíz del entorno
PKG_FILE="${PORTABLE_ROOT}/packages-baseline.txt"
if [ ! -f "$PKG_FILE" ]; then
    echo -e "\e[31m[ERROR] No se encontró packages-baseline.txt en ${PORTABLE_ROOT}.\e[0m"
    exit 1
fi
mapfile -t packages < <(sed 's/#.*$//' "$PKG_FILE" | tr -d ' \t\r' | grep -v '^$')

pkg_string="${packages[*]}"

# Descargar paquetes a la caché local sin instalarlos (-Sw)
pacman -Sw --cachedir "$CACHE_DIR" --noconfirm --needed $pkg_string

echo -e "\n========================================================"
echo " Descarga completada con éxito "
echo " Los paquetes se guardaron en: $CACHE_DIR"
echo "========================================================"
