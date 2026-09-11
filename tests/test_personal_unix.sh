#!/usr/bin/env bash
# test_personal_unix.sh - Pruebas de integración para instalación y desinstalación personal en macOS/Linux

set -eu

CYAN='\033[36m'; GREEN='\033[32m'; RED='\033[31m'; RESET='\033[0m'
BOLD='\033[1m'

echo -e "${CYAN}${BOLD}=== Iniciando pruebas de entorno personal para macOS / Linux ===${RESET}"

TEST_HOME="$(mktemp -d)"
trap 'rm -rf "$TEST_HOME"' EXIT

# Simular entorno de usuario aislado
export HOME="$TEST_HOME"
export TARGET_BIN_DIR="$TEST_HOME/.local/bin"
export PATH="$TARGET_BIN_DIR:$PATH"

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 1. Crear perfiles simulados
touch "$HOME/.bashrc"
touch "$HOME/.zshrc"

echo "-> Ejecutando instalador en HOME simulado: $HOME ..."
bash "$SCRIPT_ROOT/unix/setup-personal.sh"

# 2. Verificar que los binarios existan y sean ejecutables
echo "-> Verificando scripts de gestión instalados en $TARGET_BIN_DIR ..."
for s in ayuda clonar nuevo-proyecto verificar entregar doctor desinstalar-personal.sh; do
    if [ ! -x "$TARGET_BIN_DIR/$s" ]; then
        echo -e "${RED}[FALLA] Falta $s o no es ejecutable en $TARGET_BIN_DIR${RESET}"
        exit 1
    fi
done
echo -e "${GREEN}[OK] Todos los scripts de gestión están presentes y tienen permisos +x.${RESET}"

# 3. Verificar que los perfiles tengan el bloque de PATH
for prof in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if ! grep -q "P1-GESTION-PERSONAL" "$prof"; then
        echo -e "${RED}[FALLA] El archivo $prof no contiene el bloque de configuración de PATH.${RESET}"
        exit 1
    fi
done
echo -e "${GREEN}[OK] Bloques de PATH configurados correctamente en .bashrc y .zshrc.${RESET}"

# 4. Prueba funcional de los scripts
echo "-> Probando 'ayuda' ..."
"$TARGET_BIN_DIR/ayuda" >/dev/null

echo "-> Probando 'nuevo-proyecto' ..."
cd "$TEST_HOME"
"$TARGET_BIN_DIR/nuevo-proyecto" "demo_tp"
if [ ! -f "$TEST_HOME/demo_tp/main.c" ] || [ ! -f "$TEST_HOME/demo_tp/Makefile" ]; then
    echo -e "${RED}[FALLA] 'nuevo-proyecto' no creó los archivos esperados.${RESET}"
    exit 1
fi
echo -e "${GREEN}[OK] 'nuevo-proyecto' generó la estructura correctamente.${RESET}"

echo "-> Probando 'verificar' en el proyecto creado ..."
cd "$TEST_HOME/demo_tp"
"$TARGET_BIN_DIR/verificar" .
echo -e "${GREEN}[OK] 'verificar' compiló y evaluó el proyecto correctamente.${RESET}"

echo "-> Probando 'entregar' ..."
# Responder 's' a compilar y 'n' si pide push
printf 's\nn\n' | "$TARGET_BIN_DIR/entregar" .
ZIP_COUNT="$(ls -1 "$TEST_HOME"/ENTREGA_demo_tp_*.zip 2>/dev/null | wc -l)"
if [ "$ZIP_COUNT" -lt 1 ]; then
    echo -e "${RED}[FALLA] 'entregar' no generó el paquete ZIP.${RESET}"
    exit 1
fi
echo -e "${GREEN}[OK] 'entregar' generó el ZIP empaquetado correctamente.${RESET}"

echo "-> Probando 'doctor' ..."
"$TARGET_BIN_DIR/doctor" || true
echo -e "${GREEN}[OK] 'doctor' ejecutó el diagnóstico sin abortar.${RESET}"

# 5. Probar desinstalador
echo "-> Probando 'desinstalar-personal.sh' ..."
"$TARGET_BIN_DIR/desinstalar-personal.sh"

for s in ayuda clonar nuevo-proyecto verificar entregar doctor; do
    if [ -f "$TARGET_BIN_DIR/$s" ]; then
        echo -e "${RED}[FALLA] El script $s sigue existiendo tras la desinstalación.${RESET}"
        exit 1
    fi
done
echo -e "${GREEN}[OK] Scripts de gestión eliminados exitosamente.${RESET}"

for prof in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if grep -q "P1-GESTION-PERSONAL" "$prof"; then
        echo -e "${RED}[FALLA] El bloque de PATH aún está presente en $prof tras desinstalar.${RESET}"
        exit 1
    fi
done
echo -e "${GREEN}[OK] Bloques de PATH removidos limpiamente de los perfiles.${RESET}"

echo ""
echo -e "${GREEN}${BOLD}=== Todas las pruebas de entorno personal pasaron satisfactoriamente ===${RESET}"
