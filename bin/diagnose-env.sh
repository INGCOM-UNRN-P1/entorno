#!/usr/bin/env bash
# diagnose-env.sh - Diagnostica el estado del entorno portable, herramientas instaladas y scripts bin/.
# Debe ejecutarse dentro del terminal portable (launch.bat).

# Asegurar codificación UTF-8 para soporte de acentos y caracteres especiales
export LANG="es_AR.UTF-8"
export LC_ALL="es_AR.UTF-8"

if [ -z "$MSYSTEM_PREFIX" ]; then
    echo -e "\e[31m[ERROR] No estás dentro de la consola del entorno portable.\e[0m"
    echo "Por favor, ejecutá 'launch.bat' o 'launch-vscode.bat' antes de correr este script."
    exit 1
fi

LOG_FILE="diagnose.log"
{
    echo "======================================================================"
    echo "INFORME DE DIAGNÓSTICO DEL ENTORNO PORTABLE"
    echo "======================================================================"
    echo "Fecha/Hora           : $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Sistema Operativo    : $OS / MSYSTEM: $MSYSTEM"
    echo "HOME de sesión       : $HOME"
    echo "PATH configurado     : $PATH"
    echo "======================================================================"
    echo ""

    echo "=== Versiones de Herramientas Clave ==="
    for cmd in clang clang++ mingw32-make cmake ninja gdb python python3 pip pip3 uv cppcheck doxygen git gh; do
        if command -v "$cmd" &> /dev/null; then
            echo -e "$cmd: \e[32m$(which "$cmd")\e[0m"
            # Mostrar la versión del comando
            case "$cmd" in
                python|python3) "$cmd" --version 2>&1 ;;
                pip|pip3) "$cmd" --version 2>&1 | cut -d' ' -f1-3 ;;
                uv) "$cmd" --version 2>&1 ;;
                clang|clang++) "$cmd" --version 2>&1 | head -n 1 ;;
                mingw32-make) "$cmd" --version 2>&1 | head -n 1 ;;
                cmake) "$cmd" --version 2>&1 | head -n 1 ;;
                ninja) echo "versión $("$cmd" --version 2>&1)" ;;
                gdb) "$cmd" --version 2>&1 | head -n 1 ;;
                cppcheck) "$cmd" --version 2>&1 ;;
                doxygen) "$cmd" --version 2>&1 ;;
                git) "$cmd" --version 2>&1 ;;
                gh) "$cmd" --version 2>&1 | head -n 1 ;;
            esac
        else
            echo -e "$cmd: \e[31mNO DETECTADO\e[0m"
        fi
        echo "--------------------------------------------------"
    done
    echo ""

    echo "=== Contenido de la carpeta bin/ ==="
    # Localizar la carpeta bin
    if command -v configure-git.sh &> /dev/null; then
        BIN_DIR=$(dirname "$(which configure-git.sh)")
        echo "Carpeta bin encontrada en: $BIN_DIR"
        ls -la "$BIN_DIR"
    else
        echo "ERROR: No se pudo localizar la carpeta bin/ en el PATH."
    fi
    echo ""

    echo "=== Listado de Paquetes Instalados de Pacman (pacman -Q) ==="
    pacman -Q
    echo ""
} 2>&1 | tee "$LOG_FILE"

echo -e "\n\e[32m[DIAGNÓSTICO COMPLETADO] El informe detallado se guardó en '$LOG_FILE'.\e[0m"
