#!/usr/bin/env bash
# setup-personal.sh - Instalador del entorno de desarrollo para computadoras personales
# Compatible con macOS (Darwin) y distribuciones Linux.
#
# Acciones que realiza:
#   1. Comprueba paquetes de herramientas básicas del sistema (C, make, git, python3).
#   2. Instala 'uv' en el perfil del estudiante (~/.local/bin).
#   3. Instala 'gh' (GitHub CLI) de forma local en el perfil (~/.local/bin) sin requerir sudo.
#   4. Instala los scripts de gestión de cátedra (ayuda, clonar, nuevo-proyecto, verificar, entregar, doctor).
#   5. Configura el PATH de forma idempotente en ~/.bashrc, ~/.zshrc y ~/.bash_profile.
#   6. Ejecuta una comprobación de salud del entorno.

set -eu

CYAN='\033[36m'; GREEN='\033[32m'; RED='\033[31m'; YELLOW='\033[33m'; RESET='\033[0m'
BOLD='\033[1m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_BIN="${TARGET_BIN_DIR:-$HOME/.local/bin}"

OS_TYPE="$(uname -s)"
ARCH_TYPE="$(uname -m)"

echo -e "${CYAN}${BOLD}======================================================================${RESET}"
echo -e "${CYAN}${BOLD}  INSTALADOR DE ENTORNO PERSONAL — PROGRAMACIÓN 1 (macOS / Linux)     ${RESET}"
echo -e "${CYAN}${BOLD}======================================================================${RESET}"
echo -e "Sistema Operativo detectado : ${OS_TYPE} (${ARCH_TYPE})"
echo -e "Directorio de instalación   : ${TARGET_BIN}"
echo ""

mkdir -p "${TARGET_BIN}"

# ----------------------------------------------------------------------
# 1. Comprobación de paquetes del sistema
# ----------------------------------------------------------------------
echo -e "${CYAN}[1/5] Comprobando herramientas base del sistema...${RESET}"

MISSING_TOOLS=()
for tool in git make python3 curl; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        MISSING_TOOLS+=("$tool")
    fi
done

# Compilador C (clang o gcc)
if ! command -v clang >/dev/null 2>&1 && ! command -v gcc >/dev/null 2>&1; then
    MISSING_TOOLS+=("compilador C (clang/gcc)")
fi

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    echo -e "${YELLOW}[AVISO] Se detectaron herramientas faltantes en el sistema:${RESET}"
    for m in "${MISSING_TOOLS[@]}"; do
        echo "  - $m"
    done
    echo ""
    if [ "$OS_TYPE" = "Darwin" ]; then
        echo -e "${CYAN}En macOS podés instalarlas ejecutando en terminal:${RESET}"
        echo "  xcode-select --install"
        echo "O utilizando Homebrew: brew install git make python"
    else
        echo -e "${CYAN}En Linux podés instalarlas con tu gestor de paquetes:${RESET}"
        if command -v apt-get >/dev/null 2>&1; then
            echo "  sudo apt update && sudo apt install build-essential git python3 curl"
        elif command -v dnf >/dev/null 2>&1; then
            echo "  sudo dnf install gcc gcc-c++ make git python3 curl"
        elif command -v pacman >/dev/null 2>&1; then
            echo "  sudo pacman -S base-devel git python curl"
        fi
    fi
    echo ""
else
    echo -e "${GREEN}[OK] Herramientas básicas presentes.${RESET}"
fi

# ----------------------------------------------------------------------
# 2. Instalación de UV en el perfil del estudiante
# ----------------------------------------------------------------------
echo ""
echo -e "${CYAN}[2/5] Comprobando gestor de herramientas Python 'uv'...${RESET}"

if command -v uv >/dev/null 2>&1; then
    echo -e "${GREEN}[OK] 'uv' ya se encuentra instalado en: $(command -v uv)${RESET}"
else
    echo -e "${CYAN}-> Instalando 'uv' en el perfil del usuario (${TARGET_BIN})...${RESET}"
    if command -v curl >/dev/null 2>&1; then
        # Instalador oficial de Astral configurando destino en TARGET_BIN
        UV_INSTALL_DIR="${TARGET_BIN}" curl -LsSf https://astral.sh/uv/install.sh | env CARGO_HOME="$HOME/.cargo" sh || true
        # Asegurar binario en TARGET_BIN
        if [ -f "$HOME/.cargo/bin/uv" ] && [ ! -f "${TARGET_BIN}/uv" ]; then
            cp "$HOME/.cargo/bin/uv" "${TARGET_BIN}/uv"
            cp "$HOME/.cargo/bin/uvx" "${TARGET_BIN}/uvx" 2>/dev/null || true
            chmod +x "${TARGET_BIN}/uv"
        fi
    fi

    if [ -x "${TARGET_BIN}/uv" ]; then
        echo -e "${GREEN}[OK] 'uv' instalado exitosamente en ${TARGET_BIN}/uv${RESET}"
    else
        echo -e "${YELLOW}[AVISO] No se pudo instalar automáticamente 'uv'. Podés instalarlo con:${RESET}"
        echo "  curl -LsSf https://astral.sh/uv/install.sh | sh"
    fi
fi

# ----------------------------------------------------------------------
# 3. Instalación de GitHub CLI (gh) de forma local en el perfil
# ----------------------------------------------------------------------
echo ""
echo -e "${CYAN}[3/5] Comprobando GitHub CLI (gh) en el perfil...${RESET}"

GH_INSTALLED=0
if [ -x "${TARGET_BIN}/gh" ]; then
    GH_INSTALLED=1
    echo -e "${GREEN}[OK] 'gh' ya está instalado en el perfil: ${TARGET_BIN}/gh${RESET}"
elif command -v gh >/dev/null 2>&1; then
    GH_INSTALLED=1
    echo -e "${GREEN}[OK] 'gh' disponible en el sistema: $(command -v gh)${RESET}"
fi

if [ "$GH_INSTALLED" -eq 0 ]; then
    echo -e "${CYAN}-> Descargando e instalando 'gh' en forma local en ${TARGET_BIN}...${RESET}"
    GH_VERSION="2.55.0"
    TMP_GH="$(mktemp -d)"
    
    # Mapeo de plataforma y arquitectura
    GH_OS=""
    GH_ARCH=""
    case "$OS_TYPE" in
        Darwin) GH_OS="macOS" ;;
        Linux)  GH_OS="linux" ;;
        *)      GH_OS="linux" ;;
    esac

    case "$ARCH_TYPE" in
        x86_64|amd64)   GH_ARCH="amd64" ;;
        arm64|aarch64)  GH_ARCH="arm64" ;;
        *)              GH_ARCH="386" ;;
    esac

    TARBALL_NAME="gh_${GH_VERSION}_${GH_OS}_${GH_ARCH}"
    EXT="tar.gz"
    [ "$GH_OS" = "macOS" ] && EXT="zip"

    GH_URL="https://github.com/cli/cli/releases/download/v${GH_VERSION}/${TARBALL_NAME}.${EXT}"
    
    echo "  Descargando desde: $GH_URL"
    if curl -sSL -f -o "$TMP_GH/gh_pkg.${EXT}" "$GH_URL"; then
        if [ "$EXT" = "zip" ]; then
            unzip -q "$TMP_GH/gh_pkg.zip" -d "$TMP_GH"
        else
            tar -xzf "$TMP_GH/gh_pkg.tar.gz" -C "$TMP_GH"
        fi
        
        EXTRACTED_BIN="$(find "$TMP_GH" -type f -name gh -perm -111 2>/dev/null | head -n1 || true)"
        if [ -n "$EXTRACTED_BIN" ] && [ -f "$EXTRACTED_BIN" ]; then
            cp "$EXTRACTED_BIN" "${TARGET_BIN}/gh"
            chmod +x "${TARGET_BIN}/gh"
            echo -e "${GREEN}[OK] 'gh' instalado exitosamente en ${TARGET_BIN}/gh${RESET}"
        fi
    else
        echo -e "${YELLOW}[AVISO] No se pudo descargar el binario precompilado de gh.${RESET}"
        echo "Podés instalarlo con tu gestor de paquetes si disponés de permisos."
    fi
    rm -rf "$TMP_GH"
fi

# ----------------------------------------------------------------------
# 4. Instalación de scripts de gestión mínimos
# ----------------------------------------------------------------------
echo ""
echo -e "${CYAN}[4/5] Instalando scripts de gestión en ${TARGET_BIN}...${RESET}"

SRC_BIN_DIR="${SCRIPT_DIR}/bin"
SCRIPTS_GESTION=(ayuda clonar nuevo-proyecto verificar entregar doctor)

for s in "${SCRIPTS_GESTION[@]}"; do
    if [ -f "${SRC_BIN_DIR}/$s" ]; then
        cp "${SRC_BIN_DIR}/$s" "${TARGET_BIN}/$s"
        chmod +x "${TARGET_BIN}/$s"
        echo "  * Instalado: ${TARGET_BIN}/$s"
    fi
done

# Copiar también el desinstalador para acceso rápido
cp "${SCRIPT_DIR}/desinstalar-personal.sh" "${TARGET_BIN}/desinstalar-personal.sh" 2>/dev/null || true
[ -f "${TARGET_BIN}/desinstalar-personal.sh" ] && chmod +x "${TARGET_BIN}/desinstalar-personal.sh"

# ----------------------------------------------------------------------
# 5. Configuración del PATH en el perfil del usuario
# ----------------------------------------------------------------------
echo ""
echo -e "${CYAN}[5/5] Configurando variables de entorno en el perfil del estudiante...${RESET}"

PATH_LINE="export PATH=\"${TARGET_BIN}:\$PATH\""
BLOCK_START="# >>> P1-GESTION-PERSONAL >>>"
BLOCK_END="# <<< P1-GESTION-PERSONAL <<<"

configurar_archivo_perfil() {
    local perfil="$1"
    [ ! -f "$perfil" ] && touch "$perfil"

    if grep -qF "$BLOCK_START" "$perfil"; then
        # Actualizar bloque existente
        sed -i.bak "/$BLOCK_START/,/$BLOCK_END/d" "$perfil" 2>/dev/null || sed -i "" "/$BLOCK_START/,/$BLOCK_END/d" "$perfil"
        rm -f "${perfil}.bak"
    fi

    cat << PROFILE_EOF >> "$perfil"

$BLOCK_START
# Configuración del entorno de cátedra Programación 1
$PATH_LINE
$BLOCK_END
PROFILE_EOF
    echo "  * Actualizado: $perfil"
}

# Configurar para bash y zsh
[ -f "$HOME/.bashrc" ] || [ -f "$HOME/.bash_profile" ] || [ "$OS_TYPE" = "Linux" ] && configurar_archivo_perfil "$HOME/.bashrc"
if [ "$OS_TYPE" = "Darwin" ]; then
    configurar_archivo_perfil "$HOME/.zshrc"
    configurar_archivo_perfil "$HOME/.bash_profile"
elif [ -f "$HOME/.zshrc" ] || [ "${SHELL:-}" = "*/zsh" ]; then
    configurar_archivo_perfil "$HOME/.zshrc"
fi

# Exportar PATH en la sesión actual
export PATH="${TARGET_BIN}:$PATH"

echo ""
echo -e "${GREEN}${BOLD}======================================================================${RESET}"
echo -e "${GREEN}${BOLD}  INSTALACIÓN COMPLETADA EXITOSAMENTE                                 ${RESET}"
echo -e "${GREEN}${BOLD}======================================================================${RESET}"
echo "Comandos disponibles en tu terminal:"
echo "  - ayuda"
echo "  - nuevo-proyecto"
echo "  - clonar"
echo "  - verificar"
echo "  - entregar"
echo "  - doctor"
echo ""
echo "Para aplicar los cambios en tus terminales abiertas actuales, ejecutá:"
echo -e "${CYAN}  source ~/.bashrc${RESET}  (si usás Bash) o  ${CYAN}source ~/.zshrc${RESET}  (si usás Zsh)"
echo ""

# Ejecutar doctor para validar salud inicial
if [ -x "${TARGET_BIN}/doctor" ]; then
    "${TARGET_BIN}/doctor" || true
fi
