#!/usr/bin/env bash
# desinstalar-personal.sh - Desinstalador de scripts de gestión del entorno personal
# Compatible con macOS y Linux.
#
# Uso: desinstalar-personal.sh [--all]
#   --all  Elimina también 'gh' y 'uv' de ~/.local/bin si fueron instalados allí.

set -eu

CYAN='\033[36m'; GREEN='\033[32m'; RED='\033[31m'; YELLOW='\033[33m'; RESET='\033[0m'
BOLD='\033[1m'

TARGET_BIN="${TARGET_BIN_DIR:-$HOME/.local/bin}"
REMOVE_ALL=0

for arg in "$@"; do
    case "$arg" in
        --all|--purge) REMOVE_ALL=1 ;;
        -h|--help)
            echo "Uso: desinstalar-personal.sh [--all]"
            echo "  --all  Elimina también 'gh' y 'uv' de ${TARGET_BIN}"
            exit 0
            ;;
    esac
done

echo -e "${YELLOW}${BOLD}======================================================================${RESET}"
echo -e "${YELLOW}${BOLD}  DESINSTALADOR DE SCRIPTS DE GESTIÓN — PROGRAMACIÓN 1                ${RESET}"
echo -e "${YELLOW}${BOLD}======================================================================${RESET}"
echo -e "Directorio de destino : ${TARGET_BIN}"
echo ""

# 1. Eliminar scripts de gestión
echo -e "${CYAN}-> Eliminando scripts de gestión de cátedra...${RESET}"
SCRIPTS_GESTION=(ayuda clonar nuevo-proyecto verificar entregar doctor desinstalar-personal.sh)

for s in "${SCRIPTS_GESTION[@]}"; do
    if [ -f "${TARGET_BIN}/$s" ]; then
        rm -f "${TARGET_BIN}/$s"
        echo "  - Eliminado: ${TARGET_BIN}/$s"
    fi
done

# 2. Opcional: remover gh y uv si se especificó --all
if [ "$REMOVE_ALL" -eq 1 ]; then
    echo ""
    echo -e "${CYAN}-> Eliminando herramientas locales instaladas en el perfil (--all)...${RESET}"
    if [ -f "${TARGET_BIN}/gh" ]; then
        rm -f "${TARGET_BIN}/gh"
        echo "  - Eliminado: ${TARGET_BIN}/gh"
    fi
    if [ -f "${TARGET_BIN}/uv" ]; then
        rm -f "${TARGET_BIN}/uv" "${TARGET_BIN}/uvx" 2>/dev/null || true
        echo "  - Eliminado: ${TARGET_BIN}/uv"
    fi
fi

# 3. Limpiar bloques de PATH en archivos de configuración de shell
echo ""
echo -e "${CYAN}-> Limpiando configuración de variables en perfiles de shell...${RESET}"
BLOCK_START="# >>> P1-GESTION-PERSONAL >>>"
BLOCK_END="# <<< P1-GESTION-PERSONAL <<<"

limpiar_perfil() {
    local perfil="$1"
    if [ -f "$perfil" ] && grep -qF "$BLOCK_START" "$perfil"; then
        sed -i.bak "/$BLOCK_START/,/$BLOCK_END/d" "$perfil" 2>/dev/null || sed -i "" "/$BLOCK_START/,/$BLOCK_END/d" "$perfil"
        rm -f "${perfil}.bak"
        echo "  - Limpiado: $perfil"
    fi
}

limpiar_perfil "$HOME/.bashrc"
limpiar_perfil "$HOME/.zshrc"
limpiar_perfil "$HOME/.bash_profile"
limpiar_perfil "$HOME/.profile"

echo ""
echo -e "${GREEN}${BOLD}======================================================================${RESET}"
echo -e "${GREEN}${BOLD}  DESINSTALACIÓN COMPLETADA EXITOSAMENTE                              ${RESET}"
echo -e "${GREEN}${BOLD}======================================================================${RESET}"
echo "Los scripts de gestión han sido removidos de tu perfil de usuario."
echo "Para actualizar tu sesión actual de terminal, ejecutá:"
echo -e "${CYAN}  hash -r${RESET}  (en Bash) o  ${CYAN}rehash${RESET}  (en Zsh)"
echo ""
