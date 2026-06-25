#!/usr/bin/env bash
# install-llvm-clang.sh – Instala el toolchain LLVM/Clang (MinGW‑w64) con los paquetes mínimos comunes.
# Incluye compilador clang, enlazador lld y runtime LLVM.

set -e
export LANG="es_AR.UTF-8"
export LC_ALL="es_AR.UTF-8"

if [ -z "$MSYSTEM_PREFIX" ]; then
    echo -e "\e[31m[ERROR] No estás dentro de la consola del entorno portable.\e[0m"
    echo "Ejecuta 'launch.bat' o 'launch-vscode.bat' antes de correr este script."
    exit 1
fi

echo -e "\e[36m=== Instalación mínima de LLVM/Clang ===\e[0m"

# Paquetes LLVM/Clang esenciales
clang_packages=(
    "mingw-w64-clang-x86_64-clang"
    "mingw-w64-clang-x86_64-lld"
    "mingw-w64-clang-x86_64-llvm"
)

pacman -S --needed --noconfirm "${clang_packages[@]}"

echo -e "\e[32mInstalación de LLVM/Clang completada.\e[0m"
