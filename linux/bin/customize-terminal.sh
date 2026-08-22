#!/usr/bin/env bash
# customize-terminal.sh - Personalización de la terminal para el entorno portable (Linux).
# Permite configurar el banner de bienvenida y el prompt (PS1) del entorno Bash.
# Los cambios se escriben en $HOME/.bashrc entre marcas, sin tocar el host.

set -u

CYAN='\033[36m'; GREEN='\033[32m'; YELLOW='\033[33m'; RED='\033[31m'; RESET='\033[0m'

START_BANNER="# === START WELCOME BANNER ==="
END_BANNER="# === END WELCOME BANNER ==="
START_PROMPT="# === START PROMPT ==="
END_PROMPT="# === END PROMPT ==="

# Pregunta con tolerancia a EOF (Ctrl+D): devuelve cadena vacía en lugar de abortar.
# El prompt se escribe en stderr para poder capturar el valor limpio con $().
ask() {
    local reply=""
    printf "%b" "${CYAN}$1${RESET}" >&2
    read -r reply || reply=""
    printf '%s' "$reply"
}

if [ -z "${PORTABLE_ROOT:-}" ]; then
    printf "%b" "${RED}[ERROR]${RESET} No estás dentro del entorno portátil. Activá primero la sesión:\n"
    echo "       source linux/activate.sh"
    exit 1
fi

BASHRC="$HOME/.bashrc"
if [ ! -f "$BASHRC" ]; then
    printf "%b" "${RED}[ERROR]${RESET} No se encontró el archivo .bashrc en \$HOME (${HOME}).\n"
    echo "Desactivá y volvé a activar el entorno: deactivate && source linux/activate.sh"
    exit 1
fi

# Reemplaza el bloque entre dos marcas, o agrega BLOCK_CONTENT al final si no existen.
replace_or_append_block() {
    local rc="$1" start="$2" end="$3" tmp
    tmp="$(mktemp)"
    export BLOCK_CONTENT
    if grep -qF "$start" "$rc"; then
        awk -v s="$start" -v e="$end" '
            BEGIN { skip = 0 }
            index($0, s) == 1 { print ENVIRON["BLOCK_CONTENT"]; skip = 1; next }
            index($0, e) == 1 { skip = 0; next }
            { if (!skip) print }
        ' "$rc" > "$tmp"
    else
        { cat "$rc"; printf '\n%s\n' "$BLOCK_CONTENT"; } > "$tmp"
    fi
    mv "$tmp" "$rc"
    unset BLOCK_CONTENT
}

echo -e "${CYAN}======================================================================${RESET}"
echo -e "${CYAN}          Asistente de Personalización de Terminal (Linux)${RESET}"
echo -e "${CYAN}======================================================================${RESET}"
echo "Este asistente configura el banner de bienvenida y el prompt de Bash."
echo ""

# ---------------------------------------------------------------
# Parte 1: Banner de bienvenida
# ---------------------------------------------------------------
CONFIGURE_BANNER=1
answer="$(ask "¿Querés configurar o modificar el mensaje de bienvenida? (S/n): ")"
if [[ "$answer" =~ ^[nN]$ ]]; then
    CONFIGURE_BANNER=0
fi

if [ "$CONFIGURE_BANNER" -eq 1 ]; then
    echo ""
    echo -e "${CYAN}Seleccioná el color del banner:${RESET}"
    echo "1) Celeste (Cyan)"
    echo "2) Verde (Green)"
    echo "3) Amarillo (Yellow)"
    echo "4) Violeta (Purple)"
    echo "5) Blanco (White)"
    color_choice="$(ask "Seleccioná una opción de color (1-5): ")"
    case "$color_choice" in
        2) COLOR_CODE="32" ;;
        3) COLOR_CODE="33" ;;
        4) COLOR_CODE="35" ;;
        5) COLOR_CODE="37" ;;
        *) COLOR_CODE="36" ;;
    esac

    ESTUDIANTE="${USER:-${USERNAME:-Estudiante}}"
    echo ""
    echo -e "${CYAN}Elegí el tipo de banner de bienvenida:${RESET}"
    echo "1) Saludo minimalista (Recomendado)"
    echo "2) Frase motivacional (Programación/Tecnología)"
    echo "3) Resumen de herramientas útiles y comandos rápidos"
    echo "4) Escribir tu propio mensaje línea por línea"
    banner_choice="$(ask "Seleccioná una opción (1-4): ")"

    BANNER_LINES=()
    case "$banner_choice" in
        2)
            FRASES=(
                "\"El único modo de hacer un gran trabajo es amar lo que haces.\" - Steve Jobs"
                "\"La simplicidad es la clave de la brillantez.\" - Edsger Dijkstra"
                "\"Los programas deben ser escritos para que la gente los lea, y sólo incidentalmente para que las máquinas los ejecuten.\" - Harold Abelson"
                "\"Primero, resuelve el problema. Después, escribe el código.\" - John Johnson"
                "\"Controlar la complejidad es la esencia de la programación.\" - Brian Kernighan"
                "\"La mejor forma de predecir el futuro es inventarlo.\" - Alan Kay"
                "\"Hablar es barato. Muéstrame el código.\" - Linus Torvalds"
                "\"El código es como el humor. Cuando tienes que explicarlo, es malo.\" - Cory House"
            )
            RANDOM_INDEX=$(( RANDOM % ${#FRASES[@]} ))
            BANNER_LINES+=(
                "  Frase del día para $ESTUDIANTE:"
                "  ${FRASES[$RANDOM_INDEX]}"
            )
            ;;
        3)
            BANNER_LINES+=(
                "  Herramientas disponibles en este terminal:"
                "  * gcc / make / cmake / ninja - Compilación de proyectos C"
                "  * python3 / pip              - Consola y librerías de Python 3"
                "  * install-lib.sh             - Instalar librerías de C desde GitHub"
                "  * configure-git.sh           - Configurar Git y GitHub CLI paso a paso"
                "  * ll                         - Ver archivos con color y detalles"
            )
            ;;
        4)
            echo ""
            echo "Escribí tu mensaje de bienvenida línea por línea."
            echo "Cuando termines, presioná Enter en una línea vacía para finalizar:"
            while :; do
                line="$(ask "> ")"
                [ -z "$line" ] && break
                BANNER_LINES+=("$line")
            done
            ;;
        *)
            BANNER_LINES+=(
                "  ¡Hola, $ESTUDIANTE!"
                "  Listo para desarrollar tus proyectos de Programación 1."
            )
            ;;
    esac

    BLOCK_CONTENT="$START_BANNER
echo -e \"\\e[${COLOR_CODE}m\"
echo \"======================================================================\""
    for line in "${BANNER_LINES[@]}"; do
        escaped_line="${line//\"/\\\"}"
        BLOCK_CONTENT="$BLOCK_CONTENT
echo \"$escaped_line\""
    done
    BLOCK_CONTENT="$BLOCK_CONTENT
echo \"======================================================================\"
echo -e \"\\e[0m\"
$END_BANNER"

    echo ""
    echo "Escribiendo banner en $BASHRC ..."
    replace_or_append_block "$BASHRC" "$START_BANNER" "$END_BANNER"
else
    BLOCK_CONTENT="$START_BANNER
$END_BANNER"
    replace_or_append_block "$BASHRC" "$START_BANNER" "$END_BANNER"
    echo -e "${YELLOW}Banner de bienvenida desactivado.${RESET}"
fi

# ---------------------------------------------------------------
# Parte 2: Prompt (PS1)
# ---------------------------------------------------------------
answer="$(ask "¿Querés cambiar el estilo del prompt? (S/n): ")"
if [[ "$answer" =~ ^[nN]$ ]]; then
    echo -e "${YELLOW}Prompt actual conservado.${RESET}"
else
    echo ""
    echo -e "${CYAN}Elegí un estilo de prompt:${RESET}"
    echo "1) Estándar del entorno (usuario verde + ruta amarilla, recomendado)"
    echo "2) Minimalista ('>' celeste)"
    prompt_choice="$(ask "Seleccioná una opción (1-2): ")"
    case "$prompt_choice" in
        2) PS1_LINE='\[\e[36m\]> \[\e[0m\] ' ;;
        *) PS1_LINE='\[\e[32m\]\u@portable \[\e[33m\]\w\[\e[0m\]\n\$ ' ;;
    esac

    BLOCK_CONTENT="$START_PROMPT
export PS1='$PS1_LINE'
$END_PROMPT"

    echo ""
    echo "Escribiendo prompt en $BASHRC ..."
    replace_or_append_block "$BASHRC" "$START_PROMPT" "$END_PROMPT"
fi

touch "$HOME/.bash_customized"

echo ""
echo -e "${GREEN}=== PERSONALIZACIÓN COMPLETADA ===${RESET}"
echo "El banner y el prompt se aplicarán al abrir una nueva terminal."
echo "Para probarlos ahora mismo ejecutá: source ~/.bashrc"
