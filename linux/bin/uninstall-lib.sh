#!/usr/bin/env bash
# uninstall-lib.sh - Desinstala una librería instalada previamente con install-lib.sh
# Funciona en el entorno portable de Windows (MSYS2/UCRT64) y en la variante Linux.
#
# Uso:
#   uninstall-lib.sh              # lista las librerías registradas
#   uninstall-lib.sh <nombre>     # elimina los archivos registrados de esa librería
#
# Las librerías que se instalaron vía CMake o 'make install' sin manifiesto detallado
# solo quedan anotadas: el script avisará que no puede eliminarlas automáticamente.

set -u

RED='\033[31m'; GREEN='\033[32m'; YELLOW='\033[33m'; CYAN='\033[36m'; RESET='\033[0m'

# Prefijo portable: Linux usa PORTABLE_PREFIX; Windows (MSYS2) usa MSYSTEM_PREFIX (/ucrt64)
PREFIX_DIR="${PORTABLE_PREFIX:-${MSYSTEM_PREFIX:-}}"
if [ -z "$PREFIX_DIR" ]; then
    echo -e "${RED}[ERROR] No estás dentro del entorno portátil.${RESET}"
    echo "Activá primero la sesión (source linux/activate.sh) o usá el terminal de launch.bat."
    exit 1
fi

MANIFEST_DIR="$PREFIX_DIR/portable-libs"

if [ ! -d "$MANIFEST_DIR" ] || [ -z "$(ls -A "$MANIFEST_DIR" 2>/dev/null)" ]; then
    echo -e "${YELLOW}[INFO] No hay librerías registradas en ${MANIFEST_DIR}.${RESET}"
    exit 0
fi

if [ -z "${1:-}" ]; then
    echo -e "${CYAN}Librerías registradas en ${PREFIX_DIR}:${RESET}"
    for m in "$MANIFEST_DIR"/*.files; do
        count=$(grep -cv -e '^#' -e '^$' "$m" || true)
        echo "  * $(basename "$m" .files)  (${count} archivos)"
    done
    echo ""
    echo "Ejecutá: uninstall-lib.sh <nombre> para desinstalar."
    exit 0
fi

TARGET_MANIFEST=""
for m in "$MANIFEST_DIR"/*.files; do
    name=$(basename "$m" .files)
    if [ "$name" = "$1" ] || [ "$name" = "$(printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '_')" ]; then
        TARGET_MANIFEST="$m"
        break
    fi
done

if [ -z "$TARGET_MANIFEST" ]; then
    echo -e "${RED}[ERROR] No se encontró el manifiesto '$1'. Ejecutá 'uninstall-lib.sh' para listar.${RESET}"
    exit 1
fi

removed=0
while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
        ''|\#*) continue ;;
    esac
    target="$PREFIX_DIR/$line"
    if [ -e "$target" ] || [ -L "$target" ]; then
        rm -rf "$target"
        removed=$((removed + 1))
        # Podar directorios padre que hayan quedado vacíos (sin salir del prefijo)
        parent="$(dirname "$target")"
        while [ "$parent" != "$PREFIX_DIR" ] && [ "$parent" != "/" ]; do
            if [ -d "$parent" ] && [ -z "$(ls -A "$parent" 2>/dev/null)" ]; then
                rmdir "$parent"
                parent="$(dirname "$parent")"
            else
                break
            fi
        done
    fi
done < "$TARGET_MANIFEST"

grep -q '^#' "$TARGET_MANIFEST" 2>/dev/null && \
    echo -e "${YELLOW}[AVISO] Esta librería tiene notas de instalación parcial (CMake/make install):${RESET}" && \
    grep '^#' "$TARGET_MANIFEST" | sed 's/^/    /'

rm -f "$TARGET_MANIFEST"
echo -e "${GREEN}[ÉXITO] '$(basename "$TARGET_MANIFEST" .files)' desinstalada ($removed archivos eliminados).${RESET}"
