#!/usr/bin/env bash
# update-env.sh - Actualiza los scripts de la variante Linux del entorno portable.
# Si el repositorio fue clonado con Git, usa 'git pull'; si es standalone,
# descarga el snapshot del canal configurado en .env (CHANNEL, por defecto main).
# Las herramientas nativas (gcc, cmake, etc.) se actualizan con el gestor de
# paquetes de tu distribución: este entorno nunca las instala ni modifica el sistema.

set -eu

if [ -z "${PORTABLE_ROOT:-}" ]; then
    echo -e "\e[31m[ERROR] No estás dentro del entorno portable.\e[0m"
    echo "Activá primero la sesión: source linux/activate.sh"
    exit 1
fi

REPO_OWNER="INGCOM-UNRN-P1"
REPO_NAME="entorno"
# Canal de actualización configurable vía .env (ej: CHANNEL=estable-2026c1)
BRANCH="main"
if [ -f "$PORTABLE_ROOT/.env" ]; then
    parsed_branch="$(sed -n -E 's/^CHANNEL=([^[:space:]#]+).*$/\1/p' "$PORTABLE_ROOT/.env" | head -n 1)"
    [ -n "$parsed_branch" ] && BRANCH="$parsed_branch"
fi

echo -e "\e[36m======================================================================\e[0m"
echo -e "\e[36m     Actualización de Scripts del Entorno Portable (Linux) [canal: $BRANCH]\e[0m"
echo -e "\e[36m======================================================================\e[0m"

updated=0

# 1. Repositorio Git: git pull
if [ -d "$PORTABLE_ROOT/.git" ] && command -v git >/dev/null 2>&1; then
    echo "-> Repositorio Git detectado. Ejecutando git pull..."
    if git -C "$PORTABLE_ROOT" pull; then
        updated=1
        echo -e "\e[32m[OK] Scripts actualizados vía Git.\e[0m"
    else
        echo -e "\e[33m[AVISO] git pull falló (¿sin conexión o conflictos?). Se intentará snapshot.\e[0m"
    fi
fi

# 2. Standalone: snapshot ZIP
if [ "$updated" -eq 0 ] && [ ! -d "$PORTABLE_ROOT/.git" ]; then
    TEMP_DIR="$(mktemp -d)"
    trap 'rm -rf "$TEMP_DIR"' EXIT
    ZIP_PATH="$TEMP_DIR/repo.zip"
    echo "-> Descargando snapshot del canal '$BRANCH' desde GitHub..."
    curl -sSL -o "$ZIP_PATH" "https://github.com/$REPO_OWNER/$REPO_NAME/archive/refs/heads/$BRANCH.zip"
    unzip -q -o "$ZIP_PATH" -d "$TEMP_DIR"
    EXTRACTED_DIR="$TEMP_DIR/$REPO_NAME-$BRANCH"
    [ -d "$EXTRACTED_DIR" ] || { echo -e "\e[31m[ERROR] Snapshot inesperado.\e[0m"; exit 1; }

    cp -r "$EXTRACTED_DIR/linux/." "$PORTABLE_ROOT/linux/"
    for f in README.md plan.md AGENTS.md packages-baseline.txt VERSION; do
        [ -f "$EXTRACTED_DIR/$f" ] && cp -f "$EXTRACTED_DIR/$f" "$PORTABLE_ROOT/"
    done
    chmod +x "$PORTABLE_ROOT"/linux/bin/* "$PORTABLE_ROOT"/linux/*.sh 2>/dev/null || true
    updated=1
    echo -e "\e[32m[OK] Scripts de linux/ actualizados a la versión del canal.\e[0m"
fi

if [ "$updated" -eq 0 ]; then
    echo -e "\e[33m[INFO] No se pudo actualizar automáticamente. Revisá tu conexión o ejecutá git pull manualmente.\e[0m"
    exit 1
fi

echo ""
echo -e "\e[36m[INFO] Para actualizar las herramientas nativas usá tu gestor de paquetes\e[0m"
echo -e "\e[36m       (linux/bootstrap.sh sugiere los comandos según tu distribución).\e[0m"
