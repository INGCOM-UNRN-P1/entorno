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

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "OK: $PASS pruebas superadas."
    exit 0
else
    echo "FALLOS: $FAIL de $((PASS + FAIL)) pruebas."
    exit 1
fi
