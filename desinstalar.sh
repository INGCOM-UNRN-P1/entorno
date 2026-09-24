#!/usr/bin/env bash
# desinstalar.sh - Desinstalador del entorno de Programación 1 para macOS y Linux.
#
# Uso:
#   ~/p1/entorno/desinstalar.sh [opciones]
#   curl -fsSL https://raw.githubusercontent.com/INGCOM-UNRN-P1/entorno/main/desinstalar.sh | bash
#
# Qué hace:
#   - Quita el bloque '# >>> p1-entorno >>>' de ~/.bashrc, ~/.zshrc, ~/.bash_profile y ~/.profile.
#   - Elimina ~/p1/entorno (incluidas las herramientas locales uv y gh) y el atajo ~/p1/entrar.
#   - Conserva el espacio de trabajo ~/p1/dev (tus proyectos) salvo que pidas borrarlo.
#
# Opciones:
#   --borrar-dev   Borra también ~/p1/dev con todos tus proyectos (¡irreversible!).
#   -y, --si       No pide confirmación (conserva ~/p1/dev salvo --borrar-dev).
#   -h, --help     Muestra esta ayuda.
#
# Variables: P1_TTY (dispositivo para las respuestas, por defecto /dev/tty).

set -eu

main() {
    local CYAN GREEN YELLOW RED BOLD RESET
    CYAN='\033[36m'; GREEN='\033[32m'; YELLOW='\033[33m'; RED='\033[31m'
    BOLD='\033[1m'; RESET='\033[0m'

    local BORRAR_DEV=0 SIN_PREGUNTAS=0
    local TTY_DEV="${P1_TTY:-/dev/tty}"

    while [ $# -gt 0 ]; do
        case "$1" in
            --borrar-dev) BORRAR_DEV=1 ;;
            -y|--si|--yes) SIN_PREGUNTAS=1 ;;
            -h|--help)
                if [ -f "${BASH_SOURCE[0]:-}" ]; then
                    sed -n '2,/^$/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
                else
                    echo "Uso: desinstalar.sh [--borrar-dev] [-y|--si]"
                fi
                return 0 ;;
            *) printf "${RED}[ERROR]${RESET} Opción desconocida: %s (usá --help)\n" "$1" >&2; return 2 ;;
        esac
        shift
    done

    if [ -n "${P1_SEPARADO:-}" ]; then
        printf "${RED}[ERROR]${RESET} Estás dentro del espacio de trabajo separado (HOME=%s).\n" "$HOME" >&2
        echo "        Salí con 'exit' y ejecutá el desinstalador desde tu sesión habitual." >&2
        return 1
    fi

    local P1_RAIZ="$HOME/p1"
    local ENTORNO="$P1_RAIZ/entorno"
    local DEV="$P1_RAIZ/dev"
    local MARCA_INICIO="# >>> p1-entorno >>>"
    local MARCA_FIN="# <<< p1-entorno <<<"

    hay_tty() { { : < "$TTY_DEV"; } 2>/dev/null; }
    preguntar() { # preguntar <texto> <defecto s|n> → 0 si la respuesta es sí
        local r=""
        printf "%s " "$1"
        read -r r <&3 || r=""
        [ -z "$r" ] && r="$2"
        case "$r" in s|S|si|sí|Si|Sí|y|Y) return 0 ;; *) return 1 ;; esac
    }

    printf "${YELLOW}${BOLD}%s${RESET}\n" "======================================================================"
    printf "${YELLOW}${BOLD}%s${RESET}\n" "  DESINSTALADOR DEL ENTORNO — PROGRAMACIÓN 1 (macOS / Linux)"
    printf "${YELLOW}${BOLD}%s${RESET}\n" "======================================================================"

    if [ ! -d "$ENTORNO" ] && [ ! -e "$P1_RAIZ/entrar" ] && ! grep -qsxF "$MARCA_INICIO" \
        "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.bash_profile" "$HOME/.profile"; then
        echo "No se encontró ninguna instalación del entorno en $P1_RAIZ."
        return 0
    fi

    # Protección: solo se borra una carpeta que realmente sea el entorno
    if [ -d "$ENTORNO" ] && [ ! -f "$ENTORNO/.p1-instalacion" ] && [ ! -f "$ENTORNO/unix/p1-env.sh" ]; then
        printf "${RED}[ERROR]${RESET} '%s' no parece una instalación del entorno; no se toca.\n" "$ENTORNO" >&2
        return 1
    fi

    echo "Se eliminará:"
    echo "  - $ENTORNO (scripts, uv y gh locales)"
    echo "  - $P1_RAIZ/entrar y la integración en tus archivos de inicio de la terminal"
    if [ "$BORRAR_DEV" = "1" ]; then
        printf "  - ${RED}%s (TODOS tus proyectos)${RESET}\n" "$DEV"
    else
        echo "Se conserva: $DEV (tus proyectos)"
    fi
    echo ""

    if [ "$SIN_PREGUNTAS" != "1" ]; then
        if ! hay_tty; then
            printf "${RED}[ERROR]${RESET} No hay terminal para confirmar. Usá --si para desinstalar sin preguntas.\n" >&2
            return 1
        fi
        # Un único descriptor para todas las respuestas (la terminal o su simulación)
        exec 3< "$TTY_DEV"
        if ! preguntar "¿Continuar con la desinstalación? (s/N):" n; then
            echo "Desinstalación cancelada. No se modificó nada."
            return 0
        fi
        if [ "$BORRAR_DEV" != "1" ] && [ -d "$DEV" ]; then
            if preguntar "¿Borrar también $DEV con todos tus proyectos? Es irreversible (s/N):" n; then
                BORRAR_DEV=1
            fi
        fi
    fi

    # Salir de cualquier carpeta que se vaya a borrar
    cd "$HOME"

    local p
    for p in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.bash_profile" "$HOME/.profile"; do
        if [ -f "$p" ] && grep -qxF "$MARCA_INICIO" "$p"; then
            local tmp
            tmp="$(mktemp)"
            awk -v s="$MARCA_INICIO" -v e="$MARCA_FIN" \
                '$0 == s { skip = 1; next } skip { if ($0 == e) skip = 0; next } { print }' "$p" > "$tmp"
            cat "$tmp" > "$p"
            rm -f "$tmp"
            echo "  - Integración quitada de: $p"
        fi
    done

    rm -f "$P1_RAIZ/entrar"
    if [ -d "$ENTORNO" ]; then
        rm -rf "$ENTORNO"
        echo "  - Eliminado: $ENTORNO"
    fi
    rm -rf "$P1_RAIZ"/.instalando.* 2>/dev/null || true

    if [ "$BORRAR_DEV" = "1" ] && [ -d "$DEV" ]; then
        rm -rf "$DEV"
        echo "  - Eliminado: $DEV"
    elif [ -d "$DEV" ]; then
        printf "  ${CYAN}*${RESET} Conservado: %s\n" "$DEV"
    fi
    rmdir "$P1_RAIZ" 2>/dev/null || true

    echo ""
    printf "${GREEN}${BOLD}%s${RESET}\n" "DESINSTALACIÓN COMPLETADA"
    echo "Abrí una terminal nueva para que los cambios en tu sesión tengan efecto."
}

main "$@"
