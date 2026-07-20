#!/usr/bin/env bash
# install-lib.sh - Instala y compila librerías de C desde GitHub en el entorno portable.
# Diseñado para ejecutarse dentro del terminal Clang64 Bash.

set -e

# Imprimir uso si faltan parámetros
if [ -z "$1" ]; then
    echo -e "\e[31m[ERROR] Faltan parámetros.\e[0m"
    echo "Uso:   ./install-lib.sh <usuario/repositorio> [rama_o_tag]"
    echo "Ej:    ./install-lib.sh primaryfe/nuklear"
    echo "       ./install-lib.sh davidsiaw/inih r29"
    exit 1
fi

REPO=$1
REF=${2:-""}
PREFIX_DIR="${MSYSTEM_PREFIX}"

if [ -z "$PREFIX_DIR" ]; then
    echo -e "\e[31m[ERROR] No estás dentro de la consola del entorno portable.\e[0m"
    echo "Por favor, ejecutá 'launch.bat' o 'launch-vscode.bat' antes de correr este script."
    exit 1
fi

# Resolver URL de GitHub
if [[ ! "$REPO" =~ ^http ]]; then
    URL="https://github.com/${REPO}.git"
else
    URL="$REPO"
fi

# Directorio temporal para la clonación
TEMP_DIR=$(mktemp -d -t portable-lib-XXXXXX)
echo -e "\e[36m-> Clonando $URL en directorio temporal...\e[0m"

if [ -n "$REF" ]; then
    git clone --depth 1 --branch "$REF" "$URL" "$TEMP_DIR"
else
    git clone --depth 1 "$URL" "$TEMP_DIR"
fi

cd "$TEMP_DIR"

# ==========================================
# FLUJO DE INSTALACIÓN SEGÚN ESPECIFICACIÓN
# ==========================================

# 1. Especificación de library.spec (Plantilla-Librería)
if [ -f "library.spec" ]; then
    echo -e "\e[32m-> Detectada especificación de librería 'library.spec'. Cargando...\e[0m"
    # shellcheck source=/dev/null
    source "library.spec"
    
    build_cmd="${LIB_BUILD_CMD:-make}"
    echo -e "\e[32m-> Compilando con: $build_cmd...\e[0m"
    eval "$build_cmd"
    
    echo -e "\e[32m-> Instalando archivos exportados en $PREFIX_DIR...\e[0m"
    
    # Exportar cabeceras
    if [ -n "${LIB_HEADERS+x}" ] && [ ${#LIB_HEADERS[@]} -gt 0 ]; then
        for item in "${LIB_HEADERS[@]}"; do
            src="${item%%:*}"
            dest="${item#*:}"
            echo "   Cabecera: $src -> $PREFIX_DIR/$dest"
            mkdir -p "$PREFIX_DIR/$(dirname "$dest")"
            cp -p "$src" "$PREFIX_DIR/$dest"
        done
    fi
    
    # Exportar binarios
    if [ -n "${LIB_BINARIES+x}" ] && [ ${#LIB_BINARIES[@]} -gt 0 ]; then
        for item in "${LIB_BINARIES[@]}"; do
            src="${item%%:*}"
            dest="${item#*:}"
            echo "   Binario:  $src -> $PREFIX_DIR/$dest"
            mkdir -p "$PREFIX_DIR/$(dirname "$dest")"
            cp -p "$src" "$PREFIX_DIR/$dest"
        done
    fi
    echo -e "\e[32m-> Instalación de librería estructurada completada.\e[0m"

# 2. Receta personalizada (.portable-recipe.sh)
elif [ -f ".portable-recipe.sh" ]; then
    echo -e "\e[32m-> Detectada receta personalizada '.portable-recipe.sh'. Ejecutando...\e[0m"
    chmod +x .portable-recipe.sh
    ./.portable-recipe.sh "$PREFIX_DIR"
    echo -e "\e[32m-> Instalación por receta personalizada completada.\e[0m"

# 3. Construcción con CMake
elif [ -f "CMakeLists.txt" ]; then
    echo -e "\e[32m-> Detectado archivo CMakeLists.txt. Compilando con CMake + Ninja...\e[0m"
    cmake -G Ninja -B build -DCMAKE_INSTALL_PREFIX="$PREFIX_DIR" -DCMAKE_BUILD_TYPE=Release
    cmake --build build
    cmake --install build
    echo -e "\e[32m-> Instalación vía CMake completada en $PREFIX_DIR.\e[0m"

# 4. Construcción con Makefile estándar
elif [ -f "Makefile" ] || [ -f "makefile" ]; then
    echo -e "\e[32m-> Detectado Makefile. Compilando con mingw32-make...\e[0m"
    mingw32-make -j$(nproc)
    
    echo -e "\e[36m-> Intentando instalar en el prefijo $PREFIX_DIR...\e[0m"
    # Intentar instalar usando variables comunes de Makefile
    if mingw32-make install PREFIX="$PREFIX_DIR" DESTDIR="" >/dev/null 2>&1; then
        echo -e "\e[32m-> Instalación vía Makefile completada.\e[0m"
    else
        echo -e "\e[33m[ADVERTENCIA] 'make install' falló. Copiando archivos de forma manual...\e[0m"
        # Copia de seguridad si falla la instalación estándar del Makefile
        mkdir -p "$PREFIX_DIR/include" "$PREFIX_DIR/lib"
        find . -maxdepth 2 -name "*.h" -exec cp -p {} "$PREFIX_DIR/include/" \; 2>/dev/null || true
        find . -maxdepth 2 -name "*.a" -exec cp -p {} "$PREFIX_DIR/lib/" \; 2>/dev/null || true
        find . -maxdepth 2 -name "*.dll" -exec cp -p {} "$PREFIX_DIR/bin/" \; 2>/dev/null || true
        echo -e "\e[32m-> Copia manual del Makefile finalizada.\e[0m"
    fi

# 4. Librerías de Cabecera (Header-only) u otros archivos sueltos
else
    echo -e "\e[33m-> Sin sistema de construcción estándar. Buscando archivos .h...\e[0m"
    HEADERS=$(find . -name "*.h" -o -name "*.hpp")
    if [ -n "$HEADERS" ]; then
        echo -e "\e[32m-> Copiando archivos de cabecera a $PREFIX_DIR/include...\e[0m"
        mkdir -p "$PREFIX_DIR/include"
        # Copiar manteniendo estructura relativa o plano si es corto
        find . -name "*.h" -o -name "*.hpp" | while read -r file; do
            dest_dir="$PREFIX_DIR/include/$(dirname "$file")"
            mkdir -p "$dest_dir"
            cp -p "$file" "$dest_dir/"
        done
        echo -e "\e[32m-> Copia de archivos de cabecera completada.\e[0m"
    else
        echo -e "\e[31m[ERROR] No se reconoció ningún método de instalación ni cabeceras en el repositorio.\e[0m"
        cd /
        rm -rf "$TEMP_DIR"
        exit 1
    fi
fi

# Limpieza final de temporales
cd /
rm -rf "$TEMP_DIR"
echo -e "\e[32m=== PROCESO DE INSTALACIÓN EXITOSO ===\e[0m"
