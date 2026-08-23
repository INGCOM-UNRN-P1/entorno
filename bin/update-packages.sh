#!/usr/bin/env bash
# update-packages.sh - Actualiza los paquetes del entorno portable de forma unificada.
# Ejecuta la sincronización/actualización de pacman y garantiza que todos los paquetes
# obligatorios (fuente única: packages-baseline.txt) estén instalados, usando la caché
# local portátil como almacenamiento de descargas.
#
# Diseñado para ejecutarse dentro del terminal portable de Windows (MSYS2/UCRT64).

set -eu

RED='\033[31m'; GREEN='\033[32m'; YELLOW='\033[33m'; CYAN='\033[36m'; RESET='\033[0m'

if [ -z "${PORTABLE_ROOT:-}" ]; then
    echo -e "${RED}[ERROR] No estás dentro de la consola del entorno portable.${RESET}"
    echo "Por favor, ejecutá 'launch.bat' antes de correr este script."
    exit 1
fi

PKG_FILE="${PORTABLE_ROOT}/packages-baseline.txt"
CACHE_DIR="${PORTABLE_ROOT}/descargas/pacman_cache"

if [ ! -f "$PKG_FILE" ]; then
    echo -e "${RED}[ERROR] No se encontró packages-baseline.txt en ${PORTABLE_ROOT}.${RESET}"
    exit 1
fi

mapfile -t packages < <(sed 's/#.*$//' "$PKG_FILE" | tr -d ' \t\r' | grep -v '^$')
pkg_string="${packages[*]}"

mkdir -p "$CACHE_DIR"

echo -e "${CYAN}======================================================================${RESET}"
echo -e "${CYAN}     Actualización Unificada de Paquetes del Entorno Portable${RESET}"
echo -e "${CYAN}======================================================================${RESET}"
echo "Paquetes obligatorios: ${#packages[@]} (definidos en packages-baseline.txt)"
echo ""

echo -e "${CYAN}-> Sincronizando base de datos de pacman...${RESET}"
pacman -Sy --cachedir "$CACHE_DIR" --noconfirm

echo ""
echo -e "${CYAN}-> Actualizando el sistema base...${RESET}"
pacman -Su --cachedir "$CACHE_DIR" --noconfirm || {
    echo -e "${YELLOW}[AVISO] La actualización del sistema reportó errores; se continúa con el baseline.${RESET}"
}

echo ""
echo -e "${CYAN}-> Instalando/verificando paquetes obligatorios...${RESET}"
pacman -S --needed --cachedir "$CACHE_DIR" --noconfirm $pkg_string

echo ""
echo -e "${GREEN}[ÉXITO] Entorno actualizado: sistema al día y baseline completo.${RESET}"
echo "Sugerencia: ejecutá 'doctor' para validar la salud del entorno."
