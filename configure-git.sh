#!/usr/bin/env bash
# configure-git.sh - Configura la identidad de Git y el almacenamiento de credenciales portátil.
# Debe ejecutarse dentro del terminal portable (launch.bat).

set -e

if [ -z "$MSYSTEM_PREFIX" ]; then
    echo -e "\e[31m[ERROR] No estás dentro de la consola del entorno portable.\e[0m"
    echo "Por favor, ejecutá 'launch.bat' o 'launch-vscode.bat' antes de correr este script."
    exit 1
fi

echo -e "\e[36m=== Configuración de Git Portable ===\e[0m"

# Solicitar Nombre
read -p "Ingresá tu nombre para Git (Ej: Martín René): " GIT_NAME
if [ -n "$GIT_NAME" ]; then
    git config --global user.name "$GIT_NAME"
fi

# Solicitar Email
read -p "Ingresá tu email para Git (Ej: user@gmail.com): " GIT_EMAIL
if [ -n "$GIT_EMAIL" ]; then
    git config --global user.email "$GIT_EMAIL"
fi

# Configurar Credential Helper Portable
# Guarda las credenciales en un archivo de texto en el HOME portable del pendrive/carpeta.
echo "Configurando almacenamiento de credenciales portable..."
git config --global credential.helper 'store --file ~/.git-credentials'

# Configuración básica recomendada
git config --global core.autocrlf input
git config --global init.defaultBranch main

echo -e "\e[32mGit configurado con éxito.\e[0m"
echo -e "Nombre:  $(git config --global user.name)"
echo -e "Email:   $(git config --global user.email)"
echo -e "Destino: ~/.gitconfig (portable)\n"

# Autenticar GitHub CLI
if command -v gh &> /dev/null; then
    echo -e "\e[36m=== Autenticación de GitHub CLI (gh) ===\e[0m"
    read -p "¿Querés iniciar sesión en GitHub CLI ahora? (s/n): " AUTH_GH
    if [[ "$AUTH_GH" =~ ^[sS]$ ]]; then
        gh auth login
    fi
fi
