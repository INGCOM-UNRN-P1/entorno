#!/usr/bin/env bash
# bootstrap.sh - Verifica las dependencias del entorno portable en Linux.
#
# SOLO DIAGNÓSTICO: este script nunca instala nada, nunca escribe fuera de la
# terminal y no requiere permisos de administrador. Se limita a informar qué
# herramientas faltan y a sugerir los comandos para que cada usuario las
# instale por su propia cuenta, fuera del entorno.

set -u

CYAN='\033[36m'; GREEN='\033[32m'; YELLOW='\033[33m'; RED='\033[31m'; RESET='\033[0m'

if [ "${1:-}" = "--install" ] || [ "${1:-}" = "--yes" ]; then
    echo -e "${YELLOW}[AVISO] El modo de instalación automática fue eliminado.${RESET}"
    echo "        Por diseño, el entorno nunca modifica el sistema ni usa sudo."
    echo "        Este script ahora solo diagnostica y sugiere comandos."
    exit 2
fi

# Herramientas obligatorias para usar el entorno (candidatos de binario separados por espacio)
CORE_TOOLS=(
    "git:git"
    "gcc:gcc cc"
    "g++:g++ c++"
    "make:make"
    "cmake:cmake"
    "ninja:ninja"
    "python3:python3 python"
    "pip:pip3 pip"
    "curl:curl"
)
# Herramientas recomendadas (el entorno funciona sin ellas)
OPT_TOOLS=(
    "gdb:gdb"
    "cppcheck:cppcheck"
    "doxygen:doxygen"
    "gh:gh"
    "uv:uv"
)

tool_present() {
    local c
    for c in $1; do
        if command -v "$c" >/dev/null 2>&1; then return 0; fi
    done
    return 1
}

detect_manager() {
    if command -v apt-get >/dev/null 2>&1; then echo "apt"
    elif command -v dnf >/dev/null 2>&1; then echo "dnf"
    elif command -v yum >/dev/null 2>&1; then echo "yum"
    elif command -v pacman >/dev/null 2>&1; then echo "pacman"
    elif command -v zypper >/dev/null 2>&1; then echo "zypper"
    elif command -v apk >/dev/null 2>&1; then echo "apk"
    else echo ""
    fi
}

pkg_for() {
    local mgr="$1" tool="$2"
    case "$mgr:$tool" in
        apt:ninja)     echo "ninja-build" ;;
        apt:pip)       echo "python3-pip" ;;
        dnf|yum:g++)   echo "gcc-c++" ;;
        dnf|yum:ninja) echo "ninja-build" ;;
        dnf|yum:pip)   echo "python3-pip" ;;
        pacman:pip)    echo "python-pip" ;;
        zypper:g++)    echo "gcc-c++" ;;
        zypper:pip)    echo "python3-pip" ;;
        apk:pip)       echo "py3-pip" ;;
        *)             echo "$tool" ;;
    esac
}

install_hint() {
    local mgr="$1"
    shift
    case "$mgr" in
        apt)    echo "sudo apt install $*" ;;
        dnf)    echo "sudo dnf install $*" ;;
        yum)    echo "sudo yum install $*" ;;
        pacman) echo "sudo pacman -S $*" ;;
        zypper) echo "sudo zypper install $*" ;;
        apk)    echo "sudo apk add $*" ;;
        *)      echo "(instalá estas herramientas con el gestor de tu distribución)" ;;
    esac
}

echo -e "${CYAN}======================================================================${RESET}"
echo -e "${CYAN}     Diagnóstico de Dependencias del Entorno Portable (Linux)${RESET}"
echo -e "${CYAN}======================================================================${RESET}"
echo -e "Modo solo lectura: no se modifica nada del sistema ni se piden permisos."
echo ""

MANAGER="$(detect_manager)"
missing_core=()
missing_pkgs=()

printf "%-12s %s\n" "HERRAMIENTA" "ESTADO"
printf "%-12s %s\n" "-----------" "------"
for entry in "${CORE_TOOLS[@]}"; do
    name="${entry%%:*}"
    if tool_present "${entry#*:}"; then
        printf "%-12s ${GREEN}%s${RESET}\n" "$name" "[OK] disponible"
    else
        printf "%-12s ${RED}%s${RESET}\n" "$name" "[FALTA]"
        missing_core+=("$name")
        if [ -n "$MANAGER" ]; then
            p="$(pkg_for "$MANAGER" "$name")"
            case " ${missing_pkgs[*]:-} " in
                *" $p "*) : ;;
                *) missing_pkgs+=("$p") ;;
            esac
        fi
    fi
done

missing_opt=()
for entry in "${OPT_TOOLS[@]}"; do
    name="${entry%%:*}"
    if tool_present "${entry#*:}"; then
        printf "%-12s ${GREEN}%s${RESET}\n" "$name" "[OK] disponible (recomendada)"
    else
        printf "%-12s ${YELLOW}%s${RESET}\n" "$name" "[falta] (recomendada)"
        missing_opt+=("$name")
    fi
done

echo ""
if [ "${#missing_core[@]}" -eq 0 ]; then
    echo -e "${GREEN}[ÉXITO] Todas las herramientas obligatorias están disponibles.${RESET}"
else
    if [ -n "$MANAGER" ] && [ "${#missing_pkgs[@]}" -gt 0 ]; then
        echo -e "${YELLOW}Para instalar lo que falta (por tu cuenta, con tus credenciales):${RESET}"
        echo "    $(install_hint "$MANAGER" "${missing_pkgs[@]}")"
    else
        echo -e "${YELLOW}Faltan herramientas obligatorias: ${missing_core[*]}${RESET}"
        echo "    Instalalas con el gestor de paquetes de tu distribución o pedilas al administrador del laboratorio."
    fi
fi

if [ "${#missing_opt[@]}" -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}Recomendadas opcionales no encontradas:${RESET}"
    for t in "${missing_opt[@]}"; do
        case "$t" in
            gh)     echo "  * gh: https://github.com/cli/cli#installation" ;;
            uv)     echo "  * uv (sin admin, a nivel de usuario): curl -LsSf https://astral.sh/uv/install.sh | sh" ;;
            *)      p="$(pkg_for "${MANAGER:-x}" "$t")"; echo "  * $t${p:+ (paquete: $p)}" ;;
        esac
    done
fi

echo ""
echo -e "${CYAN}[INFO] Recordatorio: ejecutá los instaladores ANTES de activar el entorno o${RESET}"
echo -e "${CYAN}       con la sesión activada si querés que queden dentro del HOME portable.${RESET}"

[ "${#missing_core[@]}" -eq 0 ] && exit 0 || exit 1
