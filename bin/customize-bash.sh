#!/usr/bin/env bash
# customize-bash.sh - Script interactivo para personalizar el entorno Bash y el banner de bienvenida.
# Diseñado para correr dentro del entorno de la consola portable.

set -e

# Asegurar que se ejecuta dentro del entorno de la consola portable
if [ -z "$PORTABLE_ROOT" ]; then
    echo -e "\e[31m[ERROR] No estás dentro de la consola del entorno portable.\e[0m"
    echo "Por favor, ejecutá la consola primero (launch.bat o launch-vscode.bat)."
    exit 1
fi

BASHRC_PATH="$HOME/.bashrc"
if [ ! -f "$BASHRC_PATH" ]; then
    echo -e "\e[31m[ERROR] No se encontró el archivo .bashrc en $HOME.\e[0m"
    exit 1
fi

echo -e "\e[36m======================================================================\e[0m"
echo -e "\e[36m          Asistente de Personalización del Entorno Bash\e[0m"
echo -e "\e[36m======================================================================\e[0m"
echo "Este asistente te permite configurar un banner o mensaje de bienvenida"
echo "que se mostrará cada vez que inicies una nueva terminal Bash."
echo ""

echo -n "¿Querés configurar o modificar el mensaje de bienvenida de la consola? (s/n): "
read -r config_banner

START_MARKER="# === START WELCOME BANNER ==="
END_MARKER="# === END WELCOME BANNER ==="

if [[ "$config_banner" =~ ^[sS]$ ]]; then
    # 1. Selección de Color
    echo -e "\n\e[36mSeleccioná el color del banner:\e[0m"
    echo "1) Celeste (Cyan)"
    echo "2) Verde (Green)"
    echo "3) Amarillo (Yellow)"
    echo "4) Violeta (Purple)"
    echo "5) Blanco (White)"
    echo -n "Seleccioná una opción de color (1-5): "
    read -r color_choice

    case "$color_choice" in
        2) COLOR_CODE="32" ;;
        3) COLOR_CODE="33" ;;
        4) COLOR_CODE="35" ;; # Violeta
        5) COLOR_CODE="37" ;;
        *) COLOR_CODE="36" ;; # Celeste (predeterminado)
    esac

    # 2. Selección de Sugerencias / Plantillas
    echo -e "\n\e[36mElegí el tipo de banner de bienvenida:\e[0m"
    echo "1) Saludo minimalista (Recomendado)"
    echo "2) Frase motivacional (Programación/Tecnología)"
    echo "3) Resumen de herramientas útiles y comandos rápidos"
    echo "4) Escribir tu propio mensaje línea por línea"
    echo -n "Seleccioná una opción (1-4): "
    read -r banner_choice

    BANNER_LINES=()
    ESTUDIANTE="${USER:-${USERNAME:-Estudiante}}"

    case "$banner_choice" in
        1)
            BANNER_LINES+=(
                "  ¡Hola, $ESTUDIANTE!"
                "  Listo para desarrollar tus proyectos de Programación 1."
            )
            ;;
        2)
            # Elegir una frase aleatoria
            FRASES=(
                "\"El único modo de hacer un gran trabajo es amar lo que haces.\" - Steve Jobs"
                "\"La simplicidad es la clave de la brillantez.\" - Edsger Dijkstra"
                "\"Los programas deben ser escritos para que la gente los lea, y sólo incidentalmente para que las máquinas los ejecuten.\" - Harold Abelson"
                "\"No te preocupes si no funciona bien. Si todo funcionara, no tendrías trabajo.\" - Ley de Mosher de la Ingeniería de Software"
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
                "  * python            - Consola de Python 3"
                "  * pip               - Administrador de librerías Python"
                "  * make              - Compilador de archivos C"
                "  * install-lib.sh    - Instalar librerías de C desde GitHub"
                "  * build-launcher.sh - Compilar los accesos directos (.exe)"
                "  * ll                - Ver archivos con color y detalles"
            )
            ;;
        4)
            echo -e "\nEscribí tu mensaje de bienvenida línea por línea."
            echo "Cuando termines, presioná Enter en una línea vacía para finalizar:"
            while true; do
                echo -n "> "
                read -r line
                if [ -z "$line" ]; then
                    break
                fi
                BANNER_LINES+=("$line")
            done
            ;;
        *)
            BANNER_LINES+=( "  ¡Hola, $ESTUDIANTE! Bienvenido al terminal portable." )
            ;;
    esac

    # Generar el bloque del banner formateado con los colores ansi correctos
    BANNER_BLOCK="$START_MARKER
echo -e \"\\e[${COLOR_CODE}m\"
echo \"======================================================================\""
    for line in "${BANNER_LINES[@]}"; do
        # Escapar comillas dobles para evitar errores en bashrc
        escaped_line=$(echo "$line" | sed 's/"/\\"/g')
        BANNER_BLOCK="$BANNER_BLOCK
echo \"$escaped_line\""
    done
    BANNER_BLOCK="$BANNER_BLOCK
echo \"======================================================================\"
echo -e \"\\e[0m\"
$END_MARKER"

else
    # Si elige desactivar, simplemente insertamos el bloque vacío
    echo -e "\nDesactivando mensaje de bienvenida personalizado..."
    BANNER_BLOCK="$START_MARKER
$END_MARKER"
fi

# Escribir en .bashrc reemplazando el bloque existente o agregándolo al final
TEMP_BASHRC=$(mktemp)

if grep -q "$START_MARKER" "$BASHRC_PATH"; then
    # Usamos awk para reemplazar todo lo contenido entre los marcadores de banner de bienvenida
    awk -v r="$BANNER_BLOCK" '
    BEGIN {print_flag=1}
    /# === START WELCOME BANNER ===/ {print r; print_flag=0; next}
    /# === END WELCOME BANNER ===/ {print_flag=1; next}
    {if (print_flag) print}
    ' "$BASHRC_PATH" > "$TEMP_BASHRC"
else
    cp "$BASHRC_PATH" "$TEMP_BASHRC"
    echo -e "\n\n$BANNER_BLOCK" >> "$TEMP_BASHRC"
fi

mv "$TEMP_BASHRC" "$BASHRC_PATH"

echo -e "\n\e[32m=== PERSONALIZACIÓN COMPLETADA ===\e[0m"
echo "El mensaje de bienvenida se mostrará la próxima vez que abras una terminal."
