#!/usr/bin/env bash
# update-self.sh – Auto‑actualiza el entorno portable.
# 1) Actualiza el repositorio (scripts, docs, etc.)
# 2) Sincroniza la base de datos de pacman y actualiza los paquetes instalados
# 3) Opcional: reinstala toolchains GCC/LLVM si se desea (se puede comentar).
# 4) Copia cualquier cambio en el directorio portable 'home/' al $HOME del usuario.

set -e
export LANG="es_AR.UTF-8"
export LC_ALL="es_AR.UTF-8"

# Verificar que estamos dentro del entorno portable
if [ -z "$MSYSTEM_PREFIX" ]; then
    echo -e "\e[31m[ERROR] No estás dentro de la consola del entorno portable.\e[0m"
    echo "Ejecuta 'launch.bat' o 'launch-vscode.bat' antes de correr este script."
    exit 1
fi

# ----------------------------------------------------------------------
# 1) Actualizar scripts mediante git
# ----------------------------------------------------------------------
if [ -d ".git" ]; then
    echo -e "\e[36m=== Actualizando scripts del entorno (git pull) ===\e[0m"
    git fetch --all --quiet
    git reset --hard origin/main --quiet
    echo -e "\e[32mScripts actualizados.\e[0m"
else
    echo -e "\e[33m[WARN] No se encontró repositorio git; se asume código está estático.\e[0m"
fi

# ----------------------------------------------------------------------
# 2) Actualizar paquetes del sistema (pacman)
# ----------------------------------------------------------------------
echo -e "\e[36m=== Sincronizando bases de datos de pacman ===\e[0m"
pacman -Syu --noconfirm

# Ejecutar script propio que instala/actualiza los paquetes obligatorios
if [ -x "bin/update-packages.sh" ]; then
    echo -e "\e[36m=== Ejecutando update-packages.sh ===\e[0m"
    ./bin/update-packages.sh
fi

# ----------------------------------------------------------------------
# 3) (Opcional) Reinstalar toolchains mínimas
# ----------------------------------------------------------------------
# Descomentar si se desea reinstalar GCC/Clang en cada actualización
# echo -e "\e[36m=== Reinstalando GCC ===\e[0m"
# ./bin/install-gcc.sh
# echo -e "\e[36m=== Reinstalando LLVM/Clang ===\e[0m"
# ./bin/install-llvm-clang.sh

# ----------------------------------------------------------------------
# 4) Copiar configuración portable (home) al $HOME del usuario
# ----------------------------------------------------------------------
if [ -d "$MSYSTEM_PREFIX/home" ]; then
    echo -e "\e[36m=== Copiando contenido de $HOME portable ===\e[0m"
    rsync -a --ignore-existing "$MSYSTEM_PREFIX/home/" "$HOME/"
    echo -e "\e[32mContenido copiado a $HOME.\e[0m"
else
    echo -e "\e[33m[WARN] Directorio portable home no encontrado; nada que copiar.\e[0m"
fi

echo -e "\e[32mActualización completa. Reinicia la consola para cargar los cambios.\e[0m"
