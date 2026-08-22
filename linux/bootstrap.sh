#!/usr/bin/env bash
# bootstrap.sh - Verifica las dependencias del entorno portable en Linux y,
# opcionalmente, instala las faltantes con el gestor de paquetes de la distribución.
#
# Uso:
#   linux/bootstrap.sh             # sólo diagnóstico (no modifica el sistema)
#   linux/bootstrap.sh --install   # ofrece instalar lo que falte (usa sudo)
#   linux/bootstrap.sh --install --yes  # instala sin pedir confirmación

set -u

DO_INSTALL=0
ASSUME_YES=0
for arg in "$@"; do
    case "$arg" in
        --install) DO_INSTALL=1 ;;
        --yes) ASSUME_YES=1 ;;
        *) echo "Parámetro desconocido: $arg (usá --install y/o --yes)" >&2; exit 2 ;;
    esac
done

CYAN='\033[36m'; GREEN='\033[32m'; YELLOW='\033[33m'; RED='\033[31m'; RESET='\033[0m'

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
        apt:gcc)      echo "gcc" ;;
        apt:g++)      echo "g++" ;;
        apt:ninja)    echo "ninja-build" ;;
        apt:pip)      echo "python3-pip" ;;
        dnf:g++)      echo "gcc-c++" ;;
        dnf:ninja)    echo "ninja-build" ;;
        dnf:pip)      echo "python3-pip" ;;
        yum:g++)      echo "gcc-c++" ;;
        yum:ninja)    echo "ninja-build" ;;
        yum:pip)      echo "python3-pip" ;;
        pacman:gcc|pacman:make) echo "base-devel" ;;
        pacman:pip)   echo "python-pip" ;;
        zypper:g++)   echo "gcc-c++" ;;
        zypper:pip)   echo "python3-pip" ;;
        apk:gcc|apk:make) echo "build-base" ;;
        apk:pip)      echo "py3-pip" ;;
        *)            echo "$tool" ;;
    esac
}

echo -e "${CYAN}======================================================================${RESET}"
echo -e "${CYAN}     Bootstrap del Entorno Portable de Desarrollo (Linux)${RESET}"
echo -e "${CYAN}======================================================================${RESET}"

MANAGER="$(detect_manager)"
if [ -n "$MANAGER" ]; then
    echo -e "Gestor de paquetes detectado: ${GREEN}$MANAGER${RESET}"
else
    echo -e "${YELLOW}No se detectó un gestor de paquetes conocido (apt/dnf/yum/pacman/zypper/apk).${RESET}"
fi
echo ""

missing_core=()
missing_opt=()
printf "%-12s %s\n" "HERRAMIENTA" "ESTADO"
printf "%-12s %s\n" "-----------" "------"
for entry in "${CORE_TOOLS[@]}"; do
    name="${entry%%:*}"
    if tool_present "${entry#*:}"; then
        printf "%-12s ${GREEN}%s${RESET}\n" "$name" "[OK] disponible"
    else
        printf "%-12s ${RED}%s${RESET}\n" "$name" "[FALTA]"
        missing_core+=("$name")
    fi
done
for entry in "${OPT_TOOLS[@]}"; do
    name="${entry%%:*}"
    if tool_present "${entry#*:}"; then
        printf "%-12s ${GREEN}%s${RESET}\n" "$name" "[OK] disponible (recomendada)"
    else
        printf "%-12s ${YELLOW}%s${RESET}\n" "$name" "[falta] (recomendada)"
        missing_opt+=("$name")
    fi
done

if [ "${#missing_core[@]}" -eq 0 ]; then
    echo ""
    echo -e "${GREEN}[ÉXITO] Todas las herramientas obligatorias están disponibles.${RESET}"
    if [ "${#missing_opt[@]}" -gt 0 ]; then
        echo -e "${YELLOW}[INFO] Recomendadas no encontradas: ${missing_opt[*]}${RESET}"
    fi
fi

if [ "${#missing_core[@]}" -eq 0 ] || [ "$DO_INSTALL" -eq 0 ] || [ -z "$MANAGER" ]; then
    if [ "${#missing_core[@]}" -gt 0 ] && [ "$DO_INSTALL" -eq 0 ]; then
        echo ""
        echo -e "${YELLOW}[AVISO] Faltan herramientas obligatorias. Ejecutá con --install para instalarlas:${RESET}"
        echo "        linux/bootstrap.sh --install"
    fi
    if [ "${#missing_opt[@]}" -gt 0 ]; then
        for t in "${missing_opt[@]}"; do
            [ "$t" = "uv" ] && { echo "        uv (instalador oficial): curl -LsSf https://astral.sh/uv/install.sh | sh"; continue; }
            [ "$t" = "gh" ] && [ -z "$MANAGER" ] && { echo "        gh: https://github.com/cli/cli#installation"; continue; }
        done
    fi
    [ "${#missing_core[@]}" -eq 0 ] && exit 0 || exit 1
fi

# --- Modo instalación ---
install_pkgs=()
for t in "${missing_core[@]}" "${missing_opt[@]}"; do
    if [ "$t" = "uv" ]; then continue; fi  # uv se instala por su instalador oficial
    p="$(pkg_for "$MANAGER" "$t")"
    case " ${install_pkgs[*]} " in
        *" $p "*) : ;;
        *) install_pkgs+=("$p") ;;
    esac
done

if [ "${#install_pkgs[@]}" -eq 0 ]; then
    echo -e "${YELLOW}[INFO] No hay paquetes instalables automáticamente.${RESET}"
    echo "       uv (instalador oficial): curl -LsSf https://astral.sh/uv/install.sh | sh"
    exit 0
fi

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then SUDO="sudo"
    elif command -v doas >/dev/null 2>&1; then SUDO="doas"
    else
        echo -e "${RED}[ERROR] Se requieren privilegios de administrador y no se encontró sudo/doas.${RESET}"
        exit 1
    fi
fi

echo ""
echo "Paquetes a instalar ($MANAGER): ${install_pkgs[*]}"
if [ "$ASSUME_YES" -eq 0 ]; then
    printf "%s" "¿Continuar con la instalación? (s/n): "
    read -r answer || answer="n"
    [[ "$answer" =~ ^[sS]$ ]] || { echo "Instalación cancelada."; exit 1; }
fi

case "$MANAGER" in
    apt)
        $SUDO apt-get update
        $SUDO apt-get install -y "${install_pkgs[@]}"
        ;;
    dnf|yum)
        $SUDO "$MANAGER" install -y "${install_pkgs[@]}"
        ;;
    pacman)
        $SUDO pacman -Sy --noconfirm --needed "${install_pkgs[@]}"
        ;;
    zypper)
        $SUDO zypper install -y "${install_pkgs[@]}"
        ;;
    apk)
        $SUDO apk add "${install_pkgs[@]}"
        ;;
esac
rc=$?

if [ $rc -eq 0 ]; then
    echo ""
    echo -e "${GREEN}[ÉXITO] Instalación finalizada. Volvé a correr este script para verificar:${RESET}"
    echo "        linux/bootstrap.sh"
else
    echo ""
    echo -e "${RED}[ERROR] La instalación devolvió un error (código $rc). Revisá los mensajes anteriores.${RESET}"
    echo "        gh puede requerir un repositorio extra: https://github.com/cli/cli#installation"
fi
exit $rc
