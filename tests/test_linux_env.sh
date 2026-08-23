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

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "OK: $PASS pruebas superadas."
    exit 0
else
    echo "FALLOS: $FAIL de $((PASS + FAIL)) pruebas."
    exit 1
fi
