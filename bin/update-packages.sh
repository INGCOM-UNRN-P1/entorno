#!/usr/bin/env bash
# update-packages.sh - Sincroniza pacman, actualiza el sistema e instala los paquetes necesarios.
# Debe ejecutarse dentro del terminal portable (launch.bat).

set -e

# Asegurar codificación UTF-8 para soporte de acentos y caracteres especiales
export LANG="es_AR.UTF-8"
export LC_ALL="es_AR.UTF-8"

if [ -z "$MSYSTEM_PREFIX" ]; then
    echo -e "\e[31m[ERROR] No estás dentro de la consola del entorno portable.\e[0m"
    echo "Por favor, ejecutá 'launch.bat' o 'launch-vscode.bat' antes de correr este script."
    exit 1
fi

echo -e "\e[36m=== Actualización de Paquetes de Pacman ===\e[0m"

# 1. Sincronizar bases de datos y actualizar paquetes del sistema
echo -e "\e[33mSincronizando base de datos de pacman y actualizando paquetes del sistema...\e[0m"
pacman -Syu --noconfirm

echo -e "\e[33mConsolidando actualizaciones del entorno...\e[0m"
pacman -Su --noconfirm

# 2. Definir e instalar los paquetes requeridos por el entorno
PACKAGES=(
    "mingw-w64-clang-x86_64-clang"
    "mingw-w64-clang-x86_64-lld"
    "mingw-w64-clang-x86_64-make"
    "mingw-w64-clang-x86_64-cmake"
    "mingw-w64-clang-x86_64-ninja"
    "mingw-w64-clang-x86_64-gdb"
    "mingw-w64-clang-x86_64-python"
    "mingw-w64-clang-x86_64-python-pip"
    "mingw-w64-clang-x86_64-uv"
    "mingw-w64-clang-x86_64-cppcheck"
    "mingw-w64-clang-x86_64-zlib"
    "mingw-w64-clang-x86_64-openssl"
    "mingw-w64-clang-x86_64-sqlite3"
    "mingw-w64-clang-x86_64-curl"
    "mingw-w64-clang-x86_64-doxygen"
    "git"
)

echo -e "\e[33mVerificando e instalando dependencias obligatorias del entorno...\e[0m"
pacman -S --needed --noconfirm "${PACKAGES[@]}"

echo -e "\e[32mSincronización y actualización de paquetes completada con éxito.\e[0m"
