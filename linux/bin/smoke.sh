#!/usr/bin/env bash
# smoke.sh - Automatiza las pruebas de aceptación del plan.md que no requieren
# interfaz gráfica ni privilegios: compila y ejecuta C (Prueba A), valida
# Python/pip/uv con instalación aislada en el HOME portable (Prueba B),
# construye un proyecto CMake+Ninja (Prueba C), instala/desinstala una librería
# local con manifiesto (subset de la Prueba E) y verifica identidad de Git (F).
#
# Las pruebas D (IntelliSense en VS Code), G (redespliegue offline completo) y
# H (limpieza interactiva) siguen siendo manuales: ver plan.md.
#
# Uso: smoke.sh    (0 = todo OK)

PASS=0; FAIL=0
CYAN='\033[36m'; GREEN='\033[32m'; RED='\033[31m'; YELLOW='\033[33m'; RESET='\033[0m'

ok()  { printf "${GREEN}[PASS]${RESET} %s\n" "$1"; PASS=$((PASS+1)); }
bad() { printf "${RED}[FALLA]${RESET} %s\n" "$1"; FAIL=$((FAIL+1)); }
hdr() { printf "\n${CYAN}=== %s ===${RESET}\n" "$1"; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

if [ -z "${PORTABLE_ROOT:-}" ]; then
    echo -e "${RED}[ERROR] Ejecutá este script dentro del terminal portable (launch.bat).${RESET}"
    exit 1
fi

# ---------------------------------------------------------------
hdr "Prueba A: Compilación GCC C"
printf '#include <stdio.h>\nint main(void){ printf("Hola desde GCC Portable UCRT!\\n"); return 0; }\n' > "$WORK/test.c"
if gcc "$WORK/test.c" -o "$WORK/test" && [ "$("$WORK/test")" = "Hola desde GCC Portable UCRT!" ]; then
    ok "gcc compila, ejecuta y la salida es la esperada"
else
    bad "compilación o ejecución básica de C"
fi
if command -v cppcheck >/dev/null 2>&1; then
    if cppcheck --enable=warning --suppress=missingIncludeSystem "$WORK/test.c" >/dev/null 2>&1; then
        ok "cppcheck analiza el archivo sin errores"
    else
        bad "cppcheck reporta problemas en el archivo de prueba"
    fi
elif command -v gaff >/dev/null 2>&1; then
    if gaff check "$WORK/test.c" >/dev/null 2>&1; then
        ok "gaff analiza el archivo sin violaciones de estilo"
    else
        bad "gaff reporta desviaciones en el archivo de prueba"
    fi
else
    printf "%b[AVISO] Linter estático (cppcheck/gaff) no encontrado en PATH (no bloquea el resto).%b\n" "$YELLOW" "$RESET"
fi

# ---------------------------------------------------------------
hdr "Prueba B: Python, pip y uv"
for cmd in python python3 pip uv; do
    if command -v $cmd >/dev/null 2>&1; then
        ok "$(printf '%s responde: %s' "$cmd" "$($cmd --version 2>&1 | head -n 1)")"
    else
        bad "$cmd no encontrado"
    fi
done
# Instalación aislada: venv dentro del HOME portable (evita PEP 668 y toca solo home/)
# Política del entorno: uv es el creador de entornos por defecto cuando existe
# (más rápido y sin dependencias externas), con fallback automático a python -m venv.
VENV_CREADO=0
if command -v uv >/dev/null 2>&1 && uv venv "$WORK/.venv" >/dev/null 2>&1; then
    VENV_CREADO=1
    VENV_MOTOR="uv"
elif python -m venv "$WORK/.venv" >/dev/null 2>&1; then
    VENV_CREADO=1
    VENV_MOTOR="python -m venv"
fi
if [ "$VENV_CREADO" = 1 ]; then
    if "$WORK/.venv/bin/python" -m pip install --quiet requests >/dev/null 2>&1 && \
       "$WORK/.venv/bin/python" -c "import requests" >/dev/null 2>&1; then
        ok "venv en HOME portable instala e importa 'requests' (motor: $VENV_MOTOR)"
    else
        bad "instalación de paquete en entorno virtual"
    fi
else
    bad "creación de venv de Python"
fi

# ---------------------------------------------------------------
hdr "Prueba C: Sistema de construcción (CMake + Ninja)"
mkdir -p "$WORK/cmake-proj"
cat > "$WORK/cmake-proj/CMakeLists.txt" <<'EOF'
cmake_minimum_required(VERSION 3.10)
project(smoke_c C)
add_executable(smoke_c main.c)
EOF
printf 'int main(void){return 0;}\n' > "$WORK/cmake-proj/main.c"
GEN="Unix Makefiles"
command -v ninja >/dev/null 2>&1 && GEN="Ninja"
if cmake -G "$GEN" -S "$WORK/cmake-proj" -B "$WORK/cmake-proj/build" >/dev/null 2>&1 && \
   cmake --build "$WORK/cmake-proj/build" >/dev/null 2>&1; then
    ok "CMake configura y compila con generador $GEN"
else
    bad "build CMake ($GEN)"
fi

# ---------------------------------------------------------------
hdr "Subset Prueba E: gestión de librerías con manifiesto"
mkdir -p "$WORK/libfix/inc"
printf '#ifndef SMOKE_H\n#define SMOKE_H\n#endif\n' > "$WORK/libfix/inc/smoke.h"
if install-lib.sh "$WORK/libfix" >/dev/null 2>&1 && [ -f "${PORTABLE_PREFIX:-$PORTABLE_ROOT/local}/include/inc/smoke.h" ]; then
    ok "install-lib instala cabecera conservando estructura"
else
    bad "instalación de librería de prueba"
fi
if uninstall-lib.sh libfix >/dev/null 2>&1; then
    ok "uninstall-lib elimina según manifiesto"
else
    bad "desinstalación vía manifiesto"
fi

# ---------------------------------------------------------------
hdr "Chequeo Prueba F: identidad de Git"
if [ -n "$(git config --global user.name 2>/dev/null)" ] && [ -n "$(git config --global user.email 2>/dev/null)" ]; then
    ok "identidad configurada ($(git config --global user.name))"
else
    printf "%b[AVISO] Sin identidad de Git: ejecutá configure-git.sh (no bloquea el resto).%b\n" "$YELLOW" "$RESET"
fi

# ---------------------------------------------------------------
printf "\n${CYAN}======================================================================${RESET}\n"
if [ "$FAIL" -eq 0 ]; then
    printf "${GREEN}RESULTADO: %d/%d verificaciones superadas. Núcleo del entorno OK.${RESET}\n" "$PASS" "$PASS"
    exit 0
else
    printf "${RED}RESULTADO: %d fallo(s) de %d verificaciones.${RESET}\n" "$FAIL" "$((PASS+FAIL))"
    exit 1
fi
