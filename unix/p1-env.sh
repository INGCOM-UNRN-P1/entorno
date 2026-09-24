# shellcheck shell=sh
# p1-env.sh - Variables del entorno de Programación 1 para macOS y Linux.
#
# Se carga con '.' (compatible con bash y zsh) desde:
#   - el bloque '# >>> p1-entorno >>>' de ~/.bashrc / ~/.zshrc (modo integrado), o
#   - unix/entrar, al abrir la sesión aislada (modo separado).
# Requiere que P1_ENTORNO apunte a la raíz de la instalación (~/p1/entorno).

if [ -n "${P1_ENTORNO:-}" ] && [ -d "$P1_ENTORNO/unix/bin" ]; then
    : "${P1_DEV:=${P1_ENTORNO%/*}/dev}"
    export P1_ENTORNO P1_DEV

    # Comandos de cátedra y herramientas locales (uv, gh) sin duplicar en shells anidados
    case ":$PATH:" in
        *":$P1_ENTORNO/unix/bin:"*) : ;;
        *) PATH="$P1_ENTORNO/unix/bin:$P1_ENTORNO/local/bin:$PATH" ;;
    esac
    export PATH
fi
