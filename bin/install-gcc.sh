#!/usr/bin/env bash
# install-gcc.sh – Instala el toolchain GCC (MinGW‑w64) con los paquetes mínimos comunes.
# Incluye compilador, make, cmake, ninja, gdb y Python.

set -e
export LANG="es_AR.UTF-8"
export LC_ALL="es_AR.UTF-8"

if [ -z "$MSYSTEM_PREFIX" ]; then
    echo -e "\e[31m[ERROR] No estás dentro de la consola del entorno portable.\e[0m"
    echo "Ejecuta 'launch.bat' o 'launch-vscode.bat' antes de correr este script."
    exit 1
fi

echo -e "\e[36m=== Instalación mínima de GCC ===\e[0m"

# Paquetes GCC esenciales
gcc_packages=(
    "mingw-w64-gcc-x86_64-gcc"
    "mingw-w64-gcc-x86_64-g++"
    "mingw-w64-gcc-x86_64-make"
    "mingw-w64-gcc-x86_64-cmake"
    "mingw-w64-gcc-x86_64-ninja"
    "mingw-w64-gcc-x86_64-gdb"
    "mingw-w64-gcc-x86_64-python"
    "mingw-w64-gcc-x86_64-python-pip"
    "mingw-w64-gcc-x86_64-uv"
    "mingw-w64-gcc-x86_64-cppcheck"
)

pacman -S --needed --noconfirm "${gcc_packages[@]}"

echo -e "\e[32mInstalación de GCC completada.\e[0m"
