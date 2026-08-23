#!/usr/bin/env bash
# install-lib.sh - Instala y compila librerías de C desde GitHub dentro del entorno portable (Linux).
# Los archivos se instalan en el prefijo local del entorno (<raíz>/local), nunca en el sistema host.
#
# Uso:
#   install-lib.sh <usuario/repositorio> [rama_o_tag]
#   install-lib.sh <ruta_local_al_proyecto>          (útil para pruebas offline)
#
# Requiere la sesión activada (source linux/activate.sh).

set -eu

RED='\033[31m'; GREEN='\033[32m'; YELLOW='\033[33m'; CYAN='\033[36m'; RESET='\033[0m'

if [ -z "$1" ]; then
    echo -e "${RED}[ERROR] Faltan parámetros.${RESET}"
    echo "Uso:   install-lib.sh <usuario/repositorio> [rama_o_tag]"
    echo "Ej:    install-lib.sh davidsiaw/inih r29"
    echo "       install-lib.sh immediate-mode-ui/nuklear"
    exit 1
fi

if [ -z "${PORTABLE_ROOT:-}" ]; then
    echo -e "${RED}[ERROR] No estás dentro del entorno portátil.${RESET}"
    echo "Activá primero la sesión: source linux/activate.sh"
    exit 1
fi

REPO="$1"
REF="${2:-}"
PREFIX_DIR="${PORTABLE_PREFIX:-$PORTABLE_ROOT/local}"

command -v git >/dev/null 2>&1 || { echo -e "${RED}[ERROR] git no está instalado.${RESET}"; exit 1; }

# Resolver origen: ruta local, URL completa o usuario/repositorio de GitHub
IS_LOCAL_DIR=0
if [ -d "$REPO" ]; then
    URL="$(cd "$REPO" && pwd)"
    if [ ! -e "$URL/.git" ]; then
        IS_LOCAL_DIR=1
    fi
elif [[ "$REPO" =~ ^(https?|ssh|git):// ]] || [[ "$REPO" =~ ^git@ ]]; then
    URL="$REPO"
else
    URL="https://github.com/${REPO}.git"
fi

JOBS="$(nproc 2>/dev/null || echo 2)"

TEMP_DIR="$(mktemp -d -t portable-lib-XXXXXX)"
cleanup() { rm -rf "$TEMP_DIR"; }
trap cleanup EXIT

echo -e "${CYAN}-> Obteniendo $URL en directorio temporal...${RESET}"

if [ "$IS_LOCAL_DIR" -eq 1 ]; then
    # Directorio local sin Git: copia directa (útil para pruebas offline)
    cp -r "$URL"/. "$TEMP_DIR"/
else
    if [ -n "$REF" ]; then
        if ! git clone --depth 1 --branch "$REF" "$URL" "$TEMP_DIR"; then
            echo -e "${YELLOW}[AVISO] No se encontró la rama o tag '$REF'. Intentando con la rama por defecto...${RESET}"
            git clone --depth 1 "$URL" "$TEMP_DIR"
        fi
    else
        if ! git clone --depth 1 "$URL" "$TEMP_DIR"; then
            echo -e "${RED}[ERROR] No se pudo clonar $URL. Verificá el nombre del repositorio o tu conexión.${RESET}"
            exit 1
        fi
    fi
fi

cd "$TEMP_DIR"

# ==========================================
# MANIFIESTO PARA DESINSTALACIÓN (uninstall-lib.sh)
# ==========================================
SLUG="$(printf '%s' "$(basename "$URL" .git)" | tr -c 'A-Za-z0-9._-' '_')"
MANIFEST_DIR="$PREFIX_DIR/portable-libs"
MANIFEST_FILE="$MANIFEST_DIR/${SLUG}.files"
mkdir -p "$MANIFEST_DIR"
: > "$MANIFEST_FILE"
record_file() {
    local rel="$1"
    rel="${rel#"$PREFIX_DIR"/}"
    rel="${rel#/}"
    grep -qxF "$rel" "$MANIFEST_FILE" || printf '%s\n' "$rel" >> "$MANIFEST_FILE"
}
note_install() {
    printf '# %s\n' "$1" >> "$MANIFEST_FILE"
}

# ==========================================
# FLUJO DE INSTALACIÓN SEGÚN ESPECIFICACIÓN
# ==========================================

# 1. Especificación de library.spec (Plantilla-Librería)
if [ -f "library.spec" ]; then
    echo -e "${GREEN}-> Detectada especificación de librería 'library.spec'. Cargando...${RESET}"
    # shellcheck source=/dev/null
    source "library.spec"

    build_cmd="${LIB_BUILD_CMD:-make}"
    echo -e "${GREEN}-> Compilando con: $build_cmd...${RESET}"
    eval "$build_cmd"

    echo -e "${GREEN}-> Instalando archivos exportados en $PREFIX_DIR...${RESET}"

    # Exportar cabeceras
    if [ -n "${LIB_HEADERS+x}" ] && [ ${#LIB_HEADERS[@]} -gt 0 ]; then
        for item in "${LIB_HEADERS[@]}"; do
            src="${item%%:*}"
            dest="${item#*:}"
            dest="${dest#/}"
            echo "   Cabecera: $src -> $PREFIX_DIR/$dest"
            mkdir -p "$PREFIX_DIR/$(dirname "$dest")"
            cp -p "$src" "$PREFIX_DIR/$dest"
            record_file "$dest"
        done
    fi

    # Exportar binarios
    if [ -n "${LIB_BINARIES+x}" ] && [ ${#LIB_BINARIES[@]} -gt 0 ]; then
        for item in "${LIB_BINARIES[@]}"; do
            src="${item%%:*}"
            dest="${item#*:}"
            dest="${dest#/}"
            echo "   Binario:  $src -> $PREFIX_DIR/$dest"
            mkdir -p "$PREFIX_DIR/$(dirname "$dest")"
            cp -p "$src" "$PREFIX_DIR/$dest"
            record_file "$dest"
        done
    fi
    echo -e "${GREEN}-> Instalación de librería estructurada completada.${RESET}"

# 2. Receta personalizada (.portable-recipe.sh)
elif [ -f ".portable-recipe.sh" ]; then
    echo -e "${GREEN}-> Detectada receta personalizada '.portable-recipe.sh'. Ejecutando...${RESET}"
    chmod +x .portable-recipe.sh
    ./.portable-recipe.sh "$PREFIX_DIR"
    echo -e "${GREEN}-> Instalación por receta personalizada completada.${RESET}"

# 3. Construcción con CMake
elif [ -f "CMakeLists.txt" ]; then
    if command -v cmake >/dev/null 2>&1; then
        if command -v ninja >/dev/null 2>&1; then
            GEN="Ninja"
        else
            GEN="Unix Makefiles"
        fi
        echo -e "${GREEN}-> Detectado CMakeLists.txt. Compilando con CMake ($GEN)...${RESET}"
        cmake -G "$GEN" -B build -DCMAKE_INSTALL_PREFIX="$PREFIX_DIR" -DCMAKE_BUILD_TYPE=Release
        cmake --build build -j"$JOBS"
        cmake --install build
        note_install "instalación vía cmake: archivos no enumerados individualmente"
        echo -e "${GREEN}-> Instalación vía CMake completada en $PREFIX_DIR.${RESET}"
    else
        echo -e "${RED}[ERROR] El proyecto requiere CMake y no está instalado. Instalalo con tu gestor de paquetes (linux/bootstrap.sh sugiere cómo).${RESET}"
        exit 1
    fi

# 4. Construcción con Makefile estándar
elif [ -f "Makefile" ] || [ -f "makefile" ]; then
    echo -e "${GREEN}-> Detectado Makefile. Compilando con make (-j$JOBS)...${RESET}"
    make -j"$JOBS"

    echo -e "${CYAN}-> Intentando instalar en el prefijo $PREFIX_DIR...${RESET}"
    if make install PREFIX="$PREFIX_DIR" prefix="$PREFIX_DIR" DESTDIR="" >/dev/null 2>&1; then
        note_install "instalación vía 'make install': archivos no enumerados individualmente"
        echo -e "${GREEN}-> Instalación vía Makefile completada.${RESET}"
    else
        echo -e "${YELLOW}[ADVERTENCIA] 'make install' falló. Copiando archivos de forma manual...${RESET}"
        mkdir -p "$PREFIX_DIR/include" "$PREFIX_DIR/lib"
        find . -maxdepth 2 -name "*.h" | while read -r f; do
            cp -p "$f" "$PREFIX_DIR/include/"
            record_file "include/$(basename "$f")"
        done
        find . -maxdepth 2 \( -name "*.a" -o -name "*.so*" \) | while read -r f; do
            cp -p "$f" "$PREFIX_DIR/lib/"
            record_file "lib/$(basename "$f")"
        done
        find . -maxdepth 2 -type f -perm -u+x -name "*" -path "*bin*" | while read -r f; do
            cp -p "$f" "$PREFIX_DIR/bin/"
            record_file "bin/$(basename "$f")"
        done
        echo -e "${GREEN}-> Copia manual del Makefile finalizada.${RESET}"
    fi

# 5. Librerías de Cabecera (Header-only) u otros archivos sueltos
else
    echo -e "${YELLOW}-> Sin sistema de construcción estándar. Buscando archivos .h/.hpp...${RESET}"
    HEADERS=$(find . \( -name "*.h" -o -name "*.hpp" \) | head -n 1)
    if [ -n "$HEADERS" ]; then
        echo -e "${GREEN}-> Copiando archivos de cabecera a $PREFIX_DIR/include...${RESET}"
        find . \( -name "*.h" -o -name "*.hpp" \) | while read -r file; do
            rel="${file#./}"
            dest_dir="$PREFIX_DIR/include/$(dirname "$rel")"
            mkdir -p "$dest_dir"
            cp -p "$file" "$dest_dir/"
            record_file "include/$rel"
        done
        echo -e "${GREEN}-> Copia de archivos de cabecera completada.${RESET}"
    else
        echo -e "${RED}[ERROR] No se reconoció ningún método de instalación ni cabeceras en el repositorio.${RESET}"
        exit 1
    fi
fi

echo ""
echo -e "${GREEN}=== PROCESO DE INSTALACIÓN EXITOSO ===${RESET}"
echo "Cabeceras : $PREFIX_DIR/include"
echo "Librerías : $PREFIX_DIR/lib"
echo ""
echo "La sesión activada ya exporta CPATH, LIBRARY_PATH, PKG_CONFIG_PATH y"
echo "CMAKE_PREFIX_PATH hacia este prefijo, por lo que podés compilar directamente:"
echo "  gcc test.c -o test   (cabeceras y librerías se resuelven automáticamente)"
