#!/usr/bin/env bash
# test_linux_env.sh - Pruebas de la variante Linux sin dependencias externas.
# Se ejecuta en CI y localmente:  tests/test_linux_env.sh
# Trabaja sobre un sandbox temporal copiando linux/ para no tocar el repositorio real.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

PASS=0
FAIL=0
assert() { # assert <descripcion> <comando...>
    local desc="$1"; shift
    if "$@" >/dev/null 2>&1; then
        PASS=$((PASS + 1))
    else
        echo "FALLA: $desc"
        FAIL=$((FAIL + 1))
    fi
}

# Sandbox: solo hace falta el directorio linux/ dentro de una raíz falsa
mkdir -p "$SANDBOX/repo"
cp -r "$REPO_ROOT/linux" "$SANDBOX/repo/linux"
printf '0.0-test\n' > "$SANDBOX/repo/VERSION"

run_in_sandbox() { # run_in_sandbox <script-bash>
    bash -c "source '$SANDBOX/repo/linux/activate.sh' >/dev/null; $1"
}

# --- Pruebas de activación ---
OUT=$(run_in_sandbox 'echo "$HOME"')
assert "activación redirige HOME al sandbox" [ "$OUT" = "$SANDBOX/repo/home" ]

OUT=$(run_in_sandbox 'echo "${PORTABLE_ROOT##*/}"')
assert "PORTABLE_ROOT apunta a la raíz del sandbox" [ "$OUT" = "repo" ]

OUT=$(run_in_sandbox 'command -v install-lib.sh')
assert "linux/bin queda en el PATH tras activar" [ -n "$OUT" ] && [ "$(dirname "$OUT")" = "$SANDBOX/repo/linux/bin" ]

OUT=$(run_in_sandbox 'type -t deactivate')
assert "define la función deactivate" [ "$OUT" = "function" ]

# --- HOME personalizado vía .env ---
printf 'set "HOME_DIR_NAME=alumno2026"\n' > "$SANDBOX/repo/.env"
OUT=$(run_in_sandbox 'echo "$HOME"')
assert ".env con HOME_DIR_NAME personalizado se respeta" [ "$OUT" = "$SANDBOX/repo/alumno2026" ]
rm -f "$SANDBOX/repo/.env"

# --- Desactivación restaura ---
OUT=$(bash -c '
    OLD_HOME="$HOME"
    source '"$SANDBOX/repo/linux/activate.sh"' >/dev/null
    deactivate >/dev/null
    { [ "$HOME" = "$OLD_HOME" ] && ! type -t deactivate >/dev/null; } && echo ok || echo mal
')
assert "deactivate restaura HOME y elimina la función" test "$OUT" = "ok"

OUT=$(bash -c '
    OLD_PATH="$PATH"
    source '"$SANDBOX/repo/linux/activate.sh"' >/dev/null
    deactivate >/dev/null
    [ "$PATH" = "$OLD_PATH" ] && echo ok || echo mal
')
assert "PATH idéntico tras desactivar" test "$OUT" = "ok"

# --- Skel y deduplicación de PATH en shells anidados ---
run_in_sandbox 'exit 0' # fuerza creación del skel .bashrc
assert "skel .bashrc creado en el home portable" test -f "$SANDBOX/repo/home/.bashrc"
assert "skel .bash_profile creado en el home portable" test -f "$SANDBOX/repo/home/.bash_profile"

OUT=$(run_in_sandbox 'bash -c "echo \$PATH" | tr ":" "\n" | grep -c "repo/linux/bin$" || true')
assert "PATH no duplica linux/bin en shell anidado" test "$OUT" -le 1

# --- Bloques entre marcas en .bashrc (customize-terminal) ---
printf '# base\n' > "$SANDBOX/repo/home/.bashrc"
export PORTABLE_ROOT="$SANDBOX/repo"
export HOME="$SANDBOX/repo/home"
printf 's\n1\n1\n2\n' | bash "$REPO_ROOT/linux/bin/customize-terminal.sh" >/dev/null 2>&1
assert "banner escrito con marcas" grep -q "# === START WELCOME BANNER ===" "$SANDBOX/repo/home/.bashrc"
assert "prompt escrito con marcas" grep -q "# === START PROMPT ===" "$SANDBOX/repo/home/.bashrc"

# --- Flujo GitHub Classroom: clonar + entregar con publicación (repositorio local) ---
REMOTE="$SANDBOX/tp01.git"
git init -q --bare "$REMOTE"
git -C "$REMOTE" symbolic-ref HEAD refs/heads/main

# Sembrar un TP mínimo en el remoto para poder clonarlo
SEED="$SANDBOX/seed"
mkdir -p "$SEED"
cat > "$SEED/main.c" <<'EOF'
#include <stdio.h>
int main(void){ printf("Hola desde tp01!\n"); return 0; }
EOF
cat > "$SEED/Makefile" <<'EOF'
TARGET := tp01
all: $(TARGET)
$(TARGET): main.c
	gcc -O2 -Wall -o $@ $<
clean:
	rm -f $(TARGET)
.PHONY: all clean
EOF
git -C "$SEED" init -q -b main
git -C "$SEED" add -A
git -C "$SEED" -c user.name=Semilla -c user.email=semilla@test.local commit -qm "TP inicial"
git -C "$SEED" push -q "$REMOTE" main

run_in_sandbox "clonar '$REMOTE'" >/dev/null
assert "clonar crea el proyecto bajo HOME/proyectos" test -d "$SANDBOX/repo/home/proyectos/tp01/.git"

TC=$(run_in_sandbox "clonar '$REMOTE' >/dev/null 2>&1; echo \$?")
assert "clonar rechaza clonar dos veces sobre la misma carpeta" test "$TC" -ne 0

# Identidad global dentro del HOME portable (no toca el host)
run_in_sandbox "git config --global user.name Alumno && git config --global user.email alumno@test.local"

REPO="$SANDBOX/repo/home/proyectos/tp01"
N0=$(git --git-dir="$REMOTE" rev-list --count main)

# Cambios + respuesta 's s': compila y publica
printf 's\ns\n' | run_in_sandbox "cd '$REPO' && printf '// avance\n' >> main.c && entregar >/dev/null"
N1=$(git --git-dir="$REMOTE" rev-list --count main)
assert "entregar publica commit+push al responder s" test "$N1" -eq $((N0 + 1))

# Cambios + respuesta 's n': compila pero no publica
printf 's\nn\n' | run_in_sandbox "cd '$REPO' && printf '// avance 2\n' >> main.c && entregar >/dev/null"
N2=$(git --git-dir="$REMOTE" rev-list --count main)
assert "entregar omite la publicación al responder n" test "$N2" -eq "$N1"

# --- Corrector local: verificar como filtro de la entrega ---
run_in_sandbox "cd '$SANDBOX/repo/home' && nuevo-proyecto tpv" >/dev/null
TPV="$SANDBOX/repo/home/tpv"
assert "nuevo-proyecto genera el caso inicial del corrector" test -f "$TPV/tests/caso_01.out"

VC=$(run_in_sandbox "cd '$TPV' && verificar >/dev/null 2>&1; echo \$?")
assert "verificar aprueba el proyecto recién creado" test "$VC" -eq 0

sed -i 's/Hola desde tpv/Salida rota/' "$TPV/main.c"
VC=$(run_in_sandbox "cd '$TPV' && verificar >/dev/null 2>&1; echo \$?")
assert "verificar rechaza una salida incorrecta" test "$VC" -ne 0

# Pruebas fallidas + respuesta n en "¿Empacar igualmente?" → cancela sin ZIP
printf 's\nn\n' | run_in_sandbox "cd '$TPV' && entregar" >/dev/null
assert "entregar no genera ZIP cuando las pruebas fallan y se cancela" \
    bash -c "! ls '$SANDBOX/repo/home'/ENTREGA_tpv_* 2>/dev/null"

sed -i 's/Salida rota/Hola desde tpv/' "$TPV/main.c"
printf 's\n' | run_in_sandbox "cd '$TPV' && entregar" >/dev/null
assert "entregar genera el ZIP cuando las pruebas pasan" \
    bash -c "ls '$SANDBOX/repo/home'/ENTREGA_tpv_*.zip >/dev/null 2>&1"

# --- Comando soporte: informe único anonimizado ---
SUP=$(run_in_sandbox "cd '$SANDBOX/repo/home' && soporte >/dev/null && ls '$SANDBOX/repo'/soporte-*.txt | head -n1")
assert "soporte genera el informe en la raíz del entorno" test -f "$SUP"
assert "el informe no filtra la ruta real" bash -c "! grep -qF '$SANDBOX' '$SUP'"
assert "el informe no filtra el nombre de usuario" bash -c "! grep -qF '$(whoami)' '$SUP'"
assert "el informe incluye versión y diagnóstico" \
    bash -c "grep -q '^Versión' '$SUP' && grep -q 'DIAGNÓSTICO' '$SUP'"

# --- configure-git: elección de credential helper (caché temporal vs store) ---
run_in_sandbox "printf 'Alumno\nalumno@p1.test\nn\n1\n' | configure-git.sh >/dev/null 2>&1"
CH=$(HOME="$SANDBOX/repo/home" git config --global credential.helper)
assert "configure-git ofrece caché temporal de credenciales por defecto" \
    test "$CH" = "cache --timeout=3600"

run_in_sandbox "printf 'Alumno\nalumno@p1.test\nn\n2\n' | configure-git.sh >/dev/null 2>&1"
CH=$(HOME="$SANDBOX/repo/home" git config --global credential.helper)
assert "configure-git permite store persistente al elegirlo explícitamente" \
    test "$CH" = "store --file ~/.git-credentials"

# --- Activación doble: idempotente dentro de la misma sesión ---
DOBLE=$(run_in_sandbox "H1=\"\$HOME\"; OUT=\"\$(source '$SANDBOX/repo/linux/activate.sh' 2>&1 || true)\"; case \"\$OUT\" in *'ya está activo'*) echo \"guard:\$HOME=\$H1\";; *) echo \"mal:\$OUT\";; esac")
case "$DOBLE" in
    guard:*) assert "doble activación avisa y conserva el HOME portable" true ;;
    *) assert "doble activación avisa y conserva el HOME portable" false ;;
esac

# --- Ayuda: se renderiza y muestra la versión del entorno ---
AYUDA=$(run_in_sandbox "ayuda")
assert "ayuda muestra el encabezado de guía" bash -c "grep -q 'GUÍA RÁPIDA' <<< \"\$(
    cat <<'EOF'
$AYUDA
EOF
)\""
assert "ayuda informa la versión del entorno" bash -c "grep -q 'v0\.0-test' <<'EOF'
$AYUDA
EOF"

# --- diagnose-env escribe el informe en la raíz aunque el CWD sea otro ---
run_in_sandbox "cd /tmp && diagnose-env.sh >/dev/null 2>&1"
assert "diagnose-env deja diagnose.log en PORTABLE_ROOT" \
    test -f "$SANDBOX/repo/diagnose.log"
assert "el informe incluye versión y encabezado" \
    bash -c "head -n 5 '$SANDBOX/repo/diagnose.log' | grep -q 'INFORME DE DIAGNÓSTICO'"
rm -f "$SANDBOX/repo/diagnose.log"

# --- Integridad del repositorio: fuentes únicas sin drift ---
assert "packages-baseline.txt no tiene paquetes duplicados ni vacío" python3 -c "
import sys
lineas = [l.split('#')[0].strip() for l in open('$REPO_ROOT/packages-baseline.txt')]
paquetes = [l for l in lineas if l]
sys.exit(0 if paquetes and len(paquetes) == len(set(paquetes)) else 1)
"
assert "versions.json es JSON válido con canal definido" python3 -c "
import json, sys
datos = json.load(open('$REPO_ROOT/versions.json'))
sys.exit(0 if isinstance(datos, dict) and datos.get('canal') else 1)
"

# --- backup y restaurar: roundtrip del HOME portable ---
run_in_sandbox "printf 'int main(void){return 0;}\n' > '$SANDBOX/repo/home/main.c'"
run_in_sandbox "mkdir -p '$SANDBOX/repo/home/.cache/junk' && touch '$SANDBOX/repo/home/.cache/junk/tmp.bin'"
run_in_sandbox "mkdir -p '$SANDBOX/repo/home/proy/__pycache__' && touch '$SANDBOX/repo/home/proy/__pycache__/m.pyc'"
run_in_sandbox "mkdir -p '$SANDBOX/repo/local/portable-libs' '$SANDBOX/repo/local/include' '$SANDBOX/repo/local/lib'"
run_in_sandbox "printf 'include/milib.h\nlib/libmilib.a\n# nota: instalado via make install\n' > '$SANDBOX/repo/local/portable-libs/milib.files'"
run_in_sandbox "touch '$SANDBOX/repo/local/include/milib.h' '$SANDBOX/repo/local/lib/libmilib.a'"

BKZIP="$SANDBOX/bk.zip"
run_in_sandbox "backup '$BKZIP'" >/dev/null
assert "backup crea el ZIP de respaldo" test -f "$BKZIP"
assert "el respaldo excluye cachés regenerables" python3 -c "
import zipfile, sys
nombres = zipfile.ZipFile('$BKZIP').namelist()
sys.exit(1 if any('.cache/' in n or '.pyc' in n for n in nombres) else 0)
"
assert "el respaldo incluye el código y los manifiestos" python3 -c "
import zipfile, sys
nombres = zipfile.ZipFile('$BKZIP').namelist()
ok = any(n == 'home/main.c' for n in nombres) and any('meta/portable-libs/milib.files' in n for n in nombres)
sys.exit(0 if ok else 1)
"

# Destruir el home y recuperar desde el ZIP (respuesta s)
run_in_sandbox "rm -rf '$SANDBOX/repo/home' && mkdir -p '$SANDBOX/repo/home'"
run_in_sandbox "rm -rf '$SANDBOX/repo/local'"
printf 's\n' | run_in_sandbox "restaurar '$BKZIP'" >/dev/null
assert "restaurar recupera el archivo del alumno" \
    bash -c "grep -q 'int main' '$SANDBOX/repo/home/main.c'"
assert "restaurar repone los manifiestos de librerías" \
    test -f "$SANDBOX/repo/local/portable-libs/milib.files"

# --- uninstall-lib con manifiesto fabricado ---
ULS=$(run_in_sandbox "uninstall-lib.sh")
assert "uninstall-lib lista las librerías registradas" \
    bash -c "grep -q 'milib' <<'EOF'
$ULS
EOF"
TC=$(run_in_sandbox "uninstall-lib.sh inexistente >/dev/null 2>&1; echo \$?")
assert "uninstall-lib falla ante un manifiesto desconocido" test "$TC" -ne 0
USAL=$(run_in_sandbox "uninstall-lib.sh milib")
assert "uninstall-lib elimina los archivos del manifiesto" \
    bash -c "! test -e '$SANDBOX/repo/local/include/milib.h' && ! test -e '$SANDBOX/repo/local/lib/libmilib.a'"
assert "uninstall-lib poda los directorios que quedaron vacíos" \
    bash -c "! test -d '$SANDBOX/repo/local/include'"
assert "uninstall-lib avisa sobre notas de instalación parcial" \
    bash -c "grep -q 'instalación parcial' <<'EOF'
$USAL
EOF"
assert "uninstall-lib elimina el manifiesto consumido" \
    bash -c "! test -f '$SANDBOX/repo/local/portable-libs/milib.files'"

# --- doctor --fix en la variante Linux ---
run_in_sandbox "rm -rf '$SANDBOX/repo/home' && doctor --fix >/dev/null"
assert "doctor --fix recrea el skel con el banner institucional" \
    bash -c "grep -q 'START INSTITUTIONAL BANNER' '$SANDBOX/repo/home/.bashrc'"
FIX2=$(run_in_sandbox "doctor --fix")
assert "doctor --fix es idempotente" \
    bash -c "grep -q 'Nada que reparar' <<'EOF'
$FIX2
EOF"
run_in_sandbox "printf '# config propia\n' > '$SANDBOX/repo/home/.bashrc' && rm -f '$SANDBOX/repo/home/.bash_profile' && doctor --fix >/dev/null"
assert "doctor --fix completa lo faltante sin pisar archivos propios" \
    bash -c "grep -q 'config propia' '$SANDBOX/repo/home/.bashrc' && test -f '$SANDBOX/repo/home/.bash_profile'"

# --- verificar: casos avanzados de la convención de cátedra ---
run_in_sandbox "cd '$SANDBOX/repo/home' && nuevo-proyecto tpv2 >/dev/null"
TPV2="$SANDBOX/repo/home/tpv2"

# Tolerancia a CRLF y espacios finales en la salida esperada
run_in_sandbox "cd '$TPV2' && printf 'Hola desde tpv2!\r\n' > tests/caso_02.out && printf 'entrada\n' > tests/caso_02.in"
VC=$(run_in_sandbox "cd '$TPV2' && verificar >/dev/null 2>&1; echo \$?")
assert "verificar tolera CRLF y espacios finales en el esperado" test "$VC" -eq 0

# Precedencia del objetivo 'test:' del Makefile sobre los casos .in/.out
run_in_sandbox "cd '$TPV2' && printf 'test:\n\t@echo PRUEBA-MAKE-OK\n' >> Makefile"
VOUT=$(printf 'n\nn\n' | run_in_sandbox "cd '$TPV2' && verificar")
assert "verificar prioriza 'make test' cuando existe" \
    bash -c "grep -q 'PRUEBA-MAKE-OK' <<'EOF'
$VOUT
EOF"

# Programa que cuelga: el timeout lo corta y el caso falla
run_in_sandbox "cd '$TPV2' && sed -i '/^test:/,+1d' Makefile"
run_in_sandbox "cd '$TPV2' && sed -i 's/return 0;/for(;;);/' main.c && rm -rf tests && mkdir tests && : > tests/caso_01.in && printf 'x\n' > tests/caso_01.out"
VC=$(run_in_sandbox "cd '$TPV2' && verificar >/dev/null 2>&1; echo \$?")
assert "verificar corta con timeout un programa que no responde" test "$VC" -ne 0

# --- entregar: exclusiones del paquete ---
run_in_sandbox "cd '$TPV2' && sed -i 's/for(;;);//' main.c && mkdir -p build && touch build/intermedio.o objeto.o binario.exe"
printf 's\ns\n' | run_in_sandbox "cd '$TPV2' && entregar" >/dev/null
ZIPRC=$(python3 -c "
import zipfile, glob, sys
zips = sorted(glob.glob('$SANDBOX/repo/home/ENTREGA_tpv2_*.zip'))
sys.exit(0 if zips and not any(n.endswith(('.o', '.exe')) or n.startswith('build/') for n in zipfile.ZipFile(zips[-1]).namelist()) else 1)
"; echo $?)
assert "entregar excluye .o/.exe/build del paquete" test "$ZIPRC" -eq 0

# Proyecto que no es C: rechazo temprano
run_in_sandbox "mkdir -p '$SANDBOX/repo/home/vacio' && cd '$SANDBOX/repo/home/vacio' && entregar >/dev/null 2>&1; echo \$?" > /tmp/entvacio.$$
TC=$(cat /tmp/entvacio.$$); rm -f /tmp/entvacio.$$
assert "entregar rechaza un directorio que no es proyecto C" test "$TC" -ne 0

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "OK: $PASS pruebas superadas."
    exit 0
else
    echo "FALLOS: $FAIL de $((PASS + FAIL)) pruebas."
    exit 1
fi
